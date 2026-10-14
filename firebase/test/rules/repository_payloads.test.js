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
//  4. T-15 — `contract.t15.scenarios`: FirebaseMembershipRepository (M1–M4, M7, M8), FirebaseReportRepository
//     ve FirebaseBlockRepository'nin GERÇEK okuma + yazımları. Her senaryo kendi ön koşul belgeleriyle
//     (`seed`, kurallar kapalıyken) koşar; `tx: true` ise okumalar ve yazımlar repository'deki gibi TEK
//     transaction'dır (okumalar da kurallardan geçer: var olmayan kendi belgesi boş döner). `denied`
//     aynı çağrının kasıtlı bozuk biçimleridir (sayaçsız, yanlış durum, başkası adına …): reddedilir ve
//     hiçbir belge değişmez.
//  5. T-16 — ekranların gerçek çağrıları aynı listelerdedir: `updateApplicationNote` (CLB-05 "Kaydet";
//     yalnızca `private/contact.note`), CLB-03 kulüp şikayeti (`ReportRepository.report · kulüp`: hedef
//     kulübün kendisi) `t15.scenarios` içinde; SHT-07'nin üç `updateClubSettings` yazımı (tümünü sessize
//     al / sessizi kaldır / tek tür) öykü adımlarında (`steps`). SHT-05 `apply` / `joinInstant`
//     senaryoları T-15'ten beri listededir (M1–M4).
//  6. T-19 — `contract.t19.scenarios`: FirebasePostRepository, FirebaseCommentRepository,
//     FirebaseSavedPostRepository ve FirebaseAnnouncementCounterRepository'nin GERÇEK okuma + yazımları.
//     Her senaryo kendi bağlamıyla (`role`: üye, yönetim, danışman, süper admin) koşar; bağlamların
//     kullanıcı + üyelik belgeleri roles.json'dan, içerik belgeleri senaryonun `seed`'inden kurulur.
//     Ek nöbetçiler: `{"@arrayUnion": [uid]}` / `{"@arrayRemove": [uid]}`, `@daysAhead:N`, `merge: true`
//     (set(merge)), `@yyyyMMdd` / `@yyyy-MM-dd` (emülatörün Istanbul günü) ve koşu başına TEK `@autoId`
//     (yorum yolu ↔ `lastCommentRef`). Bildirimli duyuru, oy, sabitleme ve gönderi silme repository'deki
//     gibi tek transaction'dır: okumalar da kurallardan geçer.
//  7. T-22 — `contract.t22.scenarios`: FirebaseEventRepository ve FirebaseRsvpRepository'nin GERÇEK okuma +
//     yazımları (biçim `t19` ile aynı). Ek: `upload` (kapak — dosya senaryonun bağlamıyla, sözleşmedeki
//     `customMetadata` ile Storage'a yüklenir, sonra Firestore yazımı gider; Storage kuralı etkinlik belgesini
//     okumaz — W-73) ve kontenjan yarışı: kontenjan = 1 iken ikinci katılımcının eski okumaya dayanan `going`
//     yazımı Rules'ta reddedilir, aynı kişinin bekleme listesi yazımı geçer.
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const {
  Timestamp,
  arrayRemove,
  arrayUnion,
  collection,
  doc,
  getDoc,
  increment,
  runTransaction,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} = require('firebase/firestore');
const { getMetadata, ref, uploadBytes } = require('firebase/storage');
const contract = require('../contracts/repository_payloads.json');
const { contextFor, definition } = require('../helpers/contexts');
const { baseDocs, readDoc, seedDocs } = require('../helpers/fixtures');
const { istanbulDay } = require('../helpers/payloads');
const { getAdminContext } = require('../setup/env');

const SENTINEL = contract.serverTimestamp;
const INCREMENT = contract.t15.increment;
const ARRAY_UNION = contract.t19.arrayUnion;
const ARRAY_REMOVE = contract.t19.arrayRemove;
const DAYS_AHEAD = contract.t19.daysAhead;
const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * Sözleşmedeki nöbetçileri SDK nöbetçisine çevirir (iç içe map / liste dahil): `@serverTimestamp` →
 * `serverTimestamp()`, `{"@increment": n}` → `increment(n)`, `{"@arrayUnion": [...]}` / `{"@arrayRemove":
 * [...]}` → `arrayUnion(...)` / `arrayRemove(...)`, `@daysAhead:N` → şimdiden N gün sonrası (istemci saati).
 */
function materialize(value) {
  if (value === SENTINEL) return serverTimestamp();
  if (typeof value === 'string' && value.startsWith(DAYS_AHEAD)) {
    return Timestamp.fromMillis(Date.now() + Number(value.slice(DAYS_AHEAD.length)) * DAY_MS);
  }
  if (Array.isArray(value)) return value.map(materialize);
  if (value && typeof value === 'object') {
    const keys = Object.keys(value);
    if (keys.length === 1 && keys[0] === INCREMENT) return increment(value[INCREMENT]);
    if (keys.length === 1 && keys[0] === ARRAY_UNION) return arrayUnion(...value[ARRAY_UNION]);
    if (keys.length === 1 && keys[0] === ARRAY_REMOVE) return arrayRemove(...value[ARRAY_REMOVE]);
    return Object.fromEntries(Object.entries(value).map(([key, inner]) => [key, materialize(inner)]));
  }
  return value;
}

/** Tek yazımı `target`'a (batch / transaction) ya da — `target` yoksa — doğrudan gönderir. */
function applyWrite(db, target, write) {
  const ref = doc(db, write.path);
  const data = materialize(write.data);
  if (write.op === 'set') {
    // `merge: true` = SetOptions(merge: true): var olan belgede kurallar için update'tir.
    if (write.merge) return target ? target.set(ref, data, { merge: true }) : setDoc(ref, data, { merge: true });
    return target ? target.set(ref, data) : setDoc(ref, data);
  }
  if (write.op === 'update') return target ? target.update(ref, data) : updateDoc(ref, data);
  throw new Error(`bilinmeyen işlem: ${write.op}`);
}

/**
 * Bir adımın yazımlarını repository'nin gönderdiği biçimde gönderir: tek yazım doğrudan, birden çok
 * yazım tek batch (`FirestoreService.commitBatch`). Noktalı anahtar (`clubs.c01`) iki SDK'da da alan
 * yoludur.
 */
function send(db, writes) {
  if (writes.length === 1) return applyWrite(db, null, writes[0]);
  const batch = writeBatch(db);
  for (const write of writes) applyWrite(db, batch, write);
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

describe('T-15 · kulüp / üyelik / şikayet / engel — senaryolar (sahibi, kurallar açık)', () => {
  const t15 = contract.t15;
  const DAYS_AGO = '@daysAgo:';

  /** Ön koşul belgesindeki nöbetçiler: sunucu zamanı ve `@daysAgo:N` (negatif = gelecekte). */
  function seedValue(value) {
    if (value === SENTINEL) return serverTimestamp();
    if (typeof value === 'string' && value.startsWith(DAYS_AGO)) {
      return Timestamp.fromMillis(Date.now() - Number(value.slice(DAYS_AGO.length)) * DAY_MS);
    }
    if (Array.isArray(value)) return value.map(seedValue);
    if (value && typeof value === 'object') {
      return Object.fromEntries(Object.entries(value).map(([key, inner]) => [key, seedValue(inner)]));
    }
    return value;
  }

  /** `{"$fixture": ad, …}` → `fixtures[ad]` + üzerine yazılan alanlar (nöbetçiler çözülmeden). */
  function expand(entry) {
    const { $fixture: name, ...fields } = entry;
    if (name !== undefined && !t15.fixtures[name]) throw new Error(`bilinmeyen fixture: ${name}`);
    return { ...(name === undefined ? {} : t15.fixtures[name]), ...fields };
  }

  /**
   * Senaryonun ön koşul belgeleri; `variant.seed` yamaları üzerine yazılır. Gönderen başka bir bağlamsa
   * (`variant.role`) onun da etkin bir kullanıcı belgesi kurulur: ret "kullanıcı belgesi yok"tan değil,
   * "sahibi değil"den gelmelidir.
   */
  function seedOf(scenario, variant = {}) {
    const docs = Object.fromEntries(Object.entries(scenario.seed).map(([path, entry]) => [path, expand(entry)]));
    for (const [path, patch] of Object.entries(variant.seed || {})) docs[path] = { ...docs[path], ...expand(patch) };
    if (variant.role) docs[`users/${definition(variant.role).uid}`] = expand({ $fixture: 'user' });
    return Object.fromEntries(Object.entries(docs).map(([path, data]) => [path, seedValue(data)]));
  }

  /** Bozuk varyantın yazımları: `patch` alanları üzerine yazılır, `without` sıraları çıkarılır. */
  function writesOf(scenario, variant = {}) {
    const patch = variant.patch || {};
    const without = variant.without || [];
    return scenario.writes
      .map((write, index) => (patch[index] ? { ...write, data: { ...write.data, ...patch[index] } } : write))
      .filter((_write, index) => !without.includes(index));
  }

  /**
   * Senaryoyu repository'nin gönderdiği biçimde gönderir: `tx` ise okumalar + yazımlar tek transaction
   * (yeniden deneme yok); değilse okumalar tekil `get`, yazımlar `send`. `@autoId` yolu yeni bir kimlik alır.
   */
  async function run(db, scenario, writes) {
    const refOf = (path) => doc(db, path.replace(t15.autoId, doc(collection(db, 'activity')).id));
    if (scenario.tx) {
      return runTransaction(
        db,
        async (tx) => {
          for (const path of scenario.reads) await tx.get(refOf(path));
          for (const write of writes) {
            if (write.op === 'set') tx.set(refOf(write.path), materialize(write.data));
            else if (write.op === 'update') tx.update(refOf(write.path), materialize(write.data));
            else throw new Error(`bilinmeyen işlem: ${write.op}`);
          }
        },
        { maxAttempts: 1 },
      );
    }
    for (const path of scenario.reads) await getDoc(refOf(path));
    return writes.length === 0 ? undefined : send(db, writes);
  }

  /** Senaryonun dokunduğu sabit yollar (ön koşul + yazım; üretilen kimlikli günlük hariç). */
  const pathsOf = (scenario, seed) => [
    ...new Set([...Object.keys(seed), ...scenario.writes.map((write) => write.path)]),
  ].filter((path) => !path.includes(t15.autoId));

  async function snapshot(paths) {
    const out = {};
    for (const path of paths) out[path] = await readDoc(path);
    return out;
  }

  test('sözleşme: nöbetçiler ve bağlam', () => {
    expect(t15.autoId).toBe('@autoId');
    expect(INCREMENT).toBe('@increment');
    // Başvuranın kullanıcı belgesi etkin kullanıcıdır (activeUser()).
    expect(t15.fixtures.user).toMatchObject({ status: 'active', profileComplete: true });
    expect(t15.fixtures.contact.email).toBe(contract.email);
  });

  describe.each(t15.scenarios.map((scenario) => [scenario.call, scenario]))('%s', (_call, scenario) => {
    test('gerçek okuma + yazımlar geçer', async () => {
      const seed = seedOf(scenario);
      await seedDocs(seed);

      await assertSucceeds(run(ownerDb(), scenario, scenario.writes));

      for (const write of scenario.writes) {
        if (!write.path.includes(t15.autoId)) expect(await readDoc(write.path)).not.toBeNull();
      }
      for (const [path, fields] of Object.entries(scenario.expect || {})) {
        expect(await readDoc(path)).toMatchObject(fields);
      }
    });

    const denied = scenario.denied || [];
    if (denied.length === 0) return;
    test.each(denied.map((variant) => [variant.name, variant]))('ret: %s', async (_name, variant) => {
      const seed = seedOf(scenario, variant);
      await seedDocs(seed);
      const paths = pathsOf(scenario, seed);
      const before = await snapshot(paths);

      await assertFails(run(contextFor(variant.role || contract.role).firestore(), scenario, writesOf(scenario, variant)));

      expect(await snapshot(paths)).toEqual(before);
    });
  });
});

describe('T-19 · gönderi / yorum / oy / kayıt / duyuru sayacı — senaryolar (kendi bağlamı, kurallar açık)', () => {
  const t19 = contract.t19;
  const DAYS_AGO = '@daysAgo:';

  /** Bağlamların kullanıcı ve üyelik belgeleri (roles.json): `activeUser()` / `isMember()` bunları okur. */
  const identityDocs = () =>
    Object.fromEntries(Object.entries(baseDocs()).filter(([path]) => /^(users|memberships)\/[^/]+$/.test(path)));

  /** Koşunun yer tutucuları: üretilen TEK kimlik ve emülatörün (sunucunun) Istanbul günü. */
  function tokensFor(db) {
    const { key, day } = istanbulDay();
    return { [t19.autoId]: doc(collection(db, 'comments')).id, [t19.dayKey]: key, [t19.day]: day };
  }

  /** Dizgilerdeki (yol ve yük; iç içe map / liste dahil, anahtarlar hariç) yer tutucuları doldurur. */
  function fill(value, tokens) {
    if (typeof value === 'string') {
      return Object.entries(tokens).reduce((text, [token, actual]) => text.split(token).join(actual), value);
    }
    if (Array.isArray(value)) return value.map((inner) => fill(inner, tokens));
    if (value && typeof value === 'object') {
      return Object.fromEntries(Object.entries(value).map(([key, inner]) => [key, fill(inner, tokens)]));
    }
    return value;
  }

  /** Ön koşul belgesindeki nöbetçiler: sunucu zamanı ve `@daysAgo:N` (negatif = gelecekte). */
  function seedValue(value) {
    if (value === SENTINEL) return serverTimestamp();
    if (typeof value === 'string' && value.startsWith(DAYS_AGO)) {
      return Timestamp.fromMillis(Date.now() - Number(value.slice(DAYS_AGO.length)) * DAY_MS);
    }
    if (Array.isArray(value)) return value.map(seedValue);
    if (value && typeof value === 'object') {
      return Object.fromEntries(Object.entries(value).map(([key, inner]) => [key, seedValue(inner)]));
    }
    return value;
  }

  /** `{"$fixture": ad, …}` → `fixtures[ad]` + üzerine yazılan alanlar. */
  function expand(entry) {
    const { $fixture: name, ...fields } = entry;
    if (name !== undefined && !t19.fixtures[name]) throw new Error(`bilinmeyen fixture: ${name}`);
    return { ...(name === undefined ? {} : t19.fixtures[name]), ...fields };
  }

  /** Bağlam belgeleri + senaryonun içerik belgeleri; `variant.seed` yamaları üzerine yazılır. */
  function seedOf(scenario, variant, tokens) {
    const docs = Object.fromEntries(Object.entries(scenario.seed).map(([path, entry]) => [path, expand(entry)]));
    for (const [path, patch] of Object.entries(variant.seed || {})) {
      if (!docs[path]) throw new Error(`varyant yaması senaryoda olmayan belgeye: ${path}`);
      docs[path] = { ...docs[path], ...patch };
    }
    const content = Object.fromEntries(
      Object.entries(docs).map(([path, data]) => [fill(path, tokens), seedValue(fill(data, tokens))]),
    );
    return { ...identityDocs(), ...content };
  }

  /** Bozuk varyantın yazımları: `patch` alanları üzerine yazılır, `without` sıraları çıkarılır. */
  function writesOf(scenario, variant, tokens) {
    const patch = variant.patch || {};
    const without = variant.without || [];
    const writes = scenario.writes
      .map((write, index) => (patch[index] ? { ...write, data: { ...write.data, ...patch[index] } } : write))
      .filter((_write, index) => !without.includes(index));
    return fill(writes, tokens);
  }

  /**
   * Senaryoyu repository'nin gönderdiği biçimde gönderir: `tx` ise okumalar + yazımlar tek transaction
   * (yeniden deneme yok); değilse okumalar tekil `get`, yazımlar tek yazım ya da tek batch.
   */
  async function run(db, scenario, writes, tokens) {
    const reads = fill(scenario.reads, tokens);
    if (scenario.tx) {
      return runTransaction(
        db,
        async (tx) => {
          for (const path of reads) await tx.get(doc(db, path));
          for (const write of writes) applyWrite(db, tx, write);
        },
        { maxAttempts: 1 },
      );
    }
    for (const path of reads) await getDoc(doc(db, path));
    return writes.length === 0 ? undefined : send(db, writes);
  }

  async function snapshot(paths) {
    const out = {};
    for (const path of paths) out[path] = await readDoc(path);
    return out;
  }

  test('sözleşme: nöbetçiler ve bağlamlar roles.json ile aynı', () => {
    expect(t19.autoId).toBe(contract.t15.autoId);
    expect(t19.increment).toBe(INCREMENT);
    for (const [role, uid] of Object.entries(t19.actors)) expect(definition(role).uid).toBe(uid);
    // Yer tutucular birbirinin alt dizgisi değildir (doldurma sırası sonucu değiştirmez).
    expect(t19.dayKey.includes(t19.day) || t19.day.includes(t19.dayKey)).toBe(false);
    // Gün yer tutucusu Rules'un gün biçimleriyle aynı uzunluktadır.
    const { key, day } = istanbulDay();
    expect(key).toMatch(/^\d{8}$/);
    expect(day).toMatch(/^\d{4}-\d{2}-\d{2}$/);
  });

  describe.each(t19.scenarios.map((scenario) => [scenario.call, scenario]))('%s', (_call, scenario) => {
    test(`gerçek okuma + yazımlar geçer (${scenario.role})`, async () => {
      const db = contextFor(scenario.role).firestore();
      const tokens = tokensFor(db);
      await seedDocs(seedOf(scenario, {}, tokens));
      const writes = writesOf(scenario, {}, tokens);

      await assertSucceeds(run(db, scenario, writes, tokens));

      for (const write of writes) expect(await readDoc(write.path)).not.toBeNull();
      for (const [path, fields] of Object.entries(scenario.expect || {})) {
        expect(await readDoc(fill(path, tokens))).toMatchObject(fill(fields, tokens));
      }
    });

    const denied = scenario.denied || [];
    if (denied.length === 0) return;
    test.each(denied.map((variant) => [variant.name, variant]))('ret: %s', async (_name, variant) => {
      const db = contextFor(variant.role || scenario.role).firestore();
      const tokens = tokensFor(db);
      const seed = seedOf(scenario, variant, tokens);
      await seedDocs(seed);
      const writes = writesOf(scenario, variant, tokens);
      const paths = [...new Set([...Object.keys(seed), ...writes.map((write) => write.path)])];
      const before = await snapshot(paths);

      await assertFails(run(db, scenario, writes, tokens));

      expect(await snapshot(paths)).toEqual(before);
    });
  });
});

describe('T-22 · etkinlik / katılım — senaryolar (kendi bağlamı, kurallar açık)', () => {
  const t22 = contract.t22;
  const DAYS_AGO = '@daysAgo:';
  /** Kapak yüklemesinin baytları (ImagePickerService her zaman JPEG üretir). */
  const JPEG = Uint8Array.from([0xff, 0xd8, 0xff, 0xe0]);

  /** Bağlamların kullanıcı ve üyelik belgeleri (roles.json): `activeUser()` / `isMember()` bunları okur. */
  const identityDocs = () =>
    Object.fromEntries(Object.entries(baseDocs()).filter(([path]) => /^(users|memberships)\/[^/]+$/.test(path)));

  /** Koşunun TEK üretilen kimliği (yeni etkinlik: yol, coverSeed, günlük kimliği). */
  const tokensFor = (db) => ({ [t22.autoId]: doc(collection(db, 'events')).id });

  function fill(value, tokens) {
    if (typeof value === 'string') {
      return Object.entries(tokens).reduce((text, [token, actual]) => text.split(token).join(actual), value);
    }
    if (Array.isArray(value)) return value.map((inner) => fill(inner, tokens));
    if (value && typeof value === 'object') {
      return Object.fromEntries(Object.entries(value).map(([key, inner]) => [key, fill(inner, tokens)]));
    }
    return value;
  }

  /** Ön koşul belgesindeki nöbetçiler: sunucu zamanı ve `@daysAgo:N` (negatif = gelecekte). */
  function seedValue(value) {
    if (value === SENTINEL) return serverTimestamp();
    if (typeof value === 'string' && value.startsWith(DAYS_AGO)) {
      return Timestamp.fromMillis(Date.now() - Number(value.slice(DAYS_AGO.length)) * DAY_MS);
    }
    if (Array.isArray(value)) return value.map(seedValue);
    if (value && typeof value === 'object') {
      return Object.fromEntries(Object.entries(value).map(([key, inner]) => [key, seedValue(inner)]));
    }
    return value;
  }

  function expand(entry) {
    const { $fixture: name, ...fields } = entry;
    if (name !== undefined && !t22.fixtures[name]) throw new Error(`bilinmeyen fixture: ${name}`);
    return { ...(name === undefined ? {} : t22.fixtures[name]), ...fields };
  }

  function seedOf(scenario, variant, tokens) {
    const docs = Object.fromEntries(Object.entries(scenario.seed).map(([path, entry]) => [path, expand(entry)]));
    for (const [path, patch] of Object.entries(variant.seed || {})) {
      if (!docs[path]) throw new Error(`varyant yaması senaryoda olmayan belgeye: ${path}`);
      docs[path] = { ...docs[path], ...patch };
    }
    const content = Object.fromEntries(
      Object.entries(docs).map(([path, data]) => [fill(path, tokens), seedValue(fill(data, tokens))]),
    );
    return { ...identityDocs(), ...content };
  }

  function writesOf(scenario, variant, tokens) {
    const patch = variant.patch || {};
    const without = variant.without || [];
    const writes = scenario.writes
      .map((write, index) => (patch[index] ? { ...write, data: { ...write.data, ...patch[index] } } : write))
      .filter((_write, index) => !without.includes(index));
    return fill(writes, tokens);
  }

  /** Senaryoyu repository'nin gönderdiği biçimde gönderir (`tx`: okumalar + yazımlar tek transaction). */
  async function run(db, scenario, writes, tokens) {
    const reads = fill(scenario.reads, tokens);
    if (scenario.tx) {
      return runTransaction(
        db,
        async (tx) => {
          for (const path of reads) await tx.get(doc(db, path));
          for (const write of writes) applyWrite(db, tx, write);
        },
        { maxAttempts: 1 },
      );
    }
    for (const path of reads) await getDoc(doc(db, path));
    return writes.length === 0 ? undefined : send(db, writes);
  }

  /** Kapak dosyasını sözleşmedeki yol, tür ve üst veriyle [role] bağlamından yükler. */
  const uploadOf = (role, upload) =>
    uploadBytes(ref(contextFor(role).storage(), upload.path), JPEG, {
      contentType: upload.contentType,
      customMetadata: upload.customMetadata,
    });

  async function snapshot(paths) {
    const out = {};
    for (const path of paths) out[path] = await readDoc(path);
    return out;
  }

  const scenarioOf = (call) => t22.scenarios.find((scenario) => scenario.call === call);

  test('sözleşme: nöbetçiler ve bağlamlar roles.json ile aynı; etkinlik yazımlarında lastRsvpRef yok (W-64)', () => {
    expect(t22.autoId).toBe(contract.t15.autoId);
    expect(t22.increment).toBe(INCREMENT);
    expect(t22.daysAhead).toBe(DAYS_AHEAD);
    for (const [role, uid] of Object.entries(t22.actors)) expect(definition(role).uid).toBe(uid);
    const eventWrites = t22.scenarios.flatMap((scenario) => scenario.writes).filter((write) => write.path.startsWith('events/'));
    expect(eventWrites.length).toBeGreaterThan(10);
    expect(eventWrites.filter((write) => 'lastRsvpRef' in write.data)).toEqual([]);
  });

  describe.each(t22.scenarios.map((scenario) => [scenario.call, scenario]))('%s', (_call, scenario) => {
    test(`gerçek okuma + yazımlar geçer (${scenario.role})`, async () => {
      const db = contextFor(scenario.role).firestore();
      const tokens = tokensFor(db);
      await seedDocs(seedOf(scenario, {}, tokens));
      const writes = writesOf(scenario, {}, tokens);

      if (scenario.upload) await assertSucceeds(uploadOf(scenario.role, scenario.upload));
      await assertSucceeds(run(db, scenario, writes, tokens));

      for (const write of writes) expect(await readDoc(write.path)).not.toBeNull();
      for (const [path, fields] of Object.entries(scenario.expect || {})) {
        expect(await readDoc(fill(path, tokens))).toMatchObject(fill(fields, tokens));
      }
      if (scenario.upload) {
        const meta = await getMetadata(ref((await getAdminContext()).storage(), scenario.upload.path));
        expect(meta.customMetadata).toEqual(scenario.upload.customMetadata);
      }
    });

    const denied = scenario.denied || [];
    if (denied.length === 0) return;
    test.each(denied.map((variant) => [variant.name, variant]))('ret: %s', async (_name, variant) => {
      const db = contextFor(variant.role || scenario.role).firestore();
      const tokens = tokensFor(db);
      const seed = seedOf(scenario, variant, tokens);
      await seedDocs(seed);
      const writes = writesOf(scenario, variant, tokens);
      const paths = [...new Set([...Object.keys(seed), ...writes.map((write) => write.path)])];
      const before = await snapshot(paths);

      await assertFails(run(db, scenario, writes, tokens));

      expect(await snapshot(paths)).toEqual(before);
    });
  });

  test('kapak yüklemesi: başka kulübün yöneticisi yükleyemez (Storage: metadata.clubId kulübünün yöneticisi)', async () => {
    const scenario = scenarioOf('EventRepository.uploadCover');
    await seedDocs(seedOf(scenario, {}, {}));

    await assertFails(uploadOf('otherManager', { ...scenario.upload, customMetadata: { ...scenario.upload.customMetadata, uploaderId: 'u_mgr2' } }));
    await assertFails(uploadOf('member', { ...scenario.upload, customMetadata: { ...scenario.upload.customMetadata, uploaderId: 'u_member' } }));
  });

  describe('kontenjan yarışı (kontenjan = 1) — Rules son savunma hattı', () => {
    const going = () => scenarioOf('RsvpRepository.join · yeni kayıt (going)');
    const waitlist = () => scenarioOf('RsvpRepository.join · kontenjan dolu → bekleme listesi');
    /** Öğrencinin yazımlarını üyenin kaydına çevirir (aynı yük, başka sahip). */
    const asMember = (writes) => JSON.parse(JSON.stringify(writes).split('u_student').join('u_member'));
    const E = 'events/e01';

    async function seedRace() {
      const scenario = going();
      await seedDocs(seedOf(scenario, { seed: { [E]: { capacity: 1, goingCount: 0 } } }, {}));
    }

    test('ilk katılım going geçer; ikinci katılımcının eski okumaya (kayıtlı 0) dayanan going yazımı RET; bekleme listesi yazımı geçer', async () => {
      await seedRace();
      const student = contextFor('student').firestore();
      const member = contextFor('member').firestore();

      await assertSucceeds(run(student, going(), going().writes, {}));
      // Üyenin işlemi öğrencininkinden ÖNCE okumuştu (kayıtlı 0 → going): sunucu çakışmayı yakalamasa da
      // etkinliğin sayaç dalı kayıtlı sayısının kontenjanı aşmasını reddeder.
      await assertFails(send(member, asMember(going().writes)));
      expect(await readDoc(E)).toMatchObject({ capacity: 1, goingCount: 1, waitlistCount: 0 });
      expect(await readDoc('rsvps/e01_u_member')).toBeNull();

      // Yeniden koşan işlem güncel sayacı (1/1) görür → bekleme listesi.
      const memberWaitlist = { ...waitlist(), reads: asMember(waitlist().reads) };
      await assertSucceeds(run(member, memberWaitlist, asMember(waitlist().writes), {}));
      expect(await readDoc(E)).toMatchObject({ goingCount: 1, waitlistCount: 1 });
      expect(await readDoc('rsvps/e01_u_member')).toMatchObject({ status: 'waitlist', userId: 'u_member' });
    });

    // Emülatör bulgusu: aynı anda okuyan iki işlemden kaybedenin commit'i çakışma (yeniden deneme) yerine
    // Security Rules'a takılır — `permission-denied`, SDK yeniden denemez. FirebaseRsvpRepository.join bu
    // yüzden Rules reddinde işlemi güncel sayaçla BİR KEZ daha koşar (Dart: firebase_rsvp_repository_test
    // "Rules reddinde tek yeniden deneme").
    test('iki eşzamanlı katılım (repository kararı + tek yeniden deneme, gerçek transaction): biri going, biri bekleme listesi; sayaçlar 1 / 1', async () => {
      await seedRace();
      /** Repository'nin kararı: işlemde okunan sayaçtan; yer yoksa bekleme listesi yükü. */
      const attempt = (role, convert) => {
        const db = contextFor(role).firestore();
        return runTransaction(db, async (tx) => {
          const event = (await tx.get(doc(db, E))).data();
          await tx.get(doc(db, convert(going().reads)[1]));
          const full = event.capacity != null && event.goingCount >= event.capacity;
          for (const write of convert((full ? waitlist() : going()).writes)) applyWrite(db, tx, write);
          return full ? 'waitlist' : 'going';
        });
      };
      const denials = [];
      const join = (role, convert) =>
        attempt(role, convert).catch((error) => {
          if (error.code !== 'permission-denied') throw error;
          denials.push(role);
          return attempt(role, convert);
        });

      const outcomes = await Promise.all([join('student', (x) => x), join('member', asMember)]);

      expect([...outcomes].sort()).toEqual(['going', 'waitlist']);
      expect(denials.length).toBeLessThanOrEqual(1);
      expect(await readDoc(E)).toMatchObject({ capacity: 1, goingCount: 1, waitlistCount: 1 });
    });
  });
});

// 8. T-25 — `contract.t25.scenarios`: FirebaseNotificationRepository (NotificationRepository + NotificationWriter)
//    ve ClientFanOutDispatcher'ın GERÇEK yükleri (biçim `t22` ile aynı). `@autoId` olay anahtarıdır (koşu başına
//    TEK Firestore otomatik kimliği: bir notifyX çağrısının tüm alıcıları aynı anahtarı paylaşır); `batches`
//    yazımların ayrı commit'lere bölünüşüdür (application_received alıcı başına ayrı batch). Kritik bildirim
//    (waitlist_promoted) terfi yazımlarıyla AYNI batch'te geçer, tek başına reddedilir.
describe('T-25 · bildirimler — senaryolar (kendi bağlamı, kurallar açık)', () => {
  const t25 = contract.t25;
  const DAYS_AGO = '@daysAgo:';

  const identityDocs = () =>
    Object.fromEntries(Object.entries(baseDocs()).filter(([path]) => /^(users|memberships)\/[^/]+$/.test(path)));

  /** Koşunun TEK olay anahtarı (NotificationWriter.newEventKey biçimi). */
  const tokensFor = (db) => ({ [t25.autoId]: doc(collection(db, 'notifications')).id });

  function fill(value, tokens) {
    if (typeof value === 'string') {
      return Object.entries(tokens).reduce((text, [token, actual]) => text.split(token).join(actual), value);
    }
    if (Array.isArray(value)) return value.map((inner) => fill(inner, tokens));
    if (value && typeof value === 'object') {
      return Object.fromEntries(Object.entries(value).map(([key, inner]) => [key, fill(inner, tokens)]));
    }
    return value;
  }

  function seedValue(value) {
    if (value === SENTINEL) return serverTimestamp();
    if (typeof value === 'string' && value.startsWith(DAYS_AGO)) {
      return Timestamp.fromMillis(Date.now() - Number(value.slice(DAYS_AGO.length)) * DAY_MS);
    }
    if (Array.isArray(value)) return value.map(seedValue);
    if (value && typeof value === 'object') {
      return Object.fromEntries(Object.entries(value).map(([key, inner]) => [key, seedValue(inner)]));
    }
    return value;
  }

  function expand(entry) {
    const { $fixture: name, ...fields } = entry;
    if (name !== undefined && !t25.fixtures[name]) throw new Error(`bilinmeyen fixture: ${name}`);
    return { ...(name === undefined ? {} : t25.fixtures[name]), ...fields };
  }

  function seedOf(scenario, variant, tokens) {
    const docs = Object.fromEntries(Object.entries(scenario.seed).map(([path, entry]) => [path, expand(entry)]));
    for (const [path, patch] of Object.entries(variant.seed || {})) {
      if (!docs[path]) throw new Error(`varyant yaması senaryoda olmayan belgeye: ${path}`);
      docs[path] = { ...docs[path], ...patch };
    }
    const content = Object.fromEntries(
      Object.entries(docs).map(([path, data]) => [fill(path, tokens), seedValue(fill(data, tokens))]),
    );
    return { ...identityDocs(), ...content };
  }

  /** Yazımlar commit gruplarıyla: `batches` yoksa tümü tek grup; `without` ile çıkarılan sıralar gruptan düşer. */
  function groupsOf(scenario, variant, tokens) {
    const patch = variant.patch || {};
    const without = variant.without || [];
    const all = scenario.writes.map((write, index) => (patch[index] ? { ...write, data: { ...write.data, ...patch[index] } } : write));
    const batches = scenario.batches || [all.map((_write, index) => index)];
    return batches
      .map((indexes) => indexes.filter((index) => !without.includes(index)).map((index) => fill(all[index], tokens)))
      .filter((group) => group.length > 0);
  }

  /** Senaryoyu repository'nin gönderdiği biçimde gönderir: okumalar, sonra her grup ayrı commit (sırayla). */
  async function run(db, scenario, groups, tokens) {
    for (const path of fill(scenario.reads, tokens)) await getDoc(doc(db, path));
    for (const group of groups) await send(db, group);
  }

  async function snapshot(paths) {
    const out = {};
    for (const path of paths) out[path] = await readDoc(path);
    return out;
  }

  test('sözleşme: bağlamlar roles.json ile aynı; bildirim yüklerinde metin / aktör alanı yok, refs yalnızca dolu (W-51)', () => {
    expect(t25.autoId).toBe(contract.t15.autoId);
    for (const [role, uid] of Object.entries(t25.actors)) expect(definition(role).uid).toBe(uid);
    const created = t25.scenarios
      .flatMap((scenario) => scenario.writes)
      .filter((write) => write.op === 'set' && write.path.startsWith('notifications/'));
    expect(created.length).toBeGreaterThanOrEqual(10);
    for (const write of created) {
      expect(Object.keys(write.data).sort()).toEqual(
        ['createdAt', 'deletedAt', 'deletedBy', 'isDeleted', 'read', 'refs', 'type', 'updatedAt', 'userId'],
      );
      expect(Object.values(write.data.refs).every((value) => typeof value === 'string' && value.length > 0)).toBe(true);
      expect(write.path.endsWith(`_${write.data.userId}`)).toBe(true);
    }
  });

  describe.each(t25.scenarios.map((scenario) => [scenario.call, scenario]))('%s', (_call, scenario) => {
    test(`gerçek okuma + yazımlar geçer (${scenario.role})`, async () => {
      const db = contextFor(scenario.role).firestore();
      const tokens = tokensFor(db);
      await seedDocs(seedOf(scenario, {}, tokens));
      const groups = groupsOf(scenario, {}, tokens);

      await assertSucceeds(run(db, scenario, groups, tokens));

      for (const write of groups.flat()) expect(await readDoc(write.path)).not.toBeNull();
      for (const [path, fields] of Object.entries(scenario.expect || {})) {
        expect(await readDoc(fill(path, tokens))).toMatchObject(fill(fields, tokens));
      }
    });

    const denied = scenario.denied || [];
    if (denied.length === 0) return;
    test.each(denied.map((variant) => [variant.name, variant]))('ret: %s', async (_name, variant) => {
      const db = contextFor(variant.role || scenario.role).firestore();
      const tokens = tokensFor(db);
      const seed = seedOf(scenario, variant, tokens);
      await seedDocs(seed);
      const groups = groupsOf(scenario, variant, tokens);
      const paths = [...new Set([...Object.keys(seed), ...groups.flat().map((write) => write.path)])];
      const before = await snapshot(paths);

      await assertFails(run(db, scenario, groups, tokens));

      expect(await snapshot(paths)).toEqual(before);
    });
  });

  test.each([
    ['NotificationDispatcher.notifyEventNew', 'tekrarlanabilen olay: yeni anahtar → yeni belge', 'allow'],
    ['NotificationDispatcher.notifyAnnouncement', 'tek seferlik olay (kimlik = postId): hiçbir anahtarla yeniden itilemez — CD-148', 'deny'],
  ])('aynı olayın kesinleşmiş parçası yeniden gönderilirse ret (ikinci set = update — W-49) · %s · %s', async (call, _title, again) => {
    const scenario = t25.scenarios.find((s) => s.call === call);
    const db = contextFor(scenario.role).firestore();
    const tokens = tokensFor(db);
    await seedDocs(seedOf(scenario, {}, tokens));
    const groups = groupsOf(scenario, {}, tokens);

    await assertSucceeds(run(db, scenario, groups, tokens));
    await assertFails(run(db, scenario, groups, tokens));
    const next = tokensFor(db);
    const repeat = run(db, scenario, groupsOf(scenario, {}, next), next);
    await (again === 'allow' ? assertSucceeds(repeat) : assertFails(repeat));
  });
});
