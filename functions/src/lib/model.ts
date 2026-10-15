/**
 * Bildirim türleri, referanslar ve küçük ayrıştırma yardımcıları (T-25 şeması — `NotificationType`,
 * `NotificationRefsModel`; docs/plans/T-25.md §6).
 */

/** Uygulamanın tanıdığı bildirim türleri (`NotificationType.json`; `unknown` hariç). */
export const NOTIFICATION_TYPES = [
  'application_received',
  'application_approved',
  'application_rejected',
  'removed_from_club',
  'role_changed',
  'announcement',
  'event_new',
  'event_reminder',
  'event_cancelled',
  'waitlist_promoted',
  'report_resolved',
  'new_report',
  'system',
] as const;
export type NotificationType = (typeof NOTIFICATION_TYPES)[number];

const KNOWN: ReadonlySet<string> = new Set(NOTIFICATION_TYPES);

/** Tanınan tür mü? (Bilinmeyen tür uygulamada `unknown` olur ve gizlenir.) */
export const isKnownType = (type: unknown): type is NotificationType => typeof type === 'string' && KNOWN.has(type);

/** `refs` alanları (`NotificationRefsModel`; hepsi isteğe bağlı dizge). */
export const REF_KEYS = ['clubId', 'eventId', 'postId', 'applicantId', 'reportId', 'role', 'textKey'] as const;
export type RefKey = (typeof REF_KEYS)[number];
export type Refs = Partial<Record<RefKey, string>>;

/** Belgedeki `refs` haritasından yalnızca dolu dizge alanları (W-51: boş / null alan yok sayılır). */
export function refsFrom(value: unknown): Refs {
  const out: Refs = {};
  if (!value || typeof value !== 'object') return out;
  const raw = value as Record<string, unknown>;
  for (const key of REF_KEYS) {
    const v = raw[key];
    if (typeof v === 'string' && v.length > 0) out[key] = v;
  }
  return out;
}

/** Tek yol parçası olabilen kimlik (`RepositoryHelpers.isValidId`). */
export const isValidId = (id: unknown): id is string =>
  typeof id === 'string' && id.length > 0 && !id.includes('/') && id !== '.' && id !== '..' && !/^__.*__$/.test(id);

/** Firestore `Timestamp` / `Date` / milisaniye → `Date` (çözülemezse `null`). */
export function toDate(value: unknown): Date | null {
  if (value instanceof Date) return value;
  if (typeof value === 'number') return new Date(value);
  if (value && typeof (value as { toDate?: unknown }).toDate === 'function') {
    return (value as { toDate: () => Date }).toDate();
  }
  return null;
}

/** gRPC / Firestore hata kodu karşılaştırması (Admin SDK sayısal `code`, bazı yollarda dizge döner). */
export function hasCode(error: unknown, numeric: number, text: string): boolean {
  const code = (error as { code?: unknown } | null)?.code;
  return code === numeric || code === text;
}

/** `ALREADY_EXISTS` (create çakışması). */
export const isAlreadyExists = (error: unknown): boolean => hasCode(error, 6, 'already-exists');

/** `FAILED_PRECONDITION` (`lastUpdateTime` önkoşulu tutmadı). */
export const isFailedPrecondition = (error: unknown): boolean => hasCode(error, 9, 'failed-precondition');
