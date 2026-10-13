'use strict';
// Yazma yükleri — Dart `BaseFieldsPayload` ve `SoftDelete` sınıflarının JS eşleniği
// (packages/gu_data/lib/src/core/{base_fields,soft_delete}.dart). Anahtar kümeleri Dart ile birebirdir;
// `parity.test.js` Dart kaynağını okuyup doğrular. Zaman damgaları istemci saatinden değil
// `serverTimestamp()`'ten gelir: Rules bunları `request.time` ile karşılaştırır.
const { Timestamp, serverTimestamp, increment } = require('firebase/firestore');
const roles = require('../expectations/roles.json');

/** Yeniden başvuru bekleme süresi (Dart `Limits.reapplyCooldown` = 7 gün) — yönetici yüklerindeki `retryAfter`. */
const REAPPLY_COOLDOWN_MS = 7 * 24 * 60 * 60 * 1000;

/** Geçerli bir kuruluş yılı (`Limits.foundedMin` ≤ yıl ≤ bu yıl). */
const FOUNDED_YEAR = 2015;

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

// ── T-15 · kulüp, üyelik, şikayet, engel, faaliyet ───────────────────────────────────────────
// Üyelik işlemleri çok belgeli batch'lerdir (PLAN §10.4 MembershipRepository): yük üreticileri
// `{ad: {op, path, data}}` döndürür; test bir yazımı çıkarıp / değiştirip `Object.values(...)` ile
// gönderir. Matris vakaları aynı üreticileri `batch` adıyla çağırır (`batchFor`).

const membershipPath = (club, uid) => `memberships/${requireId(club, 'club')}_${requireId(uid, 'uid')}`;
const contactPath = (club, uid) => `${membershipPath(club, uid)}/private/contact`;

/** Başvuranın anlık görüntüsü — fixtures.js `userDoc` ile aynı dört alan (Rules birebir eşitlik ister). */
function applicantOf(uid) {
  return { name: `Test ${uid}`, department: 'd01', year: '1', avatarSeed: uid };
}

/** Karar alanlarının açık `null` biçimi (seed; yeniden başvuruda repository de böyle temizler). */
const DECISION_NULLS = Object.freeze({ decidedAt: null, decidedBy: null, retryAfter: null, rejectReason: null, rejectNote: null });

/** M1 / M2 üyelik belgesi (istemci biçimi: null karar alanlarının anahtarı yok — W-51). `note` YOK (CD-137). */
function membershipCreate(club, uid, status, extra) {
  return {
    clubId: club,
    userId: uid,
    status,
    role: 'member',
    applicant: applicantOf(uid),
    appliedAt: serverTimestamp(),
    priorCount: 0,
    ...baseCreate(),
    ...extra,
  };
}

/** M3 / M4 üyelik güncellemesi: karar alanları temizlenir, `priorCount` bir artar. */
function membershipReapply(uid, status, priorCount, extra) {
  return {
    status,
    role: 'member',
    applicant: applicantOf(uid),
    appliedAt: serverTimestamp(),
    priorCount,
    ...DECISION_NULLS,
    ...baseUpdate(),
    ...extra,
  };
}

/** `memberships/{id}/private/contact` — M1 / M2 (ve belge yoksa M3 / M4) tam yazımı. */
function contactCreate(email, note = '', extra) {
  return { email, emailLower: email.toLowerCase(), note, ...baseCreate(), ...extra };
}

/** `private/contact` — yeniden başvuruda yalnızca `note` + `updatedAt` (U(a)). */
function contactNote(note = '', extra) {
  return { note, ...baseUpdate(), ...extra };
}

/** `ActivityRepository.addToBatch` — oturumun kendi üyelik geçişinin günlüğü. */
function activityOwn(club, uid, kind, extra) {
  return { clubId: club, actorId: uid, kind, refs: { userId: uid }, createdAt: serverTimestamp(), ...extra };
}

/**
 * `clubs.memberCount ±1` — yalnızca delta (+ `updatedAt`). Eşlik eden üyeliğin yolu kulüp belgesine
 * YAZILMAZ (CD-137 madde 8q): kural yolu oturumdan türetir (`memberships/{clubId}_{uid}`).
 */
function memberCountBump(delta) {
  return { memberCount: increment(delta), ...baseUpdate() };
}

const set = (path, data) => ({ op: 'set', path, data });
const update = (path, data) => ({ op: 'update', path, data });
/**
 * Günlük belgesi yolu — Dart `FirestoreIds.activity`: `{clubId}_{uid}_{kind}_{priorCount}`. Kimlik
 * sabittir (Rules karşılaştırır): bir üyelik geçişine tek günlük belgesi düşer (CD-137 madde 8t).
 * `priorCount` = geçişten SONRAKİ üyelik belgesindeki değer.
 */
const activityPath = (club, uid, kind, priorCount = 0) => `activity/${club}_${uid}_${kind}_${priorCount}`;

/** Başvuru notu örneği (boş değil: `requireNote` kulübünde de geçerli). */
const APPLICATION_NOTE = 'Kulübe katılmak istiyorum.';

/** `MembershipRepository.apply` — M1: üyelik `pending` + `private/contact` + `activity`. */
function applyWrites({ club, uid, email, note = APPLICATION_NOTE }) {
  return {
    membership: set(membershipPath(club, uid), membershipCreate(club, uid, 'pending')),
    contact: set(contactPath(club, uid), contactCreate(email, note)),
    activity: set(activityPath(club, uid, 'application_received'), activityOwn(club, uid, 'application_received')),
  };
}

/** `MembershipRepository.joinInstant` — M2: üyelik `active` + contact (`note: ''`) + `memberCount +1` + `activity`. */
function joinWrites({ club, uid, email }) {
  return {
    membership: set(membershipPath(club, uid), membershipCreate(club, uid, 'active')),
    contact: set(contactPath(club, uid), contactCreate(email, '')),
    club: update(`clubs/${club}`, memberCountBump(1)),
    activity: set(activityPath(club, uid, 'member_joined'), activityOwn(club, uid, 'member_joined')),
  };
}

/**
 * `apply` / `joinInstant` yeniden başvuru — M3 / M4: üyelik güncellemesi + contact'ta yalnızca `note`;
 * hedef `active` ise `memberCount +1`.
 */
function reapplyWrites({ club, uid, status = 'pending', priorCount = 1, note }) {
  const kind = status === 'active' ? 'member_joined' : 'application_received';
  const writes = {
    membership: update(membershipPath(club, uid), membershipReapply(uid, status, priorCount)),
    contact: update(contactPath(club, uid), contactNote(note === undefined ? (status === 'active' ? '' : APPLICATION_NOTE) : note)),
  };
  if (status === 'active') writes.club = update(`clubs/${club}`, memberCountBump(1));
  writes.activity = set(activityPath(club, uid, kind, priorCount), activityOwn(club, uid, kind));
  return writes;
}

/** `MembershipRepository.leave` — M8: `status: 'left'` + `memberCount −1` + `activity` (`priorCount` değişmez). */
function leaveWrites({ club, uid, priorCount = 0 }) {
  return {
    membership: update(membershipPath(club, uid), { status: 'left', ...baseUpdate() }),
    club: update(`clubs/${club}`, memberCountBump(-1)),
    activity: set(activityPath(club, uid, 'member_left', priorCount), activityOwn(club, uid, 'member_left')),
  };
}

/** Yönetici geçişlerinin (T-30'da açılır) hedefleri: bekleyen başvuru ve sıradan üye. */
const PENDING_TARGET = 'u_pending';
const MEMBER_TARGET = 'u_member';

/** M5 onay batch'i (T-30): bugün her bağlam için ret. */
function approveWrites({ club, uid }) {
  return {
    membership: update(membershipPath(club, PENDING_TARGET), {
      status: 'active',
      role: 'member',
      decidedAt: serverTimestamp(),
      decidedBy: uid,
      ...baseUpdate(),
    }),
    club: update(`clubs/${club}`, memberCountBump(1)),
  };
}

/** M9 çıkarma batch'i (T-30): bugün her bağlam için ret. */
function removeWrites({ club, uid }) {
  return {
    membership: update(membershipPath(club, MEMBER_TARGET), {
      status: 'removed',
      decidedAt: serverTimestamp(),
      decidedBy: uid,
      retryAfter: Timestamp.fromMillis(Date.now() + REAPPLY_COOLDOWN_MS),
      rejectReason: 'other',
      rejectNote: '',
      ...baseUpdate(),
    }),
    club: update(`clubs/${club}`, memberCountBump(-1)),
  };
}

/** `ReportRepository.report` — `ReportModel.toJson()` (null alanların anahtarı yok) + `BaseFieldsPayload.create()`. */
function reportCreate(uid, target, extra) {
  const payload = { targetType: target.type, targetId: target.id };
  if (target.clubId !== undefined && target.clubId !== null) payload.targetClubId = target.clubId;
  return { ...payload, reporterId: uid, reason: 'spam', note: '', status: 'open', ...baseCreate(), ...extra };
}

/** Matris hedefi: temel veri kümesindeki gönderi. */
const REPORT_TARGET = Object.freeze({ type: 'post', id: 'p01', clubId: roles.club });

/** `BlockRepository.block` — `BlockModel.toJson()` + `BaseFieldsPayload.create()`. */
function blockCreate(blockerId, blockedId, extra) {
  return { blockerId, blockedId, ...baseCreate(), ...extra };
}

/** Süper adminin ADM-03 kulüp belgesi (T-37'de açılır): bugün her bağlam için ret. */
function clubCreate(uid) {
  return {
    name: 'Yeni Kulüp',
    nameLower: 'yeni kulüp',
    categoryId: 'k01',
    iconName: 'cpu',
    palette: 'red',
    pattern: 'dots',
    coverSeed: 'club-c_new',
    memberCount: 1,
    approvalRequired: true,
    applicationsOpen: true,
    requireNote: false,
    founded: FOUNDED_YEAR,
    summary: '',
    about: '',
    conditions: [],
    social: {},
    presidentId: 'u_president',
    status: 'active',
    ...baseCreate({ createdBy: uid }),
  };
}

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
  // T-15 · clubs (yazımlar T-30 / T-37'de açılır; sayaç dalı tek başına geçmez)
  ['clubCreate', (ctx) => clubCreate(ctx.uid)],
  ['clubSettingsUpdate', () => ({ summary: 'Güncel özet.', applicationsOpen: false, ...baseUpdate() })],
  ['clubSuspend', () => ({ status: 'suspended', suspendReason: SUSPEND_REASON, ...baseUpdate() })],
  ['clubBumpAlone', () => memberCountBump(1)],
  // T-15 · memberships (tek yazımlı geçişler; çok yazımlılar aşağıda `batches`)
  ['membershipCancel', () => ({ status: 'cancelled', ...baseUpdate() })],
  ['membershipReject', (ctx) => ({
    status: 'rejected',
    decidedAt: serverTimestamp(),
    decidedBy: ctx.uid,
    retryAfter: Timestamp.fromMillis(Date.now() + REAPPLY_COOLDOWN_MS),
    rejectReason: 'quota',
    rejectNote: '',
    ...baseUpdate(),
  })],
  ['membershipRole', () => ({ role: 'board', ...baseUpdate() })],
  // T-15 · memberships/private/contact
  ['contactCreate', (ctx) => contactCreate(emailOf(ctx.role), APPLICATION_NOTE)],
  ['contactNoteUpdate', () => contactNote('Güncel not.')],
  ['contactEmailUpdate', () => ({ email: 'baska@ogr.gumushane.edu.tr', emailLower: 'baska@ogr.gumushane.edu.tr', ...baseUpdate() })],
  // T-15 · reports
  ['reportPost', (ctx) => reportCreate(ctx.uid, REPORT_TARGET)],
  ['reportPostSeedNulls', (ctx) => reportCreate(ctx.uid, REPORT_TARGET, { action: null, resolvedAt: null, resolvedBy: null })],
  ['reportResolve', (ctx) => ({ status: 'resolved', action: 'dismissed', resolvedAt: serverTimestamp(), resolvedBy: ctx.uid, ...baseUpdate() })],
  // T-15 · blocks
  ['blockBoard', (ctx) => blockCreate(ctx.uid, 'u_board')],
  ['blockMember', (ctx) => blockCreate(ctx.uid, 'u_member')],
  // T-15 · activity (eşlik eden üyelik yazımı OLMADAN: ret)
  ['activityApplicationReceived', (ctx) => activityOwn(ctx.club, ctx.uid, 'application_received')],
  ['activityMemberJoined', (ctx) => activityOwn(ctx.club, ctx.uid, 'member_joined')],
  ['activityMemberLeft', (ctx) => activityOwn(ctx.club, ctx.uid, 'member_left')],
  ['activityPostCreated', (ctx) => ({ clubId: ctx.club, actorId: ctx.uid, kind: 'post_created', refs: { postId: 'p01' }, createdAt: serverTimestamp() })],
  ['activityRoleChanged', (ctx) => ({ clubId: ctx.club, actorId: ctx.uid, kind: 'role_changed', refs: { userId: MEMBER_TARGET, role: 'board' }, createdAt: serverTimestamp() })],
  ['activitySettingsChanged', (ctx) => ({ clubId: ctx.club, actorId: ctx.uid, kind: 'settings_changed', refs: {}, createdAt: serverTimestamp() })],
]);

/**
 * `expectations/*.json` vakalarındaki `batch` adları → çok belgeli yazım üreticisi `(ctx) => {ad: yazım}`.
 * Yazımlar tek `WriteBatch` olarak gönderilir (repository'nin transaction'ı ile aynı atomiklik).
 */
const batches = new Map([
  ['applyBatch', (ctx) => applyWrites({ club: ctx.club, uid: ctx.uid, email: emailOf(ctx.role) })],
  ['joinBatch', (ctx) => joinWrites({ club: ctx.club, uid: ctx.uid, email: emailOf(ctx.role) })],
  ['reapplyPendingBatch', (ctx) => reapplyWrites({ club: ctx.club, uid: ctx.uid, status: 'pending' })],
  ['reapplyActiveBatch', (ctx) => reapplyWrites({ club: ctx.club, uid: ctx.uid, status: 'active' })],
  ['leaveBatch', (ctx) => leaveWrites({ club: ctx.club, uid: ctx.uid })],
  ['approveBatch', (ctx) => approveWrites({ club: ctx.club, uid: ctx.uid })],
  ['removeBatch', (ctx) => removeWrites({ club: ctx.club, uid: ctx.uid })],
]);

/** Batch varyantının yazım listesini üretir; bilinmeyen ad hatadır. */
function batchFor(name, ctx) {
  const build = batches.get(name);
  if (!build) throw new Error(`bilinmeyen batch varyantı: ${name} (payloads.js batches)`);
  return Object.values(build(ctx));
}

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
  APPLICATION_NOTE,
  DECISION_NULLS,
  PENDING_TARGET,
  MEMBER_TARGET,
  REPORT_TARGET,
  membershipPath,
  contactPath,
  applicantOf,
  membershipCreate,
  membershipReapply,
  contactCreate,
  contactNote,
  activityOwn,
  activityPath,
  memberCountBump,
  applyWrites,
  joinWrites,
  reapplyWrites,
  leaveWrites,
  approveWrites,
  removeWrites,
  reportCreate,
  blockCreate,
  registerVariant,
  payloadFor,
  batchFor,
};
