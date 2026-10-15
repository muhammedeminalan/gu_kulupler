'use strict';
// T-37 — erişim çağrısı bütçesi: süper admin işlemleri (rules-spec §1.8; PLAN §11.3; sözleşme docs/plans/T-37.md §4 a.9).
// Sınır: işlem / belge başına 10, istek başına 20 erişim çağrısı (emülatör ayrı yolu bir kez sayar — helpers/budget.js).
// Ayrı yollar (tekil):
//   başkan atama, yeni hedef (8 yazım): hedef üyelik · eski başkanın üyeliği · kulüp · yan belge · users/{hedef} ·
//     hedefin hesap belgesi (contact e-postası) · contact · users/{süper} (bildirim `activeUser`) · süper adminin
//     üyeliği (yan belge `ownMembershipUnmoved` / `isManager`) = 9
//   kulüp oluşturma (3 yazım): başkanın üyeliği · kulüp · users/{başkan} · başkanın hesabı · contact = 5
//   danışman bağlama (3 yazım): hedef üyelik · kulüp · users/{hedef} · hedefin hesabı · contact = 5
//   kullanıcı askısı (2 yazım): users/{uid} · private/account = 2 · kulüp askısı: 0
//   şikayet grubu çözümü: `removed` → hedef gönderi (getAfter) · users/{süper} (bildirim) = 2 — şikayet sayısından
//     BAĞIMSIZ (alıcı ↔ şikayet bağı aranmaz — §4 a.6). En kötü durum tek batch: n = 224 → 2n + 1 = 449 yazım
//     (Limits.batchMaxWrites = 450).
// Ret bütçeden değil kuraldan gelir ("Service call error" yok).
const budget = require('../helpers/budget');
const { contextFor } = require('../helpers/contexts');
const { readDoc, seedDocs, seedFixture } = require('../helpers/fixtures');
const admin = require('../helpers/admin_payloads');

const classify = (role, writes) => budget.classify(budget.buildBatch(contextFor(role).firestore(), Object.values(writes)).commit());
const outcome = async (role, writes) => (await classify(role, writes)).outcome;

/** Limits.batchMaxWrites (packages/gu_data/lib/src/constants/limits.dart). */
const BATCH_MAX_WRITES = 450;

describe('bütçe · süper admin işlemleri (T-37)', () => {
  test('başkan atama (yeni hedef), kulüp oluşturma, danışman bağlama, kullanıcı / kulüp askısı bütçe içinde geçer', async () => {
    await seedFixture('base', undefined, { patch: { 'clubs/c02': { advisor: { ...admin.ADVISOR, userId: null } } } });
    expect(await outcome('super', admin.assignWrites())).toBe(budget.Outcome.ok);
    expect(await outcome('super', admin.createClubWrites({ president: 'u_board' }))).toBe(budget.Outcome.ok);
    expect(await outcome('super', admin.advisorLinkWrites({ club: 'c02', uid: 'u_student' }))).toBe(budget.Outcome.ok);
    expect(await outcome('super', admin.suspendUserWrites())).toBe(budget.Outcome.ok);
    expect(await outcome('super', admin.suspendClubWrites({ club: 'c02' }))).toBe(budget.Outcome.ok);
    expect(await readDoc('clubs/c01')).toMatchObject({ presidentId: 'u_student', memberCount: 6 });
  });

  test('şikayet grubu en kötü durum: 224 şikayet + gizleme + 224 report_resolved = 449 yazım tek batch', async () => {
    await seedFixture('base');
    const reporters = Array.from({ length: 224 }, (_, i) => `u_r${String(i).padStart(3, '0')}`);
    await seedDocs(Object.fromEntries(reporters.map((r) => [`reports/${r}_post_p01`, admin.reportDoc(r, 'post', 'p01', 'c01')])));
    const writes = admin.resolveWrites({ reporters });
    expect(Object.keys(writes)).toHaveLength(2 * reporters.length + 1);
    expect(Object.keys(writes).length).toBeLessThanOrEqual(BATCH_MAX_WRITES);
    expect(await outcome('super', writes)).toBe(budget.Outcome.ok);
    expect(await readDoc(`reports/${reporters[223]}_post_p01`)).toMatchObject({ status: 'resolved', action: 'removed' });
  });

  test('eksik parçalı atama ve gizlemesiz removed bütçeden değil kuraldan reddedilir', async () => {
    await seedFixture('base');
    const { counter: _counter, ...withoutSide } = admin.assignWrites();
    expect(await outcome('super', withoutSide)).toBe(budget.Outcome.permissionDenied);
    expect(await outcome('super', admin.resolveWrites({ reporters: ['u_member'], hide: false }))).toBe(budget.Outcome.permissionDenied);
  });
});
