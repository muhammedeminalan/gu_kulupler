'use strict';
// T-15 — `blocks/{blockerId}_{blockedId}` (rules-spec §3.13; PLAN §11.1 satır 15).
//
//  1. Rol × işlem matrisi: `expectations/blocks.json` (yalnızca engelleyen okur / yazar; engellenen
//     kullanıcı ve süper admin dahil başkası okuyamaz; askıdaki hesap okur ama yazamaz).
//  2. Akış: engelle (C) → engeli kaldır (soft delete) → yeniden engelle / Geri al (restore).
//     Hard delete yoktur (D-10); kaldırılmış engelin üzerine ikinci `set` reddedilir (repository restore eder).
//  3. Alan beyaz listesi, kimlik biçimi, sunucu zamanı.
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { Timestamp, doc, serverTimestamp, setDoc, updateDoc } = require('firebase/firestore');
const { contextFor } = require('../helpers/contexts');
const { readDoc, seedFixture } = require('../helpers/fixtures');
const { runMatrix } = require('../helpers/matrix');
const payloads = require('../helpers/payloads');

const MEMBER = 'u_member';
const TARGET = 'u_board';
const NEW_BLOCK = `blocks/${MEMBER}_${TARGET}`;
const EXISTING = 'blocks/u_member_u_student';
const SUSP_BLOCK = 'blocks/u_susp_u_student';

const dbOf = (role) => contextFor(role).firestore();
const clientTime = () => Timestamp.fromMillis(Date.now() - 60 * 1000);
const expectWrite = (request, expected) => (expected === 'allow' ? assertSucceeds(request) : assertFails(request));
const omit = (object, keys) => Object.fromEntries(Object.entries(object).filter(([key]) => !keys.includes(key)));
/** Kaldırılmış (soft delete edilmiş) engel: kurallar kapalıyken kurulur. */
const removed = (path, by) => ({ patch: { [path]: { isDeleted: true, deletedBy: by, deletedAt: clientTime() } } });

runMatrix('blocks.json');

describe('blocks · akış: engelle → kaldır → geri al (rules-spec §3.13)', () => {
  test('engelleyen: create → soft delete → restore; belge hiçbir adımda silinmez', async () => {
    await seedFixture('base');
    const ref = doc(dbOf('member'), NEW_BLOCK);

    await assertSucceeds(setDoc(ref, payloads.blockCreate(MEMBER, TARGET)));
    expect(await readDoc(NEW_BLOCK)).toMatchObject({ blockerId: MEMBER, blockedId: TARGET, isDeleted: false });

    await assertSucceeds(updateDoc(ref, payloads.softDelete(MEMBER)));
    expect(await readDoc(NEW_BLOCK)).toMatchObject({ isDeleted: true, deletedBy: MEMBER });

    // Kaldırılmış engelin üzerine yeniden `set` bir update'tir ve reddedilir: block() restore eder.
    await assertFails(setDoc(ref, payloads.blockCreate(MEMBER, TARGET)));
    await assertSucceeds(updateDoc(ref, payloads.restore()));
    expect(await readDoc(NEW_BLOCK)).toMatchObject({ blockerId: MEMBER, blockedId: TARGET, isDeleted: false, deletedAt: null, deletedBy: null });
  });

  test('kaldırılmış engeli yalnızca engelleyen okur ve geri alır', async () => {
    await seedFixture('base', undefined, removed(EXISTING, MEMBER));
    for (const role of ['student', 'board', 'super']) {
      await assertFails(updateDoc(doc(dbOf(role), EXISTING), payloads.restore()));
    }
    expect((await readDoc(EXISTING)).isDeleted).toBe(true);
    await assertSucceeds(updateDoc(doc(dbOf('member'), EXISTING), payloads.restore()));
    expect((await readDoc(EXISTING)).isDeleted).toBe(false);
  });

  test('askıdaki hesap kaldırılmış engelini geri alamaz (§11.1 satır 15 susp: S/R yok)', async () => {
    await seedFixture('base', undefined, removed(SUSP_BLOCK, 'u_susp'));
    await assertFails(updateDoc(doc(dbOf('susp'), SUSP_BLOCK), payloads.restore()));
    expect((await readDoc(SUSP_BLOCK)).isDeleted).toBe(true);
  });
});

describe('blocks · create — alan beyaz listesi ve kimlik (rules-spec §3.13 C)', () => {
  // Satır: [başlık, belge yolu, eklenen / ezilen alanlar, çıkarılan anahtarlar, beklenti].
  test.each([
    ['blockerId başka kullanıcı', NEW_BLOCK, { blockerId: 'u_president' }, [], 'deny'],
    ['başkası adına engel (belge kimliği başka engelleyen)', `blocks/u_president_${TARGET}`, { blockerId: 'u_president' }, [], 'deny'],
    ['kimlik alanlarla uyuşmuyor (blockedId farklı)', NEW_BLOCK, { blockedId: 'u_president' }, [], 'deny'],
    ['blockedId boş', `blocks/${MEMBER}_`, { blockedId: '' }, [], 'deny'],
    ['blockedId dizgi değil', NEW_BLOCK, { blockedId: 7 }, [], 'deny'],
    ['beyaz liste dışı alan (reason)', NEW_BLOCK, { reason: 'spam' }, [], 'deny'],
    ['isDeleted: true', NEW_BLOCK, { isDeleted: true }, [], 'deny'],
    ['createdAt istemci saati', NEW_BLOCK, { createdAt: clientTime() }, [], 'deny'],
    ['updatedAt yok', NEW_BLOCK, {}, ['updatedAt'], 'deny'],
    ['deletedAt / deletedBy anahtarı yok (W-51)', NEW_BLOCK, {}, ['deletedAt', 'deletedBy'], 'allow'],
  ])('%s', async (_title, path, extra, removedKeys, expected) => {
    await seedFixture('base');
    const payload = omit(payloads.blockCreate(MEMBER, TARGET, extra), removedKeys);
    await expectWrite(setDoc(doc(dbOf('member'), path), payload), expected);
    if (expected === 'deny') expect(await readDoc(path)).toBeNull();
  });
});

describe('blocks · update — yalnızca soft delete / restore biçimi', () => {
  test.each([
    ['blockedId değişiyor', { blockedId: 'u_president', ...payloads.baseUpdate() }],
    ['blockerId değişiyor', { blockerId: 'u_board', ...payloads.baseUpdate() }],
    ['soft delete: deletedBy başka kullanıcı', { ...payloads.softDelete(MEMBER), deletedBy: 'u_board' }],
    ['soft delete: deletedAt istemci saati', { ...payloads.softDelete(MEMBER), deletedAt: clientTime() }],
    ['soft delete ile birlikte blockedId', { ...payloads.softDelete(MEMBER), blockedId: 'u_president' }],
    ['soft delete: updatedAt yok', omit(payloads.softDelete(MEMBER), ['updatedAt'])],
    ['createdAt değişiyor', { createdAt: serverTimestamp(), ...payloads.baseUpdate() }],
  ])('%s → deny', async (_title, payload) => {
    await seedFixture('base');
    const before = await readDoc(EXISTING);
    await assertFails(updateDoc(doc(dbOf('member'), EXISTING), payload));
    expect(await readDoc(EXISTING)).toEqual(before);
  });
});
