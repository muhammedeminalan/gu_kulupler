'use strict';
// demo-data.json (prototip biçimi) → üretim şeması dönüşümü — docs/PLAN.md §9.12.
// packages/gu_data/test/fixtures/demo_data.dart ile AYNI kurallar (o dosya Dart kopyasıdır); bir kural
// değişirse ikisi birlikte değişir. Saf fonksiyonlardır: ağ, dosya ya da saat okumaz ("şimdi" ve
// rastgelelik parametredir).
//
// Zaman kuralı: her an `ISO + (now − meta.today)` olur; `*_rel_days` anahtarları yazılmaz.
// Zamanlar JS `Date` olarak döner (yazıcı bunları Firestore `timestampValue`'ya çevirir).
const { trLower } = require('./tr_lower');

/** Askıdaki kullanıcılara yazılan neden (PLAN §9.12). */
const SEED_SUSPEND_REASON = 'Topluluk kurallarının ihlali.';

/** Danışman adından ayrılan ünvanlar; sırayla denenir. */
const SEED_TITLES = Object.freeze(['Prof. Dr.', 'Doç. Dr.', 'Dr. Öğr. Üyesi', 'Öğr. Gör.', 'Dr.']);

/** Kulüpleri oluşturan ve şikayetleri çözen süper admin. */
const SUPER_ADMIN_ID = 'u_admin';

const HOUR_MS = 60 * 60 * 1000;
/** Istanbul'un UTC'ye göre sabit kayması (Dart `Limits.istanbulUtcOffset`). */
const ISTANBUL_OFFSET_MS = 3 * HOUR_MS;

const IMAGE_WIDTH = 1200;
const IMAGE_HEIGHT = 900;

/** `rsvps.ticketCode` deseni (Dart `FirestoreIds.ticketCodePattern`). */
const TICKET_CODE = /^GU-[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}$/;

/** Dönüşümün ürettiği koleksiyon anahtarları (17) — DemoDataFixture.collections ile aynı sıra. */
const COLLECTIONS = Object.freeze([
  'users', 'account', 'blocks', 'clubs', 'memberships', 'contact', 'posts', 'votes', 'comments', 'events',
  'rsvps', 'notifications', 'reports', 'activity', 'settings', 'savedPosts', 'announcementCounters',
]);

/** Koleksiyon anahtarı + kimlik → Firestore belge yolu. Oy kimliği `postId/uid` biçimindedir. */
const PATH_OF = Object.freeze({
  users: (id) => `users/${id}`,
  account: (id) => `users/${id}/private/account`,
  blocks: (id) => `blocks/${id}`,
  clubs: (id) => `clubs/${id}`,
  memberships: (id) => `memberships/${id}`,
  contact: (id) => `memberships/${id}/private/contact`,
  posts: (id) => `posts/${id}`,
  votes: (id) => `posts/${id.slice(0, id.indexOf('/'))}/votes/${id.slice(id.indexOf('/') + 1)}`,
  comments: (id) => `comments/${id}`,
  events: (id) => `events/${id}`,
  rsvps: (id) => `rsvps/${id}`,
  notifications: (id) => `notifications/${id}`,
  reports: (id) => `reports/${id}`,
  activity: (id) => `activity/${id}`,
  settings: (id) => `settings/${id}`,
  savedPosts: (id) => `savedPosts/${id}`,
  announcementCounters: (id) => `announcementCounters/${id}`,
});

const pad = (value, width) => String(value).padStart(width, '0');
/** JSON'da olmayan anahtar `null` yazılır (Dart map okuması gibi). */
const orNull = (value) => (value === undefined ? null : value);

/** Istanbul gününün parçaları (UTC+3, yaz saati yok). */
function istanbulParts(date) {
  const wall = new Date(date.getTime() + ISTANBUL_OFFSET_MS);
  return [pad(wall.getUTCFullYear(), 4), pad(wall.getUTCMonth() + 1, 2), pad(wall.getUTCDate(), 2)];
}
/** `yyyyMMdd` — `AppClock.istanbulDayKey`. */
const istanbulDayKey = (date) => istanbulParts(date).join('');
/** `yyyy-MM-dd` — `AppClock.istanbulDay`. */
const istanbulDay = (date) => istanbulParts(date).join('-');

/** `StoragePaths.newFileName` damgası: `<UTC yyyyMMddTHHmmssZ>`. */
function fileStamp(date) {
  return (
    `${pad(date.getUTCFullYear(), 4)}${pad(date.getUTCMonth() + 1, 2)}${pad(date.getUTCDate(), 2)}` +
    `T${pad(date.getUTCHours(), 2)}${pad(date.getUTCMinutes(), 2)}${pad(date.getUTCSeconds(), 2)}Z`
  );
}

/**
 * Tüm koleksiyonların dönüşümü.
 * @param {object} raw `demo-data.json` içeriği
 * @param {{now: Date, randomHex: () => string}} options
 *   `now` çalıştırma anı; `randomHex` görsel dosya adı için 16 hex üretir (betik: `crypto.randomBytes(8)`).
 * @returns {{docs: Record<string, Record<string, object>>, authUsers: object[], images: object[]}}
 *   `docs[koleksiyon][kimlik]` Firestore verisi; `authUsers` Auth emülatör kullanıcıları (parolasız);
 *   `images` Storage'a yüklenecek yer tutucu görseller.
 */
function convert(raw, { now, randomHex }) {
  if (!(now instanceof Date) || Number.isNaN(now.getTime())) throw new Error('convert: geçerli bir `now` gerekli');
  const today = new Date(raw.meta.today);
  if (Number.isNaN(today.getTime())) throw new Error('demo-data.json: meta.today geçersiz');
  const shift = now.getTime() - today.getTime();

  const { users, clubs, memberships, posts, comments, events, rsvps } = raw;

  /** `doc[field]` anı: ISO + kayma; alan boşsa `null`. */
  const time = (doc, field) => (typeof doc[field] === 'string' ? new Date(new Date(doc[field]).getTime() + shift) : null);
  /** BaseFields: `updatedAt = createdAt`, silinmemiş. */
  const base = (createdAt) => ({
    createdAt,
    updatedAt: createdAt,
    isDeleted: false,
    deletedAt: null,
    deletedBy: null,
  });
  const emailDoc = (user, createdAt) => ({ email: user.email, emailLower: user.email.toLowerCase(), ...base(createdAt) });
  const values = (map) => Object.values(map);
  const entries = (map) => Object.entries(map);
  const images = [];

  // ── users · account · blocks ───────────────────────────────────────────────────────────────
  const userDocs = {};
  const accountDocs = {};
  const blockDocs = {};
  const authUsers = [];
  for (const [uid, user] of entries(users)) {
    const createdAt = time(user, 'createdAt');
    userDocs[uid] = {
      name: user.name,
      nameLower: trLower(user.name),
      avatarSeed: orNull(user.avatarSeed),
      avatarPath: null,
      department: orNull(user.department),
      year: orNull(user.year),
      interests: orNull(user.interests),
      bio: orNull(user.bio),
      status: user.status,
      suspendReason: user.status === 'suspended' ? SEED_SUSPEND_REASON : null,
      staff: orNull(user.staff),
      profileComplete: orNull(user.profileComplete),
      ...base(createdAt),
    };
    accountDocs[uid] = { ...emailDoc(user, createdAt), fcmTokens: [], lastLoginAt: null };
    for (const blocked of user.blocked) {
      blockDocs[`${uid}_${blocked}`] = { blockerId: uid, blockedId: blocked, ...base(now) };
    }
    // Auth: e-posta doğrulanmış sayılır; `global: 'superadmin'` alan değil custom claim'dir (D-28).
    authUsers.push({
      uid,
      email: user.email,
      displayName: user.name,
      emailVerified: true,
      claims: user.global === 'superadmin' ? { superadmin: true } : null,
    });
  }

  // ── clubs ──────────────────────────────────────────────────────────────────────────────────
  /** Aktif ve danışman olmayan üyelik sayısı (demo'daki görsel sayı atılır). */
  const memberCount = (clubId) =>
    values(memberships).filter((m) => m.clubId === clubId && m.status === 'active' && m.role !== 'advisor').length;
  const pinnedPostId = (clubId) => {
    const hit = entries(posts).find(([, post]) => post.clubId === clubId && post.pinned === true);
    return hit ? hit[0] : null;
  };
  /** Danışman anlık görüntüsü: ad, ünvan önekiyle ünvan + ad olarak bölünür. */
  const advisor = (advisorId) => {
    const fullName = users[advisorId].name;
    const title = SEED_TITLES.find((t) => fullName.startsWith(`${t} `));
    return {
      name: title === undefined ? fullName : fullName.slice(title.length + 1),
      title: title === undefined ? '' : title,
      userId: advisorId,
    };
  };
  const clubDocs = {};
  for (const [clubId, club] of entries(clubs)) {
    clubDocs[clubId] = {
      name: club.name,
      nameLower: trLower(club.name),
      categoryId: orNull(club.categoryId),
      iconName: orNull(club.iconName),
      palette: orNull(club.palette),
      pattern: orNull(club.pattern),
      coverSeed: orNull(club.coverSeed),
      logoPath: null,
      coverPath: null,
      memberCount: memberCount(clubId),
      approvalRequired: orNull(club.approvalRequired),
      applicationsOpen: orNull(club.applicationsOpen),
      requireNote: orNull(club.requireNote),
      founded: orNull(club.founded),
      summary: orNull(club.summary),
      about: orNull(club.about),
      conditions: orNull(club.conditions),
      social: orNull(club.social),
      presidentId: orNull(club.presidentId),
      pinnedPostId: pinnedPostId(clubId),
      advisor: advisor(club.advisorId),
      status: orNull(club.status),
      suspendReason: orNull(club.suspendReason),
      lastMembershipRef: null,
      createdBy: SUPER_ADMIN_ID,
      ...base(time(club, 'createdAt')),
    };
  }

  // ── memberships · contact ──────────────────────────────────────────────────────────────────
  const membershipDocs = {};
  const contactDocs = {};
  for (const [id, membership] of entries(memberships)) {
    const user = users[membership.userId];
    const appliedAt = time(membership, 'appliedAt');
    // `stale` atılır (DLG-18 çakışması çalışma zamanı davranışıdır).
    membershipDocs[id] = {
      clubId: membership.clubId,
      userId: membership.userId,
      status: membership.status,
      role: membership.role,
      note: orNull(membership.note),
      applicant: {
        name: user.name,
        department: orNull(user.department),
        year: orNull(user.year),
        avatarSeed: orNull(user.avatarSeed),
      },
      appliedAt,
      decidedAt: time(membership, 'decidedAt'),
      decidedBy: orNull(membership.decidedBy),
      retryAfter: time(membership, 'retryAfter'),
      rejectReason: orNull(membership.rejectReason),
      rejectNote: orNull(membership.rejectNote),
      priorCount: orNull(membership.priorCount),
      ...base(appliedAt),
    };
    contactDocs[id] = emailDoc(user, appliedAt);
  }

  // ── posts · votes · comments ───────────────────────────────────────────────────────────────
  const postDocs = {};
  const voteDocs = {};
  for (const [postId, post] of entries(posts)) {
    const createdAt = time(post, 'createdAt');
    const likes = [...new Set(post.likes)];
    const postImages = post.images.map((seed) => {
      // StoragePaths.newFileName şeması: damga = gönderinin oluşturulma anı, 16 hex rastgele.
      const path = `posts/${postId}/${fileStamp(createdAt)}_${randomHex()}.png`;
      images.push({ path, seed, clubId: post.clubId, width: IMAGE_WIDTH, height: IMAGE_HEIGHT });
      return { path, w: IMAGE_WIDTH, h: IMAGE_HEIGHT };
    });
    postDocs[postId] = {
      clubId: post.clubId,
      authorId: post.authorId,
      type: post.type,
      title: orNull(post.title),
      text: orNull(post.text),
      images: postImages,
      poll: post.poll
        ? {
            options: post.poll.options.map((option) => ({ id: option.id, text: option.text })),
            endsAt: time(post.poll, 'endsAt'),
            showResultsAfterVote: orNull(post.poll.showResultsAfterVote),
          }
        : null,
      pinned: orNull(post.pinned),
      pushSent: orNull(post.pushSent),
      likes,
      likeCount: likes.length,
      commentCount: values(comments).filter((c) => c.postId === postId && c.deleted !== true).length,
      lastCommentRef: null,
      isHidden: orNull(post.hidden),
      hiddenBy: null,
      hiddenAt: null,
      editedAt: time(post, 'editedAt'),
      ...base(createdAt),
      isDeleted: orNull(post.deleted),
    };
    if (post.poll) {
      // Her kullanıcının İLK geçtiği seçenek bir oy belgesi olur; çoklu seçenek tekrarları düşer.
      const votedAt = new Date(createdAt.getTime() + HOUR_MS);
      for (const option of post.poll.options) {
        for (const uid of option.votes) {
          const key = `${postId}/${uid}`;
          if (!(key in voteDocs)) voteDocs[key] = { optionId: option.id, createdAt: votedAt };
        }
      }
    }
  }
  const commentDocs = {};
  for (const [commentId, comment] of entries(comments)) {
    commentDocs[commentId] = {
      postId: comment.postId,
      clubId: posts[comment.postId].clubId,
      authorId: comment.authorId,
      text: comment.text,
      isHidden: orNull(comment.hidden),
      hiddenBy: null,
      hiddenAt: null,
      ...base(time(comment, 'createdAt')),
      isDeleted: orNull(comment.deleted),
    };
  }

  // ── events · rsvps ─────────────────────────────────────────────────────────────────────────
  const rsvpCount = (eventId, status) => values(rsvps).filter((r) => r.eventId === eventId && r.status === status).length;
  const eventDocs = {};
  for (const [eventId, event] of entries(events)) {
    const createdAt = time(event, 'createdAt');
    eventDocs[eventId] = {
      clubId: event.clubId,
      createdBy: orNull(event.createdBy),
      title: event.title,
      desc: orNull(event.desc),
      type: orNull(event.type),
      startsAt: time(event, 'startsAt'),
      endsAt: time(event, 'endsAt'),
      placeId: orNull(event.placeId),
      placeText: orNull(event.placeText),
      capacity: orNull(event.capacity),
      visibility: orNull(event.visibility),
      status: event.status,
      cancelReason: orNull(event.cancelReason),
      coverSeed: orNull(event.coverSeed),
      coverPalette: orNull(event.coverPalette),
      coverPattern: orNull(event.coverPattern),
      coverPath: null,
      registrationOpen: orNull(event.registrationOpen),
      autoReminder: orNull(event.autoReminder),
      // Kayıtlı = going + attended: yoklama goingCount'u düşürmez (CD-130).
      goingCount: rsvpCount(eventId, 'going') + rsvpCount(eventId, 'attended'),
      waitlistCount: rsvpCount(eventId, 'waitlist'),
      attendedCount: rsvpCount(eventId, 'attended'),
      lastRsvpRef: null,
      publishedAt: event.status === 'draft' ? null : createdAt,
      ...base(createdAt),
    };
  }
  const rsvpDocs = {};
  for (const [id, rsvp] of entries(rsvps)) {
    const clubId = events[rsvp.eventId].clubId;
    const scannedAt = time(rsvp, 'scannedAt');
    rsvpDocs[id] = {
      eventId: rsvp.eventId,
      clubId,
      userId: rsvp.userId,
      status: rsvp.status,
      reminder: orNull(rsvp.reminder),
      ticketCode: orNull(rsvp.ticketCode),
      waitlistAt: time(rsvp, 'waitlistAt'),
      scannedAt,
      scannedBy: scannedAt === null ? null : clubs[clubId].presidentId,
      ...base(time(rsvp, 'createdAt')),
    };
  }

  // ── notifications · reports · activity ─────────────────────────────────────────────────────
  const notificationDocs = {};
  for (const [id, notification] of entries(raw.notifications)) {
    notificationDocs[id] = {
      userId: notification.userId,
      type: notification.type,
      refs: orNull(notification.refs),
      read: orNull(notification.read),
      ...base(time(notification, 'createdAt')),
    };
  }
  const targetClubId = (targetType, targetId) => {
    switch (targetType) {
      case 'post':
        return posts[targetId].clubId;
      case 'comment':
        return posts[comments[targetId].postId].clubId;
      case 'club':
        return targetId;
      case 'event':
        return events[targetId].clubId;
      default:
        return null;
    }
  };
  // Şikayet grubu şikayetçi başına bir belgeye bölünür.
  const reportDocs = {};
  for (const group of values(raw.reports)) {
    for (const reason of group.reasons) {
      reportDocs[`${reason.reporterId}_${group.targetType}_${group.targetId}`] = {
        targetType: group.targetType,
        targetId: group.targetId,
        targetClubId: targetClubId(group.targetType, group.targetId),
        reporterId: reason.reporterId,
        reason: reason.reason,
        note: orNull(reason.note),
        status: group.status,
        action: orNull(group.action),
        resolvedAt: time(group, 'resolvedAt'),
        resolvedBy: group.status === 'resolved' ? SUPER_ADMIN_ID : null,
        ...base(time(reason, 'createdAt')),
      };
    }
  }
  // Değiştirilemez günlük: BaseFields eklenmez, yalnızca `createdAt`.
  const activityDocs = {};
  for (const entry of raw.activity) {
    activityDocs[entry.id] = {
      clubId: entry.clubId,
      actorId: entry.actorId,
      kind: entry.kind,
      refs: orNull(entry.refs),
      createdAt: time(entry, 'createdAt'),
    };
  }

  // ── settings · savedPosts · announcementCounters ───────────────────────────────────────────
  const settingsDocs = {};
  for (const [uid, settings] of entries(raw.settings)) settingsDocs[uid] = { ...settings, updatedAt: now };
  const savedPostDocs = {};
  for (const [uid, postIds] of entries(raw.saved)) {
    for (const postId of postIds) {
      savedPostDocs[`${uid}_${postId}`] = {
        userId: uid,
        postId,
        clubId: posts[postId].clubId,
        savedAt: now,
        ...base(now),
      };
    }
  }
  // Sayaç günü BUGÜNE kaydırılır (Istanbul günü); demo'daki tarih atılır.
  const counterDocs = {};
  for (const [key, count] of entries(raw.dailyAnnouncementCount)) {
    const clubId = key.slice(0, key.lastIndexOf('_'));
    counterDocs[`${clubId}_${istanbulDayKey(now)}`] = {
      clubId,
      day: istanbulDay(now),
      count,
      lastPostRef: null,
      updatedAt: now,
    };
  }

  return {
    docs: {
      users: userDocs,
      account: accountDocs,
      blocks: blockDocs,
      clubs: clubDocs,
      memberships: membershipDocs,
      contact: contactDocs,
      posts: postDocs,
      votes: voteDocs,
      comments: commentDocs,
      events: eventDocs,
      rsvps: rsvpDocs,
      notifications: notificationDocs,
      reports: reportDocs,
      activity: activityDocs,
      settings: settingsDocs,
      savedPosts: savedPostDocs,
      announcementCounters: counterDocs,
    },
    authUsers,
    images,
  };
}

/**
 * Beklenen belge sayıları — dönüşümden BAĞIMSIZ olarak doğrudan demo-data.json'dan sayılır
 * (`--check` emülatördeki sayıları bununla karşılaştırır).
 * @returns {Record<string, number>} koleksiyon anahtarı → belge sayısı
 */
function expectedCounts(raw) {
  const size = (map) => Object.keys(map).length;
  const sum = (list, pick) => list.reduce((total, item) => total + pick(item), 0);
  const voters = new Set();
  for (const [postId, post] of Object.entries(raw.posts)) {
    if (!post.poll) continue;
    for (const option of post.poll.options) for (const uid of option.votes) voters.add(`${postId}/${uid}`);
  }
  return {
    users: size(raw.users),
    account: size(raw.users),
    blocks: sum(Object.values(raw.users), (u) => u.blocked.length),
    clubs: size(raw.clubs),
    memberships: size(raw.memberships),
    contact: size(raw.memberships),
    posts: size(raw.posts),
    votes: voters.size,
    comments: size(raw.comments),
    events: size(raw.events),
    rsvps: size(raw.rsvps),
    notifications: size(raw.notifications),
    reports: sum(Object.values(raw.reports), (r) => r.reasons.length),
    activity: raw.activity.length,
    settings: size(raw.settings),
    savedPosts: sum(Object.values(raw.saved), (ids) => ids.length),
    announcementCounters: size(raw.dailyAnnouncementCount),
  };
}

/**
 * Dönüştürülmüş verinin iç tutarlılığı (PLAN §9.12 "Doğrulama"). Sorun listesi döner; boş = tutarlı.
 * @param {ReturnType<typeof convert>['docs']} docs
 * @param {{announcementDailyLimit: number}} limits
 * @returns {string[]}
 */
function validate(docs, { announcementDailyLimit }) {
  const problems = [];
  const count = (map, test) => Object.values(map).filter(test).length;

  for (const [clubId, club] of Object.entries(docs.clubs)) {
    const president = docs.memberships[`${clubId}_${club.presidentId}`];
    if (!president || president.role !== 'president' || president.status !== 'active') {
      problems.push(`clubs/${clubId}: presidentId ${club.presidentId} için aktif başkan üyeliği yok`);
    }
    const members = count(docs.memberships, (m) => m.clubId === clubId && m.status === 'active' && m.role !== 'advisor');
    if (club.memberCount !== members) problems.push(`clubs/${clubId}: memberCount ${club.memberCount} ≠ ${members}`);
  }
  for (const [eventId, event] of Object.entries(docs.events)) {
    const by = (statuses) => count(docs.rsvps, (r) => r.eventId === eventId && statuses.includes(r.status));
    const expected = { goingCount: by(['going', 'attended']), waitlistCount: by(['waitlist']), attendedCount: by(['attended']) };
    for (const [field, value] of Object.entries(expected)) {
      if (event[field] !== value) problems.push(`events/${eventId}: ${field} ${event[field]} ≠ ${value}`);
    }
  }
  for (const [postId, post] of Object.entries(docs.posts)) {
    if (post.likeCount !== post.likes.length || new Set(post.likes).size !== post.likes.length) {
      problems.push(`posts/${postId}: likeCount/likes tutarsız`);
    }
    const commentCount = count(docs.comments, (c) => c.postId === postId && c.isDeleted !== true);
    if (post.commentCount !== commentCount) problems.push(`posts/${postId}: commentCount ${post.commentCount} ≠ ${commentCount}`);
  }
  for (const [id, rsvp] of Object.entries(docs.rsvps)) {
    if (!TICKET_CODE.test(rsvp.ticketCode || '')) problems.push(`rsvps/${id}: ticketCode biçimi geçersiz`);
  }
  for (const [id, report] of Object.entries(docs.reports)) {
    if (id !== `${report.reporterId}_${report.targetType}_${report.targetId}`) problems.push(`reports/${id}: kimlik biçimi geçersiz`);
  }
  for (const [id, counter] of Object.entries(docs.announcementCounters)) {
    if (counter.count > announcementDailyLimit) problems.push(`announcementCounters/${id}: count ${counter.count} > ${announcementDailyLimit}`);
  }
  return problems;
}

/**
 * Firestore'a YAZILMAYAN referans listeleri (categories/interests/departments/places) Dart
 * `StaticTables` ile aynı mı? Fark listesi döner; boş = aynı (PLAN §9.12: fark = betik durur).
 * @param {object} raw demo-data.json
 * @param {string} staticTablesSource `static_tables.dart` kaynak metni
 */
function staticTablesDiff(raw, staticTablesSource) {
  const pairs = (model, second) => {
    const re = new RegExp(`${model}\\(\\s*id:\\s*'([^']+)'${second ? `,\\s*${second}:\\s*'([^']+)'` : ''}`, 'g');
    return [...staticTablesSource.matchAll(re)].map((m) => (second ? `${m[1]}:${m[2]}` : m[1]));
  };
  const expected = {
    categories: [pairs('CategoryModel', 'icon'), raw.categories.map((c) => `${c.id}:${c.icon}`)],
    interests: [pairs('InterestModel', 'categoryId'), raw.interests.map((i) => `${i.id}:${i.cat}`)],
    departments: [pairs('DepartmentModel', 'facultyId'), raw.departments.map((d) => `${d.id}:${d.faculty}`)],
    places: [pairs('PlaceModel', null), raw.places.map((p) => (typeof p === 'string' ? p : p.id))],
  };
  const problems = [];
  for (const [name, [dartSide, jsonSide]] of Object.entries(expected)) {
    if (dartSide.join(',') !== jsonSide.join(',')) {
      problems.push(`${name}: StaticTables (${dartSide.length}) ≠ demo-data.json (${jsonSide.length})`);
    }
  }
  return problems;
}

module.exports = {
  SEED_SUSPEND_REASON,
  SEED_TITLES,
  SUPER_ADMIN_ID,
  COLLECTIONS,
  PATH_OF,
  TICKET_CODE,
  istanbulDay,
  istanbulDayKey,
  fileStamp,
  convert,
  expectedCounts,
  validate,
  staticTablesDiff,
};
