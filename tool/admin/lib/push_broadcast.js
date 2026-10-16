'use strict';
/**
 * Serbest metinli push (send_push.js) — saf yardımcılar (firebase-admin yüklemez; tool/test ile sınanır).
 *
 * Yalnızca telefona bildirim gönderir; uygulama içi bildirim kutusuna belge YAZMAZ (o iş `system` türünün,
 * send_system_notification.js). Jetonlar `users/{uid}/private/account.fcmTokens` dizisinden okunur
 * (T-42, `{token, platform, locale?, updatedAt}`).
 */

const TITLE_MAX = 60;
const BODY_MAX = 300;
/** FCM `sendEachForMulticast` tek çağrıda en çok 500 jeton kabul eder. */
const MULTICAST_MAX = 500;
const ANDROID_CHANNEL = 'gu_push';
const ANDROID_ICON = 'ic_stat_notification';
const ANDROID_COLOR = '#D00A2D';

function validateText(title, body) {
  const t = (title ?? '').trim();
  const b = (body ?? '').trim();
  if (!t) throw new Error('--title boş olamaz');
  if (!b) throw new Error('--body boş olamaz');
  if (t.length > TITLE_MAX) throw new Error(`--title en çok ${TITLE_MAX} karakter (${t.length})`);
  if (b.length > BODY_MAX) throw new Error(`--body en çok ${BODY_MAX} karakter (${b.length})`);
  return { title: t, body: b };
}

/** Hesap belgelerinin `fcmTokens` dizilerinden benzersiz, boş olmayan jetonlar. */
function collectTokens(accountDatas) {
  const seen = new Set();
  for (const data of accountDatas) {
    const list = Array.isArray(data?.fcmTokens) ? data.fcmTokens : [];
    for (const item of list) {
      const token = typeof item?.token === 'string' ? item.token.trim() : '';
      if (token) seen.add(token);
    }
  }
  return [...seen];
}

/** Jetonları FCM çoklu gönderim parçalarına böler; her parça için mesaj gövdesi. */
function buildMulticasts({ title, body, tokens }) {
  const chunks = [];
  for (let i = 0; i < tokens.length; i += MULTICAST_MAX) {
    chunks.push({
      tokens: tokens.slice(i, i + MULTICAST_MAX),
      notification: { title, body },
      android: {
        priority: 'high',
        notification: { channelId: ANDROID_CHANNEL, icon: ANDROID_ICON, color: ANDROID_COLOR },
      },
      apns: { payload: { aps: { sound: 'default' } } },
    });
  }
  return chunks;
}

module.exports = { TITLE_MAX, BODY_MAX, MULTICAST_MAX, validateText, collectTokens, buildMulticasts };
