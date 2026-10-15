// CD-165 b4 · finishAccountDeletions gövdesi: 1–72 sa penceresi, temizlik yazımları, idempotent ikinci koşu,
// `lastUpdateTime` önkoşulu (istemcinin eşzamanlı temizliğiyle çift sayaç düşüşü yok).
// T-45 A5-02 · büyük kişisel küme: iki geçiş (önce kritik), koşu başına sınırlı sayfalı okuma, gruplu batch, süre bütçesi.
import { FieldValue, Firestore, Timestamp } from 'firebase-admin/firestore';
import { buildCleanupPlan } from '../src/lib/account_cleanup';
import { applyCleanupPlan, readCleanupState, runAccountCleanup } from '../src/lib/account_cleanup_runner';
import { emulatorDb, uniq } from './helpers/emulator';

const db = emulatorDb();
const nowMs = Date.now();
const deps = { db, now: () => new Date(nowMs) };
const HOUR = 3_600_000;

async function seedDeleted(hoursAgo: number) {
  const uid = uniq('u');
  const clubId = uniq('c');
  const eventId = uniq('e');
  await db.doc(`users/${uid}`).set({ status: 'deleted', isDeleted: true, deletedAt: Timestamp.fromMillis(nowMs - hoursAgo * HOUR) });
  await db.doc(`users/${uid}/private/account`).set({ email: 'x@ogr.gumushane.edu.tr', emailLower: 'x@ogr.gumushane.edu.tr', fcmTokens: [{ token: 't' }] });
  await db.doc(`clubs/${clubId}`).set({ memberCount: 3, isDeleted: false });
  await db.doc(`memberships/${clubId}_${uid}`).set({ userId: uid, clubId, status: 'active', role: 'member', applicant: { name: 'Ayşe' } });
  await db.doc(`events/${eventId}`).set({ clubId, goingCount: 2, endsAt: Timestamp.fromMillis(nowMs + 48 * HOUR), isDeleted: false });
  await db.doc(`rsvps/${eventId}_${uid}`).set({ userId: uid, eventId, clubId, status: 'going' });
  await db.doc(`notifications/system_k_${uid}`).set({ userId: uid, type: 'system', isDeleted: false });
  return { uid, clubId, eventId };
}

const get = async (path: string) => (await db.doc(path).get()).data() ?? {};

describe('finishAccountDeletions', () => {
  test('pencere içindeki hesap temizlenir, ikinci koşu yazmaz, pencere dışı (72 sa+ / 1 sa−) dokunulmaz', async () => {
    const inside = await seedDeleted(2);
    const old = await seedDeleted(100);
    const fresh = await seedDeleted(0.5);

    const first = await runAccountCleanup(deps);
    expect(first).toMatchObject({ users: 1, applied: 4, rejected: 0, failed: 0 });
    expect(await get(`users/${inside.uid}/private/account`)).toMatchObject({ email: '', emailLower: '', fcmTokens: [] });
    expect(await get(`memberships/${inside.clubId}_${inside.uid}`)).toMatchObject({ status: 'left', applicant: { name: 'Silinmiş kullanıcı' } });
    expect(await get(`clubs/${inside.clubId}`)).toMatchObject({ memberCount: 2 });
    expect(await get(`rsvps/${inside.eventId}_${inside.uid}`)).toMatchObject({ status: 'cancelled' });
    expect(await get(`events/${inside.eventId}`)).toMatchObject({ goingCount: 1 });
    expect(await get(`notifications/system_k_${inside.uid}`)).toMatchObject({ isDeleted: true, deletedBy: inside.uid });
    for (const other of [old, fresh]) {
      expect(await get(`users/${other.uid}/private/account`)).toMatchObject({ email: 'x@ogr.gumushane.edu.tr' });
    }

    expect(await runAccountCleanup(deps)).toMatchObject({ users: 1, skipped: 1, applied: 0 });
    expect(await get(`clubs/${inside.clubId}`)).toMatchObject({ memberCount: 2 });
  });

  test('okunduktan sonra değişen belgenin birimi reddedilir (çift sayaç düşüşü yok), diğer birimler yazılır', async () => {
    const { uid, eventId } = await seedDeleted(5);
    const { input, versions } = await readCleanupState(db, uid, new Date(nowMs));
    const plan = buildCleanupPlan(input);
    // İstemcinin eşzamanlı resumeCleanup'ı aynı katılımı kapattı.
    await db.doc(`rsvps/${eventId}_${uid}`).update({ status: 'cancelled', updatedAt: FieldValue.serverTimestamp() });
    await db.doc(`events/${eventId}`).update({ goingCount: FieldValue.increment(-1) });

    expect(await applyCleanupPlan(db, plan, versions)).toEqual({ applied: 3, rejected: 1, failed: 0 });
    expect(await get(`events/${eventId}`)).toMatchObject({ goingCount: 1 });
  });

  test('sayfalama: pencerenin başındaki 50+ temiz (boş planlı) hesap sınırı doldurmaz, arkadaki hesap da temizlenir', async () => {
    // Temizliği bitmiş hesaplar `status == 'deleted'` kalır ve 72 sa boyunca pencerededir (en eskiler — sıranın başı).
    // Eski davranış: `limit(50)` bu 51 temiz hesapla dolar, yeni silinen hesap hiçbir koşuda işlenmezdi.
    const batch = db.batch();
    for (let i = 0; i < 51; i += 1) {
      const uid = uniq('clean');
      const deletedAt = Timestamp.fromMillis(nowMs - 71 * HOUR + i * 60_000);
      batch.set(db.doc(`users/${uid}`), { status: 'deleted', isDeleted: true, deletedAt });
      batch.set(db.doc(`users/${uid}/private/account`), { email: '', emailLower: '', fcmTokens: [] });
    }
    await batch.commit();
    const pending = await seedDeleted(69);

    const run = await runAccountCleanup(deps);
    expect(run).toMatchObject({ rejected: 0, failed: 0 });
    expect(run.skipped).toBeGreaterThanOrEqual(51);
    expect(await get(`users/${pending.uid}/private/account`)).toMatchObject({ email: '', fcmTokens: [] });
    expect(await get(`clubs/${pending.clubId}`)).toMatchObject({ memberCount: 2 });

    // Sınır yalnızca yazım planlanan hesapları sayar; süre bütçesi dolunca yeni sayfa açılmaz.
    const capped = await seedDeleted(68);
    // T-45 A5-02: bütçe hesaplar (ve birimler) arasında da denetlenir → bütçe 0 iken hiçbir hesap okunmaz.
    expect(await runAccountCleanup(deps, { pageSize: 10, budgetMs: 0 })).toMatchObject({ users: 0, applied: 0, budgetHit: true });
    expect(await get(`users/${capped.uid}/private/account`)).toMatchObject({ email: 'x@ogr.gumushane.edu.tr' });
    const one = await runAccountCleanup(deps, { pageSize: 100, maxUsers: 1 });
    expect(one.users - one.skipped).toBe(1);
    expect(await get(`users/${capped.uid}/private/account`)).toMatchObject({ email: '' });
  });

  test('A5-02 · büyük kişisel küme arkadaki hesabın kritik temizliğini geciktirmez; kişisel belgeler koşu başına sınırlı ve gruplu', async () => {
    // Yalnızca bu testin hesaplarını içeren pencere (diğer testlerin hesapları `nowMs`'ten eskidir).
    const later = nowMs + 1000 * HOUR;
    const hoarder = await seedHoarder(later - 71.9 * HOUR, 1000); // sıranın başı: ~1000 engel belgesi
    const victim = await seedVictim(later - 71.8 * HOUR); // arkasında: iletişim e-postası dolu üyelik
    const counted = countingDb(db);
    const run = (limits: Parameters<typeof runAccountCleanup>[1]) =>
      runAccountCleanup({ db: counted.db, now: () => new Date(later) }, limits);
    const since = (mark: number) => counted.commits() - mark;

    // 1. koşu, bütçe = 3 commit: iki hesabın kritik birimleri (saldırgan 1 + kurban 2) biter, kişisel geçişe sıra gelmez.
    // Eski davranış: saldırganın 1000 kişisel birimi kurbandan önce tek tek yazılırdı (1003 commit).
    const first = await run({ budgetMs: 3, elapsed: () => counted.commits() });
    expect(counted.commits()).toBe(3);
    expect(first).toMatchObject({ users: 2, applied: 3, rejected: 0, failed: 0, budgetHit: true });
    expect(await get(`memberships/${victim.clubId}_${victim.uid}/private/contact`)).toMatchObject({ email: '', emailLower: '', note: '' });
    expect(await get(`users/${victim.uid}/private/account`)).toMatchObject({ email: '', emailLower: '' });
    expect(await get(`clubs/${victim.clubId}`)).toMatchObject({ memberCount: 1 });
    expect(await get(`users/${hoarder}/private/account`)).toMatchObject({ email: '', emailLower: '' });
    expect(await liveBlocks(hoarder)).toBe(1000);

    // 2. koşu, kişisel sınır 100: tam 100 belge soft delete, tek gruplu batch (≤ ceil(100 / 450)).
    let mark = counted.commits();
    expect(await run({ personalMax: 100 })).toMatchObject({ skipped: 2, applied: 1, rejected: 0, failed: 0, budgetHit: false });
    expect(since(mark)).toBe(1);
    expect(await liveBlocks(hoarder)).toBe(900);
    const sample = await db.collection('blocks').where('blockerId', '==', hoarder).where('isDeleted', '==', true).limit(1).get();
    expect(sample.docs[0].data()).toMatchObject({ isDeleted: true, deletedBy: hoarder });

    // 3. koşu, sayfa 30: sıradaki 100 belge 30'luk sayfalarla okunur, 30'luk batch'lerle yazılır (4 commit).
    mark = counted.commits();
    await run({ personalMax: 100, personalPage: 30 });
    expect(since(mark)).toBe(4);
    expect(await liveBlocks(hoarder)).toBe(800);

    // Bütçe 0: hiçbir hesap okunmaz / yazılmaz.
    mark = counted.commits();
    expect(await run({ budgetMs: 0 })).toMatchObject({ users: 0, applied: 0, budgetHit: true });
    expect(since(mark)).toBe(0);
    expect(await liveBlocks(hoarder)).toBe(800);

    // Okuma (bellek) de sınırlı: koleksiyon başına en çok `personalMax` belge.
    const { input } = await readCleanupState(db, hoarder, new Date(later), { personalMax: 50 });
    expect(Object.keys(input.personal.blocks)).toHaveLength(50);
  });

  test('A5-02 · gruplu kişisel batch: okunduktan sonra değişen tek belge parçayı reddeder, sonraki koşu yeniden planlar', async () => {
    const later = nowMs + 2000 * HOUR;
    const uid = uniq('u');
    await db.doc(`users/${uid}`).set({ status: 'deleted', isDeleted: true, deletedAt: Timestamp.fromMillis(later - 3 * HOUR) });
    const ids = [0, 1, 2].map((i) => `system_k${i}_${uid}`);
    for (const id of ids) await db.doc(`notifications/${id}`).set({ userId: uid, type: 'system', read: false, isDeleted: false });

    const { input, versions } = await readCleanupState(db, uid, new Date(later));
    const plan = buildCleanupPlan(input);
    await db.doc(`notifications/${ids[1]}`).update({ read: true }); // istemci arada okundu işaretledi
    expect(await applyCleanupPlan(db, plan, versions)).toEqual({ applied: 0, rejected: 1, failed: 0 });
    for (const id of ids) expect(await get(`notifications/${id}`)).toMatchObject({ isDeleted: false }); // batch atomik

    expect(await runAccountCleanup({ db, now: () => new Date(later) })).toMatchObject({ applied: 1, rejected: 0, failed: 0 });
    for (const id of ids) expect(await get(`notifications/${id}`)).toMatchObject({ isDeleted: true, deletedBy: uid });
  });
});

/** Silinmiş hesap + `count` engel belgesi (kişisel küme; Rules `blocks` create hedefin varlığını denetlemez). */
async function seedHoarder(deletedAtMs: number, count: number): Promise<string> {
  const uid = uniq('hoard');
  await db.doc(`users/${uid}`).set({ status: 'deleted', isDeleted: true, deletedAt: Timestamp.fromMillis(deletedAtMs) });
  await db.doc(`users/${uid}/private/account`).set({ email: 'h@ogr.gumushane.edu.tr', emailLower: 'h@ogr.gumushane.edu.tr', fcmTokens: [] });
  const writer = db.bulkWriter();
  for (let i = 0; i < count; i += 1) {
    const ghost = `ghost${String(i).padStart(4, '0')}`;
    void writer.set(db.doc(`blocks/${uid}_${ghost}`), { blockerId: uid, blockedId: ghost, isDeleted: false });
  }
  await writer.close();
  return uid;
}

/** Silinmiş hesap: e-postası dolu hesap belgesi + etkin üyelik + dolu iletişim belgesi (kritik birimler). */
async function seedVictim(deletedAtMs: number): Promise<{ uid: string; clubId: string }> {
  const uid = uniq('victim');
  const clubId = uniq('c');
  await db.doc(`users/${uid}`).set({ status: 'deleted', isDeleted: true, deletedAt: Timestamp.fromMillis(deletedAtMs) });
  await db.doc(`users/${uid}/private/account`).set({ email: 'v@ogr.gumushane.edu.tr', emailLower: 'v@ogr.gumushane.edu.tr', fcmTokens: [] });
  await db.doc(`clubs/${clubId}`).set({ memberCount: 2, isDeleted: false });
  await db.doc(`memberships/${clubId}_${uid}`).set({ userId: uid, clubId, status: 'active', role: 'member', applicant: { name: 'Ayşe' } });
  await db.doc(`memberships/${clubId}_${uid}/private/contact`).set({ email: 'v@ogr.gumushane.edu.tr', emailLower: 'v@ogr.gumushane.edu.tr', note: 'not' });
  return { uid, clubId };
}

async function liveBlocks(uid: string): Promise<number> {
  const snap = await db.collection('blocks').where('blockerId', '==', uid).where('isDeleted', '==', false).count().get();
  return snap.data().count;
}

/** `batch().commit()` çağrılarını sayan sarmalayıcı (yalnızca koşucuya verilir; tohumlama ham `db` ile). */
function countingDb(target: Firestore): { db: Firestore; commits: () => number } {
  let commits = 0;
  const wrapped = new Proxy(target, {
    get(t, prop) {
      if (prop === 'batch') {
        return () => {
          const batch = t.batch();
          const commit = batch.commit.bind(batch);
          batch.commit = () => {
            commits += 1;
            return commit();
          };
          return batch;
        };
      }
      const value = Reflect.get(t, prop, t) as unknown;
      return typeof value === 'function' ? (value as (...args: unknown[]) => unknown).bind(t) : value;
    },
  });
  return { db: wrapped, commits: () => commits };
}
