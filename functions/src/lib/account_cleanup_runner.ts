/**
 * `finishAccountDeletions` gövdesi (CD-165 b4): `deletedAt` son 1–72 saat içindeki silinmiş hesapların yarım kalan
 * temizliğini tamamlar (daha eskisi `tool/admin/finish_account_deletion.js`).
 *
 * - **Sayfalama (güvenlik incelemesi):** temizliği bitmiş hesaplar da `status == 'deleted'` kalır ve 72 saat boyunca
 *   pencerededir. Tarama `deletedAt asc` sayfalarla (`startAfter`) ilerler; koşu sınırı ([CLEANUP_MAX_USERS]) yalnızca
 *   gerçekten kritik yazım planlanan hesapları sayar → dönem sonu gibi yoğun günlerde yeni silinen hesaplar eski,
 *   temiz hesapların arkasında kalmaz.
 * - **İki geçiş (T-45 A5-02):** kişisel belgeleri (`notifications` / `savedPosts` / `blocks`) kullanıcı sınırsız
 *   üretebilir. 1. geçiş penceredeki her hesabın KRİTİK birimlerini (hesap belgesi, katılım + sayaç, üyelik + sayaç +
 *   danışman + iletişim) yazar; 2. geçiş kalan bütçeyle kişisel belgeleri soft delete eder → büyük kişisel kümesi olan
 *   hesap arkasındaki hesapların e-posta / iletişim temizliğini geciktiremez. Kişisel okuma sayfalıdır
 *   ([CLEANUP_PERSONAL_PAGE]) ve koşu başına hesap × koleksiyon başına sınırlıdır ([CLEANUP_PERSONAL_MAX_PER_USER]);
 *   kalanı sonraki koşu okur (sorgu `isDeleted == false` süzer).
 * - **Süre bütçesi** ([CLEANUP_BUDGET_MS]) sayfa, hesap ve batch öncesi denetlenir; dolunca koşu durur, kalan birimler
 *   sonraki koşuya kalır (`budgetHit`).
 *
 * - Okuma `tool/admin/lib/account_cleanup_runner.js` (`finish_account_deletion.js` koşucusu — T-45'te aynı iki geçiş,
 *   sayfalı okuma ve önkoşul ilkesi) ile aynı küme; planlayıcı [buildCleanupPlan] (TS portu, değişmez — iki geçiş
 *   planlayıcıyı iki ayrı girdiyle çağırır).
 * - Kritik her birim AYRI batch'tir ve ilk yazımı, o belgenin okunduğu andaki `lastUpdateTime` önkoşuluyla yapılır:
 *   istemcinin eşzamanlı `resumeCleanup`'ı belgeyi değiştirdiyse birim reddedilir (çift sayaç düşüşü yok), sonraki
 *   koşu yeniden planlar. Kişisel tek yazımlı birimler ≤ [CLEANUP_PERSONAL_PAGE] yazımlık gruplu batch'lerdir; HER
 *   yazım kendi önkoşulunu taşır, biri tutmazsa parça reddedilir (atomik), sonraki koşu yeniden okur. İdempotent:
 *   ikinci koşu boş plan üretir.
 * - Zincir: rsvp `going → cancelled` terfiyi tetikler (istenen); bildirim soft delete'i update'tir → push yok.
 * - Hiçbir belge ya da Auth kimliği silinmez (D-10, Q-11). Log'da uid / e-posta yok, yalnızca sayılar.
 */
import {
  DocumentData,
  FieldPath,
  FieldValue,
  Firestore,
  QueryDocumentSnapshot,
  QuerySnapshot,
  Timestamp,
} from 'firebase-admin/firestore';
import { buildCleanupPlan, CleanupInput, CleanupPlan, Doc, PlanWrite } from './account_cleanup';
import {
  CLEANUP_BUDGET_MS,
  CLEANUP_MAX_AGE_MS,
  CLEANUP_MAX_USERS,
  CLEANUP_MIN_AGE_MS,
  CLEANUP_PAGE_SIZE,
  CLEANUP_PERSONAL_MAX_PER_USER,
  CLEANUP_PERSONAL_PAGE,
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

/** Kişisel koleksiyonlar ve sahiplik alanı (planlayıcı girdisindeki sırayla). */
const PERSONAL_SOURCES: ReadonlyArray<readonly [string, string]> = [
  [Col.notifications, 'userId'],
  [Col.savedPosts, 'userId'],
  [Col.blocks, 'blockerId'],
];
const PERSONAL_PREFIXES = PERSONAL_SOURCES.map(([collection]) => `${collection}/`);

/** Kişisel okuma sınırları (bkz. [CleanupLimits]). */
export type PersonalReadLimits = Partial<Pick<CleanupLimits, 'personalPage' | 'personalMax'>>;

/** Sorgu sonucunu [out]'a yazar, her belgenin sürümünü [versions]'a kaydeder. */
function collect(
  snapshot: QuerySnapshot<DocumentData>,
  collection: string,
  versions: Versions,
  out: Record<string, Doc>,
): void {
  for (const doc of snapshot.docs) {
    versions.set(`${collection}/${doc.id}`, doc.updateTime);
    out[doc.id] = plain(doc.data()) as Doc;
  }
}

/** Hesabın kritik belgeleri (yalnızca okuma; `personal` boş) + okunan her belgenin sürümü. */
export async function readCriticalState(
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
    collect(snapshot, collection, versions, out);
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
    personal: {},
  };
  return { input, versions };
}

/**
 * Hesabın silinmemiş kişisel belgeleri: koleksiyon başına `orderBy(documentId())` sayfalarla, en çok `personalMax`
 * belge (T-45 A5-02 — limitsiz okuma yok).
 */
export async function readPersonalState(
  db: Firestore,
  uid: string,
  limits: PersonalReadLimits = {},
): Promise<{ personal: Record<string, Record<string, Doc>>; versions: Versions }> {
  const page = Math.max(1, limits.personalPage ?? CLEANUP_PERSONAL_PAGE);
  const max = Math.max(0, limits.personalMax ?? CLEANUP_PERSONAL_MAX_PER_USER);
  const versions: Versions = new Map();
  const personal: Record<string, Record<string, Doc>> = {};
  for (const [collection, field] of PERSONAL_SOURCES) {
    const out: Record<string, Doc> = {};
    const base = db
      .collection(collection)
      .where(field, '==', uid)
      .where('isDeleted', '==', false)
      .orderBy(FieldPath.documentId());
    let cursor: QueryDocumentSnapshot | undefined;
    for (let read = 0; read < max; ) {
      const size = Math.min(page, max - read);
      const snapshot = await (cursor ? base.startAfter(cursor) : base).limit(size).get();
      collect(snapshot, collection, versions, out);
      read += snapshot.size;
      if (snapshot.size < size) break;
      cursor = snapshot.docs[snapshot.docs.length - 1];
    }
    personal[collection] = out;
  }
  return { personal, versions };
}

/** Hesabın kalan belgeleri (kritik + sınırlı kişisel; yalnızca okuma) + okunan her belgenin sürümü. */
export async function readCleanupState(
  db: Firestore,
  uid: string,
  now: Date,
  limits: PersonalReadLimits = {},
): Promise<{ input: CleanupInput; versions: Versions }> {
  const critical = await readCriticalState(db, uid, now);
  const { personal, versions } = await readPersonalState(db, uid, limits);
  for (const [path, version] of versions) critical.versions.set(path, version);
  return { input: { ...critical.input, personal }, versions: critical.versions };
}

/** 2. geçişin planlayıcı girdisi: yalnızca kişisel belgeler (kritik alanlar boş → yalnızca kişisel birim üretir). */
const personalOnly = (
  uid: string,
  now: Date,
  user: Doc,
  personal: Record<string, Record<string, Doc>>,
): CleanupInput => ({
  uid,
  now,
  user,
  account: null,
  memberships: {},
  contacts: {},
  clubs: {},
  rsvps: {},
  events: {},
  personal,
});

/** Tek yazımlı kişisel soft delete birimi mi (gruplanabilir)? */
const isPersonalUnit = (unit: PlanWrite[]): boolean =>
  unit.length === 1 && PERSONAL_PREFIXES.some((prefix) => unit[0].path.startsWith(prefix));

/** `applied` / `rejected` / `failed` batch (commit) sayısıdır. */
export interface ApplyResult {
  applied: number;
  rejected: number;
  failed: number;
}

export interface ApplyOptions {
  /** Kişisel gruplu batch boyu (varsayılan [CLEANUP_PERSONAL_PAGE]). */
  batchSize?: number;
  /** Her batch'ten önce sorulur; `true` → kalan birimler yazılmaz (sonraki koşu). */
  stop?: () => boolean;
}

/**
 * Kritik birimleri ayrı batch'lerde (ilk yazım okunan sürüm önkoşuluyla), kişisel tek yazımlı birimleri ≤ `batchSize`
 * gruplu batch'lerde (her yazım kendi önkoşuluyla) uygular.
 */
export async function applyCleanupPlan(
  db: Firestore,
  plan: CleanupPlan,
  versions: Versions,
  options: ApplyOptions = {},
): Promise<ApplyResult> {
  const batchSize = Math.max(1, options.batchSize ?? CLEANUP_PERSONAL_PAGE);
  const stop = options.stop ?? (() => false);
  const out: ApplyResult = { applied: 0, rejected: 0, failed: 0 };
  const batches: Array<{ writes: PlanWrite[]; eachPreconditioned: boolean }> = [];
  const personal: PlanWrite[] = [];
  for (const unit of plan.units) {
    if (unit.length === 0) continue;
    if (isPersonalUnit(unit)) personal.push(unit[0]);
    else batches.push({ writes: unit, eachPreconditioned: false });
  }
  for (let i = 0; i < personal.length; i += batchSize) {
    batches.push({ writes: personal.slice(i, i + batchSize), eachPreconditioned: true });
  }
  for (const { writes, eachPreconditioned } of batches) {
    if (stop()) break;
    const batch = db.batch();
    writes.forEach((write, index) => {
      const ref = db.doc(write.path);
      const data = materialize(write.data) as Record<string, unknown>;
      const version = eachPreconditioned || index === 0 ? versions.get(write.path) : undefined;
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
  /** Atlanan ya da kritik planı boş hesaplar (kişisel belgeleri 2. geçişte ayrıca yazılabilir). */
  skipped: number;
  warnings: number;
  /** Süre bütçesi doldu → koşu erken durdu, kalanı sonraki koşu. */
  budgetHit: boolean;
}

/** Koşu sınırları (testler küçük değerlerle çağırır). */
export interface CleanupLimits {
  pageSize: number;
  maxUsers: number;
  budgetMs: number;
  /** Süre bütçesinin saati (gerçek geçen süre; `deps.now` sabit olabilir). */
  elapsed: () => number;
  /** Kişisel okuma sayfası = gruplu yazım batch'i ([CLEANUP_PERSONAL_PAGE]). */
  personalPage: number;
  /** Koşu başına hesap × koleksiyon başına en çok kişisel belge ([CLEANUP_PERSONAL_MAX_PER_USER]). */
  personalMax: number;
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
  const personalLimits: PersonalReadLimits = { personalPage: limits.personalPage, personalMax: limits.personalMax };
  const from = Timestamp.fromMillis(now.getTime() - CLEANUP_MAX_AGE_MS);
  const to = Timestamp.fromMillis(now.getTime() - CLEANUP_MIN_AGE_MS);
  const summary: CleanupRunResult = {
    users: 0,
    skipped: 0,
    warnings: 0,
    applied: 0,
    rejected: 0,
    failed: 0,
    budgetHit: false,
  };
  /** Bütçe doldu mu? Bir kez dolunca koşunun geri kalanı durur. */
  const overBudget = (): boolean => {
    if (!summary.budgetHit && elapsed() >= budgetMs) summary.budgetHit = true;
    return summary.budgetHit;
  };
  const add = (result: ApplyResult): void => {
    summary.applied += result.applied;
    summary.rejected += result.rejected;
    summary.failed += result.failed;
  };
  const base = db
    .collection(Col.users)
    .where('status', '==', 'deleted')
    .where('deletedAt', '>=', from)
    .where('deletedAt', '<', to)
    .orderBy('deletedAt', 'asc')
    .limit(pageSize);

  // 1. geçiş — kritik birimler (pencere sırasıyla). Planı atlanmayan her hesap 2. geçişe sıralanır.
  const queue: Array<{ uid: string; user: Doc }> = [];
  let cursor: QueryDocumentSnapshot | undefined;
  let worked = 0;
  scan: for (;;) {
    if (overBudget()) break;
    const page = await (cursor ? base.startAfter(cursor) : base).get();
    for (const doc of page.docs) {
      if (worked >= maxUsers || overBudget()) break scan;
      summary.users += 1;
      try {
        const { input, versions } = await readCriticalState(db, doc.id, now);
        const plan = buildCleanupPlan(input);
        summary.warnings += plan.warnings.length;
        if (plan.skip) {
          summary.skipped += 1;
          continue;
        }
        queue.push({ uid: doc.id, user: input.user as Doc });
        if (plan.units.length === 0) {
          summary.skipped += 1;
          continue;
        }
        worked += 1;
        add(await applyCleanupPlan(db, plan, versions, { stop: overBudget }));
      } catch (error) {
        summary.failed += 1;
        log.warn('hesap temizliği okunamadı', errorFields(error));
      }
    }
    if (page.size < pageSize || worked >= maxUsers) break;
    cursor = page.docs[page.docs.length - 1];
  }

  // 2. geçiş — kişisel belgeler, kalan bütçeyle (hesap × koleksiyon başına sınırlı, gruplu batch).
  for (const { uid, user } of queue) {
    if (overBudget()) break;
    try {
      const { personal, versions } = await readPersonalState(db, uid, personalLimits);
      const plan = buildCleanupPlan(personalOnly(uid, now, user, personal));
      if (plan.units.length === 0) continue;
      add(await applyCleanupPlan(db, plan, versions, { batchSize: limits.personalPage, stop: overBudget }));
    } catch (error) {
      summary.failed += 1;
      log.warn('kişisel temizlik okunamadı', errorFields(error));
    }
  }
  log.info('hesap silme temizliği', { ...summary });
  return summary;
}
