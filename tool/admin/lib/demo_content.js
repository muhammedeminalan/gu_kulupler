'use strict';
/**
 * Demo içerik (seed_demo_content.js) — saf yardımcılar (firebase-admin yüklemez; tool/test ile sınanır).
 *
 * Emülatör tohumlayıcısının dönüşümünü (tool/seed/lib/convert.js) GERÇEK projeye uyarlar: kulüpler, üyelikler,
 * gönderiler, yorumlar, etkinlikler, katılımlar ve demo profiller yazılır. Bildirim ve şikayet belgeleri
 * yazılmaz: Functions tetikleyicileri (`sendPushOnNotificationCreated`, `notifyNewReport`) gerçek cihazlara
 * push gönderirdi. Silinmiş hesap dizisi (T-29) ve destek talepleri de atlanır. Auth kullanıcısı açılmaz:
 * demo profiller yalnızca içerik sahibi olarak görünür, giriş yapılamaz.
 */
const { BATCH_MAX_WRITES, packUnits } = require('./admin_cli');
const { COLLECTIONS, PATH_OF, convert, convertManagement, withExtras } = require('../../seed/lib/convert');

/** Gerçek projede yazılmayan koleksiyonlar (Functions push tetikler). */
const EXCLUDED = Object.freeze(['notifications', 'reports']);

const isExcluded = (docPath) => EXCLUDED.includes(docPath.split('/')[0]);

/**
 * Demo verisini yazım planına çevirir.
 * @param {{data: object, extraNotifications: object, management: object}} sources demo-*.json içerikleri
 * @returns {{writes: Array<{op: 'set', path: string, data: object}>, images: object[], clubIds: string[], counts: Record<string, number>}}
 */
function buildDemoContent(sources, { now, randomHex }) {
  const raw = withExtras(sources.data, sources.extraNotifications);
  const { docs, images } = convert(raw, { now, randomHex });
  const management = convertManagement(raw, sources.management, { now });
  const pairs = [
    ...COLLECTIONS.filter((name) => !EXCLUDED.includes(name))
      .flatMap((name) => Object.entries(docs[name]).map(([id, data]) => [PATH_OF[name](id), data])),
    ...management.writes,
  ].filter(([docPath]) => !isExcluded(docPath));
  const writes = pairs.map(([docPath, data]) => ({ op: 'set', path: docPath, data }));
  const counts = {};
  for (const { path } of writes) {
    const key = path.replace(/\/[^/]+(\/|$)/g, '/*$1');
    counts[key] = (counts[key] || 0) + 1;
  }
  return { writes, images, clubIds: Object.keys(docs.clubs), counts };
}

/** Yazımları batch'lere böler (her belge tek başına bir birim). */
const toBatches = (writes, max = BATCH_MAX_WRITES) => packUnits(writes.map((w) => [w]), max);

module.exports = { EXCLUDED, buildDemoContent, toBatches };
