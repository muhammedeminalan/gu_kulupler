'use strict';
// T-25 — `notifications/{id}` (rules-spec §3.9; PLAN §11.1 satır 11; sözleşme docs/plans/T-25.md §6 a, b, f, g).
//
//  1. Rol × işlem matrisi: `expectations/notifications.json` (okuma / liste yalnızca sahibi; okundu, soft delete,
//     geri al yalnızca sahibi; `event_new` ve `event_reminder` üreticileri; `system` istemciye kapalı; delete yok).
//  2. Tür bazlı create — her açık tür için izinli üretici ve reddedilen üreticiler (sıradan üye, danışman, başka
//     kulübün yöneticisi, süper admin, kendine sahte bildirim, alakasız alıcı, olaysız bildirim). T-30: yönetici
//     kararlarının dört türü (olay belgesi = alıcının hedef üyeliği — W-83).
//  3. Kimlik (W-49): `{type}_{eventKey}_{userId}` biçimi, tekrarlanan olay (yeni anahtar = yeni belge), aynı
//     olayın ikinci `set`'i (= update → ret), birleşim belirsizliği (okunan belgenin alanları karşılaştırılır).
//  6. Güvenlik incelemesi (CD-148): tek seferlik olayda kimlik olayın kimliğidir (duyuru / iptal / başvuru —
//     ikinci anahtarla tekrar ret), `event_new` yayın penceresi, askıdaki / silinmiş kulüp, gizlenmiş duyuru.
//  4. Şema: alan beyaz listesi, `read == false`, ortak alanlar, `refs` beyaz listesi ve W-51 iki biçim.
//  5. Okuma / güncelleme: gelen kutusu sorgusu, markAllRead parçası, üretici yazdığını okuyamaz.
// Parça boyutu ölçümü `budget/fanout_budget.test.js`, indeks `queries.test.js`.
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { Timestamp, collection, doc, getDoc, getDocs, limit, orderBy, query, serverTimestamp, where } = require('firebase/firestore');
const budget = require('../helpers/budget');
const { contextFor, CLUB, OTHER_CLUB } = require('../helpers/contexts');
const { readDoc, rsvpDoc, seedDocs, seedFixture } = require('../helpers/fixtures');
const { runMatrix } = require('../helpers/matrix');
const payloads = require('../helpers/payloads');

const { EVENT_KEY, EVENT_KEY_2, eventKeyOf, notificationCreate, notificationPath } = payloads;
const NO_EDIT = Object.freeze({});
/** `p02` (yazarı u_president) bildirimli duyuruya çevrilir. */
const ANNOUNCED = { patch: { 'posts/p02': { type: 'announcement', pushSent: true } } };
const CANCELLED = { patch: { 'events/e_public': { status: 'cancelled', cancelReason: payloads.CANCEL_REASON } } };

const db = (role) => contextFor(role).firestore();
const commit = (role, writes) => budget.buildBatch(db(role), Object.values(writes)).commit();
const expectWrite = (request, expected) => (expected === 'allow' ? assertSucceeds(request) : assertFails(request));
/** Tek bildirim yazımı; `path` verilmezse dağıtıcı kimliği (türün olay anahtarı — CD-148), `extra` belge alanlarını ezer. */
const one = (type, recipient, refs, { key, sequence, path, extra } = {}) => ({
  n: {
    op: 'set',
    path: path || notificationPath(type, eventKeyOf(type, refs, { key, sequence }), recipient),
    data: notificationCreate(type, recipient, refs, extra),
  },
});
/** Seed biçimli bildirim belgesi (kurallar kapalıyken yazılır). */
const seeded = (userId, extra) => ({
  userId,
  type: 'event_new',
  refs: { clubId: CLUB, eventId: 'e_public' },
  read: false,
  createdAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
  isDeleted: false,
  deletedAt: null,
  deletedBy: null,
  ...extra,
});

runMatrix('notifications.json');

describe('notifications · application_received (başvuran → kulüp yöneticileri; alıcı başına tek batch)', () => {
  const refs = (extra) => ({ clubId: CLUB, applicantId: 'u_pending', ...extra });
  // Satır: [başlık, üretici, alıcı, refs ezmesi, beklenti, veri düzenlemesi?].
  test.each([
    ['bekleyen başvuran → yönetim kurulu üyesi', 'pending', 'u_board', {}, 'allow'],
    ['bekleyen başvuran → başkan', 'pending', 'u_president', {}, 'allow'],
    ['danışman alıcı değildir', 'pending', 'u_advisor', {}, 'deny'],
    ['sıradan üye alıcı değildir (alakasız alıcı)', 'pending', 'u_member', {}, 'deny'],
    ['başka kulübün yöneticisi alıcı değildir', 'pending', 'u_mgr2', {}, 'deny'],
    ['başvurusu olmayan kulüp adına (c02 yöneticisine) yazılamaz', 'pending', 'u_mgr2', { clubId: OTHER_CLUB }, 'deny'],
    ['alıcının üyeliği etkin değil (çıkarılmış yönetici)', 'pending', 'u_board', {}, 'deny', { patch: { 'memberships/c01_u_board': { status: 'removed' } } }],
    ['başvurusu olmayan kullanıcı (olaysız bildirim)', 'student', 'u_board', { applicantId: 'u_student' }, 'deny'],
    ['aktif üye başvuran değildir', 'member', 'u_board', { applicantId: 'u_member' }, 'deny'],
    ['ayrılmış eski üye başvuran değildir', 'former', 'u_board', { applicantId: 'u_former' }, 'deny'],
    ['başkası adına başvuru bildirimi (applicantId ≠ uid)', 'pending', 'u_board', { applicantId: 'u_student' }, 'deny'],
    ['yönetici kendini başvuran gösteremez', 'board', 'u_president', { applicantId: 'u_board' }, 'deny'],
    ['askıdaki başvuran yazamaz (activeUser)', 'pending', 'u_board', {}, 'deny', { patch: { 'users/u_pending': { status: 'suspended' } } }],
  ])('%s → %s', async (_title, role, recipient, extra, expected, edit = NO_EDIT) => {
    await seedFixture('base', undefined, edit);
    await expectWrite(commit(role, one('application_received', recipient, refs(extra))), expected);
  });

  test('birleşim belirsizliği: `c01_u` + `board` = `c01` + `u_board` yolu okunsa da alanlar eşleşmez → ret', async () => {
    await seedFixture('base');
    // Saldırganın `c01_u` kulübünde bekleyen başvurusu var; alıcı yolu memberships/c01_u_board = gerçek yönetici belgesi.
    await seedDocs({ 'memberships/c01_u_u_pending': { clubId: 'c01_u', userId: 'u_pending', status: 'pending', role: 'member', isDeleted: false } });
    await assertFails(commit('pending', one('application_received', 'board', { clubId: 'c01_u', applicantId: 'u_pending' })));
  });

  test('W-63: başvuran kulübün etkin yöneticilerini listeler (listManagers; CD-139 okuma dalı)', async () => {
    await seedFixture('base');
    const managers = query(collection(db('pending'), 'memberships'), where('clubId', '==', CLUB), where('status', '==', 'active'),
      where('role', 'in', ['president', 'board', 'advisor']));
    const snapshot = await assertSucceeds(getDocs(managers));
    expect(snapshot.docs.map((d) => d.data().userId).sort()).toEqual(['u_advisor', 'u_board', 'u_president']);
  });
});

describe('notifications · announcement (yönetici → üyeler; bildirimli duyuru, parçalı)', () => {
  const refs = (extra) => ({ clubId: CLUB, postId: 'p02', ...extra });
  const chunk = (refsValue = refs()) => payloads.fanOutWrites({ type: 'announcement', refs: refsValue, recipients: ['u_member', 'u_board', 'u_susp'] });
  test.each([
    ['duyurunun yazarı yönetici (başkan) üç alıcıya tek batch', 'president', chunk(), 'allow', ANNOUNCED],
    ['bildirimsiz duyuru (pushSent false)', 'president', chunk(), 'deny', { patch: { 'posts/p02': { type: 'announcement' } } }],
    ['duyuru olmayan gönderi', 'president', chunk(), 'deny', { patch: { 'posts/p02': { pushSent: true } } }],
    ['silinmiş duyuru', 'president', chunk(), 'deny', { patch: { 'posts/p02': { type: 'announcement', pushSent: true, isDeleted: true, deletedBy: 'u_president' } } }],
    ['olmayan gönderi (olaysız bildirim)', 'president', chunk(refs({ postId: 'p_missing' })), 'deny', ANNOUNCED],
    ['yazarı olmayan yönetici (yönetim kurulu)', 'board', chunk(), 'deny', ANNOUNCED],
    ['sıradan üye', 'member', chunk(), 'deny', ANNOUNCED],
    ['danışman', 'advisor', chunk(), 'deny', ANNOUNCED],
    ['süper admin', 'super', chunk(), 'deny', ANNOUNCED],
    ['başka kulübün yöneticisi kendi kulübü adına', 'otherManager', chunk(refs({ clubId: OTHER_CLUB })), 'deny', ANNOUNCED],
    ['refs.clubId gönderinin kulübü değil', 'president', chunk(refs({ clubId: OTHER_CLUB })), 'deny', ANNOUNCED],
    ['refs.postId eksik', 'president', chunk({ clubId: CLUB }), 'deny', ANNOUNCED],
  ])('%s → %s', async (_title, role, writes, expected, edit) => {
    await seedFixture('base', undefined, edit);
    await expectWrite(commit(role, writes), expected);
  });
});

describe('notifications · event_new / event_cancelled (yönetici → üyeler / ilgi eşleşmesi / katılımcılar)', () => {
  const refs = (extra) => ({ clubId: CLUB, eventId: 'e_public', ...extra });
  test.each([
    ['event_new: yayındaki etkinlik', 'board', 'event_new', 'u_member', refs(), 'allow'],
    ['event_new: ilgi eşleşmesiyle üye olmayan alıcı (alıcı doğrulanmaz — K-J)', 'president', 'event_new', 'u_student', refs(), 'allow'],
    ['event_new: taslak etkinlik', 'board', 'event_new', 'u_member', refs({ eventId: 'e_draft' }), 'deny'],
    ['event_new: iptal edilmiş etkinlik', 'board', 'event_new', 'u_member', refs(), 'deny', CANCELLED],
    ['event_new: silinmiş etkinlik', 'board', 'event_new', 'u_member', refs(), 'deny', { patch: { 'events/e_public': { isDeleted: true, deletedBy: 'u_board' } } }],
    ['event_new: olmayan etkinlik (olaysız bildirim)', 'board', 'event_new', 'u_member', refs({ eventId: 'e_missing' }), 'deny'],
    ['event_new: başka kulübün yöneticisi kendi kulübü adına', 'otherManager', 'event_new', 'u_member', refs({ clubId: OTHER_CLUB }), 'deny'],
    ['event_new: askıdaki yönetici', 'board', 'event_new', 'u_member', refs(), 'deny', { patch: { 'users/u_board': { status: 'suspended' } } }],
    ['event_cancelled: iptal edilmiş etkinlik', 'board', 'event_cancelled', 'u_member', refs(), 'allow', CANCELLED],
    ['event_cancelled: yayındaki etkinlik (iptal olmadan)', 'board', 'event_cancelled', 'u_member', refs(), 'deny'],
    ['event_cancelled: sıradan üye', 'member', 'event_cancelled', 'u_board', refs(), 'deny', CANCELLED],
    ['event_cancelled: danışman', 'advisor', 'event_cancelled', 'u_member', refs(), 'deny', CANCELLED],
  ])('%s → %s', async (_title, role, type, recipient, refsValue, expected, edit = NO_EDIT) => {
    await seedFixture('base', undefined, edit);
    await expectWrite(commit(role, one(type, recipient, refsValue)), expected);
  });
});

describe('notifications · waitlist_promoted (kritik: terfi batch\'iyle aynı işlemde)', () => {
  test('yönetici terfi + bildirim tek batch\'te geçer; bildirim yalnızca terfi edilene yazılır', async () => {
    await seedFixture('base');
    await assertSucceeds(commit('board', payloads.promoteNotifyWrites({ club: CLUB })));
    expect(await readDoc(notificationPath('waitlist_promoted', EVENT_KEY, 'u_student'))).toMatchObject({ userId: 'u_student', read: false });
  });

  test.each([
    ['terfisiz bildirim (olaysız)', 'board', () => one('waitlist_promoted', 'u_student', { clubId: CLUB, eventId: 'e_live' })],
    ['terfi edilmeyen alıcı (alakasız)', 'board', () => payloads.promoteNotifyWrites({ club: CLUB, recipient: 'u_member' })],
    ['danışman (terfi de reddedilir)', 'advisor', () => payloads.promoteNotifyWrites({ club: CLUB })],
    ['başka kulübün yöneticisi kendi kulübü adına', 'otherManager', () => ({
      n: one('waitlist_promoted', 'u_student', { clubId: OTHER_CLUB, eventId: 'e_live' }).n,
    })],
  ])('%s → deny', async (_title, role, writes) => {
    await seedFixture('base');
    await assertFails(commit(role, writes()));
  });

  test('birleşim belirsizliği: `e` + `live_u_student` = `e_live` + `u_student` yolu okunsa da alanlar eşleşmez → ret', async () => {
    await seedFixture('base');
    const writes = payloads.promoteWrites({ club: CLUB });
    const forged = one('waitlist_promoted', 'live_u_student', { clubId: CLUB, eventId: 'e' }).n;
    await assertFails(commit('board', { ...writes, forged }));
  });
});

describe('notifications · event_reminder (cihaz kendi belgesini yazar — CD-44)', () => {
  const refs = { clubId: CLUB, eventId: 'e_public' };
  test.each([
    ['başkasının hatırlatıcısı (kendine değil)', 'u_member', payloads.reminderPath('e_public', 'u_member')],
    ['kimlik başka etkinliği gösteriyor', 'u_student', payloads.reminderPath('e_members', 'u_student')],
    ['dağıtıcı biçimli kimlik (tam eşitlik)', 'u_student', notificationPath('event_reminder', EVENT_KEY, 'u_student')],
    ['başkasının kimliğine kendi adıyla', 'u_student', payloads.reminderPath('e_public', 'u_member')],
  ])('%s → deny', async (_title, recipient, path) => {
    await seedFixture('base');
    await assertFails(commit('student', one('event_reminder', recipient, refs, { path })));
  });

  test('ikinci yazım (belge var) update sayılır ve reddedilir; createSelf önce okur (olmayan kendi belgesi boş döner)', async () => {
    // T-45 A5-01: `u_member`'ın e_public katılım kaydı var (fixture); `u_student`'ın yok.
    await seedFixture('base');
    const path = payloads.reminderPath('e_public', 'u_member');
    expect((await assertSucceeds(getDoc(doc(db('member'), path)))).exists()).toBe(false);
    await assertSucceeds(commit('member', one('event_reminder', 'u_member', refs, { path })));
    await assertFails(commit('member', one('event_reminder', 'u_member', refs, { path })));
    expect((await assertSucceeds(getDoc(doc(db('member'), path)))).data()).toMatchObject({ type: 'event_reminder', userId: 'u_member' });
  });

  // T-45 A5-01: hatırlatıcı yazarın KENDİ katılım kaydına bağlıdır (`rsvps/{eventId}_{uid}`; userId / eventId /
  // clubId eşit, durum aranmaz). Önceden yalnızca kimlik eşitliği aranıyordu: kulübe üye olmayan etkin bir hesap
  // uydurma eventId'lerle sınırsız belge yazıp her biri için push tetikleyicisini (makbuz create + update) çalıştırabiliyordu.
  const RSVP_EDIT = (eventId, uid, extra) => ({ [payloads.rsvpPath(eventId, uid)]: { ...rsvpDoc(eventId, uid, 'going'), ...extra } });
  test.each([
    ['katılım kaydı yok (student · e_public)', 'student', 'u_student', { clubId: CLUB, eventId: 'e_public' }, null, 'deny'],
    ['uydurma etkinlik + kulüp (kayıt yok)', 'student', 'u_student', { clubId: 'no_such_club', eventId: 'fake_1' }, null, 'deny'],
    ['refs.clubId kaydın kulübü değil', 'member', 'u_member', { clubId: OTHER_CLUB, eventId: 'e_public' }, null, 'deny'],
    ['kayıt alanı başka kullanıcıyı gösteriyor (kimlik birleşimi belirsizliği)', 'student', 'u_student', { clubId: CLUB, eventId: 'e_members' },
      RSVP_EDIT('e_members', 'u_student', { userId: 'u_member' }), 'deny'],
    ['kayıt alanı başka etkinliği gösteriyor', 'student', 'u_student', { clubId: CLUB, eventId: 'e_members' },
      RSVP_EDIT('e_members', 'u_student', { eventId: 'e_public' }), 'deny'],
    ['going (member · e_live)', 'member', 'u_member', { clubId: CLUB, eventId: 'e_live' }, null, 'allow'],
    ['waitlist (student · e_live)', 'student', 'u_student', { clubId: CLUB, eventId: 'e_live' }, null, 'allow'],
    ['attended (board · e_live — yoklamadan sonra dokunuş)', 'board', 'u_board', { clubId: CLUB, eventId: 'e_live' }, null, 'allow'],
    ['cancelled (iptal edilen kayıt soft kalır — dokunuş / açılış senkronu yine yazar)', 'student', 'u_student', { clubId: CLUB, eventId: 'e_members' },
      RSVP_EDIT('e_members', 'u_student', { status: 'cancelled', ticketCode: null }), 'allow'],
  ])('kendi katılım kaydı: %s → %s', async (_title, role, uid, reminderRefs, extraDocs, expected) => {
    await seedFixture('base');
    if (extraDocs) await seedDocs(extraDocs);
    const path = payloads.reminderPath(reminderRefs.eventId, uid);
    await expectWrite(commit(role, one('event_reminder', uid, reminderRefs, { path })), expected);
    if (expected === 'deny') expect(await readDoc(path)).toBeNull();
  });

  // PoC 450 belgelik batch'ti (eski kuralda geçiyordu). Yeni kuralda her belgenin başarısız `get`'i istek
  // bütçesini doldurur: 450'de emülatör "1000 ifade" hatası döner (permission-denied değil — SDK yeniden dener);
  // ret davranışı küçük batch'le sınanır.
  test('saldırı yükü: tek batch\'te uydurma eventId\'li hatırlatıcılar → deny (hiçbir belge yazılmaz)', async () => {
    await seedFixture('base');
    const writes = {};
    for (let i = 0; i < 5; i++) {
      const fake = { clubId: 'no_such_club', eventId: `fake_${i}` };
      writes[`n${i}`] = one('event_reminder', 'u_student', fake, { path: payloads.reminderPath(fake.eventId, 'u_student') }).n;
    }
    await assertFails(commit('student', writes));
    expect(await readDoc(payloads.reminderPath('fake_0', 'u_student'))).toBeNull();
  });

  test('başka tür `event_reminder_…` kimliğini işgal edemez', async () => {
    await seedFixture('base');
    await assertFails(commit('board', one('event_new', 'u_member', refs, { path: payloads.reminderPath('e_public', 'u_member') })));
  });
});

// T-30 (W-83): kritik yönetici bildirimleri — olay belgesi alıcının hedef üyeliğidir (aynı işlemde doğru geçiş,
// `decidedBy == uid()`, `decidedAt` / `updatedAt == request.time`); kimlik rastgele olay anahtarı (`keyedIdOk`).
describe('notifications · yönetici kararları (application_approved / rejected, removed_from_club, role_changed — T-30)', () => {
  const approve = (uid, extra) => payloads.approveWrites({ club: CLUB, uid, ...extra });
  const notice = (type, recipient, refs, key = EVENT_KEY) => one(type, recipient, refs, { key });
  /** Taban işlemin bildirimini değiştirir (alıcı / tür / refs / kimlik). */
  const swap = (writes, type, recipient, refs, key) => ({ ...drop(writes, 'notification'), ...notice(type, recipient, refs, key) });
  const drop = (writes, name) => Object.fromEntries(Object.entries(writes).filter(([k]) => k !== name));
  // Satır: [başlık, aktör, yazımlar, beklenti, veri düzenlemesi?].
  test.each([
    ['onay → başvurana application_approved', 'board', () => approve('u_board'), 'allow'],
    ['red → başvurana application_rejected', 'president', () => payloads.rejectWrites({ club: CLUB, uid: 'u_president' }), 'allow'],
    ['çıkarma → çıkarılana removed_from_club', 'board', () => payloads.removeWrites({ club: CLUB, uid: 'u_board' }), 'allow'],
    ['süper adminin çıkarması → removed_from_club', 'super', () => payloads.removeWrites({ club: CLUB, uid: 'u_super' }), 'allow'],
    ['rol → role_changed (refs.role yeni rol)', 'president', () => payloads.roleWrites({ club: CLUB, uid: 'u_president' }), 'allow'],
    ['devir → iki role_changed (yeni başkan + eski başkanın kendisi)', 'president', () => payloads.transferWrites({ club: CLUB, uid: 'u_president' }), 'allow'],
    ['onay bildirimi başka alıcıya (hedef üyelik değil)', 'board', () => swap(approve('u_board'), 'application_approved', 'u_member', { clubId: CLUB }), 'deny'],
    ['onayda ret bildirimi (yanlış tür)', 'board', () => swap(approve('u_board'), 'application_rejected', 'u_pending', { clubId: CLUB }), 'deny'],
    ['onay bildirimi kararsız (üyelik yazılmadı)', 'board', () => notice('application_approved', 'u_pending', { clubId: CLUB }), 'deny'],
    ['onay bildirimi tek seferlik kimlikle (rastgele anahtar değil)', 'board', () => swap(approve('u_board'), 'application_approved', 'u_pending', { clubId: CLUB }, 'u_pending'), 'deny'],
    ['onay bildirimi refs fazladan alan (role)', 'board', () => swap(approve('u_board'), 'application_approved', 'u_pending', { clubId: CLUB, role: 'member' }), 'deny'],
    ['onay bildirimi başka kulüp refs ile', 'board', () => swap(approve('u_board'), 'application_approved', 'u_pending', { clubId: OTHER_CLUB }), 'deny'],
    ['rol bildirimi yanlış rol (refs.role ≠ yeni rol)', 'president', () => swap(payloads.roleWrites({ club: CLUB, uid: 'u_president' }), 'role_changed', 'u_member', { clubId: CLUB, role: 'president' }), 'deny'],
    ['rol bildirimi rol değişmeden', 'president', () => notice('role_changed', 'u_board', { clubId: CLUB, role: 'board' }), 'deny'],
    ['danışman karar bildirimi yazamaz (Q-09; seed kararı aynı anda bile)', 'advisor', () => notice('application_approved', 'u_pending', { clubId: CLUB }), 'deny'],
    ['başka kulübün yöneticisi', 'otherManager', () => notice('removed_from_club', 'u_member', { clubId: CLUB }), 'deny'],
  ])('%s → %s', async (_title, role, build, expected, edit = NO_EDIT) => {
    await seedFixture('base', undefined, edit);
    await expectWrite(commit(role, build()), expected);
  });
});

// `report_resolved` T-37'de açıldı (yalnızca süper admin, grup anahtarı — rules/admin.test.js).
describe('notifications · istemciye kapalı türler (new_report yalnızca sunucu — T-42 `notifyNewReport`, CD-165; system Admin SDK)', () => {
  test.each([
    ['new_report', 'member', 'u_super', { reportId: 'u_member_post_p01' }],
    ['new_report', 'super', 'u_member', { reportId: 'post_p01' }],
    ['system', 'super', 'u_member', { textKey: 'welcome' }],
    ['unknown_type', 'board', 'u_member', { clubId: CLUB, eventId: 'e_public' }],
  ])('%s (%s) → deny', async (type, role, recipient, refs) => {
    await seedFixture('base');
    await assertFails(commit(role, one(type, recipient, refs)));
  });
});

describe('notifications · şema (alan beyaz listesi, ortak alanlar, refs — W-51)', () => {
  const refs = { clubId: CLUB, eventId: 'e_public' };
  const SEED_NULLS = { postId: null, applicantId: null, reportId: null, role: null, textKey: null };
  // Satır: [başlık, belge alanı ezmesi, beklenti].
  test.each([
    ['istemci biçimi (yalnızca dolu refs)', {}, 'allow'],
    ['seed biçimi: zorunlu olmayan refs açık null (W-51)', { refs: { ...refs, ...SEED_NULLS } }, 'allow'],
    ['okunmuş başlayamaz (read true)', { read: true }, 'deny'],
    ['beyaz liste dışı alan (metin yazılmaz)', { title: 'Yeni etkinlik' }, 'deny'],
    ['aktör alanı yok', { actorId: 'u_board' }, 'deny'],
    ['refs beyaz liste dışı anahtar', { refs: { ...refs, url: 'https://example.com' } }, 'deny'],
    ['refs zorunlu olmayan dolu anahtar', { refs: { ...refs, postId: 'p01' } }, 'deny'],
    ['refs zorunlu anahtar null', { refs: { clubId: CLUB, eventId: null } }, 'deny'],
    ['refs zorunlu anahtar boş dizgi', { refs: { clubId: CLUB, eventId: '' } }, 'deny'],
    ['refs dizgi değil', { refs: { clubId: CLUB, eventId: 7 } }, 'deny'],
    ['refs nesne değil', { refs: 'e_public' }, 'deny'],
    ['istemci saati (createdAt)', { createdAt: Timestamp.now() }, 'deny'],
    ['silinmiş başlayamaz', { isDeleted: true }, 'deny'],
  ])('%s → %s', async (_title, extra, expected) => {
    await seedFixture('base');
    await expectWrite(commit('board', one('event_new', 'u_member', refs, { extra })), expected);
  });

  test('refs anahtarı hiç yok → ret', async () => {
    await seedFixture('base');
    const writes = one('event_new', 'u_member', refs);
    delete writes.n.data.refs;
    await assertFails(commit('board', writes));
  });
});

describe('notifications · kimlik (W-49: `{type}_{eventKey}_{userId}`, olay başına rastgele anahtar)', () => {
  const refs = { clubId: CLUB, eventId: 'e_public' };
  // Satır: [başlık, yol, beklenti].
  test.each([
    ['20 karakter alfasayısal anahtar', `notifications/event_new_${EVENT_KEY}_u_member`, 'allow'],
    ['19 karakter anahtar', `notifications/event_new_${EVENT_KEY.slice(1)}_u_member`, 'deny'],
    ['21 karakter anahtar', `notifications/event_new_${EVENT_KEY}x_u_member`, 'deny'],
    ['anahtarda alt çizgi', `notifications/event_new_AbCdEfGhIj_lMnOpQr01_u_member`, 'deny'],
    ['anahtarda tire', `notifications/event_new_AbCdEfGhIj-lMnOpQr01_u_member`, 'deny'],
    ['sonek başka alıcı', `notifications/event_new_${EVENT_KEY}_u_board`, 'deny'],
    ['önek başka tür', `notifications/event_cancelled_${EVENT_KEY}_u_member`, 'deny'],
    ['serbest kimlik', 'notifications/n_new', 'deny'],
  ])('%s → %s', async (_title, path, expected) => {
    await seedFixture('base');
    await expectWrite(commit('board', one('event_new', 'u_member', refs, { path })), expected);
  });

  test('tekrarlanan olay yeni anahtarla yeni belge yazar; aynı olayın ikinci set\'i (update) reddedilir', async () => {
    await seedFixture('base');
    await assertSucceeds(commit('board', one('event_new', 'u_member', refs)));
    // Olayın tekrarı (yeniden yayın): yeni anahtar → yeni belge, başka yönetici de yazabilir.
    await assertSucceeds(commit('president', one('event_new', 'u_member', refs, { key: EVENT_KEY_2 })));
    // Aynı olayın (aynı anahtar) kesinleşmiş parçası yeniden gönderilirse: var olan belge → update → ret.
    await assertFails(commit('board', one('event_new', 'u_member', refs)));
    await assertFails(commit('president', one('event_new', 'u_member', refs, { key: EVENT_KEY_2 })));
    expect(await readDoc(notificationPath('event_new', EVENT_KEY, 'u_member'))).toMatchObject({ userId: 'u_member', read: false });
    expect(await readDoc(notificationPath('event_new', EVENT_KEY_2, 'u_member'))).toMatchObject({ userId: 'u_member', read: false });
  });
});

describe('notifications · güvenlik incelemesi (CD-148: olaya bağlı tek seferlik kimlik, yayın penceresi, clubLive)', () => {
  const eventRefs = { clubId: CLUB, eventId: 'e_public' };
  const postRefs = { clubId: CLUB, postId: 'p02' };
  const appRefs = { clubId: CLUB, applicantId: 'u_pending' };
  const SUSPENDED = { 'clubs/c01': { status: 'suspended' } };
  const DELETED_CLUB = { 'clubs/c01': { isDeleted: true, deletedBy: 'u_super' } };
  const HIDDEN = { 'posts/p02': { isHidden: true, hiddenBy: 'u_super' } };
  const OLD_PUBLISH = { 'events/e_public': { publishedAt: Timestamp.fromMillis(Date.now() - 24 * 60 * 60 * 1000) } };
  const patchOf = (...parts) => ({ patch: Object.assign({}, ...parts) });

  // Satır: [başlık, üretici, tür, alıcı, refs, beklenti, veri düzenlemesi].
  test.each([
    ['askıdaki kulüpte duyuru', 'president', 'announcement', 'u_member', postRefs, 'deny', patchOf(ANNOUNCED.patch, SUSPENDED)],
    ['askıdaki kulüpte event_new', 'board', 'event_new', 'u_member', eventRefs, 'deny', patchOf(SUSPENDED)],
    ['askıdaki kulüpte event_cancelled', 'board', 'event_cancelled', 'u_member', eventRefs, 'deny', patchOf(CANCELLED.patch, SUSPENDED)],
    ['silinmiş kulüpte event_new', 'board', 'event_new', 'u_member', eventRefs, 'deny', patchOf(DELETED_CLUB)],
    ['gizlenmiş duyuru yeniden itilemez', 'president', 'announcement', 'u_member', postRefs, 'deny', patchOf(ANNOUNCED.patch, HIDDEN)],
    ['eski yayının event_new bildirimi (pencere dışı)', 'board', 'event_new', 'u_member', eventRefs, 'deny', patchOf(OLD_PUBLISH)],
    ['taze yayının event_new bildirimi (pencere içi)', 'board', 'event_new', 'u_member', eventRefs, 'allow', patchOf({})],
  ])('%s → %s', async (_title, role, type, recipient, refs, expected, edit) => {
    await seedFixture('base', undefined, edit);
    await expectWrite(commit(role, one(type, recipient, refs)), expected);
  });

  // Tek seferlik olaylar: kimlik olayın kendi kimliğidir; rastgele anahtarla (tekrar itme) yazılamaz.
  test.each([
    ['duyuru rastgele anahtarla', 'president', 'announcement', postRefs, ANNOUNCED],
    ['iptal rastgele anahtarla', 'board', 'event_cancelled', eventRefs, CANCELLED],
    ['başvuru rastgele anahtarla', 'pending', 'application_received', appRefs, NO_EDIT],
  ])('%s → deny', async (_title, role, type, refs, edit) => {
    await seedFixture('base', undefined, edit);
    const recipient = type === 'application_received' ? 'u_board' : 'u_member';
    await assertFails(commit(role, one(type, recipient, refs, { key: EVENT_KEY })));
  });

  test('aynı duyuru / iptal ikinci kez itilemez (aynı kimlik = update → ret)', async () => {
    await seedFixture('base', undefined, patchOf(ANNOUNCED.patch));
    await assertSucceeds(commit('president', one('announcement', 'u_member', postRefs)));
    await assertFails(commit('president', one('announcement', 'u_member', postRefs)));
    expect(await readDoc('notifications/announcement_p02_u_member')).toMatchObject({ userId: 'u_member', read: false });
  });

  test('bekleyen başvuran yöneticiye başvuru başına tek bildirim yazar; başka sıra ret; yeniden başvuru yeni belge', async () => {
    await seedFixture('base');
    await assertSucceeds(commit('pending', one('application_received', 'u_board', appRefs)));
    expect(await readDoc('notifications/application_received_c01_u_pending_0_u_board')).toMatchObject({ userId: 'u_board' });
    // Spam: aynı başvuru ikinci kez (aynı kimlik) ve uydurma sıra (priorCount ≠ 1) → ret.
    await assertFails(commit('pending', one('application_received', 'u_board', appRefs)));
    await assertFails(commit('pending', one('application_received', 'u_board', appRefs, { sequence: 1 })));
    // Yeniden başvuru (M3/M4: priorCount +1) yeni olaydır.
    await seedFixture('base', undefined, { patch: { 'memberships/c01_u_pending': { priorCount: 1 } } });
    await assertSucceeds(commit('pending', one('application_received', 'u_board', appRefs, { sequence: 1 })));
  });
});

describe('notifications · okuma ve güncelleme (sahibi)', () => {
  const MINE = notificationPath('event_new', EVENT_KEY, 'u_member');
  const MINE_DELETED = notificationPath('event_new', EVENT_KEY_2, 'u_member');
  const BOARDS = notificationPath('event_new', EVENT_KEY, 'u_board');
  const seedInbox = async () => {
    await seedFixture('base');
    await seedDocs({
      [MINE]: seeded('u_member'),
      [MINE_DELETED]: seeded('u_member', { isDeleted: true, deletedAt: serverTimestamp(), deletedBy: 'u_member' }),
      [BOARDS]: seeded('u_board'),
    });
  };

  test('watchInbox: userId == uid, isDeleted == false, createdAt ↓, limit — yalnızca kendi silinmemiş bildirimleri', async () => {
    await seedInbox();
    const inbox = query(collection(db('member'), 'notifications'), where('userId', '==', 'u_member'), where('isDeleted', '==', false),
      orderBy('createdAt', 'desc'), limit(100));
    const snapshot = await assertSucceeds(getDocs(inbox));
    expect(snapshot.docs.map((d) => d.id).sort()).toEqual([MINE.split('/')[1], 'n01'].sort());
    // Silinmiş kendi bildirimi tekil okunur (Geri al toast'ı).
    await assertSucceeds(getDoc(doc(db('member'), MINE_DELETED)));
  });

  test('markAllRead parçası: kendi bildirimleri tek batch\'te okundu; başkasının belgesi batch\'i düşürür', async () => {
    await seedInbox();
    const read = (path) => ({ op: 'update', path, data: payloads.notificationRead() });
    await assertSucceeds(commit('member', { a: read('notifications/n01'), b: read(MINE) }));
    await assertFails(commit('member', { a: read(MINE), b: read(BOARDS) }));
    expect(await readDoc(BOARDS)).toMatchObject({ read: false });
  });

  test('üretici yazdığı bildirimi okuyamaz ve güncelleyemez (yalnızca alıcı)', async () => {
    await seedFixture('base');
    await assertSucceeds(commit('board', one('event_new', 'u_member', { clubId: CLUB, eventId: 'e_public' })));
    await assertFails(getDoc(doc(db('board'), MINE)));
    await assertFails(commit('board', { a: { op: 'update', path: MINE, data: payloads.notificationRead() } }));
    await assertSucceeds(getDoc(doc(db('member'), MINE)));
  });
});
