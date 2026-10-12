'use strict';
// T-12 — Repository ↔ Rules yük sözleşmesi (uçtan uca; CLAUDE.md §9 "yazma yolu = Rules + testi").
//
// `contracts/repository_payloads.json` repository'lerin Firestore'a gönderdiği GERÇEK yazımlardır:
// Dart tarafı (packages/gu_data/test/repositories/rules_payload_contract_test.dart) gerçek
// FirebaseUserRepository / FirebaseSettingsRepository'nin SDK'ya verdiği ham yükün bu dosyayla birebir
// aynı olduğunu doğrular. Bu dosya aynı yazımları emülatörde, kurallar AÇIKKEN, hesabın sahibi olarak
// gönderir: hepsi geçmelidir. Böylece "repository'nin yazdığı her alan Rules beyaz listesinde" iddiası
// elle kopyalanmış bir yük (helpers/payloads.js) yerine tek kaynaktan sınanır.
//
//  1. Öykü adımları: her adım, önceki adımların bıraktığı belgeler üzerinde koşar (önceki adımlar
//     kurallar kapalıyken aynı yüklerle kurulur).
//  2. Akış kısıtları (repository yükü doğru olsa da çağrı SIRASI yanlışsa ret): doğrulanmamış oturum
//     profil oluşturamaz; profil tamamlanmadan (interests boş) tek alanlı güncelleme geçmez.
//  3. T-14 — AUT-05'in GERÇEK yazım sırası (`contract.aut05`; SetupProfileViewModel.submit):
//     createProfile → tamamlama yaması → Storage yüklemesi → avatarPath. Önceki adımlar da kurallar
//     AÇIKKEN, hesabın sahibi olarak gönderilir (yeniden oynatma yok): sıra baştan sona geçer; ters sıra
//     (önce fotoğraf) reddedilir. Storage yüklemesi profil belgesini okur (`accountActive()`:
//     `users/{uid}.status == 'active'`): createProfile'dan ÖNCE yükleme reddedilir, sonrasında —
//     profil tamamlanmamış olsa da — geçer.
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, serverTimestamp, setDoc, updateDoc, writeBatch } = require('firebase/firestore');
const { getMetadata, ref, uploadBytes } = require('firebase/storage');
const contract = require('../contracts/repository_payloads.json');
const { contextFor, definition } = require('../helpers/contexts');
const { readDoc } = require('../helpers/fixtures');
const { getAdminContext } = require('../setup/env');

const SENTINEL = contract.serverTimestamp;

/** Sözleşmedeki `@serverTimestamp` nöbetçilerini SDK nöbetçisine çevirir (iç içe map / liste dahil). */
function materialize(value) {
  if (value === SENTINEL) return serverTimestamp();
  if (Array.isArray(value)) return value.map(materialize);
  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.entries(value).map(([key, inner]) => [key, materialize(inner)]));
  }
  return value;
}

/**
 * Bir adımın yazımlarını repository'nin gönderdiği biçimde gönderir: tek yazım doğrudan, birden çok
 * yazım tek batch (`FirestoreService.commitBatch`). Noktalı anahtar (`clubs.c01`) iki SDK'da da alan
 * yoludur.
 */
function send(db, writes) {
  const apply = (target, write) => {
    const ref = doc(db, write.path);
    const data = materialize(write.data);
    if (write.op === 'set') return target ? target.set(ref, data) : setDoc(ref, data);
    if (write.op === 'update') return target ? target.update(ref, data) : updateDoc(ref, data);
    throw new Error(`bilinmeyen işlem: ${write.op}`);
  };
  if (writes.length === 1) return apply(null, writes[0]);
  const batch = writeBatch(db);
  for (const write of writes) apply(batch, write);
  return batch.commit();
}

/** Verilen adımları kuralları atlayarak uygular (öykünün önceki adımları). */
async function replay(steps) {
  const db = (await getAdminContext()).firestore();
  for (const step of steps) await send(db, step.writes);
}

const ownerDb = () => contextFor(contract.role).firestore();
const stepByCall = (call) => contract.steps.find((step) => step.call === call);

describe('sözleşme bağlamı', () => {
  test('uid ve e-posta roles.json bağlamıyla aynı (token e-postası = private/account.email)', () => {
    const def = definition(contract.role);
    expect(contract.uid).toBe(def.uid);
    expect(contract.email).toBe(def.token.email);
    expect(def.token.email_verified).toBe(true);
  });
});

describe('repository yazımları kurallardan geçer — öykü (sahibi, kurallar açık)', () => {
  test.each(contract.steps.map((step, index) => [step.call, index]))('%s', async (_call, index) => {
    await replay(contract.steps.slice(0, index));
    const step = contract.steps[index];

    await assertSucceeds(send(ownerDb(), step.writes));

    for (const write of step.writes) expect(await readDoc(write.path)).not.toBeNull();
  });
});

describe('repository yazımları kurallardan geçer — boş veritabanı', () => {
  test.each(contract.standalone.map((step) => [step.call, step]))('%s', async (_call, step) => {
    await assertSucceeds(send(ownerDb(), step.writes));

    for (const write of step.writes) expect(await readDoc(write.path)).not.toBeNull();
  });
});

describe('akış kısıtları — yük doğru, çağrı sırası yanlış → ret', () => {
  const createProfile = stepByCall('UserRepository.createProfile');

  test('doğrulanmamış oturum (kayıttan hemen sonra) profil oluşturamaz: createProfile doğrulama SONRASI çağrılır', async () => {
    const def = definition('unver');
    const retarget = (value) =>
      JSON.parse(JSON.stringify(value).split(contract.uid).join(def.uid).split(contract.email).join(def.token.email));

    await assertFails(send(contextFor('unver').firestore(), retarget(createProfile.writes)));

    for (const write of retarget(createProfile.writes)) expect(await readDoc(write.path)).toBeNull();
  });

  test('profil tamamlanmadan (interests boş) tek alanlı güncelleme reddedilir: AUT-05 yaması önce gider', async () => {
    await replay([createProfile]);
    const before = await readDoc(`users/${contract.uid}`);

    await assertFails(send(ownerDb(), stepByCall('UserRepository.updateProfile · profil fotoğrafı').writes));

    expect(await readDoc(`users/${contract.uid}`)).toEqual(before);
  });
});

describe('AUT-05 gerçek yazım sırası (SetupProfileViewModel.submit) — sahibi, kurallar açık, baştan sona', () => {
  const [create, complete, avatar] = contract.aut05.map(stepByCall);
  const userPath = `users/${contract.uid}`;
  const avatarPath = avatar.writes[0].data.avatarPath;
  /** ImagePickerService her zaman JPEG üretir; repository dosyayı `avatarPath` yoluna yükler. */
  const JPEG = Uint8Array.from([0xff, 0xd8, 0xff, 0xe0]);
  const uploadAvatar = (role = contract.role) =>
    uploadBytes(ref(contextFor(role).storage(), avatarPath), JPEG, { contentType: 'image/jpeg' });

  test('sözleşme: üç adım sırayla createProfile → updateProfile → updateAvatar; avatar yolu users/{uid}/<StoragePaths.newFileName>.jpg', () => {
    expect(contract.aut05).toHaveLength(3);
    expect(contract.steps.slice(0, 3).map((step) => step.call)).toEqual(contract.aut05);
    // Tamamlama yaması ad taşımaz (CD-134) ve fotoğraf alanına dokunmaz.
    expect(Object.keys(complete.writes[0].data).sort()).toEqual(['department', 'interests', 'profileComplete', 'updatedAt', 'year']);
    expect(Object.keys(avatar.writes[0].data).sort()).toEqual(['avatarPath', 'updatedAt']);
    expect(avatarPath).toMatch(new RegExp(`^users/${contract.uid}/\\d{8}T\\d{6}Z_[0-9a-f]{16}\\.jpg$`));
  });

  test('createProfile → tamamlama yaması → Storage yüklemesi → avatarPath: hepsi geçer', async () => {
    const db = ownerDb();

    await assertSucceeds(send(db, create.writes));
    await assertSucceeds(send(db, complete.writes));
    await assertSucceeds(uploadAvatar());
    await assertSucceeds(send(db, avatar.writes));

    expect(await readDoc(userPath)).toMatchObject({
      department: 'd02',
      year: '2',
      interests: ['i01', 'i05'],
      profileComplete: true,
      avatarPath,
      status: 'active',
      staff: false,
      isDeleted: false,
    });
    expect(await readDoc(`${userPath}/private/account`)).toMatchObject({ email: contract.email });
    expect(await readDoc(`settings/${contract.uid}`)).not.toBeNull();
  });

  test('fotoğrafsız akış: createProfile → tamamlama yaması yeterlidir (avatarPath hiç yazılmaz)', async () => {
    const db = ownerDb();

    await assertSucceeds(send(db, create.writes));
    await assertSucceeds(send(db, complete.writes));

    const user = await readDoc(userPath);
    expect(user.profileComplete).toBe(true);
    expect(user).not.toHaveProperty('avatarPath');
  });

  test('ters sıra (önce fotoğraf): dosya yüklenir ama avatarPath yazımı reddedilir; tamamlama yamasından sonra aynı yazım geçer', async () => {
    const db = ownerDb();
    await assertSucceeds(send(db, create.writes));
    // Storage kuralı yalnızca hesabın etkin olduğunu okur (`status == 'active'`), `profileComplete`'e
    // bakmaz: yükleme profil tamamlanmadan da geçer.
    await assertSucceeds(uploadAvatar());
    const before = await readDoc(userPath);

    await assertFails(send(db, avatar.writes));
    expect(await readDoc(userPath)).toEqual(before);

    await assertSucceeds(send(db, complete.writes));
    await assertSucceeds(send(db, avatar.writes));
    expect((await readDoc(userPath)).avatarPath).toBe(avatarPath);
  });

  test('createProfile atlanırsa (belge yok) tamamlama yaması, Storage yüklemesi ve avatarPath yazımı reddedilir', async () => {
    const db = ownerDb();

    await assertFails(send(db, complete.writes));
    // Storage `accountActive()`: profil belgesi olmayan oturum dosya yükleyemez.
    await assertFails(uploadAvatar());
    await assertFails(send(db, avatar.writes));

    expect(await readDoc(userPath)).toBeNull();
    // Reddedilen yükleme dosya bırakmaz (kurallar kapalıyken bakılır).
    await expect(getMetadata(ref((await getAdminContext()).storage(), avatarPath))).rejects.toMatchObject({
      code: 'storage/object-not-found',
    });
  });

  test('hesap askıya alınınca (users.status) Storage yüklemesi ve avatarPath yazımı reddedilir', async () => {
    const db = ownerDb();
    await assertSucceeds(send(db, create.writes));
    await assertSucceeds(send(db, complete.writes));
    // Askı süper adminin yazımıdır; burada kurallar kapalıyken kurulur.
    await updateDoc(doc((await getAdminContext()).firestore(), userPath), { status: 'suspended' });

    await assertFails(uploadAvatar());
    await assertFails(send(db, avatar.writes));

    expect((await readDoc(userPath)).status).toBe('suspended');
    expect(await readDoc(userPath)).not.toHaveProperty('avatarPath');
  });

  test('tamamlama yaması ilgi alanı olmadan reddedilir (öğrenci; interestsMin)', async () => {
    const db = ownerDb();
    await assertSucceeds(send(db, create.writes));
    const empty = [{ ...complete.writes[0], data: { ...complete.writes[0].data, interests: [] } }];

    await assertFails(send(db, empty));

    expect((await readDoc(userPath)).profileComplete).toBe(false);
  });

  test('başka kullanıcı aynı yazımları sahibinin belgesine ve klasörüne gönderemez', async () => {
    await assertSucceeds(send(ownerDb(), create.writes));
    const before = await readDoc(userPath);
    const other = contextFor('member').firestore();

    await assertFails(send(other, complete.writes));
    await assertFails(uploadAvatar('member'));
    await assertFails(send(other, avatar.writes));

    expect(await readDoc(userPath)).toEqual(before);
  });
});
