'use strict';
/**
 * K-A / M13 · danışman hesabı bağlama planlayıcısı (SAF; `set_advisor.js`). Yazımlar
 * `FirebaseMembershipRepository.setAdvisor` (AdminRepository.setAdvisor) ile AYNI belgelerdir (sözleşme
 * docs/plans/T-37.md §4 a.4; `firebase/test/contracts/repository_payloads.json#t37` `setAdvisor` senaryoları):
 *
 *  - bağla: kulübün danışman kaydı (ad / ünvan) şart; hedef hesap etkin; üyelik yok / geçmiş (`left`,
 *    `cancelled`, `rejected`, `removed`) → `active` + `advisor` (karar alanları `null`, `rejectNote: ''`,
 *    `appliedAt` sunucu zamanı — etkin üye listesi sırası), iletişim belgesi hesap e-postasıyla, kulüpte
 *    `advisor.userId`; `memberCount` ve yan belge YOK (danışman sayılmaz);
 *  - kaldır: etkin danışman üyeliği → `left` + kulüpte `advisor.userId: null` (ad / ünvan kalır); bayat bağda
 *    (üyelik etkin danışman değil ama kulüp bu hesabı gösteriyor — hesap silme) yalnızca kulüp bağı ayrılır.
 *
 * Hatalar (`{error}`, yazım yok): kulüp yok / silinmiş; danışman kaydı yok; başka hesap bağlı; hedefin etkin /
 * bekleyen başka bir üyeliği var; hesap etkin değil; kaldırmada etkin danışman üyeliği yok. Zaten bağlı → `noop`.
 */
const { SERVER_TIME, isValidId } = require('./admin_cli');

const PAST = new Set(['left', 'cancelled', 'rejected', 'removed']);
const BASE_CREATE = () => ({ isDeleted: false, createdAt: SERVER_TIME, updatedAt: SERVER_TIME, deletedAt: null, deletedBy: null });

/**
 * @param {{clubId: string, uid: string, remove: boolean, club: object|null, membership: object|null,
 *   contact: object|null, user: object|null, account: object|null}} state işlem içinde okunan belgeler
 * @returns {{error: string|null, noop: boolean, writes: Array<{op: string, path: string, data: object}>}}
 */
function buildAdvisorPlan(state) {
  const { clubId, uid, remove, club, membership, contact, user, account } = state;
  const fail = (error) => ({ error, noop: false, writes: [] });
  if (!isValidId(clubId) || !isValidId(uid)) return fail('geçersiz kimlik');
  if (!club || club.isDeleted === true) return fail(`clubs/${clubId} yok ya da silinmiş`);
  const membershipPath = `memberships/${clubId}_${uid}`;
  const owned = membership && membership.clubId === clubId && membership.userId === uid ? membership : null;
  if (membership && !owned) return fail(`${membershipPath}: başka bir üyeliğin kimliği`);
  const isAdvisor = !!owned && owned.status === 'active' && owned.role === 'advisor';
  const advisor = club.advisor || null;

  if (remove) {
    const linked = !!advisor && advisor.userId === uid;
    // Bayat bağ (üyelik hesap silmeyle zaten kapandı — M14 / W-91): yalnızca kulüp bağı ayrılır.
    if (!isAdvisor && !linked) return fail(`${membershipPath}: etkin danışman üyeliği yok`);
    const writes = isAdvisor ? [{ op: 'update', path: membershipPath, data: { status: 'left', updatedAt: SERVER_TIME } }] : [];
    if (linked) {
      writes.push({ op: 'update', path: `clubs/${clubId}`, data: { 'advisor.userId': null, updatedAt: SERVER_TIME } });
    }
    return { error: null, noop: false, writes };
  }

  if (!advisor) return fail(`clubs/${clubId}: danışman kaydı (ad / ünvan) yok — önce ADM-03'te ekle`);
  if (isAdvisor && advisor.userId === uid) return { error: null, noop: true, writes: [] };
  if (advisor.userId) return fail(`clubs/${clubId}: başka bir hesap bağlı (${advisor.userId}) — önce --remove`);
  if (owned && !PAST.has(owned.status)) return fail(`${membershipPath}: hedefin ${owned.status} / ${owned.role} üyeliği var`);
  if (!user || user.status !== 'active' || user.isDeleted === true) return fail(`users/${uid}: hesap etkin değil`);
  const email = account && typeof account.email === 'string' ? account.email : '';
  if (!email) return fail(`users/${uid}/private/account: e-posta yok`);

  const fields = {
    status: 'active',
    role: 'advisor',
    applicant: {
      name: user.name,
      department: user.department === undefined ? null : user.department,
      year: user.year === undefined ? null : user.year,
      avatarSeed: user.avatarSeed,
    },
    appliedAt: SERVER_TIME,
    decidedAt: null,
    decidedBy: null,
    retryAfter: null,
    rejectReason: null,
    rejectNote: '',
  };
  const writes = [
    owned
      // Geçmiş üyelik: `priorCount` korunur.
      ? { op: 'update', path: membershipPath, data: { ...fields, updatedAt: SERVER_TIME } }
      : { op: 'set', path: membershipPath, data: { clubId, userId: uid, ...fields, priorCount: 0, ...BASE_CREATE() } },
    contact
      ? { op: 'update', path: `${membershipPath}/private/contact`, data: { email, emailLower: email.toLowerCase(), updatedAt: SERVER_TIME } }
      : { op: 'set', path: `${membershipPath}/private/contact`, data: { email, emailLower: email.toLowerCase(), note: '', ...BASE_CREATE() } },
    { op: 'update', path: `clubs/${clubId}`, data: { 'advisor.userId': uid, updatedAt: SERVER_TIME } },
  ];
  return { error: null, noop: false, writes };
}

module.exports = { buildAdvisorPlan };
