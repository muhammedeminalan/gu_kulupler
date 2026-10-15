'use strict';
/**
 * PLAN §10.5 / §21.1 #14b · `system` bildirimi planlayıcısı (SAF; `send_system_notification.js`). Mod C'de
 * `system` türünü yalnızca bu betik (Admin SDK) yazar; istemci dalı Rules'ta kapalıdır
 * (`ClientFanOutDispatcher.notifySystem` yazmaz). Belge biçimi `NotificationWriter` ile aynıdır: kimlik
 * `system_{eventKey}_{uid}` (tek olay anahtarı, alıcı eki), `refs: {textKey}`, `read: false`, BaseFields.
 */
const crypto = require('crypto');
const { SERVER_TIME, isValidId } = require('./admin_cli');

/** `NotificationRefsModel.textKey` değerleri (metin ARB'de: `notificationSystem*`). */
const TEXT_KEYS = Object.freeze(['welcome', 'maintenance']);

/** Olay anahtarı biçimi (`NotificationWriter.newEventKey`; Rules `[A-Za-z0-9]{20}`). */
const EVENT_KEY = /^[A-Za-z0-9]{20}$/;
const ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

/** Kriptografik kaynaktan 20 karakterlik olay anahtarı. */
function newEventKey(randomBytes = crypto.randomBytes) {
  const bytes = randomBytes(20);
  return Array.from(bytes, (b) => ALPHABET[b % ALPHABET.length]).join('');
}

/**
 * @param {{textKey: string, uids: string[], eventKey: string}} input alıcılar tekilleştirilir (sıra korunur)
 * @returns {Array<{op: 'set', path: string, data: object}>}
 */
function buildSystemNotifications({ textKey, uids, eventKey }) {
  if (!TEXT_KEYS.includes(textKey)) throw new Error(`--text-key ${TEXT_KEYS.join(' | ')} olmalı: ${textKey}`);
  if (!EVENT_KEY.test(eventKey)) throw new Error(`olay anahtarı biçimi geçersiz: ${eventKey}`);
  const unique = [...new Set(uids)];
  if (unique.length === 0) throw new Error('alıcı yok');
  for (const uid of unique) if (!isValidId(uid)) throw new Error(`geçersiz uid: ${uid}`);
  return unique.map((uid) => ({
    op: 'set',
    path: `notifications/system_${eventKey}_${uid}`,
    data: {
      userId: uid,
      type: 'system',
      refs: { textKey },
      read: false,
      isDeleted: false,
      createdAt: SERVER_TIME,
      updatedAt: SERVER_TIME,
      deletedAt: null,
      deletedBy: null,
    },
  }));
}

module.exports = { EVENT_KEY, TEXT_KEYS, buildSystemNotifications, newEventKey };
