/**
 * Sunucunun yazdığı bildirim belgelerinin kimliği ve şeması (T-25 ile birebir — `FirestoreIds.notification`,
 * `NotificationWriter` dartdoc'u, `tool/admin/lib/system_notification.js`).
 */
import { createHash } from 'node:crypto';
import { FieldValue } from 'firebase-admin/firestore';
import { EVENT_KEY_LENGTH } from './config';
import { NotificationType, Refs } from './model';

/** Deterministik olay anahtarı: `sha256(input).hex` ilk 20 karakter (yeniden teslimde aynı anahtar). */
export const eventKeyOf = (input: string): string =>
  createHash('sha256').update(input, 'utf8').digest('hex').slice(0, EVENT_KEY_LENGTH);

/** `notifications/{type}_{eventKey}_{userId}`. */
export const notificationId = (type: NotificationType, eventKey: string, userId: string): string =>
  `${type}_${eventKey}_${userId}`;

/**
 * Bildirim belgesi: `userId`, `type`, `refs` (yalnızca dolu referanslar — W-51), `read: false`, sunucu zamanlı
 * `createdAt` / `updatedAt`, `isDeleted: false`, `deletedAt` / `deletedBy` null.
 */
export function notificationData(type: NotificationType, userId: string, refs: Refs): Record<string, unknown> {
  const now = FieldValue.serverTimestamp();
  const filled: Refs = {};
  for (const [key, value] of Object.entries(refs) as Array<[keyof Refs, string | undefined]>) {
    if (typeof value === 'string' && value.length > 0) filled[key] = value;
  }
  return {
    userId,
    type,
    refs: filled,
    read: false,
    createdAt: now,
    updatedAt: now,
    isDeleted: false,
    deletedAt: null,
    deletedBy: null,
  };
}
