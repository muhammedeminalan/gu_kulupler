'use strict';
// T-19 — erişim çağrısı bütçesi: gönderi yayını ve sabitleme (rules-spec §1.8; PLAN §11.3 satır 3).
// Sınır: tek yazımda 10, tek istekte 20 `get / exists / getAfter` (emülatör aynı yolu bir kez sayar).
// Aşım `permission-denied` + "Service call error" iletisi bırakır (`budget.classify` → `evaluation-error`);
// burada en ağır işlemlerin sınırın altında kaldığı (`ok`) ve reddin bütçeden değil kuraldan geldiği
// (`permission-denied`) gösterilir. Ayrı yol sayıları kural yorumlarındaki sayımla aynıdır:
//   bildirimli duyuru = users/{uid} · üyelik · kulüp · sayaç · gönderi (5)
//   yeniden sabitleme = users/{uid} · üyelik · kulüp · yeni gönderi · eski gönderi (5)
const budget = require('../helpers/budget');
const { contextFor, CLUB } = require('../helpers/contexts');
const { seedFixture } = require('../helpers/fixtures');
const payloads = require('../helpers/payloads');

const classify = (role, writes) => budget.classify(budget.buildBatch(contextFor(role).firestore(), Object.values(writes)).commit());
const PINNED = { patch: { 'posts/p01': { pinned: true }, [`clubs/${CLUB}`]: { pinnedPostId: 'p01' } } };

describe('bütçe · gönderi yayını ve sabitleme (T-19)', () => {
  test('bildirimli duyuru (gönderi + günlük + sayaç) bütçe içinde geçer; 3. duyuru bütçeden değil kuraldan reddedilir', async () => {
    await seedFixture('base');
    // En pahalı biçim: dört görselli duyuru (liste elemanları tek tek denetlenir — ifade sayısı sınırı).
    const publish = (postId, previousCount) => {
      const writes = payloads.createPostWrites({ club: CLUB, uid: 'u_board', type: 'announcement', pushSent: true, postId, previousCount });
      writes.post.data.images = [0, 1, 2, 3].map((i) => payloads.postImage(postId, i));
      return writes;
    };
    expect((await classify('board', publish('p_a1', 0))).outcome).toBe(budget.Outcome.ok);
    expect((await classify('board', publish('p_a2', 1))).outcome).toBe(budget.Outcome.ok);
    expect((await classify('board', publish('p_a3', 2))).outcome).toBe(budget.Outcome.permissionDenied);
  });

  test('yeniden sabitleme (eski + yeni gönderi + kulüp) ve sabit gönderiyi süper adminin silmesi bütçe içinde geçer', async () => {
    await seedFixture('base', undefined, PINNED);
    expect((await classify('board', payloads.pinWrites({ club: CLUB, postId: 'p02', oldPostId: 'p01' }))).outcome).toBe(budget.Outcome.ok);
    await seedFixture('base', undefined, PINNED);
    const remove = payloads.removePostWrites({ club: CLUB, uid: 'u_super', postId: 'p01', pinned: true });
    expect((await classify('super', remove)).outcome).toBe(budget.Outcome.ok);
  });
});
