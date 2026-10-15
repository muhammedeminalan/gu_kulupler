/**
 * Push freni (T-42 güvenlik incelemesi; rules-spec §9.3, PLAN R-07 / S-3). Hibritte (CD-165) bildirim belgelerini
 * istemci yazar ve Rules fan-out türlerinde alıcının olayla bağını DOĞRULAMAZ (alıcı başına `get` bütçeyi aşar). Gelen
 * kutusu spam'i kabul edilmiş sınırlamadır (K-J, CD-65); ama push kilit ekranına düşer ve FORCED türler kapatılamaz.
 * Sunucu bu yüzden push'tan ÖNCE iki ucuz denetim yapar (bildirim belgesine dokunmaz — gelen kutusu aynen kalır):
 *
 * 1. **Bağ** ([linkOf]) — alıcı olayın doğal alıcısı mı (istemcinin `RecipientResolver`'ı ile aynı küme):
 *    | Tür | Bağ |
 *    |---|---|
 *    | `announcement` | `memberships/{clubId}_{uid}.status == 'active'` (`membersOf`) |
 *    | `event_cancelled` | `rsvps/{eventId}_{uid}.status ∈ {going, waitlist}` (`rsvpUsersOf`) |
 *    | `event_new` | etkin üye, ya da etkinlik bu kulübün ve `visibility == 'public'` (ilgi eşleşmesi — CD-38) |
 *    Diğer türler Rules'ta alıcının kendi geçişine bağlıdır → bağ denetlenmez. Geçiş tek seferlik DEĞİLDİR (T-45 S2-01 /
 *    A5-03): `removed_from_club` (FORCED; hedef member ise yönetim kurulu da — M9 ↔ M12b 30 sn geri al), `role_changed`
 *    (FORCED; başkanın rol aç-kapa döngüsü — M10) ve `application_approved` / `_rejected` (tercihle kapatılabilir —
 *    M5 / M6 ↔ M12a) döngüyle sınırsız yinelenebilir; her tur Rules'tan geçen yeni bir gelen kutusu belgesidir (kabul —
 *    K-J, CD-65), push'u ise aşağıdaki kapsam kilidi frenler.
 * 2. **Kapsam kilidi** ([gateIdFor]) — aynı kapsamın ikinci push'u gönderilmez: `pushReceipts/once_{type}_{key}_{uid}`
 *    `create()` (zaten varsa `throttled`). Kapsamlar: `event_new` üyeye etkinlik başına, üye olmayana kulüp başına
 *    günde bir; `application_received` (kulüp, başvuran) başına günde bir; `new_report` admin başına 15 dakikada bir;
 *    karar türleri ([DECISION_TYPES]: `removed_from_club`, `role_changed`, `application_approved`,
 *    `application_rejected`) (tür, kulüp, alıcı) başına Istanbul günü başına bir (T-45 — aynı günün meşru ikinci kararı
 *    da yalnızca gelen kutusunda görünür; tür kimlikte olduğundan onay ve ret ayrı sayılır).
 *    `once_` öneki bildirim kimliği olamaz (tür öneki beyaz listede) → makbuzlarla çakışmaz.
 */
import { Firestore } from 'firebase-admin/firestore';
import { Col, NEW_REPORT_PUSH_WINDOW_MS, TIME_ZONE } from './config';
import { eventKeyOf } from './ids';
import { isValidId, Refs } from './model';

/** Alıcının olayla bağı: `none` → push gönderilmez; `unchecked` → türde bağ denetimi yok. */
export type Link = 'member' | 'attendee' | 'public' | 'none' | 'unchecked';

const OPEN_RSVP: ReadonlySet<unknown> = new Set(['going', 'waitlist']);

/** Kapsam kilidi belgelerinin kimlik öneki (`pushReceipts` içinde). */
export const GATE_PREFIX = 'once_';

/**
 * Yöneticinin geri alınabilir kararından doğan türler (T-45 S2-01 / A5-03): döngüyle yinelenebilir → (tür, kulüp,
 * alıcı) başına Istanbul günü başına bir push.
 */
export const DECISION_TYPES: ReadonlySet<string> = new Set([
  'removed_from_club',
  'role_changed',
  'application_approved',
  'application_rejected',
]);

async function activeMember(db: Firestore, clubId: string | undefined, userId: string): Promise<boolean> {
  if (!isValidId(clubId)) return false;
  const snap = await db.collection(Col.memberships).doc(`${clubId}_${userId}`).get();
  return (
    snap.exists && snap.get('clubId') === clubId && snap.get('userId') === userId && snap.get('status') === 'active'
  );
}

/** [userId] alıcısının [type] / [refs] olayıyla bağı (bileşik kimlik tek başına kanıt değil: alanlar da tutmalı). */
export async function linkOf(db: Firestore, type: string, refs: Refs, userId: string): Promise<Link> {
  switch (type) {
    case 'announcement':
      return (await activeMember(db, refs.clubId, userId)) ? 'member' : 'none';
    case 'event_cancelled': {
      if (!isValidId(refs.eventId)) return 'none';
      const rsvp = await db.collection(Col.rsvps).doc(`${refs.eventId}_${userId}`).get();
      const ok =
        rsvp.exists &&
        rsvp.get('eventId') === refs.eventId &&
        rsvp.get('userId') === userId &&
        OPEN_RSVP.has(rsvp.get('status'));
      return ok ? 'attendee' : 'none';
    }
    case 'event_new': {
      if (await activeMember(db, refs.clubId, userId)) return 'member';
      if (!isValidId(refs.eventId)) return 'none';
      const event = await db.collection(Col.events).doc(refs.eventId).get();
      const ok = event.exists && event.get('clubId') === refs.clubId && event.get('visibility') === 'public';
      return ok ? 'public' : 'none';
    }
    default:
      return 'unchecked';
  }
}

const istanbulDate = new Intl.DateTimeFormat('en-CA', {
  timeZone: TIME_ZONE,
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
});

/** [now] anının Istanbul yerel günü (`YYYY-MM-DD`). */
export const istanbulDay = (now: Date): string => istanbulDate.format(now);

/** Kapsam kilidi belge kimliği; türde kilit yoksa `null`. */
export function gateIdFor(type: string, refs: Refs, userId: string, link: Link, now: Date): string | null {
  let scope: string | null;
  switch (type) {
    case 'event_new':
      scope = link === 'member' ? `event|${refs.eventId}` : `club|${refs.clubId}|${istanbulDay(now)}`;
      break;
    case 'application_received':
      scope = `apply|${refs.clubId}|${refs.applicantId}|${istanbulDay(now)}`;
      break;
    case 'new_report':
      scope = `report|${Math.floor(now.getTime() / NEW_REPORT_PUSH_WINDOW_MS)}`;
      break;
    default:
      scope = DECISION_TYPES.has(type) ? `decision|${refs.clubId}|${istanbulDay(now)}` : null;
  }
  return scope === null ? null : `${GATE_PREFIX}${type}_${eventKeyOf(scope)}_${userId}`;
}
