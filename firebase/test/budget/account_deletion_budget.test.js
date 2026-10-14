'use strict';
// T-29 — hesap silme parça boyutu ölçümü (RP06; PLAN §11.3 satır 1; rules-spec §1.8; sözleşme docs/plans/T-29.md
// §4 g). Sınır: istek başına 20 `get / exists / getAfter` (emülatör aynı yolu bir kez sayar — helpers/budget.js).
// En ağır parça: N farklı kulüpte ETKİN `member` üyeliği (M14 `active → left`) + her birinin `private/contact`'ı +
// her kulübün `memberCount −1`'i, tek batch (repository'de tek transaction). Tekil yollar:
//   users/{uid} (`deletedUser` — tüm parçada 1) · kulüp i (`counterDelta`) · üyelik i (kulübün −1 dalı; contact
//   dalının getAfter'ı aynı yol) → 1 + 2N. Beklenen: N = 9 → 19 geçer, N = 10 → 21 reddedilir.
// Ölçüm: N ∈ 3–12, ilk retten sonra durur; ret bütçe hatası olmalıdır ("Service call error"), kural hatası
// değil. `account_deletion_result.json#chunk` = min(5, en büyük geçen N) = Limits.accountDeletionChunk
// (RP06 — tool/check_rules_parity.js; Rules `// budget: chunk=5`).
// Ayrıca: `Limits.accountDeletionChunk` boyunda rsvp parçası (2N yol) ve `Limits.batchMaxWrites` boyunda karışık
// kişisel parça (bildirim + kayıt + engel; 1 yol) bütçe içinde geçer.
const fs = require('node:fs');
const path = require('node:path');
const budget = require('../helpers/budget');
const { contextFor, CLUB } = require('../helpers/contexts');
const { DAY_MS, baseDocs, eventDoc, fromNow, readDoc, rsvpDoc, seedDocs } = require('../helpers/fixtures');
const payloads = require('../helpers/payloads');

const N_MIN = 3;
const N_MAX = 12;
const CHUNK_CAP = 5;
const RESULT_FILE = 'account_deletion_result.json';
const LIMITS_DART = path.resolve(__dirname, '..', '..', '..', 'packages/gu_data/lib/src/constants/limits.dart');
const UID = 'u_deleted';
const ROLE = 'deleted';

const dartInt = (name) => Number(new RegExp(`static const int ${name} = (\\d+);`).exec(fs.readFileSync(LIMITS_DART, 'utf8'))[1]);
const classify = (writes) => budget.classify(budget.buildBatch(contextFor(ROLE).firestore(), Object.values(writes)).commit());
const clubIds = (n) => Array.from({ length: n }, (_, i) => `cb${String(i).padStart(2, '0')}`);

/** `u_deleted` (hesabı silinmiş) için N kulüpte etkin `member` üyeliği + contact; kulüpler `c02` kopyası. */
function seedMemberships(n) {
  const docs = baseDocs();
  for (const club of clubIds(n)) {
    docs[`clubs/${club}`] = { ...docs['clubs/c02'], name: `Bütçe Kulübü ${club}`, nameLower: `bütçe kulübü ${club}`, memberCount: 1 };
    docs[payloads.membershipPath(club, UID)] = { ...docs[payloads.membershipPath(CLUB, UID)], clubId: club };
    docs[payloads.contactPath(club, UID)] = { ...docs[payloads.contactPath(CLUB, UID)] };
  }
  return seedDocs(docs);
}

const membershipChunk = (n) =>
  payloads.anonymizeMembershipWrites({ uid: UID, memberships: clubIds(n).map((club) => ({ club, from: 'active', role: 'member' })) });

describe('bütçe · hesap silme parçası (T-29, RP06)', () => {
  test('üyelik parçası: N kulüpte etkin üye + contact + memberCount −1 ölçülür; account_deletion_result.json yazılır ve Limits.accountDeletionChunk ile aynıdır', async () => {
    const results = [];
    let firstRejected = null;
    for (let n = N_MIN; n <= N_MAX; n += 1) {
      await seedMemberships(n);
      const { outcome } = await classify(membershipChunk(n));
      results.push({ n, ok: outcome === budget.Outcome.ok, outcome });
      if (outcome !== budget.Outcome.ok) {
        firstRejected = n;
        break;
      }
    }
    const passing = results.filter((r) => r.ok).map((r) => r.n);
    expect(passing.length).toBeGreaterThan(0);
    const maxPassing = Math.max(...passing);
    // Ret gözlenmeli ve bütçeden gelmeli (kural hatası parça boyutunu ölçmez).
    expect(firstRejected).toBe(maxPassing + 1);
    expect(results[results.length - 1].outcome).toBe(budget.Outcome.evaluationError);
    const chunk = Math.min(CHUNK_CAP, maxPassing);
    budget.writeResult(RESULT_FILE, {
      chunk,
      maxPassing,
      firstRejected,
      type: 'membership_active_member',
      results,
      rule: `chunk = min(${CHUNK_CAP}, maxPassing); N ∈ ${N_MIN}–${N_MAX}, ilk retten sonra durur`,
    });
    expect(dartInt('accountDeletionChunk')).toBe(chunk);
  }, 180000);

  test('Limits parçası geçer: üyelik (5), rsvp (5 etkinlik, sayaç −1) ve 450\'lik karışık kişisel parça', async () => {
    const chunk = dartInt('accountDeletionChunk');
    const personalMax = dartInt('batchMaxWrites');

    await seedMemberships(chunk);
    expect((await classify(membershipChunk(chunk))).outcome).toBe(budget.Outcome.ok);
    expect((await readDoc(payloads.membershipPath(clubIds(chunk)[chunk - 1], UID))).status).toBe('left');

    // rsvp parçası: N farklı bitmemiş etkinlik × (kayıt + etkinlik sayacı) — 2N tekil yol.
    const events = Array.from({ length: chunk }, (_, i) => `eb${i}`);
    const rsvpDocs = baseDocs();
    for (const eventId of events) {
      rsvpDocs[`events/${eventId}`] = eventDoc('public', 'published', 1, { startsAt: fromNow(DAY_MS), endsAt: fromNow(2 * DAY_MS) });
      rsvpDocs[payloads.rsvpPath(eventId, UID)] = rsvpDoc(eventId, UID, 'going');
    }
    await seedDocs(rsvpDocs);
    const rsvpWrites = Object.assign({}, ...events.map((eventId, i) => {
      const w = payloads.rsvpCancelWrites({ uid: UID, eventId });
      return { [`rsvp${i}`]: w.rsvp, [`event${i}`]: w.event };
    }));
    expect((await classify(rsvpWrites)).outcome).toBe(budget.Outcome.ok);
    expect((await readDoc(`events/${events[chunk - 1]}`)).goingCount).toBe(0);

    // Kişisel parça: bildirim / kayıt / engel karışık, `Limits.batchMaxWrites` belge — 1 tekil yol (users).
    const personalDocs = baseDocs();
    const paths = [];
    for (let i = 0; i < personalMax; i += 1) {
      const id = String(i).padStart(3, '0');
      const kind = i % 3;
      if (kind === 0) {
        paths.push(`notifications/system_n${id}_${UID}`);
        personalDocs[paths[i]] = { ...personalDocs['notifications/n01'], userId: UID };
      } else if (kind === 1) {
        paths.push(`savedPosts/${UID}_p${id}`);
        personalDocs[paths[i]] = { ...personalDocs['savedPosts/u_member_p01'], userId: UID, postId: `p${id}` };
      } else {
        paths.push(`blocks/${UID}_u_t${id}`);
        personalDocs[paths[i]] = { ...personalDocs['blocks/u_member_u_student'], blockerId: UID, blockedId: `u_t${id}` };
      }
    }
    await seedDocs(personalDocs);
    expect((await classify(payloads.personalSoftDeleteWrites({ uid: UID, paths }))).outcome).toBe(budget.Outcome.ok);
    expect(await readDoc(paths[personalMax - 1])).toMatchObject({ isDeleted: true, deletedBy: UID });
  }, 120000);
});
