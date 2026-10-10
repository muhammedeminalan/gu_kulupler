'use strict';
// Firebase emülatörlerinin REST uçlarıyla konuşan en küçük istemci (bağımlılık yok: Node ≥ 20 `fetch`).
//
// GÜVENLİK: Bu dosyadaki her istek `http://<emülatör adresi>/…` biçimindedir ve adres yalnızca
// `resolveTarget` korumalarından geçen yerel (loopback) emülatör adresidir. googleapis.com'a ya da
// başka bir makineye istek üreten bir kod yolu yoktur; kimlik bilgisi okunmaz. `Authorization: Bearer
// owner` emülatörün yerel "kuralları atla" jetonudur, gerçek projede hiçbir anlamı yoktur.
// Belge silme çağrısı yoktur (D-10).

/** Emülatörün dinlediği yerel adresler. */
const LOOPBACK_HOSTS = Object.freeze(['127.0.0.1', 'localhost', '[::1]']);

/** Yalnızca-emülatör proje öneki (Firebase "demo project"). */
const DEMO_PREFIX = 'demo-';

const ENV = Object.freeze({
  firestore: 'FIRESTORE_EMULATOR_HOST',
  auth: 'FIREBASE_AUTH_EMULATOR_HOST',
  storage: 'FIREBASE_STORAGE_EMULATOR_HOST',
});
const PROJECT_ENV = Object.freeze(['GCLOUD_PROJECT', 'GOOGLE_CLOUD_PROJECT']);

/** Tek `documents:commit` isteğindeki yazım sayısı (Firestore sınırı 500). */
const COMMIT_CHUNK = 400;
const OWNER = Object.freeze({ Authorization: 'Bearer owner' });

/** Koruma reddi: betik yazmadan durur (çıkış kodu 2). */
class GuardError extends Error {}

function splitHostPort(value) {
  const at = value.lastIndexOf(':');
  const port = Number(value.slice(at + 1));
  if (at <= 0 || !Number.isInteger(port) || port <= 0) return null;
  return { host: value.slice(0, at), port };
}

function loopback(name, value) {
  const parsed = splitHostPort(value);
  if (!parsed) throw new GuardError(`${name}="${value}" host:port biçiminde değil`);
  if (!LOOPBACK_HOSTS.includes(parsed.host)) {
    throw new GuardError(`${name}="${value}" yerel adres değil — tohumlayıcı yalnızca bu makinedeki emülatöre yazar`);
  }
  return `${parsed.host}:${parsed.port}`;
}

/**
 * Hedefi çözer ve korumaları uygular. Geçemeyen her durum `GuardError`'dur; hiçbir istek gönderilmez.
 *  1. `FIRESTORE_EMULATOR_HOST` ve `FIREBASE_AUTH_EMULATOR_HOST` tanımlı olmalı.
 *  2. Adresler yerel (loopback) olmalı.
 *  3. Proje kimliği (`--project` ya da `GCLOUD_PROJECT`) `demo-` ile başlamalı; ikisi verilmişse aynı olmalı.
 * Storage emülatörü isteğe bağlıdır (yoksa görseller yüklenmez).
 * @param {NodeJS.ProcessEnv} env
 * @param {string|null} projectArg `--project` değeri
 * @returns {{projectId: string, firestore: string, auth: string, storage: string|null}}
 */
function resolveTarget(env, projectArg) {
  const missing = [ENV.firestore, ENV.auth].filter((name) => !env[name]);
  if (missing.length) {
    throw new GuardError(
      `${missing.join(' ve ')} tanımlı değil — tohumlayıcı yalnızca emülatöre yazar ` +
        '(firebase emulators:exec --only auth,firestore --project demo-gu-kulupler "node tool/seed/seed_emulator.js")',
    );
  }
  const fromEnv = PROJECT_ENV.map((name) => env[name]).find(Boolean) || null;
  if (projectArg && fromEnv && projectArg !== fromEnv) {
    throw new GuardError(`--project ${projectArg} ile ortamdaki proje (${fromEnv}) farklı`);
  }
  const projectId = projectArg || fromEnv;
  if (!projectId) throw new GuardError('proje kimliği yok: --project demo-gu-kulupler');
  if (!projectId.startsWith(DEMO_PREFIX) || projectId.length === DEMO_PREFIX.length) {
    throw new GuardError(`proje kimliği "${projectId}" ${DEMO_PREFIX} ile başlamıyor — gerçek projeye asla yazılmaz`);
  }
  return {
    projectId,
    firestore: loopback(ENV.firestore, env[ENV.firestore]),
    auth: loopback(ENV.auth, env[ENV.auth]),
    storage: env[ENV.storage] ? loopback(ENV.storage, env[ENV.storage]) : null,
  };
}

async function request(url, { method = 'GET', headers = {}, body } = {}) {
  if (!/^http:\/\/(127\.0\.0\.1|localhost|\[::1\]):\d+\//.test(url)) {
    throw new GuardError(`yerel olmayan adrese istek engellendi: ${url}`);
  }
  let response;
  try {
    response = await fetch(url, { method, headers: { ...OWNER, ...headers }, body });
  } catch (error) {
    throw new Error(`${method} ${url}: bağlantı kurulamadı (${error.cause ? error.cause.code || error.cause.message : error.message})`);
  }
  const text = await response.text();
  return { ok: response.ok, status: response.status, text };
}

async function requestJson(url, options = {}) {
  const hasBody = options.body !== undefined;
  const result = await request(url, {
    ...options,
    headers: { ...(hasBody ? { 'Content-Type': 'application/json' } : {}), ...options.headers },
    body: hasBody ? JSON.stringify(options.body) : undefined,
  });
  let json = null;
  try {
    json = result.text ? JSON.parse(result.text) : null;
  } catch (error) {
    json = null;
  }
  return { ...result, json };
}

function fail(what, result) {
  const detail = result.json && result.json.error ? result.json.error.message : result.text.slice(0, 200);
  return new Error(`${what}: HTTP ${result.status} ${detail}`);
}

/**
 * Hedefin gerçekten emülatör olduğunu doğrular: Auth emülatörünün yalnızca-emülatör yapılandırma ucu
 * ve Firestore emülatörünün kök yanıtı beklenir. Başarısızsa `GuardError`.
 */
async function probe(target) {
  const auth = await requestJson(`http://${target.auth}/emulator/v1/projects/${target.projectId}/config`).catch((e) => ({ ok: false, text: e.message }));
  if (!auth.ok || !auth.json || typeof auth.json !== 'object') {
    throw new GuardError(`Auth emülatörü ${target.auth} adresinde yanıt vermiyor (${auth.status || auth.text})`);
  }
  const firestore = await request(`http://${target.firestore}/`).catch((e) => ({ ok: false, text: e.message }));
  if (!firestore.ok) {
    throw new GuardError(`Firestore emülatörü ${target.firestore} adresinde yanıt vermiyor (${firestore.status || firestore.text})`);
  }
}

// ── Firestore ────────────────────────────────────────────────────────────────────────────────

/** JS değeri → Firestore REST `Value`. `Date` → `timestampValue`; tamsayı → `integerValue`. */
function encodeValue(value) {
  if (value === null) return { nullValue: null };
  if (value === undefined) throw new Error('encodeValue: undefined yazılamaz (null kullan)');
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'number') {
    if (!Number.isFinite(value)) throw new Error(`encodeValue: sonlu olmayan sayı (${value})`);
    return Number.isInteger(value) ? { integerValue: String(value) } : { doubleValue: value };
  }
  if (value instanceof Date) {
    if (Number.isNaN(value.getTime())) throw new Error('encodeValue: geçersiz tarih');
    return { timestampValue: value.toISOString() };
  }
  if (Array.isArray(value)) return { arrayValue: { values: value.map(encodeValue) } };
  if (typeof value === 'object') return { mapValue: { fields: encodeFields(value) } };
  throw new Error(`encodeValue: desteklenmeyen tür (${typeof value})`);
}

function encodeFields(data) {
  return Object.fromEntries(Object.entries(data).map(([key, value]) => [key, encodeValue(value)]));
}

const documentsRoot = (target) => `projects/${target.projectId}/databases/(default)/documents`;

/**
 * Belgeleri yazar (tam üzerine yazma = `set`; aynı kimlikle yeniden koşum aynı sonucu verir).
 * @param {object} target `resolveTarget` çıktısı
 * @param {[string, object][]} writes [belge yolu, veri]
 * @returns {Promise<number>} yazılan belge sayısı
 */
async function writeDocuments(target, writes) {
  const url = `http://${target.firestore}/v1/${documentsRoot(target)}:commit`;
  for (let i = 0; i < writes.length; i += COMMIT_CHUNK) {
    const body = {
      writes: writes.slice(i, i + COMMIT_CHUNK).map(([path, data]) => ({
        update: { name: `${documentsRoot(target)}/${path}`, fields: encodeFields(data) },
      })),
    };
    const result = await requestJson(url, { method: 'POST', body });
    if (!result.ok) throw fail(`Firestore commit (${writes[i][0]} …)`, result);
  }
  return writes.length;
}

/**
 * Bir koleksiyonun (ya da koleksiyon grubunun) belge yollarını listeler.
 * @param {string} collectionId `users`, `private`, `votes` …
 * @param {boolean} allDescendants `true` = koleksiyon grubu
 * @returns {Promise<string[]>} `documents/` sonrası yollar
 */
async function listDocumentPaths(target, collectionId, allDescendants) {
  const url = `http://${target.firestore}/v1/${documentsRoot(target)}:runQuery`;
  const body = {
    structuredQuery: { from: [{ collectionId, allDescendants }], select: { fields: [{ fieldPath: '__name__' }] } },
  };
  const result = await requestJson(url, { method: 'POST', body });
  if (!result.ok || !Array.isArray(result.json)) throw fail(`Firestore runQuery (${collectionId})`, result);
  const prefix = `${documentsRoot(target)}/`;
  return result.json.filter((row) => row.document).map((row) => row.document.name.slice(prefix.length));
}

// ── Auth ─────────────────────────────────────────────────────────────────────────────────────

const authBase = (target) => `http://${target.auth}/identitytoolkit.googleapis.com/v1/projects/${target.projectId}`;

/**
 * Auth emülatör kullanıcısını oluşturur; kimlik zaten varsa günceller (yeniden koşum).
 * @param {{uid: string, email: string, displayName: string, emailVerified: boolean, claims: object|null}} user
 * @param {string} password yerel demo parolası (demo-data.json#meta.demoPassword); günlüğe yazılmaz
 */
async function upsertAuthUser(target, user, password) {
  const account = {
    localId: user.uid,
    email: user.email,
    password,
    displayName: user.displayName,
    emailVerified: user.emailVerified,
  };
  const created = await requestJson(`${authBase(target)}/accounts`, { method: 'POST', body: account });
  const duplicate = !created.ok && /DUPLICATE_LOCAL_ID|EMAIL_EXISTS/.test(created.text);
  if (!created.ok && !duplicate) throw fail(`Auth kullanıcı oluşturma (${user.uid})`, created);
  if (duplicate || user.claims) {
    const update = { ...account, ...(user.claims ? { customAttributes: JSON.stringify(user.claims) } : {}) };
    const updated = await requestJson(`${authBase(target)}/accounts:update`, { method: 'POST', body: update });
    if (!updated.ok) throw fail(`Auth kullanıcı güncelleme (${user.uid})`, updated);
  }
}

/** Auth emülatöründeki kullanıcılar: [{localId, email, emailVerified, customAttributes}]. */
async function listAuthUsers(target) {
  const out = [];
  let pageToken = '';
  do {
    const query = `maxResults=1000${pageToken ? `&nextPageToken=${encodeURIComponent(pageToken)}` : ''}`;
    const result = await requestJson(`${authBase(target)}/accounts:batchGet?${query}`);
    if (!result.ok) throw fail('Auth kullanıcı listesi', result);
    out.push(...((result.json && result.json.users) || []));
    pageToken = (result.json && result.json.nextPageToken) || '';
  } while (pageToken);
  return out;
}

// ── Storage ──────────────────────────────────────────────────────────────────────────────────

/**
 * Dosyayı Storage emülatörüne yükler (GCS JSON API, çok parçalı: metadata + içerik).
 * @param {string} bucket
 * @param {{path: string, contentType: string, metadata: Record<string, string>}} file
 * @param {Buffer} bytes
 */
async function uploadFile(target, bucket, file, bytes) {
  const boundary = `gu-seed-${file.path.length}-${bytes.length}`;
  const head = JSON.stringify({ name: file.path, contentType: file.contentType, metadata: file.metadata });
  const body = Buffer.concat([
    Buffer.from(`--${boundary}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n${head}\r\n`),
    Buffer.from(`--${boundary}\r\nContent-Type: ${file.contentType}\r\n\r\n`),
    bytes,
    Buffer.from(`\r\n--${boundary}--\r\n`),
  ]);
  const url = `http://${target.storage}/upload/storage/v1/b/${encodeURIComponent(bucket)}/o?uploadType=multipart&name=${encodeURIComponent(file.path)}`;
  const result = await request(url, {
    method: 'POST',
    headers: { 'Content-Type': `multipart/related; boundary=${boundary}` },
    body,
  });
  if (!result.ok) throw new Error(`Storage yükleme (${file.path}): HTTP ${result.status} ${result.text.slice(0, 200)}`);
}

/** Storage emülatöründe `prefix` ile başlayan nesne adları. */
async function listFiles(target, bucket, prefix) {
  const out = [];
  let pageToken = '';
  do {
    const query = `prefix=${encodeURIComponent(prefix)}&maxResults=1000${pageToken ? `&pageToken=${encodeURIComponent(pageToken)}` : ''}`;
    const result = await requestJson(`http://${target.storage}/storage/v1/b/${encodeURIComponent(bucket)}/o?${query}`);
    if (!result.ok) throw fail('Storage nesne listesi', result);
    out.push(...((result.json && result.json.items) || []).map((item) => item.name));
    pageToken = (result.json && result.json.nextPageToken) || '';
  } while (pageToken);
  return out;
}

module.exports = {
  GuardError,
  ENV,
  resolveTarget,
  probe,
  encodeValue,
  writeDocuments,
  listDocumentPaths,
  upsertAuthUser,
  listAuthUsers,
  uploadFile,
  listFiles,
};
