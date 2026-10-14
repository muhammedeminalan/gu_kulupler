'use strict';
// T-30 — erişim çağrısı bütçesi: onay (M5), red (M6), çıkarma (M9) ve geri al (M12) — rules-spec §1.8; PLAN §11.3
// (M5 satırı); sözleşme docs/plans/T-30.md §4 f. Sınır: istek başına 20 erişim çağrısı (emülatör ayrı yolu bir kez
// sayar — helpers/budget.js). İşlem 5 yazımdır (üyelik · kulüp · yan belge · günlük · bildirim) ve hepsi aynı yolları
// okur. Ayrı yollar:
//   onay: users/{uid} · aktörün üyeliği · kulüp · users/{başvuran} · yan belge · hedef üyelik = 6
//   çıkarma: users/{uid} · aktörün üyeliği · kulüp · yan belge · hedef üyelik = 5 (kullanıcı durumu okunmaz — W-89 c)
// Ret bütçeden değil kuraldan gelir ("Service call error" yok).
const budget = require('../helpers/budget');
const { contextFor, CLUB } = require('../helpers/contexts');
const { readDoc, seedFixture } = require('../helpers/fixtures');
const payloads = require('../helpers/payloads');

const classify = (role, writes) => budget.classify(budget.buildBatch(contextFor(role).firestore(), Object.values(writes)).commit());
const outcome = async (role, writes) => (await classify(role, writes)).outcome;

describe('bütçe · yönetici üyelik kararları (T-30)', () => {
  test('onay + geri al, red, çıkarma + geri al (beş yazımlı işlemler) bütçe içinde geçer', async () => {
    await seedFixture('base');
    expect(await outcome('board', payloads.approveWrites({ club: CLUB, uid: 'u_board' }))).toBe(budget.Outcome.ok);
    expect(await outcome('board', payloads.undoDecisionWrites({ club: CLUB }))).toBe(budget.Outcome.ok);
    expect(await outcome('president', payloads.rejectWrites({ club: CLUB, uid: 'u_president' }))).toBe(budget.Outcome.ok);
    expect(await outcome('president', payloads.removeWrites({ club: CLUB, uid: 'u_president' }))).toBe(budget.Outcome.ok);
    expect(await outcome('president', payloads.undoRemovalWrites({ club: CLUB }))).toBe(budget.Outcome.ok);
    expect(await outcome('super', payloads.removeWrites({ club: CLUB, uid: 'u_super', target: 'u_board' }))).toBe(budget.Outcome.ok);
    expect((await readDoc(`clubs/${CLUB}`)).memberCount).toBe(4);
  });

  test('danışmanın ve silinmiş başvuranın onayı bütçeden değil kuraldan reddedilir', async () => {
    await seedFixture('base', undefined, { patch: { 'users/u_pending': { status: 'deleted' } } });
    expect(await outcome('advisor', payloads.approveWrites({ club: CLUB, uid: 'u_advisor' }))).toBe(budget.Outcome.permissionDenied);
    expect(await outcome('board', payloads.approveWrites({ club: CLUB, uid: 'u_board' }))).toBe(budget.Outcome.permissionDenied);
  });
});
