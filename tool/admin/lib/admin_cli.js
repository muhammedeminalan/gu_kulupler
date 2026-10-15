'use strict';
/**
 * tool/admin betiklerinin ortak SAF yardımcıları (T-37; sözleşme docs/plans/T-37.md §4 e). `firebase-admin`'i
 * YÜKLEMEZ: betik dışı testler (`node --test tool/test/admin_*.test.js`) bu modülü içe aktarır, betiği çalıştırmaz.
 *
 * Kalıp `set_superadmin.js` ile aynıdır: kuru çalıştırma varsayılan (yalnızca plan basılır), `--yes` uygular;
 * gerçek projede TTY'de proje kimliği yazılarak onaylanır; `--emulator --project demo-…` yerel emülatöre yazar;
 * servis hesabı anahtarı REPO DIŞINDA durur (D-36). Hard delete yok (D-10): planlar yalnızca `set` / `update` üretir.
 */
const fs = require('fs');
const path = require('path');

/** Repo kökü (anahtar yolu denetimi). */
const REPO = path.resolve(__dirname, '..', '..', '..');

/** Firestore batch sınırı (`Limits.batchMaxWrites`). */
const BATCH_MAX_WRITES = 450;

/** Sunucu zamanı nöbetçisi (betik `FieldValue.serverTimestamp()`'a çevirir). */
const SERVER_TIME = Object.freeze({ $serverTimestamp: true });

/** Sayaç deltası nöbetçisi (betik `FieldValue.increment(n)`'e çevirir). */
const increment = (n) => Object.freeze({ $increment: n });

/** Emülatör varsayılan adresleri (`firebase.json`). */
const EMULATOR_HOSTS = Object.freeze({ FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080', FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:9099' });

class UsageError extends Error {}

/**
 * Argümanları çözer. `spec.values` değer alan bayraklar, `spec.flags` mantıksal bayraklar; bilinmeyen argüman,
 * değersiz değer bayrağı ve tekrarlanan bayrak `UsageError`'dır.
 * @returns {Record<string, string|boolean|null>} bayrak adı (`--` olmadan, camelCase) → değer
 */
function parseArgs(argv, spec) {
  const camel = (flag) => flag.replace(/^--/, '').replace(/-([a-z])/g, (_, c) => c.toUpperCase());
  const out = {};
  for (const flag of spec.values) out[camel(flag)] = null;
  for (const flag of spec.flags) out[camel(flag)] = false;
  const seen = new Set();
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (seen.has(arg)) throw new UsageError(`${arg} iki kez verildi`);
    seen.add(arg);
    if (spec.values.includes(arg)) {
      const value = argv[i + 1];
      if (value === undefined || value.startsWith('--')) throw new UsageError(`${arg} değer ister`);
      out[camel(arg)] = value;
      i += 1;
    } else if (spec.flags.includes(arg)) {
      out[camel(arg)] = true;
    } else {
      throw new UsageError(`bilinmeyen argüman: ${arg}`);
    }
  }
  return out;
}

/**
 * Hedef: emülatör (`--emulator`; proje kimliği `demo-` ile başlamalı, adresler yerel) ya da gerçek proje
 * (anahtar repo dışında, var olan geçerli JSON; `--project` verildiyse anahtardaki projeyle aynı).
 * @param {{emulator: boolean, project: string|null, key: string|null}} options
 * @param {Record<string, string|undefined>} env süreç ortamı (okunur; değiştirilmez)
 * @param {{repo?: string, readFile?: (p: string) => string, exists?: (p: string) => boolean}} [io]
 * @returns {{emulator: boolean, projectId: string, env: Record<string, string>, keyPath?: string, key?: object}}
 */
function resolveTarget(options, env, io = {}) {
  const repo = io.repo || REPO;
  const exists = io.exists || fs.existsSync;
  const readFile = io.readFile || ((p) => fs.readFileSync(p, 'utf8'));
  if (options.emulator) {
    const projectId = options.project;
    if (!projectId || !projectId.startsWith('demo-')) {
      throw new UsageError('--emulator için --project demo-… gerekli (ör. demo-gu-kulupler); gerçek proje kimliği emülatörde kullanılmaz');
    }
    const hosts = {};
    for (const [name, fallback] of Object.entries(EMULATOR_HOSTS)) {
      const host = env[name] || fallback;
      if (!/^(127\.0\.0\.1|localhost|\[::1\]):\d+$/.test(host)) throw new UsageError(`${name} yerel değil: ${host}`);
      hosts[name] = host;
    }
    return { emulator: true, projectId, env: hosts };
  }
  const keyPath = options.key || env.GOOGLE_APPLICATION_CREDENTIALS;
  if (!keyPath) throw new UsageError('servis hesabı anahtarı gerekli: --key <yol> ya da GOOGLE_APPLICATION_CREDENTIALS (anahtar repo DIŞINDA durmalı)');
  const abs = path.resolve(keyPath);
  const rel = path.relative(repo, abs);
  if (!rel.startsWith('..') && !path.isAbsolute(rel)) throw new UsageError(`anahtar repo içinde: ${rel}. Repo dışına taşı (D-36); asla commit edilmez`);
  if (!exists(abs)) throw new UsageError(`anahtar dosyası yok: ${abs}`);
  let key;
  try {
    key = JSON.parse(readFile(abs));
  } catch (e) {
    throw new UsageError('anahtar dosyası geçerli JSON değil');
  }
  if (options.project && key.project_id && options.project !== key.project_id) {
    throw new UsageError(`--project (${options.project}) anahtardaki proje (${key.project_id}) ile uyuşmuyor`);
  }
  const projectId = options.project || key.project_id;
  if (!projectId) throw new UsageError('proje kimliği yok (--project ya da anahtardaki project_id)');
  return { emulator: false, projectId, env: {}, keyPath: abs, key };
}

/**
 * Uygulama izni: kuru çalıştırmada (`--yes` yok) `dry`; gerçek projede TTY yoksa `noTty`; aksi halde `ask`
 * (betik proje kimliğini yazdırıp [confirmationMatches] ile karşılaştırır); emülatörde `apply`.
 */
function applyMode({ yes, emulator, isTty }) {
  if (!yes) return 'dry';
  if (emulator) return 'apply';
  return isTty ? 'ask' : 'noTty';
}

/** Gerçek projede yazılan yanıt proje kimliğinin kendisi mi (boşluk kırpılır, büyük-küçük harf duyarlı). */
const confirmationMatches = (answer, projectId) => typeof answer === 'string' && answer.trim() === projectId;

/**
 * Bölünmez yazım gruplarını (sayaç + asıl yazım aynı grupta) en çok [max] yazımlık batch'lere paketler; tek grup
 * sınırı aşarsa hata. Sıra korunur.
 * @param {Array<Array<{op: string, path: string, data: object}>>} units
 */
function packUnits(units, max = BATCH_MAX_WRITES) {
  const batches = [];
  let current = [];
  for (const unit of units) {
    if (unit.length === 0) continue;
    if (unit.length > max) throw new Error(`tek işlem ${unit.length} yazım: batch sınırı ${max}`);
    if (current.length + unit.length > max) {
      batches.push(current);
      current = [];
    }
    current.push(...unit);
  }
  if (current.length > 0) batches.push(current);
  return batches;
}

/** Nöbetçileri Admin SDK değerlerine çevirir (`fieldValue` = `admin.firestore.FieldValue`). */
function materialize(value, fieldValue) {
  if (value === SERVER_TIME || (value && value.$serverTimestamp === true)) return fieldValue.serverTimestamp();
  if (value && typeof value === 'object' && Object.keys(value).length === 1 && typeof value.$increment === 'number') {
    return fieldValue.increment(value.$increment);
  }
  if (Array.isArray(value)) return value.map((inner) => materialize(inner, fieldValue));
  if (value && typeof value === 'object' && !(value instanceof Date)) {
    return Object.fromEntries(Object.entries(value).map(([k, inner]) => [k, materialize(inner, fieldValue)]));
  }
  return value;
}

/** Planın insan okunur özeti (kuru çalıştırma çıktısı). */
function describeWrites(writes) {
  const show = (value) => JSON.stringify(value, (_k, v) => {
    if (v && v.$serverTimestamp === true) return '<sunucu zamanı>';
    if (v && typeof v.$increment === 'number') return `<${v.$increment > 0 ? '+' : ''}${v.$increment}>`;
    return v;
  });
  return writes.map((w) => `  ${w.op.padEnd(6)} ${w.path}  ${show(w.data)}`).join('\n');
}

/** Tek yol parçası olabilen kimlik (boş değil, `/` yok). */
const isValidId = (id) => typeof id === 'string' && id.length > 0 && !id.includes('/');

module.exports = {
  BATCH_MAX_WRITES,
  EMULATOR_HOSTS,
  REPO,
  SERVER_TIME,
  UsageError,
  applyMode,
  confirmationMatches,
  describeWrites,
  increment,
  isValidId,
  materialize,
  packUnits,
  parseArgs,
  resolveTarget,
};
