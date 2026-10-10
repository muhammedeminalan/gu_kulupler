'use strict';
// Erişim çağrısı bütçesi ölçümü (rules-spec §1.8; PLAN §11.3): çok yazımlı batch kurucu, sonucun
// sınıflandırılması ve ölçüm çıktısının JSON olarak yazılması.
//
// Rules bir işlemde 10, bir istekte 20 `get/exists/getAfter` çağrısına izin verir. Sınır aşılınca
// emülatör de `permission-denied` döner; ayrım ileti metnindedir ("evaluation error"). Bütçe testleri
// (`budget/*.test.js`, T-22/T-25/T-29/T-30) parça boyutunu büyüterek `ok` → `evaluation-error`
// eşiğini bulur ve sonucu `budget/<ad>_result.json` dosyasına yazar; `tool/check_rules_parity.js`
// (RP05, RP06) o dosyayı `Limits` ile karşılaştırır.
const fs = require('node:fs');
const path = require('node:path');
const { doc, writeBatch } = require('firebase/firestore');

const BUDGET_DIR = path.resolve(__dirname, '..', 'budget');

/** Sonuç sınıfları. */
const Outcome = Object.freeze({
  ok: 'ok',
  permissionDenied: 'permission-denied',
  evaluationError: 'evaluation-error',
  other: 'other',
});

const BATCH_OPS = Object.freeze(['set', 'update']);

/**
 * Yazım listesinden tek bir `WriteBatch` kurar (commit etmez).
 * @param {import('firebase/firestore').Firestore} db bağlamın Firestore'u
 * @param {{op: 'set'|'update', path: string, data: object}[]} writes
 */
function buildBatch(db, writes) {
  const batch = writeBatch(db);
  for (const write of writes) {
    if (!BATCH_OPS.includes(write.op)) {
      throw new Error(`geçersiz batch işlemi: ${write.op} (yalnızca ${BATCH_OPS.join(', ')}; silme yok — D-10)`);
    }
    const ref = doc(db, write.path);
    if (write.op === 'set') batch.set(ref, write.data);
    else batch.update(ref, write.data);
  }
  return batch;
}

/**
 * Bir isteğin sonucunu sınıflandırır; hata fırlatmaz.
 * @param {Promise<unknown>} request
 * @returns {Promise<{outcome: string, message: string}>}
 */
async function classify(request) {
  try {
    await request;
    return { outcome: Outcome.ok, message: '' };
  } catch (error) {
    const code = String((error && error.code) || '').toLowerCase();
    const message = String((error && error.message) || error);
    const denied = code === 'permission-denied' || /permission[_ -]denied/i.test(message);
    if (!denied) return { outcome: Outcome.other, message };
    return { outcome: /evaluation error/i.test(message) ? Outcome.evaluationError : Outcome.permissionDenied, message };
  }
}

/**
 * Ölçüm sonucunu JSON olarak yazar (commit edilir). Anahtar sırası sabittir: dosya farkı yalnızca
 * ölçüm değişince oluşur.
 * @param {string} fileName `fanout_result.json`
 * @param {object} result ölçüm (`chunkSize` / `chunk` + ölçülen noktalar)
 * @param {string} [dir] hedef dizin (varsayılan `firebase/test/budget`)
 * @returns {string} yazılan dosyanın yolu
 */
function writeResult(fileName, result, dir = BUDGET_DIR) {
  if (!/^[a-z_]+_result\.json$/.test(fileName)) throw new Error(`geçersiz sonuç dosyası adı: ${fileName}`);
  const sorted = Object.fromEntries(Object.entries(result).sort(([a], [b]) => a.localeCompare(b)));
  const target = path.join(dir, fileName);
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(target, JSON.stringify(sorted, null, 2) + '\n');
  return target;
}

module.exports = { BUDGET_DIR, Outcome, buildBatch, classify, writeResult };
