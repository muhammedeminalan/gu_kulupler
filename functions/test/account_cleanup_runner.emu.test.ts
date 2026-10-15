// CD-165 b4 · finishAccountDeletions gövdesi: 1–72 sa penceresi, temizlik yazımları, idempotent ikinci koşu,
// `lastUpdateTime` önkoşulu (istemcinin eşzamanlı temizliğiyle çift sayaç düşüşü yok).
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
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
    expect(await runAccountCleanup(deps, { pageSize: 10, budgetMs: 0 })).toMatchObject({ users: 10, skipped: 10 });
    expect(await get(`users/${capped.uid}/private/account`)).toMatchObject({ email: 'x@ogr.gumushane.edu.tr' });
    const one = await runAccountCleanup(deps, { pageSize: 100, maxUsers: 1 });
    expect(one.users - one.skipped).toBe(1);
    expect(await get(`users/${capped.uid}/private/account`)).toMatchObject({ email: '' });
  });
});
