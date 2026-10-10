'use strict';
// Rules testlerinin en küçük veri kümesi (PLAN §11.6). Veri kuralları atlayarak
// (`withSecurityRulesDisabled` bağlamı — setup/env.js `getAdminContext`) kurulur; testin kendisi
// kurallar AÇIKKEN koşar.
// Kullanıcı ve üyelik belgeleri `expectations/roles.json` bağlam tanımlarından türetilir:
// bağlam (token) ile belge (users.status, memberships.status/role) ayrı yerlerde yazılmaz.
const { doc, getDoc, writeBatch, serverTimestamp, Timestamp } = require('firebase/firestore');
const roles = require('../expectations/roles.json');
const { getAdminContext } = require('../setup/env');

const CLUB = roles.club;
const OTHER_CLUB = roles.otherClub;

/** Tek batch'teki yazım üst sınırı (Dart `Limits.batchMaxWrites` ile aynı pay). */
const BATCH_MAX_WRITES = 450;

const HOUR_MS = 60 * 60 * 1000;
const DAY_MS = 24 * HOUR_MS;

/** Silinmemiş belgenin ortak alanları (sunucu zamanı). */
function base(extra) {
  return {
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    isDeleted: false,
    deletedAt: null,
    deletedBy: null,
    ...extra,
  };
}

/** Şimdiden `ms` sonrası (negatif = öncesi). */
function fromNow(ms) {
  return Timestamp.fromMillis(Date.now() + ms);
}

function userDoc(uid, user) {
  return base({
    name: `Test ${uid}`,
    nameLower: `test ${uid}`,
    avatarSeed: uid,
    avatarPath: null,
    department: 'd01',
    year: '1',
    interests: ['i01'],
    bio: '',
    status: user.status,
    suspendReason: user.status === 'suspended' ? 'Topluluk kurallarının ihlali.' : null,
    staff: false,
    profileComplete: user.profileComplete,
  });
}

function emailDoc(email) {
  return base({ email, emailLower: email.toLowerCase() });
}

function settingsDoc() {
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
  };
}

function membershipDoc(uid, membership) {
  const decided = membership.status !== 'pending';
  return base({
    clubId: membership.clubId,
    userId: uid,
    status: membership.status,
    role: membership.role,
    note: '',
    applicant: { name: `Test ${uid}`, department: 'd01', year: '1', avatarSeed: uid },
    appliedAt: fromNow(-30 * DAY_MS),
    decidedAt: decided ? fromNow(-29 * DAY_MS) : null,
    decidedBy: decided ? 'u_president' : null,
    retryAfter: null,
    rejectReason: null,
    rejectNote: null,
    priorCount: 0,
  });
}

function clubDoc(clubId, presidentId, memberCount) {
  return base({
    name: `Test Kulübü ${clubId}`,
    nameLower: `test kulübü ${clubId}`,
    categoryId: 'k01',
    iconName: 'cpu',
    palette: 'red',
    pattern: 'mountain',
    coverSeed: `club-${clubId}`,
    logoPath: null,
    coverPath: null,
    memberCount,
    approvalRequired: true,
    applicationsOpen: true,
    requireNote: false,
    founded: 2015,
    summary: 'Rules testi kulübü.',
    about: '',
    conditions: [],
    social: { email: null, instagram: null, web: null },
    presidentId,
    pinnedPostId: null,
    advisor: null,
    status: 'active',
    suspendReason: null,
    lastMembershipRef: null,
    createdBy: 'u_super',
  });
}

function eventDoc(visibility, status, goingCount) {
  return base({
    clubId: CLUB,
    createdBy: 'u_board',
    title: `Etkinlik ${visibility}/${status}`,
    desc: '',
    type: 'egitim',
    startsAt: fromNow(2 * DAY_MS),
    endsAt: fromNow(2 * DAY_MS + 2 * HOUR_MS),
    placeId: 'pl01',
    placeText: null,
    capacity: 40,
    visibility,
    status,
    cancelReason: null,
    coverSeed: 'event-test',
    coverPalette: 'red',
    coverPattern: 'lines',
    coverPath: null,
    registrationOpen: true,
    autoReminder: true,
    goingCount,
    waitlistCount: 0,
    attendedCount: 0,
    lastRsvpRef: null,
    publishedAt: status === 'draft' ? null : serverTimestamp(),
  });
}

/** Bağlam tanımlarından kullanıcı, hesap, ayar, üyelik ve iletişim belgeleri. */
function identityDocs({ formerStatus }) {
  const docs = {};
  for (const [name, def] of Object.entries(roles.definitions)) {
    if (!def.uid) continue;
    if (def.user) {
      docs[`users/${def.uid}`] = userDoc(def.uid, def.user);
      docs[`users/${def.uid}/private/account`] = { ...emailDoc(def.token.email), fcmTokens: [], lastLoginAt: null };
      docs[`settings/${def.uid}`] = settingsDoc();
    }
    if (def.membership) {
      const membership = name === 'former' ? { ...def.membership, status: formerStatus } : def.membership;
      const id = `${membership.clubId}_${def.uid}`;
      docs[`memberships/${id}`] = membershipDoc(def.uid, membership);
      docs[`memberships/${id}/private/contact`] = emailDoc(def.token.email);
    }
  }
  return docs;
}

/** Kulübün `memberCount` değeri: aktif ve danışman olmayan üyelikler (domain-model §4). */
function memberCount(docs, clubId) {
  return Object.entries(docs).filter(
    ([path, data]) =>
      /^memberships\/[^/]+$/.test(path) && data.clubId === clubId && data.status === 'active' && data.role !== 'advisor',
  ).length;
}

/**
 * Temel veri kümesi: bağlamların kullanıcı/üyelik belgeleri, iki kulüp (`c01`, `c02`), bir gönderi
 * (anketli) + oy + yorum, üç etkinlik (public, members, draft), bir katılım, bildirim, şikayet,
 * faaliyet, engel, kayıt, destek talebi ve duyuru sayacı. Koleksiyon task'ları genişletir.
 * @param {{formerStatus?: string}} [options] `former` bağlamının üyelik durumu (varsayılan `left`)
 * @returns {Record<string, object>} belge yolu → veri
 */
function baseDocs(options = {}) {
  const formerStatus = options.formerStatus || roles.formerStatuses[0];
  if (!roles.formerStatuses.includes(formerStatus)) throw new Error(`geçersiz formerStatus: ${formerStatus}`);
  const docs = identityDocs({ formerStatus });

  docs[`clubs/${CLUB}`] = clubDoc(CLUB, 'u_president', memberCount(docs, CLUB));
  docs[`clubs/${OTHER_CLUB}`] = clubDoc(OTHER_CLUB, 'u_mgr2', memberCount(docs, OTHER_CLUB));

  docs['posts/p01'] = base({
    clubId: CLUB,
    authorId: 'u_board',
    type: 'poll',
    title: null,
    text: 'Rules testi gönderisi.',
    images: [],
    poll: {
      options: [
        { id: 'o1', text: 'Evet' },
        { id: 'o2', text: 'Hayır' },
      ],
      endsAt: fromNow(7 * DAY_MS),
      showResultsAfterVote: true,
    },
    pinned: false,
    pushSent: false,
    likes: [],
    likeCount: 0,
    commentCount: 1,
    lastCommentRef: null,
    isHidden: false,
    hiddenBy: null,
    hiddenAt: null,
    editedAt: null,
  });
  docs['posts/p01/votes/u_member'] = { optionId: 'o1', createdAt: serverTimestamp() };
  docs['comments/cm01'] = base({
    postId: 'p01',
    clubId: CLUB,
    authorId: 'u_member',
    text: 'Rules testi yorumu.',
    isHidden: false,
    hiddenBy: null,
    hiddenAt: null,
  });

  docs['events/e_public'] = eventDoc('public', 'published', 1);
  docs['events/e_members'] = eventDoc('members', 'published', 0);
  docs['events/e_draft'] = eventDoc('public', 'draft', 0);
  docs['rsvps/e_public_u_member'] = base({
    eventId: 'e_public',
    clubId: CLUB,
    userId: 'u_member',
    status: 'going',
    reminder: '1h',
    ticketCode: 'GU-ABCD-2345',
    waitlistAt: null,
    scannedAt: null,
    scannedBy: null,
  });

  docs['notifications/n01'] = base({ userId: 'u_member', type: 'system', refs: { textKey: 'welcome' }, read: false });
  docs['reports/u_member_post_p01'] = base({
    targetType: 'post',
    targetId: 'p01',
    targetClubId: CLUB,
    reporterId: 'u_member',
    reason: 'spam',
    note: '',
    status: 'open',
    action: null,
    resolvedAt: null,
    resolvedBy: null,
  });
  docs['activity/a01'] = {
    clubId: CLUB,
    actorId: 'u_board',
    kind: 'post_created',
    refs: { postId: 'p01' },
    createdAt: serverTimestamp(),
  };
  docs['blocks/u_member_u_student'] = base({ blockerId: 'u_member', blockedId: 'u_student' });
  docs['savedPosts/u_member_p01'] = base({
    userId: 'u_member',
    postId: 'p01',
    clubId: CLUB,
    savedAt: serverTimestamp(),
  });
  docs['supportTickets/t01'] = base({
    userId: 'u_student',
    ticketNo: 'GU-ABC234',
    topic: 'other',
    message: 'Rules testi destek talebi.',
    attachmentPaths: [],
    status: 'open',
  });
  // Sayaç günü sabittir; gün sınırı vakaları (T-19 announcement_limit) kendi sayacını kurar.
  docs[`announcementCounters/${CLUB}_20261008`] = {
    clubId: CLUB,
    day: '2026-10-08',
    count: 1,
    lastPostRef: null,
    updatedAt: serverTimestamp(),
  };
  return docs;
}

/** Tek bir hedef belge için en küçük veri (deny-all / delete vakaları: belge VAR olmalı). */
function targetDoc(extra) {
  return base({ ownerId: 'u_owner', ...extra });
}

/** `expectations/*.json#fixture` adları → veri kümesi üreticisi. */
const FIXTURES = Object.freeze({
  base: baseDocs,
  none: () => ({}),
});

/**
 * Belgeleri kuralları atlayarak yazar.
 * @param {Record<string, object>} docs belge yolu → veri
 */
async function seedDocs(docs) {
  const entries = Object.entries(docs);
  if (entries.length === 0) return;
  const db = (await getAdminContext()).firestore();
  for (let i = 0; i < entries.length; i += BATCH_MAX_WRITES) {
    const batch = writeBatch(db);
    for (const [path, data] of entries.slice(i, i + BATCH_MAX_WRITES)) batch.set(doc(db, path), data);
    await batch.commit();
  }
}

/** Adlı veri kümesini yazar; bilinmeyen ad hatadır. */
async function seedFixture(name, options) {
  const build = FIXTURES[name];
  if (!build) throw new Error(`bilinmeyen fixture: ${name} (geçerli: ${Object.keys(FIXTURES).join(', ')})`);
  const docs = build(options);
  await seedDocs(docs);
  return docs;
}

/** Temel veri kümesini yazar ve yazılan belgeleri döndürür. */
function seedBase(options) {
  return seedFixture('base', options);
}

/** Belgeyi kuralları atlayarak okur; yoksa `null`. */
async function readDoc(path) {
  const snapshot = await getDoc(doc((await getAdminContext()).firestore(), path));
  return snapshot.exists() ? snapshot.data() : null;
}

module.exports = { CLUB, OTHER_CLUB, FIXTURES, baseDocs, targetDoc, seedDocs, seedFixture, seedBase, readDoc };
