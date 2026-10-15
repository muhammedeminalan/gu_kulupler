'use strict';
/**
 * tool/admin betiklerinin Admin SDK çalışma zamanı (T-37). `firebase-admin`'i yükler: yalnızca betikler
 * (kullanıcının kendi terminalinde) içe aktarır; testler saf modülleri (`admin_cli.js`, planlayıcılar) sınar.
 */
const readline = require('readline');
const { UsageError, applyMode, confirmationMatches, materialize, resolveTarget } = require('./admin_cli');

/** Betik adıyla hata basar ve çıkar (1 genel · 2 kullanım / koruma · 3 onay yok). */
function fail(name, message, code = 1) {
  console.error(`${name}: ${message}`);
  process.exit(code);
}

/** `firebase-admin`'i yükler; kurulu değilse yol gösterir. */
function loadAdmin(name) {
  try {
    return require('firebase-admin');
  } catch (e) {
    return fail(name, 'firebase-admin kurulu değil: (cd tool/admin && npm ci --ignore-scripts)', 2);
  }
}

/**
 * Hedefi çözer ve uygulamayı başlatır. Emülatörde adres değişkenleri yerel varsayılanlarla kurulur (yalnızca bu
 * süreçte); gerçek projede anahtar repo dışında olmalıdır.
 */
function initApp(name, admin, options) {
  let target;
  try {
    target = resolveTarget(options, process.env);
  } catch (e) {
    if (e instanceof UsageError) fail(name, e.message, 2);
    throw e;
  }
  for (const [key, value] of Object.entries(target.env)) process.env[key] = value;
  if (target.emulator) admin.initializeApp({ projectId: target.projectId });
  else admin.initializeApp({ credential: admin.credential.cert(target.key), projectId: target.projectId });
  return target;
}

/**
 * Uygulama izni: `--yes` yoksa kuru çalıştırma (`false`); gerçek projede yalnızca TTY'de, proje kimliği yazılarak.
 */
async function confirmApply(name, target, yes, message) {
  const mode = applyMode({ yes, emulator: target.emulator, isTty: !!(process.stdin.isTTY && process.stdout.isTTY) });
  if (mode === 'dry') {
    console.log('Kuru çalıştırma: hiçbir şey yazılmadı. Uygulamak için --yes ekle.');
    return false;
  }
  if (mode === 'noTty') fail(name, 'GERÇEK projede yazım yalnızca etkileşimli terminalde yapılır (TTY yok). Komutu kendi terminalinde çalıştır.', 3);
  if (mode === 'apply') return true;
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  const answer = await new Promise((resolve) => rl.question(`${message}\nOnaylamak için proje kimliğini yaz (${target.projectId}): `, resolve));
  rl.close();
  if (!confirmationMatches(answer, target.projectId)) fail(name, 'onay eşleşmedi; işlem iptal', 3);
  return true;
}

/** Plan yazımlarını (nöbetçiler çevrilerek) batch'ler hâlinde, sırayla gönderir. */
async function commitBatches(admin, db, batches) {
  const fieldValue = admin.firestore.FieldValue;
  let written = 0;
  for (const writes of batches) {
    const batch = db.batch();
    for (const write of writes) {
      const ref = db.doc(write.path);
      const data = materialize(write.data, fieldValue);
      if (write.op === 'set') batch.set(ref, data);
      else if (write.op === 'update') batch.update(ref, data);
      else throw new Error(`desteklenmeyen işlem: ${write.op}`);
    }
    await batch.commit();
    written += writes.length;
  }
  return written;
}

/** Firestore değerlerini planlayıcı girdisine çevirir (`Timestamp` → `Date`). */
function plain(value) {
  if (value && typeof value.toDate === 'function') return value.toDate();
  if (Array.isArray(value)) return value.map(plain);
  if (value && typeof value === 'object') return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, plain(v)]));
  return value;
}

/** Ana fonksiyonu koşar; kullanım hatası 2, diğer hata 1 ile çıkar. */
function run(name, main) {
  main().then(() => process.exit(0)).catch((e) => {
    if (e instanceof UsageError) fail(name, e.message, 2);
    fail(name, e && e.message ? e.message : String(e), 1);
  });
}

module.exports = { commitBatches, confirmApply, fail, initApp, loadAdmin, plain, run };
