'use strict';
// T-45 (karar 3, 2026-10-15) — `reportCounters/{uid}_{yyyyMMdd}` ve günlük şikayet kotası: kullanıcı başına
// Istanbul günü başına en çok `Limits.reportDailyLimit` (20) şikayet (rules-spec §3.10, §3.18, §4; PLAN §11.1
// satır 22). Duyuru sayacının kalıbı (T-19 — `announcement_limit.test.js`, W-50, CD-129) aynen uygulanır.
//
//  1. Rol × işlem matrisi: `expectations/report_counters.json` (yalnızca sahibi okur; olmayan kendi sayacı boş
//     döner; sayaç tek başına, doğrudan ya da silme ile yazılamaz).
//  2. Kota: 1.–20. şikayet geçer (count 1 → 20), 21. reddedilir (sayaçlı da sayaçsız da); önceki günün dolu
//     sayacı bugünü etkilemez; çözülen şikayet hakkı iade etmez.
//  3. İki yönlü bağ: sayaç ↔ şikayet (`reportId`); tek artışla iki şikayet, var olan şikayeti gösteren
//     işaretçi, başkasının sayacı, mutlak değer / azaltma / sıfırlama → ret.
//  4. Gün anahtarı (W-50): Rules günü `request.time + 3 sa`'ten hesaplar ve eşitlik toleranssızdır — dün / yarın
//     anahtarı ve yanlış `day` alanı reddedilir, sunucu günü geçer (istemci bir kez komşu günle yeniden dener).
const path = require('node:path');
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, getDoc, increment, serverTimestamp } = require('firebase/firestore');
const budget = require('../helpers/budget');
const { contextFor, CLUB } = require('../helpers/contexts');
const { readDoc, seedDocs, seedFixture } = require('../helpers/fixtures');
const { runMatrix } = require('../helpers/matrix');
const payloads = require('../helpers/payloads');

const REPO_ROOT = path.resolve(__dirname, '..', '..', '..');
const limits = require(path.join(REPO_ROOT, 'tool', 'lib', 'dart_sources.js')).readLimits(REPO_ROOT).ints;

const UID = 'u_student';
const DAY_MS = payloads.DAY_MS;
const ISTANBUL_OFFSET_MS = 3 * 60 * 60 * 1000;
const SETTLE_MS = 5000;
const LIMIT = limits.reportDailyLimit;

const commit = (role, writes) => budget.buildBatch(contextFor(role).firestore(), Object.values(writes)).commit();
const drop = (writes, name) => Object.fromEntries(Object.entries(writes).filter(([key]) => key !== name));
const today = (uid = UID) => payloads.reportCounterPath(uid);
const countOf = async (p = today()) => ((await readDoc(p)) || { count: 0 }).count;
/** Temel veri kümesindeki kulübe ait, şikayet edilebilir `i`. gönderi (hedef VAR olmalı — CD-137 madde 8u). */
const post = (i) => ({ type: 'post', id: `t_${i}`, clubId: CLUB });
const report = (i, extra = {}) => payloads.reportWrites({ uid: UID, target: post(i), ...extra });
const reportPath = (i, uid = UID) => `reports/${uid}_post_t_${i}`;
/** Sayaç yazımını ezer (yol ve / veya alanlar). */
const withCounter = (writes, { path: p, data }) => ({ ...writes, counter: { ...writes.counter, path: p || writes.counter.path, data: { ...writes.counter.data, ...data } } });

/** Temel veri kümesi + `n` hedef gönderi. */
async function seedTargets(n = LIMIT + 2) {
  await seedFixture('base');
  await seedDocs(Object.fromEntries(Array.from({ length: n }, (_, i) => [`posts/t_${i}`, { clubId: CLUB }])));
}

/** Bugünün sayacını kuralları atlayarak kurar; `withRef: false` → `reportId` anahtarı hiç yazılmaz (W-51). */
const seedCounter = (count, { uid = UID, ms, withRef = true } = {}) =>
  seedDocs({ [payloads.reportCounterPath(uid, ms)]: { userId: uid, day: payloads.istanbulDay(ms).day, count, updatedAt: serverTimestamp(), ...(withRef ? { reportId: null } : {}) } });

/** Istanbul gün sınırına `SETTLE_MS`'ten az kaldıysa sınırı bekler (anahtar ve istek aynı güne düşsün). */
async function settleDay() {
  const left = DAY_MS - ((Date.now() + ISTANBUL_OFFSET_MS) % DAY_MS);
  if (left < SETTLE_MS) await new Promise((resolve) => setTimeout(resolve, left + 50));
}

beforeEach(settleDay);

runMatrix('report_counters.json');

describe('şikayet kotası · Dart Limits ↔ kullanıcı kararı', () => {
  test('Limits.reportDailyLimit = 20 (T-45 karar 3); sayaç yolu FirestoreIds.reportCounter biçiminde', () => {
    expect(LIMIT).toBe(20);
    expect(payloads.reportCounterPath(UID, Date.UTC(2027, 1, 3, 12))).toBe(`reportCounters/${UID}_20270203`);
    expect(payloads.reportCounterPath(UID, Date.UTC(2026, 9, 13, 21, 0, 0))).toBe(`reportCounters/${UID}_20261014`);
  });
});

describe('şikayet kotası · kullanıcı başına günde 20 şikayet (T-45 karar 3)', () => {
  test('1.–20. şikayet geçer (count 1 → 20), 21. reddedilir; sayaç son şikayeti gösterir', async () => {
    await seedTargets();
    for (let i = 0; i < LIMIT; i += 1) await assertSucceeds(commit('student', report(i)));
    const counter = await readDoc(today());
    expect(Object.keys(counter).sort()).toEqual(['count', 'day', 'reportId', 'updatedAt', 'userId']);
    expect(counter).toMatchObject({ userId: UID, day: payloads.istanbulDay().day, count: LIMIT, reportId: `${UID}_post_t_${LIMIT - 1}` });

    await assertFails(commit('student', report(LIMIT)));
    await assertFails(commit('student', drop(report(LIMIT), 'counter')));
    expect(await readDoc(reportPath(LIMIT))).toBeNull();
    expect(await countOf()).toBe(LIMIT);
  });

  test('20. şikayet (19 → 20) geçer; dolu sayaçta 21. hem sayaçlı hem sayaçsız reddedilir', async () => {
    await seedTargets();
    await seedCounter(LIMIT - 1);
    await assertSucceeds(commit('student', report(0)));
    expect(await countOf()).toBe(LIMIT);
    await assertFails(commit('student', report(1)));
    await assertFails(commit('student', drop(report(1), 'counter')));
    await assertFails(commit('student', withCounter(report(1), { data: { count: LIMIT } })));
    expect(await readDoc(reportPath(1))).toBeNull();
  });

  test.each([
    ['seed biçimi (reportId: null)', true],
    ['istemci biçimi (reportId anahtarı yok — W-51)', false],
  ])('var olan sayaç artar: %s', async (_title, withRef) => {
    await seedTargets();
    await seedCounter(3, { withRef });
    await assertSucceeds(commit('student', report(0)));
    expect(await readDoc(today())).toMatchObject({ count: 4, reportId: reportPath(0).slice('reports/'.length) });
  });

  test('kota kişiseldir: başka kullanıcının dolu sayacı bu kullanıcıyı etkilemez', async () => {
    await seedTargets();
    await seedCounter(LIMIT, { uid: 'u_member' });
    await assertSucceeds(commit('student', report(0)));
    expect(await countOf()).toBe(1);
    expect(await countOf(today('u_member'))).toBe(LIMIT);
  });

  test('önceki günün dolu sayacı bugünü etkilemez; çözülen şikayet hakkı iade etmez', async () => {
    await seedTargets();
    const yesterday = Date.now() - DAY_MS;
    await seedCounter(LIMIT, { ms: yesterday });
    await assertSucceeds(commit('student', report(0)));
    expect(await countOf()).toBe(1);
    expect(await countOf(payloads.reportCounterPath(UID, yesterday))).toBe(LIMIT);
    // Süper admin şikayeti çözer: sayaç değişmez (iade yok — yeni gün yeni belgedir).
    await assertSucceeds(commit('super', { r: { op: 'update', path: reportPath(0), data: { status: 'resolved', action: 'dismissed', resolvedAt: serverTimestamp(), resolvedBy: 'u_super', ...payloads.baseUpdate() } } }));
    expect(await countOf()).toBe(1);
  });

  test('sahibi bugünkü sayacını okur (istemci ön denetimi); olmayan sayaç boş döner; başkası okuyamaz', async () => {
    await seedTargets();
    const own = doc(contextFor('student').firestore(), today());
    expect((await assertSucceeds(getDoc(own))).exists()).toBe(false);
    await assertSucceeds(commit('student', report(0)));
    expect((await assertSucceeds(getDoc(own))).data().count).toBe(1);
    await assertFails(getDoc(doc(contextFor('member').firestore(), today())));
    await assertFails(getDoc(doc(contextFor('super').firestore(), today())));
  });
});

describe('şikayet kotası · sayaç ↔ şikayet eşliği ve gün anahtarı (W-50)', () => {
  const yesterday = () => Date.now() - DAY_MS;
  const tomorrow = () => Date.now() + DAY_MS;

  // Satır: [başlık, bağlam, yazım üreticisi, bugünün sayacı (önceden)?]. Hepsi ret; sayaç ve şikayetler değişmez.
  test.each([
    ['sayaç artışı olmadan şikayet', 'student', () => drop(report(0), 'counter')],
    ['şikayet olmadan sayaç', 'student', () => ({ counter: report(0).counter })],
    ['tek sayaç artışıyla iki şikayet', 'student', () => ({ ...report(0), second: report(1).report })],
    ['sayaç var olan şikayeti gösterir (şikayet bu işlemde değil)', 'member', () => ({ counter: payloads.reportWrites({ uid: 'u_member' }).counter })],
    ['sayaç başkasının şikayetini gösterir', 'student', () => withCounter(report(0), { data: { reportId: 'u_member_post_p01' } })],
    ['işaretçi yol taşıyor (kimlik değil)', 'student', () => withCounter(report(0), { data: { reportId: `reports/${UID}_post_t_0` } })],
    ['işaretçisiz sayaç', 'student', () => withCounter(report(0), { data: { reportId: null } })],
    ['ilk yazımda count 2', 'student', () => withCounter(report(0), { data: { count: 2 } })],
    ['count artmıyor (3 → 3)', 'student', () => withCounter(report(0), { data: { count: 3 } }), 3],
    ['count increment(2)', 'student', () => withCounter(report(0), { data: { count: increment(2) } }), 3],
    ['count azalır (5 → 4)', 'student', () => withCounter(report(0), { data: { count: 4 } }), 5],
    ['dolu sayaç sıfırlanarak yeniden kullanılır (20 → 1)', 'student', () => withCounter(report(0), { data: { count: 1 } }), LIMIT],
    ['sayaçta beyaz liste dışı alan', 'student', () => withCounter(report(0), { data: { note: 'x' } })],
    ['sayaç updatedAt taşımıyor', 'student', () => { const w = report(0); const { updatedAt: _omitted, ...data } = w.counter.data; return { ...w, counter: { ...w.counter, data } }; }],
    ['sayaçta userId başka kullanıcı', 'student', () => withCounter(report(0), { data: { userId: 'u_member' } })],
    ['başka kullanıcının sayacı (kimlik u_member, alan u_student)', 'student', () => withCounter(report(0), { path: payloads.reportCounterPath('u_member') })],
    ['başka kullanıcının sayacı (kimlik ve alan u_member)', 'student', () => withCounter(report(0), { path: payloads.reportCounterPath('u_member'), data: { userId: 'u_member' } })],
    ['dünün anahtarı (komşu gün — tolerans yok)', 'student', () => report(0, { ms: yesterday() })],
    ['yarının anahtarı (komşu gün — tolerans yok)', 'student', () => report(0, { ms: tomorrow() })],
    ['doğru anahtar, yanlış `day` alanı', 'student', () => withCounter(report(0), { data: { day: payloads.istanbulDay(yesterday()).day } })],
    ['`day` sıfır dolgusuz / biçimsiz', 'student', () => withCounter(report(0), { data: { day: payloads.istanbulDay().key } })],
    ['gün eki olmayan sayaç kimliği', 'student', () => withCounter(report(0), { path: `reportCounters/${UID}` })],
    ['askıdaki hesap', 'susp', () => payloads.reportWrites({ uid: 'u_susp', target: post(0) })],
  ])('%s → deny', async (_title, role, build, existing = null) => {
    await seedTargets();
    if (existing !== null) await seedCounter(existing);
    const before = await readDoc('reports/u_member_post_p01');
    await assertFails(commit(role, build()));
    expect(await countOf()).toBe(existing === null ? 0 : existing);
    for (const i of [0, 1]) expect(await readDoc(reportPath(i))).toBeNull();
    expect(await readDoc('reports/u_susp_post_t_0')).toBeNull();
    expect(await readDoc(payloads.reportCounterPath('u_member'))).toBeNull();
    expect(await readDoc('reports/u_member_post_p01')).toEqual(before);
  });

  test('sunucu gününün anahtarı geçer; aynı işlem komşu gün anahtarıyla reddedilir (istemci bir kez komşu günle yeniden dener)', async () => {
    await seedTargets();
    for (const ms of [yesterday(), tomorrow()]) await assertFails(commit('student', report(0, { ms })));
    await assertSucceeds(commit('student', report(0)));
    expect(await readDoc(payloads.reportCounterPath(UID, yesterday()))).toBeNull();
    expect(await readDoc(payloads.reportCounterPath(UID, tomorrow()))).toBeNull();
    expect(await readDoc(today())).toMatchObject({ count: 1, day: payloads.istanbulDay().day });
  });

  test('sayaç doğrudan yazılamaz: sahibi mutlak değerle düşüremez, süper admin sıfırlayamaz', async () => {
    await seedTargets();
    await seedCounter(LIMIT);
    const reset = { op: 'update', path: today(), data: { count: 0, updatedAt: serverTimestamp() } };
    for (const role of ['student', 'super']) await assertFails(commit(role, { reset }));
    expect(await countOf()).toBe(LIMIT);
  });
});
