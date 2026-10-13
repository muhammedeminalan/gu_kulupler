'use strict';
// T-19 — `posts/{postId}/votes/{uid}` (rules-spec §3.5; PLAN §11.1 satır 7; sözleşme §6.a madde 4).
//
//  1. Rol × işlem matrisi: `expectations/votes.json` (okuma gönderiyle aynı görünürlükte; oy yalnızca
//     yazma yetkili üyeye; U / D her bağlamda ret; koleksiyon grubu kapalı).
//  2. Oy (C): bir kez, kendi adına, açık ankete, var olan seçeneğe; biçim (`optionId`, `createdAt`).
// Oy sayacı alanı yoktur: sayım `where optionId == x` + `count()` (sorgu biçimi `queries.test.js`).
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { Timestamp, doc, setDoc, updateDoc } = require('firebase/firestore');
const { contextFor } = require('../helpers/contexts');
const { readDoc, seedFixture } = require('../helpers/fixtures');
const { runMatrix } = require('../helpers/matrix');
const payloads = require('../helpers/payloads');

const BOARD = 'u_board';
const VOTE = `posts/p01/votes/${BOARD}`;
const HOUR_MS = 60 * 60 * 1000;
const NO_EDIT = Object.freeze({});
/** İstemci biçimli anket (W-51): `p02` ankete çevrilir; null alanların anahtarı yoktur. */
const CLIENT_POLL = { patch: { 'posts/p02': { type: 'poll', poll: payloads.pollOf(['A', 'B', 'C']) } } };

const vote = (role, data, path = VOTE) => setDoc(doc(contextFor(role).firestore(), path), data);
const expectWrite = (request, expected) => (expected === 'allow' ? assertSucceeds(request) : assertFails(request));
const closed = (ms) => ({ 'posts/p01': { poll: { ...payloads.pollOf(), endsAt: Timestamp.fromMillis(Date.now() + ms) } } });

runMatrix('votes.json');

describe('votes · create — bir kez, açık ankete, var olan seçeneğe (rules-spec §3.5 votes C)', () => {
  test('oy belgesi yalnızca iki alan taşır; oy değiştirilemez ve ikinci kez verilemez (TST-10)', async () => {
    await seedFixture('base');
    await assertSucceeds(vote('board', payloads.voteCreate('o2')));
    const saved = await readDoc(VOTE);
    expect(Object.keys(saved).sort()).toEqual(['createdAt', 'optionId']);
    expect(saved.optionId).toBe('o2');
    // İkinci set update sayılır; alan güncellemesi de kapalıdır. Gönderi belgesi oydan etkilenmez.
    await assertFails(vote('board', payloads.voteCreate('o1')));
    await assertFails(vote('board', payloads.voteCreate('o2')));
    await assertFails(updateDoc(doc(contextFor('board').firestore(), VOTE), { optionId: 'o1' }));
    expect((await readDoc(VOTE)).optionId).toBe('o2');
    expect(await readDoc('posts/p01')).toMatchObject({ likeCount: 0, commentCount: 1 });
  });

  // Satır: [başlık, yük, beklenti, veri düzenlemesi?, oy yolu?]. Bağlam: yönetim kurulu üyesi (oy vermemiş).
  test.each([
    ['son seçenek (o2 / 2)', payloads.voteCreate('o2'), 'allow'],
    ['istemci biçimli ankette üçüncü seçenek (o3 / 3 — W-51)', payloads.voteCreate('o3'), 'allow', CLIENT_POLL, `posts/p02/votes/${BOARD}`],
    ['olmayan seçenek (o3 / 2)', payloads.voteCreate('o3'), 'deny'],
    ['istemci biçimli ankette olmayan seçenek (o4 / 3)', payloads.voteCreate('o4'), 'deny', CLIENT_POLL, `posts/p02/votes/${BOARD}`],
    ['serbest seçenek kimliği', payloads.voteCreate('evet'), 'deny'],
    ['seçenek kimliği dizgi değil', payloads.voteCreate(1), 'deny'],
    ['seçeneksiz oy', { createdAt: payloads.voteCreate('o1').createdAt }, 'deny'],
    ['fazladan alan (weight)', payloads.voteCreate('o1', { weight: 10 }), 'deny'],
    ['createdAt istemci saati', payloads.voteCreate('o1', { createdAt: Timestamp.fromMillis(Date.now() - HOUR_MS) }), 'deny'],
    ['süresi dolmuş anket', payloads.voteCreate('o1'), 'deny', { patch: closed(-HOUR_MS) }],
    ['süresi dolmak üzere olan anket (1 sa kaldı)', payloads.voteCreate('o1'), 'allow', { patch: closed(HOUR_MS) }],
    ['anket olmayan gönderi', payloads.voteCreate('o1'), 'deny', NO_EDIT, `posts/p02/votes/${BOARD}`],
    ['silinmiş anket', payloads.voteCreate('o1'), 'deny', { patch: { 'posts/p01': { isDeleted: true, deletedBy: BOARD } } }],
    ['gizli anket', payloads.voteCreate('o1'), 'deny', { patch: { 'posts/p01': { isHidden: true, hiddenBy: 'u_super' } } }],
    ['olmayan gönderi', payloads.voteCreate('o1'), 'deny', NO_EDIT, `posts/p_missing/votes/${BOARD}`],
  ])('%s → %s', async (_title, data, expected, edit = NO_EDIT, path = VOTE) => {
    await seedFixture('base', undefined, edit);
    await expectWrite(vote('board', data, path), expected);
    if (expected === 'deny') expect(await readDoc(path)).toBeNull();
    else expect((await readDoc(path)).optionId).toBe(data.optionId);
  });
});
