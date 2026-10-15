'use strict';
// T-45 — erişim çağrısı bütçesi: günlük kotalı şikayet ve engel oluşturma (rules-spec §1.8; karar 3).
// Sınır: tek yazımda 10, tek istekte 20 `get / exists / getAfter` (emülatör aynı yolu bir kez sayar).
// Aşım `permission-denied` + "Service call error" iletisi bırakır (`budget.classify` → `evaluation-error`);
// burada işlemlerin sınırın altında kaldığı (`ok`) ve kota reddinin bütçeden değil kuraldan geldiği
// (`permission-denied`) gösterilir. Ayrı yol sayıları kural yorumlarındaki sayımla aynıdır:
//   şikayet (gönderi hedefi) = users/{uid} · hedef gönderi · şikayet sayacı · şikayet (4)
//   engel oluşturma          = users/{uid} · users/{blockedId} (2)
const { serverTimestamp } = require('firebase/firestore');
const budget = require('../helpers/budget');
const { contextFor, CLUB } = require('../helpers/contexts');
const { seedDocs, seedFixture } = require('../helpers/fixtures');
const payloads = require('../helpers/payloads');

const UID = 'u_student';
const classify = (role, writes) => budget.classify(budget.buildBatch(contextFor(role).firestore(), Object.values(writes)).commit());
const report = (id) => payloads.reportWrites({ uid: UID, target: { type: 'post', id, clubId: CLUB } });

describe('bütçe · şikayet kotası ve engel (T-45)', () => {
  test('şikayet + günün sayacı bütçe içinde geçer; dolu günde 21. şikayet bütçeden değil kuraldan reddedilir', async () => {
    await seedFixture('base');
    await seedDocs({ 'posts/t_a': { clubId: CLUB }, 'posts/t_b': { clubId: CLUB } });
    expect((await classify('student', report('t_a'))).outcome).toBe(budget.Outcome.ok);
    await seedDocs({
      [payloads.reportCounterPath(UID)]: { userId: UID, day: payloads.istanbulDay().day, count: 20, reportId: null, updatedAt: serverTimestamp() },
    });
    expect((await classify('student', report('t_b'))).outcome).toBe(budget.Outcome.permissionDenied);
  });

  test('engel oluşturma (engellenen kullanıcının varlığı dahil) bütçe içinde geçer; olmayan kullanıcı kuraldan reddedilir', async () => {
    await seedFixture('base');
    const block = (blocked) => ({ b: { op: 'set', path: `blocks/u_member_${blocked}`, data: payloads.blockCreate('u_member', blocked) } });
    expect((await classify('member', block('u_board'))).outcome).toBe(budget.Outcome.ok);
    expect((await classify('member', block('u_yok'))).outcome).toBe(budget.Outcome.permissionDenied);
  });
});
