'use strict';
// T-15 — sayaç tutarlılığı: `clubs.memberCount` (rules-spec §4; PLAN §11.2b `canBumpMemberCount`, CD-41).
// T-19 (`likeCount`, `commentCount`, `announcementCounters.count`) ve T-22 (`goingCount`, `waitlistCount`,
// `attendedCount`) kendi `describe` bloklarını bu dosyaya ekler.
//
// İki yönlü doğrulama: üyelik dalı `counterDelta` ile sayacın aynı batch'te tam ±1 oynadığını, kulüp
// dalı oturumun BU kulüpteki üyeliğinin (`memberships/{clubId}_{uid}`) aynı batch'te doğru geçişi
// yaptığını görür. Yol oturumdan türetilir; kulüp belgesine YAZILMAZ (CD-137 madde 8q).
//  1. Meşru batch'ler: M2 anında katıl +1 · M3 yeniden katıl +1 · M8 ayrıl −1.
//  2. ±1 dışı delta, ters yön, çift yazım, mutlak değer → ret.
//  3. Eşlik yok: sayaçsız üyelik geçişi ve üyelik geçişi olmayan sayaç yazımı → ret.
//  4. Sızıntı: kulüp belgesi (doğrulanmış herkese açık) kimin katıldığını / ayrıldığını taşımaz;
//     `lastMembershipRef` yazan sayaç yükü reddedilir.
//  5. Sayaç dalı başka alan taşıyamaz; yönetici ve süper admin aktörü T-30 / T-37'ye kadar kapalıdır.
//  6. Null alanın iki biçimi (W-51): null alanlarının anahtarı olmayan kulüp belgesi.
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, getDoc, increment } = require('firebase/firestore');
const budget = require('../helpers/budget');
const { contextFor, CLUB, OTHER_CLUB } = require('../helpers/contexts');
const { readDoc, seedFixture } = require('../helpers/fixtures');
const payloads = require('../helpers/payloads');

const STUDENT = 'u_student';
const MEMBER = 'u_member';
const CLUB_PATH = `clubs/${CLUB}`;
const OTHER_CLUB_PATH = `clubs/${OTHER_CLUB}`;
const M_STUDENT = payloads.membershipPath(CLUB, STUDENT);
const M_MEMBER = payloads.membershipPath(CLUB, MEMBER);
const INSTANT = { patch: { [CLUB_PATH]: { approvalRequired: false } } };
const NO_EDIT = Object.freeze({});
/** Temel veri kümesinde c01'in aktif, danışman olmayan üye sayısı. */
const BASE_COUNT = 5;

const commit = (role, writes) => budget.buildBatch(contextFor(role).firestore(), Object.values(writes)).commit();
const expectWrite = (request, expected) => (expected === 'allow' ? assertSucceeds(request) : assertFails(request));
const drop = (writes, name) => Object.fromEntries(Object.entries(writes).filter(([key]) => key !== name));
const clubWrite = (data, path = CLUB_PATH) => ({ op: 'update', path, data });
const bump = (delta, extra) => ({ memberCount: increment(delta), ...payloads.baseUpdate(), ...extra });

const join = () => payloads.joinWrites({ club: CLUB, uid: STUDENT, email: payloads.emailOf('student') });
const leave = () => payloads.leaveWrites({ club: CLUB, uid: MEMBER });

describe('memberCount · meşru batch\'ler (±1; eşlik eden üyelik oturumdan türetilir)', () => {
  test('M2 instant join single batch passes: memberCount +1, sayaç üyelikle aynı anda yazılır', async () => {
    await seedFixture('base', undefined, INSTANT);
    await assertSucceeds(commit('student', join()));
    const club = await readDoc(CLUB_PATH);
    expect(club.memberCount).toBe(BASE_COUNT + 1);
    expect(club.updatedAt.toMillis()).toBe((await readDoc(M_STUDENT)).updatedAt.toMillis());
  });

  test('istemci biçimli kulüp belgesi (null alanların anahtarı yok — W-51) sayacı kabul eder', async () => {
    await seedFixture('base', undefined, { ...INSTANT, unset: { [CLUB_PATH]: ['lastMembershipRef', 'logoPath', 'coverPath', 'pinnedPostId', 'advisor', 'suspendReason'] } });
    await assertSucceeds(commit('student', join()));
    const club = await readDoc(CLUB_PATH);
    expect(club.memberCount).toBe(BASE_COUNT + 1);
    expect(club).not.toHaveProperty('lastMembershipRef');
  });

  test('M3 yeniden katılım (left → active) +1', async () => {
    await seedFixture('base', undefined, INSTANT);
    await assertSucceeds(commit('former', payloads.reapplyWrites({ club: CLUB, uid: 'u_former', status: 'active' })));
    expect((await readDoc(CLUB_PATH)).memberCount).toBe(BASE_COUNT + 1);
  });

  test('sızıntı (CD-137 8q): katılım / ayrılma sonrası kulüp belgesi üyenin kimliğini taşımaz', async () => {
    await seedFixture('base', undefined, INSTANT);
    await assertSucceeds(commit('student', join()));
    await assertSucceeds(commit('member', leave()));

    // Kulüp belgesini doğrulanmış herkes okur — burada c01'de üyeliği olmayan başka kulüp yöneticisi.
    const club = (await assertSucceeds(getDoc(doc(contextFor('otherManager').firestore(), CLUB_PATH)))).data();
    expect(club.lastMembershipRef).toBeNull();
    const serialized = JSON.stringify(club);
    for (const uid of [STUDENT, MEMBER]) expect(serialized).not.toContain(uid);
    // Aynı bağlam o üyeliklerin kendisini de okuyamaz (üye listesi üye olmayana kapalı).
    await assertFails(getDoc(doc(contextFor('otherManager').firestore(), M_MEMBER)));
  });

  test('M8 leave −1; ayrılan üye onaysız kulübe yeniden katılınca +1 (sayaç başa döner)', async () => {
    await seedFixture('base', undefined, INSTANT);
    await assertSucceeds(commit('member', leave()));
    expect((await readDoc(CLUB_PATH)).memberCount).toBe(BASE_COUNT - 1);

    await assertSucceeds(commit('member', payloads.reapplyWrites({ club: CLUB, uid: MEMBER, status: 'active' })));
    expect((await readDoc(CLUB_PATH)).memberCount).toBe(BASE_COUNT);
    expect(await readDoc(M_MEMBER)).toMatchObject({ status: 'active', role: 'member', priorCount: 1 });
  });

  test('başvuru (M1), iptal (M7) ve yeniden başvuru (M3 → pending) sayaca dokunmaz', async () => {
    await seedFixture('base');
    await assertSucceeds(commit('student', payloads.applyWrites({ club: CLUB, uid: STUDENT, email: payloads.emailOf('student') })));
    await assertSucceeds(commit('student', { m: { op: 'update', path: M_STUDENT, data: { status: 'cancelled', ...payloads.baseUpdate() } } }));
    await assertSucceeds(commit('student', payloads.reapplyWrites({ club: CLUB, uid: STUDENT, status: 'pending' })));
    expect(await readDoc(CLUB_PATH)).toMatchObject({ memberCount: BASE_COUNT, lastMembershipRef: null });
  });
});

describe('memberCount · katılım (M2) — ±1 dışı ve eşliksiz yazımlar', () => {
  // Satır: [başlık, yazımları değiştiren işlev]. Taban: onaysız kulüpte öğrencinin katılım batch'i.
  test.each([
    ['sayaç yazımı yok (eşlik yok)', (w) => drop(w, 'club')],
    ['delta +2', (w) => ({ ...w, club: clubWrite(bump(2)) })],
    ['delta 0 (yalnızca updatedAt)', (w) => ({ ...w, club: clubWrite(payloads.baseUpdate()) })],
    ['ters yön: katılımda −1', (w) => ({ ...w, club: clubWrite(bump(-1)) })],
    ['mutlak değer (memberCount: 100)', (w) => ({ ...w, club: clubWrite({ memberCount: 100, ...payloads.baseUpdate() }) })],
    ['aynı batch\'te sayaç iki kez (+1, +1)', (w) => ({ ...w, again: clubWrite(bump(1)) })],
    ['sayaçla birlikte lastMembershipRef (üyelik yolu herkese açık belgeye yazılamaz — CD-137 8q)', (w) => ({ ...w, club: clubWrite(bump(1, { lastMembershipRef: M_STUDENT })) })],
    ['sayaçla birlikte başka alan (summary)', (w) => ({ ...w, club: clubWrite(bump(1, { summary: 'x' })) })],
    ['sayaçla birlikte approvalRequired', (w) => ({ ...w, club: clubWrite(bump(1, { approvalRequired: true })) })],
    ['sayaç updatedAt taşımıyor', (w) => ({ ...w, club: clubWrite({ memberCount: increment(1) }) })],
    ['başka kulübün sayacı da oynatılıyor (c02\'de üyelik geçişi yok)', (w) => ({ ...w, other: clubWrite(bump(1), OTHER_CLUB_PATH) })],
  ])('%s → deny', async (_title, mutate) => {
    await seedFixture('base', undefined, INSTANT);
    await assertFails(commit('student', mutate(join())));
    expect(await readDoc(M_STUDENT)).toBeNull();
    expect((await readDoc(CLUB_PATH)).memberCount).toBe(BASE_COUNT);
    expect((await readDoc(OTHER_CLUB_PATH)).memberCount).toBe(1);
  });
});

describe('memberCount · ayrılma (M8) — ±1 dışı ve eşliksiz yazımlar', () => {
  test.each([
    ['sayaç yazımı yok (eşlik yok)', (w) => drop(w, 'club')],
    ['delta −2', (w) => ({ ...w, club: clubWrite(bump(-2)) })],
    ['ters yön: ayrılırken +1', (w) => ({ ...w, club: clubWrite(bump(1)) })],
    ['sayaçla birlikte lastMembershipRef (CD-137 8q)', (w) => ({ ...w, club: clubWrite(bump(-1, { lastMembershipRef: M_MEMBER })) })],
    ['başka kulübün sayacı düşürülüyor', (w) => ({ ...w, other: clubWrite(bump(-1), OTHER_CLUB_PATH) })],
  ])('%s → deny', async (_title, mutate) => {
    await seedFixture('base');
    await assertFails(commit('member', mutate(leave())));
    expect((await readDoc(M_MEMBER)).status).toBe('active');
    expect((await readDoc(CLUB_PATH)).memberCount).toBe(BASE_COUNT);
    expect((await readDoc(OTHER_CLUB_PATH)).memberCount).toBe(1);
  });
});

describe('memberCount · üyelik geçişi olmayan sayaç yazımı (tek başına `clubs` yazan batch)', () => {
  // Satır: [başlık, bağlam, delta, veri düzenlemesi?]. Eşlik eden belge oturumun kendi üyeliğidir:
  // geçiş yapmayan (ya da olmayan) üyelikle sayaç oynatılamaz; başkasının üyeliği gösterilemez.
  test.each([
    ['aktif üye (üyeliği değişmiyor) +1', 'member', 1],
    ['aktif üye (üyeliği değişmiyor) −1', 'member', -1],
    ['eski üye (left) geçmiş ayrılığını yeniden sayarak −1', 'former', -1],
    ['bekleyen başvuran +1', 'pending', 1],
    ['üyeliği olmayan öğrenci +1', 'student', 1, INSTANT],
    ['yönetici +1 (M5 — T-30)', 'board', 1],
    ['başkan −1 (M9 — T-30)', 'president', -1],
    ['süper admin +1 (T-37)', 'super', 1],
    ['başka kulübün yöneticisi −1', 'otherManager', -1],
  ])('%s → deny', async (_title, role, delta, edit = NO_EDIT) => {
    await seedFixture('base', undefined, edit);
    await assertFails(commit(role, { club: clubWrite(bump(delta)) }));
    expect(await readDoc(CLUB_PATH)).toMatchObject({ memberCount: BASE_COUNT, lastMembershipRef: null });
  });

  test('sayaç sıfırın altına inemez (bozuk sayaçta bile)', async () => {
    await seedFixture('base', undefined, { patch: { [CLUB_PATH]: { memberCount: 0 } } });
    await assertFails(commit('member', leave()));
    expect((await readDoc(CLUB_PATH)).memberCount).toBe(0);
  });
});
