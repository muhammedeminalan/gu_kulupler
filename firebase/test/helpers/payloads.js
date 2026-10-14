'use strict';
// Yazma yükleri — Dart `BaseFieldsPayload` ve `SoftDelete` sınıflarının JS eşleniği
// (packages/gu_data/lib/src/core/{base_fields,soft_delete}.dart). Anahtar kümeleri Dart ile birebirdir;
// `parity.test.js` Dart kaynağını okuyup doğrular. Zaman damgaları istemci saatinden değil
// `serverTimestamp()`'ten gelir: Rules bunları `request.time` ile karşılaştırır.
const { Timestamp, arrayRemove, arrayUnion, increment, serverTimestamp } = require('firebase/firestore');
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

// ── T-19 · gönderi, oy, yorum, kayıt, duyuru sayacı ───────────────────────────────────────────
// Yazma yolları docs/plans/T-19.md §6.a tablosundaki içeriktir (PostRepository / CommentRepository /
// SavedPostRepository). Çok belgeli işlemler `{ad: {op, path, data}}` döndürür (T-15 kalıbı).

const HOUR_MS = 60 * 60 * 1000;
const DAY_MS = 24 * HOUR_MS;
/** Dart `Limits.istanbulUtcOffset` (3 sa). */
const ISTANBUL_OFFSET_MS = 3 * HOUR_MS;

/**
 * Istanbul günü (Dart `AppClock.istanbulDayKey` / `istanbulDay`; Rules `request.time + 3 sa`).
 * @param {number} [ms] an (epoch ms); varsayılan şimdi
 * @returns {{key: string, day: string}} `yyyyMMdd` (sayaç belge kimliği eki) ve `yyyy-MM-dd` (`day` alanı)
 */
function istanbulDay(ms = Date.now()) {
  const iso = new Date(ms + ISTANBUL_OFFSET_MS).toISOString().slice(0, 10);
  return { key: iso.replace(/-/g, ''), day: iso };
}

/** Geçerli bir gönderi görseli (`PostImageModel`): `posts/{postId}/<StoragePaths.newFileName>`. */
function postImage(postId, index = 0) {
  return { path: `posts/${requireId(postId, 'postId')}/20261008T20150${index}Z_3f9a1c2b7d4e5f60.jpg`, w: 1200, h: 800 };
}

/** `PollModel.toJson()`: seçenek kimlikleri `o1`…`oN`; `endsAt` = istemci saati + gün (CD-32 toleransı). */
function pollOf(texts = ['Evet', 'Hayır'], days = 7, skewMs = 0) {
  return {
    options: texts.map((text, i) => ({ id: `o${i + 1}`, text })),
    endsAt: Timestamp.fromMillis(Date.now() + days * DAY_MS + skewMs),
    showResultsAfterVote: true,
  };
}

/**
 * `PostRepository.create` → `posts/{postId}` (istemci biçimi: null alanların anahtarı yok — W-51).
 * `title` yalnızca duyuruda, `poll` yalnızca ankette yazılır.
 */
function postCreate({ club, uid, type = 'post', pushSent = false }, extra) {
  const data = {
    clubId: club,
    authorId: uid,
    type,
    text: 'Yeni gönderi metni.',
    images: [],
    pinned: false,
    pushSent,
    likes: [],
    likeCount: 0,
    commentCount: 0,
    isHidden: false,
    ...baseCreate(),
  };
  if (type === 'announcement') data.title = 'Duyuru başlığı';
  if (type === 'poll') data.poll = pollOf();
  return { ...data, ...extra };
}

/** Seed biçimi: null olabilen gönderi alanları açık `null` (W-51). */
const POST_NULLS = Object.freeze({ title: null, poll: null, lastCommentRef: null, hiddenBy: null, hiddenAt: null, editedAt: null });

/** Gönderi türü → günlük türü (`ActivityKind`). */
const POST_ACTIVITY_KIND = Object.freeze({ post: 'post_created', announcement: 'announcement', poll: 'poll' });

/** Temel veri kümesindeki `p01` anketinin sorusu (fixtures.js `posts/p01.text` ile aynı dizgi). */
const POLL_QUESTION = 'Rules testi gönderisi.';

/** Günlük belgesi yolu — Dart `FirestoreIds.postActivity`: `{clubId}_{actorId}_{kind}_{postId}`. */
const postActivityPath = (club, uid, kind, postId) => `activity/${club}_${uid}_${kind}_${postId}`;

/** Gönderi yayınının günlüğü: `refs` yalnızca `postId`. */
function postActivity(club, uid, kind, postId, extra) {
  return { clubId: club, actorId: uid, kind, refs: { postId }, createdAt: serverTimestamp(), ...extra };
}

/** Duyuru sayacı yükü (`set(merge)`): `count` mutlak değerdir (işlem önceki değeri okur). */
function counterData({ club, postId, count, ms }, extra) {
  return { clubId: club, day: istanbulDay(ms).day, count, lastPostRef: `posts/${postId}`, updatedAt: serverTimestamp(), ...extra };
}

/** Sayaç belgesi yolu — Dart `FirestoreIds.announcementCounter`. */
const counterPath = (club, ms) => `announcementCounters/${club}_${istanbulDay(ms).key}`;

/**
 * `PostRepository.create` — gönderi + günlük; `pushSent` ise + günün sayacı (`set(merge)`, `count: önceki + 1`).
 * @param {{club: string, uid: string, postId?: string, type?: string, pushSent?: boolean, previousCount?: number, ms?: number}} o
 *   `ms` sayaç gününün hesaplandığı an (varsayılan şimdi)
 */
function createPostWrites({ club, uid, postId = 'p_new', type = 'post', pushSent = false, previousCount = 0, ms }) {
  const kind = POST_ACTIVITY_KIND[type];
  const writes = {
    post: set(`posts/${postId}`, postCreate({ club, uid, type, pushSent })),
    activity: set(postActivityPath(club, uid, kind, postId), postActivity(club, uid, kind, postId)),
  };
  if (pushSent) {
    writes.counter = { op: 'set', merge: true, path: counterPath(club, ms), data: counterData({ club, postId, count: previousCount + 1, ms }) };
  }
  return writes;
}

/** `PostRepository.update` — düzenleme: verilen alanlar + `editedAt` + `updatedAt`. */
function postEdit(extra) {
  return { text: 'Düzenlenmiş metin.', editedAt: serverTimestamp(), ...baseUpdate(), ...extra };
}

/** `PostRepository.like` / `unlike` — kör update; `updatedAt` YAZILMAZ. */
const postLike = (uid) => ({ likes: arrayUnion(uid), likeCount: increment(1) });
const postUnlike = (uid) => ({ likes: arrayRemove(uid), likeCount: increment(-1) });

/** `hide` / `unhide` (süper admin) — gönderi ve yorumda aynı alanlar. */
const hidePayload = (uid) => ({ isHidden: true, hiddenBy: uid, hiddenAt: serverTimestamp(), ...baseUpdate() });
const unhidePayload = () => ({ isHidden: false, hiddenBy: null, hiddenAt: null, ...baseUpdate() });

/** `PostRepository.vote` → `posts/{id}/votes/{uid}`. */
const voteCreate = (optionId, extra) => ({ optionId, createdAt: serverTimestamp(), ...extra });

/** `PostRepository.pin` — eski sabit (varsa) `pinned: false` + yeni `pinned: true` + `clubs.pinnedPostId`. */
function pinWrites({ club, postId, oldPostId }) {
  const writes = {};
  if (oldPostId) writes.old = update(`posts/${oldPostId}`, { pinned: false, ...baseUpdate() });
  writes.post = update(`posts/${postId}`, { pinned: true, ...baseUpdate() });
  writes.club = update(`clubs/${club}`, { pinnedPostId: postId, ...baseUpdate() });
  return writes;
}

/** `PostRepository.unpin` — `pinned: false` + `clubs.pinnedPostId: null`. */
function unpinWrites({ club, postId }) {
  return {
    post: update(`posts/${postId}`, { pinned: false, ...baseUpdate() }),
    club: update(`clubs/${club}`, { pinnedPostId: null, ...baseUpdate() }),
  };
}

/** `PostRepository.softDeletePost` — sabitse aynı yazımda `pinned: false` + `clubs.pinnedPostId: null`. */
function removePostWrites({ club, uid, postId, pinned = false }) {
  const writes = { post: update(`posts/${postId}`, { ...softDelete(uid), ...(pinned ? { pinned: false } : {}) }) };
  if (pinned) writes.club = update(`clubs/${club}`, { pinnedPostId: null, ...baseUpdate() });
  return writes;
}

/** `CommentRepository.add` → `comments/{id}` (istemci biçimi: `hiddenBy` / `hiddenAt` anahtarı yok). */
function commentCreate({ club, uid, postId }, extra) {
  return { postId, clubId: club, authorId: uid, text: 'Yeni yorum.', isHidden: false, ...baseCreate(), ...extra };
}

/** Gönderinin yorum sayacı yazımı: `commentCount ±1` + `lastCommentRef` + `updatedAt`. */
const commentCountBump = (postId, commentId, delta) =>
  update(`posts/${postId}`, counterBump('commentCount', delta, 'lastCommentRef', `comments/${commentId}`));

/** `CommentRepository.add` — yorum + `posts.commentCount +1`. */
function addCommentWrites({ club, uid, postId = 'p01', commentId = 'cm_new' }) {
  return {
    comment: set(`comments/${commentId}`, commentCreate({ club, uid, postId })),
    post: commentCountBump(postId, commentId, 1),
  };
}

/** `CommentRepository.softDeleteComment` — soft delete + `posts.commentCount −1`. */
function removeCommentWrites({ uid, postId = 'p01', commentId = 'cm01' }) {
  return { comment: update(`comments/${commentId}`, softDelete(uid)), post: commentCountBump(postId, commentId, -1) };
}

/** `CommentRepository.restoreComment` — restore + `posts.commentCount +1`. */
function restoreCommentWrites({ postId = 'p01', commentId = 'cm01' }) {
  return { comment: update(`comments/${commentId}`, restore()), post: commentCountBump(postId, commentId, 1) };
}

/** `SavedPostRepository.save` → `savedPosts/{userId}_{postId}`. */
function savedCreate({ club, uid, postId = 'p01' }, extra) {
  return { userId: uid, postId, clubId: club, savedAt: serverTimestamp(), ...baseCreate(), ...extra };
}

/** `save` — silinmiş kayıt: restore + `savedAt` yenilenir. */
const savedResave = () => ({ ...restore(), savedAt: serverTimestamp() });

// ── T-28 · supportTickets ─────────────────────────────────────────────────────────────────────

/** Matrisin yeni talep numarası (`newDocPath` = `supportTickets/GU-NEWT23`). */
const NEW_TICKET_NO = 'GU-NEWT23';

/** `support/{ticketNo}/` + StoragePaths.newFileName biçiminde ek yolu. */
const supportAttachmentPath = (ticketNo = NEW_TICKET_NO, file = '20261014T090000Z_0123456789abcdef.jpg') =>
  `support/${requireId(ticketNo, 'ticketNo')}/${file}`;

/**
 * `SupportRepository.createTicket` — `SupportTicketModel.toJson()` + `BaseFieldsPayload.create()`:
 * `ticketNo` (= belge kimliği), `userId`, `subject`, `message`, `attachmentPaths`, `status: open`.
 */
function ticketCreate({ uid, ticketNo = NEW_TICKET_NO, attachmentPaths = [] }, extra) {
  return {
    ticketNo,
    userId: requireId(uid, 'uid'),
    subject: 'bug',
    message: 'Bildirimler gelmiyor.',
    attachmentPaths,
    status: 'open',
    ...baseCreate(),
    ...extra,
  };
}

// ── T-22 · etkinlik, katılım, yoklama, terfi ──────────────────────────────────────────────────
// Yazma yolları docs/plans/T-22.md §6.2 – §6.5 tablolarındaki içeriktir (EventRepository / RsvpRepository;
// yoklama ve terfi yüklerini T-30 `AttendanceRepository` yazar — kuralları T-22'de açılır).

/** Seed biçimi: null olabilen etkinlik alanları açık `null` (W-51). */
const EVENT_NULLS = Object.freeze({ placeId: null, placeText: null, capacity: null, cancelReason: null, coverPath: null, publishedAt: null });
/** Seed biçimi: null olabilen katılım alanları açık `null` (W-51). */
const RSVP_NULLS = Object.freeze({ waitlistAt: null, scannedAt: null, scannedBy: null });

/** Geçerli bir etkinlik kapağı yolu: `events/{eventId}/<StoragePaths.newFileName>` (CD-47). */
function eventCoverPath(eventId, index = 0) {
  return `events/${requireId(eventId, 'eventId')}/20261008T20150${index}Z_3f9a1c2b7d4e5f60.jpg`;
}

/**
 * `EventRepository.create` → `events/{eventId}` (istemci biçimi: null alanların anahtarı yok — W-51;
 * kontenjan anahtarı yok = sınırsız). `publishedAt` yalnızca `published` iken yazılır; `coverPath`,
 * `cancelReason` ve `lastRsvpRef` HİÇ yazılmaz (W-64).
 */
function eventCreate({ club, uid, eventId = 'e_new', status = 'draft', startsInMs = 3 * DAY_MS }, extra) {
  const data = {
    clubId: club,
    title: 'Yeni etkinlik',
    desc: 'Etkinlik açıklaması.',
    type: 'sosyal',
    startsAt: Timestamp.fromMillis(Date.now() + startsInMs),
    endsAt: Timestamp.fromMillis(Date.now() + startsInMs + 2 * HOUR_MS),
    placeId: 'pl02',
    visibility: 'public',
    status,
    coverSeed: `event-${requireId(eventId, 'eventId')}`,
    coverPalette: 'slate',
    coverPattern: 'dots',
    registrationOpen: true,
    autoReminder: true,
    goingCount: 0,
    waitlistCount: 0,
    attendedCount: 0,
    ...baseCreate({ createdBy: uid }),
  };
  if (status === 'published') data.publishedAt = serverTimestamp();
  return { ...data, ...extra };
}

/** Günlük belgesi yolu — Dart `FirestoreIds.eventActivity`: `{clubId}_{actorId}_{kind}_{eventId}`. */
const eventActivityPath = (club, uid, kind, eventId) => `activity/${club}_${uid}_${kind}_${eventId}`;

/** Etkinlik yayını / iptalinin günlüğü: `refs` yalnızca `eventId`. */
function eventActivity(club, uid, kind, eventId, extra) {
  return { clubId: club, actorId: uid, kind, refs: { eventId }, createdAt: serverTimestamp(), ...extra };
}

/** `EventRepository.create` — etkinlik; `published` ise + günlük `event_published`. */
function createEventWrites({ club, uid, eventId = 'e_new', status = 'draft' }) {
  const writes = { event: set(`events/${eventId}`, eventCreate({ club, uid, eventId, status })) };
  if (status === 'published') {
    writes.activity = set(eventActivityPath(club, uid, 'event_published', eventId), eventActivity(club, uid, 'event_published', eventId));
  }
  return writes;
}

/** `EventRepository.update` — içerik yaması: verilen alanlar + `updatedAt`. */
function eventEdit(extra) {
  return { title: 'Güncel başlık', desc: 'Güncel açıklama.', ...baseUpdate(), ...extra };
}

/** `EventRepository.publish` — `status` + `publishedAt` (+ ilk yayında günlük). */
const eventPublish = (extra) => ({ status: 'published', publishedAt: serverTimestamp(), ...baseUpdate(), ...extra });
function publishEventWrites({ club, uid, eventId = 'e_draft', first = true }) {
  const writes = { event: update(`events/${eventId}`, eventPublish()) };
  if (first) writes.activity = set(eventActivityPath(club, uid, 'event_published', eventId), eventActivity(club, uid, 'event_published', eventId));
  return writes;
}

/** `EventRepository.unpublish` — yalnızca `status` (`publishedAt` korunur). */
const eventUnpublish = (extra) => ({ status: 'draft', ...baseUpdate(), ...extra });

/** İptal nedeni örneği (DLG-23). */
const CANCEL_REASON = 'Salon tadilata alındı.';

/** `EventRepository.cancel` — `status` + `cancelReason` + günlük `event_cancelled`. */
const eventCancel = (reason = CANCEL_REASON, extra) => ({ status: 'cancelled', cancelReason: reason, ...baseUpdate(), ...extra });
function cancelEventWrites({ club, uid, eventId = 'e_public', reason = CANCEL_REASON }) {
  return {
    event: update(`events/${eventId}`, eventCancel(reason)),
    activity: set(eventActivityPath(club, uid, 'event_cancelled', eventId), eventActivity(club, uid, 'event_cancelled', eventId)),
  };
}

/** Katılım kaydı yolu — Dart `FirestoreIds.rsvp`: `{eventId}_{userId}`. */
const rsvpPath = (eventId, uid) => `rsvps/${requireId(eventId, 'eventId')}_${requireId(uid, 'uid')}`;

/** Yeni katılımın bilet kodu (`FirestoreIds.ticketCodePattern`). */
const TICKET_CODE = 'GU-WXYZ-6789';

/**
 * `RsvpRepository.join` → yeni `rsvps/{eventId}_{uid}` (istemci biçimi: `scannedAt` / `scannedBy` anahtarı
 * yok; `waitlistAt` yalnızca `waitlist` iken).
 */
function rsvpCreate({ club, uid, eventId = 'e_public', status = 'going', reminder = '1h' }, extra) {
  const data = { eventId, clubId: club, userId: uid, status, reminder, ticketCode: TICKET_CODE, ...baseCreate() };
  if (status === 'waitlist') data.waitlistAt = serverTimestamp();
  return { ...data, ...extra };
}

/**
 * `events` sayaç yazımı: yalnızca oynayan sayaç(lar) `increment` + `updatedAt`. İşaretçi YAZILMAZ (W-64).
 * @param {{going?: number, waitlist?: number, attended?: number}} deltas sıfır olan sayaç yüke girmez
 */
function eventCountersBump({ going = 0, waitlist = 0, attended = 0 }, extra) {
  const data = {};
  if (going !== 0) data.goingCount = increment(going);
  if (waitlist !== 0) data.waitlistCount = increment(waitlist);
  if (attended !== 0) data.attendedCount = increment(attended);
  return { ...data, ...baseUpdate(), ...extra };
}

/** Katılım durumunun oynattığı sayaç: `going` → kayıtlı, `waitlist` → bekleyen. */
const joinDeltas = (status, step) => (status === 'waitlist' ? { waitlist: step } : { going: step });

/** `RsvpRepository.join` (yeni kayıt) — kayıt + `goingCount` ya da `waitlistCount` +1. */
function rsvpJoinWrites({ club, uid, eventId = 'e_public', status = 'going', reminder = '1h' }) {
  return {
    rsvp: set(rsvpPath(eventId, uid), rsvpCreate({ club, uid, eventId, status, reminder })),
    event: update(`events/${eventId}`, eventCountersBump(joinDeltas(status, 1))),
  };
}

/** `RsvpRepository.join` (vazgeçilmiş kayıt) — `status`, `reminder`, `waitlistAt` + sayaç +1; bilet kodu aynı. */
function rsvpRejoinWrites({ uid, eventId = 'e_public', status = 'going', reminder = '1d' }) {
  return {
    rsvp: update(rsvpPath(eventId, uid), {
      status,
      reminder,
      waitlistAt: status === 'waitlist' ? serverTimestamp() : null,
      ...baseUpdate(),
    }),
    event: update(`events/${eventId}`, eventCountersBump(joinDeltas(status, 1))),
  };
}

/** `RsvpRepository.cancel` — yalnızca `status` + önceki durumun sayacı −1. */
function rsvpCancelWrites({ uid, eventId = 'e_public', from = 'going' }) {
  return {
    rsvp: update(rsvpPath(eventId, uid), { status: 'cancelled', ...baseUpdate() }),
    event: update(`events/${eventId}`, eventCountersBump(joinDeltas(from, -1))),
  };
}

/** `RsvpRepository.setReminder` — yalnızca `reminder` + `updatedAt`. */
const rsvpReminder = (reminder = '15m', extra) => ({ reminder, ...baseUpdate(), ...extra });

/** Yönetici sayaç işaretçisinin yan belgesi (W-64): `events/{eventId}/private/counter`. */
const eventCounterPath = (eventId) => `events/${requireId(eventId, 'eventId')}/private/counter`;
const eventCounterData = (club, eventId, userId, extra) => ({ clubId: club, lastRsvpRef: rsvpPath(eventId, userId), updatedAt: serverTimestamp(), ...extra });

/**
 * `AttendanceRepository.markAttended` / `scanTicket` (T-30) — yoklama: `going → attended` (`attended: true`)
 * ya da geri alma `attended → going`; `attendedCount ±1` + yan belge.
 * @param {{club: string, uid: string, eventId?: string, userId?: string, attended?: boolean}} o `uid` = yönetici
 */
function attendWrites({ club, uid, eventId = 'e_live', userId = 'u_member', attended = true }) {
  const rsvp = attended
    ? { status: 'attended', scannedAt: serverTimestamp(), scannedBy: uid, ...baseUpdate() }
    : { status: 'going', scannedAt: null, scannedBy: null, ...baseUpdate() };
  return {
    rsvp: update(rsvpPath(eventId, userId), rsvp),
    event: update(`events/${eventId}`, eventCountersBump({ attended: attended ? 1 : -1 })),
    counter: set(eventCounterPath(eventId), eventCounterData(club, eventId, userId)),
  };
}

/** `AttendanceRepository.promote` (T-30) — terfi: `waitlist → going`; tek yazımda `(+1, −1, 0)` + yan belge. */
function promoteWrites({ club, eventId = 'e_live', userId = 'u_student' }) {
  return {
    rsvp: update(rsvpPath(eventId, userId), { status: 'going', ...baseUpdate() }),
    event: update(`events/${eventId}`, eventCountersBump({ going: 1, waitlist: -1 })),
    counter: set(eventCounterPath(eventId), eventCounterData(club, eventId, userId)),
  };
}

// ── T-25 · notifications ──────────────────────────────────────────────────────────────────────
// Yazma yolları docs/plans/T-25.md §6 (a, b, f, g): NotificationWriter.addToBatch / createMany (dağıtıcı),
// NotificationRepository.createSelf (`event_reminder`), markRead / markAllRead / soft delete / restore.

/** Örnek olay anahtarları — `NotificationWriter.newEventKey` biçimi (20 karakter `[A-Za-z0-9]`). */
const EVENT_KEY = 'AbCdEfGhIjKlMnOpQr01';
const EVENT_KEY_2 = 'ZyXwVuTsRqPoNmLkJi23';

/** Dart `FirestoreIds.notification`: `notifications/{type}_{eventKey}_{userId}`. */
const notificationPath = (type, key, userId) => `notifications/${type}_${key}_${requireId(userId, 'userId')}`;

/** `event_reminder` kimliği (createSelf): `notifications/event_reminder_{eventId}_{uid}`. */
const reminderPath = (eventId, uid) => `notifications/event_reminder_${requireId(eventId, 'eventId')}_${requireId(uid, 'uid')}`;

/**
 * Bildirim belgesi (istemci biçimi): `userId`, `type`, `refs` (yalnızca dolu referanslar — W-51), `read: false`
 * + `BaseFieldsPayload.create()`. Metin ve aktör alanı yoktur (CD-147).
 */
function notificationCreate(type, userId, refs, extra) {
  return { userId, type, refs, read: false, ...baseCreate(), ...extra };
}

/**
 * Dağıtıcının olay anahtarı (CD-148 — ClientFanOutDispatcher): tek seferlik olaylarda olayın kimliği
 * (`announcement` → postId, `event_cancelled` → eventId, `application_received` →
 * `FirestoreIds.applicationEventKey` = `{clubId}_{applicantId}_{priorCount}`), diğerlerinde rastgele anahtar.
 * `key` verilirse olduğu gibi kullanılır (ret vakaları: tek seferlik türde rastgele anahtar).
 */
function eventKeyOf(type, refs, { key, sequence = 0 } = {}) {
  if (key !== undefined) return key;
  // Zorunlu referansı eksik ret vakalarında kimlik yine kurulabilsin diye boş referans rastgele anahtara düşer.
  if (type === 'announcement') return refs.postId || EVENT_KEY;
  if (type === 'event_cancelled') return refs.eventId || EVENT_KEY;
  if (type === 'application_received') return `${refs.clubId}_${refs.applicantId}_${sequence}`;
  return EVENT_KEY;
}

/** Fan-out parçası (`createMany`): tek olay anahtarı → her alıcıya bir `set`; ad = alıcı. */
function fanOutWrites({ type, refs, recipients, key, sequence }) {
  const eventKey = eventKeyOf(type, refs, { key, sequence });
  return Object.fromEntries(recipients.map((u) => [u, set(notificationPath(type, eventKey, u), notificationCreate(type, u, refs))]));
}

/** `AttendanceRepository.promote` (T-30) + terfi edilenin `waitlist_promoted` bildirimi (kritik, aynı batch). */
function promoteNotifyWrites({ club, eventId = 'e_live', userId = 'u_student', recipient = userId, key = EVENT_KEY }) {
  return {
    ...promoteWrites({ club, eventId, userId }),
    notification: set(notificationPath('waitlist_promoted', key, recipient), notificationCreate('waitlist_promoted', recipient, { clubId: club, eventId })),
  };
}

/** `markRead` / `markAllRead` (parça başına bir update). */
const notificationRead = () => ({ read: true, ...baseUpdate() });

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
  // T-19 · clubs (`pinnedPostId` tek başına: eşlik eden gönderi yazımı yok)
  ['clubPinAlone', () => ({ pinnedPostId: 'p01', ...baseUpdate() })],
  // T-19 · posts (tek yazımlı yollar; çok yazımlılar aşağıda `batches`)
  ['postCreate', (ctx) => postCreate({ club: ctx.club, uid: ctx.uid })],
  ['postCreateSeedNulls', (ctx) => postCreate({ club: ctx.club, uid: ctx.uid }, POST_NULLS)],
  ['postEdit', () => postEdit()],
  // Ankette (`p01`) soru aynı kalır, yalnızca görsel değişir (anket sorusu yayından sonra değişmez).
  ['postEditKeepText', () => postEdit({ text: POLL_QUESTION, images: [postImage('p01')] })],
  ['postLike', (ctx) => postLike(ctx.uid)],
  ['postPinAlone', () => ({ pinned: true, ...baseUpdate() })],
  ['postHide', (ctx) => hidePayload(ctx.uid)],
  ['postUnhide', () => unhidePayload()],
  ['postCommentCountAlone', () => counterBump('commentCount', 1, 'lastCommentRef', 'comments/cm01')],
  // T-19 · posts/votes
  ['voteO1', () => voteCreate('o1')],
  ['voteO2', () => voteCreate('o2')],
  // T-19 · comments
  ['commentAddAlone', (ctx) => commentCreate({ club: ctx.club, uid: ctx.uid, postId: 'p01' })],
  ['commentEditText', () => ({ text: 'Değişmiş yorum.', ...baseUpdate() })],
  ['commentHide', (ctx) => hidePayload(ctx.uid)],
  ['commentUnhide', () => unhidePayload()],
  // T-19 · savedPosts
  ['savedCreate', (ctx) => savedCreate({ club: ctx.club, uid: ctx.uid })],
  ['savedResave', () => savedResave()],
  // T-22 · activity (eşlik eden etkinlik geçişi OLMADAN: ret)
  ['activityEventPublished', (ctx) => eventActivity(ctx.club, ctx.uid, 'event_published', 'e_public')],
  ['activityEventCancelled', (ctx) => eventActivity(ctx.club, ctx.uid, 'event_cancelled', 'e_public')],
  // T-22 · events (tek yazımlı yollar; çok yazımlılar aşağıda `batches`)
  ['eventDraftCreate', (ctx) => eventCreate({ club: ctx.club, uid: ctx.uid })],
  ['eventDraftCreateSeedNulls', (ctx) => eventCreate({ club: ctx.club, uid: ctx.uid }, EVENT_NULLS)],
  ['eventEdit', () => eventEdit()],
  ['eventRegistrationClose', () => ({ registrationOpen: false, ...baseUpdate() })],
  ['eventPublish', () => eventPublish()],
  ['eventUnpublish', () => eventUnpublish()],
  ['eventCancel', () => eventCancel()],
  ['eventGoingAlone', () => eventCountersBump({ going: 1 })],
  ['eventAttendedAlone', () => eventCountersBump({ attended: 1 })],
  // T-22 · events/private/counter (eşlik eden yönetici sayaç bileşimi OLMADAN: ret)
  ['eventCounterAlone', (ctx) => eventCounterData(ctx.club, 'e_live', 'u_member')],
  // T-22 · rsvps
  ['rsvpJoinAlone', (ctx) => rsvpCreate({ club: ctx.club, uid: ctx.uid })],
  ['rsvpCancelAlone', () => ({ status: 'cancelled', ...baseUpdate() })],
  ['rsvpReminder', () => rsvpReminder()],
  ['rsvpAttendAlone', (ctx) => ({ status: 'attended', scannedAt: serverTimestamp(), scannedBy: ctx.uid, ...baseUpdate() })],
  // T-25 · notifications (alıcı `u_member`; matris yolu `newDocPath` ile verilir)
  ['notificationEventNew', (ctx) => notificationCreate('event_new', 'u_member', { clubId: ctx.club, eventId: 'e_public' })],
  ['notificationReminderSelf', (ctx) => notificationCreate('event_reminder', ctx.uid, { clubId: ctx.club, eventId: 'e_public' })],
  ['notificationSystem', () => notificationCreate('system', 'u_member', { textKey: 'welcome' })],
  ['notificationRead', () => notificationRead()],
  ['notificationUnread', () => ({ read: false, ...baseUpdate() })],
  ['notificationRetype', () => ({ type: 'announcement', ...baseUpdate() })],
  // T-28 · supportTickets
  ['ticketCreate', (ctx) => ticketCreate({ uid: ctx.uid })],
  ['ticketCreateWithAttachment', (ctx) => ticketCreate({ uid: ctx.uid, attachmentPaths: [supportAttachmentPath()] })],
  ['ticketClose', () => ({ status: 'closed', ...baseUpdate() })],
  ['ticketEditMessage', () => ({ message: 'Değiştirilmiş mesaj.', ...baseUpdate() })],
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
  // T-19
  ['postCreateBatch', (ctx) => createPostWrites({ club: ctx.club, uid: ctx.uid })],
  ['pollCreateBatch', (ctx) => createPostWrites({ club: ctx.club, uid: ctx.uid, type: 'poll' })],
  ['announcementBatch', (ctx) => createPostWrites({ club: ctx.club, uid: ctx.uid, type: 'announcement' })],
  ['announcementPushBatch', (ctx) => createPostWrites({ club: ctx.club, uid: ctx.uid, type: 'announcement', pushSent: true })],
  ['counterAloneBatch', (ctx) => ({ counter: createPostWrites({ club: ctx.club, uid: ctx.uid, type: 'announcement', pushSent: true }).counter })],
  ['pinBatch', (ctx) => pinWrites({ club: ctx.club, postId: 'p01' })],
  ['commentAddBatch', (ctx) => addCommentWrites({ club: ctx.club, uid: ctx.uid })],
  ['commentRemoveBatch', (ctx) => removeCommentWrites({ uid: ctx.uid })],
  ['commentRestoreBatch', () => restoreCommentWrites({})],
  // T-22
  ['eventPublishedCreateBatch', (ctx) => createEventWrites({ club: ctx.club, uid: ctx.uid, status: 'published' })],
  ['eventPublishBatch', (ctx) => publishEventWrites({ club: ctx.club, uid: ctx.uid })],
  ['eventCancelBatch', (ctx) => cancelEventWrites({ club: ctx.club, uid: ctx.uid })],
  ['rsvpJoinBatch', (ctx) => rsvpJoinWrites({ club: ctx.club, uid: ctx.uid })],
  ['rsvpJoinMembersBatch', (ctx) => rsvpJoinWrites({ club: ctx.club, uid: ctx.uid, eventId: 'e_members' })],
  ['rsvpCancelBatch', (ctx) => rsvpCancelWrites({ uid: ctx.uid })],
  ['rsvpRejoinBatch', (ctx) => rsvpRejoinWrites({ uid: ctx.uid })],
  ['attendBatch', (ctx) => attendWrites({ club: ctx.club, uid: ctx.uid })],
  ['unattendBatch', (ctx) => attendWrites({ club: ctx.club, uid: ctx.uid, userId: 'u_board', attended: false })],
  ['promoteBatch', (ctx) => promoteWrites({ club: ctx.club })],
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
  DAY_MS,
  POST_NULLS,
  POST_ACTIVITY_KIND,
  istanbulDay,
  POLL_QUESTION,
  postImage,
  pollOf,
  postCreate,
  postActivity,
  postActivityPath,
  counterData,
  counterPath,
  createPostWrites,
  postEdit,
  postLike,
  postUnlike,
  hidePayload,
  unhidePayload,
  voteCreate,
  pinWrites,
  unpinWrites,
  removePostWrites,
  commentCreate,
  commentCountBump,
  addCommentWrites,
  removeCommentWrites,
  restoreCommentWrites,
  savedCreate,
  savedResave,
  NEW_TICKET_NO,
  supportAttachmentPath,
  ticketCreate,
  HOUR_MS,
  EVENT_NULLS,
  RSVP_NULLS,
  CANCEL_REASON,
  TICKET_CODE,
  eventCoverPath,
  eventCreate,
  eventActivity,
  eventActivityPath,
  createEventWrites,
  eventEdit,
  eventPublish,
  publishEventWrites,
  eventUnpublish,
  eventCancel,
  cancelEventWrites,
  rsvpPath,
  rsvpCreate,
  eventCountersBump,
  rsvpJoinWrites,
  rsvpRejoinWrites,
  rsvpCancelWrites,
  rsvpReminder,
  eventCounterPath,
  eventCounterData,
  attendWrites,
  promoteWrites,
  EVENT_KEY,
  EVENT_KEY_2,
  notificationPath,
  reminderPath,
  notificationCreate,
  eventKeyOf,
  fanOutWrites,
  promoteNotifyWrites,
  notificationRead,
  registerVariant,
  payloadFor,
  batchFor,
};
