'use strict';
// gu_data Dart sabitlerinin Node tarafındaki okuyucusu — Rules parite denetimlerinin tek kaynağı.
// Kullananlar: tool/check_rules_parity.js (RP01–RP06) ve firebase/test/parity.test.js.
// Dart çalıştırılmaz; sabit bildirimleri kaynak metinden düzenli ifadeyle çıkarılır. Biçim değişirse
// (ör. sabit `static const` olmaktan çıkarsa) okuyucu sessizce boş dönmez, hata fırlatır.
// Bağımlılık yok (yalnızca Node ≥ 18).
const fs = require('fs');
const path = require('path');

const PATHS = Object.freeze({
  limits: 'packages/gu_data/lib/src/constants/limits.dart',
  emailDomainPolicy: 'packages/gu_data/lib/src/constants/email_domain_policy.dart',
  firestoreFields: 'packages/gu_data/lib/src/constants/firestore_fields.dart',
  softDelete: 'packages/gu_data/lib/src/core/soft_delete.dart',
  baseFields: 'packages/gu_data/lib/src/core/base_fields.dart',
  rolePolicy: 'packages/gu_data/lib/src/core/role_policy.dart',
});

/** `Duration(<birim>: n)` birimlerinin saniye karşılığı. */
const DART_UNIT_SECONDS = Object.freeze({ days: 86400, hours: 3600, minutes: 60, seconds: 1, milliseconds: 0.001 });

/** Rules `duration.value(n, '<birim>')` birimlerinin saniye karşılığı. */
const RULES_UNIT_SECONDS = Object.freeze({ w: 604800, d: 86400, h: 3600, m: 60, s: 1, ms: 0.001 });

function read(root, key) {
  const file = path.join(root, PATHS[key]);
  if (!fs.existsSync(file)) throw new Error(`Dart kaynağı yok: ${PATHS[key]}`);
  return fs.readFileSync(file, 'utf8');
}

/** Satır ve blok yorumlarını boşaltır (satır sayısı korunur); dizgi içindeki `//` korunur. */
function stripComments(source) {
  let out = '';
  let i = 0;
  while (i < source.length) {
    const c = source[i];
    const next = source[i + 1];
    if (c === "'" || c === '"') {
      const raw = source[i - 1] === 'r';
      let j = i + 1;
      while (j < source.length && source[j] !== c && source[j] !== '\n') j += !raw && source[j] === '\\' ? 2 : 1;
      out += source.slice(i, j + 1);
      i = j + 1;
    } else if (c === '/' && next === '/') {
      while (i < source.length && source[i] !== '\n') i += 1;
    } else if (c === '/' && next === '*') {
      const end = source.indexOf('*/', i + 2);
      const stop = end < 0 ? source.length : end + 2;
      out += source.slice(i, stop).replace(/[^\n]/g, ' ');
      i = stop;
    } else {
      out += c;
      i += 1;
    }
  }
  return out;
}

const lineOf = (source, index) => source.slice(0, index).split('\n').length;

/** `5 * 1024 * 1024` gibi yalnızca tamsayı çarpımından oluşan ifadeyi hesaplar; değilse `null`. */
function evalIntProduct(expr) {
  const compact = expr.replace(/\s+/g, '');
  if (!/^\d+(\*\d+)*$/.test(compact)) return null;
  return compact.split('*').reduce((acc, part) => acc * Number(part), 1);
}

/**
 * `Limits` sabitleri.
 * @returns {{ints: Record<string, number>, durations: Record<string, number>,
 *   intLists: Record<string, number[]>, strings: Record<string, string>, lines: Record<string, number>}}
 *   `durations` saniye cinsindendir; `strings` ham desen içeriğidir (`r'…'` içi).
 */
function readLimits(root) {
  const source = stripComments(read(root, 'limits'));
  const out = { ints: {}, durations: {}, intLists: {}, strings: {}, lines: {} };
  let m;

  const intRe = /static\s+const\s+int\s+(\w+)\s*=\s*([^;]+);/g;
  while ((m = intRe.exec(source))) {
    const value = evalIntProduct(m[2]);
    if (value === null) throw new Error(`${PATHS.limits}: ${m[1]} tamsayı ifadesi çözülemedi (${m[2].trim()})`);
    out.ints[m[1]] = value;
    out.lines[m[1]] = lineOf(source, m.index);
  }

  const durationRe = /static\s+const\s+Duration\s+(\w+)\s*=\s*Duration\(\s*(\w+)\s*:\s*(\d+)\s*,?\s*\)\s*;/g;
  while ((m = durationRe.exec(source))) {
    const unit = DART_UNIT_SECONDS[m[2]];
    if (unit === undefined) throw new Error(`${PATHS.limits}: ${m[1]} bilinmeyen Duration birimi (${m[2]})`);
    out.durations[m[1]] = Number(m[3]) * unit;
    out.lines[m[1]] = lineOf(source, m.index);
  }

  const listRe = /static\s+const\s+List<int>\s+(\w+)\s*=\s*\[([^\]]*)\]\s*;/g;
  while ((m = listRe.exec(source))) {
    out.intLists[m[1]] = m[2].split(',').map((s) => s.trim()).filter(Boolean).map(Number);
    out.lines[m[1]] = lineOf(source, m.index);
  }

  const stringRe = /static\s+const\s+String\s+(\w+)\s*=\s*r?'((?:[^'\\]|\\.)*)'\s*;/g;
  while ((m = stringRe.exec(source))) {
    out.strings[m[1]] = m[2];
    out.lines[m[1]] = lineOf(source, m.index);
  }

  if (Object.keys(out.ints).length === 0) throw new Error(`${PATHS.limits}: hiç \`static const int\` bulunamadı`);
  return out;
}

/** `EmailDomainPolicy.allowedDomains`. */
function readEmailDomains(root) {
  const source = stripComments(read(root, 'emailDomainPolicy'));
  const m = /allowedDomains\s*=\s*\[([^\]]*)\]/.exec(source);
  const domains = m ? [...m[1].matchAll(/'([^']+)'/g)].map((x) => x[1]) : [];
  if (domains.length === 0) throw new Error(`${PATHS.emailDomainPolicy}: allowedDomains bulunamadı`);
  return domains;
}

/** Dart `RegExp.escape` eşleniği (aynı karakter kümesi). */
function regExpEscape(text) {
  return text.replace(/[\\^$.|?*+()[\]{}]/g, '\\$&');
}

/** `EmailDomainPolicy.rulesRegex()` değeri: `.*@(ogr\.gumushane\.edu\.tr|gumushane\.edu\.tr)`. */
function emailRulesRegex(domains) {
  return `.*@(${domains.map(regExpEscape).join('|')})`;
}

/** Bir desenin Rules KAYNAK metnindeki dizgi içeriği: her ters bölü çiftlenir (`\.` → `\\.`). */
function toRulesLiteral(pattern) {
  return pattern.replace(/\\/g, '\\\\');
}

/** `FirestoreFields` sabitleri: ad → Firestore alan adı. */
function readFirestoreFields(root) {
  const source = stripComments(read(root, 'firestoreFields'));
  const out = {};
  for (const m of source.matchAll(/static\s+const\s+String\s+(\w+)\s*=\s*'([^']+)'\s*;/g)) out[m[1]] = m[2];
  if (Object.keys(out).length === 0) throw new Error(`${PATHS.firestoreFields}: sabit bulunamadı`);
  return out;
}

function fieldNames(root, block, where) {
  const fields = readFirestoreFields(root);
  return [...block.matchAll(/FirestoreFields\.(\w+)/g)].map((m) => {
    if (!(m[1] in fields)) throw new Error(`${where}: FirestoreFields.${m[1]} tanımsız`);
    return fields[m[1]];
  });
}

/** `SoftDelete.affectedKeys` (alan adları). */
function readSoftDeleteKeys(root) {
  const source = stripComments(read(root, 'softDelete'));
  const m = /affectedKeys\s*=\s*\{([^}]*)\}/.exec(source);
  if (!m) throw new Error(`${PATHS.softDelete}: affectedKeys bulunamadı`);
  const keys = fieldNames(root, m[1], PATHS.softDelete);
  if (keys.length === 0) throw new Error(`${PATHS.softDelete}: affectedKeys boş`);
  return keys;
}

/**
 * `BaseFieldsPayload.create()` anahtarları: `required` her zaman yazılır, `optional` yalnızca değer
 * verilince (`FirestoreFields.createdBy: ?createdBy`).
 */
function readBaseCreateKeys(root) {
  const source = stripComments(read(root, 'baseFields'));
  const m = /Map<String,\s*Object\?>\s+create\s*\([\s\S]*?return\s*\{([\s\S]*?)\};/.exec(source);
  if (!m) throw new Error(`${PATHS.baseFields}: BaseFieldsPayload.create bulunamadı`);
  const fields = readFirestoreFields(root);
  const out = { required: [], optional: [] };
  for (const entry of m[1].matchAll(/FirestoreFields\.(\w+)\s*:\s*(\?)?/g)) {
    (entry[2] ? out.optional : out.required).push(fields[entry[1]]);
  }
  return out;
}

/**
 * `RolePolicy._holdersOf` tablosu: izin → izni olan sütunlar (domain-model §3 sırasıyla
 * student, member, board, president, advisor, superadmin).
 * @returns {Record<string, string[]>}
 */
function readRolePolicy(root) {
  const source = stripComments(read(root, 'rolePolicy'));
  const sets = {};
  for (const m of source.matchAll(/static\s+const\s+Set<_Holder>\s+(_\w+)\s*=\s*\{([^}]*)\}\s*;/g)) {
    sets[m[1]] = [...m[2].matchAll(/_Holder\.(\w+)/g)].map((x) => x[1]);
  }
  const body = /_holdersOf\s*\([^)]*\)\s*=>\s*switch\s*\(\s*permission\s*\)\s*\{([\s\S]*?)\};/.exec(source);
  if (!body) throw new Error(`${PATHS.rolePolicy}: _holdersOf tablosu bulunamadı`);
  const out = {};
  for (const arm of body[1].matchAll(/((?:ClubPermission\.\w+\s*(?:\|\|\s*)?)+)=>\s*(_\w+)/g)) {
    if (!sets[arm[2]]) throw new Error(`${PATHS.rolePolicy}: ${arm[2]} kümesi tanımsız`);
    for (const p of arm[1].matchAll(/ClubPermission\.(\w+)/g)) out[p[1]] = sets[arm[2]];
  }
  if (Object.keys(out).length === 0) throw new Error(`${PATHS.rolePolicy}: _holdersOf kolu bulunamadı`);
  return out;
}

module.exports = {
  PATHS,
  DART_UNIT_SECONDS,
  RULES_UNIT_SECONDS,
  stripComments,
  evalIntProduct,
  readLimits,
  readEmailDomains,
  regExpEscape,
  emailRulesRegex,
  toRulesLiteral,
  readFirestoreFields,
  readSoftDeleteKeys,
  readBaseCreateKeys,
  readRolePolicy,
};
