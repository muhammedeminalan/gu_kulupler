'use strict';
// T-15 — sayaç tutarlılığı: `clubs.memberCount` (rules-spec §4; PLAN §11.2b `canBumpMemberCount`, CD-41).
// T-19 — `posts.likeCount` (aynı belgedeki `likes` dizisi) ve `posts.commentCount` (+ `lastCommentRef`
// işaretçisi; iki yönlü bağ) dosyanın sonundadır; `announcementCounters.count` → `announcement_limit.test.js`.
// T-22 — `events.goingCount` / `waitlistCount` / `attendedCount` dosyanın sonundadır: kendi dalı (yol oturumdan
// türetilir) ve yönetici dalı (işaretçi `events/{id}/private/counter` yan belgesinde — W-64).
//
// İki yönlü doğrulama: üyelik dalı `counterDelta` ile sayacın aynı batch'te tam ±1 oynadığını, kulüp
// dalı oturumun BU kulüpteki üyeliğinin (`memberships/{clubId}_{uid}`) aynı batch'te doğru geçişi
// yaptığını görür. Yol oturumdan türetilir; kulüp belgesine YAZILMAZ (CD-137 madde 8q).
//  1. Meşru batch'ler: M2 anında katıl +1 · M3 yeniden katıl +1 · M8 ayrıl −1.
//  2. ±1 dışı delta, ters yön, çift yazım, mutlak değer → ret.
//  3. Eşlik yok: sayaçsız üyelik geçişi ve üyelik geçişi olmayan sayaç yazımı → ret.
//  4. Sızıntı: kulüp belgesi (doğrulanmış herkese açık) kimin katıldığını / ayrıldığını taşımaz;
//     `lastMembershipRef` yazan sayaç yükü reddedilir (alan kulüp belgesinde YOKTUR — W-64, T-30).
//  5. Sayaç dalı başka alan taşıyamaz; tek başına yazılan yönetici sayacı reddedilir.
//  7. T-30 yönetici dalı (W-64): işaretçi `clubs/{id}/private/counter` yan belgesindedir; tek +1 ile iki üyelik,
//     başka kulübün / kimliği kaydırılmış üyelik, yan belgesiz ya da sayaçsız yan belge reddedilir.
//  6. Null alanın iki biçimi (W-51): null alanlarının anahtarı olmayan kulüp belgesi.
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { Timestamp, arrayUnion, doc, getDoc, increment, serverTimestamp, updateDoc } = require('firebase/firestore');
const budget = require('../helpers/budget');
const { contextFor, CLUB, OTHER_CLUB } = require('../helpers/contexts');
const { readDoc, seedDocs, seedFixture } = require('../helpers/fixtures');
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
    await seedFixture('base', undefined, { ...INSTANT, unset: { [CLUB_PATH]: ['logoPath', 'coverPath', 'pinnedPostId', 'advisor', 'suspendReason'] } });
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
    expect(club).not.toHaveProperty('lastMembershipRef');
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
    expect(await readDoc(CLUB_PATH)).toMatchObject({ memberCount: BASE_COUNT });
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
    ['yönetici +1 (yan belge ve üyelik geçişi yok — T-30)', 'board', 1],
    ['başkan −1 (yan belge ve üyelik geçişi yok — T-30)', 'president', -1],
    ['süper admin +1 (yan belge ve üyelik geçişi yok)', 'super', 1],
    ['başka kulübün yöneticisi −1', 'otherManager', -1],
  ])('%s → deny', async (_title, role, delta, edit = NO_EDIT) => {
    await seedFixture('base', undefined, edit);
    await assertFails(commit(role, { club: clubWrite(bump(delta)) }));
    expect(await readDoc(CLUB_PATH)).toMatchObject({ memberCount: BASE_COUNT });
  });

  test('sayaç sıfırın altına inemez (bozuk sayaçta bile)', async () => {
    await seedFixture('base', undefined, { patch: { [CLUB_PATH]: { memberCount: 0 } } });
    await assertFails(commit('member', leave()));
    expect((await readDoc(CLUB_PATH)).memberCount).toBe(0);
  });
});

// ── T-30 · memberCount yönetici dalı (W-64: işaretçi `clubs/{id}/private/counter` yan belgesinde) ─────
// Aktör üyeliğin sahibi değildir: kulüp dalı yan belgenin işaretçisinden üyeliği okur, üyelik dalı yan belgenin
// KENDİSİNİ gösterdiğini ister. Taban: başkanın `u_pending` onayı (M5) ve `u_member` çıkarması (M9).
describe('memberCount · yönetici dalı — yan belge işaretçisi (W-64)', () => {
  const COUNTER = payloads.clubCounterPath(CLUB);
  const approve = (extra) => payloads.approveWrites({ club: CLUB, uid: 'u_president', ...extra });
  const remove = () => payloads.removeWrites({ club: CLUB, uid: 'u_president' });
  const pointTo = (writes, userId, club = CLUB) => ({ ...writes, counter: { ...writes.counter, data: payloads.clubCounterData(club, userId) } });

  test('onay +1 ve çıkarma −1: sayaç, yan belge ve üyelik aynı işlemde; kulüp belgesi kimlik taşımaz', async () => {
    await seedFixture('base');
    await assertSucceeds(commit('president', approve()));
    expect((await readDoc(CLUB_PATH)).memberCount).toBe(BASE_COUNT + 1);
    expect(await readDoc(COUNTER)).toMatchObject({ clubId: CLUB, lastMembershipRef: payloads.membershipPath(CLUB, 'u_pending') });
    await assertSucceeds(commit('president', remove()));
    const club = await readDoc(CLUB_PATH);
    expect(club.memberCount).toBe(BASE_COUNT);
    expect(JSON.stringify(club)).not.toMatch(/u_pending|u_member/);
  });

  // Satır: [başlık, taban, yazımları değiştiren işlev, veri düzenlemesi?].
  test.each([
    ['yan belge yazılmadı (işaretçisiz sayaç)', approve, (w) => drop(w, 'counter')],
    ['sayaç yazılmadı (sayaçsız yan belge + onay)', approve, (w) => drop(w, 'club')],
    ['işaretçi başka üyeliği gösteriyor (tek +1 ile u_pending onayı + u_member)', approve, (w) => pointTo(w, MEMBER)],
    ['işaretçi başka kulübün üyeliğini gösteriyor', approve, (w) => ({ ...w, counter: { ...w.counter, data: { ...w.counter.data, lastMembershipRef: 'memberships/c02_u_mgr2' } } })],
    ['işaretçi kimliği kaydırılmış (birleşim belirsizliği: c01_u + pending)', approve, (w) => ({ ...w, counter: { ...w.counter, data: { ...w.counter.data, lastMembershipRef: 'memberships/c01_u' } } })],
    ['yan belgenin clubId alanı başka kulüp', approve, (w) => ({ ...w, counter: { ...w.counter, data: { ...w.counter.data, clubId: OTHER_CLUB } } })],
    ['yan belge beyaz liste dışı alan', approve, (w) => ({ ...w, counter: { ...w.counter, data: { ...w.counter.data, note: 'x' } } })],
    ['onayda −1 (ters yön)', approve, (w) => ({ ...w, club: clubWrite(bump(-1)) })],
    ['onayda +2', approve, (w) => ({ ...w, club: clubWrite(bump(2)) })],
    ['çıkarmada +1 (ters yön)', remove, (w) => ({ ...w, club: clubWrite(bump(1)) })],
    ['çıkarmada yan belge yok', remove, (w) => drop(w, 'counter')],
    ['iki onay tek +1 (ikinci üyelik aynı batch\'te)', approve, (w) => ({ ...w, second: payloads.approveWrites({ club: CLUB, uid: 'u_president', target: 'u_former' }).membership }), { patch: { 'memberships/c01_u_former': { status: 'pending' } } }],
  ])('%s → deny', async (_title, base, mutate, edit = NO_EDIT) => {
    await seedFixture('base', undefined, edit);
    await assertFails(commit('president', mutate(base())));
    expect((await readDoc(CLUB_PATH)).memberCount).toBe(BASE_COUNT);
  });

  // Güvenlik incelemesi (T-30): kendi dalı (M8) ile yönetici dalı (M9 / M12a) aynı −1'i ister ve `isManager`
  // yazım-öncesi durumu okur — tek sayaç oynamasıyla iki üyelik geçişi yazılamaz: aktörün kendi üyeliği işlemde
  // durum değiştiriyorsa yan belge yazılamaz (`ownMembershipUnmoved`), yönetici dalı da yan belgesiz geçmez.
  const ownLeave = () => payloads.leaveWrites({ club: CLUB, uid: 'u_board' }).membership;
  test.each([
    ['kendi ayrılması (M8) + üye çıkarma (M9), tek −1', () => ({ ...payloads.removeWrites({ club: CLUB, uid: 'u_board' }), own: ownLeave() }), NO_EDIT],
    ['kendi ayrılması (M8) + onayı geri alma (M12a), tek −1', () => ({ ...payloads.undoDecisionWrites({ club: CLUB }), own: ownLeave() }),
      { patch: { [payloads.membershipPath(CLUB, 'u_pending')]: { status: 'active', role: 'member', decidedBy: 'u_board', decidedAt: Timestamp.fromMillis(Date.now() - 5000) } } }],
  ])('yönetim kurulu: %s → deny', async (_title, build, edit) => {
    await seedFixture('base', undefined, edit);
    await assertFails(commit('board', build()));
    expect((await readDoc(CLUB_PATH)).memberCount).toBe(BASE_COUNT);
    expect((await readDoc(payloads.membershipPath(CLUB, 'u_board'))).status).toBe('active');
  });

  test('danışman danışmanın üyeliğini sayaca katamaz; danışman yan belgeyi yazamaz (Q-09)', async () => {
    await seedFixture('base');
    await assertFails(commit('advisor', payloads.approveWrites({ club: CLUB, uid: 'u_advisor' })));
    await assertFails(commit('advisor', { counter: { op: 'set', path: COUNTER, data: payloads.clubCounterData(CLUB, MEMBER) }, club: clubWrite(bump(1)) }));
    expect((await readDoc(CLUB_PATH)).memberCount).toBe(BASE_COUNT);
  });
});

// ── T-19 · posts.likeCount ───────────────────────────────────────────────────────────────────
// Beğeni ayrı belge değildir: sayaç, aynı belgedeki `likes` dizisinin uzunluk değişimiyle doğrulanır.
// `p02`: istemci biçimli gönderi (W-51), `likes: ['u_member']`, `likeCount: 1`.
describe('likeCount · beğeni / geri alma (±1; `updatedAt` yazılmaz)', () => {
  const P = 'posts/p02';
  const like = (role, data) => updateDoc(doc(contextFor(role).firestore(), P), data);

  test('like +1 ve unlike −1: dizi ve sayaç birlikte oynar, `updatedAt` değişmez', async () => {
    await seedFixture('base');
    const before = (await readDoc(P)).updatedAt.toMillis();
    await assertSucceeds(like('board', payloads.postLike('u_board')));
    expect(await readDoc(P)).toMatchObject({ likes: ['u_member', 'u_board'], likeCount: 2 });
    await assertSucceeds(like('member', payloads.postUnlike(MEMBER)));
    const post = await readDoc(P);
    expect(post).toMatchObject({ likes: ['u_board'], likeCount: 1, commentCount: 1 });
    expect(post.updatedAt.toMillis()).toBe(before);
  });

  // Satır: [başlık, bağlam, yük, veri düzenlemesi?].
  test.each([
    ['çift beğeni (kimlik zaten dizide)', 'member', payloads.postLike(MEMBER)],
    ['beğenmemiş kullanıcının geri alması', 'board', payloads.postUnlike('u_board')],
    ['başkasının kimliğiyle beğeni', 'board', payloads.postLike('u_president')],
    ['başkasının beğenisini kaldırma', 'board', payloads.postUnlike(MEMBER)],
    ['beğeniyle birlikte updatedAt', 'board', { ...payloads.postLike('u_board'), ...payloads.baseUpdate() }],
    ['delta +2', 'board', { likes: arrayUnion('u_board'), likeCount: increment(2) }],
    ['ters yön: beğenirken −1', 'board', { likes: arrayUnion('u_board'), likeCount: increment(-1) }],
    ['sayaçsız beğeni (yalnızca dizi)', 'board', { likes: arrayUnion('u_board') }],
    ['dizisiz sayaç (yalnızca likeCount)', 'board', { likeCount: increment(1) }],
    ['mutlak sayaç (likeCount: 100)', 'board', { likes: arrayUnion('u_board'), likeCount: 100 }],
    ['iki kimlik birden', 'board', { likes: arrayUnion('u_board', 'u_president'), likeCount: increment(1) }],
    ['kendi kimliğini eklerken başkasını çıkarma', 'board', { likes: ['u_board'], likeCount: increment(1) }],
    ['geri alırken başkasının beğenisini de silme (yinelenen elemanla uzunluk korunur)', 'member', { likes: ['u_board', 'u_board'], likeCount: increment(-1) }, { patch: { [P]: { likes: ['u_member', 'u_board', 'u_president'], likeCount: 3 } } }],
    ['beğeniyle birlikte başka alan (text)', 'board', { ...payloads.postLike('u_board'), text: 'x' }],
    ['beğeniyle birlikte commentCount', 'board', { ...payloads.postLike('u_board'), commentCount: increment(1) }],
    ['silinmiş gönderi', 'board', payloads.postLike('u_board'), { patch: { [P]: { isDeleted: true, deletedBy: 'u_president' } } }],
    ['gizli gönderi', 'board', payloads.postLike('u_board'), { patch: { [P]: { isHidden: true, hiddenBy: 'u_super' } } }],
  ])('%s → deny', async (_title, role, data, edit = NO_EDIT) => {
    const seeded = await seedFixture('base', undefined, edit);
    await assertFails(like(role, data));
    expect(await readDoc(P)).toMatchObject({ likes: seeded[P].likes, likeCount: seeded[P].likeCount });
  });

  // Güvenlik incelemesi (CD-141 madde 11, bulgu 1): eşlik yalnızca yazımın kendi önceki / sonraki haliyle
  // kurulmaz — İŞLEMİN TAMAMINDA sayaç tam ±1 oynar (`get` ↔ `getAfter`). Aynı işlemde aynı gönderiye
  // yinelenen beğeni yazımı (dizi bir kez büyür, sayaç her yazımda oynar) değerlendirme sırasından
  // bağımsız reddedilir.
  test.each([
    ['çift beğeni (+1, +1)', 'board', () => [payloads.postLike('u_board'), payloads.postLike('u_board')]],
    ['çift geri alma (−1, −1)', 'member', () => [payloads.postUnlike(MEMBER), payloads.postUnlike(MEMBER)]],
  ])('aynı işlemde %s → deny; dizi ve sayaç değişmez', async (_title, role, build) => {
    const seeded = await seedFixture('base');
    await assertFails(commit(role, build().map((data) => ({ op: 'update', path: P, data }))));
    expect(await readDoc(P)).toMatchObject({ likes: seeded[P].likes, likeCount: seeded[P].likeCount });
  });

  test('sayaç sıfırın altına inemez (bozuk sayaçta bile)', async () => {
    await seedFixture('base', undefined, { patch: { [P]: { likeCount: 0 } } });
    await assertFails(like('member', payloads.postUnlike(MEMBER)));
  });
});

// ── T-19 · posts.commentCount (+ lastCommentRef) ─────────────────────────────────────────────
// İki yönlü bağ: yorum kuralı gönderinin tam ±1 oynadığını ve işaretçinin KENDİSİNİ gösterdiğini, gönderi
// dalı işaretçideki yorumun aynı işlemde doğru geçişi yaptığını görür. `p01`: seed biçimi,
// `commentCount: 1` (`cm01`, yazarı u_member); `p02`: istemci biçimi, `commentCount: 1` (`cm02`).
describe('commentCount · yorum ekleme / silme / geri alma', () => {
  const add = (extra) => payloads.addCommentWrites({ club: CLUB, uid: MEMBER, ...extra });
  const remove = (extra) => payloads.removeCommentWrites({ uid: MEMBER, ...extra });
  const postWrite = (data, path = 'posts/p01') => ({ op: 'update', path, data });
  const count = async (path = 'posts/p01') => (await readDoc(path)).commentCount;
  const DELETED = { patch: { 'comments/cm01': { isDeleted: true, deletedBy: MEMBER }, 'posts/p01': { commentCount: 0 } } };

  test('comment create + commentCount +1 tek batch geçer; işaretçi yorumu gösterir, kullanıcı kimliği taşımaz', async () => {
    await seedFixture('base');
    await assertSucceeds(commit('member', add()));
    const post = await readDoc('posts/p01');
    expect(post).toMatchObject({ commentCount: 2, lastCommentRef: 'comments/cm_new' });
    expect(post.lastCommentRef).not.toContain(MEMBER);
    expect(post.updatedAt.toMillis()).toBe((await readDoc('comments/cm_new')).createdAt.toMillis());
  });

  test('istemci biçimli gönderi (lastCommentRef anahtarı yok — W-51) sayacı kabul eder', async () => {
    await seedFixture('base');
    await assertSucceeds(commit('member', add({ postId: 'p02' })));
    expect(await readDoc('posts/p02')).toMatchObject({ commentCount: 2, lastCommentRef: 'comments/cm_new', likeCount: 1 });
  });

  test('silme −1, geri alma +1; moderasyon silmesi (yönetici) de −1 — işaretçi silinen yorumu gösterir', async () => {
    await seedFixture('base');
    await assertSucceeds(commit('member', remove()));
    expect(await readDoc('posts/p01')).toMatchObject({ commentCount: 0, lastCommentRef: 'comments/cm01' });
    await assertFails(commit('member', remove()));
    await assertSucceeds(commit('member', payloads.restoreCommentWrites({})));
    expect(await count()).toBe(1);
    await assertSucceeds(commit('board', payloads.removeCommentWrites({ uid: 'u_board' })));
    expect(await count()).toBe(0);
    // Silinen yorumun içeriği ve faili sıradan üyeye / danışmana kapalıdır (işaretçi yalnızca kimliği taşır).
    await assertFails(getDoc(doc(contextFor('advisor').firestore(), 'comments/cm01')));
  });

  // Satır: [başlık, bağlam, yazımlar, veri düzenlemesi?] — sözleşme §6.f saldırı vakaları dahil.
  test.each([
    ['yorum yazmadan commentCount +1', 'member', () => ({ post: add().post })],
    ['sayaç yazımı olmayan yorum', 'member', () => ({ comment: add().comment })],
    ['tek +1 ile aynı işlemde iki yorum', 'member', () => ({ ...add(), second: add({ commentId: 'cm_new2' }).comment })],
    ['aynı işlemde aynı gönderiye iki sayaç yazımı (iki yorum, iki +1)', 'member', () => ({ ...add(), c2: add({ commentId: 'cm_new2' }).comment, p2: add({ commentId: 'cm_new2' }).post })],
    ['delta +2', 'member', () => ({ ...add(), post: postWrite({ commentCount: increment(2), lastCommentRef: 'comments/cm_new', ...payloads.baseUpdate() }) })],
    ['ters yön: eklerken −1', 'member', () => ({ ...add(), post: payloads.commentCountBump('p01', 'cm_new', -1) })],
    ['mutlak değer (commentCount: 100)', 'member', () => ({ ...add(), post: postWrite({ commentCount: 100, lastCommentRef: 'comments/cm_new', ...payloads.baseUpdate() }) })],
    ['işaretçi başka yorumu gösterir (geçiş yapmayan cm01)', 'member', () => ({ ...add(), post: payloads.commentCountBump('p01', 'cm01', 1) })],
    ['işaretçi başka gönderinin yorumunu gösterir', 'member', () => ({ comment: add({ postId: 'p02' }).comment, post: payloads.commentCountBump('p01', 'cm_new', 1) })],
    ['yorum p01\'e, sayaç p02\'ye', 'member', () => ({ comment: add().comment, post: payloads.commentCountBump('p02', 'cm_new', 1) })],
    ['işaretçisiz sayaç', 'member', () => ({ ...add(), post: postWrite({ commentCount: increment(1), ...payloads.baseUpdate() }) })],
    ['işaretçi yorum yolu değil (kullanıcı belgesi)', 'member', () => ({ ...add(), post: postWrite({ commentCount: increment(1), lastCommentRef: 'users/u_member', ...payloads.baseUpdate() }) })],
    ['sayaç updatedAt taşımıyor', 'member', () => ({ ...add(), post: postWrite({ commentCount: increment(1), lastCommentRef: 'comments/cm_new' }) })],
    ['sayaçla birlikte başka alan (likeCount)', 'member', () => ({ ...add(), post: postWrite({ commentCount: increment(1), lastCommentRef: 'comments/cm_new', likeCount: increment(1), ...payloads.baseUpdate() }) })],
    ['sayaçla birlikte başka alan (text)', 'member', () => ({ ...add(), post: postWrite({ commentCount: increment(1), lastCommentRef: 'comments/cm_new', text: 'x', ...payloads.baseUpdate() }) })],
    ['silmeden commentCount −1', 'member', () => ({ post: remove().post })],
    ['sayaçsız silme', 'member', () => ({ comment: remove().comment })],
    ['silerken +1', 'member', () => ({ ...remove(), post: payloads.commentCountBump('p01', 'cm01', 1) })],
    ['silme + ekleme aynı işlemde (net 0)', 'member', () => ({ ...remove(), c2: add().comment, p2: add().post })],
    ['geri alma sayaçsız', 'member', () => ({ comment: payloads.restoreCommentWrites({}).comment }), DELETED],
    ['geri alırken −1', 'member', () => ({ ...payloads.restoreCommentWrites({}), post: payloads.commentCountBump('p01', 'cm01', -1) }), DELETED],
    ['silinmemiş yorumu "geri alarak" +1', 'member', () => payloads.restoreCommentWrites({})],
    ['yorum yazamayan bağlam (danışman) sayacı oynatır', 'advisor', () => ({ post: add().post })],
    ['süper admin yorumsuz +1', 'super', () => ({ post: add().post })],
  ])('%s → deny', async (_title, role, build, edit = NO_EDIT) => {
    const seeded = await seedFixture('base', undefined, edit);
    await assertFails(commit(role, build()));
    expect(await count()).toBe(seeded['posts/p01'].commentCount);
    expect(await count('posts/p02')).toBe(1);
    expect(await readDoc('comments/cm_new')).toBeNull();
    expect((await readDoc('comments/cm01')).isDeleted).toBe(seeded['comments/cm01'].isDeleted);
  });

  test('sayaç sıfırın altına inemez (bozuk sayaçta bile)', async () => {
    await seedFixture('base', undefined, { patch: { 'posts/p01': { commentCount: 0 } } });
    await assertFails(commit('member', remove()));
    expect((await readDoc('comments/cm01')).isDeleted).toBe(false);
  });

  test('gizleme sayacı ve işaretçiyi değiştirmez', async () => {
    await seedFixture('base');
    const db = contextFor('super').firestore();
    await assertSucceeds(updateDoc(doc(db, 'comments/cm01'), payloads.hidePayload('u_super')));
    expect(await readDoc('posts/p01')).toMatchObject({ commentCount: 1, lastCommentRef: null });
    await assertFails(updateDoc(doc(db, 'comments/cm02'), { ...payloads.hidePayload('u_super'), hiddenAt: serverTimestamp(), text: 'x' }));
  });
});

// ── T-22 · events.goingCount / waitlistCount (kendi dalı) ───────────────────────────────────────
// İki yönlü bağ (sözleşme §6.4): katılım kuralı etkinliğin üç sayacının İŞLEMİN TAMAMINDA tam beklenen kadar
// oynadığını (`get` ↔ `getAfter`), etkinliğin sayaç dalı oturumun BU etkinlikteki kaydının
// (`rsvps/{eventId}_{uid}`) aynı işlemde doğru geçişi yaptığını görür. Yol oturumdan türetilir; etkinlik
// belgesine YAZILMAZ (W-64). `e_public`: yayında, 2 kayıtlı (u_member, u_susp), kontenjan 40.
describe('goingCount / waitlistCount · katılım ve vazgeçme (kendi dalı)', () => {
  const E = 'events/e_public';
  const R = payloads.rsvpPath('e_public', STUDENT);
  const R_MEMBER = payloads.rsvpPath('e_public', MEMBER);
  const FULL = { patch: { [E]: { capacity: 2 } } };
  const joinEvent = (options) => payloads.rsvpJoinWrites({ club: CLUB, uid: STUDENT, ...options });
  const cancelOwn = (options) => payloads.rsvpCancelWrites({ uid: MEMBER, ...options });
  const eventWrite = (data, path = E) => ({ op: 'update', path, data });
  const bumps = (deltas, extra) => eventWrite(payloads.eventCountersBump(deltas, extra));
  const counts = async (path = E) => {
    const { goingCount, waitlistCount, attendedCount } = await readDoc(path);
    return [goingCount, waitlistCount, attendedCount];
  };

  test('rsvp create + goingCount +1 tek batch geçer; etkinlik belgesi katılanın kimliğini taşımaz (W-64)', async () => {
    await seedFixture('base');
    await assertSucceeds(commit('student', joinEvent()));
    await assertSucceeds(commit('member', cancelOwn()));
    expect(await counts()).toEqual([2, 0, 0]);
    expect((await readDoc(E)).updatedAt.toMillis()).toBe((await readDoc(R_MEMBER)).updatedAt.toMillis());

    // Etkinliği doğrulanmış herkes okur — burada c01'de üyeliği olmayan başka kulüp yöneticisi.
    const event = (await assertSucceeds(getDoc(doc(contextFor('otherManager').firestore(), E)))).data();
    expect(event).not.toHaveProperty('lastRsvpRef');
    const serialized = JSON.stringify(event);
    for (const uid of [STUDENT, MEMBER]) expect(serialized).not.toContain(uid);
    // Aynı bağlam o katılım kayıtlarını da okuyamaz.
    await assertFails(getDoc(doc(contextFor('otherManager').firestore(), R)));
  });

  // KONTENJAN (W-51 iki biçim): anahtarsız ve açık null kontenjan sınırsızdır; dolu etkinlikte kayıtlı artmaz.
  test.each([
    ['kontenjan anahtarı yok (istemci biçimi) → sınırsız', { unset: { [E]: ['capacity'] } }, 'going', 'allow'],
    ['kontenjan açık null (seed biçimi) → sınırsız', { patch: { [E]: { capacity: null } } }, 'going', 'allow'],
    ['kontenjan dolu (2 / 2) → kayıtlı artamaz (goingCount <= capacity)', FULL, 'going', 'deny'],
    ['kontenjan aşılmış (bozuk veri 2 / 1) → kayıtlı artamaz', { patch: { [E]: { capacity: 1 } } }, 'going', 'deny'],
    ['kontenjan dolu → bekleyen +1', FULL, 'waitlist', 'allow'],
    ['yer varken bekleyen +1', NO_EDIT, 'waitlist', 'deny'],
  ])('%s → %s', async (_title, edit, status, expected) => {
    await seedFixture('base', undefined, edit);
    await expectWrite(commit('student', joinEvent({ status })), expected);
    const moved = expected === 'allow' ? (status === 'going' ? [3, 0, 0] : [2, 1, 0]) : [2, 0, 0];
    expect(await counts()).toEqual(moved);
  });

  // Satır: [başlık, bağlam, yazımlar, veri düzenlemesi?]. Taban: öğrencinin katılımı / üyenin vazgeçmesi.
  test.each([
    ['katılım kaydı olmadan goingCount +1', 'student', () => ({ event: joinEvent().event })],
    ['sayaç yazımı olmayan katılım', 'student', () => ({ rsvp: joinEvent().rsvp })],
    ['delta +2', 'student', () => ({ ...joinEvent(), event: bumps({ going: 2 }) })],
    ['mutlak değer (goingCount: 100)', 'student', () => ({ ...joinEvent(), event: eventWrite({ goingCount: 100, ...payloads.baseUpdate() }) })],
    ['ters yön: katılırken −1', 'student', () => ({ ...joinEvent(), event: bumps({ going: -1 }) })],
    ['yanlış sayaç: going kayıt, waitlistCount +1', 'student', () => ({ ...joinEvent(), event: bumps({ waitlist: 1 }) }), FULL],
    ['yanlış sayaç: waitlist kayıt, goingCount +1', 'student', () => ({ ...joinEvent({ status: 'waitlist' }), event: bumps({ going: 1 }) }), FULL],
    ['iki sayaç birden (+1, +1, 0)', 'student', () => ({ ...joinEvent(), event: bumps({ going: 1, waitlist: 1 }) })],
    ['katılırken attendedCount +1 (kendi yoklaması)', 'student', () => ({ ...joinEvent(), event: bumps({ going: 1, attended: 1 }) })],
    ['kendi dalında terfi bileşimi (+1, −1, 0)', 'student', () => ({ ...joinEvent(), event: bumps({ going: 1, waitlist: -1 }) }), { patch: { [E]: { waitlistCount: 1 } } }],
    ['aynı batch\'te sayaç iki kez (+1, +1)', 'student', () => ({ ...joinEvent(), again: bumps({ going: 1 }) })],
    ['sayaçla birlikte lastRsvpRef (katılım yolu herkese açık belgeye yazılamaz — W-64)', 'student', () => ({ ...joinEvent(), event: bumps({ going: 1 }, { lastRsvpRef: R }) })],
    ['sayaçla birlikte başka alan (title)', 'student', () => ({ ...joinEvent(), event: bumps({ going: 1 }, { title: 'x' }) })],
    ['sayaçla birlikte kontenjan artırma', 'student', () => ({ ...joinEvent(), event: bumps({ going: 1 }, { capacity: 100 }) }), FULL],
    ['sayaç updatedAt taşımıyor', 'student', () => ({ ...joinEvent(), event: eventWrite({ goingCount: increment(1) }) })],
    ['kayıt e_public\'e, sayaç e_members\'a', 'student', () => ({ rsvp: joinEvent().rsvp, event: eventWrite(payloads.eventCountersBump({ going: 1 }), 'events/e_members') })],
    ['başka etkinliğin sayacı da oynatılıyor (e_members\'ta katılım yok)', 'student', () => ({ ...joinEvent(), other: eventWrite(payloads.eventCountersBump({ going: 1 }), 'events/e_members') })],
    ['başkasının katılımıyla sayaç: üye, öğrencinin kaydını yazamaz', 'member', () => joinEvent()],
    ['vazgeçmeden goingCount −1', 'member', () => ({ event: cancelOwn().event })],
    ['sayaçsız vazgeçme', 'member', () => ({ rsvp: cancelOwn().rsvp })],
    ['vazgeçerken +1', 'member', () => ({ ...cancelOwn(), event: bumps({ going: 1 }) })],
    ['vazgeçerken yanlış sayaç (waitlistCount −1)', 'member', () => ({ ...cancelOwn(), event: bumps({ waitlist: -1 }) }), { patch: { [E]: { waitlistCount: 1 } } }],
    ['vazgeçerken delta −2', 'member', () => ({ ...cancelOwn(), event: bumps({ going: -2 }) })],
    ['başkasının kaydından vazgeçme (yönetici, sayaçla birlikte)', 'board', () => cancelOwn()],
    ['yönetici, katılım kaydı olmadan goingCount −1', 'board', () => ({ event: cancelOwn().event })],
    ['süper admin, katılım kaydı olmadan goingCount +1', 'super', () => ({ event: joinEvent().event })],
  ])('%s → deny', async (_title, role, build, edit = NO_EDIT) => {
    const seeded = await seedFixture('base', undefined, edit);
    await assertFails(commit(role, build()));
    expect(await counts()).toEqual([seeded[E].goingCount, seeded[E].waitlistCount, 0]);
    expect(await counts('events/e_members')).toEqual([0, 0, 0]);
    expect(await readDoc(R)).toBeNull();
    expect((await readDoc(R_MEMBER)).status).toBe('going');
  });

  test('aynı işlemde vazgeç + yeniden katıl (net 0) ve çift vazgeçme reddedilir; sayaç sıfırın altına inemez', async () => {
    await seedFixture('base');
    const rejoin = payloads.rsvpRejoinWrites({ uid: MEMBER });
    await assertFails(commit('member', { ...cancelOwn(), r2: rejoin.rsvp, e2: rejoin.event }));
    await assertFails(commit('member', { ...cancelOwn(), e2: cancelOwn().event }));
    expect(await counts()).toEqual([2, 0, 0]);

    // Bozuk sayaç (0 kayıtlı görünür): vazgeçme sayacı eksiye düşüremez.
    await seedFixture('base', undefined, { patch: { [E]: { goingCount: 0 } } });
    await assertFails(commit('member', cancelOwn()));
    expect((await readDoc(R_MEMBER)).status).toBe('going');
  });
});

// ── T-22 · events.attendedCount ve terfi (yönetici dalı; yazan repository T-30) ─────────────────
// Aktör kaydın sahibi değildir: eşlik eden kayıt, AYNI işlemde yazılan yan belgenin
// (`events/{id}/private/counter`) işaretçisinden okunur. `e_live`: süren etkinlik, kontenjan 3,
// sayaçlar (2, 1, 1) — u_member going, u_board attended, u_student waitlist.
describe('attendedCount / terfi · yönetici dalı (işaretçi yan belgede — W-64)', () => {
  const E = 'events/e_live';
  const SIDE = payloads.eventCounterPath('e_live');
  const R_MEMBER = payloads.rsvpPath('e_live', MEMBER);
  const R_BOARD = payloads.rsvpPath('e_live', 'u_board');
  const R_STUDENT = payloads.rsvpPath('e_live', STUDENT);
  const attendOne = (options) => payloads.attendWrites({ club: CLUB, uid: 'u_board', ...options });
  const promote = (options) => payloads.promoteWrites({ club: CLUB, ...options });
  const bumps = (deltas, extra, path = E) => ({ op: 'update', path, data: payloads.eventCountersBump(deltas, extra) });
  const side = (userId, extra, eventId = 'e_live') => ({ op: 'set', path: payloads.eventCounterPath(eventId), data: payloads.eventCounterData(CLUB, eventId, userId, extra) });
  const counts = async (path = E) => {
    const { goingCount, waitlistCount, attendedCount } = await readDoc(path);
    return [goingCount, waitlistCount, attendedCount];
  };

  test('yoklama (0, 0, +1) ve terfi (+1, −1, 0) geçer; işaretçi yan belgededir, etkinlik belgesi kimlik taşımaz', async () => {
    await seedFixture('base');
    await assertSucceeds(commit('board', attendOne()));
    expect(await counts()).toEqual([2, 1, 2]);
    expect(await readDoc(SIDE)).toMatchObject({ clubId: CLUB, lastRsvpRef: R_MEMBER });
    await assertSucceeds(commit('president', promote()));
    expect(await counts()).toEqual([3, 0, 2]);
    expect(await readDoc(SIDE)).toMatchObject({ lastRsvpRef: R_STUDENT });

    // Etkinlik herkese açıktır ve kimin yoklamasının alındığını / terfi ettiğini taşımaz; yan belgeyi üye okuyamaz.
    const event = (await assertSucceeds(getDoc(doc(contextFor('student').firestore(), E)))).data();
    expect(event).not.toHaveProperty('lastRsvpRef');
    for (const uid of [MEMBER, STUDENT, 'u_board']) expect(JSON.stringify({ ...event, createdBy: null })).not.toContain(uid);
    await assertFails(getDoc(doc(contextFor('member').firestore(), SIDE)));
  });

  // Satır: [başlık, bağlam, yazımlar, veri düzenlemesi?]. Taban: yöneticinin u_member yoklaması / u_student terfisi.
  test.each([
    ['yan belge yok (işaretçisiz yoklama)', 'board', () => { const w = attendOne(); return { rsvp: w.rsvp, event: w.event }; }, { without: [SIDE] }],
    ['yan belge bu işlemde yazılmıyor (eski işaretçi)', 'board', () => { const w = attendOne(); return { rsvp: w.rsvp, event: w.event }; }, { patch: { [SIDE]: { lastRsvpRef: R_MEMBER } } }],
    ['yoklama kaydı olmadan attendedCount +1 (yan belgeyle)', 'board', () => { const w = attendOne(); return { event: w.event, counter: w.counter }; }],
    ['sayaçsız yoklama (yan belgeyle)', 'board', () => { const w = attendOne(); return { rsvp: w.rsvp, counter: w.counter }; }],
    ['yan belge tek başına', 'board', () => ({ counter: attendOne().counter })],
    ['işaretçi geçiş yapmayan başka kaydı gösterir', 'board', () => ({ ...attendOne(), counter: side('u_board') })],
    ['işaretçi başka etkinliğin kaydını gösterir', 'board', () => ({ ...attendOne(), counter: side(MEMBER, { lastRsvpRef: payloads.rsvpPath('e_public', MEMBER) }) })],
    ['işaretçi katılım yolu değil (kullanıcı belgesi)', 'board', () => ({ ...attendOne(), counter: side(MEMBER, { lastRsvpRef: 'users/u_member' }) })],
    ['işaretçi alt yol taşır', 'board', () => ({ ...attendOne(), counter: side(MEMBER, { lastRsvpRef: `${R_MEMBER}/x/y` }) })],
    ['yan belgede clubId başka kulüp', 'board', () => ({ ...attendOne(), counter: side(MEMBER, { clubId: OTHER_CLUB }) })],
    ['yan belgede updatedAt istemci saati', 'board', () => ({ ...attendOne(), counter: side(MEMBER, { updatedAt: new Date(Date.now() - 60 * 1000) }) })],
    ['yan belgede beyaz liste dışı alan', 'board', () => ({ ...attendOne(), counter: side(MEMBER, { ticketCode: 'GU-ABCD-2345' }) })],
    ['yan belge başka belge adıyla (private/other)', 'board', () => ({ ...attendOne(), counter: { ...side(MEMBER), path: 'events/e_live/private/other' } })],
    ['tek +1 ile iki yoklama (tek işaretçi)', 'board', () => ({ ...attendOne(), second: attendOne({ userId: STUDENT }).rsvp }), { patch: { [R_STUDENT]: { status: 'going' } } }],
    ['iki yoklama, iki +1 (işlem başına tek geçiş)', 'board', () => ({ ...attendOne(), r2: attendOne({ userId: STUDENT }).rsvp, e2: attendOne().event }), { patch: { [R_STUDENT]: { status: 'going' } } }],
    ['yoklamada delta +2', 'board', () => ({ ...attendOne(), event: bumps({ attended: 2 }) })],
    ['yoklamada goingCount da oynar (0 → attended kayıtlıyı düşürmez — CD-130)', 'board', () => ({ ...attendOne(), event: bumps({ going: -1, attended: 1 }) })],
    ['yoklamada mutlak değer', 'board', () => ({ ...attendOne(), event: { op: 'update', path: E, data: { attendedCount: 2, goingCount: 40, ...payloads.baseUpdate() } } })],
    ['yoklama sayacıyla birlikte başka alan (capacity)', 'board', () => ({ ...attendOne(), event: bumps({ attended: 1 }, { capacity: 100 }) })],
    ['attendedCount goingCount\'u aşar (bozuk sayaç 1 / 1)', 'board', () => attendOne(), { patch: { [E]: { goingCount: 1 } } }],
    ['geri almada attendedCount sıfırın altına iner (bozuk sayaç)', 'president', () => attendOne({ userId: 'u_board', attended: false }), { patch: { [E]: { attendedCount: 0 } } }],
    ['geri alma yönünde +1', 'president', () => ({ ...attendOne({ userId: 'u_board', attended: false }), event: bumps({ attended: 1 }) })],
    // rules-spec §3.8 (güvenlik incelemesi T-30): katılımcının kendisi yoklama alamaz / geri alamaz — yönetici de.
    ['yönetici kendi kaydının yoklamasını geri alır', 'board', () => attendOne({ userId: 'u_board', attended: false })],
    ['terfi (+1, 0, 0) ile: waitlistCount düşmez', 'board', () => ({ ...promote(), event: bumps({ going: 1 }) })],
    ['terfi (0, −1, 0) ile: goingCount artmaz', 'board', () => ({ ...promote(), event: bumps({ waitlist: -1 }) })],
    // Aynı belgeye iki yazım tek yazım gibi değerlendirilir; (+1) + (−1, −1) toplamı işlemin tamamında (+1, −2, 0)'dır.
    ['terfi iki ayrı yazımla, ikincisi fazladan −1 (işlemin tamamı +1, −2)', 'board', () => ({ ...promote(), event: bumps({ going: 1 }), e2: bumps({ waitlist: -2 }) })],
    ['terfi: kontenjan dolu (2 / 2)', 'board', () => promote(), { patch: { [E]: { capacity: 2 } } }],
    ['terfi kaydı olmadan (+1, −1, 0)', 'board', () => { const w = promote(); return { event: w.event, counter: w.counter }; }],
    ['terfi işaretçisi going kaydı gösterir', 'board', () => ({ ...promote(), counter: side(MEMBER) })],
    ['yönetici, yoklama + kendi katılımı tek işlemde (iki dal, tek sayaç yazımı)', 'president', () => ({ ...payloads.attendWrites({ club: CLUB, uid: 'u_president' }), event: bumps({ going: 1, attended: 1 }), own: { op: 'set', path: payloads.rsvpPath('e_live', 'u_president'), data: payloads.rsvpCreate({ club: CLUB, uid: 'u_president', eventId: 'e_live' }) } })],
    ['danışman, tam yoklama işlemi', 'advisor', () => payloads.attendWrites({ club: CLUB, uid: 'u_advisor' })],
    ['süper admin, tam terfi işlemi', 'super', () => promote()],
    ['başka kulübün yöneticisi, tam yoklama işlemi', 'otherManager', () => payloads.attendWrites({ club: CLUB, uid: 'u_mgr2' })],
    ['başka kulübün yöneticisi, kendi kulübü adına yan belge', 'otherManager', () => payloads.attendWrites({ club: OTHER_CLUB, uid: 'u_mgr2' })],
  ])('%s → deny', async (_title, role, build, edit = NO_EDIT) => {
    const seeded = await seedFixture('base', undefined, edit);
    await assertFails(commit(role, build()));
    expect(await counts()).toEqual([seeded[E].goingCount, 1, seeded[E].attendedCount]);
    expect((await readDoc(R_MEMBER)).status).toBe('going');
    expect((await readDoc(R_BOARD)).status).toBe('attended');
    expect((await readDoc(R_STUDENT)).status).toBe(seeded[R_STUDENT].status);
    expect(await readDoc('events/e_live/private/other')).toBeNull();
  });

  // rules-spec §3.8 (güvenlik incelemesi T-30): bekleme listesindeki yönetici kendini terfi ettiremez
  // (öndekilerin önüne geçemez) ve kendi yoklamasını alamaz; aynı kaydı başka yönetici terfi ettirir.
  test('yönetici kendi kaydını terfi ettiremez / yoklamasını alamaz; başka yönetici alır', async () => {
    const waiting = {
      patch: {
        [R_BOARD]: { status: 'waitlist', scannedAt: null, scannedBy: null, waitlistAt: Timestamp.fromMillis(Date.now() - 3 * 60 * 60 * 1000) },
        [E]: { goingCount: 1, waitlistCount: 2, attendedCount: 0 },
      },
    };
    await seedFixture('base', undefined, waiting);
    await assertFails(commit('board', promote({ userId: 'u_board' })));
    expect(await counts()).toEqual([1, 2, 0]);
    await assertSucceeds(commit('president', promote({ userId: 'u_board' })));
    expect(await counts()).toEqual([2, 1, 0]);
    await assertFails(commit('board', attendOne({ userId: 'u_board' })));
    await assertSucceeds(commit('president', payloads.attendWrites({ club: CLUB, uid: 'u_president', userId: 'u_board' })));
    expect(await counts()).toEqual([2, 1, 1]);
  });

  // Kimlik birleşimi belirsizdir: `e_live` + `u_member` = `e_live_u` + `member`. Kural işaretçideki belgenin
  // `eventId` / `userId` alanlarından yolu yeniden kurar: tek kayıt geçişiyle iki etkinliğin sayacı oynatılamaz.
  test('kimlik birleşimi kaydırılarak başka etkinliğin sayacı oynatılamaz', async () => {
    const docs = await seedFixture('base');
    await seedDocs({ 'events/e_live_u': docs[E] });
    const twin = { e2: bumps({ attended: 1 }, {}, 'events/e_live_u'), c2: side('member', {}, 'e_live_u') };
    expect(twin.c2.data.lastRsvpRef).toBe(R_MEMBER);

    await assertFails(commit('board', { ...attendOne(), ...twin }));
    await assertFails(commit('board', { rsvp: attendOne().rsvp, ...twin }));
    expect(await counts('events/e_live_u')).toEqual([2, 1, 1]);
    expect((await readDoc(R_MEMBER)).status).toBe('going');
    // Denetim: aynı işlem ikiz yazımlar olmadan geçer.
    await assertSucceeds(commit('board', attendOne()));
  });
});
