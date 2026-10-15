/**
 * W-91 · yarım kalan hesap silme temizliğinin SAF planlayıcısı — `tool/admin/lib/account_cleanup.js#buildCleanupPlan`
 * dosyasının TS portu (CD-165 b4). Aynı girdi → aynı çıktı (nöbetçiler dahil); `test/account_cleanup.test.ts` iki
 * planlayıcıyı aynı girdilerle karşılaştırır. Kuralları değiştiren İKİSİNİ birlikte değiştirir.
 *
 * Neden kopya: deploy kaynağı yalnızca `functions/`dır; `tool/admin` pakete girmez.
 *
 * Kurallar (özet; ayrıntı JS dosyasında): yalnızca `status == 'deleted'`; hesap belgesi e-posta / jeton boşaltma;
 * açık katılım → `cancelled` + sayaç −1 aynı birimde (biten etkinliğin kaydı korunur — W-80); üyelik M14 (etkin
 * BAŞKAN `left` yapılmaz — W-90); danışman bağı; iletişim belgesi; kişisel belgeler soft delete; idempotent.
 */
import { isValidId } from './model';

/** Sunucu zamanı nöbetçisi (uygulayıcı `FieldValue.serverTimestamp()`'a çevirir). */
export const SERVER_TIME = Object.freeze({ $serverTimestamp: true as const });

/** Sayaç deltası nöbetçisi (uygulayıcı `FieldValue.increment(n)`'e çevirir). */
export const increment = (n: number): Readonly<{ $increment: number }> => Object.freeze({ $increment: n });

/** `Anonymization` (packages/gu_data) ile aynı değerler. */
export const ANON_APPLICANT = Object.freeze({
  name: 'Silinmiş kullanıcı',
  department: null,
  year: null,
  avatarSeed: 'deleted',
});

/** Saat kayması payı (`Limits.clockSkewTolerance`): bu kadar içinde biten etkinliğin kaydı korunur. */
export const END_SKEW_MS = 5 * 60 * 1000;

const OPEN_RSVP: ReadonlySet<unknown> = new Set(['going', 'waitlist']);
const COUNTED_ROLES: ReadonlySet<unknown> = new Set(['member', 'board']);

export type Doc = Record<string, unknown>;

export interface PlanWrite {
  op: 'update';
  path: string;
  data: Record<string, unknown>;
}

export interface CleanupInput {
  uid: string;
  now: Date;
  user: Doc | null;
  account: Doc | null;
  memberships: Record<string, Doc>;
  contacts: Record<string, Doc | null>;
  clubs: Record<string, Doc | null>;
  rsvps: Record<string, Doc>;
  events: Record<string, Doc | null>;
  personal: Record<string, Record<string, Doc>>;
}

export interface CleanupPlan {
  skip: string | null;
  units: PlanWrite[][];
  warnings: string[];
  counts: { account: number; rsvps: number; memberships: number; contacts: number; personal: number };
}

const isAnonApplicant = (a: unknown): boolean => {
  if (!a || typeof a !== 'object') return false;
  const x = a as Doc;
  return (
    x.name === ANON_APPLICANT.name &&
    x.department === null &&
    x.year === null &&
    x.avatarSeed === ANON_APPLICANT.avatarSeed
  );
};
const isBlank = (doc: Doc, fields: string[]): boolean =>
  fields.every((f) => doc[f] === '' || doc[f] === undefined || doc[f] === null);
const toMillis = (value: unknown): number =>
  value instanceof Date ? value.getTime() : typeof value === 'number' ? value : NaN;
const update = (path: string, data: Record<string, unknown>): PlanWrite => ({
  op: 'update',
  path,
  data: { ...data, updatedAt: SERVER_TIME },
});
const byKey = <T>(entries: Array<[string, T]>): Array<[string, T]> => entries.sort(([a], [b]) => a.localeCompare(b));

export function buildCleanupPlan(input: CleanupInput): CleanupPlan {
  const { uid, now } = input;
  const result: CleanupPlan = {
    skip: null,
    units: [],
    warnings: [],
    counts: { account: 0, rsvps: 0, memberships: 0, contacts: 0, personal: 0 },
  };
  if (!isValidId(uid)) throw new Error(`geçersiz uid: ${uid}`);
  if (!input.user) return { ...result, skip: 'kullanıcı belgesi yok' };
  if (input.user.status !== 'deleted') return { ...result, skip: `hesap silinmemiş (status: ${String(input.user.status)})` };

  const account = input.account;
  if (account && (!isBlank(account, ['email', 'emailLower']) || ((account.fcmTokens as unknown[]) || []).length > 0)) {
    result.units.push([update(`users/${uid}/private/account`, { email: '', emailLower: '', fcmTokens: [] })]);
    result.counts.account += 1;
  }

  // Sayaçlar planlanan deltalarla izlenir: aynı etkinlik / kulüp iki kez düşülmez, 0'ın altına inilmez.
  const counters = new Map<string, number>();
  const decrement = (path: string, field: string, current: unknown): boolean => {
    const key = `${path}#${field}`;
    const base = counters.has(key) ? (counters.get(key) as number) : (current as number);
    const left = base - 1;
    if (!(left >= 0)) return false;
    counters.set(key, left);
    return true;
  };

  for (const [id, rsvp] of byKey(Object.entries(input.rsvps))) {
    if (rsvp.userId !== uid || id !== `${String(rsvp.eventId)}_${uid}` || !OPEN_RSVP.has(rsvp.status)) continue;
    const eventId = rsvp.eventId as string;
    const event = input.events[eventId];
    if (!event || event.isDeleted === true) continue;
    if (!(toMillis(event.endsAt) > now.getTime() + END_SKEW_MS)) continue; // W-80: biten etkinliğin kaydı kalır
    const field = rsvp.status === 'waitlist' ? 'waitlistCount' : 'goingCount';
    const unit = [update(`rsvps/${id}`, { status: 'cancelled' })];
    if (decrement(`events/${eventId}`, field, event[field])) {
      unit.push(update(`events/${eventId}`, { [field]: increment(-1) }));
    } else {
      result.warnings.push(`events/${eventId}: ${field} zaten 0 — sayaç düşülmedi`);
    }
    result.units.push(unit);
    result.counts.rsvps += 1;
  }

  for (const [id, membership] of byKey(Object.entries(input.memberships))) {
    // Bileşik kimlik tek başına kanıt değildir: sahiplik alanlardan okunur.
    if (membership.userId !== uid || id !== `${String(membership.clubId)}_${uid}`) continue;
    const clubId = membership.clubId as string;
    const clubPath = `clubs/${clubId}`;
    const club = input.clubs[clubId];
    const { status, role } = membership;
    const isPresident = status === 'active' && role === 'president';
    const next = isPresident ? status : status === 'active' ? 'left' : status === 'pending' ? 'cancelled' : status;
    const unit: PlanWrite[] = [];
    if (next !== status || !isAnonApplicant(membership.applicant)) {
      unit.push(update(`memberships/${id}`, { ...(next !== status ? { status: next } : {}), applicant: { ...ANON_APPLICANT } }));
      result.counts.memberships += 1;
    }
    if (isPresident) {
      result.warnings.push(
        `${clubPath}: silinmiş hesap etkin BAŞKAN — önce ADM-03'te başkan ata (W-90; eski başkan board olur), sonra betiği yeniden çalıştır`,
      );
    }
    if (status === 'active' && COUNTED_ROLES.has(role) && club && club.isDeleted !== true) {
      if (decrement(clubPath, 'memberCount', club.memberCount)) {
        unit.push(update(clubPath, { memberCount: increment(-1) }));
      } else {
        result.warnings.push(`${clubPath}: memberCount zaten 0 — sayaç düşülmedi`);
      }
    }
    // Durumdan bağımsız: uygulamadaki M14 danışman üyeliğini `left` yapar ama kulüp bağını ayıramaz (bayat bağ).
    const advisor = club?.advisor as Doc | null | undefined;
    if (role === 'advisor' && club && advisor && advisor.userId === uid) {
      unit.push(update(clubPath, { 'advisor.userId': null }));
    }
    const contact = input.contacts[id];
    if (contact && !isBlank(contact, ['email', 'emailLower', 'note'])) {
      unit.push(update(`memberships/${id}/private/contact`, { email: '', emailLower: '', note: '' }));
      result.counts.contacts += 1;
    }
    if (unit.length > 0) result.units.push(unit);
  }

  for (const [collection, docs] of Object.entries(input.personal)) {
    for (const id of Object.keys(docs).sort()) {
      if (docs[id].isDeleted === true) continue;
      result.units.push([update(`${collection}/${id}`, { isDeleted: true, deletedAt: SERVER_TIME, deletedBy: uid })]);
      result.counts.personal += 1;
    }
  }
  return result;
}
