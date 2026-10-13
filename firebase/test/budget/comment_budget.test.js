'use strict';
// T-19 — erişim çağrısı bütçesi: yorum ekleme / silme (rules-spec §1.8; PLAN §11.3 satır 6).
// Ayrı yollar: users/{uid} · üyelik · gönderi · yorum (4) — yorum kuralı gönderiyi (get + getAfter),
// gönderinin sayaç dalı yorumu (exists / get + getAfter) okur. Ret bütçeden değil kuraldan gelir.
const budget = require('../helpers/budget');
const { contextFor, CLUB } = require('../helpers/contexts');
const { seedFixture } = require('../helpers/fixtures');
const payloads = require('../helpers/payloads');

const classify = (role, writes) => budget.classify(budget.buildBatch(contextFor(role).firestore(), Object.values(writes)).commit());

describe('bütçe · yorum ekleme ve moderasyon silmesi (T-19)', () => {
  test('yorum + commentCount +1 ve yöneticinin silmesi bütçe içinde geçer; sayaçsız yorum kuraldan reddedilir', async () => {
    await seedFixture('base');
    const add = payloads.addCommentWrites({ club: CLUB, uid: 'u_member' });
    expect((await classify('member', add)).outcome).toBe(budget.Outcome.ok);
    expect((await classify('board', payloads.removeCommentWrites({ uid: 'u_board', commentId: 'cm_new' }))).outcome).toBe(budget.Outcome.ok);
    const alone = { comment: payloads.addCommentWrites({ club: CLUB, uid: 'u_member', commentId: 'cm_alone' }).comment };
    expect((await classify('member', alone)).outcome).toBe(budget.Outcome.permissionDenied);
  });
});
