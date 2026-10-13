'use strict';
// T-19 — `announcementCounters/{clubId}_{yyyyMMdd}` ve günlük bildirimli duyuru limiti (Q-10; rules-spec
// §3.16; PLAN §11.1 satır 18, §11.2b; sözleşme docs/plans/T-19.md §6.c — W-50, CD-129).
//
//  1. Rol × işlem matrisi: `expectations/announcement_counters.json` (okuma yalnızca kulüp yönetimi /
//     danışman / süper admin; olmayan sayaç yönetime boş döner; sayaç tek başına yazılamaz).
//  2. Limit: gün başına 2 bildirimli duyuru, 3. ret; sayaçsız bildirimli duyuru ret; bildirimsiz duyuru
//     sayaca dokunmaz; önceki günün dolu sayacı bugünü etkilemez.
//  3. İki yönlü bağ: sayaç ↔ gönderi (`lastPostRef`); tek artışla iki duyuru, bildirimsiz gönderiyi
//     gösteren işaretçi, başkasının duyurusu → ret.
//  4. Gün anahtarı (W-50): Rules günü `request.time + 3 sa`'ten hesaplar ve eşitlik toleranssızdır —
//     dün / yarın anahtarı ve yanlış `day` alanı reddedilir, sunucu günü geçer.
//
// `request.time` emülatörde sabitlenemez: gün sınırının kendisi (20:59Z → gün N, 21:00Z → gün N + 1)
// `payloads.istanbulDay` üzerinde saf hesapla sınanır; emülatör vakaları aynı fonksiyonun "şimdi" için
// ürettiği anahtarı Rules'un kabul ettiğini, komşu günleri reddettiğini gösterir. Gün sınırına birkaç
// saniye kala koşan test sınırı bekler (`settleDay`): anahtar ile istek aynı güne düşer.
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, getDoc, increment, serverTimestamp } = require('firebase/firestore');
const budget = require('../helpers/budget');
const { contextFor, CLUB, OTHER_CLUB } = require('../helpers/contexts');
const { readDoc, seedDocs, seedFixture } = require('../helpers/fixtures');
const { runMatrix } = require('../helpers/matrix');
const payloads = require('../helpers/payloads');

const BOARD = 'u_board';
const DAY_MS = payloads.DAY_MS;
const ISTANBUL_OFFSET_MS = 3 * 60 * 60 * 1000;
const SETTLE_MS = 5000;
const LIMIT = 2;

const commit = (role, writes) => budget.buildBatch(contextFor(role).firestore(), Object.values(writes)).commit();
const drop = (writes, name) => Object.fromEntries(Object.entries(writes).filter(([key]) => key !== name));
const today = () => payloads.counterPath(CLUB);
const countOf = async (path = today()) => ((await readDoc(path)) || { count: 0 }).count;

/** Istanbul gün sınırına `SETTLE_MS`'ten az kaldıysa sınırı bekler (anahtar ve istek aynı güne düşsün). */
async function settleDay() {
  const left = DAY_MS - ((Date.now() + ISTANBUL_OFFSET_MS) % DAY_MS);
  if (left < SETTLE_MS) await new Promise((resolve) => setTimeout(resolve, left + 50));
}

/** Bildirimli duyuru yayını (gönderi + günlük + sayaç); `ms` = sayaç gününün hesaplandığı an. */
const announce = (postId, previousCount, extra = {}) =>
  payloads.createPostWrites({ club: CLUB, uid: BOARD, type: 'announcement', pushSent: true, postId, previousCount, ...extra });
/** Sayaç yazımını ezer (yol ve / veya alanlar). */
const withCounter = (writes, { path, data }) => ({ ...writes, counter: { ...writes.counter, path: path || writes.counter.path, data: { ...writes.counter.data, ...data } } });
/** Bugünün sayacını kuralları atlayarak kurar; `withRef: false` → `lastPostRef` anahtarı hiç yazılmaz (W-51). */
const seedCounter = (count, { withRef = true } = {}) =>
  seedDocs({ [today()]: { clubId: CLUB, day: payloads.istanbulDay().day, count, updatedAt: serverTimestamp(), ...(withRef ? { lastPostRef: null } : {}) } });

beforeEach(settleDay);

runMatrix('announcement_counters.json');

describe('gün anahtarı · Istanbul günü (payloads.istanbulDay — AppClock.istanbulDayKey ile aynı hesap)', () => {
  test('20:59Z → gün N, 21:00Z → gün N + 1; anahtar ve `day` alanı sıfır dolguludur', () => {
    expect(payloads.istanbulDay(Date.UTC(2026, 9, 13, 20, 59, 59))).toEqual({ key: '20261013', day: '2026-10-13' });
    expect(payloads.istanbulDay(Date.UTC(2026, 9, 13, 21, 0, 0))).toEqual({ key: '20261014', day: '2026-10-14' });
    expect(payloads.istanbulDay(Date.UTC(2026, 11, 31, 21, 0, 0))).toEqual({ key: '20270101', day: '2027-01-01' });
    expect(payloads.counterPath(CLUB, Date.UTC(2027, 1, 3, 12))).toBe(`announcementCounters/${CLUB}_20270203`);
  });
});

describe('duyuru limiti · gün başına 2 bildirimli duyuru (Q-10)', () => {
  test('1. ve 2. duyuru geçer (count 1 → 2), 3. reddedilir; sayaç son duyuruyu gösterir', async () => {
    await seedFixture('base');
    await assertSucceeds(commit('board', announce('p_a1', 0)));
    const first = await readDoc(today());
    expect(Object.keys(first).sort()).toEqual(['clubId', 'count', 'day', 'lastPostRef', 'updatedAt']);
    expect(first).toMatchObject({ clubId: CLUB, day: payloads.istanbulDay().day, count: 1, lastPostRef: 'posts/p_a1' });

    // İkinci duyuruyu başka bir yönetici yayınlar: hak kulübündür, kişinin değil.
    await assertSucceeds(commit('president', payloads.createPostWrites({ club: CLUB, uid: 'u_president', type: 'announcement', pushSent: true, postId: 'p_a2', previousCount: 1 })));
    expect(await readDoc(today())).toMatchObject({ count: LIMIT, lastPostRef: 'posts/p_a2' });

    await assertFails(commit('board', announce('p_a3', LIMIT)));
    await assertFails(commit('board', drop(announce('p_a3', LIMIT), 'counter')));
    expect(await readDoc('posts/p_a3')).toBeNull();
    expect(await countOf()).toBe(LIMIT);
    // Hak dolsa da bildirimsiz duyuru ve düz gönderi yayınlanır.
    await assertSucceeds(commit('board', payloads.createPostWrites({ club: CLUB, uid: BOARD, type: 'announcement', postId: 'p_quiet' })));
    expect(await countOf()).toBe(LIMIT);
  });

  test('önceki günün dolu sayacı bugünü etkilemez; silinen duyuru hakkı iade etmez', async () => {
    await seedFixture('base');
    const yesterday = Date.now() - DAY_MS;
    await seedDocs({ [payloads.counterPath(CLUB, yesterday)]: { clubId: CLUB, day: payloads.istanbulDay(yesterday).day, count: LIMIT, lastPostRef: null, updatedAt: serverTimestamp() } });
    await assertSucceeds(commit('board', announce('p_a1', 0)));
    await assertSucceeds(commit('board', { post: { op: 'update', path: 'posts/p_a1', data: payloads.softDelete(BOARD) } }));
    expect(await countOf()).toBe(1);
    expect(await countOf(payloads.counterPath(CLUB, yesterday))).toBe(LIMIT);
  });

  test.each([
    ['seed biçimi (lastPostRef: null)', true],
    ['istemci biçimi (lastPostRef anahtarı yok — W-51)', false],
  ])('var olan sayaç artar: %s', async (_title, withRef) => {
    await seedFixture('base');
    await seedCounter(1, { withRef });
    await assertSucceeds(commit('board', announce('p_a2', 1)));
    expect(await readDoc(today())).toMatchObject({ count: LIMIT, lastPostRef: 'posts/p_a2' });
  });

  test('yönetim sayacı okur (FED-03 hak çubuğu); sıradan üye okuyamaz', async () => {
    await seedFixture('base');
    await assertSucceeds(commit('board', announce('p_a1', 0)));
    const snapshot = await assertSucceeds(getDoc(doc(contextFor('advisor').firestore(), today())));
    expect(snapshot.data().count).toBe(1);
    await assertFails(getDoc(doc(contextFor('member').firestore(), today())));
  });
});

describe('duyuru limiti · sayaç ↔ gönderi eşliği ve gün anahtarı (W-50)', () => {
  const yesterday = () => Date.now() - DAY_MS;
  const tomorrow = () => Date.now() + DAY_MS;
  const quietPost = (postId) => payloads.createPostWrites({ club: CLUB, uid: BOARD, type: 'announcement', postId });

  // Satır: [başlık, bağlam, yazım üreticisi, bugünün sayacı (önceden)?]. Hepsi ret; sayaç ve gönderi değişmez.
  test.each([
    ['sayaç artışı olmadan bildirimli duyuru', 'board', () => drop(announce('p_a1', 0), 'counter')],
    ['duyuru olmadan sayaç', 'board', () => ({ counter: announce('p_a1', 0).counter })],
    ['tek sayaç artışıyla iki bildirimli duyuru', 'board', () => ({ ...announce('p_a1', 0), second: announce('p_a2', 0).post })],
    ['sayaç bildirimsiz duyuruyu gösterir', 'board', () => ({ ...quietPost('p_a1'), counter: announce('p_a1', 0).counter })],
    ['sayaç düz gönderiyi gösterir', 'board', () => ({ ...payloads.createPostWrites({ club: CLUB, uid: BOARD, postId: 'p_a1' }), counter: announce('p_a1', 0).counter })],
    ['sayaç var olan gönderiyi gösterir (yayın bu işlemde değil)', 'board', () => ({ counter: announce('p01', 0).counter })],
    ['başkası adına bildirimli duyuru (authorId)', 'board', () => payloads.createPostWrites({ club: CLUB, uid: 'u_president', type: 'announcement', pushSent: true, postId: 'p_a1' })],
    ['işaretçi gönderi yolu değil', 'board', () => withCounter(announce('p_a1', 0), { data: { lastPostRef: 'users/u_board' } })],
    ['işaretçisiz sayaç', 'board', () => withCounter(announce('p_a1', 0), { data: { lastPostRef: null } })],
    ['ilk yazımda count 2', 'board', () => withCounter(announce('p_a1', 0), { data: { count: 2 } })],
    ['count artmıyor (1 → 1)', 'board', () => withCounter(announce('p_a2', 1), { data: { count: 1 } }), 1],
    ['count increment(2)', 'board', () => withCounter(announce('p_a2', 0), { data: { count: increment(2) } }), 0],
    ['dolu sayaç sıfırlanarak yeniden kullanılır (2 → 1)', 'board', () => withCounter(announce('p_a3', 2), { data: { count: 1 } }), LIMIT],
    ['sayaçta beyaz liste dışı alan', 'board', () => withCounter(announce('p_a1', 0), { data: { note: 'x' } })],
    ['sayaç updatedAt taşımıyor', 'board', () => { const w = announce('p_a1', 0); const { updatedAt: _omitted, ...data } = w.counter.data; return { ...w, counter: { ...w.counter, data } }; }],
    ['dünün anahtarı (komşu gün — tolerans yok)', 'board', () => announce('p_a1', 0, { ms: yesterday() })],
    ['yarının anahtarı (komşu gün — tolerans yok)', 'board', () => announce('p_a1', 0, { ms: tomorrow() })],
    ['doğru anahtar, yanlış `day` alanı', 'board', () => withCounter(announce('p_a1', 0), { data: { day: payloads.istanbulDay(yesterday()).day } })],
    ['`day` sıfır dolgusuz / biçimsiz', 'board', () => withCounter(announce('p_a1', 0), { data: { day: payloads.istanbulDay().key } })],
    ['başka kulübün sayacı (kimlik c02, alan c01)', 'board', () => withCounter(announce('p_a1', 0), { path: payloads.counterPath(OTHER_CLUB) })],
    ['başka kulübün sayacı (kimlik ve alan c02)', 'board', () => withCounter(announce('p_a1', 0), { path: payloads.counterPath(OTHER_CLUB), data: { clubId: OTHER_CLUB } })],
    ['gün eki olmayan sayaç kimliği', 'board', () => withCounter(announce('p_a1', 0), { path: `announcementCounters/${CLUB}` })],
  ])('%s → deny', async (_title, role, build, existing = null) => {
    await seedFixture('base');
    if (existing !== null) await seedCounter(existing);
    await assertFails(commit(role, build()));
    expect(await countOf()).toBe(existing === null ? 0 : existing);
    for (const id of ['p_a1', 'p_a2', 'p_a3']) expect(await readDoc(`posts/${id}`)).toBeNull();
    expect(await readDoc(payloads.counterPath(OTHER_CLUB))).toBeNull();
  });

  test('sunucu gününün anahtarı geçer; aynı işlem komşu gün anahtarıyla reddedilir (istemci bir kez komşu günle yeniden dener)', async () => {
    await seedFixture('base');
    for (const ms of [yesterday(), tomorrow()]) await assertFails(commit('board', announce('p_a1', 0, { ms })));
    await assertSucceeds(commit('board', announce('p_a1', 0)));
    expect(await readDoc(payloads.counterPath(CLUB, yesterday()))).toBeNull();
    expect(await readDoc(payloads.counterPath(CLUB, tomorrow()))).toBeNull();
    expect(await readDoc(today())).toMatchObject({ count: 1, day: payloads.istanbulDay().day });
  });

  test('sayaç doğrudan yazılamaz: yönetici mutlak değerle düşüremez, süper admin sıfırlayamaz', async () => {
    await seedFixture('base');
    await seedCounter(LIMIT);
    const reset = { op: 'update', path: today(), data: { count: 0, updatedAt: serverTimestamp() } };
    for (const role of ['board', 'president', 'super']) await assertFails(commit(role, { reset }));
    expect(await countOf()).toBe(LIMIT);
  });
});
