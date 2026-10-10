'use strict';
// T-10 — Storage varsayılan ret (PLAN §11.5): beş yol kökü × her bağlam için okuma, yükleme,
// üzerine yazma/metadata güncelleme ve silme reddedilir. Yollar sahibi task'ta açılır
// (users/ T-14 · clubs/ T-16 · events/ T-22 · posts/ T-21 · support/ T-28); `update` ve `delete`
// her zaman kapalı kalır (D-10: dosya silinmez, üzerine yazılmaz).
const fs = require('node:fs');
const { assertFails } = require('@firebase/rules-unit-testing');
const { deleteObject, getBytes, getMetadata, ref, updateMetadata, uploadBytes } = require('firebase/storage');
const { getAdminContext } = require('../setup/env');
const { rulesPath } = require('../setup/emulator_ports');
const { CONTEXTS, VARIANTS, contextFor } = require('../helpers/contexts');
const { STORAGE_PREFIX, parseMatches } = require('../helpers/matrix');

/** Okuma/yükleme kuralları açılmış yol kökleri. T-10: hiçbiri. */
const OPENED = [];

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
});

describe.each(ROOTS.filter((r) => !OPENED.includes(r)))('storage deny-all · %s/{id}/{file}', (root) => {
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
