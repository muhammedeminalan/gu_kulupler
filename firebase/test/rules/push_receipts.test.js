'use strict';
// T-42 — `pushReceipts/{notificationId}` (rules-spec §3.17; sözleşme docs/plans/T-42.md §4 b.1, f; CD-165).
//
// Makbuzu YALNIZCA sunucu yazar (`sendPushOnNotificationCreated`, Admin SDK — Rules'u atlar): önce `create()`
// (zaten varsa çık → bildirim başına en çok bir push), sonra sonuç. İstemci hiçbir koşulda okuyamaz / yazamaz.
// Her bağlam × get / list / create / update reddi `deny_all.test.js` (kapalı koleksiyon bloğu, beklenti
// `expectations/push_receipts.json`), delete reddi `delete_denied.test.js`. Burada üç somut kötüye kullanım:
//  1. Alıcı kendi makbuzunu (teslim / jeton durumu) okuyamaz ve sorgulayamaz.
//  2. İstemci makbuzu ÖNCEDEN yazarak kendi ya da tahmin ettiği başkasının push'unu bastıramaz.
//  3. Güvenlik incelemesi (push freni): kapsam kilitleri de bu koleksiyondadır (`pushReceipts/once_{type}_{key}_{uid}`
//     — functions/src/lib/push_guard.ts); kimlik deterministik olduğundan istemci önceden yazıp push'u bastıramaz,
//     okuyup başkasının etkinlik / başvuru geçmişini çıkaramaz.
const { assertFails } = require('@firebase/rules-unit-testing');
const { collection, doc, getDoc, getDocs, query, serverTimestamp, setDoc, updateDoc, where } = require('firebase/firestore');
const { contextFor } = require('../helpers/contexts');
const { readDoc, seedFixture } = require('../helpers/fixtures');

const RECEIPT = 'pushReceipts/notification_push_1'; // fixtures.baseDocs: alıcı u_student

describe('pushReceipts · yalnızca sunucu (T-42, CD-165 b.1)', () => {
  test('alıcı kendi makbuzunu okuyamaz, kendi makbuzlarını sorgulayamaz ve güncelleyemez', async () => {
    await seedFixture('base');
    const db = contextFor('student').firestore();
    await assertFails(getDoc(doc(db, RECEIPT)));
    await assertFails(getDocs(query(collection(db, 'pushReceipts'), where('userId', '==', 'u_student'))));
    await assertFails(updateDoc(doc(db, RECEIPT), { status: 'filtered', updatedAt: serverTimestamp() }));
    expect(await readDoc(RECEIPT)).toMatchObject({ userId: 'u_student', status: 'sent' });
  });

  test.each(['student', 'president', 'super'])('%s · gelecekteki bildirimin makbuzunu önceden yazamaz (push bastırma)', async (role) => {
    await seedFixture('base');
    const path = `pushReceipts/announcement_${'a'.repeat(20)}_u_member`;
    const receipt = { userId: 'u_member', type: 'announcement', status: 'filtered', successCount: 0, failureCount: 0, createdAt: serverTimestamp(), updatedAt: serverTimestamp() };
    await assertFails(setDoc(doc(contextFor(role).firestore(), path), receipt));
    expect(await readDoc(path)).toBeNull();
  });

  test.each(['student', 'president', 'super'])('%s · kapsam kilidini (once_…) önceden yazamaz, okuyamaz, sorgulayamaz', async (role) => {
    await seedFixture('base');
    const db = contextFor(role).firestore();
    const path = `pushReceipts/once_event_new_${'b'.repeat(20)}_u_member`;
    await assertFails(setDoc(doc(db, path), { userId: 'u_member', type: 'event_new', kind: 'gate', createdAt: serverTimestamp() }));
    await assertFails(getDoc(doc(db, path)));
    await assertFails(getDocs(query(collection(db, 'pushReceipts'), where('kind', '==', 'gate'))));
    expect(await readDoc(path)).toBeNull();
  });
});
