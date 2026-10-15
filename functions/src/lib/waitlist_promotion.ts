/**
 * `promoteWaitlistOnCancel` gövdesi (CD-165 b3; domain-model §8 Mod F): kayıtlı (`going`) bir katılım
 * `cancelled` olunca boşalan yeri en eski bekleyene verir.
 *
 * - Yalnızca `going → cancelled`; diğer her güncelleme no-op → kendi `waitlist → going` yazımı kendini tetiklemez.
 * - Tek transaction: etkinlik `published`, silinmemiş, kulübü yayında (`status == 'active'`, silinmemiş — manuel terfinin
 *   Rules `managedHere` → `clubLive` koşulu; güvenlik incelemesi), `endsAt > now`, `capacity` sayı ve
 *   `goingCount < capacity` değilse çık; aday `rsvps where eventId, clubId, status == waitlist orderBy waitlistAt asc` (mevcut indeks).
 * - Yazımlar manuel `FirebaseAttendanceRepository.promote` ile birebir: kayıt `status: going` + `updatedAt`;
 *   etkinlik `goingCount +1`, `waitlistCount −1` + `updatedAt`; yan belge `events/{id}/private/counter`
 *   `{clubId, lastRsvpRef, updatedAt}` (set); `waitlist_promoted` bildirimi `refs {clubId, eventId}`.
 * - Bildirim kimliği `waitlist_promoted_{sha256(tetik olayı kimliği)[0:20]}_{uid}`. **Sözleşmeye küçük ek:** yeniden
 *   teslimde aday değişir (ilki artık `going`), yani kimlik tek başına çift terfiyi önlemez; transaction aynı olay
 *   anahtarlı bir bildirim belgesini (`__name__` önek aralığı) okur, varsa çıkar → bir iptal = en çok bir terfi.
 */
import { FieldPath, FieldValue } from 'firebase-admin/firestore';
import { Col, WAITLIST_SCAN } from './config';
import { Deps } from './deps';
import { eventKeyOf, notificationData, notificationId } from './ids';
import { isValidId, toDate } from './model';
import { log } from './log';

export type PromotionResult =
  | 'promoted'
  | 'ignored'
  | 'invalid'
  | 'not_published'
  | 'ended'
  | 'unlimited'
  | 'full'
  | 'duplicate'
  | 'empty'
  | 'failed';

/** Önek aralığının üst sınırı (Unicode özel kullanım alanı; kimliklerde geçmez). */
const PREFIX_END = '';

export async function handleRsvpUpdated(
  deps: Pick<Deps, 'db' | 'now'>,
  triggerEventId: string,
  before: Record<string, unknown> | undefined,
  after: Record<string, unknown> | undefined,
): Promise<PromotionResult> {
  if (before?.status !== 'going' || after?.status !== 'cancelled') return 'ignored';
  const eventId = after.eventId;
  const clubId = after.clubId;
  if (!isValidId(eventId) || !isValidId(clubId) || triggerEventId.length === 0) return 'invalid';

  const { db } = deps;
  const key = eventKeyOf(triggerEventId);
  const prefix = `waitlist_promoted_${key}_`;
  const eventRef = db.collection(Col.events).doc(eventId);
  try {
    const result = await db.runTransaction(async (tx): Promise<PromotionResult> => {
      // Transaction kuralı: tüm okumalar yazımlardan önce.
      const eventSnap = await tx.get(eventRef);
      const event = eventSnap.data();
      if (!event || event.isDeleted === true || event.status !== 'published' || event.clubId !== clubId) {
        return 'not_published';
      }
      const club = (await tx.get(db.collection(Col.clubs).doc(clubId))).data();
      if (!club || club.isDeleted !== false || club.status !== 'active') return 'not_published';
      const endsAt = toDate(event.endsAt);
      if (!endsAt || endsAt.getTime() <= deps.now().getTime()) return 'ended';
      const capacity = event.capacity;
      if (typeof capacity !== 'number') return 'unlimited';
      const goingCount = typeof event.goingCount === 'number' ? event.goingCount : 0;
      if (goingCount >= capacity) return 'full';

      const done = await tx.get(
        db
          .collection(Col.notifications)
          .where(FieldPath.documentId(), '>=', prefix)
          .where(FieldPath.documentId(), '<', `${prefix}${PREFIX_END}`)
          .limit(1),
      );
      if (!done.empty) return 'duplicate';

      const queue = await tx.get(
        db
          .collection(Col.rsvps)
          .where('eventId', '==', eventId)
          .where('clubId', '==', clubId)
          .where('status', '==', 'waitlist')
          .orderBy('waitlistAt', 'asc')
          .limit(WAITLIST_SCAN),
      );
      // Bileşik kimlik tek başına kanıt değildir: alanlar ve kimlik birlikte tutmalı.
      const next = queue.docs.find((doc) => {
        const userId = doc.get('userId');
        return isValidId(userId) && doc.id === `${eventId}_${userId}` && doc.get('isDeleted') !== true;
      });
      if (!next) return 'empty';
      const userId = next.get('userId') as string;

      const now = FieldValue.serverTimestamp();
      tx.update(next.ref, { status: 'going', updatedAt: now });
      tx.update(eventRef, {
        goingCount: FieldValue.increment(1),
        waitlistCount: FieldValue.increment(-1),
        updatedAt: now,
      });
      tx.set(eventRef.collection(Col.private).doc(Col.counter), {
        clubId,
        lastRsvpRef: `${Col.rsvps}/${next.id}`,
        updatedAt: now,
      });
      tx.create(
        db.collection(Col.notifications).doc(notificationId('waitlist_promoted', key, userId)),
        notificationData('waitlist_promoted', userId, { clubId, eventId }),
      );
      return 'promoted';
    });
    log.info('bekleme listesi terfisi', { eventId, result });
    return result;
  } catch (error) {
    log.error('bekleme listesi terfisi başarısız', error, { eventId });
    return 'failed';
  }
}
