'use strict';
// T-10 — Storage varsayılan ret (PLAN §11.5): beş yol kökü × her bağlam için okuma, yükleme,
// üzerine yazma/metadata güncelleme ve silme reddedilir. Yollar sahibi task'ta açılır
// (users/ T-14 · clubs/ T-16 · events/ T-22 · posts/ T-21 · support/ T-28); `update` ve `delete`
// her zaman kapalı kalır (D-10: dosya silinmez, üzerine yazılmaz).
//
// T-14 — `users/{uid}/{file}` (avatar): tek dosya okuması doğrulanmış her kullanıcıya açık, klasör
// listesi kapalı; yükleme yalnızca sahibine, kendi klasörüne, StoragePaths.newFileName adıyla,
// jpeg/png/webp (uzantı türle uyumlu) ve Limits.imageMaxBytes altında; üzerine yazma, üst veri
// güncelleme ve silme herkes için ret.
// T-14 güvenlik incelemesi (CD-135 madde 8):
//  - yükleme yalnızca hesabı ETKİN kullanıcıya açıktır (`accountActive()`: `users/{uid}.status ==
//    'active'`, 1 Firestore okuması) — askıdaki / silinmiş hesap ve profil belgesi olmayan oturum
//    yükleyemez; `profileComplete` aranmaz (AUT-05 sırası: createProfile → yama → yükleme);
//  - boş dosya, `contentEncoding` (gzip…), `contentDisposition` (attachment / dosya adı) ve `users/`
//    yolunda özel üst veri reddedilir (D-10: yüklenen dosya sonradan silinemez).
//
// T-16 — `clubs/{clubId}/{file}` (logo / kapak): tek dosya okuması doğrulanmış her kullanıcıya açık
// (CLB-01, CLB-03), klasör listesi kapalı; yükleme, üzerine yazma, üst veri güncelleme ve silme
// herkes için ret — kulübün başkanı ve süper admin dahil (yükleme T-36'da açılır).
//
// T-21 — `posts/{postId}/{file}` (gönderi görseli, CD-39): tek dosya okuması doğrulanmış her kullanıcıya
// açık, klasör listesi kapalı; yükleme yalnızca `metadata.clubId` kulübünün ETKİN yöneticisine (yönetim
// kurulu / başkan — danışman, üye, süper admin ve başka kulübün yöneticisi değil), hesabı etkinken, yeni
// adla; özel üst veri yalnızca `clubId` + `uploaderId` (= oturumdaki uid; + indirme jetonu); klasör adı
// (`postId`) belge kimliği deseninde. Gönderi belgesi aranmaz (K-18: önce görsel).
// Çapraz servis: en çok 2 Firestore belgesi (üretim sınırı — emülatör uygulamaz; yapı testi sayar);
// bu yüzden kulübün askı durumu Storage'da OKUNMAZ (yayını Firestore `clubLive` reddeder).
const fs = require('node:fs');
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { deleteObject, getBytes, getMetadata, listAll, ref, updateMetadata, uploadBytes } = require('firebase/storage');
const { getAdminContext, getTestEnv } = require('../setup/env');
const { rulesPath } = require('../setup/emulator_ports');
const { CONTEXTS, VARIANTS, contextFor, definition, uidOf } = require('../helpers/contexts');
const { buildFixture, editDocs, seedDocs } = require('../helpers/fixtures');
const { STORAGE_PREFIX, parseMatches } = require('../helpers/matrix');

/** Yükleme (`create`) kuralı açılmış yol kökleri. T-14: users/ · T-21: posts/. */
const OPENED = ['users', 'posts'];

/** Tek dosya okuması (`get`) açılmış yol kökleri. T-14: users/ · T-16: clubs/ · T-21: posts/. */
const READABLE = ['users', 'clubs', 'posts'];

/**
 * Çapraz servis yardımcıları → okudukları Firestore belgesi sayısı. Üretimde tek kural değerlendirmesi
 * en çok `MAX_FIRESTORE_DOCS` belgeye erişebilir; emülatör bu sınırı uygulamaz (yapı testi sayar).
 */
const CROSS_SERVICE = { accountActive: 1, isManagerOf: 1 };
const MAX_FIRESTORE_DOCS = 2;

/** PLAN §11.5'in beş yol kökü (StoragePaths ile aynı). */
const ROOTS = ['users', 'clubs', 'events', 'posts', 'support'];

/** `StoragePaths.newFileName` biçiminde iki ad: var olan dosya ve yeni yükleme. */
const EXISTING_FILE = '20261008T201501Z_3f9a1c2b7d4e5f60.png';
const NEW_FILE = '20261008T201502Z_0a1b2c3d4e5f6071.png';

/** En küçük geçerli PNG (1×1). */
const PNG = Uint8Array.from(
  Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==', 'base64'),
);
const IMAGE = { contentType: 'image/png' };

const rulesText = fs.readFileSync(rulesPath('storage'), 'utf8');
const matches = parseMatches(rulesText, STORAGE_PREFIX);

/** Dosyayı kuralları atlayarak yükler (okuma/güncelleme/silme vakalarının hedefi). */
async function seedFile(path) {
  await uploadBytes(ref((await getAdminContext()).storage(), path), PNG, IMAGE);
}

/** Dosya yerinde mi? (kurallar kapalıyken) */
async function fileExists(path) {
  return getMetadata(ref((await getAdminContext()).storage(), path)).then(
    () => true,
    (error) => {
      if (error && error.code === 'storage/object-not-found') return false;
      throw error;
    },
  );
}

describe('storage · test düzeneği', () => {
  const nested = `users/u_duzenek/${EXISTING_FILE}`;

  test('1/2 · iç içe yola dosya kurulur', async () => {
    await seedFile(nested);
    expect(await fileExists(nested)).toBe(true);
  });

  test('2/2 · önceki testin dosyası sonraki teste taşınmaz (her testten önce tam sıfırlama)', async () => {
    expect(await fileExists(nested)).toBe(false);
  });
});

describe('storage · storage.rules yapısı', () => {
  test('beş yol kökü ve varsayılan ret bloğu vardır', () => {
    const roots = matches.filter((m) => !m.recursive).map((m) => m.names.join('/'));
    expect(roots.sort()).toEqual([...ROOTS].sort());
    expect(matches[matches.length - 1].pattern).toBe('/{allPaths=**}');
  });

  test('her yolda `allow update, delete: if false` (D-10, HD22)', () => {
    const denies = rulesText.match(/^\s*allow update, delete: if false;\s*$/gm) || [];
    expect(denies).toHaveLength(ROOTS.length);
  });

  test('açılan her yolun `create` kuralı üzerine yazmayı engeller (`isNewFile()`; `update: false` yetmez)', () => {
    expect(rulesText).toContain('function isNewFile() { return resource == null; }');
    const creates = (rulesText.match(/^\s*allow create:[^;]*;/gm) || []).filter((rule) => !/: if false;$/.test(rule.trim()));
    expect(creates).toHaveLength(OPENED.length);
    for (const rule of creates) expect(rule).toContain('isNewFile()');
  });

  test('açılan her `create` kuralı `imageOk()` ister; `imageOk()` boş dosyayı ve sunum üst verisini reddeder', () => {
    const creates = (rulesText.match(/^\s*allow create:[^;]*;/gm) || []).filter((rule) => !/: if false;$/.test(rule.trim()));
    for (const rule of creates) expect(rule).toContain('imageOk()');
    const body = /function imageOk\(\) \{([^}]*)\}/.exec(rulesText);
    expect(body).not.toBeNull();
    for (const condition of [
      'request.resource.size > 0',
      'request.resource.contentEncoding == null',
      "request.resource.contentEncoding == 'identity'",
      "request.resource.contentDisposition == null || request.resource.contentDisposition == 'inline'",
    ]) {
      expect(body[1]).toContain(condition);
    }
  });

  test('users/ yüklemesi hesabın etkin olduğunu Firestore\'dan okur ve özel üst veri kabul etmez', () => {
    const create = /match \/users\/\{uid\}\/\{file\} \{[^}]*?(allow create:[^;]*;)/.exec(rulesText);
    expect(create).not.toBeNull();
    expect(create[1]).toContain('noCustomMetadata()');
    // Çapraz servis okuması en sonda: önceki koşullar tutmazsa Firestore okunmaz (kısa devre).
    expect(create[1].trim().endsWith('&& accountActive();')).toBe(true);
    expect(rulesText).toContain("firestore.get(/databases/(default)/documents/users/$(request.auth.uid)).data.status == 'active'");
  });

  test('posts/ yüklemesi: kalıp + yalnızca `clubId` / `uploaderId` üst verisi + yönetici ve hesap durumu Firestore\'dan (CD-39)', () => {
    const create = /match \/posts\/\{postId\}\/\{file\} \{[^}]*?(allow create:[^;]*;)/.exec(rulesText);
    expect(create).not.toBeNull();
    for (const condition of ['signedInVerified()', 'isNewFile()', 'imageOk()', 'fileNameOk(file)', 'clubMetadataOnly()']) {
      expect(create[1]).toContain(condition);
    }
    // Özel üst veri beklenen tek yol: `noCustomMetadata()` burada çağrılmaz.
    expect(create[1]).not.toContain('noCustomMetadata()');
    // Çapraz servis okumaları en sonda: önceki koşullar tutmazsa Firestore okunmaz (kısa devre).
    expect(create[1].trim().endsWith('&& isManagerOf(request.resource.metadata.clubId) && accountActive();')).toBe(true);
    // Üyelik kimliği oturumdan türetilir (FirestoreIds.membership: `{clubId}_{uid}`), rol Firestore `isManager` ile aynı.
    expect(rulesText).toContain("firestore.get(/databases/(default)/documents/memberships/$(clubId + '_' + request.auth.uid)).data;");
    expect(rulesText).toContain("return m.userId == request.auth.uid && m.clubId == clubId");
    expect(rulesText).toContain("&& m.status == 'active' && m.role in ['board', 'president'];");
    expect(rulesText).toContain("request.resource.metadata.keys().hasOnly(['clubId', 'uploaderId', 'firebaseStorageDownloadTokens'])");
    expect(rulesText).toContain("request.resource.metadata.clubId.matches('[A-Za-z0-9_-]+')");
    // Yükleyen izi: üst verideki kimlik oturumdaki uid'dir; klasör adı Firestore `posts` kimlik deseninde.
    expect(rulesText).toContain('request.resource.metadata.uploaderId == request.auth.uid');
    expect(create[1]).toContain("postId.matches('[A-Za-z0-9_-]+')");
    expect(fs.readFileSync(rulesPath('firestore'), 'utf8')).toContain("&& postId.matches('[A-Za-z0-9_-]+')");
  });

  test(`her \`create\` kuralı en çok ${MAX_FIRESTORE_DOCS} Firestore belgesi okur (üretim sınırı; emülatör uygulamaz)`, () => {
    // Her çapraz servis çağrısı bilinen bir yardımcının içindedir ve her yardımcı tek belge okur.
    expect(rulesText.match(/firestore\.(get|exists)\(/g)).toHaveLength(Object.keys(CROSS_SERVICE).length);
    for (const helper of Object.keys(CROSS_SERVICE)) {
      const body = new RegExp(`function ${helper}\\([^)]*\\) \\{([^}]*)\\}`).exec(rulesText);
      expect(body).not.toBeNull();
      expect(body[1].match(/firestore\.(get|exists)\(/g)).toHaveLength(CROSS_SERVICE[helper]);
    }
    const creates = (rulesText.match(/^\s*allow create:[^;]*;/gm) || []).filter((rule) => !/: if false;$/.test(rule.trim()));
    for (const rule of creates) {
      const docs = Object.entries(CROSS_SERVICE).reduce(
        (sum, [helper, count]) => sum + count * (rule.match(new RegExp(`\\b${helper}\\(`, 'g')) || []).length,
        0,
      );
      expect(docs).toBeGreaterThan(0);
      expect(docs).toBeLessThanOrEqual(MAX_FIRESTORE_DOCS);
    }
  });

  test.each([
    ['users', 'uid'],
    ['clubs', 'clubId'],
    ['posts', 'postId'],
  ])('%s/ bloğu: okuma `get` ile açılır, `list` kapalıdır (`allow read` yazılmaz)', (root, id) => {
    const block = new RegExp(`match \\/${root}\\/\\{${id}\\}\\/\\{file\\} \\{([^}]*)\\}`).exec(rulesText);
    expect(block).not.toBeNull();
    const allows = block[1].split(';').map((rule) => rule.trim()).filter((rule) => rule.startsWith('allow ')).map((rule) => `${rule};`);
    expect(allows.map((line) => line.slice(0, line.indexOf(':')))).toEqual(['allow get', 'allow list', 'allow create', 'allow update, delete']);
    expect(allows[0]).toBe('allow get: if signedInVerified();');
    expect(allows[1]).toBe('allow list: if false;');
    expect(allows[3]).toBe('allow update, delete: if false;');
  });

  test('okuması açılan kökler: users/, clubs/ ve posts/; `allow read` hiçbir açık yolda yazılmaz', () => {
    const reads = (rulesText.match(/^\s*allow (?:get|read)[^:]*:[^;]*;/gm) || []).map((rule) => rule.trim());
    expect(reads.filter((rule) => rule.startsWith('allow get'))).toHaveLength(READABLE.length);
    for (const rule of reads.filter((rule) => rule.startsWith('allow read'))) expect(rule).toMatch(/: if false;$/);
  });

  test('clubs/ yüklemesi kapalıdır (T-36\'da açılır)', () => {
    const create = /match \/clubs\/\{clubId\}\/\{file\} \{[^}]*?(allow create:[^;]*;)/.exec(rulesText);
    expect(create).not.toBeNull();
    expect(create[1]).toBe('allow create: if false;');
  });
});

describe.each(ROOTS.filter((r) => !OPENED.includes(r) && !READABLE.includes(r)))('storage deny-all · %s/{id}/{file}', (root) => {
  const existing = `${root}/id1/${EXISTING_FILE}`;
  const created = `${root}/id1/${NEW_FILE}`;

  test.each([...CONTEXTS, ...VARIANTS])('%s · read / create / update / delete → deny', async (role) => {
    await seedFile(existing);
    const storage = contextFor(role).storage();
    await assertFails(getBytes(ref(storage, existing)));
    await assertFails(getMetadata(ref(storage, existing)));
    await assertFails(uploadBytes(ref(storage, created), PNG, IMAGE));
    await assertFails(uploadBytes(ref(storage, existing), PNG, IMAGE));
    await assertFails(updateMetadata(ref(storage, existing), { customMetadata: { clubId: 'c01' } }));
    // D-10 ret vakası: dosya silme yalnızca burada, reddedildiğini kanıtlamak için denenir.
    await assertFails(deleteObject(ref(storage, existing)));
    expect(await fileExists(existing)).toBe(true);
    expect(await fileExists(created)).toBe(false);
  });
});

// ── users/{uid}/{file} — avatar (T-14) ────────────────────────────────────────────────────────

/** Rules `signedInVerified()`: doğrulanmış + izinli alan adlı e-posta (askı / silinmiş hesap dahil). */
const isVerified = (role) => {
  const token = definition(role).token;
  return Boolean(token && token.email_verified) && /@(ogr\.)?gumushane\.edu\.tr$/.test(token.email);
};
/** Rules `accountActive()`: `users/{uid}.status == 'active'` (askıdaki / silinmiş hesap yükleyemez). */
const isActive = (role) => {
  const user = definition(role).user;
  return Boolean(user) && user.status === 'active';
};
const ALL_ROLES = [...CONTEXTS, ...VARIANTS];
const VERIFIED = ALL_ROLES.filter(isVerified);
const UNVERIFIED = ALL_ROLES.filter((role) => !isVerified(role));
/** Doğrulanmış ve hesabı etkin (yükleyebilir) / doğrulanmış ama askıda ya da silinmiş (yükleyemez). */
const UPLOADERS = VERIFIED.filter(isActive);
const INACTIVE = VERIFIED.filter((role) => !isActive(role));

/** Bağlamların `users/{uid}` belgeleri (roles.json → fixtures.js); yükleme kuralı bunları okur. */
const USER_DOCS = Object.fromEntries(Object.entries(buildFixture('base')).filter(([path]) => /^users\/[^/]+$/.test(path)));
const seedUsers = () => seedDocs(USER_DOCS);

/** Bir dosya adının üç izinli türdeki karşılığı. */
const STAMP = '20261008T201502Z_0a1b2c3d4e5f6071';
const TYPES = [
  ['image/jpeg', 'jpg'],
  ['image/png', 'png'],
  ['image/webp', 'webp'],
];
/** Limits.imageMaxBytes (5 MB); Rules `size < imageMaxBytes` ister. */
const IMAGE_MAX_BYTES = 5 * 1024 * 1024;

const OWNER = 'student';
const ownerPath = (file) => `users/${uidOf(OWNER)}/${file}`;
const upload = (role, path, bytes = PNG, metadata = IMAGE) => uploadBytes(ref(contextFor(role).storage(), path), bytes, metadata);

describe('storage users/{uid}/{file} · bağlam kümeleri', () => {
  test('doğrulanmış 11 bağlam (askı + silinmiş dahil), doğrulanmamış 3 bağlam', () => {
    expect(UNVERIFIED.sort()).toEqual(['anon', 'outsideDomain', 'unver']);
    expect(VERIFIED).toHaveLength(ALL_ROLES.length - UNVERIFIED.length);
    expect(VERIFIED).toEqual(expect.arrayContaining(['student', 'super', 'susp', 'deleted']));
  });

  test('yükleyebilen 9 bağlam (hesabı etkin); askıdaki ve silinmiş hesap doğrulanmış ama yükleyemez', () => {
    expect([...INACTIVE].sort()).toEqual(['deleted', 'susp']);
    expect(UPLOADERS).toHaveLength(VERIFIED.length - INACTIVE.length);
    expect(UPLOADERS).toEqual(expect.arrayContaining(['student', 'member', 'advisor', 'super']));
    expect(Object.keys(USER_DOCS).sort()).toEqual(VERIFIED.map((role) => `users/${uidOf(role)}`).sort());
  });
});

describe('storage users/{uid}/{file} · okuma', () => {
  test.each(VERIFIED)('%s · başkasının avatarını (tek dosya) okur → allow', async (role) => {
    await seedFile(ownerPath(EXISTING_FILE));
    const storage = contextFor(role).storage();
    await assertSucceeds(getBytes(ref(storage, ownerPath(EXISTING_FILE))));
    await assertSucceeds(getMetadata(ref(storage, ownerPath(EXISTING_FILE))));
  });

  test.each(UNVERIFIED)('%s · okuyamaz → deny', async (role) => {
    await seedFile(ownerPath(EXISTING_FILE));
    const storage = contextFor(role).storage();
    await assertFails(getBytes(ref(storage, ownerPath(EXISTING_FILE))));
    await assertFails(getMetadata(ref(storage, ownerPath(EXISTING_FILE))));
  });

  test.each(ALL_ROLES)('%s · klasör listelenemez (eski avatarlar sızmaz) → deny', async (role) => {
    await seedFile(ownerPath(EXISTING_FILE));
    const storage = contextFor(role).storage();
    await assertFails(listAll(ref(storage, `users/${uidOf(OWNER)}`)));
    await assertFails(listAll(ref(storage, `users/${uidOf(role)}`)));
    await assertFails(listAll(ref(storage, 'users')));
  });
});

describe('storage users/{uid}/{file} · yükleme (sahiplik)', () => {
  beforeEach(seedUsers);

  test.each(UPLOADERS)('%s · kendi klasörüne yükler → allow', async (role) => {
    const path = `users/${uidOf(role)}/${NEW_FILE}`;
    await assertSucceeds(upload(role, path));
    expect(await fileExists(path)).toBe(true);
  });

  test.each(INACTIVE)('%s · askıdaki / silinmiş hesap kendi klasörüne yükleyemez → deny (okuması açık kalır)', async (role) => {
    const path = `users/${uidOf(role)}/${NEW_FILE}`;
    await seedFile(ownerPath(EXISTING_FILE));
    await assertFails(upload(role, path));
    expect(await fileExists(path)).toBe(false);
    await assertSucceeds(getBytes(ref(contextFor(role).storage(), ownerPath(EXISTING_FILE))));
  });

  test.each(UNVERIFIED)('%s · kendi klasörüne yükleyemez (doğrulanmamış / oturumsuz / alan adı dışı) → deny', async (role) => {
    const path = `users/${uidOf(role)}/${NEW_FILE}`;
    await assertFails(upload(role, path));
    expect(await fileExists(path)).toBe(false);
  });

  test.each(ALL_ROLES.filter((role) => role !== OWNER))('%s · başkasının klasörüne yükleyemez → deny', async (role) => {
    await assertFails(upload(role, ownerPath(NEW_FILE)));
    expect(await fileExists(ownerPath(NEW_FILE))).toBe(false);
  });

  test('alt klasör ve kök düzeyi dosya `users/{uid}/{file}` kalıbına girmez → deny', async () => {
    await assertFails(upload(OWNER, `users/${uidOf(OWNER)}/alt/${NEW_FILE}`));
    await assertFails(upload(OWNER, `users/${NEW_FILE}`));
  });
});

describe('storage users/{uid}/{file} · yükleme (hesap durumu: users/{uid}.status)', () => {
  const path = ownerPath(NEW_FILE);
  const ownerDoc = `users/${uidOf(OWNER)}`;
  const withOwner = (fields) => seedDocs({ ...USER_DOCS, [ownerDoc]: { ...USER_DOCS[ownerDoc], ...fields } });

  test('profil belgesi yok (createProfile öncesi) → deny; başkalarının belgesi sayılmaz', async () => {
    const { [ownerDoc]: _, ...others } = USER_DOCS;
    await seedDocs(others);
    await assertFails(upload(OWNER, path));
    expect(await fileExists(path)).toBe(false);
  });

  test('etkin hesap, profil henüz tamamlanmamış (AUT-05: createProfile sonrası) → allow', async () => {
    await withOwner({ profileComplete: false, interests: [] });
    await assertSucceeds(upload(OWNER, path));
    expect(await fileExists(path)).toBe(true);
  });

  test.each([['suspended'], ['deleted'], ['ACTIVE'], [''], [null]])('status = %p → deny', async (status) => {
    await withOwner({ status });
    await assertFails(upload(OWNER, path));
    expect(await fileExists(path)).toBe(false);
  });

  test('status alanı olmayan belge → deny', async () => {
    const { status: _, ...rest } = USER_DOCS[ownerDoc];
    await seedDocs({ [ownerDoc]: rest });
    await assertFails(upload(OWNER, path));
    expect(await fileExists(path)).toBe(false);
  });

  test('askı kapatma anahtarıdır: etkinken yükler, askıya alınınca yükleyemez, askı kalkınca yeniden yükler', async () => {
    const second = ownerPath('20261008T201503Z_1a2b3c4d5e6f7081.png');
    const third = ownerPath('20261008T201504Z_2a3b4c5d6e7f8091.png');
    await seedUsers();
    await assertSucceeds(upload(OWNER, path));

    await withOwner({ status: 'suspended' });
    await assertFails(upload(OWNER, second));
    expect(await fileExists(second)).toBe(false);

    await withOwner({ status: 'active' });
    await assertSucceeds(upload(OWNER, third));
    expect(await fileExists(path)).toBe(true);
    expect(await fileExists(third)).toBe(true);
  });
});

describe('storage users/{uid}/{file} · yükleme (içerik türü, uzantı, boyut, dosya adı)', () => {
  beforeEach(seedUsers);

  test.each(TYPES)('%s + .%s → allow', async (contentType, extension) => {
    const path = ownerPath(`${STAMP}.${extension}`);
    await assertSucceeds(upload(OWNER, path, PNG, { contentType }));
    expect(await fileExists(path)).toBe(true);
  });

  test.each([
    ['image/gif'],
    ['image/svg+xml'],
    ['image/heic'],
    ['image/bmp'],
    ['text/plain'],
    ['text/html'],
    ['application/octet-stream'],
    ['IMAGE/PNG'],
    ['image/png; charset=utf-8'],
  ])('izinli olmayan içerik türü %s → deny', async (contentType) => {
    await assertFails(upload(OWNER, ownerPath(NEW_FILE), PNG, { contentType }));
    expect(await fileExists(ownerPath(NEW_FILE))).toBe(false);
  });

  test('içerik türü verilmeden yükleme → deny', async () => {
    await assertFails(uploadBytes(ref(contextFor(OWNER).storage(), ownerPath(NEW_FILE)), PNG));
    expect(await fileExists(ownerPath(NEW_FILE))).toBe(false);
  });

  test.each(
    TYPES.flatMap(([contentType, own]) => TYPES.filter(([, other]) => other !== own).map(([, other]) => [contentType, other])),
  )('uzantı içerik türüyle uyuşmuyor: %s + .%s → deny', async (contentType, extension) => {
    const path = ownerPath(`${STAMP}.${extension}`);
    await assertFails(upload(OWNER, path, PNG, { contentType }));
    expect(await fileExists(path)).toBe(false);
  });

  test('boyut sınırı: imageMaxBytes − 1 → allow, imageMaxBytes ve üstü → deny', async () => {
    const under = ownerPath(`${STAMP}.jpg`);
    const exact = ownerPath('20261008T201503Z_0a1b2c3d4e5f6071.jpg');
    const over = ownerPath('20261008T201504Z_0a1b2c3d4e5f6071.jpg');
    const jpeg = { contentType: 'image/jpeg' };

    await assertSucceeds(upload(OWNER, under, new Uint8Array(IMAGE_MAX_BYTES - 1), jpeg));
    await assertFails(upload(OWNER, exact, new Uint8Array(IMAGE_MAX_BYTES), jpeg));
    await assertFails(upload(OWNER, over, new Uint8Array(IMAGE_MAX_BYTES + 1), jpeg));

    expect(await fileExists(under)).toBe(true);
    expect(await fileExists(exact)).toBe(false);
    expect(await fileExists(over)).toBe(false);
  });

  test('boş dosya (0 bayt) → deny', async () => {
    await assertFails(upload(OWNER, ownerPath(NEW_FILE), new Uint8Array(0)));
    expect(await fileExists(ownerPath(NEW_FILE))).toBe(false);
  });

  // Sunumu değiştiren üst veri (T-14 güvenlik incelemesi). Dosya silinemediği için (D-10) kötü yük
  // kalıcıdır: `contentEncoding: gzip` küçük dosyayı indirirken GB'lara açtırır; `contentDisposition`
  // jetonlu indirme adresini keyfi adlı dosya dağıtımına çevirir.
  test.each([
    ['contentEncoding: gzip', { contentEncoding: 'gzip' }],
    ['contentEncoding: deflate', { contentEncoding: 'deflate' }],
    ['contentEncoding: br', { contentEncoding: 'br' }],
    ['contentEncoding: GZIP', { contentEncoding: 'GZIP' }],
    ['contentEncoding: identity, gzip', { contentEncoding: 'identity, gzip' }],
    ['contentDisposition: attachment + dosya adı', { contentDisposition: 'attachment; filename="odev.exe"' }],
    ['contentDisposition: attachment', { contentDisposition: 'attachment' }],
    ['contentDisposition: inline + dosya adı', { contentDisposition: 'inline; filename="odev.exe"' }],
    ["contentDisposition: inline + şema dışı ad (filename*)", { contentDisposition: "inline; filename*=utf-8''odev.exe" }],
    ["contentDisposition: inline + yol geçişli ad", { contentDisposition: `inline; filename*=utf-8''..%2F${NEW_FILE}` }],
    ["contentDisposition: attachment + şemaya uyan ad", { contentDisposition: `attachment; filename*=utf-8''${NEW_FILE}` }],
    ['özel üst veri', { customMetadata: { clubId: 'c01' } }],
    ['özel üst veri (boş değer)', { customMetadata: { x: '' } }],
    ['özel üst veri (jeton + başka anahtar)', { customMetadata: { firebaseStorageDownloadTokens: 't', x: '1' } }],
  ])('sunum üst verisi · %s → deny', async (_, extra) => {
    await assertFails(upload(OWNER, ownerPath(NEW_FILE), PNG, { ...IMAGE, ...extra }));
    expect(await fileExists(ownerPath(NEW_FILE))).toBe(false);
  });

  test.each([
    ['contentEncoding: identity', { contentEncoding: 'identity' }],
    ['contentDisposition: inline', { contentDisposition: 'inline' }],
    // Gerçek sunucunun varsayılan biçimleri (ilk canlı denemede katı eşitlik her yüklemeyi reddetti).
    ['contentDisposition: sunucu varsayılanı (dosya adı)', { contentDisposition: `inline; filename*=utf-8''${NEW_FILE}` }],
    ['contentDisposition: sunucu varsayılanı (kodlanmış yol)', { contentDisposition: `inline; filename*=utf-8''users%2Fabc_123%2F${NEW_FILE}` }],
    ['özel üst veri: yalnızca indirme jetonu', { customMetadata: { firebaseStorageDownloadTokens: 'jeton' } }],
  ])('sunum üst verisi · %s (varsayılanla aynı anlam) → allow', async (_, extra) => {
    await assertSucceeds(upload(OWNER, ownerPath(NEW_FILE), PNG, { ...IMAGE, ...extra }));
    expect(await fileExists(ownerPath(NEW_FILE))).toBe(true);
  });

  test.each([
    ['avatar.png'],
    ['0.png'],
    ['20261008T201502Z_0A1B2C3D4E5F6071.png'],
    ['20261008T201502Z_0a1b2c3d4e5f607.png'],
    ['20261008T201502Z_0a1b2c3d4e5f60711.png'],
    ['20261008T201502Z_0a1b2c3d4e5f607g.png'],
    ['2026-10-08T20:15:02Z_0a1b2c3d4e5f6071.png'],
    ['20261008T201502_0a1b2c3d4e5f6071.png'],
    ['20261008T201502Z-0a1b2c3d4e5f6071.png'],
    ['20261008T201502Z_0a1b2c3d4e5f6071.PNG'],
    ['20261008T201502Z_0a1b2c3d4e5f6071.png.png'],
    ['20261008T201502Z_0a1b2c3d4e5f6071.jpg.png'],
    ['x20261008T201502Z_0a1b2c3d4e5f6071.png'],
    [' 20261008T201502Z_0a1b2c3d4e5f6071.png'],
    ['20261008T201502Z_0a1b2c3d4e5f6071'],
    ['20261008T201502Z_0a1b2c3d4e5f6071.gif'],
  ])('StoragePaths.newFileName şeması dışındaki ad "%s" → deny', async (file) => {
    await assertFails(upload(OWNER, ownerPath(file)));
    expect(await fileExists(ownerPath(file))).toBe(false);
  });
});

describe('storage users/{uid}/{file} · üzerine yazma / üst veri / silme (D-10)', () => {
  beforeEach(seedUsers);

  test.each(ALL_ROLES)('%s · var olan dosyada update / metadata / delete → deny (sahibi dahil)', async (role) => {
    const existing = `users/${uidOf(role)}/${EXISTING_FILE}`;
    await seedFile(existing);
    await seedFile(ownerPath(EXISTING_FILE));
    const storage = contextFor(role).storage();
    for (const path of [existing, ownerPath(EXISTING_FILE)]) {
      // Aynı ada ikinci yükleme: Storage bunu `create` sayar (`update` yalnızca üst veridir) —
      // üzerine yazmayı kuraldaki `isNewFile()` (resource == null) engeller.
      await assertFails(uploadBytes(ref(storage, path), PNG, IMAGE));
      await assertFails(updateMetadata(ref(storage, path), { contentType: 'image/jpeg' }));
      await assertFails(updateMetadata(ref(storage, path), { customMetadata: { owner: 'x' } }));
      // D-10 ret vakası: dosya silme yalnızca burada, reddedildiğini kanıtlamak için denenir.
      await assertFails(deleteObject(ref(storage, path)));
      expect(await fileExists(path)).toBe(true);
    }
  });

  test('fotoğraf değişimi = yeni adla ikinci yükleme → allow; eski dosya yerinde kalır', async () => {
    const first = ownerPath(`${STAMP}.jpg`);
    const second = ownerPath('20261008T201503Z_1a2b3c4d5e6f7081.png');

    await assertSucceeds(upload(OWNER, first, PNG, { contentType: 'image/jpeg' }));
    await assertSucceeds(upload(OWNER, second));

    expect(await fileExists(first)).toBe(true);
    expect(await fileExists(second)).toBe(true);
  });
});

describe('storage users/{uid}/{file} · repository sözleşmesi (UserRepository.updateAvatar)', () => {
  // Firestore'a yazılan `avatarPath` değerleri repository'nin Storage'a yüklediği GERÇEK yollardır
  // (Dart: rules_payload_contract_test.dart "avatarPath, Storage'a yüklenen dosyanın yoludur").
  const contract = require('../contracts/repository_payloads.json');
  const CONTENT_TYPE = { jpg: 'image/jpeg', png: 'image/png', webp: 'image/webp' };
  const avatarSteps = contract.steps.filter((step) => step.call.startsWith('UserRepository.updateAvatar'));
  const paths = [...new Set(avatarSteps.map((step) => step.writes[0].data.avatarPath))];

  beforeEach(seedUsers);

  test('sözleşmede en az bir updateAvatar yolu var; AUT-05 yolu JPEG', () => {
    expect(paths.length).toBeGreaterThan(0);
    const aut05 = contract.steps.find((step) => step.call === contract.aut05[2]);
    expect(aut05.writes[0].data.avatarPath).toMatch(/\.jpg$/);
    expect(paths).toContain(aut05.writes[0].data.avatarPath);
  });

  test.each(paths)('%s · sahibi yükler → allow; başkası yükleyemez → deny', async (path) => {
    const contentType = CONTENT_TYPE[path.slice(path.lastIndexOf('.') + 1)];
    expect(path.startsWith(`users/${contract.uid}/`)).toBe(true);

    await assertFails(upload('member', path, PNG, { contentType }));
    expect(await fileExists(path)).toBe(false);

    await assertSucceeds(upload(contract.role, path, PNG, { contentType }));
    expect(await fileExists(path)).toBe(true);
    // Yüklenen dosya profil görüntülenirken tek dosya olarak okunur.
    await assertSucceeds(getBytes(ref(contextFor('member').storage(), path)));
  });
});

// ── posts/{postId}/{file} — gönderi görseli (T-21, CD-39) ─────────────────────────────────────

/** Yükleme anında gönderi belgesi YOKTUR (K-18): kimlik istemcide önceden üretilir. */
const POST_ID = 'pYeni_01';
const postFile = (file, postId = POST_ID) => `posts/${postId}/${file}`;
/** `c01` kulübünün etkin yöneticileri (Firestore `isManager`: yönetim kurulu / başkan). */
const MANAGERS = UPLOADERS.filter((role) => ['board', 'president'].includes(definition(role).clubRole));
const MANAGER = 'board';
/**
 * `PostRepository.uploadImages` üst verisi: içerik türü + `customMetadata` { clubId, uploaderId }.
 * `uploaderId` yükleyenin kendi kimliğidir (Rules oturumla karşılaştırır).
 */
const metaFor = (uid, clubId = 'c01', extra = {}) => ({ ...IMAGE, customMetadata: { clubId, uploaderId: uid, ...extra } });
/** `role` bağlamının kendi kimliğiyle gönderdiği üst veri. */
const metaOf = (role, clubId = 'c01', extra = {}) => metaFor(uidOf(role), clubId, extra);
/** Varsayılan yükleyenin (`MANAGER`) üst verisi. */
const clubMeta = (clubId = 'c01', extra = {}) => metaOf(MANAGER, clubId, extra);
/** Kuralın okuduğu belgeler (hesap + üyelik) ve kulüpler (kural OKUMAZ — askı vakası için kurulur). */
const IDENTITY_DOCS = Object.fromEntries(
  Object.entries(buildFixture('base')).filter(([path]) => /^(users|memberships|clubs)\/[^/]+$/.test(path)),
);
const seedIdentity = (edit) => seedDocs(editDocs(IDENTITY_DOCS, edit));
const MANAGER_DOC = `users/${uidOf(MANAGER)}`;
const MANAGER_MEMBERSHIP = `memberships/c01_${uidOf(MANAGER)}`;

describe('storage posts/{postId}/{file} · bağlam kümeleri', () => {
  test('c01 yöneticileri: board ve president; danışman, üye, süper admin ve başka kulübün yöneticisi değil', () => {
    expect([...MANAGERS].sort()).toEqual(['board', 'president']);
    expect(Object.keys(IDENTITY_DOCS)).toEqual(expect.arrayContaining([MANAGER_DOC, MANAGER_MEMBERSHIP, 'clubs/c01', 'clubs/c02']));
  });
});

describe('storage posts/{postId}/{file} · okuma', () => {
  const image = postFile(EXISTING_FILE, 'p01');

  // Üyelik aranmaz: yol yalnızca gönderi belgesinde durur (o belgeyi kulübün içini gören okur).
  test.each(VERIFIED)('%s · gönderi görselini (tek dosya) okur → allow', async (role) => {
    await seedFile(image);
    const storage = contextFor(role).storage();
    await assertSucceeds(getBytes(ref(storage, image)));
    await assertSucceeds(getMetadata(ref(storage, image)));
  });

  test.each(UNVERIFIED)('%s · okuyamaz → deny', async (role) => {
    await seedFile(image);
    const storage = contextFor(role).storage();
    await assertFails(getBytes(ref(storage, image)));
    await assertFails(getMetadata(ref(storage, image)));
  });

  test.each(ALL_ROLES)('%s · klasör listelenemez (kaldırılan görseller sızmaz) → deny', async (role) => {
    await seedFile(image);
    const storage = contextFor(role).storage();
    await assertFails(listAll(ref(storage, 'posts/p01')));
    await assertFails(listAll(ref(storage, 'posts')));
  });
});

describe('storage posts/{postId}/{file} · yükleme (rol: metadata.clubId kulübünün yöneticisi)', () => {
  const path = postFile(NEW_FILE);

  beforeEach(() => seedIdentity());

  test.each(MANAGERS)('%s · kendi kulübü (c01) adına yükler → allow', async (role) => {
    await assertSucceeds(upload(role, path, PNG, metaOf(role)));
    expect(await fileExists(path)).toBe(true);
  });

  // Üye, danışman, başvurusu bekleyen, ayrılmış, üye olmayan, süper admin, başka kulübün yöneticisi,
  // askıdaki / silinmiş hesap, doğrulanmamış ve oturumsuz bağlam.
  test.each(ALL_ROLES.filter((role) => !MANAGERS.includes(role)))('%s · c01 adına yükleyemez → deny', async (role) => {
    await assertFails(upload(role, path, PNG, metaOf(role)));
    expect(await fileExists(path)).toBe(false);
  });

  test('başka kulübün yöneticisi: kendi kulübü (c02) adına yükler → allow; c01 adına → deny', async () => {
    const own = postFile('20261008T201503Z_1a2b3c4d5e6f7081.png');
    await assertFails(upload('otherManager', path, PNG, metaOf('otherManager', 'c01')));
    await assertSucceeds(upload('otherManager', own, PNG, metaOf('otherManager', 'c02')));
    expect(await fileExists(path)).toBe(false);
    expect(await fileExists(own)).toBe(true);
  });

  test.each([['c02'], ['yok'], ['C01']])('yönetici, yöneticisi olmadığı kulüp (%s) adına yükleyemez → deny', async (clubId) => {
    await assertFails(upload(MANAGER, path, PNG, clubMeta(clubId)));
    expect(await fileExists(path)).toBe(false);
  });

  // Üyelik kimliği `{clubId}_{uid}` birleşimidir: `c01_u` + `board` = `c01` + `u_board`. Kural okuduğu
  // belgenin `userId` / `clubId` alanlarını da karşılaştırır — başkasının üyelik belgesi gösterilemez.
  test('kimlik birleşimi kaydırılarak başka yöneticinin üyelik belgesi gösterilemez → deny', async () => {
    const uid = uidOf(MANAGER).slice('u_'.length);
    expect(`c01_u_${uid}`).toBe(MANAGER_MEMBERSHIP.slice('memberships/'.length));
    await seedDocs({ [`users/${uid}`]: IDENTITY_DOCS[MANAGER_DOC] });
    const storage = getTestEnv()
      .authenticatedContext(uid, { email: `${uid}@ogr.gumushane.edu.tr`, email_verified: true })
      .storage();

    await assertFails(uploadBytes(ref(storage, path), PNG, metaFor(uid, 'c01_u')));
    await assertFails(uploadBytes(ref(storage, path), PNG, metaFor(uid, 'c01')));
    expect(await fileExists(path)).toBe(false);

    // Denetim: aynı oturum KENDİ yönetici üyeliğiyle yükler (ret, bağlamın geçersizliğinden değildir).
    await seedDocs({
      [`memberships/c01_${uid}`]: { ...IDENTITY_DOCS[MANAGER_MEMBERSHIP], userId: uid },
    });
    await assertFails(uploadBytes(ref(storage, path), PNG, metaFor(uid, 'c01_u')));
    await assertSucceeds(uploadBytes(ref(storage, path), PNG, metaFor(uid, 'c01')));
    expect(await fileExists(path)).toBe(true);
  });

  test.each([
    ['userId', { userId: 'u_baskasi' }],
    ['clubId', { clubId: 'c02' }],
  ])('üyelik belgesinin %s alanı kimliğiyle uyuşmuyor → deny', async (_, fields) => {
    await seedIdentity({ patch: { [MANAGER_MEMBERSHIP]: fields } });
    await assertFails(upload(MANAGER, path, PNG, clubMeta('c01')));
    expect(await fileExists(path)).toBe(false);
  });

  test('gönderi belgesi aranmaz (K-18): olmayan ve var olan gönderi kimliğine yükleme → allow', async () => {
    const existingPost = postFile(NEW_FILE, 'p01');
    await assertSucceeds(upload(MANAGER, path, PNG, clubMeta()));
    await assertSucceeds(upload(MANAGER, existingPost, PNG, clubMeta()));
    expect(await fileExists(path)).toBe(true);
    expect(await fileExists(existingPost)).toBe(true);
  });

  test('alt klasör ve kök düzeyi dosya `posts/{postId}/{file}` kalıbına girmez → deny', async () => {
    await assertFails(upload(MANAGER, `posts/${POST_ID}/alt/${NEW_FILE}`, PNG, clubMeta()));
    await assertFails(upload(MANAGER, `posts/${NEW_FILE}`, PNG, clubMeta()));
  });
});

describe('storage posts/{postId}/{file} · yükleme (üyelik ve hesap durumu: Firestore)', () => {
  const path = postFile(NEW_FILE);
  const patch = (docPath, fields) => seedIdentity({ patch: { [docPath]: fields } });

  test('üyelik belgesi yok → deny', async () => {
    await seedIdentity({ without: [MANAGER_MEMBERSHIP] });
    await assertFails(upload(MANAGER, path, PNG, clubMeta()));
    expect(await fileExists(path)).toBe(false);
  });

  test.each([['pending'], ['left'], ['cancelled'], ['rejected'], ['removed'], ['ACTIVE'], [null]])(
    'üyelik status = %p → deny',
    async (status) => {
      await patch(MANAGER_MEMBERSHIP, { status });
      await assertFails(upload(MANAGER, path, PNG, clubMeta()));
      expect(await fileExists(path)).toBe(false);
    },
  );

  test.each([['member'], ['advisor'], ['PRESIDENT'], [null]])('üyelik role = %p → deny', async (role) => {
    await patch(MANAGER_MEMBERSHIP, { role });
    await assertFails(upload(MANAGER, path, PNG, clubMeta()));
    expect(await fileExists(path)).toBe(false);
  });

  test('profil belgesi yok → deny', async () => {
    await seedIdentity({ without: [MANAGER_DOC] });
    await assertFails(upload(MANAGER, path, PNG, clubMeta()));
    expect(await fileExists(path)).toBe(false);
  });

  test.each([['suspended'], ['deleted'], [null]])('yöneticinin hesabı status = %p → deny (üyeliği active kalsa da)', async (status) => {
    await patch(MANAGER_DOC, { status });
    await assertFails(upload(MANAGER, path, PNG, clubMeta()));
    expect(await fileExists(path)).toBe(false);
  });

  test('askı kapatma anahtarıdır: yönetici yükler, askıya alınınca yükleyemez, yönetimden çıkınca yükleyemez', async () => {
    const second = postFile('20261008T201503Z_1a2b3c4d5e6f7081.png');
    const third = postFile('20261008T201504Z_2a3b4c5d6e7f8091.png');
    await seedIdentity();
    await assertSucceeds(upload(MANAGER, path, PNG, clubMeta()));

    await patch(MANAGER_DOC, { status: 'suspended' });
    await assertFails(upload(MANAGER, second, PNG, clubMeta()));

    await patch(MANAGER_MEMBERSHIP, { role: 'member' });
    await assertFails(upload(MANAGER, third, PNG, clubMeta()));

    expect(await fileExists(path)).toBe(true);
    expect(await fileExists(second)).toBe(false);
    expect(await fileExists(third)).toBe(false);
  });

  // Kabul edilen sınırlama (rules-spec §7): üretimde kural başına en çok 2 Firestore belgesi okunur
  // (üyelik + hesap) — kulüp belgesi okunamaz. Askıdaki kulübün yöneticisi dosyayı yükler ama gönderiyi
  // yayınlayamaz / düzenleyemez (Firestore `clubLive`; rules/posts.test.js): dosya yetim kalır.
  test.each([
    ['askıda', { status: 'suspended' }],
    ['silinmiş', { isDeleted: true }],
  ])('%s kulüp: Storage kuralı kulüp belgesini OKUMAZ → allow (yayını Firestore reddeder)', async (_, fields) => {
    await patch('clubs/c01', fields);
    await assertSucceeds(upload(MANAGER, path, PNG, clubMeta()));
    expect(await fileExists(path)).toBe(true);
  });
});

describe('storage posts/{postId}/{file} · yükleme (özel üst veri: yalnızca clubId + uploaderId)', () => {
  const path = postFile(NEW_FILE);
  const UID = uidOf(MANAGER);

  beforeEach(() => seedIdentity());

  test.each([
    ['üst veri yok', IMAGE],
    ['boş özel üst veri', { ...IMAGE, customMetadata: {} }],
    ['clubId yok (yalnızca uploaderId)', { ...IMAGE, customMetadata: { uploaderId: UID } }],
    ['clubId yok, başka anahtar', { ...IMAGE, customMetadata: { uploaderId: UID, x: 'c01' } }],
    ['clubId yok, yalnızca indirme jetonu', { ...IMAGE, customMetadata: { uploaderId: UID, firebaseStorageDownloadTokens: 'jeton' } }],
    ['clubId + fazladan anahtar', clubMeta('c01', { x: '1' })],
    ['clubId + jeton + fazladan anahtar', clubMeta('c01', { firebaseStorageDownloadTokens: 'jeton', x: '1' })],
    ['clubId farklı yazım (clubid)', { ...IMAGE, customMetadata: { clubid: 'c01', uploaderId: UID } }],
    // Yükleyen kimliği (T-21 güvenlik incelemesi): alan atlanamaz, başkasının adı yazılamaz.
    ['uploaderId yok (yalnızca clubId)', { ...IMAGE, customMetadata: { clubId: 'c01' } }],
    ['uploaderId boş', clubMeta('c01', { uploaderId: '' })],
    ['uploaderId başka yöneticinin kimliği', clubMeta('c01', { uploaderId: uidOf('president') })],
    ['uploaderId olmayan bir kimlik', clubMeta('c01', { uploaderId: 'u_yok' })],
    ['uploaderId sonunda boşluk', clubMeta('c01', { uploaderId: `${UID} ` })],
    ['uploaderId farklı yazım (uploaderid)', { ...IMAGE, customMetadata: { clubId: 'c01', uploaderid: UID } }],
    ['clubId boş', clubMeta('')],
    ['clubId yol ayırıcı taşır', clubMeta('c01/x')],
    ['clubId üst klasöre çıkar', clubMeta('../c01')],
    ['clubId boşluk taşır', clubMeta('c01 ')],
    ['clubId üyelik kimliğinin tamamı', clubMeta(`c01_${uidOf(MANAGER)}`)],
  ])('%s → deny', async (_, metadata) => {
    await assertFails(upload(MANAGER, path, PNG, metadata));
    expect(await fileExists(path)).toBe(false);
  });

  // Gerçek sunucu indirme jetonunu değerlendirme anında haritaya koyabilir (T-14 canlı dersi).
  test('clubId + uploaderId + indirme jetonu anahtarı → allow', async () => {
    await assertSucceeds(upload(MANAGER, path, PNG, clubMeta('c01', { firebaseStorageDownloadTokens: 'jeton' })));
    expect(await fileExists(path)).toBe(true);
  });

  test.each([
    ['contentEncoding: gzip', { contentEncoding: 'gzip' }],
    ['contentDisposition: attachment + dosya adı', { contentDisposition: 'attachment; filename="odev.exe"' }],
    ["contentDisposition: inline + şema dışı ad", { contentDisposition: "inline; filename*=utf-8''odev.exe" }],
  ])('sunum üst verisi · %s → deny', async (_, extra) => {
    await assertFails(upload(MANAGER, path, PNG, { ...clubMeta(), ...extra }));
    expect(await fileExists(path)).toBe(false);
  });

  test('sunum üst verisi · sunucu varsayılanı (kodlanmış yol) → allow', async () => {
    const disposition = `inline; filename*=utf-8''posts%2F${POST_ID}%2F${NEW_FILE}`;
    await assertSucceeds(upload(MANAGER, path, PNG, { ...clubMeta(), contentDisposition: disposition, contentEncoding: 'identity' }));
    expect(await fileExists(path)).toBe(true);
  });
});

// T-21 güvenlik incelemesi (bulgu 1 ve 3). Storage nesnesi yükleyeni kendiliğinden kaydetmez ve klasör
// adı kimlik taşımaz: `uploaderId` olmadan dosya yığan yönetici konsoldan bulunamaz, tek fren olan hesap
// askısı (rules-spec §9.8) uygulanamazdı. Klasör adı da belge kimliği deseniyle sınırlıdır.
describe('storage posts/{postId}/{file} · yükleme (yükleyen izi ve klasör adı)', () => {
  /** Yüklenen nesnenin özel üst verisi (kurallar kapalıyken). */
  const customMetadataOf = async (path) => (await getMetadata(ref((await getAdminContext()).storage(), path))).customMetadata;

  beforeEach(() => seedIdentity());

  test.each(MANAGERS)('%s · yüklenen nesne yükleyenin kimliğini ve kulübünü taşır', async (role) => {
    const path = postFile(NEW_FILE);
    await assertSucceeds(upload(role, path, PNG, metaOf(role)));
    expect(await customMetadataOf(path)).toMatchObject({ clubId: 'c01', uploaderId: uidOf(role) });
  });

  test('yönetici, aynı kulübün başka yöneticisinin adıyla yükleyemez (iz başkasına bırakılamaz) → deny', async () => {
    const path = postFile(NEW_FILE);
    await assertFails(upload('president', path, PNG, metaOf('board')));
    await assertFails(upload('board', path, PNG, metaOf('president')));
    expect(await fileExists(path)).toBe(false);
  });

  test.each([
    ['boşluk ve ünlem', 'bosluk ve unlem !'],
    ['Türkçe harf', 'ü-ğ-ş'],
    ['kural ifadesi', '$(x)'],
    ['nokta', 'p.01'],
    ['artı ve eşittir', 'a+b=c'],
  ])('klasör adı belge kimliği deseninde değil (%s) → deny', async (_, postId) => {
    const path = postFile(NEW_FILE, postId);
    await assertFails(upload(MANAGER, path, PNG, clubMeta()));
    expect(await fileExists(path)).toBe(false);
  });

  test.each([['p01'], ['pYeni_01'], ['Ab3-_x'], ['0Zk9QmT4vX2sLr7NcB1e']])('klasör adı belge kimliği deseninde (%s) → allow', async (postId) => {
    const path = postFile(NEW_FILE, postId);
    await assertSucceeds(upload(MANAGER, path, PNG, clubMeta()));
    expect(await fileExists(path)).toBe(true);
  });

  // Kabul edilen davranış (rules-spec §7, §9.11): kural gönderi belgesine bakmaz (K-18), bu yüzden başka
  // kulübün yöneticisi KENDİ kulübü adına `c01` gönderisinin klasörüne dosya yükleyebilir. Dosyayı
  // gönderiye iliştiremez (`posts.images` alanını yalnızca gönderinin yazarı yazar — rules/posts.test.js);
  // dosya yetim kalır ve yükleyeni üst veriden bulunur. `c01` adına yüklemesi yine reddedilir.
  test('başkasının gönderi klasörü: başka kulübün yöneticisi kendi kulübü (c02) adına p01 klasörüne yükler → allow; izi kendi kimliğidir', async () => {
    const path = postFile(NEW_FILE, 'p01');
    await assertFails(upload('otherManager', path, PNG, metaOf('otherManager', 'c01')));
    expect(await fileExists(path)).toBe(false);

    await assertSucceeds(upload('otherManager', path, PNG, metaOf('otherManager', 'c02')));
    expect(await customMetadataOf(path)).toMatchObject({ clubId: 'c02', uploaderId: uidOf('otherManager') });
    // Üzerine yazılamaz: gönderinin kendi yöneticisi de aynı ada yükleyemez (yeni ad kullanır).
    await assertFails(upload(MANAGER, path, PNG, clubMeta()));
  });
});

describe('storage posts/{postId}/{file} · yükleme (içerik türü, uzantı, boyut, dosya adı)', () => {
  beforeEach(() => seedIdentity());

  test.each(TYPES)('%s + .%s → allow', async (contentType, extension) => {
    const path = postFile(`${STAMP}.${extension}`);
    await assertSucceeds(upload(MANAGER, path, PNG, { ...clubMeta(), contentType }));
    expect(await fileExists(path)).toBe(true);
  });

  test.each([['image/gif'], ['image/svg+xml'], ['image/heic'], ['text/html'], ['application/octet-stream']])(
    'izinli olmayan içerik türü %s → deny',
    async (contentType) => {
      await assertFails(upload(MANAGER, postFile(NEW_FILE), PNG, { ...clubMeta(), contentType }));
      expect(await fileExists(postFile(NEW_FILE))).toBe(false);
    },
  );

  test.each([
    ['image/jpeg', 'png'],
    ['image/png', 'webp'],
    ['image/webp', 'jpg'],
  ])('uzantı içerik türüyle uyuşmuyor: %s + .%s → deny', async (contentType, extension) => {
    const path = postFile(`${STAMP}.${extension}`);
    await assertFails(upload(MANAGER, path, PNG, { ...clubMeta(), contentType }));
    expect(await fileExists(path)).toBe(false);
  });

  test('boyut sınırı: imageMaxBytes − 1 → allow, imageMaxBytes → deny; boş dosya → deny', async () => {
    const under = postFile(`${STAMP}.jpg`);
    const exact = postFile('20261008T201503Z_0a1b2c3d4e5f6071.jpg');
    const empty = postFile('20261008T201504Z_0a1b2c3d4e5f6071.jpg');
    const jpeg = { ...clubMeta(), contentType: 'image/jpeg' };

    await assertSucceeds(upload(MANAGER, under, new Uint8Array(IMAGE_MAX_BYTES - 1), jpeg));
    await assertFails(upload(MANAGER, exact, new Uint8Array(IMAGE_MAX_BYTES), jpeg));
    await assertFails(upload(MANAGER, empty, new Uint8Array(0), jpeg));

    expect(await fileExists(under)).toBe(true);
    expect(await fileExists(exact)).toBe(false);
    expect(await fileExists(empty)).toBe(false);
  });

  test.each([
    ['0.png'],
    ['gorsel.png'],
    ['20261008T201502Z_0A1B2C3D4E5F6071.png'],
    ['20261008T201502Z_0a1b2c3d4e5f607.png'],
    ['20261008T201502Z_0a1b2c3d4e5f6071.png.png'],
    ['20261008T201502Z_0a1b2c3d4e5f6071.gif'],
  ])('StoragePaths.newFileName şeması dışındaki ad "%s" → deny', async (file) => {
    await assertFails(upload(MANAGER, postFile(file), PNG, clubMeta()));
    expect(await fileExists(postFile(file))).toBe(false);
  });
});

describe('storage posts/{postId}/{file} · üzerine yazma / üst veri / silme (D-10)', () => {
  const existing = postFile(EXISTING_FILE);

  beforeEach(() => seedIdentity());

  test.each(ALL_ROLES)('%s · var olan dosyada üzerine yazma / metadata / delete → deny (yönetici dahil)', async (role) => {
    await seedFile(existing);
    const storage = contextFor(role).storage();
    // Aynı ada ikinci yükleme `create`tir: üzerine yazmayı kuraldaki `isNewFile()` engeller.
    await assertFails(uploadBytes(ref(storage, existing), PNG, metaOf(role)));
    await assertFails(updateMetadata(ref(storage, existing), { contentType: 'image/jpeg' }));
    await assertFails(updateMetadata(ref(storage, existing), { customMetadata: { clubId: 'c02' } }));
    // Yükleyen izi sonradan değiştirilemez (üst veri güncellemesi kapalı).
    await assertFails(updateMetadata(ref(storage, existing), { customMetadata: { uploaderId: 'u_baskasi' } }));
    // D-10 ret vakası: dosya silme yalnızca burada, reddedildiğini kanıtlamak için denenir.
    await assertFails(deleteObject(ref(storage, existing)));
    expect(await fileExists(existing)).toBe(true);
  });

  test('aynı gönderiye 4 görsel = yeni adlarla 4 yükleme → allow; hepsi yerinde kalır', async () => {
    const files = [1, 2, 3, 4].map((n) => postFile(`20261008T20150${n}Z_1a2b3c4d5e6f708${n}.png`));
    for (const path of files) await assertSucceeds(upload(MANAGER, path, PNG, clubMeta()));
    for (const path of files) expect(await fileExists(path)).toBe(true);
  });
});

// ── clubs/{clubId}/{file} — logo ve kapak (T-16: yalnızca okuma) ──────────────────────────────

describe('storage clubs/{clubId}/{file} · okuma', () => {
  const CLUB_ID = 'c01';
  const logo = `clubs/${CLUB_ID}/${EXISTING_FILE}`;
  const otherClubCover = `clubs/c02/${EXISTING_FILE}`;

  test.each(VERIFIED)('%s · kulüp görselini (tek dosya) okur → allow', async (role) => {
    await seedFile(logo);
    await seedFile(otherClubCover);
    const storage = contextFor(role).storage();
    // Üyelik aranmaz: kulüp belgesi doğrulanmış herkese açıktır (CLB-01 keşif listesi).
    for (const path of [logo, otherClubCover]) {
      await assertSucceeds(getBytes(ref(storage, path)));
      await assertSucceeds(getMetadata(ref(storage, path)));
    }
  });

  test.each(UNVERIFIED)('%s · okuyamaz → deny', async (role) => {
    await seedFile(logo);
    const storage = contextFor(role).storage();
    await assertFails(getBytes(ref(storage, logo)));
    await assertFails(getMetadata(ref(storage, logo)));
  });

  test.each(ALL_ROLES)('%s · klasör listelenemez (eski logo / kapak sızmaz) → deny', async (role) => {
    await seedFile(logo);
    const storage = contextFor(role).storage();
    await assertFails(listAll(ref(storage, `clubs/${CLUB_ID}`)));
    await assertFails(listAll(ref(storage, 'clubs')));
  });

  test('alt klasör ve kök düzeyi dosya `clubs/{clubId}/{file}` kalıbına girmez → deny', async () => {
    await seedFile(`clubs/${CLUB_ID}/alt/${EXISTING_FILE}`);
    await seedFile(`clubs/${EXISTING_FILE}`);
    const storage = contextFor('member').storage();
    await assertFails(getBytes(ref(storage, `clubs/${CLUB_ID}/alt/${EXISTING_FILE}`)));
    await assertFails(getBytes(ref(storage, `clubs/${EXISTING_FILE}`)));
  });
});

describe('storage clubs/{clubId}/{file} · yükleme / üzerine yazma / üst veri / silme (kapalı — yükleme T-36)', () => {
  const CLUB_ID = 'c01';
  const existing = `clubs/${CLUB_ID}/${EXISTING_FILE}`;
  const created = `clubs/${CLUB_ID}/${NEW_FILE}`;

  // Yönetici rolleri (board, president), danışman ve süper admin dahil: yükleme kuralı henüz yok.
  test.each(ALL_ROLES)('%s · create / üzerine yazma / metadata / delete → deny', async (role) => {
    await seedUsers();
    await seedFile(existing);
    const storage = contextFor(role).storage();
    await assertFails(uploadBytes(ref(storage, created), PNG, IMAGE));
    await assertFails(uploadBytes(ref(storage, existing), PNG, IMAGE));
    await assertFails(updateMetadata(ref(storage, existing), { contentType: 'image/jpeg' }));
    await assertFails(updateMetadata(ref(storage, existing), { customMetadata: { clubId: CLUB_ID } }));
    // D-10 ret vakası: dosya silme yalnızca burada, reddedildiğini kanıtlamak için denenir.
    await assertFails(deleteObject(ref(storage, existing)));
    expect(await fileExists(existing)).toBe(true);
    expect(await fileExists(created)).toBe(false);
  });
});

// GEÇİCİ (W-61, CD-136): test süresince `gmail.com` de izinli alan adıdır (`signedInVerified()` deseni
// EmailDomainPolicy.rulesRegex() ile aynı). Geri almada bu blok silinir.
describe('GEÇİCİ (W-61) · storage users/{uid}/{file} · gmail.com geçici izinli', () => {
  const UID = 'u_gmail';
  const own = `users/${UID}/${NEW_FILE}`;
  const verified = (email) => ({ email, email_verified: true });
  /** Verilen token claim'leriyle istemci (roles.json bağlamlarının dışındaki e-postalar için). */
  const storageWith = (token) => getTestEnv().authenticatedContext(UID, token).storage();

  // Yükleme `accountActive()` ister: `u_gmail` için etkin bir profil belgesi kurulur.
  beforeEach(() => seedDocs({ ...USER_DOCS, [`users/${UID}`]: USER_DOCS[`users/${uidOf(OWNER)}`] }));

  test.each([
    ['gmail.com', 'allow', verified('ad.soyad@gmail.com')],
    ['büyük harfli gmail.com', 'allow', verified('Ad.Soyad@Gmail.COM')],
    ['gmail.com ama email_verified: false', 'deny', { email: 'ad.soyad@gmail.com', email_verified: false }],
    ['gmail önek olarak (gmail.com.evil.com)', 'deny', verified('ad@gmail.com.evil.com')],
    ['sonu gmail.com ile biten alan adı (xgmail.com)', 'deny', verified('ad@xgmail.com')],
    ['gmail alt alan adı (mail.gmail.com)', 'deny', verified('ad@mail.gmail.com')],
    ['hotmail.com (kontrol)', 'deny', verified('ad@hotmail.com')],
  ])('%s · avatar okuma + kendi klasörüne yükleme → %s', async (_title, expected, token) => {
    await seedFile(ownerPath(EXISTING_FILE));
    const storage = storageWith(token);
    const check = expected === 'allow' ? assertSucceeds : assertFails;

    await check(getBytes(ref(storage, ownerPath(EXISTING_FILE))));
    await check(uploadBytes(ref(storage, own), PNG, IMAGE));
    expect(await fileExists(own)).toBe(expected === 'allow');
  });
});

describe('storage deny-all · tanımsız yol (match /{allPaths=**})', () => {
  test.each(['anon', 'member', 'super'])('%s · read / create / delete → deny', async (role) => {
    await seedFile('other/file.png');
    const storage = contextFor(role).storage();
    await assertFails(getBytes(ref(storage, 'other/file.png')));
    await assertFails(uploadBytes(ref(storage, 'other/new.png'), PNG, IMAGE));
    await assertFails(uploadBytes(ref(storage, 'users/kok-duzeyi.png'), PNG, IMAGE));
    await assertFails(deleteObject(ref(storage, 'other/file.png')));
    expect(await fileExists('other/file.png')).toBe(true);
  });
});
