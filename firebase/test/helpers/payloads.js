'use strict';
// Yazma yükleri — Dart `BaseFieldsPayload` ve `SoftDelete` sınıflarının JS eşleniği
// (packages/gu_data/lib/src/core/{base_fields,soft_delete}.dart). Anahtar kümeleri Dart ile birebirdir;
// `parity.test.js` Dart kaynağını okuyup doğrular. Zaman damgaları istemci saatinden değil
// `serverTimestamp()`'ten gelir: Rules bunları `request.time` ile karşılaştırır.
const { serverTimestamp, increment } = require('firebase/firestore');
const roles = require('../expectations/roles.json');

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

// ── T-12 · kimlik ve profil (users, users/private/account, settings) ─────────────────────────
// Yükler repository'nin yazdığıyla aynı biçimdedir: model `toJson()` çıktısı null alanı HİÇ yazmaz
// (build.yaml `include_if_null: false`); açık `null` biçimi (seed) `...SeedNulls` varyantlarındadır
// (W-51, CD-130 — Rules iki biçimi de kabul etmelidir).

/** Oturumsuz bağlamın yüklerinde kullanılan e-posta (izinli alan adında; ret kural yüzünden gelsin). */
const ANON_EMAIL = 'anon@ogr.gumushane.edu.tr';

/** Bağlamın token e-postası (`roles.json`); oturumsuz bağlamda `ANON_EMAIL`. */
function emailOf(role) {
  const def = roles.definitions[roles.aliases[role] || role];
  return (def && def.token && def.token.email) || ANON_EMAIL;
}

/** Geçerli bir avatar yolu: `users/{uid}/<StoragePaths.newFileName>`. */
function avatarPathOf(uid) {
  return `users/${uid}/20261008T201501Z_3f9a1c2b7d4e5f60.jpg`;
}

/** `UserRepository.createProfile` → `users/{uid}`: `UserModel.toJson()` + `BaseFieldsPayload.create()`. */
function userCreate(uid, extra) {
  return {
    name: 'Yeni Kullanıcı',
    nameLower: 'yeni kullanıcı',
    avatarSeed: requireId(uid, 'uid'),
    interests: [],
    bio: '',
    status: 'active',
    staff: false,
    profileComplete: false,
    ...baseCreate(),
    ...extra,
  };
}

/** `UserRepository.updateProfile` — AUT-05 sonu: `UserProfilePatch`'in dokuz alanı + `updatedAt`. */
function userProfileUpdate(uid, extra) {
  return {
    name: 'Güncel Ad',
    nameLower: 'güncel ad',
    avatarSeed: `${requireId(uid, 'uid')}-2`,
    avatarPath: avatarPathOf(uid),
    department: 'd02',
    year: '2',
    interests: ['i01', 'i05'],
    bio: 'Merhaba.',
    profileComplete: true,
    ...baseUpdate(),
    ...extra,
  };
}

/** `createProfile` → `users/{uid}/private/account`: `email`, `emailLower`, `fcmTokens: []` + ortak alanlar. */
function accountCreate(email, extra) {
  return { email, emailLower: email.toLowerCase(), fcmTokens: [], ...baseCreate(), ...extra };
}

/** `UserRepository.touchLastLogin` → `lastLoginAt` + `updatedAt` (ikisi de sunucu zamanı). */
function accountTouchLastLogin(extra) {
  return { lastLoginAt: serverTimestamp(), ...baseUpdate(), ...extra };
}

/** `UserSettingsModel.defaults(uid).toJson()` + `updatedAt` (BaseFields yok). */
function settingsCreate(extra) {
  return {
    announcements: true,
    eventReminders: true,
    newEvents: true,
    applicationResults: true,
    management: true,
    system: true,
    reminderTime: '1h',
    quiet: false,
    quietFrom: '22:00',
    quietTo: '08:00',
    clubs: {},
    updatedAt: serverTimestamp(),
    ...extra,
  };
}

/** `SettingsRepository.updateSettings` — `UserSettingsPatch` alanlarının bir alt kümesi + `updatedAt`. */
function settingsUpdate(extra) {
  return { announcements: false, reminderTime: '1d', quiet: true, quietFrom: '23:30', quietTo: '07:15', ...baseUpdate(), ...extra };
}

/** `SettingsRepository.updateClubSettings` — alan yolu `clubs.<clubId>` + `updatedAt`. */
function settingsClubUpdate(clubId, extra) {
  return {
    [`clubs.${requireId(clubId, 'clubId')}`]: { announcements: true, events: false, posts: true, muted: false },
    ...baseUpdate(),
    ...extra,
  };
}

/** Askı gerekçesi örneği (fixtures.js `accountDoc` ile aynı metin). */
const SUSPEND_REASON = 'Topluluk kurallarının ihlali.';

/**
 * `expectations/*.json` vakalarındaki `variant` adları → yük üreticisi `(ctx) => data`.
 * `ctx` = { role, uid, club, otherClub }. Koleksiyon task'ları kendi varyantlarını aşağıya ekler
 * (dosya dışından `registerVariant`); T-10 iskeletinde yalnızca alan-bağımsız iki yük vardır.
 */
const variants = new Map([
  ['genericCreate', (ctx) => ({ ownerId: ctx.uid, ...baseCreate({ createdBy: ctx.uid }) })],
  ['genericUpdate', () => ({ touched: true, ...baseUpdate() })],
  // T-12 · users
  ['userCreate', (ctx) => userCreate(ctx.uid)],
  ['userCreateSeedNulls', (ctx) => userCreate(ctx.uid, { avatarPath: null, department: null, year: null })],
  ['userProfileUpdate', (ctx) => userProfileUpdate(ctx.uid)],
  ['userSuspend', () => ({ status: 'suspended', ...baseUpdate() })],
  ['userReactivate', () => ({ status: 'active', ...baseUpdate() })],
  // T-12 · users/private/account
  ['accountCreate', (ctx) => accountCreate(emailOf(ctx.role))],
  ['accountCreateSeedNulls', (ctx) => accountCreate(emailOf(ctx.role), { lastLoginAt: null, suspendReason: null })],
  ['accountTouchLastLogin', () => accountTouchLastLogin()],
  ['accountSetSuspendReason', () => ({ suspendReason: SUSPEND_REASON, ...baseUpdate() })],
  ['accountClearSuspendReason', () => ({ suspendReason: null, ...baseUpdate() })],
  // T-12 · settings
  ['settingsCreate', () => settingsCreate()],
  ['settingsUpdate', () => settingsUpdate()],
  ['settingsClubUpdate', (ctx) => settingsClubUpdate(ctx.club)],
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
  SUSPEND_REASON,
  baseCreate,
  baseUpdate,
  softDelete,
  restore,
  counterBump,
  emailOf,
  avatarPathOf,
  userCreate,
  userProfileUpdate,
  accountCreate,
  accountTouchLastLogin,
  settingsCreate,
  settingsUpdate,
  settingsClubUpdate,
  registerVariant,
  payloadFor,
};
