#!/usr/bin/env node
'use strict';
/**
 * Demo veri tohumlayıcısı — tool/seed/demo-data.json → YEREL Firebase emülatörü (Auth + Firestore
 * [+ Storage]). Dönüşüm kuralları: docs/PLAN.md §9.12 (tool/seed/lib/convert.js).
 *
 *   firebase emulators:exec --only auth,firestore --project demo-gu-kulupler "node tool/seed/seed_emulator.js --check"
 *   firebase emulators:start --only auth,firestore,storage --project demo-gu-kulupler      # ayrı terminal
 *   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
 *   FIREBASE_STORAGE_EMULATOR_HOST=127.0.0.1:9199 node tool/seed/seed_emulator.js --project demo-gu-kulupler
 *
 * Seçenekler:
 *   --project <id>   proje kimliği (`demo-` ile başlamalı; emulators:exec GCLOUD_PROJECT verir)
 *   --check          yazdıktan sonra emülatördeki sayıları demo-data.json ile karşılaştırır (fark = çıkış 1)
 *   --now <ISO>      "şimdi" (varsayılan: çalıştırma anı); her an `ISO + (now − meta.today)` olur
 *   --bucket <ad>    Storage kovası (varsayılan `<proje>.firebasestorage.app`)
 *   --dry-run        yalnızca dönüştürür, doğrular ve sayıları basar; ağa çıkmaz
 *
 * Korumalar (geçemeyen koşum HİÇBİR ŞEY yazmadan çıkış kodu 2 ile durur):
 *   - FIRESTORE_EMULATOR_HOST ve FIREBASE_AUTH_EMULATOR_HOST tanımlı ve yerel (127.0.0.1 / localhost) olmalı;
 *   - proje kimliği `demo-` ile başlamalı (gerçek `gu-kulupler` projesi reddedilir);
 *   - hedefin emülatör olduğu yazmadan önce yoklanır.
 * Tüm istekler emülatörün yerel adresine gider; kimlik bilgisi ve servis hesabı kullanılmaz.
 * Hard delete yok (D-10): betik hiçbir belgeyi, kullanıcıyı ya da dosyayı silmez; yazımlar üzerine yazar.
 * Temiz başlangıç için emülatörü yeniden başlat. `--check` boş emülatör bekler.
 * Çıkış: 0 tamam · 1 doğrulama/sayım hatası · 2 koruma reddi ya da kullanım hatası.
 */
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const { COLLECTIONS, PATH_OF, convert, expectedCounts, staticTablesDiff, validate } = require('./lib/convert');
const rest = require('./lib/emulator_rest');
const { placeholderPng } = require('./placeholder_png');
const dart = require('../lib/dart_sources');

const NAME = 'seed_emulator';
const REPO = path.resolve(__dirname, '..', '..');
const DATA_FILE = path.join(__dirname, 'demo-data.json');
const STATIC_TABLES = path.join(REPO, 'packages/gu_data/lib/src/constants/static_tables.dart');

/** Aynı anda açık Auth / Storage isteği sayısı. */
const CONCURRENCY = 16;
const VALUE_FLAGS = ['--project', '--now', '--bucket'];
const BOOL_FLAGS = ['--check', '--dry-run', '--help', '-h'];

/** `--check` sayımında koleksiyon anahtarı → emülatör sorgusu ve yol süzgeci. */
const COUNT_QUERIES = Object.freeze({
  users: ['users', false, /^users\/[^/]+$/],
  account: ['private', true, /^users\/[^/]+\/private\/account$/],
  blocks: ['blocks', false, /^blocks\/[^/]+$/],
  clubs: ['clubs', false, /^clubs\/[^/]+$/],
  memberships: ['memberships', false, /^memberships\/[^/]+$/],
  contact: ['private', true, /^memberships\/[^/]+\/private\/contact$/],
  posts: ['posts', false, /^posts\/[^/]+$/],
  votes: ['votes', true, /^posts\/[^/]+\/votes\/[^/]+$/],
  comments: ['comments', false, /^comments\/[^/]+$/],
  events: ['events', false, /^events\/[^/]+$/],
  rsvps: ['rsvps', false, /^rsvps\/[^/]+$/],
  notifications: ['notifications', false, /^notifications\/[^/]+$/],
  reports: ['reports', false, /^reports\/[^/]+$/],
  activity: ['activity', false, /^activity\/[^/]+$/],
  settings: ['settings', false, /^settings\/[^/]+$/],
  savedPosts: ['savedPosts', false, /^savedPosts\/[^/]+$/],
  announcementCounters: ['announcementCounters', false, /^announcementCounters\/[^/]+$/],
});

class UsageError extends Error {}

function parseArgs(argv) {
  const out = { project: null, now: null, bucket: null, check: false, dryRun: false, help: false };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (VALUE_FLAGS.includes(arg)) {
      const value = argv[i + 1];
      if (value === undefined || value.startsWith('--')) throw new UsageError(`${arg} değer ister`);
      out[arg.slice(2)] = value;
      i += 1;
    } else if (BOOL_FLAGS.includes(arg)) {
      if (arg === '--check') out.check = true;
      else if (arg === '--dry-run') out.dryRun = true;
      else out.help = true;
    } else {
      throw new UsageError(`bilinmeyen argüman: ${arg}`);
    }
  }
  if (out.now !== null) {
    const now = new Date(out.now);
    if (Number.isNaN(now.getTime())) throw new UsageError(`--now geçersiz tarih: ${out.now}`);
    out.now = now;
  }
  return out;
}

function usage() {
  return fs.readFileSync(__filename, 'utf8').split("\n").slice(3, 26).join('\n').replace(/^ \* ?/gm, '');
}

/** İşleri en çok `limit` eşzamanlı istekle koşar. */
async function pool(items, limit, work) {
  let next = 0;
  const run = async () => {
    while (next < items.length) {
      const index = next;
      next += 1;
      await work(items[index]);
    }
  };
  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, run));
}

/** Demo parolası tek kaynaktan okunur (PLAN §9.12); değeri hiçbir çıktıya yazılmaz. */
function demoPassword(raw) {
  const value = raw.meta && raw.meta.demoPassword;
  if (typeof value !== 'string' || value.length < 8) {
    throw new rest.GuardError('demo-data.json#meta.demoPassword yok ya da 8 karakterden kısa (tool/seed/README.md madde 3)');
  }
  return value;
}

function printCounts(title, rows) {
  console.log(title);
  const width = Math.max(...rows.map(([name]) => name.length));
  for (const [name, ...cells] of rows) console.log(`  ${name.padEnd(width)}  ${cells.join('  ')}`);
}

/** Emülatördeki belge/kullanıcı/dosya sayıları. */
async function countEmulator(target, bucket) {
  const cache = new Map();
  const paths = async (collectionId, group) => {
    const key = `${collectionId}:${group}`;
    if (!cache.has(key)) cache.set(key, await rest.listDocumentPaths(target, collectionId, group));
    return cache.get(key);
  };
  const counts = {};
  for (const name of COLLECTIONS) {
    const [collectionId, group, filter] = COUNT_QUERIES[name];
    counts[name] = (await paths(collectionId, group)).filter((p) => filter.test(p)).length;
  }
  const authUsers = await rest.listAuthUsers(target);
  return {
    counts,
    auth: authUsers.length,
    superAdmins: authUsers.filter((u) => /"superadmin":\s*true/.test(u.customAttributes || '')).length,
    files: target.storage ? (await rest.listFiles(target, bucket, 'posts/')).length : null,
  };
}

async function main(argv) {
  const args = parseArgs(argv);
  if (args.help) {
    console.log(usage());
    return 0;
  }

  const raw = JSON.parse(fs.readFileSync(DATA_FILE, 'utf8'));
  const now = args.now || new Date();
  const { docs, authUsers, images } = convert(raw, { now, randomHex: () => crypto.randomBytes(8).toString('hex') });

  // Yazmadan önce: dönüşüm tutarlı mı, referans listeleri Dart StaticTables ile aynı mı?
  const limits = dart.readLimits(REPO);
  const problems = [
    ...validate(docs, { announcementDailyLimit: limits.ints.announcementDailyLimit }),
    ...staticTablesDiff(raw, fs.readFileSync(STATIC_TABLES, 'utf8')),
  ];
  const expected = expectedCounts(raw);
  for (const name of COLLECTIONS) {
    const produced = Object.keys(docs[name]).length;
    if (produced !== expected[name]) problems.push(`${name}: dönüşüm ${produced} belge üretti, demo-data.json ${expected[name]} bekliyor`);
  }
  if (problems.length) {
    for (const p of problems) console.error(`${NAME}: HATA ${p}`);
    console.error(`${NAME}: ${problems.length} tutarsızlık — hiçbir şey yazılmadı`);
    return 1;
  }

  if (args.dryRun) {
    printCounts(`${NAME}: kuru koşum (yazılmadı) · now=${now.toISOString()}`, [
      ...COLLECTIONS.map((name) => [name, String(expected[name])]),
      ['auth', String(authUsers.length)],
      ['storage', String(images.length)],
    ]);
    return 0;
  }

  const target = rest.resolveTarget(process.env, args.project);
  const password = demoPassword(raw);
  await rest.probe(target);
  const bucket = args.bucket || `${target.projectId}.firebasestorage.app`;
  console.log(`${NAME}: hedef ${target.projectId} · firestore ${target.firestore} · auth ${target.auth} · storage ${target.storage || '—'} · now=${now.toISOString()}`);

  await pool(authUsers, CONCURRENCY, (user) => rest.upsertAuthUser(target, user, password));

  const writes = COLLECTIONS.flatMap((name) => Object.entries(docs[name]).map(([id, data]) => [PATH_OF[name](id), data]));
  await rest.writeDocuments(target, writes);

  if (target.storage) {
    await pool(images, CONCURRENCY, (image) =>
      rest.uploadFile(
        target,
        bucket,
        { path: image.path, contentType: 'image/png', metadata: { clubId: image.clubId } },
        placeholderPng(image.seed, image.width, image.height),
      ),
    );
  } else {
    console.log(`UYARI: ${rest.ENV.storage} tanımlı değil — ${images.length} gönderi görseli yüklenmedi (belgelerdeki yollar yazıldı)`);
  }

  if (!args.check) {
    printCounts(`${NAME}: yazıldı`, [
      ...COLLECTIONS.map((name) => [name, String(expected[name])]),
      ['auth', String(authUsers.length)],
      ['storage', target.storage ? String(images.length) : 'atlandı'],
    ]);
    console.log(`${NAME}: tamam — ${writes.length} belge, ${authUsers.length} Auth kullanıcısı`);
    return 0;
  }

  // --check: emülatörü yeniden say ve demo-data.json ile karşılaştır.
  const found = await countEmulator(target, bucket);
  const superAdmins = authUsers.filter((u) => u.claims && u.claims.superadmin).length;
  const rows = [
    ...COLLECTIONS.map((name) => [name, found.counts[name], expected[name]]),
    ['auth', found.auth, authUsers.length],
    ['auth:superadmin', found.superAdmins, superAdmins],
    ...(found.files === null ? [] : [['storage posts/', found.files, images.length]]),
  ];
  const mark = (actual, wanted) => (actual === wanted ? '✓' : '✗');
  printCounts(`${NAME}: sayım (emülatör / demo-data.json)`, rows.map(([name, a, e]) => [name, String(a).padStart(4), String(e).padStart(4), mark(a, e)]));
  const bad = rows.filter(([, a, e]) => a !== e);
  const total = COLLECTIONS.reduce((sum, name) => sum + found.counts[name], 0);
  if (bad.length) {
    console.error(`${NAME}: SAYIM TUTMUYOR — ${bad.map(([name, a, e]) => `${name} ${a}≠${e}`).join(', ')} (emülatör boş başlatıldı mı?)`);
    return 1;
  }
  console.log(`${NAME}: tamam — ${total} belge, ${found.auth} Auth kullanıcısı; sayılar demo-data.json ile eşit`);
  return 0;
}

if (require.main === module) {
  main(process.argv.slice(2)).then(
    (code) => process.exit(code),
    (error) => {
      const guard = error instanceof rest.GuardError || error instanceof UsageError;
      console.error(`${NAME}: ${guard ? 'REDDEDİLDİ — ' : 'HATA '}${error.message}`);
      process.exit(guard ? 2 : 1);
    },
  );
}

module.exports = { parseArgs, main };
