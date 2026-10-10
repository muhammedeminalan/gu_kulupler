'use strict';
// Rol × işlem matrisi koşucusu (PLAN §11.6): `expectations/<koleksiyon>.json` → vaka başına bir jest testi.
// Bir dosya = §11.1'in bir satırı. Vaka: { role, op, variant, expect, ref, query?, group? }.
//   op      get · list · create · update · softDelete · restore · delete
//   role    contexts.js bağlamı (12 + alt varyantlar; `superadmin`/`otherMgr` takma adları kabul edilir)
//   variant payloads.js yük adı (create/update); softDelete/restore yükleri sabittir
//   expect  allow | deny
// `query` taşıyan her `list` vakası için süzgeçsiz ikizi otomatik üretilir ve `deny` beklenir
// (rules-spec §1.7: Rules filtre değildir).
//
// Ayrıca iki kaynak okuyucu burada durur (deny_all / delete_denied bunlarla koleksiyon listesini türetir):
// `dartCollections()` (FirestoreCollections sabitleri) ve `parseMatches()` (Rules `match` yolları).
const fs = require('node:fs');
const path = require('node:path');
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const {
  collection,
  collectionGroup,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  orderBy,
  query,
  setDoc,
  updateDoc,
  where,
} = require('firebase/firestore');
const { CLUB, OTHER_CLUB, contextFor, resolveName, uidOf } = require('./contexts');
const { seedFixture } = require('./fixtures');
const payloads = require('./payloads');

const EXPECTATIONS_DIR = path.resolve(__dirname, '..', 'expectations');
const REPO_ROOT = path.resolve(__dirname, '..', '..', '..');
const COLLECTIONS_DART = path.join(REPO_ROOT, 'packages/gu_data/lib/src/constants/firestore_collections.dart');

const OPS = Object.freeze(['get', 'list', 'create', 'update', 'softDelete', 'restore', 'delete']);
const EXPECTS = Object.freeze(['allow', 'deny']);

/** Beklenti dosyası olmayan JSON'lar (bağlam ve rol tabloları). */
const NON_COLLECTION_FILES = Object.freeze(['roles.json', 'role_policy.json']);

// ── Kaynak okuyucular ────────────────────────────────────────────────────────────────────────

/**
 * `FirestoreCollections` sabitleri (Dart kaynağından): koleksiyon ve alt koleksiyon adları ile sabit
 * belge adları. Adı `Doc` ile biten sabit belge adıdır (`accountDoc`, `contactDoc`), `Sub` ile biten
 * alt koleksiyondur, diğerleri kök koleksiyondur.
 * @returns {{roots: string[], subs: string[], docs: Record<string, string>}}
 */
function dartCollections(file = COLLECTIONS_DART) {
  const source = fs.readFileSync(file, 'utf8');
  const out = { roots: [], subs: [], docs: {} };
  const re = /static\s+const\s+String\s+(\w+)\s*=\s*'([^']+)'\s*;/g;
  let m;
  while ((m = re.exec(source))) {
    const [, name, value] = m;
    if (name.endsWith('Doc')) out.docs[name] = value;
    else if (name.endsWith('Sub')) out.subs.push(value);
    else out.roots.push(value);
  }
  if (out.roots.length === 0) throw new Error(`FirestoreCollections sabiti bulunamadı: ${file}`);
  return out;
}

/** Yorumları ve dizgi içeriklerini boşaltır (uzunluk ve satırlar korunur). */
function stripCommentsAndStrings(text) {
  return text
    .replace(/\/\*[\s\S]*?\*\//g, (s) => s.replace(/[^\n]/g, ' '))
    .replace(/'(?:\\.|[^'\\\n])*'|"(?:\\.|[^"\\\n])*"/g, (s) => s[0] + ' '.repeat(s.length - 2) + s[0])
    .replace(/\/\/[^\n]*/g, (s) => ' '.repeat(s.length));
}

/**
 * Rules kaynağındaki `match` bloklarını iç içe yollarıyla birlikte çıkarır.
 * @param {string} rulesText `firestore.rules` ya da `storage.rules` içeriği
 * @param {string} servicePrefix atılacak servis kökü (`/databases/{database}/documents`, `/b/{bucket}/o`)
 * @returns {{pattern: string, names: string[], recursive: boolean}[]}
 *   `pattern` servis köküne göre tam yol; `names` yolun sabit parçaları (koleksiyon adları);
 *   `recursive` yol `{x=**}` joker parçası taşıyor mu (koleksiyon grubu ya da varsayılan ret).
 */
function parseMatches(rulesText, servicePrefix) {
  const text = stripCommentsAndStrings(rulesText);
  const token = /\bmatch\s+((?:\/(?:[\w.-]+|\{\w+(?:=\*\*)?\}))+)\s*\{|[{}]/g;
  const stack = [];
  const out = [];
  let m;
  while ((m = token.exec(text))) {
    if (m[0] === '}') {
      stack.pop();
      continue;
    }
    if (m[0] === '{') {
      stack.push(null);
      continue;
    }
    stack.push(m[1]);
    const full = stack.filter(Boolean).join('');
    if (full === servicePrefix) continue;
    if (!full.startsWith(servicePrefix + '/')) throw new Error(`servis kökü dışında match: ${full}`);
    const pattern = full.slice(servicePrefix.length);
    const parts = pattern.split('/').filter(Boolean);
    out.push({
      pattern,
      names: parts.filter((part) => !part.startsWith('{')),
      recursive: parts.some((part) => part.includes('=**')),
    });
  }
  if (stack.length !== 0) throw new Error('Rules kaynağında dengesiz süslü parantez');
  return out;
}

const FIRESTORE_PREFIX = '/databases/{database}/documents';
const STORAGE_PREFIX = '/b/{bucket}/o';

// ── Beklenti dosyaları ───────────────────────────────────────────────────────────────────────

function validateCase(file, c, index) {
  const where_ = `${file} cases[${index}]`;
  resolveName(c.role);
  if (!OPS.includes(c.op)) throw new Error(`${where_}: geçersiz op "${c.op}" (${OPS.join(', ')})`);
  if (!EXPECTS.includes(c.expect)) throw new Error(`${where_}: geçersiz expect "${c.expect}"`);
  if ((c.op === 'create' || c.op === 'update') && !c.variant) throw new Error(`${where_}: ${c.op} için variant zorunlu`);
}

/**
 * Bir beklenti dosyasını okur ve doğrular.
 * @param {string} file dosya adı (`posts.json`) ya da mutlak yol
 */
function loadExpectations(file) {
  const full = path.isAbsolute(file) ? file : path.join(EXPECTATIONS_DIR, file);
  const exp = JSON.parse(fs.readFileSync(full, 'utf8'));
  const name = path.basename(full);
  for (const key of ['collection', 'match', 'docPath', 'newDocPath', 'listPath']) {
    if (typeof exp[key] !== 'string' || exp[key].length === 0) throw new Error(`${name}: "${key}" zorunlu`);
  }
  if (!Array.isArray(exp.cases)) throw new Error(`${name}: "cases" dizi olmalı`);
  exp.cases.forEach((c, i) => validateCase(name, c, i));
  return { ...exp, file: name };
}

/** Tüm koleksiyon beklenti dosyaları (§11.1 satır sırasıyla). */
function loadAllExpectations() {
  return fs
    .readdirSync(EXPECTATIONS_DIR)
    .filter((f) => f.endsWith('.json') && !NON_COLLECTION_FILES.includes(f))
    .map(loadExpectations)
    .sort((a, b) => a.row - b.row);
}

// ── Vaka koşucusu ────────────────────────────────────────────────────────────────────────────

/** Yol şablonundaki `{uid}`, `{club}`, `{otherClub}` yer tutucularını doldurur. */
function fillPath(template, ctx) {
  return template.replace(/\{(uid|club|otherClub)\}/g, (_, key) => ctx[key]);
}

function listQuery(db, exp, c) {
  const source = c.group ? collectionGroup(db, exp.group) : collection(db, exp.listPath);
  const spec = c.query || {};
  const constraints = [
    ...(spec.where || []).map(([field, op, value]) => where(field, op, value)),
    ...(spec.orderBy || []).map(([field, direction]) => orderBy(field, direction || 'asc')),
  ];
  return constraints.length ? query(source, ...constraints) : source;
}

/** Vakanın isteğini (henüz beklenmemiş söz olarak) üretir. */
function perform(db, exp, c, ctx) {
  const target = doc(db, fillPath(c.docPath || exp.docPath, ctx));
  switch (c.op) {
    case 'get':
      return getDoc(target);
    case 'list':
      return getDocs(listQuery(db, exp, c));
    case 'create':
      return setDoc(doc(db, fillPath(c.newDocPath || exp.newDocPath, ctx)), payloads.payloadFor(c.variant, ctx));
    case 'update':
      return updateDoc(target, payloads.payloadFor(c.variant, ctx));
    case 'softDelete':
      return updateDoc(target, payloads.softDelete(ctx.uid));
    case 'restore':
      return updateDoc(target, payloads.restore());
    case 'delete':
      // D-10 ret vakası: hard delete yalnızca burada, reddedildiğini kanıtlamak için denenir.
      return deleteDoc(target);
    default:
      throw new Error(`geçersiz op: ${c.op}`);
  }
}

/**
 * Tek vakayı koşar: veri kurulur (kurallar kapalı) → istek bağlamla gönderilir → sonuç beklentiyle
 * karşılaştırılır. `deny` yalnızca `permission-denied` ile sağlanır (başka hata = test hatası).
 * @param {object} exp beklenti dosyası
 * @param {object} c vaka
 * @param {{seed?: false | ((exp: object, c: object) => Promise<unknown>)}} [options]
 *   `seed` verilmezse `exp.fixture` kurulur; işlev verilirse o çağrılır; `false` ise veri kurulmaz
 *   (çağıran kendisi kurmuştur — aynı veri üzerinde art arda vaka).
 */
async function runCase(exp, c, options = {}) {
  if (typeof options.seed === 'function') await options.seed(exp, c);
  else if (options.seed !== false) await seedFixture(exp.fixture || 'base', c.fixtureOptions);
  const role = resolveName(c.role);
  const ctx = { role, uid: uidOf(role), club: CLUB, otherClub: OTHER_CLUB };
  const request = perform(contextFor(role).firestore(), exp, c, ctx);
  await (c.expect === 'allow' ? assertSucceeds(request) : assertFails(request));
}

/** `query` taşıyan `list` vakalarına süzgeçsiz ret ikizini ekler. */
function expandCases(cases) {
  const out = [];
  for (const c of cases) {
    out.push(c);
    if (c.op === 'list' && c.query) {
      out.push({ ...c, query: undefined, expect: 'deny', ref: `${c.ref || ''} · süzgeçsiz ikiz (rules-spec §1.7)`.trim() });
    }
  }
  return out;
}

function caseTitle(c) {
  const variant = c.variant ? `(${c.variant})` : c.op === 'list' ? (c.query ? '(süzgeçli)' : '(süzgeçsiz)') : '';
  return `${c.role} · ${c.op}${variant} → ${c.expect}${c.ref ? ` — ${c.ref}` : ''}`;
}

/** Vakaları jest testlerine çevirir (çağıran `describe` içinde olmalıdır). */
function runCases(exp, cases, options) {
  for (const c of expandCases(cases)) {
    test(caseTitle(c), () => runCase(exp, c, options));
  }
}

/**
 * Bir koleksiyonun beklenti dosyasını koşar (`rules/<koleksiyon>.test.js` tek satırla çağırır).
 * Vakası olmayan dosya hatadır: boş matris sessizce "yeşil" sayılmaz.
 * @param {string} expectationsFile `posts.json`
 */
function runMatrix(expectationsFile, options) {
  const exp = loadExpectations(expectationsFile);
  describe(`${exp.collection} — rol × işlem matrisi (${exp.file})`, () => {
    if (exp.cases.length === 0) {
      test('beklenti dosyası vaka içerir', () => {
        throw new Error(`${exp.file}: cases boş — sahibi task (${exp.owner}) doldurur`);
      });
      return;
    }
    runCases(exp, exp.cases, options);
  });
}

module.exports = {
  OPS,
  FIRESTORE_PREFIX,
  STORAGE_PREFIX,
  dartCollections,
  parseMatches,
  loadExpectations,
  loadAllExpectations,
  fillPath,
  runCase,
  runCases,
  runMatrix,
};
