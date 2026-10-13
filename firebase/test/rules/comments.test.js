'use strict';
// T-19 — `comments/{commentId}` (rules-spec §3.6; PLAN §11.1 satır 8; sözleşme §6.a madde 5, 6, 13).
//
//  1. Rol × işlem matrisi: `expectations/comments.json` (okuma; ekleme / silme / geri alma yalnızca
//     `posts.commentCount ±1` ile aynı batch'te; gizleme süper admine; düzenleme kapalı).
//  2. Ekleme (C): alan beyaz listesi, sınırlar, gönderi ↔ kulüp eşliği, W-51 iki biçim.
// Sayaç–yorum eşliği ve saldırı vakaları `counters.test.js`, sorgu sözleşmesi `queries.test.js`.
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { Timestamp } = require('firebase/firestore');
const budget = require('../helpers/budget');
const { contextFor, CLUB, OTHER_CLUB } = require('../helpers/contexts');
const { readDoc, seedFixture } = require('../helpers/fixtures');
const { runMatrix } = require('../helpers/matrix');
const payloads = require('../helpers/payloads');

const MEMBER = 'u_member';
const NEW_PATH = 'comments/cm_new';
const NO_EDIT = Object.freeze({});

const commit = (role, writes) => budget.buildBatch(contextFor(role).firestore(), Object.values(writes)).commit();
const expectWrite = (request, expected) => (expected === 'allow' ? assertSucceeds(request) : assertFails(request));
/** Üyenin yorum batch'i (yorum + sayaç); `extra` yorum alanlarını ezer / ekler. */
const add = (extra, postId = 'p01') => {
  const writes = payloads.addCommentWrites({ club: CLUB, uid: MEMBER, postId });
  return { ...writes, comment: { ...writes.comment, data: { ...writes.comment.data, ...extra } } };
};

runMatrix('comments.json');

describe('comments · create — biçim ve sınırlar (rules-spec §3.6 C)', () => {
  test('yorum yalnızca beklenen alanları taşır (istemci biçimi: hiddenBy / hiddenAt anahtarı yok)', async () => {
    await seedFixture('base');
    await assertSucceeds(commit('member', add()));
    const comment = await readDoc(NEW_PATH);
    expect(Object.keys(comment).sort()).toEqual([
      'authorId', 'clubId', 'createdAt', 'deletedAt', 'deletedBy', 'isDeleted', 'isHidden', 'postId', 'text', 'updatedAt',
    ]);
    expect(comment).toMatchObject({ postId: 'p01', clubId: CLUB, authorId: MEMBER, isHidden: false, isDeleted: false });
  });

  // Satır: [başlık, yorum alanı ezmesi, beklenti, veri düzenlemesi?, gönderi?].
  test.each([
    ['metin tam sınırda (500)', { text: 'a'.repeat(500) }, 'allow'],
    ['seed biçimi: hiddenBy / hiddenAt açık null (W-51)', { hiddenBy: null, hiddenAt: null }, 'allow'],
    ['istemci biçimli gönderiye yorum (W-51)', {}, 'allow', NO_EDIT, 'p02'],
    ['boş metin', { text: '' }, 'deny'],
    ['yalnızca boşluktan oluşan metin', { text: ' \n ' }, 'deny'],
    ['metin sınırın üstünde (501)', { text: 'a'.repeat(501) }, 'deny'],
    ['başkası adına (authorId)', { authorId: 'u_board' }, 'deny'],
    ['clubId gönderinin kulübü değil', { clubId: OTHER_CLUB }, 'deny'],
    ['gizli doğan yorum', { isHidden: true }, 'deny'],
    ['hiddenBy dolu', { hiddenBy: MEMBER }, 'deny'],
    ['silinmiş doğan yorum', { isDeleted: true }, 'deny'],
    ['createdAt istemci saati', { createdAt: Timestamp.fromMillis(Date.now() - 60 * 1000) }, 'deny'],
    ['beyaz liste dışı alan (likeCount)', { likeCount: 0 }, 'deny'],
    ['silinmiş gönderiye yorum', {}, 'deny', { patch: { 'posts/p01': { isDeleted: true, deletedBy: 'u_board' } } }],
    ['gizli gönderiye yorum', {}, 'deny', { patch: { 'posts/p01': { isHidden: true, hiddenBy: 'u_super' } } }],
    ['olmayan gönderiye yorum', {}, 'deny', NO_EDIT, 'p_missing'],
  ])('%s → %s', async (_title, extra, expected, edit = NO_EDIT, postId = 'p01') => {
    await seedFixture('base', undefined, edit);
    await expectWrite(commit('member', add(extra, postId)), expected);
    if (expected === 'deny') expect(await readDoc(NEW_PATH)).toBeNull();
    else expect((await readDoc(NEW_PATH)).authorId).toBe(MEMBER);
  });

  test('var olan yorumun üzerine yeniden yazım (set) reddedilir', async () => {
    await seedFixture('base');
    const writes = payloads.addCommentWrites({ club: CLUB, uid: MEMBER, commentId: 'cm01' });
    await assertFails(commit('member', writes));
    expect((await readDoc('comments/cm01')).text).toBe('Rules testi yorumu.');
  });
});
