'use strict';
// tool/seed/seed_emulator.js öz-testi: korumalar (yalnızca yerel emülatör + demo- proje) ve PLAN §9.12
// dönüşüm kuralları. Emülatör gerekmez: koruma vakaları yazmadan önce reddedilir, dönüşüm saftır.
// Beklenen değerler packages/gu_data/test/models/demo_data_parse_test.dart ile aynı kaynaktandır (§9.11).
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { TOOL_DIR } = require('./helpers');
const {
  ANONYMIZATION, COLLECTIONS, PATH_OF, SUPPORT_TICKET_NO, convert, convertDeleted, convertManagement, convertSupport, dayShiftMs,
  expectedCounts, staticTablesDiff, validate, validateDeleted, validateManagement, validateSupport, withExtras,
} = require('../seed/lib/convert');
const { GuardError, encodeValue, resolveTarget } = require('../seed/lib/emulator_rest');
const { placeholderPng } = require('../seed/placeholder_png');

const SCRIPT = path.join(TOOL_DIR, 'seed', 'seed_emulator.js');
const REPO = path.resolve(TOOL_DIR, '..');
const raw = JSON.parse(fs.readFileSync(path.join(TOOL_DIR, 'seed', 'demo-data.json'), 'utf8'));
const TODAY = new Date(raw.meta.today);
const DAY_MS = 24 * 60 * 60 * 1000;

let counter = 0;
const sequentialHex = () => (counter++).toString(16).padStart(16, '0');
const atToday = convert(raw, { now: TODAY, randomHex: sequentialHex });

/** Betiği verilen ortamla (emülatör değişkenleri temizlenmiş) çalıştırır. */
function run(args, env) {
  const clean = { ...process.env };
  for (const name of ['FIRESTORE_EMULATOR_HOST', 'FIREBASE_AUTH_EMULATOR_HOST', 'FIREBASE_STORAGE_EMULATOR_HOST', 'GCLOUD_PROJECT', 'GOOGLE_CLOUD_PROJECT']) {
    delete clean[name]; // ortam değişkeni (nesne anahtarı) temizliği; Firestore silmesi değildir
  }
  const r = spawnSync(process.execPath, [SCRIPT, ...args], { encoding: 'utf8', env: { ...clean, ...env } });
  return { code: r.status, stdout: r.stdout, stderr: r.stderr };
}

const LOCAL = { FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080', FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:9099' };

test('seed · koruma: emülatör değişkenleri yoksa reddeder (çıkış 2, yazım yok)', () => {
  const none = run(['--project', 'demo-gu-kulupler'], {});
  assert.equal(none.code, 2);
  assert.match(none.stderr, /REDDEDİLDİ — FIRESTORE_EMULATOR_HOST ve FIREBASE_AUTH_EMULATOR_HOST tanımlı değil/);
  const onlyFirestore = run(['--project', 'demo-gu-kulupler'], { FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080' });
  assert.equal(onlyFirestore.code, 2);
  assert.match(onlyFirestore.stderr, /FIREBASE_AUTH_EMULATOR_HOST tanımlı değil/);
});

test('seed · koruma: proje kimliği demo- ile başlamıyorsa reddeder (gerçek gu-kulupler dahil)', () => {
  for (const project of ['gu-kulupler', 'demo-', 'my-demo-project']) {
    const r = run(['--project', project], LOCAL);
    assert.equal(r.code, 2, project);
    assert.match(r.stderr, /REDDEDİLDİ — proje kimliği ".*" demo- ile başlamıyor/);
  }
  const fromEnv = run([], { ...LOCAL, GCLOUD_PROJECT: 'gu-kulupler' });
  assert.equal(fromEnv.code, 2);
  const mismatch = run(['--project', 'demo-gu-kulupler'], { ...LOCAL, GCLOUD_PROJECT: 'demo-baska' });
  assert.equal(mismatch.code, 2);
  assert.match(mismatch.stderr, /farklı/);
  const missing = run([], LOCAL);
  assert.equal(missing.code, 2);
  assert.match(missing.stderr, /proje kimliği yok/);
});

test('seed · koruma: yerel olmayan emülatör adresini ve yanıt vermeyen hedefi reddeder', () => {
  const remote = run(['--project', 'demo-gu-kulupler'], { ...LOCAL, FIRESTORE_EMULATOR_HOST: 'firestore.googleapis.com:443' });
  assert.equal(remote.code, 2);
  assert.match(remote.stderr, /yerel adres değil/);
  assert.throws(() => resolveTarget({ ...LOCAL, FIREBASE_AUTH_EMULATOR_HOST: '10.0.0.5:9099' }, 'demo-x'), GuardError);
  assert.throws(() => resolveTarget({ ...LOCAL, FIREBASE_STORAGE_EMULATOR_HOST: 'example.com:9199' }, 'demo-x'), GuardError);
  // 127.0.0.1:1 — dinleyen yok: emülatör yoklaması başarısız → yazmadan reddeder
  const dead = run(['--project', 'demo-gu-kulupler'], { FIRESTORE_EMULATOR_HOST: '127.0.0.1:1', FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:1' });
  assert.equal(dead.code, 2);
  assert.match(dead.stderr, /REDDEDİLDİ — Auth emülatörü 127\.0\.0\.1:1 adresinde yanıt vermiyor/);
  assert.deepEqual(resolveTarget({ ...LOCAL, GCLOUD_PROJECT: 'demo-gu-kulupler' }, null), {
    projectId: 'demo-gu-kulupler', firestore: '127.0.0.1:8080', auth: '127.0.0.1:9099', storage: null,
  });
});

test('seed · --dry-run ağa çıkmadan sayıları basar; bilinmeyen argüman kullanım hatasıdır', () => {
  const dry = run(['--dry-run', '--now', raw.meta.today], {});
  assert.equal(dry.code, 0, dry.stderr);
  assert.match(dry.stdout, /kuru koşum \(yazılmadı\)/);
  assert.match(dry.stdout, /^\s+rsvps\s+944$/m);
  // T-25: demo-notifications.json'daki 5 ek tür birleştirilir (40 + 5).
  assert.match(dry.stdout, /^\s+notifications\s+45$/m);
  // T-28: demo-support.json'daki 5 destek talebi (COLLECTIONS dışında, kendi satırı).
  assert.match(dry.stdout, /^\s+supportTickets\s+5$/m);
  // T-29: demo-deleted.json'daki silinmiş hesap (6 belge; Auth kimliği kalır — Q-11).
  assert.match(dry.stdout, /^\s+deleted \(T-29\)\s+6$/m);
  // T-30: demo-management.json'daki yönetici geçmişi (2 karar × 3 belge + rol günlüğü + 2 yan sayaç belgesi).
  assert.match(dry.stdout, /^\s+management \(T-30\)\s+9$/m);
  assert.match(dry.stdout, /^\s+auth\s+227$/m);
  assert.equal(dry.stdout.includes(raw.meta.demoPassword), false, 'parola çıktıya yazılmamalı');
  assert.equal(run(['--sil'], {}).code, 2);
  assert.equal(run(['--now', 'dün'], {}).code, 2);
});

test('seed · dönüşüm sayıları demo-data.json ve PLAN §9.11 ile eşit', () => {
  const produced = Object.fromEntries(COLLECTIONS.map((name) => [name, Object.keys(atToday.docs[name]).length]));
  assert.deepEqual(produced, expectedCounts(raw));
  assert.deepEqual(produced, {
    users: 226, account: 226, blocks: 1, clubs: 14, memberships: 515, contact: 515, posts: 36, votes: 250,
    comments: 41, events: 22, rsvps: 944, notifications: 40, reports: 11, activity: 222, settings: 226,
    savedPosts: 2, announcementCounters: 1,
  });
  assert.deepEqual(Object.keys(atToday.docs), COLLECTIONS);
  assert.deepEqual(validate(atToday.docs, { announcementDailyLimit: 2 }), []);
  assert.deepEqual(staticTablesDiff(raw, fs.readFileSync(path.join(REPO, 'packages/gu_data/lib/src/constants/static_tables.dart'), 'utf8')), []);
});

test('seed · §9.12 kuralları: kullanıcı, kulüp, üyelik', () => {
  const { docs, authUsers } = atToday;
  assert.equal(docs.users.u_ayse.nameLower, 'ayşe demir');
  assert.equal(docs.users.u_ayse.avatarPath, null);
  assert.equal('global' in docs.users.u_admin, false);
  assert.equal('email' in docs.users.u_ayse, false, 'e-posta users belgesine yazılmaz (D-29)');
  const suspended = Object.entries(docs.users).filter(([, u]) => u.status === 'suspended');
  assert.deepEqual(suspended.map(([uid]) => uid), ['u_suspended', 'u007']);
  // Askı gerekçesi herkese açık `users` belgesinde değil `private/account`'tadır (CD-133).
  assert.ok(Object.values(docs.users).every((u) => !('suspendReason' in u)));
  for (const [uid] of suspended) assert.equal(docs.account[uid].suspendReason, 'Topluluk kurallarının ihlali.');
  assert.deepEqual(docs.account.u_ayse, {
    email: 'ayse.demir@ogr.gumushane.edu.tr', emailLower: 'ayse.demir@ogr.gumushane.edu.tr',
    createdAt: new Date(raw.users.u_ayse.createdAt), updatedAt: new Date(raw.users.u_ayse.createdAt),
    isDeleted: false, deletedAt: null, deletedBy: null, fcmTokens: [], lastLoginAt: null, suspendReason: null,
  });
  assert.deepEqual(Object.keys(docs.blocks), ['u_mehmet_u042']);

  assert.equal(authUsers.length, 226);
  assert.ok(authUsers.every((u) => u.emailVerified === true && !('password' in u)));
  assert.deepEqual(authUsers.filter((u) => u.claims).map((u) => [u.uid, u.claims]), [['u_admin', { superadmin: true }]]);

  assert.equal(raw.clubs.c01.memberCount, 188);
  assert.equal(docs.clubs.c01.memberCount, 80);
  assert.equal(docs.clubs.c03.memberCount, 20);
  assert.equal(docs.clubs.c02.nameLower, 'girişimcilik ve inovasyon kulübü');
  assert.deepEqual(docs.clubs.c01.advisor, { name: 'Zeynep Arslan', title: 'Dr. Öğr. Üyesi', userId: 'u_zeynep' });
  assert.equal(docs.clubs.c01.pinnedPostId, 'p01');
  assert.equal(Object.values(docs.clubs).filter((c) => c.pinnedPostId !== null).length, 8);
  assert.equal(docs.clubs.c01.createdBy, 'u_admin');
  // Sayaç işaretçisi kulüp belgesinde yok (W-64, T-30): yan belge yalnızca yönetici Tx'inde yazılır.
  assert.equal('lastMembershipRef' in docs.clubs.c01, false);

  const membership = docs.memberships.c01_u_p_c01;
  assert.equal('stale' in membership, false);
  assert.deepEqual(membership.applicant, { name: raw.users.u_p_c01.name, department: raw.users.u_p_c01.department, year: raw.users.u_p_c01.year, avatarSeed: 'u_p_c01' });
  assert.equal(membership.rejectNote, null);
  assert.equal(docs.contact.c01_u_p_c01.email, raw.users.u_p_c01.email);
  // Başvuru notu yalnızca `private/contact`'ta durur; üyelik belgesi (üye listesi) not taşımaz (CD-137).
  assert.equal(raw.memberships.c06_u_mehmet.note, 'Gitar çalıyorum, jam seanslarına katılmak istiyorum.');
  assert.equal(docs.contact.c06_u_mehmet.note, raw.memberships.c06_u_mehmet.note);
  assert.equal(docs.contact.c01_u_p_c01.note, '');
  assert.ok(Object.values(docs.memberships).every((m) => !('note' in m)));
  assert.equal(Object.values(docs.contact).filter((c) => c.note !== '').length, 25);
});

test('seed · §9.12 kuralları: gönderi, oy, etkinlik, şikayet, sayaç, zaman', () => {
  const { docs, images } = atToday;
  const p01 = docs.posts.p01;
  assert.equal(p01.likeCount, new Set(raw.posts.p01.likes).size);
  assert.ok(raw.posts.p01.likes.length > p01.likeCount, 'demo beğenileri tekrar içerir');
  assert.equal('commentIds' in p01 || 'hidden' in p01 || 'deleted' in p01 || 'id' in p01, false);
  assert.equal(p01.isHidden, false);
  assert.equal(p01.isDeleted, false);
  assert.match(docs.posts.p02.images[0].path, /^posts\/p02\/20260930T050000Z_[0-9a-f]{16}\.png$/);
  assert.notEqual(docs.posts.p02.images[0].path, docs.posts.p02.images[1].path);
  assert.deepEqual([docs.posts.p02.images[0].w, docs.posts.p02.images[0].h], [1200, 900]);
  assert.equal(images.length, 15);
  assert.deepEqual(images.filter((i) => i.path.startsWith('posts/p02/')).map((i) => i.clubId), ['c01', 'c01']);

  const pollPost = Object.entries(raw.posts).find(([, p]) => p.poll);
  const poll = docs.posts[pollPost[0]].poll;
  assert.equal('votes' in poll.options[0], false);
  assert.ok(poll.endsAt instanceof Date);
  const voteId = Object.keys(docs.votes).find((id) => id.startsWith(`${pollPost[0]}/`));
  assert.equal(docs.votes[voteId].createdAt.getTime(), new Date(pollPost[1].createdAt).getTime() + 60 * 60 * 1000);
  assert.equal(PATH_OF.votes('p04/u156'), 'posts/p04/votes/u156');
  assert.equal(PATH_OF.account('u_ayse'), 'users/u_ayse/private/account');
  assert.equal(PATH_OF.contact('c01_u_p_c01'), 'memberships/c01_u_p_c01/private/contact');

  assert.equal(docs.comments.cm01.clubId, 'c01');
  const counts = (id) => [docs.events[id].goingCount, docs.events[id].waitlistCount, docs.events[id].attendedCount];
  assert.deepEqual(counts('e03'), [30, 4, 0]);
  assert.equal(docs.events.e09.goingCount, 64);
  assert.deepEqual([docs.events.e19.goingCount, docs.events.e19.attendedCount], [38, 34]);
  const draft = Object.values(docs.events).find((e) => e.status === 'draft');
  assert.equal(draft.publishedAt, null);
  assert.equal(docs.events.e01.publishedAt.getTime(), docs.events.e01.createdAt.getTime());
  const scanned = Object.values(docs.rsvps).filter((r) => r.scannedAt !== null);
  assert.equal(scanned.length, 105);
  assert.ok(scanned.every((r) => r.scannedBy === raw.clubs[r.clubId].presidentId));

  assert.deepEqual(Object.keys(docs.reports).filter((id) => id.endsWith('_post_p17')), ['u051_post_p17', 'u052_post_p17', 'u053_post_p17']);
  assert.equal(docs.reports.u051_post_p17.targetClubId, raw.posts.p17.clubId);
  // T-25 şeması: kimlik {type}_{eventKey}_{userId} (hatırlatıcı event_reminder_{eventId}_{uid}), refs yalnızca
  // türün zorunluları (eksik clubId etkinlikten), read bool; `id` alanı yok.
  const n001 = docs.notifications.system_seedn001000000000000_u_ayse;
  assert.deepEqual(n001.refs, { textKey: 'welcome' });
  assert.equal('id' in n001, false);
  assert.ok(docs.notifications.event_reminder_e01_u_mehmet);
  assert.deepEqual(docs.notifications.event_new_seedn002000000000000_u_ayse.refs, { clubId: 'c01', eventId: 'e01' });
  assert.ok(Object.values(docs.notifications).every((n) => typeof n.read === 'boolean'));
  assert.deepEqual(Object.keys(Object.values(docs.activity)[0]).sort(), ['actorId', 'clubId', 'createdAt', 'kind', 'refs']);
  assert.deepEqual(Object.keys(docs.savedPosts), ['u_mehmet_p01', 'u_mehmet_p21']);

  // meta.today = 2026-10-07T21:00Z = Istanbul 2026-10-08 00:00 → sayaç günü bugüne kaydırılır
  assert.deepEqual(docs.announcementCounters, {
    c01_20261008: { clubId: 'c01', day: '2026-10-08', count: 1, lastPostRef: null, updatedAt: TODAY },
  });
  const later = new Date(TODAY.getTime() + 3 * DAY_MS - 1);
  const shifted = convert(raw, { now: later, randomHex: sequentialHex }).docs;
  assert.deepEqual(Object.keys(shifted.announcementCounters), ['c01_20261010']);

  // zaman kuralı: meta.today gününden now'ın Istanbul gününe TAM gün kayması (saat korunur); 10 Ekim
  // 23:59:59.999 → 2 gün. *_rel_days hiçbir belgede yok
  assert.equal(docs.events.e01.startsAt.toISOString(), '2026-10-09T15:00:00.000Z');
  assert.equal(dayShiftMs(TODAY, later), 2 * DAY_MS);
  assert.equal(dayShiftMs(TODAY, new Date(TODAY.getTime() + 3 * DAY_MS)), 3 * DAY_MS);
  assert.equal(shifted.events.e01.startsAt.getTime(), docs.events.e01.startsAt.getTime() + 2 * DAY_MS);
  assert.equal(shifted.notifications.event_reminder_e01_u_mehmet.createdAt.getTime(),
    docs.notifications.event_reminder_e01_u_mehmet.createdAt.getTime() + 2 * DAY_MS);
  assert.equal(docs.events.e01.updatedAt.getTime(), docs.events.e01.createdAt.getTime());
  const leaked = COLLECTIONS.flatMap((name) => Object.entries(docs[name]).filter(([, d]) => JSON.stringify(d).includes('_rel_days')).map(([id]) => `${name}/${id}`));
  assert.deepEqual(leaked, []);
});

test('seed · validate tutarsız veriyi yakalar (betik yazmadan durur)', () => {
  const broken = structuredClone(atToday.docs);
  broken.clubs.c01.memberCount += 1;
  broken.events.e03.goingCount -= 1;
  broken.rsvps[Object.keys(broken.rsvps)[0]].ticketCode = 'GU-0000-IIII';
  broken.memberships.c02_u_p_c02.role = 'board';
  broken.announcementCounters.c01_20261008.count = 3;
  const problems = validate(broken, { announcementDailyLimit: 2 });
  assert.equal(problems.length, 5, problems.join('\n'));
  assert.match(problems.join('\n'), /clubs\/c01: memberCount 81 ≠ 80/);
  assert.match(problems.join('\n'), /clubs\/c02: presidentId u_p_c02 için aktif başkan üyeliği yok/);
  assert.match(problems.join('\n'), /events\/e03: goingCount 29 ≠ 30/);
  assert.match(problems.join('\n'), /ticketCode biçimi geçersiz/);
  assert.match(problems.join('\n'), /count 3 > 2/);

  // T-19 · içerik değişmezleri (Security Rules'un gönderi / oy / yorum / kayıt / sayaç biçimi)
  assert.deepEqual(validate(atToday.docs, { announcementDailyLimit: 2 }), []);
  const content = structuredClone(atToday.docs);
  content.posts.p02.title = 'Gönderide başlık olmaz';
  content.posts.p04.poll.options[1].id = 'x2';
  content.posts.p06.images[0].path = content.posts.p02.images[0].path;
  content.posts.p03.pinned = true;
  content.clubs.c02.pinnedPostId = 'p01';
  content.votes[Object.keys(content.votes).find((key) => key.startsWith('p09/'))].optionId = 'o4';
  content.comments.cm01.clubId = 'c02';
  content.savedPosts.u_mehmet_p01.clubId = 'c02';
  content.announcementCounters.c01_20261008.day = '2026-10-09';
  const contentProblems = validate(content, { announcementDailyLimit: 2 }).join('\n');
  for (const expected of [
    /posts\/p02: başlık yalnızca duyuruda olur/,
    /posts\/p04: seçenek kimlikleri o1…oN değil/,
    /posts\/p06: görsel yolu gönderinin klasöründe değil/,
    /posts\/p03: pinned ile clubs\/c01\.pinnedPostId tutarsız/,
    /clubs\/c02: pinnedPostId p01 bu kulübün gönderisi değil/,
    /votes\/p09\/[^:]+: ankette olmayan seçenek/,
    /comments\/cm01: clubId gönderinin kulübü değil/,
    /savedPosts\/u_mehmet_p01: kimlik ya da clubId tutarsız/,
    /announcementCounters\/c01_20261008: kimlik ile day tutarsız/,
  ]) {
    assert.match(contentProblems, expected);
  }

  // T-22 · etkinlik / katılım değişmezleri (Security Rules'un `events` / `rsvps` biçimi)
  const events = structuredClone(atToday.docs);
  events.events.e09.goingCount = 65;
  events.events.e09.capacity = 64;
  events.rsvps.e08_u_mehmet.waitlistAt = null;
  events.rsvps.e01_u_mehmet.clubId = 'c02';
  events.rsvps[Object.keys(events.rsvps).find((id) => events.rsvps[id].status === 'attended')].scannedBy = null;
  events.events.e22.coverSeed = 'event-e01';
  const eventProblems = validate(events, { announcementDailyLimit: 2 }).join('\n');
  for (const expected of [
    /events\/e09: goingCount 65 > capacity 64/,
    /rsvps\/e08_u_mehmet: bekleyen kaydın waitlistAt'i yok/,
    /rsvps\/e01_u_mehmet: kimlik ya da clubId tutarsız/,
    /rsvps\/[^:]+: yoklama alanları durumla tutarsız/,
    /events\/e22: coverSeed event-e22 değil/,
  ]) {
    assert.match(eventProblems, expected);
  }
  // Prototipte anı olmayan bekleyen kayıt oluşturulduğu anda girmiş sayılır; diğerleri kendi anını taşır.
  assert.equal(atToday.docs.rsvps.e08_u_mehmet.waitlistAt.getTime(), atToday.docs.rsvps.e08_u_mehmet.createdAt.getTime());
  assert.ok(Object.values(atToday.docs.rsvps).every((r) => (r.status === 'waitlist') === (r.waitlistAt !== null)));
  assert.ok(Object.values(atToday.docs.events).every((e) => !('lastRsvpRef' in e)));
  assert.deepEqual(staticTablesDiff({ ...raw, places: raw.places.slice(1) }, fs.readFileSync(path.join(REPO, 'packages/gu_data/lib/src/constants/static_tables.dart'), 'utf8')), ['places: StaticTables (10) ≠ demo-data.json (9)']);
});

test('seed · yardımcılar: Firestore değer kodlaması, yer tutucu PNG (trLower: seed_tr_lower.test.js)', () => {
  assert.deepEqual(encodeValue({ a: 1, b: 1.5, c: 'x', d: null, e: true, f: [new Date('2026-10-08T00:00:00.000Z')], g: { h: [] } }), {
    mapValue: {
      fields: {
        a: { integerValue: '1' }, b: { doubleValue: 1.5 }, c: { stringValue: 'x' }, d: { nullValue: null }, e: { booleanValue: true },
        f: { arrayValue: { values: [{ timestampValue: '2026-10-08T00:00:00.000Z' }] } },
        g: { mapValue: { fields: { h: { arrayValue: { values: [] } } } } },
      },
    },
  });
  assert.throws(() => encodeValue({ a: undefined }), /undefined/);
  const png = placeholderPng('p02-img1');
  assert.equal(png.subarray(0, 8).toString('hex'), '89504e470d0a1a0a');
  assert.deepEqual([png.readUInt32BE(16), png.readUInt32BE(20)], [1200, 900]);
  assert.deepEqual(placeholderPng('p02-img1'), png);
  assert.notDeepEqual(placeholderPng('p02-img2'), png);
  assert.ok(png.length < 5 * 1024);
});

test('seed · T-25 ek bildirimler: 13 türün hepsi, okunmuş ve okunmamış; kimlik çakışması hata', () => {
  const extras = JSON.parse(fs.readFileSync(path.join(TOOL_DIR, 'seed', 'demo-notifications.json'), 'utf8'));
  const merged = withExtras(raw, extras);
  const { docs } = convert(merged, { now: TODAY, randomHex: sequentialHex });
  assert.equal(Object.keys(docs.notifications).length, expectedCounts(merged).notifications);
  assert.deepEqual(validate(docs, { announcementDailyLimit: 2 }), []);
  const types = new Set(Object.values(docs.notifications).map((n) => n.type));
  assert.equal(types.size, 13);
  assert.ok(Object.values(docs.notifications).some((n) => n.read) && Object.values(docs.notifications).some((n) => !n.read));
  assert.deepEqual(docs.notifications.role_changed_seedn102000000000000_u_elif?.refs, { clubId: 'c01', role: 'board' });
  assert.throws(() => withExtras(raw, { notifications: { n001: raw.notifications.n001 } }), /zaten var/);
  assert.equal(Object.keys(raw.notifications).length, 40, 'demo-data.json değişmez');

  const broken = structuredClone(docs);
  broken.notifications['event_new_kisaanahtar_u_ayse'] = { ...Object.values(docs.notifications)[1] };
  broken.notifications.system_seedn001000000000000_u_ayse.refs = { textKey: 'welcome', clubId: 'c01' };
  const problems = validate(broken, { announcementDailyLimit: 2 });
  assert.equal(problems.length, 2, problems.join('\n'));
});

test('seed · T-28 destek talepleri: numara = kimlik, durum karışık, kullanıcılar demo verisinde; validate bozuğu yakalar', () => {
  const extras = JSON.parse(fs.readFileSync(path.join(TOOL_DIR, 'seed', 'demo-support.json'), 'utf8'));
  const tickets = convertSupport(raw, extras, { now: TODAY });
  assert.equal(Object.keys(tickets).length, 5);
  assert.deepEqual(validateSupport(tickets, raw.users), []);
  for (const [id, t] of Object.entries(tickets)) {
    assert.match(id, SUPPORT_TICKET_NO);
    assert.equal(t.ticketNo, id);
    assert.deepEqual(t.attachmentPaths, []);
    assert.equal(t.isDeleted, false);
  }
  const statuses = new Set(Object.values(tickets).map((t) => t.status));
  assert.deepEqual([...statuses].sort(), ['closed', 'open']);
  // Kapalı talebin updatedAt'i createdAt'ten sonradır; zamanlar meta.today → now tam gün kayar.
  assert.ok(tickets['GU-H2W9TB'].updatedAt > tickets['GU-H2W9TB'].createdAt);
  const shifted = convertSupport(raw, extras, { now: new Date(TODAY.getTime() + 3 * DAY_MS) });
  assert.equal(shifted['GU-4825KM'].createdAt.getTime(), tickets['GU-4825KM'].createdAt.getTime() + 3 * DAY_MS);

  const broken = structuredClone(tickets);
  broken['GU-4825KM'].status = 'pending';
  broken['GU-7KD3MP'].message = 'x'.repeat(501);
  broken['GU-ZP5R8C'].userId = 'u_yok';
  broken['GU-I01OAB'] = { ...broken['GU-Q6V4NE'], ticketNo: 'GU-I01OAB' };
  const problems = validateSupport(broken, raw.users);
  assert.equal(problems.length, 4, problems.join('\n'));
});

test('seed · T-29 silinmiş hesap: alanlar anonim (Dart Anonymization ile aynı), üyelik left + contact boş, eski '
  + 'gönderi / yorum kalır, Auth kimliği kalır; validate bozuğu yakalar', () => {
  const extras = JSON.parse(fs.readFileSync(path.join(TOOL_DIR, 'seed', 'demo-deleted.json'), 'utf8'));
  const deleted = convertDeleted(raw, extras, { now: TODAY });
  assert.deepEqual(validateDeleted(deleted, raw), []);
  const docs = Object.fromEntries(deleted.writes);
  assert.deepEqual(Object.keys(docs), [
    'users/u_deleted',
    'users/u_deleted/private/account',
    'memberships/c01_u_deleted',
    'memberships/c01_u_deleted/private/contact',
    'posts/p_del01',
    'comments/cm_del01',
  ]);
  const user = docs['users/u_deleted'];
  assert.equal(user.name, ANONYMIZATION.deletedUserName);
  assert.equal(user.status, 'deleted');
  assert.equal(user.isDeleted, true);
  assert.equal(user.deletedBy, 'u_deleted');
  assert.equal(docs['users/u_deleted/private/account'].email, '');
  assert.equal(docs['memberships/c01_u_deleted'].status, 'left');
  assert.equal(docs['posts/p_del01'].authorId, 'u_deleted');
  assert.equal(docs['posts/p_del01'].commentCount, 1);
  assert.equal(docs['comments/cm_del01'].clubId, 'c01');
  assert.deepEqual(deleted.authUsers.map((u) => [u.uid, u.email]), [['u_deleted', 'silinen.hesap@ogr.gumushane.edu.tr']]);
  // Literaller Dart sabitleriyle (ve dolayısıyla Rules'la) aynı.
  const dartSource = fs.readFileSync(path.join(REPO, 'packages/gu_data/lib/src/constants/anonymization.dart'), 'utf8');
  assert.match(dartSource, new RegExp(`deletedUserName = '${ANONYMIZATION.deletedUserName}'`));
  assert.match(dartSource, new RegExp(`_deletedUserNameLower = '${ANONYMIZATION.deletedUserNameLower}'`));
  assert.match(dartSource, new RegExp(`_deletedAvatarSeed = '${ANONYMIZATION.deletedAvatarSeed}'`));

  const broken = structuredClone(deleted);
  const at = (docPath) => broken.writes.find(([p]) => p === docPath)[1];
  at('users/u_deleted').bio = 'Merhaba';
  at('memberships/c01_u_deleted').status = 'active';
  at('memberships/c01_u_deleted/private/contact').note = 'not';
  const problems = validateDeleted(broken, raw);
  assert.equal(problems.length, 3, problems.join('\n'));
});

test('seed · T-30 yönetici geçmişi: ret (retryAfter = karar + 7 gün), geri alınmış onay (pending, günlük kalır), rol '
  + 'günlüğü ve yan sayaç belgeleri FirestoreIds / Rules biçiminde; memberCount değişmez; validate bozuğu yakalar', () => {
  const extras = JSON.parse(fs.readFileSync(path.join(TOOL_DIR, 'seed', 'demo-management.json'), 'utf8'));
  const management = convertManagement(raw, extras, { now: TODAY });
  assert.deepEqual(validateManagement(management, raw), []);
  const docs = Object.fromEntries(management.writes);
  assert.deepEqual(Object.keys(docs), [
    'memberships/c01_u002',
    'memberships/c01_u002/private/contact',
    'activity/c01_u_elif_application_rejected_u002_0',
    'memberships/c01_u003',
    'memberships/c01_u003/private/contact',
    'activity/c01_u_elif_application_approved_u003_0',
    'activity/c01_u_p_c01_role_changed_u_elif_board_0',
    'clubs/c01/private/counter',
    'events/e18/private/counter',
  ]);
  const rejected = docs['memberships/c01_u002'];
  assert.equal(rejected.status, 'rejected');
  assert.equal(rejected.decidedBy, 'u_elif');
  assert.equal(rejected.retryAfter.getTime() - rejected.decidedAt.getTime(), 7 * DAY_MS);
  assert.equal(docs['memberships/c01_u003'].status, 'pending');
  assert.equal(docs['memberships/c01_u003'].decidedBy, null);
  assert.deepEqual(docs['clubs/c01/private/counter'].lastMembershipRef, 'memberships/c01_u154');
  assert.deepEqual(Object.keys(docs['events/e18/private/counter']).sort(), ['clubId', 'lastRsvpRef', 'updatedAt']);
  // Sayaçlar tutarlı: yeni üyelikler sayılmaz (reddedilen / bekleyen), kulüp belgesi yazılmaz.
  assert.equal(management.writes.some(([p]) => /^clubs\/[^/]+$/.test(p)), false);
  assert.equal(atToday.docs.clubs.c01.memberCount, Object.values(atToday.docs.memberships)
    .filter((m) => m.clubId === 'c01' && m.status === 'active' && m.role !== 'advisor').length);
  // Kimlik biçimi Dart FirestoreIds ile aynı; süre ve not sınırı Limits ile aynı.
  const ids = fs.readFileSync(path.join(REPO, 'packages/gu_data/lib/src/constants/firestore_ids.dart'), 'utf8');
  assert.match(ids, /static String managerActivity\(/);
  assert.match(ids, /_roleChanged = 'role_changed'/);
  const limits = fs.readFileSync(path.join(REPO, 'packages/gu_data/lib/src/constants/limits.dart'), 'utf8');
  assert.match(limits, /reapplyCooldown = Duration\(days: 7\)/);
  assert.match(limits, /rejectNoteMax = 200;/);

  const broken = structuredClone(management);
  const at = (docPath) => broken.writes.find(([p]) => p === docPath)[1];
  at('memberships/c01_u002').decidedBy = 'u_mehmet';
  at('memberships/c01_u003').decidedBy = 'u_elif';
  at('clubs/c01/private/counter').lastMembershipRef = 'memberships/c02_u_elif';
  const problems = validateManagement(broken, raw);
  assert.equal(problems.length, 3, problems.join('\n'));
});
