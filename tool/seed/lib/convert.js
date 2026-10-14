'use strict';
// demo-data.json (prototip biçimi) → üretim şeması dönüşümü — docs/PLAN.md §9.12.
// packages/gu_data/test/fixtures/demo_data.dart ile AYNI kurallar (o dosya Dart kopyasıdır); bir kural
// değişirse ikisi birlikte değişir. Saf fonksiyonlardır: ağ, dosya ya da saat okumaz ("şimdi" ve
// rastgelelik parametredir).
//
// Zaman kuralı (tek yer: `dayShiftMs`): her an `ISO + D` olur; D = referans gün (`meta.today`, Istanbul
// gece yarısı) ile çalıştırma anının Istanbul günü arasındaki TAM gün farkı — saat korunur (demo'da
// "yarın 18:00" olan etkinlik, tohumlama hangi saatte yapılırsa yapılsın yine yarın 18:00'dedir).
// `*_rel_days` anahtarları yazılmaz.
// Zamanlar JS `Date` olarak döner (yazıcı bunları Firestore `timestampValue`'ya çevirir).
const { trLower } = require('./tr_lower');

/** Askıdaki kullanıcıların `private/account` belgesine yazılan neden (PLAN §9.12, CD-133). */
const SEED_SUSPEND_REASON = 'Topluluk kurallarının ihlali.';

/** Danışman adından ayrılan ünvanlar; sırayla denenir. */
const SEED_TITLES = Object.freeze(['Prof. Dr.', 'Doç. Dr.', 'Dr. Öğr. Üyesi', 'Öğr. Gör.', 'Dr.']);

/** Kulüpleri oluşturan ve şikayetleri çözen süper admin. */
const SUPER_ADMIN_ID = 'u_admin';

const HOUR_MS = 60 * 60 * 1000;
const DAY_MS = 24 * HOUR_MS;
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

/** [date]'in Istanbul gününün başlangıcı (UTC ms) — `AppClock.istanbulStartOfDay`. */
const istanbulStartOfDay = (date) =>
  Math.floor((date.getTime() + ISTANBUL_OFFSET_MS) / DAY_MS) * DAY_MS - ISTANBUL_OFFSET_MS;

/** Demo verinin kayması: `meta.today` gününden [now]'ın Istanbul gününe tam gün farkı (ms). */
const dayShiftMs = (today, now) => istanbulStartOfDay(now) - istanbulStartOfDay(today);

// ── T-25 · bildirim belgeleri (docs/plans/T-25.md §6 a–b) ────────────────────────────────────────
/** Türün zorunlu `refs` alanları — Dart `NotificationRefsModel.requiredFor` ile aynı. */
const NOTIFICATION_REFS = Object.freeze({
  application_received: ['clubId', 'applicantId'],
  application_approved: ['clubId'],
  application_rejected: ['clubId'],
  removed_from_club: ['clubId'],
  role_changed: ['clubId', 'role'],
  announcement: ['clubId', 'postId'],
  event_new: ['clubId', 'eventId'],
  event_reminder: ['clubId', 'eventId'],
  event_cancelled: ['clubId', 'eventId'],
  waitlist_promoted: ['clubId', 'eventId'],
  report_resolved: ['reportId'],
  new_report: ['reportId'],
  system: ['textKey'],
});
/** Olay anahtarı biçimi (`NotificationWriter.newEventKey`; Rules `[A-Za-z0-9]{20}`). */
const EVENT_KEY = /^[A-Za-z0-9]{20}$/;

/**
 * Bildirim belgesinin kimliği (`FirestoreIds.notification`): `event_reminder` → `event_reminder_{eventId}_{uid}`
 * (createSelf ile aynı — ikinci belge açılmaz); tek seferlik olaylarda dağıtıcıyla aynı olay anahtarı (CD-148):
 * `announcement` → postId, `event_cancelled` → eventId, `application_received` → `{clubId}_{applicantId}_{priorCount}`
 * ([sequence] = başvuranın seed üyeliğinin `priorCount`'u, yoksa 0); diğerleri `{type}_{eventKey}_{uid}`. Demo
 * kaydının olay anahtarı kaydın kimliğinden türer (`seed` + kimliğin harf / rakamları, `0` ile 20 karaktere):
 * yeniden tohumlama aynı belgeye yazar; 20'yi aşan ya da çakışan anahtar dönüşüm / sayı denetiminde hatadır.
 */
function notificationDocId(rawId, notification, sequence = 0) {
  const { type, refs, userId } = notification;
  if (type === 'event_reminder') return `event_reminder_${refs.eventId}_${userId}`;
  if (type === 'announcement') return `announcement_${refs.postId}_${userId}`;
  if (type === 'event_cancelled') return `event_cancelled_${refs.eventId}_${userId}`;
  if (type === 'application_received') return `application_received_${refs.clubId}_${refs.applicantId}_${sequence}_${userId}`;
  const key = `seed${rawId.replace(/[^A-Za-z0-9]/g, '')}`.padEnd(20, '0');
  if (!EVENT_KEY.test(key)) throw new Error(`notifications/${rawId}: olay anahtarı üretilemedi (${key})`);
  return `${notification.type}_${key}_${notification.userId}`;
}

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
  const shift = dayShiftMs(today, now);

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
      staff: orNull(user.staff),
      profileComplete: orNull(user.profileComplete),
      ...base(createdAt),
    };
    // Askı gerekçesi herkese açık `users` belgesine değil buraya yazılır (CD-133).
    accountDocs[uid] = {
      ...emailDoc(user, createdAt),
      fcmTokens: [],
      lastLoginAt: null,
      suspendReason: user.status === 'suspended' ? SEED_SUSPEND_REASON : null,
    };
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
    // `stale` atılır (DLG-18 çakışması çalışma zamanı davranışıdır). Başvuru notu üyelik belgesine
    // yazılmaz: belgeyi kulübün her aktif üyesi okuyabilir; not `private/contact`'tadır (CD-137).
    membershipDocs[id] = {
      clubId: membership.clubId,
      userId: membership.userId,
      status: membership.status,
      role: membership.role,
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
    contactDocs[id] = { ...emailDoc(user, appliedAt), note: orNull(membership.note) };
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
      images.push({ path, seed, clubId: post.clubId, uploaderId: post.authorId, width: IMAGE_WIDTH, height: IMAGE_HEIGHT });
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
      // Bekleme sırası `waitlistAt`'tan okunur (T-22): prototipte anı olmayan bekleyen kayıt oluşturulduğu anda
      // girmiş sayılır.
      waitlistAt: time(rsvp, 'waitlistAt') ?? (rsvp.status === 'waitlist' ? time(rsvp, 'createdAt') : null),
      scannedAt,
      scannedBy: scannedAt === null ? null : clubs[clubId].presidentId,
      ...base(time(rsvp, 'createdAt')),
    };
  }

  // ── notifications · reports · activity ─────────────────────────────────────────────────────
  // T-25 şeması: kimlik `{type}_{eventKey}_{uid}`, `refs` yalnızca türün zorunluları (eksik `clubId`
  // etkinlikten), `read` bool; metin / aktör alanı yok (CD-147).
  const notificationDocs = {};
  for (const [id, notification] of entries(raw.notifications)) {
    const required = NOTIFICATION_REFS[notification.type];
    if (!required) throw new Error(`notifications/${id}: bilinmeyen tür ${notification.type}`);
    const given = notification.refs || {};
    const refs = {};
    for (const field of required) {
      refs[field] = field === 'clubId' && !given.clubId && given.eventId ? events[given.eventId]?.clubId : given[field];
    }
    const applicant = refs.applicantId ? membershipDocs[`${refs.clubId}_${refs.applicantId}`] : undefined;
    notificationDocs[notificationDocId(id, { ...notification, refs }, applicant?.priorCount || 0)] = {
      userId: notification.userId,
      type: notification.type,
      refs,
      read: notification.read === true,
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

/** Gönderi görseli yolu: `posts/{postId}/<StoragePaths.newFileName>` (firestore.rules `imageOk` ile aynı desen). */
const POST_IMAGE = /^posts\/([^/]+)\/\d{8}T\d{6}Z_[0-9a-f]{16}\.(?:jpg|png|webp)$/;

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
    // T-19 · Security Rules'un gönderi biçimi (firestore.rules `posts`): tohumlanan belge kurallardan geçen
    // yazımlarla (düzenleme, oy, sabitleme) uyumlu olmalıdır.
    if ((post.title !== null) !== (post.type === 'announcement')) problems.push(`posts/${postId}: başlık yalnızca duyuruda olur`);
    if ((post.poll !== null) !== (post.type === 'poll')) problems.push(`posts/${postId}: anket yalnızca anket gönderisinde olur`);
    if (post.pushSent === true && post.type !== 'announcement') problems.push(`posts/${postId}: pushSent yalnızca duyuruda olur`);
    if (post.poll !== null) {
      const ids = post.poll.options.map((option) => option.id);
      if (ids.length < 2 || ids.length > 4 || ids.some((id, index) => id !== `o${index + 1}`)) {
        problems.push(`posts/${postId}: seçenek kimlikleri o1…oN değil (${ids.join(', ')})`);
      }
    }
    for (const image of post.images) {
      const folder = POST_IMAGE.exec(image.path);
      if (!folder || folder[1] !== postId) problems.push(`posts/${postId}: görsel yolu gönderinin klasöründe değil (${image.path})`);
    }
    // Sabitleme iki yönlüdür: posts.pinned ↔ clubs.pinnedPostId (kulüp başına en çok bir sabit gönderi).
    const pinnedHere = docs.clubs[post.clubId].pinnedPostId === postId;
    if ((post.pinned === true) !== pinnedHere || (pinnedHere && post.isDeleted === true)) {
      problems.push(`posts/${postId}: pinned ile clubs/${post.clubId}.pinnedPostId tutarsız`);
    }
  }
  for (const [clubId, club] of Object.entries(docs.clubs)) {
    if (club.pinnedPostId !== null && docs.posts[club.pinnedPostId]?.clubId !== clubId) {
      problems.push(`clubs/${clubId}: pinnedPostId ${club.pinnedPostId} bu kulübün gönderisi değil`);
    }
  }
  for (const [key, vote] of Object.entries(docs.votes)) {
    const poll = docs.posts[key.slice(0, key.indexOf('/'))]?.poll;
    if (!poll || !poll.options.some((option) => option.id === vote.optionId)) problems.push(`votes/${key}: ankette olmayan seçenek`);
  }
  for (const [id, comment] of Object.entries(docs.comments)) {
    if (docs.posts[comment.postId]?.clubId !== comment.clubId) problems.push(`comments/${id}: clubId gönderinin kulübü değil`);
  }
  // T-25 · bildirim biçimi (firestore.rules `notifications`): kimlik ↔ tür / alıcı, refs zorunluları dolu.
  for (const [id, n] of Object.entries(docs.notifications)) {
    const required = NOTIFICATION_REFS[n.type] || [];
    const keyed = id.startsWith(`${n.type}_`) && id.endsWith(`_${n.userId}`)
      && EVENT_KEY.test(id.slice(n.type.length + 1, id.length - n.userId.length - 1));
    const sequence = n.refs.applicantId ? docs.memberships[`${n.refs.clubId}_${n.refs.applicantId}`]?.priorCount || 0 : 0;
    const exact = { event_reminder: true, announcement: true, event_cancelled: true, application_received: true }[n.type];
    const idOk = exact ? id === notificationDocId(id, n, sequence) : keyed;
    if (!idOk) problems.push(`notifications/${id}: kimlik {type}_{eventKey}_{userId} değil`);
    if (Object.keys(n.refs).join(',') !== required.join(',') || required.some((f) => typeof n.refs[f] !== 'string' || !n.refs[f])) {
      problems.push(`notifications/${id}: refs türün zorunlularıyla tutarsız`);
    }
    if (typeof n.read !== 'boolean') problems.push(`notifications/${id}: read bool değil`);
  }
  for (const [id, saved] of Object.entries(docs.savedPosts)) {
    if (id !== `${saved.userId}_${saved.postId}` || docs.posts[saved.postId]?.clubId !== saved.clubId) {
      problems.push(`savedPosts/${id}: kimlik ya da clubId tutarsız`);
    }
  }
  for (const [id, rsvp] of Object.entries(docs.rsvps)) {
    if (!TICKET_CODE.test(rsvp.ticketCode || '')) problems.push(`rsvps/${id}: ticketCode biçimi geçersiz`);
    // T-22 · Rules'un katılım biçimi (firestore.rules `rsvps`): kimlik `{eventId}_{userId}`, kulüp etkinliğin
    // kulübü; bekleyen kaydın sırası `waitlistAt`'tadır; yoklaması alınmış kayıt `scannedAt` + `scannedBy` taşır.
    if (id !== `${rsvp.eventId}_${rsvp.userId}` || docs.events[rsvp.eventId]?.clubId !== rsvp.clubId) {
      problems.push(`rsvps/${id}: kimlik ya da clubId tutarsız`);
    }
    if (rsvp.status === 'waitlist' && rsvp.waitlistAt === null) problems.push(`rsvps/${id}: bekleyen kaydın waitlistAt'i yok`);
    if ((rsvp.status === 'attended') !== (rsvp.scannedAt !== null && rsvp.scannedBy !== null)) {
      problems.push(`rsvps/${id}: yoklama alanları durumla tutarsız`);
    }
  }
  for (const [eventId, event] of Object.entries(docs.events)) {
    // Rules sayaç dalı: kayıtlı kontenjanı aşamaz; yalnızca yayındaki / iptal edilmiş etkinlikte kayıt olur.
    if (event.capacity !== null && event.goingCount > event.capacity) {
      problems.push(`events/${eventId}: goingCount ${event.goingCount} > capacity ${event.capacity}`);
    }
    if (event.status === 'draft' && event.goingCount + event.waitlistCount > 0) problems.push(`events/${eventId}: taslakta kayıt var`);
    if (event.coverSeed !== `event-${eventId}`) problems.push(`events/${eventId}: coverSeed event-${eventId} değil`);
  }
  for (const [id, report] of Object.entries(docs.reports)) {
    if (id !== `${report.reporterId}_${report.targetType}_${report.targetId}`) problems.push(`reports/${id}: kimlik biçimi geçersiz`);
  }
  for (const [id, counter] of Object.entries(docs.announcementCounters)) {
    if (counter.count > announcementDailyLimit) problems.push(`announcementCounters/${id}: count ${counter.count} > ${announcementDailyLimit}`);
    // Belge kimliği `{clubId}_{yyyyMMdd}`, `day` alanı aynı günün `yyyy-MM-dd` yazımıdır (Rules ikisini de denetler).
    if (id !== `${counter.clubId}_${String(counter.day).replace(/-/g, '')}`) problems.push(`announcementCounters/${id}: kimlik ile day tutarsız`);
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

/**
 * `demo-data.json` + T-25 ek bildirimleri (`demo-notifications.json`; README madde 4: demo veri salt okunur,
 * yeni senaryo ayrı dosyada). Kimlik çakışması hatadır. Saf fonksiyon: [raw] değişmez.
 */
function withExtras(raw, extras) {
  const notifications = { ...raw.notifications };
  for (const [id, notification] of Object.entries(extras.notifications || {})) {
    if (notifications[id]) throw new Error(`demo-notifications.json: ${id} demo-data.json'da zaten var`);
    notifications[id] = notification;
  }
  return { ...raw, notifications };
}

// ── T-28 · supportTickets (demo-support.json) ───────────────────────────────────────────────────

/** `supportTickets/{ticketNo}` deseni (Dart `FirestoreIds.supportTicketNoPattern`; firestore.rules aynı). */
const SUPPORT_TICKET_NO = /^GU-[A-HJ-NP-Z2-9]{6}$/;
/** `SupportSubject` (5) ve `TicketStatus` (2) JSON değerleri. */
const SUPPORT_SUBJECTS = Object.freeze(['bug', 'suggestion', 'account', 'club', 'other']);
const TICKET_STATUSES = Object.freeze(['open', 'closed']);
/** Destek mesajının üst sınırı (Dart `Limits.supportMessageMax`). */
const SUPPORT_MESSAGE_MAX = 500;

/**
 * Demo destek talepleri → `supportTickets` belgeleri (`SupportTicketModel.toJson()` + BaseFields). Bu
 * koleksiyon demo-data.json'da yoktur: `COLLECTIONS` (17, Dart DemoDataFixture ile aynı) dışında tutulur.
 * Zamanlar `meta.today` → `now` tam gün kaydırılır; `updatedAt` verilmezse `createdAt`.
 */
function convertSupport(raw, extras, { now }) {
  const shift = dayShiftMs(new Date(raw.meta.today), now);
  const at = (iso) => new Date(new Date(iso).getTime() + shift);
  const docs = {};
  for (const [ticketNo, ticket] of Object.entries(extras.supportTickets || {})) {
    const createdAt = at(ticket.createdAt);
    docs[ticketNo] = {
      ticketNo,
      userId: ticket.userId,
      subject: ticket.subject,
      message: ticket.message,
      attachmentPaths: [],
      status: ticket.status,
      createdAt,
      updatedAt: typeof ticket.updatedAt === 'string' ? at(ticket.updatedAt) : createdAt,
      isDeleted: false,
      deletedAt: null,
      deletedBy: null,
    };
  }
  return docs;
}

/** Destek taleplerinin Rules biçimi (firestore.rules `supportTickets`); sorun listesi döner, boş = tutarlı. */
function validateSupport(tickets, users) {
  const problems = [];
  for (const [id, t] of Object.entries(tickets)) {
    const where = `supportTickets/${id}`;
    if (!SUPPORT_TICKET_NO.test(id) || t.ticketNo !== id) problems.push(`${where}: kimlik talep numarası değil`);
    if (!users[t.userId]) problems.push(`${where}: kullanıcı ${t.userId} demo verisinde yok`);
    if (!SUPPORT_SUBJECTS.includes(t.subject)) problems.push(`${where}: bilinmeyen konu ${t.subject}`);
    if (!TICKET_STATUSES.includes(t.status)) problems.push(`${where}: bilinmeyen durum ${t.status}`);
    if (typeof t.message !== 'string' || t.message.length === 0 || t.message.length > SUPPORT_MESSAGE_MAX) {
      problems.push(`${where}: mesaj 1 – ${SUPPORT_MESSAGE_MAX} karakter değil`);
    }
    if (!Array.isArray(t.attachmentPaths) || t.attachmentPaths.length > 1) problems.push(`${where}: en çok 1 ek`);
    if (!(t.createdAt instanceof Date) || !(t.updatedAt instanceof Date) || t.updatedAt < t.createdAt) {
      problems.push(`${where}: zaman alanları geçersiz`);
    }
  }
  return problems;
}

// ── T-29 · silinmiş (anonimleştirilmiş) hesap (demo-deleted.json) ───────────────────────────────

/**
 * Hesap silme anonimleştirme literalleri — Dart `Anonymization` (packages/gu_data/lib/src/constants/
 * anonymization.dart) ve firestore.rules hesap silme dalları ile aynı; öz-test Dart kaynağıyla karşılaştırır.
 */
const ANONYMIZATION = Object.freeze({
  deletedUserName: 'Silinmiş kullanıcı',
  deletedUserNameLower: 'silinmiş kullanıcı',
  deletedAvatarSeed: 'deleted',
});

/**
 * Demo silinmiş hesaplar → hesap silme dizisinin SONUÇ belgeleri (`[yol, alanlar]` listesi) + Auth
 * kullanıcıları. Bu belgeler demo-data.json'da yoktur: `COLLECTIONS` (17, Dart DemoDataFixture ile aynı)
 * dışında, kendi sayım satırıyla yazılır. Auth kimliği ve e-postası kalır (Q-11); Firestore'daki e-posta
 * boştur (D-29). Zamanlar `meta.today` → `now` tam gün kaydırılır.
 */
function convertDeleted(raw, extras, { now }) {
  const shift = dayShiftMs(new Date(raw.meta.today), now);
  const at = (iso) => (typeof iso === 'string' ? new Date(new Date(iso).getTime() + shift) : null);
  const base = (createdAt, updatedAt) => ({ createdAt, updatedAt, isDeleted: false, deletedAt: null, deletedBy: null });
  const writes = [];
  const authUsers = [];
  for (const [uid, user] of Object.entries(extras.users || {})) {
    const createdAt = at(user.createdAt);
    const deletedAt = at(user.deletedAt);
    writes.push([
      PATH_OF.users(uid),
      {
        name: ANONYMIZATION.deletedUserName,
        nameLower: ANONYMIZATION.deletedUserNameLower,
        avatarSeed: user.avatarSeed,
        avatarPath: null,
        department: null,
        year: null,
        interests: [],
        bio: '',
        status: 'deleted',
        staff: false,
        profileComplete: true,
        createdAt,
        updatedAt: deletedAt,
        isDeleted: true,
        deletedAt,
        deletedBy: uid,
      },
    ]);
    writes.push([
      PATH_OF.account(uid),
      { email: '', emailLower: '', fcmTokens: [], lastLoginAt: null, suspendReason: null, ...base(createdAt, deletedAt) },
    ]);
    for (const [clubId, membership] of Object.entries(user.memberships || {})) {
      const id = `${clubId}_${uid}`;
      const appliedAt = at(membership.appliedAt);
      writes.push([
        PATH_OF.memberships(id),
        {
          clubId,
          userId: uid,
          status: 'left',
          role: membership.role,
          applicant: { name: ANONYMIZATION.deletedUserName, department: null, year: null, avatarSeed: ANONYMIZATION.deletedAvatarSeed },
          appliedAt,
          decidedAt: at(membership.decidedAt),
          decidedBy: raw.clubs[clubId] ? raw.clubs[clubId].presidentId : null,
          retryAfter: null,
          rejectReason: null,
          rejectNote: null,
          priorCount: 0,
          ...base(appliedAt, deletedAt),
        },
      ]);
      writes.push([PATH_OF.contact(id), { email: '', emailLower: '', note: '', ...base(appliedAt, deletedAt) }]);
    }
    const comments = Object.entries(user.comments || {});
    for (const [postId, post] of Object.entries(user.posts || {})) {
      const createdAt = at(post.createdAt);
      writes.push([
        PATH_OF.posts(postId),
        {
          clubId: post.clubId,
          authorId: uid,
          type: 'post',
          title: null,
          text: post.text,
          images: [],
          poll: null,
          pinned: false,
          pushSent: false,
          likes: [],
          likeCount: 0,
          commentCount: comments.filter(([, c]) => c.postId === postId).length,
          lastCommentRef: null,
          isHidden: false,
          hiddenBy: null,
          hiddenAt: null,
          editedAt: null,
          ...base(createdAt, createdAt),
        },
      ]);
    }
    for (const [commentId, comment] of comments) {
      const createdAt = at(comment.createdAt);
      writes.push([
        PATH_OF.comments(commentId),
        {
          postId: comment.postId,
          clubId: user.posts[comment.postId].clubId,
          authorId: uid,
          text: comment.text,
          isHidden: false,
          hiddenBy: null,
          hiddenAt: null,
          ...base(createdAt, createdAt),
        },
      ]);
    }
    authUsers.push({ uid, email: user.email, displayName: null, emailVerified: true, claims: null });
  }
  return { writes, authUsers };
}

/**
 * Silinmiş hesap belgelerinin tutarlılığı (domain-model §11 alan listesi + Rules hesap silme dalları); sorun
 * listesi döner, boş = tutarlı. [raw] demo verisidir (kimlik çakışması, kulüp varlığı).
 */
function validateDeleted(deleted, raw) {
  const problems = [];
  const docs = Object.fromEntries(deleted.writes);
  for (const [docPath, data] of deleted.writes) {
    const [collection, id] = docPath.split('/');
    if (collection === 'users' && docPath.split('/').length === 2) {
      if (raw.users[id]) problems.push(`${docPath}: demo-data.json'da zaten var`);
      if (data.name !== ANONYMIZATION.deletedUserName || data.nameLower !== ANONYMIZATION.deletedUserNameLower) {
        problems.push(`${docPath}: ad anonim değil`);
      }
      if (data.status !== 'deleted' || data.isDeleted !== true || data.deletedBy !== id) problems.push(`${docPath}: silinmiş değil`);
      if (data.bio !== '' || data.interests.length || data.avatarPath !== null || data.department !== null || data.year !== null) {
        problems.push(`${docPath}: kişisel alan kalmış`);
      }
      const account = docs[PATH_OF.account(id)];
      if (!account || account.email !== '' || account.emailLower !== '' || account.fcmTokens.length) {
        problems.push(`${docPath}: private/account boşaltılmamış`);
      }
    }
    if (collection === 'memberships' && docPath.split('/').length === 2) {
      if (!raw.clubs[data.clubId]) problems.push(`${docPath}: kulüp ${data.clubId} yok`);
      if (data.status === 'active' || data.status === 'pending') problems.push(`${docPath}: üyelik kapanmamış (${data.status})`);
      if (data.applicant.name !== ANONYMIZATION.deletedUserName || data.applicant.avatarSeed !== ANONYMIZATION.deletedAvatarSeed) {
        problems.push(`${docPath}: applicant anonim değil`);
      }
      const contact = docs[PATH_OF.contact(id)];
      if (!contact || contact.email !== '' || contact.note !== '') problems.push(`${docPath}: contact boşaltılmamış`);
    }
    if (collection === 'posts' && !raw.clubs[data.clubId]) problems.push(`${docPath}: kulüp ${data.clubId} yok`);
    if ((collection === 'posts' && raw.posts[id]) || (collection === 'comments' && raw.comments[id])) {
      problems.push(`${docPath}: demo-data.json'da zaten var`);
    }
    if (collection === 'comments' && !docs[PATH_OF.posts(data.postId)]) problems.push(`${docPath}: gönderi ${data.postId} yok`);
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
  dayShiftMs,
  notificationDocId,
  withExtras,
  SUPPORT_TICKET_NO,
  convertSupport,
  validateSupport,
  ANONYMIZATION,
  convertDeleted,
  validateDeleted,
  fileStamp,
  convert,
  expectedCounts,
  validate,
  staticTablesDiff,
};
