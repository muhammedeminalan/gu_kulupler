'use strict';
// T-37 — süper admin yazımlarının yükleri (sözleşme docs/plans/T-37.md §4 a; PLAN §10.4 AdminRepository,
// MembershipRepository.setAdvisor). Her üretici repository'nin tek batch / transaction'ındaki yazımları
// `{ad: {op, path, data}}` olarak döndürür (T-15 kalıbı); test bir yazımı çıkarıp / değiştirip
// `Object.values(...)` ile gönderir (helpers/budget.js `buildBatch`). İstemci biçimi: null alanların anahtarı
// yoktur (include_if_null: false — W-51); `seedNulls` açık `null` biçimini üretir.
const { increment, serverTimestamp } = require('firebase/firestore');
const roles = require('../expectations/roles.json');
const payloads = require('./payloads');

const {
  EVENT_KEY,
  EVENT_KEY_2,
  applicantOf,
  baseCreate,
  baseUpdate,
  clubCounterData,
  clubCounterPath,
  contactPath,
  hidePayload,
  membershipPath,
  notificationCreate,
  notificationPath,
  roleActivity,
  roleActivityPath,
} = payloads;

const set = (path, data) => ({ op: 'set', path, data });
const update = (path, data) => ({ op: 'update', path, data });

/** Süper admin bağlamının uid'i (roles.json `super`). */
const ADMIN = roles.definitions.super.uid;
/** Yeni kulübün kimliği (otomatik kimlik biçimi `[A-Za-z0-9]+` — `_` yok). */
const NEW_CLUB = 'cNew01';
/** Askı gerekçesi örneği. */
const REASON = 'Topluluk kurallarının ihlali.';
/** Danışman kaydı (K-A): ad + ünvan, hesap bağlı değil. */
const ADVISOR = Object.freeze({ name: 'Ayşe Yılmaz', title: 'Doç. Dr.' });
/** Kulüp medya yolu (`StoragePaths.newFileName`). */
const MEDIA_PATH = (club, ext = 'jpg') => `clubs/${club}/20261015T090000Z_0a1b2c3d4e5f6071.${ext}`;

/** uid → fixture hesabının e-postası (`users/{uid}/private/account.email` — roles.json token e-postası). */
function emailOfUid(uid) {
  const def = Object.values(roles.definitions).find((d) => d.uid === uid);
  if (!def || !def.token) throw new Error(`fixture hesabı yok: ${uid}`);
  return def.token.email;
}

// ── Kulüp ────────────────────────────────────────────────────────────────────────────────────

/** `AdminRepository.createClub` kulüp belgesi (`ClubModel.toJson()` + `BaseFieldsPayload.create()`). */
function clubCreateDoc({ club = NEW_CLUB, actor = ADMIN, president = 'u_student', advisor, seedNulls = false } = {}, extra) {
  const doc = {
    name: 'Yeni Kulüp',
    nameLower: 'yeni kulüp',
    categoryId: 'k02',
    iconName: 'flask-conical',
    palette: 'slate',
    pattern: 'dots',
    coverSeed: `club-${club}`,
    memberCount: 1,
    approvalRequired: true,
    applicationsOpen: true,
    requireNote: false,
    founded: 2020,
    summary: 'Yeni kurulan kulüp.',
    about: '',
    conditions: [],
    social: {},
    presidentId: president,
    status: 'active',
    ...baseCreate({ createdBy: actor }),
  };
  if (advisor) doc.advisor = { ...advisor };
  if (seedNulls) {
    Object.assign(doc, { logoPath: null, coverPath: null, pinnedPostId: null, suspendReason: null });
    if (!advisor) doc.advisor = null;
    if (advisor) doc.advisor.userId = null;
  }
  return { ...doc, ...extra };
}

/**
 * Süper admin yerleştirmesinin üyelik alanları (A `_appointed`): `active` + rol, `applicant` hedefin profilinden,
 * `appliedAt` sunucu zamanı, karar alanları aktör (danışmanda `null` — M13), önceki kararın izleri boş.
 */
function appointedFields(uid, role, { actor = ADMIN, decided = role !== 'advisor' } = {}) {
  return {
    status: 'active',
    role,
    applicant: applicantOf(uid),
    appliedAt: serverTimestamp(),
    decidedAt: decided ? serverTimestamp() : null,
    decidedBy: decided ? actor : null,
    retryAfter: null,
    rejectReason: null,
    rejectNote: '',
  };
}

/** Hedefin üyelik yazımı: belge yoksa `set` (C), geçmiş üyelikse `update` (`priorCount` korunur). */
function appointedWrite(club, uid, role, { existing = false, actor } = {}) {
  const fields = appointedFields(uid, role, { actor });
  return existing
    ? update(membershipPath(club, uid), { ...fields, ...baseUpdate() })
    : set(membershipPath(club, uid), { clubId: club, userId: uid, ...fields, priorCount: 0, ...baseCreate() });
}

/** Hedefin `private/contact` yazımı: hesap e-postası; var olan belgede yalnızca e-posta. */
function appointedContact(club, uid, { existing = false, email = emailOfUid(uid) } = {}) {
  return existing
    ? update(contactPath(club, uid), { email, emailLower: email.toLowerCase(), ...baseUpdate() })
    : set(contactPath(club, uid), { email, emailLower: email.toLowerCase(), note: '', ...baseCreate() });
}

/** `AdminRepository.createClub` — kulüp + başkan üyeliği + contact (tek batch). */
function createClubWrites({ club = NEW_CLUB, actor = ADMIN, president = 'u_student', advisor, seedNulls } = {}) {
  return {
    club: set(`clubs/${club}`, clubCreateDoc({ club, actor, president, advisor, seedNulls })),
    membership: appointedWrite(club, president, 'president', { actor }),
    contact: appointedContact(club, president),
  };
}

/** `AdminRepository.updateClubIdentity` — `ClubIdentityPatch` alanları + `updatedAt`. */
function identityWrites({ club = 'c01' } = {}, extra) {
  return {
    club: update(`clubs/${club}`, {
      name: 'Robotik Topluluğu',
      nameLower: 'robotik topluluğu',
      categoryId: 'k03',
      iconName: 'mountain',
      founded: 2016,
      summary: 'Yeni özet.',
      approvalRequired: false,
      ...baseUpdate(),
      ...extra,
    }),
  };
}

/** `AdminRepository.updateClubMedia` — kulüp yolu (Storage yüklemesinden sonra). */
const mediaWrites = ({ club = 'c01' } = {}) => ({ club: update(`clubs/${club}`, { logoPath: MEDIA_PATH(club), ...baseUpdate() }) });

/** `AdminRepository.suspendClub` / `activateClub`. */
const suspendClubWrites = ({ club = 'c01', reason = REASON } = {}) => ({
  club: update(`clubs/${club}`, { status: 'suspended', suspendReason: reason, ...baseUpdate() }),
});
const activateClubWrites = ({ club = 'c01' } = {}) => ({
  club: update(`clubs/${club}`, { status: 'active', suspendReason: null, ...baseUpdate() }),
});

/**
 * `AdminRepository.assignPresident` (yeni hedef — W-94): hedef üyelik `active` + `president` (+ contact), eski başkan
 * `board`, kulüp `{presidentId, memberCount +1}`, yan belge hedefi gösterir, `role_changed` günlüğü + iki bildirim.
 */
function assignWrites({ club = 'c01', actor = ADMIN, to = 'u_student', from = 'u_president', existing = false, contactExists = existing, priorCount = 0 } = {}) {
  return {
    to: appointedWrite(club, to, 'president', { existing, actor }),
    contact: appointedContact(club, to, { existing: contactExists }),
    from: update(membershipPath(club, from), { role: 'board', ...baseUpdate() }),
    club: update(`clubs/${club}`, { presidentId: to, memberCount: increment(1), ...baseUpdate() }),
    counter: set(clubCounterPath(club), clubCounterData(club, to)),
    activity: set(roleActivityPath(club, actor, to, 'president', priorCount), roleActivity(club, actor, to, 'president')),
    notifyTo: set(notificationPath('role_changed', EVENT_KEY, to), notificationCreate('role_changed', to, { clubId: club, role: 'president' })),
    notifyFrom: set(notificationPath('role_changed', EVENT_KEY_2, from), notificationCreate('role_changed', from, { clubId: club, role: 'board' })),
  };
}

/** `MembershipRepository.setAdvisor(active: true)` — M13 bağla: üyelik `active` + `advisor` + contact + `advisor.userId`. */
function advisorLinkWrites({ club = 'c01', uid = 'u_student', existing = false, contactExists = existing } = {}) {
  return {
    membership: appointedWrite(club, uid, 'advisor', { existing }),
    contact: appointedContact(club, uid, { existing: contactExists }),
    club: update(`clubs/${club}`, { 'advisor.userId': uid, ...baseUpdate() }),
  };
}

/** `MembershipRepository.setAdvisor(active: false)` — M13 kaldır: üyelik `left` + `advisor.userId: null`. */
function advisorUnlinkWrites({ club = 'c01', uid = 'u_advisor', clubLinked = true } = {}) {
  const writes = { membership: update(membershipPath(club, uid), { status: 'left', ...baseUpdate() }) };
  if (clubLinked) writes.club = update(`clubs/${club}`, { 'advisor.userId': null, ...baseUpdate() });
  return writes;
}

// ── Kullanıcı ────────────────────────────────────────────────────────────────────────────────

/** `AdminRepository.suspendUser` (CD-133): `users.status` + `private/account.suspendReason` tek batch. */
function suspendUserWrites({ uid = 'u_member', reason = REASON, status = 'suspended' } = {}) {
  return {
    user: update(`users/${uid}`, { status, ...baseUpdate() }),
    account: update(`users/${uid}/private/account`, { suspendReason: reason, ...baseUpdate() }),
  };
}
/** `AdminRepository.activateUser`. */
const activateUserWrites = ({ uid = 'u_susp' } = {}) => suspendUserWrites({ uid, reason: null, status: 'active' });

// ── Şikayet ──────────────────────────────────────────────────────────────────────────────────

/** Grup anahtarı — `FirestoreIds.reportGroupKey`: `{targetType}_{targetId}`. */
const groupKey = (type, id) => `${type}_${id}`;

/** `ReportRepository.report` biçiminde (seed) ek şikayet belgesi. */
function reportDoc(reporterId, type, id, clubId) {
  const doc = { targetType: type, targetId: id, reporterId, reason: 'spam', note: '', status: 'open', action: null, resolvedAt: null, resolvedBy: null };
  if (clubId) doc.targetClubId = clubId;
  else doc.targetClubId = null;
  const now = serverTimestamp();
  return { ...doc, createdAt: now, updatedAt: now, isDeleted: false, deletedAt: null, deletedBy: null };
}

/**
 * `AdminRepository.resolveReports` — grubun her açık şikayeti çözülür; `removed` ise hedef gönderi / yorum gizlenir
 * (`addHideToBatch`, T-19 süper dalı); her şikayetçiye bir `report_resolved` (tek olay anahtarı).
 */
function resolveWrites({ reporters, type = 'post', id = 'p01', action = 'removed', actor = ADMIN, hide = action === 'removed', key = EVENT_KEY }) {
  const writes = {};
  for (const reporter of reporters) {
    writes[`report_${reporter}`] = update(`reports/${reporter}_${type}_${id}`, {
      status: 'resolved',
      action,
      resolvedAt: serverTimestamp(),
      resolvedBy: actor,
      ...baseUpdate(),
    });
  }
  if (hide) writes.hide = update(`${type === 'comment' ? 'comments' : 'posts'}/${id}`, hidePayload(actor));
  for (const reporter of reporters) {
    writes[`notify_${reporter}`] = set(
      notificationPath('report_resolved', key, reporter),
      notificationCreate('report_resolved', reporter, { reportId: groupKey(type, id) }),
    );
  }
  return writes;
}

module.exports = {
  ADMIN,
  NEW_CLUB,
  REASON,
  ADVISOR,
  MEDIA_PATH,
  emailOfUid,
  clubCreateDoc,
  appointedFields,
  appointedWrite,
  appointedContact,
  createClubWrites,
  identityWrites,
  mediaWrites,
  suspendClubWrites,
  activateClubWrites,
  assignWrites,
  advisorLinkWrites,
  advisorUnlinkWrites,
  suspendUserWrites,
  activateUserWrites,
  groupKey,
  reportDoc,
  resolveWrites,
};
