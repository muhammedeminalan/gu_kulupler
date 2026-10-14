'use strict';
// T-22 — `rsvps/{eventId}_{userId}` ve `events/{eventId}/private/counter` (rules-spec §3.8; PLAN §11.1 satır 10;
// sözleşme docs/plans/T-22.md §6.3 – §6.5, §6.7).
//
//  1. Rol × işlem matrisi: `expectations/rsvps.json` (okuma: sahibi / yönetim; katılım public / members;
//     vazgeçme askıdaki hesaba açık; yoklama ve terfi yalnızca yönetici; soft delete / delete yok) ve
//     `expectations/event_counters.json` (yan belge: yalnızca `seesMgmt` okur, tek başına yazılamaz — W-64).
//  2. Katıl (C): kimlik `{eventId}_{uid}` ↔ alanlar, beyaz liste, `reminder` 4 değer (CD-34), bilet kodu
//     deseni, etkinliğin durumu ve zamanı (`request.time`), W-51 iki biçim.
//  3. Kontenjan: yer varken `going`, doluyken `waitlist` (+ `waitlistAt`); tersi reddedilir.
//  4. Vazgeç / yeniden katıl / hatırlatma: durum geçişleri, bilet kodu korunur.
//  5. Yoklama (yönetici): pencere (başlangıç − 2 sa … bitiş + 6 sa — Limits.attendanceWindowBefore / After),
//     `scannedAt == request.time`, `scannedBy == uid`; terfi: bitmemiş etkinlik.
// Sayaç–katılım eşliği ve saldırı vakaları `counters.test.js`, sorgu biçimleri `queries.test.js`.
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { Timestamp, collection, doc, getDoc, getDocs, limit, query, serverTimestamp, updateDoc, where } = require('firebase/firestore');
const budget = require('../helpers/budget');
const { contextFor, CLUB, OTHER_CLUB } = require('../helpers/contexts');
const { HOUR_MS, fromNow, readDoc, seedFixture } = require('../helpers/fixtures');
const { runMatrix } = require('../helpers/matrix');
const payloads = require('../helpers/payloads');

const STUDENT = 'u_student';
const MEMBER = 'u_member';
const BOARD = 'u_board';
const E_PUBLIC = 'events/e_public';
const E_LIVE = 'events/e_live';
const R_STUDENT = payloads.rsvpPath('e_public', STUDENT);
const R_MEMBER = payloads.rsvpPath('e_public', MEMBER);
const R_LIVE_MEMBER = payloads.rsvpPath('e_live', MEMBER);
const R_LIVE_STUDENT = payloads.rsvpPath('e_live', STUDENT);
const NO_EDIT = Object.freeze({});
const MINUTE_MS = 60 * 1000;
/** Kontenjanı dolu `e_public` (2 kayıtlı / 2 kontenjan). */
const FULL = { patch: { [E_PUBLIC]: { capacity: 2 } } };

const db = (role) => contextFor(role).firestore();
const commit = (role, writes) => budget.buildBatch(db(role), Object.values(writes)).commit();
const expectWrite = (request, expected) => (expected === 'allow' ? assertSucceeds(request) : assertFails(request));
const without = (data, ...keys) => Object.fromEntries(Object.entries(data).filter(([key]) => !keys.includes(key)));
const at = (ms) => Timestamp.fromMillis(Date.now() + ms);
/** Öğrencinin katılım işlemi (kayıt + sayaç); `extra` kayıt alanlarını ezer, `drop` anahtarları çıkarır. */
const join = (extra, { drop = [], status = 'going', path } = {}) => {
  const writes = payloads.rsvpJoinWrites({ club: CLUB, uid: STUDENT, status });
  return { ...writes, rsvp: { op: 'set', path: path || writes.rsvp.path, data: without({ ...writes.rsvp.data, ...extra }, ...drop) } };
};
/** Yöneticinin yoklama işlemi; `extra` kayıt yükünü ezer. */
const attend = (extra, options = {}) => {
  const writes = payloads.attendWrites({ club: CLUB, uid: BOARD, ...options });
  return { ...writes, rsvp: { ...writes.rsvp, data: { ...writes.rsvp.data, ...extra } } };
};

runMatrix('rsvps.json');
runMatrix('event_counters.json');

describe('rsvps · create (Katıl) — kimlik, biçim ve etkinlik koşulları (rules-spec §3.8 C)', () => {
  test('kayıt yalnızca beklenen alanları taşır (istemci biçimi); bilet kodu yalnızca bu belgededir', async () => {
    await seedFixture('base');
    await assertSucceeds(commit('student', join()));
    const rsvp = await readDoc(R_STUDENT);
    expect(Object.keys(rsvp).sort()).toEqual([
      'clubId', 'createdAt', 'deletedAt', 'deletedBy', 'eventId', 'isDeleted', 'reminder', 'status', 'ticketCode', 'updatedAt', 'userId',
    ]);
    expect(rsvp).toMatchObject({ eventId: 'e_public', clubId: CLUB, userId: STUDENT, status: 'going', ticketCode: payloads.TICKET_CODE });
    // Herkese açık etkinlik belgesi bilet kodunu ve katılanın kimliğini taşımaz (W-64).
    const event = JSON.stringify((await assertSucceeds(getDoc(doc(db('otherManager'), E_PUBLIC)))).data());
    expect(event).not.toContain(payloads.TICKET_CODE);
    expect(event).not.toContain(STUDENT);
    // Başka bir katılımcı (sıradan üye) bu kaydı ve bilet kodunu okuyamaz.
    await assertFails(getDoc(doc(db('member'), R_STUDENT)));
  });

  // Satır: [başlık, kayıt alanı ezmesi, beklenti, seçenekler?, veri düzenlemesi?].
  test.each([
    ['hatırlatma none (CD-34)', { reminder: 'none' }, 'allow'],
    ['hatırlatma 15m (CD-34)', { reminder: '15m' }, 'allow'],
    ['hatırlatma 1d (CD-34)', { reminder: '1d' }, 'allow'],
    ['seed biçimi: waitlistAt / scannedAt / scannedBy açık null (W-51)', payloads.RSVP_NULLS, 'allow'],
    ['istemci biçimli etkinlik: kontenjan anahtarı yok = sınırsız (W-51)', {}, 'allow', {}, { unset: { [E_PUBLIC]: ['capacity', 'placeText', 'cancelReason', 'coverPath'] } }],
    ['seed biçimli etkinlik: kontenjan açık null = sınırsız (W-51)', {}, 'allow', {}, { patch: { [E_PUBLIC]: { capacity: null } } }],
    ['başlamış ama bitmemiş etkinlik (endsAt > request.time)', {}, 'allow', {}, { patch: { [E_PUBLIC]: { startsAt: fromNow(-HOUR_MS), endsAt: fromNow(HOUR_MS) } } }],
    ['hatırlatma değer listesi dışında', { reminder: '2h' }, 'deny'],
    ['hatırlatma yok', {}, 'deny', { drop: ['reminder'] }],
    ['bilet kodu yok', {}, 'deny', { drop: ['ticketCode'] }],
    ['bilet kodu alfabe dışı karakter (0)', { ticketCode: 'GU-ABCD-2340' }, 'deny'],
    ['bilet kodu küçük harf', { ticketCode: 'gu-abcd-2345' }, 'deny'],
    ['bilet kodu ayırıcısız', { ticketCode: 'GU-ABCD2345' }, 'deny'],
    ['bilet kodu fazladan ek', { ticketCode: 'GU-ABCD-2345-X' }, 'deny'],
    ['başkası adına katılım: userId başkası (kimlik kendi)', { userId: BOARD }, 'deny'],
    ['başkası adına katılım: kimlik başkasının (userId kendi)', {}, 'deny', { path: payloads.rsvpPath('e_public', BOARD) }],
    ['başkası adına katılım: kimlik ve userId başkasının', { userId: BOARD }, 'deny', { path: payloads.rsvpPath('e_public', BOARD) }],
    ['eventId alanı kimlikle uyuşmuyor (başka etkinlik)', { eventId: 'e_members' }, 'deny'],
    ['clubId etkinliğin kulübü değil', { clubId: OTHER_CLUB }, 'deny'],
    ['attended doğan kayıt', { status: 'attended' }, 'deny'],
    ['cancelled doğan kayıt', { status: 'cancelled' }, 'deny'],
    ['going kayıtta waitlistAt dolu', { waitlistAt: serverTimestamp() }, 'deny'],
    ['scannedAt dolu', { scannedAt: serverTimestamp() }, 'deny'],
    ['scannedBy dolu', { scannedBy: BOARD }, 'deny'],
    ['beyaz liste dışı alan (role)', { role: 'board' }, 'deny'],
    ['silinmiş doğan kayıt', { isDeleted: true }, 'deny'],
    ['createdAt istemci saati', { createdAt: at(-MINUTE_MS) }, 'deny'],
    ['geçmiş etkinlik: endsAt <= request.time (TST-X6)', {}, 'deny', {}, { patch: { [E_PUBLIC]: { startsAt: fromNow(-3 * HOUR_MS), endsAt: fromNow(-MINUTE_MS) } } }],
  ])('%s → %s', async (_title, extra, expected, options = {}, seedEdit = NO_EDIT) => {
    await seedFixture('base', undefined, seedEdit);
    const writes = join(extra, options);
    await expectWrite(commit('student', writes), expected);
    expect((await readDoc(E_PUBLIC)).goingCount).toBe(expected === 'allow' ? 3 : 2);
    if (expected === 'deny') expect(await readDoc(writes.rsvp.path)).toBeNull();
  });

  // Güvenlik incelemesi (CD-144; D-30): kodu istemci üretir, kural yalnızca deseni denetler — başkasının kodunu
  // kopyalayan katılım KABUL edilir (tekillik Rules'ta kurulamaz). Savunma okuma tarafındadır: yönetimin bilet
  // araması `limit 2` ile iki kayıt görür ve `FirebaseRsvpRepository.findByTicket` eşleşmeyi belirsiz sayar
  // (failedPrecondition — gerçek sahibin okutması kopyalayana çevrilemez; birim testi orada).
  test('kopyalanmış bilet kodu: katılım geçer, yönetimin bilet araması iki kayıt döndürür', async () => {
    const seeded = await seedFixture('base');
    const code = seeded[R_MEMBER].ticketCode;
    await assertSucceeds(commit('student', join({ ticketCode: code })));
    const byTicket = query(collection(db('board'), 'rsvps'), where('eventId', '==', 'e_public'), where('clubId', '==', CLUB),
      where('ticketCode', '==', code), limit(2));
    const found = await assertSucceeds(getDocs(byTicket));
    expect(found.docs.map((d) => d.id).sort()).toEqual([R_MEMBER.split('/')[1], R_STUDENT.split('/')[1]].sort());
  });

  test('olmayan etkinliğe katılım reddedilir', async () => {
    await seedFixture('base');
    await assertFails(commit('student', payloads.rsvpJoinWrites({ club: CLUB, uid: STUDENT, eventId: 'e_missing' })));
    await assertFails(commit('student', { rsvp: payloads.rsvpJoinWrites({ club: CLUB, uid: STUDENT, eventId: 'e_missing' }).rsvp }));
  });
});

describe('rsvps · kontenjan ve bekleme listesi (domain-model §8; sözleşme §6.3 going ⇔ yer var ve bekleyen yok — CD-144)', () => {
  // Satır: [başlık, durum, kayıt alanı ezmesi, beklenti, veri düzenlemesi, beklenen (going, waitlist)].
  test.each([
    ['kontenjan dolu → waitlist + waitlistAt sunucu zamanı', 'waitlist', {}, 'allow', FULL, [2, 1]],
    ['son yer (2 / 3 → 3 / 3) → going', 'going', {}, 'allow', { patch: { [E_PUBLIC]: { capacity: 3 } } }, [3, 0]],
    ['kontenjan dolu → going (kontenjan aşımı)', 'going', {}, 'deny', FULL, [2, 0]],
    // Güvenlik incelemesi (CD-144): boşalan yer önce bekleyenindir (Mod C'de yönetici terfi eder) — yeni gelen sırayı atlayamaz.
    ['yer var ama önde bekleyen var → going (sıra atlama)', 'going', {}, 'deny', { patch: { [E_PUBLIC]: { capacity: 5, waitlistCount: 1 } } }, [2, 1]],
    ['yer var ama önde bekleyen var → waitlist', 'waitlist', {}, 'allow', { patch: { [E_PUBLIC]: { capacity: 5, waitlistCount: 1 } } }, [2, 2]],
    ['sınırsız etkinlikte bekleyen olsa da → going', 'going', {}, 'allow', { patch: { [E_PUBLIC]: { capacity: null, waitlistCount: 1 } } }, [3, 1]],
    ['yer varken waitlist', 'waitlist', {}, 'deny', NO_EDIT, [2, 0]],
    ['sınırsız etkinlikte waitlist (kontenjan anahtarı yok)', 'waitlist', {}, 'deny', { unset: { [E_PUBLIC]: ['capacity'] } }, [2, 0]],
    ['waitlist kayıtta waitlistAt yok', 'waitlist', {}, 'deny', FULL, [2, 0], ['waitlistAt']],
    ['waitlist kayıtta waitlistAt istemci saati (sıra öne çekilemez)', 'waitlist', { waitlistAt: at(-24 * HOUR_MS) }, 'deny', FULL, [2, 0]],
  ])('%s → %s', async (_title, status, extra, expected, seedEdit, [going, waitlist], drop = []) => {
    await seedFixture('base', undefined, seedEdit);
    await expectWrite(commit('student', join(extra, { status, drop })), expected);
    expect(await readDoc(E_PUBLIC)).toMatchObject({ goingCount: going, waitlistCount: waitlist });
    const rsvp = await readDoc(R_STUDENT);
    if (expected === 'deny') expect(rsvp).toBeNull();
    else if (status === 'waitlist') expect(rsvp.waitlistAt.toMillis()).toBe(rsvp.createdAt.toMillis());
  });
});

describe('rsvps · vazgeç / yeniden katıl / hatırlatma (rules-spec §3.8 U sahibi)', () => {
  const CANCELLED = { patch: { [R_MEMBER]: { status: 'cancelled' }, [E_PUBLIC]: { goingCount: 1 } } };
  const WAITING = { patch: { [R_MEMBER]: { status: 'waitlist', waitlistAt: fromNow(-HOUR_MS) }, [E_PUBLIC]: { goingCount: 1, waitlistCount: 1, capacity: 1 } } };
  const ATTENDED = { patch: { [R_MEMBER]: { status: 'attended', scannedAt: fromNow(-HOUR_MS), scannedBy: BOARD }, [E_PUBLIC]: { attendedCount: 1 } } };
  const rejoin = (options) => payloads.rsvpRejoinWrites({ uid: MEMBER, ...options });
  const cancel = (options) => payloads.rsvpCancelWrites({ uid: MEMBER, ...options });
  const patchRsvp = (writes, extra) => ({ ...writes, rsvp: { ...writes.rsvp, data: { ...writes.rsvp.data, ...extra } } });

  test('vazgeç → yeniden katıl: aynı belge, aynı bilet kodu ve createdAt; sayaç başa döner', async () => {
    const seeded = await seedFixture('base');
    const before = await readDoc(R_MEMBER);
    await assertSucceeds(commit('member', cancel()));
    expect(await readDoc(R_MEMBER)).toMatchObject({ status: 'cancelled', ticketCode: seeded[R_MEMBER].ticketCode });
    expect((await readDoc(E_PUBLIC)).goingCount).toBe(1);
    await assertFails(commit('member', cancel()));

    await assertSucceeds(commit('member', rejoin()));
    const after = await readDoc(R_MEMBER);
    expect(after).toMatchObject({ status: 'going', reminder: '1d', ticketCode: seeded[R_MEMBER].ticketCode, waitlistAt: null });
    expect(after.createdAt.toMillis()).toBe(before.createdAt.toMillis());
    expect((await readDoc(E_PUBLIC)).goingCount).toBe(2);
  });

  // Satır: [başlık, yazımlar, beklenti, veri düzenlemesi].
  test.each([
    ['yeniden katıl: kontenjan doluyken waitlist', () => rejoin({ status: 'waitlist' }), 'allow', { patch: { ...CANCELLED.patch, [E_PUBLIC]: { goingCount: 1, capacity: 1 } } }],
    ['yeniden katıl: istemci biçimli kayıt (waitlistAt anahtarı yok — W-51)', () => rejoin(), 'allow', { ...CANCELLED, unset: { [R_MEMBER]: ['waitlistAt', 'scannedAt', 'scannedBy'] } }],
    ['yeniden katıl: bilet kodu değişir', () => patchRsvp(rejoin(), { ticketCode: payloads.TICKET_CODE }), 'deny', CANCELLED],
    ['yeniden katıl: createdAt yenilenir', () => patchRsvp(rejoin(), { createdAt: serverTimestamp() }), 'deny', CANCELLED],
    ['yeniden katıl: going ama waitlistAt dolu', () => patchRsvp(rejoin(), { waitlistAt: serverTimestamp() }), 'deny', CANCELLED],
    ['yeniden katıl: hatırlatma değer listesi dışında', () => rejoin({ reminder: '3h' }), 'deny', CANCELLED],
    ['yeniden katıl: kayıt kapalı', () => rejoin(), 'deny', { patch: { ...CANCELLED.patch, [E_PUBLIC]: { goingCount: 1, registrationOpen: false } } }],
    ['yeniden katıl: bitmiş etkinlik', () => rejoin(), 'deny', { patch: { ...CANCELLED.patch, [E_PUBLIC]: { goingCount: 1, startsAt: fromNow(-3 * HOUR_MS), endsAt: fromNow(-HOUR_MS) } } }],
    ['yeniden katıl: doğrudan attended', () => patchRsvp(rejoin(), { status: 'attended' }), 'deny', CANCELLED],
    ['vazgeç: bekleme listesinden (waitlistCount −1)', () => cancel({ from: 'waitlist' }), 'allow', WAITING],
    // Güvenlik incelemesi (CD-144): bitmiş etkinlikte "Gelmedin" kaydı iptale çevrilip `goingCount` düşürülerek
    // yoklama oranı şişirilemez; süren etkinlikte vazgeçilir (EVT-02 / EVT-03 "Vazgeç" bitişe kadar görünür).
    ['vazgeç: bittikten sonra (yoklama oranı şişirme)', () => cancel(), 'deny', { patch: { [E_PUBLIC]: { startsAt: fromNow(-3 * HOUR_MS), endsAt: fromNow(-HOUR_MS) } } }],
    ['vazgeç: bekleme listesinden, bittikten sonra', () => cancel({ from: 'waitlist' }), 'deny', { patch: { ...WAITING.patch, [E_PUBLIC]: { ...WAITING.patch[E_PUBLIC], startsAt: fromNow(-3 * HOUR_MS), endsAt: fromNow(-HOUR_MS) } } }],
    ['vazgeç: başlamış ama bitmemiş etkinlik', () => cancel(), 'allow', { patch: { [E_PUBLIC]: { startsAt: fromNow(-HOUR_MS), endsAt: fromNow(HOUR_MS) } } }],
    ['vazgeç: iptal edilmiş etkinlik (durum aranmaz)', () => cancel(), 'allow', { patch: { [E_PUBLIC]: { status: 'cancelled', cancelReason: 'x' } } }],
    ['vazgeç: yoklaması alınmış kayıt (attended)', () => cancel(), 'deny', ATTENDED],
    ['vazgeç: aynı yazımda hatırlatma', () => patchRsvp(cancel(), { reminder: 'none' }), 'deny', NO_EDIT],
    ['vazgeç: aynı yazımda bilet kodu', () => patchRsvp(cancel(), { ticketCode: payloads.TICKET_CODE }), 'deny', NO_EDIT],
    // Güvenlik incelemesi (CD-144): bekleyen vazgeçip yeniden katılarak sırayı atlayamaz (yer var ama önde bekleyen var).
    ['yeniden katıl: yer var ama önde bekleyen var → going (kendini terfi)', () => rejoin(), 'deny', { patch: { ...CANCELLED.patch, [E_PUBLIC]: { goingCount: 1, capacity: 5, waitlistCount: 1 } } }],
    ['yeniden katıl: yer var ama önde bekleyen var → waitlist', () => rejoin({ status: 'waitlist' }), 'allow', { patch: { ...CANCELLED.patch, [E_PUBLIC]: { goingCount: 1, capacity: 5, waitlistCount: 1 } } }],
    ['bekleyen kendini terfi ettiremez (waitlist → going)', () => ({ rsvp: { op: 'update', path: R_MEMBER, data: { status: 'going', ...payloads.baseUpdate() } }, event: { op: 'update', path: E_PUBLIC, data: payloads.eventCountersBump({ going: 1, waitlist: -1 }) } }), 'deny', { patch: { ...WAITING.patch, [E_PUBLIC]: { goingCount: 1, waitlistCount: 1, capacity: 5 } } }],
    ['katılımcı kendi yoklamasını alamaz (going → attended)', () => payloads.attendWrites({ club: CLUB, uid: MEMBER, eventId: 'e_public', userId: MEMBER }), 'deny', { patch: { [E_PUBLIC]: { startsAt: fromNow(-HOUR_MS), endsAt: fromNow(HOUR_MS) } } }],
  ])('%s → %s', async (_title, build, expected, seedEdit) => {
    const seeded = await seedFixture('base', undefined, seedEdit);
    await expectWrite(commit('member', build()), expected);
    const rsvp = await readDoc(R_MEMBER);
    expect(rsvp.ticketCode).toBe(seeded[R_MEMBER].ticketCode);
    if (expected === 'deny') {
      expect(rsvp.status).toBe(seeded[R_MEMBER].status);
      expect(await readDoc(E_PUBLIC)).toMatchObject({ goingCount: seeded[E_PUBLIC].goingCount, waitlistCount: seeded[E_PUBLIC].waitlistCount });
    }
  });

  // Satır: [başlık, yük, beklenti, veri düzenlemesi?].
  test.each([
    ['none', payloads.rsvpReminder('none'), 'allow'],
    ['15m', payloads.rsvpReminder('15m'), 'allow'],
    ['1d, bekleme listesindeyken', payloads.rsvpReminder('1d'), 'allow', WAITING],
    ['değer listesi dışında (30m)', payloads.rsvpReminder('30m'), 'deny'],
    ['aynı yazımda durum', payloads.rsvpReminder('15m', { status: 'attended' }), 'deny'],
    ['aynı yazımda bilet kodu', payloads.rsvpReminder('15m', { ticketCode: payloads.TICKET_CODE }), 'deny'],
    ['updatedAt yok', { reminder: '15m' }, 'deny'],
    ['yoklaması alınmış kayıtta', payloads.rsvpReminder('15m'), 'deny', ATTENDED],
  ])('hatırlatma · %s → %s', async (_title, data, expected, seedEdit = NO_EDIT) => {
    await seedFixture('base', undefined, seedEdit);
    await expectWrite(updateDoc(doc(db('member'), R_MEMBER), data), expected);
    expect((await readDoc(R_MEMBER)).reminder).toBe(expected === 'allow' ? data.reminder : '1h');
  });
});

describe('rsvps · yoklama ve terfi (yönetici; rules-spec §3.8 U yönetici; K-G penceresi)', () => {
  /** `e_live` zamanlarını değiştirir: [başlangıca kalan ms, bitişe kalan ms]. */
  const windowAt = (startsIn, endsIn) => ({ patch: { [E_LIVE]: { startsAt: fromNow(startsIn), endsAt: fromNow(endsIn) } } });

  test('yoklama: scannedAt sunucu zamanı, scannedBy yönetici; geri alma ikisini boşaltır', async () => {
    await seedFixture('base');
    await assertSucceeds(commit('board', attend()));
    const scanned = await readDoc(R_LIVE_MEMBER);
    expect(scanned).toMatchObject({ status: 'attended', scannedBy: BOARD });
    expect(scanned.scannedAt.toMillis()).toBe(scanned.updatedAt.toMillis());
    expect(await readDoc(E_LIVE)).toMatchObject({ goingCount: 2, attendedCount: 2 });

    await assertSucceeds(commit('president', payloads.attendWrites({ club: CLUB, uid: 'u_president', attended: false })));
    expect(await readDoc(R_LIVE_MEMBER)).toMatchObject({ status: 'going', scannedAt: null, scannedBy: null });
    expect(await readDoc(E_LIVE)).toMatchObject({ goingCount: 2, attendedCount: 1 });
  });

  // Limits.attendanceWindowBefore = 2 sa, attendanceWindowAfter = 6 sa (iki uç dahil); 5 dk pay = test süresi.
  test.each([
    ['başlangıca 1 sa 55 dk (pencere açık)', windowAt(2 * HOUR_MS - 5 * MINUTE_MS, 4 * HOUR_MS), 'allow'],
    ['başlangıca 2 sa 5 dk (pencere henüz açılmadı)', windowAt(2 * HOUR_MS + 5 * MINUTE_MS, 4 * HOUR_MS), 'deny'],
    ['bitişten 5 sa 55 dk sonra (pencere açık)', windowAt(-8 * HOUR_MS, -6 * HOUR_MS + 5 * MINUTE_MS), 'allow'],
    ['bitişten 6 sa 5 dk sonra (pencere kapandı)', windowAt(-8 * HOUR_MS, -6 * HOUR_MS - 5 * MINUTE_MS), 'deny'],
  ])('pencere · %s → %s', async (_title, seedEdit, expected) => {
    await seedFixture('base', undefined, seedEdit);
    await expectWrite(commit('board', attend()), expected);
    expect((await readDoc(E_LIVE)).attendedCount).toBe(expected === 'allow' ? 2 : 1);
    // Geri alma da aynı pencereye bağlıdır (u_board'un kaydını başkan geri alır — kendi kaydı ret, §3.8).
    await expectWrite(commit('president', payloads.attendWrites({ club: CLUB, uid: 'u_president', userId: BOARD, attended: false })), expected);
  });

  // Satır: [başlık, yazımlar, veri düzenlemesi?].
  test.each([
    ['scannedBy başka yönetici', () => attend({ scannedBy: 'u_president' })],
    ['scannedAt istemci saati', () => attend({ scannedAt: at(-MINUTE_MS) })],
    ['scannedAt yok', () => attend({ scannedAt: null })],
    ['aynı yazımda hatırlatma', () => attend({ reminder: 'none' })],
    ['aynı yazımda bilet kodu', () => attend({ ticketCode: payloads.TICKET_CODE })],
    ['aynı yazımda kayıt başkasına devredilir (userId)', () => attend({ userId: BOARD })],
    ['bekleyen kaydın yoklaması (waitlist → attended)', () => attend({}, { userId: STUDENT })],
    ['vazgeçilmiş kaydın yoklaması', () => attend(), { patch: { [R_LIVE_MEMBER]: { status: 'cancelled' } } }],
    ['iptal edilmiş etkinlikte yoklama', () => attend(), { patch: { [E_LIVE]: { status: 'cancelled', cancelReason: 'x' } } }],
    ['taslağa çekilmiş etkinlikte yoklama', () => attend(), { patch: { [E_LIVE]: { status: 'draft' } } }],
    ['silinmiş etkinlikte yoklama', () => attend(), { patch: { [E_LIVE]: { isDeleted: true, deletedBy: BOARD } } }],
    ['geri alma: scannedAt / scannedBy boşaltılmaz', () => ({ ...payloads.attendWrites({ club: CLUB, uid: BOARD, userId: BOARD, attended: false }), rsvp: { op: 'update', path: payloads.rsvpPath('e_live', BOARD), data: { status: 'going', ...payloads.baseUpdate() } } })],
    ['terfi: bitmiş etkinlik', () => payloads.promoteWrites({ club: CLUB }), windowAt(-3 * HOUR_MS, -HOUR_MS)],
    ['terfi: iptal edilmiş etkinlik', () => payloads.promoteWrites({ club: CLUB }), { patch: { [E_LIVE]: { status: 'cancelled', cancelReason: 'x' } } }],
    ['terfi: kontenjan dolu (TST-X14)', () => payloads.promoteWrites({ club: CLUB }), { patch: { [E_LIVE]: { capacity: 2 } } }],
    ['terfi: aynı yazımda bilet kodu', () => { const w = payloads.promoteWrites({ club: CLUB }); return { ...w, rsvp: { ...w.rsvp, data: { ...w.rsvp.data, ticketCode: payloads.TICKET_CODE } } }; }],
    ['terfi: kayıtlı (going) kaydı "terfi"', () => payloads.promoteWrites({ club: CLUB, userId: MEMBER })],
  ])('%s → deny', async (_title, build, seedEdit = NO_EDIT) => {
    const seeded = await seedFixture('base', undefined, seedEdit);
    await assertFails(commit('board', build()));
    expect(await readDoc(E_LIVE)).toMatchObject({ goingCount: 2, waitlistCount: 1, attendedCount: 1 });
    expect((await readDoc(R_LIVE_MEMBER)).status).toBe(seeded[R_LIVE_MEMBER].status);
    expect((await readDoc(R_LIVE_STUDENT)).status).toBe('waitlist');
  });

  test('istemci biçimli kayıt ve etkinlik (null alanların anahtarı yok — W-51): yoklama ve sınırsız etkinlikte terfi geçer', async () => {
    await seedFixture('base', undefined, {
      unset: { [R_LIVE_MEMBER]: ['waitlistAt', 'scannedAt', 'scannedBy'], [E_LIVE]: ['capacity', 'placeText', 'cancelReason', 'coverPath'] },
    });
    await assertSucceeds(commit('board', attend()));
    await assertSucceeds(commit('board', payloads.promoteWrites({ club: CLUB })));
    expect(await readDoc(E_LIVE)).toMatchObject({ goingCount: 3, waitlistCount: 0, attendedCount: 2 });
    // Terfi yalnızca `status` yazar: bekleme anı ve bilet kodu yerinde kalır.
    expect(await readDoc(R_LIVE_STUDENT)).toMatchObject({ status: 'going', ticketCode: 'GU-LVST-2345' });
  });
});
