'use strict';
/**
 * W-91 · yarım kalan hesap silme temizliğinin SAF planlayıcısı (T-37; sözleşme docs/plans/T-37.md §4 e). Girdi
 * belge anlık görüntüleri (betik okur), çıktı bölünmez yazım grupları — T-29 `FirebaseAccountDeletionRepository`
 * dizisinin (buildPlan → katılım vazgeçme → M14 üyelik anonimleştirme → kişisel belgeler) Admin SDK eşdeğeri.
 *
 * Kurallar (T-29 ile aynı; farklar işaretli):
 *  - Yalnızca `users.status == 'deleted'` hesap; Auth kimliği kalır (Q-11); hiçbir belge silinmez (D-10).
 *  - Hesap belgesi: e-posta / FCM jetonları boş değilse boşaltılır (markDeleted yarım kaldıysa).
 *  - Açık katılım (`going` / `waitlist`) → `cancelled` + etkinlik sayacı −1 AYNI grupta; biten (ya da 5 dk içinde
 *    biten) etkinliğin kaydı korunur (W-80, CD-144); silinmiş / olmayan etkinlik atlanır.
 *  - Üyelik (M14): etkin üye / kurul → `left` + kulüp `memberCount −1` aynı grupta; bekleyen → `cancelled`; etkin
 *    danışman → `left` (sayaç yok) ve kulübün `advisor.userId`'si bu hesapsa `null` (yeni danışman bağlanabilsin —
 *    M13); geçmiş üyelikte yalnızca anlık görüntü; hepsinde `applicant` anonim, iletişim belgesi boş.
 *  - **Etkin BAŞKAN `left` yapılmaz** (sözleşme §4 e'den sapma — T-37 bağlama kararı): `presidentId` ayrılmış bir
 *    üyeliği gösterirse ADM-03 başkan ataması (eski başkanın etkin başkan üyeliğini ister) kilitlenirdi. Başkanın
 *    yalnızca kişisel verisi boşalır ve "önce başkan ata" uyarısı çıkar (W-90): `AdminRepository.assignPresident`
 *    silinmiş başkanı `board` yapar; betik yeniden koşunca o üyelik `left` olur (sayaç −1).
 *  - Sayaç 0'ın altına inmez (uyarı). Kişisel belgeler (`notifications`, `savedPosts`, `blocks`) soft delete.
 *  - İdempotent: yalnızca nihai olmayan durumlar / boşalmamış alanlar yazılır; ikinci koşum boş plan üretir.
 */
const { SERVER_TIME, increment, isValidId } = require('./admin_cli');

/** `Anonymization` (packages/gu_data) ile aynı değerler. */
const ANON_APPLICANT = Object.freeze({ name: 'Silinmiş kullanıcı', department: null, year: null, avatarSeed: 'deleted' });

/** Saat kayması payı (`Limits.clockSkewTolerance`): bu kadar içinde biten etkinliğin kaydı korunur. */
const END_SKEW_MS = 5 * 60 * 1000;

const OPEN_RSVP = new Set(['going', 'waitlist']);
const COUNTED_ROLES = new Set(['member', 'board']);

const isAnonApplicant = (a) =>
  !!a && a.name === ANON_APPLICANT.name && a.department === null && a.year === null && a.avatarSeed === ANON_APPLICANT.avatarSeed;
const isBlank = (doc, fields) => fields.every((f) => doc[f] === '' || doc[f] === undefined || doc[f] === null);
const toMillis = (value) => (value instanceof Date ? value.getTime() : typeof value === 'number' ? value : NaN);
const update = (path, data) => ({ op: 'update', path, data: { ...data, updatedAt: SERVER_TIME } });

/**
 * @param {{
 *   uid: string, now: Date, user: object|null, account: object|null,
 *   memberships: Record<string, object>, contacts: Record<string, object|null>, clubs: Record<string, object|null>,
 *   rsvps: Record<string, object>, events: Record<string, object|null>,
 *   personal: {notifications: Record<string, object>, savedPosts: Record<string, object>, blocks: Record<string, object>},
 * }} input zaman alanları `Date` (betik `Timestamp.toDate()` ile çevirir)
 * @returns {{skip: string|null, units: Array<Array<{op: string, path: string, data: object}>>, warnings: string[],
 *   counts: Record<string, number>}}
 */
function buildCleanupPlan(input) {
  const { uid, now } = input;
  const result = { skip: null, units: [], warnings: [], counts: { account: 0, rsvps: 0, memberships: 0, contacts: 0, personal: 0 } };
  if (!isValidId(uid)) throw new Error(`geçersiz uid: ${uid}`);
  if (!input.user) return { ...result, skip: 'kullanıcı belgesi yok' };
  if (input.user.status !== 'deleted') return { ...result, skip: `hesap silinmemiş (status: ${input.user.status})` };

  const account = input.account;
  if (account && (!isBlank(account, ['email', 'emailLower']) || (account.fcmTokens || []).length > 0)) {
    result.units.push([update(`users/${uid}/private/account`, { email: '', emailLower: '', fcmTokens: [] })]);
    result.counts.account += 1;
  }

  // Sayaçlar planlanan deltalarla izlenir: aynı etkinlik / kulüp iki kez düşülmez, 0'ın altına inilmez.
  const counters = new Map();
  const decrement = (path, field, current) => {
    const key = `${path}#${field}`;
    const left = (counters.has(key) ? counters.get(key) : current) - 1;
    if (!(left >= 0)) return false;
    counters.set(key, left);
    return true;
  };

  for (const [id, rsvp] of Object.entries(input.rsvps).sort(([a], [b]) => a.localeCompare(b))) {
    if (rsvp.userId !== uid || id !== `${rsvp.eventId}_${uid}` || !OPEN_RSVP.has(rsvp.status)) continue;
    const event = input.events[rsvp.eventId];
    if (!event || event.isDeleted === true) continue;
    if (!(toMillis(event.endsAt) > now.getTime() + END_SKEW_MS)) continue; // W-80: biten etkinliğin kaydı kalır
    const field = rsvp.status === 'waitlist' ? 'waitlistCount' : 'goingCount';
    const unit = [update(`rsvps/${id}`, { status: 'cancelled' })];
    if (decrement(`events/${rsvp.eventId}`, field, event[field])) {
      unit.push(update(`events/${rsvp.eventId}`, { [field]: increment(-1) }));
    } else {
      result.warnings.push(`events/${rsvp.eventId}: ${field} zaten 0 — sayaç düşülmedi`);
    }
    result.units.push(unit);
    result.counts.rsvps += 1;
  }

  for (const [id, membership] of Object.entries(input.memberships).sort(([a], [b]) => a.localeCompare(b))) {
    // Bileşik kimlik tek başına kanıt değildir: sahiplik alanlardan okunur.
    if (membership.userId !== uid || id !== `${membership.clubId}_${uid}`) continue;
    const clubPath = `clubs/${membership.clubId}`;
    const club = input.clubs[membership.clubId];
    const { status, role } = membership;
    const isPresident = status === 'active' && role === 'president';
    const next = isPresident ? status
      : status === 'active' ? 'left'
        : status === 'pending' ? 'cancelled'
          : status;
    const unit = [];
    if (next !== status || !isAnonApplicant(membership.applicant)) {
      unit.push(update(`memberships/${id}`, { ...(next !== status ? { status: next } : {}), applicant: { ...ANON_APPLICANT } }));
      result.counts.memberships += 1;
    }
    if (isPresident) {
      result.warnings.push(`${clubPath}: silinmiş hesap etkin BAŞKAN — önce ADM-03'te başkan ata (W-90; eski başkan board olur), sonra betiği yeniden çalıştır`);
    }
    if (status === 'active' && COUNTED_ROLES.has(role) && club && club.isDeleted !== true) {
      if (decrement(clubPath, 'memberCount', club.memberCount)) {
        unit.push(update(clubPath, { memberCount: increment(-1) }));
      } else {
        result.warnings.push(`${clubPath}: memberCount zaten 0 — sayaç düşülmedi`);
      }
    }
    // Durumdan bağımsız: uygulamadaki M14 danışman üyeliğini `left` yapar ama kulüp bağını ayıramaz (bayat bağ).
    if (role === 'advisor' && club && club.advisor && club.advisor.userId === uid) {
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

module.exports = { ANON_APPLICANT, END_SKEW_MS, buildCleanupPlan };
