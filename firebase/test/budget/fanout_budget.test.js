'use strict';
// T-25 — bildirim fan-out parça boyutu ölçümü (PLAN §10.5, §11.3; rules-spec §1.8, §5; sözleşme
// docs/plans/T-25.md §6.f). Sınır: işlem başına 10, istek başına 20 `get / exists / getAfter` (emülatör aynı yolu
// bir kez sayar — helpers/budget.js). Parçadaki her belge AYNI yolları okur, alıcı başına erişim çağrısı yoktur
// (CD-148 güvenlik incelemesiyle yönetici dallarına `clubLive` eklendi — kulüp belgesi +1):
//   announcement = users/{uid} · üyelik · gönderi · kulüp (4)   event_new / event_cancelled = users/{uid} · üyelik · etkinlik · kulüp (4)
//   waitlist_promoted (terfi batch'inde) = etkinlik · yan belge · katılım kaydı · users/{uid} · üyelik · kulüp (6)
//   application_received = users/{uid} · kendi üyeliği · alıcının üyeliği (3; alıcı başına batch — ölçülmez)
// Ölçüm: 1 yönetim kurulu üyesi, yeni yayımlanmış etkinliğin `event_new` bildirimi (rastgele anahtarlı tür — her
// ölçüm noktası ayrı anahtar), N ∈ {10, 20, 50, 100, 200, 400, 450 = Limits.batchMaxWrites} alıcıya tek
// WriteBatch; ilk ret N'i kaydedilir. Canlıda aşım `permission-denied` olursa dağıtıcı parçayı yarılar (CD-148). `fanout_result.json#chunkSize` = en büyük geçen N'nin yarısı
// (alt 10, üst 450) = Limits.notificationFanOutChunkSize (RP05 — tool/check_rules_parity.js).
const fs = require('node:fs');
const path = require('node:path');
const budget = require('../helpers/budget');
const { contextFor, CLUB } = require('../helpers/contexts');
const { readDoc, seedFixture } = require('../helpers/fixtures');
const payloads = require('../helpers/payloads');

const N_VALUES = Object.freeze([10, 20, 50, 100, 200, 400, 450]);
const CHUNK_MIN = 10;
const CHUNK_MAX = 450;
const RESULT_FILE = 'fanout_result.json';
const LIMITS_DART = path.resolve(__dirname, '..', '..', '..', 'packages/gu_data/lib/src/constants/limits.dart');
const ANNOUNCED = { patch: { 'posts/p02': { type: 'announcement', pushSent: true } } };

const classify = (role, writes) => budget.classify(budget.buildBatch(contextFor(role).firestore(), Object.values(writes)).commit());
const recipientsOf = (n) => Array.from({ length: n }, (_, i) => `u_r${String(i).padStart(3, '0')}`);
/** Ölçüm noktası başına ayrı olay anahtarı (20 karakter): önceki noktanın belgeleri update sayılmasın. */
const keyOf = (n) => `N${String(n).padStart(3, '0')}${payloads.EVENT_KEY}`.slice(0, 20);
const chunkOf = (maxPassing) => Math.min(CHUNK_MAX, Math.max(CHUNK_MIN, Math.floor(maxPassing / 2)));
const dartChunkSize = () => Number(/static const int notificationFanOutChunkSize = (\d+);/.exec(fs.readFileSync(LIMITS_DART, 'utf8'))[1]);

describe('bütçe · bildirim fan-out parçası (T-25)', () => {
  test('event_new: N alıcılı tek batch ölçülür; fanout_result.json yazılır ve Limits.notificationFanOutChunkSize ile aynıdır', async () => {
    const results = [];
    for (const n of N_VALUES) {
      await seedFixture('base', undefined, ANNOUNCED);
      const writes = payloads.fanOutWrites({ type: 'event_new', refs: { clubId: CLUB, eventId: 'e_public' }, recipients: recipientsOf(n), key: keyOf(n) });
      const { outcome } = await classify('board', writes);
      results.push({ n, ok: outcome === budget.Outcome.ok, outcome });
      if (outcome !== budget.Outcome.ok) break;
    }
    const passing = results.filter((r) => r.ok).map((r) => r.n);
    expect(passing.length).toBeGreaterThan(0);
    const maxPassing = Math.max(...passing);
    const chunkSize = chunkOf(maxPassing);
    budget.writeResult(RESULT_FILE, {
      chunkSize,
      maxPassing,
      type: 'event_new',
      results,
      rule: 'en büyük geçen N\'nin yarısı (10–450)',
    });
    // Son geçen noktada yazım gerçekten oldu (ret sessizce "geçti" sayılmadı).
    expect(await readDoc(payloads.notificationPath('event_new', keyOf(maxPassing), recipientsOf(maxPassing)[maxPassing - 1]))).toMatchObject({ read: false });
    expect(dartChunkSize()).toBe(chunkSize);
  }, 180000);

  test('Limits parçası en ağır fan-out türlerinde bütçe içinde geçer; ret bütçeden değil kuraldan gelir', async () => {
    const chunk = dartChunkSize();
    const recipients = recipientsOf(chunk);
    const refs = { clubId: CLUB, eventId: 'e_public' };
    await seedFixture('base', undefined, ANNOUNCED);
    expect((await classify('board', payloads.fanOutWrites({ type: 'event_new', refs, recipients }))).outcome).toBe(budget.Outcome.ok);
    // Sıradan üyenin aynı parçası bütçeden değil kuraldan reddedilir ("Service call error" yok).
    expect((await classify('member', payloads.fanOutWrites({ type: 'event_new', refs, recipients, key: payloads.EVENT_KEY_2 }))).outcome)
      .toBe(budget.Outcome.permissionDenied);
    // Duyuru (4 ayrı yol), terfi batch'i + kritik bildirim (6 ayrı yol) ve alıcı başına başvuru bildirimi (3 ayrı yol).
    expect((await classify('president', payloads.fanOutWrites({ type: 'announcement', refs: { clubId: CLUB, postId: 'p02' }, recipients }))).outcome)
      .toBe(budget.Outcome.ok);
    expect((await classify('board', payloads.promoteNotifyWrites({ club: CLUB }))).outcome).toBe(budget.Outcome.ok);
    const applied = payloads.fanOutWrites({ type: 'application_received', refs: { clubId: CLUB, applicantId: 'u_pending' }, recipients: ['u_board'] });
    expect((await classify('pending', applied)).outcome).toBe(budget.Outcome.ok);
  }, 60000);
});
