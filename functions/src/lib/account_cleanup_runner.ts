/**
 * `finishAccountDeletions` gövdesi (CD-165 b4): `deletedAt` son 1–72 saat içindeki silinmiş hesapların yarım kalan
 * temizliğini tamamlar (daha eskisi `tool/admin/finish_account_deletion.js`).
 *
 * - **Sayfalama (güvenlik incelemesi):** temizliği bitmiş hesaplar da `status == 'deleted'` kalır ve 72 saat boyunca
 *   pencerededir. Tarama `deletedAt asc` sayfalarla (`startAfter`) ilerler; koşu sınırı ([CLEANUP_MAX_USERS]) yalnızca
 *   gerçekten yazım planlanan hesapları sayar, süre bütçesi ([CLEANUP_BUDGET_MS]) dolunca yeni sayfa açılmaz →
 *   dönem sonu gibi yoğun günlerde yeni silinen hesaplar eski, temiz hesapların arkasında kalmaz.
 *
 * - Okuma `tool/admin/finish_account_deletion.js#readState` ile aynı; planlayıcı [buildCleanupPlan] (TS portu).
 * - Her birim AYRI batch'tir ve ilk yazımı, o belgenin okunduğu andaki `lastUpdateTime` önkoşuluyla yapılır:
 *   istemcinin eşzamanlı `resumeCleanup`'ı belgeyi değiştirdiyse birim reddedilir (çift sayaç düşüşü yok), sonraki
 *   koşu yeniden planlar. İdempotent: ikinci koşu boş plan üretir.
 * - Zincir: rsvp `going → cancelled` terfiyi tetikler (istenen); bildirim soft delete'i update'tir → push yok.
 * - Hiçbir belge ya da Auth kimliği silinmez (D-10, Q-11). Log'da uid / e-posta yok, yalnızca sayılar.
 */
import {
  DocumentData,
  FieldValue,
  Firestore,
  QueryDocumentSnapshot,
  QuerySnapshot,
  Timestamp,
} from 'firebase-admin/firestore';
import { buildCleanupPlan, CleanupInput, CleanupPlan, Doc } from './account_cleanup';
import {
  CLEANUP_BUDGET_MS,
  CLEANUP_MAX_AGE_MS,
  CLEANUP_MAX_USERS,
  CLEANUP_MIN_AGE_MS,
  CLEANUP_PAGE_SIZE,
  Col,
} from './config';
import { Deps } from './deps';
import { isFailedPrecondition } from './model';
import { errorFields, log } from './log';

/** Okunan belgelerin sürümü: yol → `updateTime` (önkoşul). */
export type Versions = Map<string, Timestamp>;

/** Firestore değerlerini planlayıcı girdisine çevirir (`Timestamp` → `Date`; `admin_runtime.js#plain`). */
export function plain(value: unknown): unknown {
  if (value && typeof (value as { toDate?: unknown }).toDate === 'function') return (value as Timestamp).toDate();
  if (Array.isArray(value)) return value.map(plain);
  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.entries(value as Doc).map(([k, v]) => [k, plain(v)]));
  }
  return value;
}

/** Plan nöbetçilerini Admin SDK değerlerine çevirir (`admin_cli.js#materialize`). */
export function materialize(value: unknown): unknown {
  if (value && typeof value === 'object' && (value as { $serverTimestamp?: unknown }).$serverTimestamp === true) {
    return FieldValue.serverTimestamp();
  }
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    const keys = Object.keys(value);
    const inc = (value as { $increment?: unknown }).$increment;
    if (keys.length === 1 && typeof inc === 'number') return FieldValue.increment(inc);
  }
  if (Array.isArray(value)) return value.map(materialize);
  if (value && typeof value === 'object' && !(value instanceof Date)) {
    return Object.fromEntries(Object.entries(value as Doc).map(([k, v]) => [k, materialize(v)]));
  }
  return value;
}

/** Hesabın kalan belgeleri (yalnızca okuma) + okunan her belgenin sürümü. */
export async function readCleanupState(
  db: Firestore,
  uid: string,
  now: Date,
): Promise<{ input: CleanupInput; versions: Versions }> {
  const versions: Versions = new Map();
  const get = async (path: string): Promise<Doc | null> => {
    const snap = await db.doc(path).get();
    if (!snap.exists) return null;
    if (snap.updateTime) versions.set(path, snap.updateTime);
    return plain(snap.data()) as Doc;
  };
  const docsOf = (collection: string, snapshot: QuerySnapshot<DocumentData>): Record<string, Doc> => {
    const out: Record<string, Doc> = {};
    for (const doc of snapshot.docs) {
      versions.set(`${collection}/${doc.id}`, doc.updateTime);
      out[doc.id] = plain(doc.data()) as Doc;
    }
    return out;
  };
  const memberships = docsOf(Col.memberships, await db.collection(Col.memberships).where('userId', '==', uid).get());
  const rsvps = docsOf(Col.rsvps, await db.collection(Col.rsvps).where('userId', '==', uid).get());
  const contacts: Record<string, Doc | null> = {};
  const clubs: Record<string, Doc | null> = {};
  for (const [id, m] of Object.entries(memberships)) {
    contacts[id] = await get(`${Col.memberships}/${id}/${Col.private}/${Col.contact}`);
    const clubId = String(m.clubId);
    if (!(clubId in clubs)) clubs[clubId] = await get(`${Col.clubs}/${clubId}`);
  }
  const events: Record<string, Doc | null> = {};
  for (const r of Object.values(rsvps)) {
    const eventId = String(r.eventId);
    if (!(eventId in events)) events[eventId] = await get(`${Col.events}/${eventId}`);
  }
  const live = async (collection: string, field: string): Promise<Record<string, Doc>> =>
    docsOf(collection, await db.collection(collection).where(field, '==', uid).where('isDeleted', '==', false).get());
  const input: CleanupInput = {
    uid,
    now,
    user: await get(`${Col.users}/${uid}`),
    account: await get(`${Col.users}/${uid}/${Col.private}/${Col.account}`),
    memberships,
    contacts,
    clubs,
    rsvps,
    events,
    personal: {
      notifications: await live(Col.notifications, 'userId'),
      savedPosts: await live(Col.savedPosts, 'userId'),
      blocks: await live(Col.blocks, 'blockerId'),
    },
  };
  return { input, versions };
}

export interface ApplyResult {
  applied: number;
  rejected: number;
  failed: number;
}

/** Her birimi ayrı batch'te uygular; ilk yazım okunan sürüm önkoşuluyla. */
export async function applyCleanupPlan(db: Firestore, plan: CleanupPlan, versions: Versions): Promise<ApplyResult> {
  const out: ApplyResult = { applied: 0, rejected: 0, failed: 0 };
  for (const unit of plan.units) {
    if (unit.length === 0) continue;
    const batch = db.batch();
    unit.forEach((write, index) => {
      const ref = db.doc(write.path);
      const data = materialize(write.data) as Record<string, unknown>;
      const version = index === 0 ? versions.get(write.path) : undefined;
      if (version) batch.update(ref, data, { lastUpdateTime: version });
      else batch.update(ref, data);
    });
    try {
      await batch.commit();
      out.applied += 1;
    } catch (error) {
      if (isFailedPrecondition(error)) out.rejected += 1;
      else {
        out.failed += 1;
        log.warn('temizlik birimi yazılamadı', errorFields(error));
      }
    }
  }
  return out;
}

export interface CleanupRunResult extends ApplyResult {
  /** Taranan hesap sayısı (boş planlılar dahil). */
  users: number;
  skipped: number;
  warnings: number;
}

/** Koşu sınırları (testler küçük değerlerle çağırır). */
export interface CleanupLimits {
  pageSize: number;
  maxUsers: number;
  budgetMs: number;
  /** Süre bütçesinin saati (gerçek geçen süre; `deps.now` sabit olabilir). */
  elapsed: () => number;
}

export async function runAccountCleanup(
  deps: Pick<Deps, 'db' | 'now'>,
  limits: Partial<CleanupLimits> = {},
): Promise<CleanupRunResult> {
  const { db } = deps;
  const now = deps.now();
  const started = Date.now();
  const pageSize = limits.pageSize ?? CLEANUP_PAGE_SIZE;
  const maxUsers = limits.maxUsers ?? CLEANUP_MAX_USERS;
  const budgetMs = limits.budgetMs ?? CLEANUP_BUDGET_MS;
  const elapsed = limits.elapsed ?? (() => Date.now() - started);
  const from = Timestamp.fromMillis(now.getTime() - CLEANUP_MAX_AGE_MS);
  const to = Timestamp.fromMillis(now.getTime() - CLEANUP_MIN_AGE_MS);
  const summary: CleanupRunResult = { users: 0, skipped: 0, warnings: 0, applied: 0, rejected: 0, failed: 0 };
  const base = db
    .collection(Col.users)
    .where('status', '==', 'deleted')
    .where('deletedAt', '>=', from)
    .where('deletedAt', '<', to)
    .orderBy('deletedAt', 'asc')
    .limit(pageSize);
  let cursor: QueryDocumentSnapshot | undefined;
  let worked = 0;
  for (;;) {
    const page = await (cursor ? base.startAfter(cursor) : base).get();
    for (const doc of page.docs) {
      if (worked >= maxUsers) break;
      summary.users += 1;
      try {
        const { input, versions } = await readCleanupState(db, doc.id, now);
        const plan = buildCleanupPlan(input);
        summary.warnings += plan.warnings.length;
        if (plan.skip || plan.units.length === 0) {
          summary.skipped += 1;
          continue;
        }
        worked += 1;
        const applied = await applyCleanupPlan(db, plan, versions);
        summary.applied += applied.applied;
        summary.rejected += applied.rejected;
        summary.failed += applied.failed;
      } catch (error) {
        summary.failed += 1;
        log.warn('hesap temizliği okunamadı', errorFields(error));
      }
    }
    if (page.size < pageSize || worked >= maxUsers || elapsed() >= budgetMs) break;
    cursor = page.docs[page.docs.length - 1];
  }
  log.info('hesap silme temizliği', { ...summary });
  return summary;
}
