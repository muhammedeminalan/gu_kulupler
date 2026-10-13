'use strict';
// T-19 — `savedPosts/{userId}_{postId}` (rules-spec §3.14; PLAN §11.1 satır 16; sözleşme §6.a madde 7, 8).
//
//  1. Rol × işlem matrisi: `expectations/saved_posts.json` (yalnızca sahibi okur / yazar; kayıt için
//     gönderiyi görmek gerekir; kaldırma / geri alma üyelik aramaz).
//  2. Kayıt (C) biçimi ve yeniden kaydetme / Geri al ayrımı (`savedAt`).
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { Timestamp, doc, setDoc, updateDoc } = require('firebase/firestore');
const { contextFor, CLUB, OTHER_CLUB } = require('../helpers/contexts');
const { readDoc, seedFixture } = require('../helpers/fixtures');
const { runMatrix } = require('../helpers/matrix');
const payloads = require('../helpers/payloads');

const BOARD = 'u_board';
const OWN = `savedPosts/${BOARD}_p01`;
const MEMBER_SAVED = 'savedPosts/u_member_p01';
const NO_EDIT = Object.freeze({});
const clientTime = () => Timestamp.fromMillis(Date.now() - 60 * 1000);
const dbOf = (role) => contextFor(role).firestore();
const expectWrite = (request, expected) => (expected === 'allow' ? assertSucceeds(request) : assertFails(request));
const saved = (extra, postId = 'p01') => payloads.savedCreate({ club: CLUB, uid: BOARD, postId }, extra);

runMatrix('saved_posts.json');

describe('savedPosts · create — biçim (rules-spec §3.14 C)', () => {
  // Satır: [başlık, yük, beklenti, veri düzenlemesi?, belge yolu?]. Bağlam: yönetim kurulu üyesi.
  test.each([
    ['istemci biçimli gönderi (W-51)', saved({}, 'p02'), 'allow', NO_EDIT, `savedPosts/${BOARD}_p02`],
    ['kimlik ↔ postId uyuşmuyor', saved({}, 'p02'), 'deny'],
    ['başkası adına (userId)', saved({ userId: 'u_member' }), 'deny'],
    ['clubId gönderinin kulübü değil', saved({ clubId: OTHER_CLUB }), 'deny'],
    ['savedAt istemci saati', saved({ savedAt: clientTime() }), 'deny'],
    ['savedAt yok', saved({ savedAt: null }), 'deny'],
    ['beyaz liste dışı alan (note)', saved({ note: 'x' }), 'deny'],
    ['silinmiş doğan kayıt', saved({ isDeleted: true }), 'deny'],
    ['silinmiş gönderi', saved(), 'deny', { patch: { 'posts/p01': { isDeleted: true, deletedBy: BOARD } } }],
    ['gizli gönderi', saved(), 'deny', { patch: { 'posts/p01': { isHidden: true, hiddenBy: 'u_super' } } }],
    ['olmayan gönderi', saved({}, 'p_missing'), 'deny', NO_EDIT, `savedPosts/${BOARD}_p_missing`],
  ])('%s → %s', async (_title, data, expected, edit = NO_EDIT, path = OWN) => {
    await seedFixture('base', undefined, edit);
    await expectWrite(setDoc(doc(dbOf('board'), path), data), expected);
    if (expected === 'deny') expect(await readDoc(path)).toBeNull();
    else expect(Object.keys(await readDoc(path)).sort()).toEqual(['clubId', 'createdAt', 'deletedAt', 'deletedBy', 'isDeleted', 'postId', 'savedAt', 'updatedAt', 'userId']);
  });
});

describe('savedPosts · update — kaldır / Geri al / yeniden kaydet', () => {
  const update = (data) => updateDoc(doc(dbOf('member'), MEMBER_SAVED), data);

  test('kaldır → Geri al `savedAt` değerini korur; kaldır → yeniden kaydet sunucu zamanına yeniler', async () => {
    await seedFixture('base');
    const original = (await readDoc(MEMBER_SAVED)).savedAt.toMillis();
    await assertSucceeds(update(payloads.softDelete('u_member')));
    await assertFails(update(payloads.softDelete('u_member')));
    await assertSucceeds(update(payloads.restore()));
    expect((await readDoc(MEMBER_SAVED)).savedAt.toMillis()).toBe(original);

    await assertSucceeds(update(payloads.softDelete('u_member')));
    await assertSucceeds(update(payloads.savedResave()));
    const again = await readDoc(MEMBER_SAVED);
    expect(again).toMatchObject({ isDeleted: false, deletedAt: null, deletedBy: null });
    expect(again.savedAt.toMillis()).toBe(again.updatedAt.toMillis());
  });

  test.each([
    ['yeniden kaydederken savedAt istemci saati', { ...payloads.restore(), savedAt: clientTime() }],
    ['yeniden kaydederken başka gönderiye taşıma', { ...payloads.savedResave(), postId: 'p02' }],
    ['yeniden kaydederken kulüp değişimi', { ...payloads.savedResave(), clubId: OTHER_CLUB }],
    ['geri alırken sahibi değiştirme', { ...payloads.restore(), userId: BOARD }],
  ])('%s → deny', async (_title, data) => {
    await seedFixture('base', undefined, { patch: { [MEMBER_SAVED]: { isDeleted: true, deletedBy: 'u_member' } } });
    await assertFails(update(data));
    expect(await readDoc(MEMBER_SAVED)).toMatchObject({ isDeleted: true, postId: 'p01', userId: 'u_member', clubId: CLUB });
  });

  test('kaldırırken başkası adına silme (deletedBy) ve yürürlükteki kayıtta `savedAt` değişimi reddedilir', async () => {
    await seedFixture('base');
    await assertFails(update(payloads.softDelete(BOARD)));
    await assertFails(update({ savedAt: payloads.savedResave().savedAt, ...payloads.baseUpdate() }));
  });
});
