'use strict';
// Yazma yükleri — Dart `BaseFieldsPayload` ve `SoftDelete` sınıflarının JS eşleniği
// (packages/gu_data/lib/src/core/{base_fields,soft_delete}.dart). Anahtar kümeleri Dart ile birebirdir;
// `parity.test.js` Dart kaynağını okuyup doğrular. Zaman damgaları istemci saatinden değil
// `serverTimestamp()`'ten gelir: Rules bunları `request.time` ile karşılaştırır.
const { serverTimestamp, increment } = require('firebase/firestore');

/** `BaseFieldsPayload.create()` anahtarları (`createdBy` isteğe bağlı, ayrıca eklenir). */
const BASE_CREATE_KEYS = Object.freeze(['createdAt', 'updatedAt', 'isDeleted', 'deletedAt', 'deletedBy']);

/** `SoftDelete.affectedKeys`. */
const SOFT_DELETE_KEYS = Object.freeze(['isDeleted', 'deletedAt', 'deletedBy', 'updatedAt']);

function requireId(value, name) {
  if (typeof value !== 'string' || value.length === 0) throw new Error(`${name} boş olamaz`);
  return value;
}

/** Yeni belgenin ortak alanları; `createdBy` verilmezse anahtar yüke girmez. */
function baseCreate({ createdBy } = {}) {
  const payload = {
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    isDeleted: false,
    deletedAt: null,
    deletedBy: null,
  };
  if (createdBy !== undefined) payload.createdBy = requireId(createdBy, 'createdBy');
  return payload;
}

/** Güncellenen belgenin ortak alanı. */
function baseUpdate() {
  return { updatedAt: serverTimestamp() };
}

/** `SoftDelete.payload(actorId:)` — silme = update (D-10). */
function softDelete(actorId) {
  return {
    isDeleted: true,
    deletedAt: serverTimestamp(),
    deletedBy: requireId(actorId, 'actorId'),
    updatedAt: serverTimestamp(),
  };
}

/** `SoftDelete.restorePayload()` — `deletedAt`/`deletedBy` kaldırılmaz, `null` yazılır. */
function restore() {
  return { isDeleted: false, deletedAt: null, deletedBy: null, updatedAt: serverTimestamp() };
}

/**
 * Sayaç yükü (PLAN §11.2b): sayaç ±delta + eşlik eden iş belgesinin yolu (`last*Ref`) aynı yazımda.
 * @param {string} field    sayaç alanı (`memberCount`, `goingCount`, `commentCount` …)
 * @param {number} delta    ±1 (Rules başka değeri reddeder)
 * @param {string} refField `lastMembershipRef` | `lastRsvpRef` | `lastCommentRef` | `lastPostRef`
 * @param {string} refPath  iş belgesinin yolu (`memberships/c01_u_member`)
 */
function counterBump(field, delta, refField, refPath) {
  return { [field]: increment(delta), [refField]: requireId(refPath, refField), ...baseUpdate() };
}

/**
 * `expectations/*.json` vakalarındaki `variant` adları → yük üreticisi `(ctx) => data`.
 * `ctx` = { role, uid, club, otherClub }. Koleksiyon task'ları kendi varyantlarını `registerVariant`
 * ile ekler; T-10 iskeletinde yalnızca alan-bağımsız iki yük vardır.
 */
const variants = new Map([
  ['genericCreate', (ctx) => ({ ownerId: ctx.uid, ...baseCreate({ createdBy: ctx.uid }) })],
  ['genericUpdate', () => ({ touched: true, ...baseUpdate() })],
]);

/** Yeni varyant kaydeder; aynı ad iki kez kaydedilemez (sessiz ezme yok). */
function registerVariant(name, build) {
  if (variants.has(name)) throw new Error(`varyant zaten kayıtlı: ${name}`);
  variants.set(name, build);
}

/** Varyantın yükünü üretir; bilinmeyen varyant hatadır. */
function payloadFor(variant, ctx) {
  const build = variants.get(variant);
  if (!build) throw new Error(`bilinmeyen yük varyantı: ${variant} (payloads.js registerVariant)`);
  return build(ctx);
}

module.exports = {
  BASE_CREATE_KEYS,
  SOFT_DELETE_KEYS,
  baseCreate,
  baseUpdate,
  softDelete,
  restore,
  counterBump,
  registerVariant,
  payloadFor,
};
