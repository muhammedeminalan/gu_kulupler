'use strict';
// Rol × işlem matrisi koşucusu (PLAN §11.6): `expectations/<koleksiyon>.json` → vaka başına bir jest testi.
// Bir dosya = §11.1'in bir satırı. Vaka: { role, op, variant | batch, expect, ref, query?, twin?, group?,
// docPath?, newDocPath?, without?, patch?, unset?, fixtureOptions? }.
//   op      get · list · create · update · softDelete · restore · delete
//   role    contexts.js bağlamı (12 + alt varyantlar; `superadmin`/`otherMgr` takma adları kabul edilir)
//   variant payloads.js yük adı (create/update); softDelete/restore yükleri sabittir
//   batch   payloads.js çok belgeli yazım adı (create/update): yazımlar tek WriteBatch olarak gönderilir
//           (üyelik + contact + sayaç + günlük gibi birlikte geçen işlemler — T-15)
//   expect  allow | deny
//   query   list süzgeçleri; dizgi değerlerde `{uid}` / `{club}` / `{otherClub}` doldurulur
//   twin    false → süzgeçsiz ikiz üretilmez (süzgeçsiz okuması da izinli bağlam: süper admin)
//   docPath / newDocPath   dosyanın hedef yolunu bu vaka için değiştirir (`{uid}` = bağlamın uid'i)
//   without / patch / unset   veri kümesini bu vaka için düzenler (fixtures.js `editDocs`): kurulmayacak
//           belgeler · üzerine yazılacak alanlar · kaldırılacak anahtarlar; yollar `{uid}` taşıyabilir
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
const budget = require('./budget');
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

const isPlainObject = (value) => value !== null && typeof value === 'object' && !Array.isArray(value);

function validateCase(file, c, index) {
  const where_ = `${file} cases[${index}]`;
  resolveName(c.role);
  if (!OPS.includes(c.op)) throw new Error(`${where_}: geçersiz op "${c.op}" (${OPS.join(', ')})`);
  if (!EXPECTS.includes(c.expect)) throw new Error(`${where_}: geçersiz expect "${c.expect}"`);
  const isWrite = c.op === 'create' || c.op === 'update';
  if (isWrite && !c.variant && !c.batch) throw new Error(`${where_}: ${c.op} için variant zorunlu`);
  if (c.variant && c.batch) throw new Error(`${where_}: variant ve batch birlikte verilemez`);
  if (c.batch && !isWrite) throw new Error(`${where_}: batch yalnızca create/update ile kullanılır`);
  if (c.without !== undefined && !Array.isArray(c.without)) throw new Error(`${where_}: without dizi olmalı`);
  for (const key of ['patch', 'unset']) {
    if (c[key] !== undefined && !isPlainObject(c[key])) throw new Error(`${where_}: ${key} nesne olmalı`);
  }
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

/** Süzgeç değerindeki yer tutucuları doldurur (dizgi ve dizgi listesi; diğer tipler olduğu gibi). */
function fillValue(value, ctx) {
  if (typeof value === 'string') return fillPath(value, ctx);
  if (Array.isArray(value)) return value.map((item) => fillValue(item, ctx));
  return value;
}

function listQuery(db, exp, c, ctx) {
  const source = c.group ? collectionGroup(db, exp.group) : collection(db, exp.listPath);
  const spec = c.query || {};
  const constraints = [
    ...(spec.where || []).map(([field, op, value]) => where(field, op, fillValue(value, ctx))),
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
      return getDocs(listQuery(db, exp, c, ctx));
    case 'create':
      if (c.batch) return budget.buildBatch(db, payloads.batchFor(c.batch, ctx)).commit();
      return setDoc(doc(db, fillPath(c.newDocPath || exp.newDocPath, ctx)), payloads.payloadFor(c.variant, ctx));
    case 'update':
      if (c.batch) return budget.buildBatch(db, payloads.batchFor(c.batch, ctx)).commit();
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

/** Vakanın veri kümesi düzenlemesi (`without` / `patch` / `unset`), yol şablonları doldurulmuş olarak. */
function caseEdit(c, ctx) {
  const fillKeys = (object = {}) => Object.fromEntries(Object.entries(object).map(([p, value]) => [fillPath(p, ctx), value]));
  return {
    without: (c.without || []).map((p) => fillPath(p, ctx)),
    patch: fillKeys(c.patch),
    unset: fillKeys(c.unset),
  };
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
  const role = resolveName(c.role);
  const ctx = { role, uid: uidOf(role), club: CLUB, otherClub: OTHER_CLUB };
  if (typeof options.seed === 'function') await options.seed(exp, c);
  else if (options.seed !== false) await seedFixture(exp.fixture || 'base', c.fixtureOptions, caseEdit(c, ctx));
  const request = perform(contextFor(role).firestore(), exp, c, ctx);
  await (c.expect === 'allow' ? assertSucceeds(request) : assertFails(request));
}

/** `query` taşıyan `list` vakalarına süzgeçsiz ret ikizini ekler. */
function expandCases(cases) {
  const out = [];
  for (const c of cases) {
    out.push(c);
    if (c.op === 'list' && c.query && c.twin !== false) {
      out.push({ ...c, query: undefined, expect: 'deny', ref: `${c.ref || ''} · süzgeçsiz ikiz (rules-spec §1.7)`.trim() });
    }
  }
  return out;
}

function caseTitle(c) {
  const filters = () => (c.query.where || []).map(([field, op, value]) => `${field} ${op} ${JSON.stringify(value)}`).join(', ');
  const variant = c.variant || c.batch ? `(${c.variant || c.batch})` : c.op === 'list' ? (c.query ? `(${filters()})` : '(süzgeçsiz)') : '';
  const override = c.op === 'create' ? c.newDocPath : c.docPath;
  const target = override ? ` @ ${override}` : '';
  const former = c.fixtureOptions && c.fixtureOptions.formerStatus ? ` [former: ${c.fixtureOptions.formerStatus}]` : '';
  return `${c.role} · ${c.op}${variant}${target}${former} → ${c.expect}${c.ref ? ` — ${c.ref}` : ''}`;
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
