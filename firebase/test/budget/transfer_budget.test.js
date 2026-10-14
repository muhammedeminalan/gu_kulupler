'use strict';
// T-30 — erişim çağrısı bütçesi: başkanlık devri (M11) ve rol değişimi (M10) — rules-spec §1.8; PLAN §11.3 (M11
// satırı); sözleşme docs/plans/T-30.md §4 f. Devir TEK işlemde 6 yazımdır (iki üyelik · kulüp · günlük · iki
// bildirim) ve hepsi aynı yolları okur. Ayrı yollar:
//   devir: users/{uid} · eski başkanın üyeliği · yeni başkanın üyeliği · kulüp · users/{yeni} = 5
//   rol: users/{uid} · aktörün üyeliği · hedef üyelik · kulüp = 4
// Ret bütçeden değil kuraldan gelir.
const budget = require('../helpers/budget');
const { contextFor, CLUB } = require('../helpers/contexts');
const { readDoc, seedFixture } = require('../helpers/fixtures');
const payloads = require('../helpers/payloads');

const classify = (role, writes) => budget.classify(budget.buildBatch(contextFor(role).firestore(), Object.values(writes)).commit());
const outcome = async (role, writes) => (await classify(role, writes)).outcome;

describe('bütçe · başkanlık devri ve rol değişimi (T-30)', () => {
  test('rol değişimi ve başkanın devri bütçe içinde geçer', async () => {
    await seedFixture('base');
    expect(await outcome('president', payloads.roleWrites({ club: CLUB, uid: 'u_president' }))).toBe(budget.Outcome.ok);
    expect(await outcome('president', payloads.transferWrites({ club: CLUB, uid: 'u_president' }))).toBe(budget.Outcome.ok);
    expect(await readDoc(`clubs/${CLUB}`)).toMatchObject({ presidentId: 'u_board' });
  });

  test('süper adminin devri bütçe içinde geçer', async () => {
    await seedFixture('base');
    expect(await outcome('super', payloads.transferWrites({ club: CLUB, uid: 'u_super', to: 'u_member' }))).toBe(budget.Outcome.ok);
  });

  test('eksik parçalı devir ve askıdaki hedefe devir bütçeden değil kuraldan reddedilir', async () => {
    await seedFixture('base', undefined, { patch: { 'users/u_board': { status: 'suspended' } } });
    const { from: _from, ...withoutOld } = payloads.transferWrites({ club: CLUB, uid: 'u_president', to: 'u_member' });
    expect(await outcome('president', withoutOld)).toBe(budget.Outcome.permissionDenied);
    expect(await outcome('president', payloads.transferWrites({ club: CLUB, uid: 'u_president' }))).toBe(budget.Outcome.permissionDenied);
  });
});
