'use strict';
// T-15 — sayaç tutarlılığı: `clubs.memberCount` (rules-spec §4; PLAN §11.2b `canBumpMemberCount`, CD-41).
// T-19 — `posts.likeCount` (aynı belgedeki `likes` dizisi) ve `posts.commentCount` (+ `lastCommentRef`
// işaretçisi; iki yönlü bağ) dosyanın sonundadır; `announcementCounters.count` → `announcement_limit.test.js`.
// T-22 (`goingCount`, `waitlistCount`, `attendedCount`) kendi `describe` bloklarını bu dosyaya ekler.
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
const { arrayUnion, doc, getDoc, increment, serverTimestamp, updateDoc } = require('firebase/firestore');
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
