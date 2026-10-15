'use strict';
// T-12 — `users/{uid}` ve `users/{uid}/private/account` (rules-spec §3.1, §3.2; PLAN §11.1 satır 1–2).
//
//  1. Rol × işlem matrisi: `expectations/users.json`, `expectations/private_account.json`.
//  2. Alan beyaz listesi, tipler ve sınırlar (create / update): tablo testleri. Sınır değerleri Dart
//     `Limits` kaynağından okunur ("Limits.<ad> geçer, + 1 reddedilir").
//  3. Sunucu zamanı: `createdAt` / `updatedAt` / `lastLoginAt` istemci saatiyle yazılamaz.
//  4. Null alanın iki biçimi (W-51, CD-130): anahtar yok (istemci) ve açık `null` (seed).
//  5. `suspendReason` (CD-133): `users` belgesinin alanı değildir; `private/account`'ta sahibi için
//     salt okunurdur (askıdaki kullanıcı okur, değiştiremez, silemez).
//  6. Sorgu sözleşmesi (rules-spec §6 ADM-05; PLAN §10.4 `getUsers`).
//  7. Güvenlik incelemesi (CD-133 madde 14): profil ↔ hesap belgesi birlikte oluşur (`existsAfter`),
//     `fcmTokens` eleman biçimi, `avatarSeed` / `avatarPath` / ad sınırları, `profileComplete` koşulu.
//
// Süper adminin askıya alma yolu (`users.status` + `account.suspendReason` tek batch) T-37'de açıldı — tek başına
// yazım reddedilir (matris satırları), tam batch `admin.test.js`; hesap silme (`deleted` dalı) T-29.
const path = require('node:path');
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const {
  Timestamp,
  collection,
  deleteField,
  doc,
  documentId,
  getDoc,
  getDocs,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} = require('firebase/firestore');
const { contextFor } = require('../helpers/contexts');
const { baseDocs, editDocs, readDoc, seedDocs } = require('../helpers/fixtures');
const { runMatrix } = require('../helpers/matrix');
const payloads = require('../helpers/payloads');

const REPO_ROOT = path.resolve(__dirname, '..', '..', '..');
const limits = require(path.join(REPO_ROOT, 'tool', 'lib', 'dart_sources.js')).readLimits(REPO_ROOT).ints;

const UID = 'u_student';
const USER = `users/${UID}`;
const ACCOUNT = `${USER}/private/account`;
const SETTINGS = `settings/${UID}`;
const EMAIL = payloads.emailOf('student');

const studentDb = () => contextFor('student').firestore();
/** İstemci saatinden üretilmiş zaman damgası (`request.time` ile eşleşmez). */
const clientTime = () => Timestamp.fromMillis(Date.now() - 60 * 1000);
const text = (length) => 'a'.repeat(length);
const interests = (count) => Array.from({ length: count }, (_, i) => `i${String(i + 1).padStart(2, '0')}`);
const tokens = (count) =>
  Array.from({ length: count }, (_, i) => ({ token: `token-${i}`, platform: 'android', updatedAt: clientTime() }));
/** Tek geçerli `FcmTokenModel` elemanı (isteğe bağlı alan ezmesiyle). */
const token = (extra) => ({ ...tokens(1)[0], ...extra });
const omit = (object, keys) => Object.fromEntries(Object.entries(object).filter(([key]) => !keys.includes(key)));
const expectWrite = (request, expected) => (expected === 'allow' ? assertSucceeds(request) : assertFails(request));
/**
 * Tablo satırlarının isteğe bağlı son sütunu (veri düzenlemesi) için varsayılan. Parametre VARSAYILANLI
 * olmak zorundadır: `test.each` geri çağrısı satırdan fazla parametre bildirirse jest fazlasını `done`
 * geri çağrısı sayar ve test `done()` beklerken zaman aşımına düşer.
 */
const NO_EDIT = Object.freeze({});

/** Yalnızca verilen belgeleri (temel veri kümesindeki halleriyle, isteğe bağlı düzenlemeyle) kurar. */
function seedOnly(paths, edit) {
  const all = baseDocs();
  return seedDocs(editDocs(Object.fromEntries(paths.map((p) => [p, all[p]])), edit));
}

runMatrix('users.json');
runMatrix('private_account.json');

// ── users · create ───────────────────────────────────────────────────────────────────────────

describe('users · create — alan beyaz listesi, tipler, sınırlar (rules-spec §3.1 C)', () => {
  // Satır: [başlık, eklenen / ezilen alanlar, çıkarılan anahtarlar, beklenti]. Taban yük
  // `payloads.userCreate` = `createProfile`'ın yazdığı belge (matriste `allow`).
  test.each([
    ['beyaz liste dışı alan (role)', { role: 'admin' }, [], 'deny'],
    ['suspendReason bu belgenin alanı değil — açık null bile ret (CD-133)', { suspendReason: null }, [], 'deny'],
    ['e-posta bu belgede tutulmaz (D-29)', { email: EMAIL }, [], 'deny'],
    ['status: suspended', { status: 'suspended' }, [], 'deny'],
    ['status: deleted', { status: 'deleted' }, [], 'deny'],
    ['staff: true (yalnızca seed / admin betiği yazar)', { staff: true }, [], 'deny'],
    ['profileComplete: true (AUT-05 güncellemesiyle açılır)', { profileComplete: true }, [], 'deny'],
    ['isDeleted: true', { isDeleted: true }, [], 'deny'],
    ['deletedBy dolu', { deletedBy: UID }, [], 'deny'],
    ['deletedAt dolu', { deletedAt: serverTimestamp() }, [], 'deny'],
    ['createdAt istemci saati', { createdAt: clientTime() }, [], 'deny'],
    ['updatedAt istemci saati', { updatedAt: clientTime() }, [], 'deny'],
    ['createdAt yok', {}, ['createdAt'], 'deny'],
    ['isDeleted yok', {}, ['isDeleted'], 'deny'],
    ['name nameMin − 1', { name: text(limits.nameMin - 1) }, [], 'deny'],
    ['name nameMin', { name: text(limits.nameMin) }, [], 'allow'],
    ['name nameMax', { name: text(limits.nameMax) }, [], 'allow'],
    ['name nameMax + 1', { name: text(limits.nameMax + 1) }, [], 'deny'],
    ['name dizgi değil', { name: 42 }, [], 'deny'],
    ['nameLower yok', {}, ['nameLower'], 'deny'],
    ['nameLower nameMin − 1', { nameLower: text(limits.nameMin - 1) }, [], 'deny'],
    ['nameLower nameMax + 1', { nameLower: text(limits.nameMax + 1) }, [], 'deny'],
    ['nameLower, name.lower() ile aynı değil ama 2–60 → geçer (CD-11)', { name: 'IŞIK Irmak', nameLower: 'ışık ırmak' }, [], 'allow'],
    ['name yalnızca boşluk (listelerde adsız kullanıcı)', { name: '   ' }, [], 'deny'],
    ['name kırpılınca nameMin − 1', { name: ` ${text(limits.nameMin - 1)} ` }, [], 'deny'],
    ['nameLower yalnızca boşluk', { nameLower: '   ' }, [], 'deny'],
    ['avatarSeed boş', { avatarSeed: '' }, [], 'deny'],
    ['avatarSeed avatarSeedMax', { avatarSeed: text(limits.avatarSeedMax) }, [], 'allow'],
    ['avatarSeed avatarSeedMax + 1', { avatarSeed: text(limits.avatarSeedMax + 1) }, [], 'deny'],
    ['avatarPath kendi klasörü', { avatarPath: payloads.avatarPathOf(UID) }, [], 'allow'],
    ['avatarPath başkasının klasörü', { avatarPath: payloads.avatarPathOf('u_member') }, [], 'deny'],
    ['avatarPath öneki benzeyen klasör (users/u_student2/…)', { avatarPath: payloads.avatarPathOf(`${UID}2`) }, [], 'deny'],
    ['avatarPath dosya adı şema dışı (StoragePaths.fileNamePattern)', { avatarPath: `users/${UID}/x.jpg` }, [], 'deny'],
    ['avatarPath izinsiz uzantı (.gif)', { avatarPath: payloads.avatarPathOf(UID).replace(/jpg$/, 'gif') }, [], 'deny'],
    ['avatarPath geçerli adın sonuna ek (uzunluk sınırsız kalmasın)', { avatarPath: `${payloads.avatarPathOf(UID)}${text(64)}` }, [], 'deny'],
    ['avatarPath dizgi değil', { avatarPath: 7 }, [], 'deny'],
    ['department tablo biçiminde (d24)', { department: 'd24' }, [], 'allow'],
    ['department biçim dışı', { department: 'Bilgisayar Mühendisliği' }, [], 'deny'],
    ['year enum değeri (5plus)', { year: '5plus' }, [], 'allow'],
    ['year enum dışı', { year: '6' }, [], 'deny'],
    ['interests interestsMax', { interests: interests(limits.interestsMax) }, [], 'allow'],
    ['interests interestsMax + 1', { interests: interests(limits.interestsMax + 1) }, [], 'deny'],
    ['interests tablo dışı kimlik (i17)', { interests: ['i17'] }, [], 'deny'],
    ['interests elemanı dizgi değil', { interests: [1] }, [], 'deny'],
    ['interests liste değil', { interests: 'i01' }, [], 'deny'],
    ['bio bioMax', { bio: text(limits.bioMax) }, [], 'allow'],
    ['bio bioMax + 1', { bio: text(limits.bioMax + 1) }, [], 'deny'],
    ['bio yok', {}, ['bio'], 'deny'],
  ])('%s', async (_title, extra, removed, expected) => {
    // Hesap belgesi yerindedir: ret, `existsAfter(private/account)` yüzünden değil satırın kendi
    // koşulu yüzünden gelir (ikisinin birlikte oluşması aşağıda ayrıca sınanır).
    await seedOnly([ACCOUNT]);
    const payload = omit(payloads.userCreate(UID, extra), removed);
    await expectWrite(setDoc(doc(studentDb(), USER), payload), expected);
    if (expected === 'deny') expect(await readDoc(USER)).toBeNull();
  });
});

// ── users · update (sahibi) ──────────────────────────────────────────────────────────────────

describe('users · update (sahibi) — alan beyaz listesi, tipler, sınırlar (rules-spec §3.1 U)', () => {
  const touch = (fields) => ({ ...fields, ...payloads.baseUpdate() });
  // Tamamlanmış profilin istemci biçimi: null alanın (`avatarPath`) anahtarı yoktur (W-51).
  const CLIENT_FORM = { unset: { [USER]: ['avatarPath'] } };
  // Profili henüz tamamlanmamış istemci belgesi (AUT-05 ortası): bölüm ve sınıf anahtarı yok.
  const INCOMPLETE = { patch: { [USER]: { profileComplete: false } }, unset: { [USER]: ['avatarPath', 'department', 'year'] } };
  const INCOMPLETE_STAFF = { patch: { [USER]: { profileComplete: false, staff: true } }, unset: INCOMPLETE.unset };

  // Satır: [başlık, yük, beklenti, veri düzenlemesi?]. Başlangıç belgesi: aktif öğrenci, profil tamam,
  // `department: 'd01'`, `year: '1'`, `interests: ['i01']`, `staff: false`, `avatarPath: null` (seed biçimi).
  test.each([
    ['yalnızca bio', touch({ bio: 'Yeni bio.' }), 'allow'],
    ['nameLower eşitlik denetimi yok (CD-11)', touch({ name: 'İpek Işık', nameLower: 'ipek ışık' }), 'allow'],
    ['updatedAt yok', { bio: 'Yeni bio.' }, 'deny'],
    ['updatedAt istemci saati', { bio: 'Yeni bio.', updatedAt: clientTime() }, 'deny'],
    ['status: suspended', touch({ status: 'suspended' }), 'deny'],
    ['status: deleted (hesap silme dalı T-29)', touch({ status: 'deleted', name: 'Silinmiş kullanıcı', bio: '', interests: [] }), 'deny'],
    ['staff: true', touch({ staff: true }), 'deny'],
    ['isDeleted: true', touch({ isDeleted: true }), 'deny'],
    ['deletedBy', touch({ deletedBy: UID }), 'deny'],
    ['createdAt', touch({ createdAt: serverTimestamp() }), 'deny'],
    ['beyaz liste dışı alan (role)', touch({ role: 'admin' }), 'deny'],
    ['suspendReason bu belgeye yazılamaz (CD-133)', touch({ suspendReason: 'x' }), 'deny'],
    ['interests boş — öğrenci', touch({ interests: [] }), 'deny'],
    ['interests boş — personel (staff: true)', touch({ interests: [] }), 'allow', { patch: { [USER]: { staff: true } } }],
    ['interests interestsMax', touch({ interests: interests(limits.interestsMax) }), 'allow'],
    ['interests interestsMax + 1', touch({ interests: interests(limits.interestsMax + 1) }), 'deny'],
    ['interests tablo dışı kimlik', touch({ interests: ['i01', 'zz'] }), 'deny'],
    ['bio bioMax + 1', touch({ bio: text(limits.bioMax + 1) }), 'deny'],
    ['name nameMin − 1', touch({ name: text(limits.nameMin - 1) }), 'deny'],
    ['name nameMax + 1', touch({ name: text(limits.nameMax + 1) }), 'deny'],
    ['nameLower nameMax + 1', touch({ nameLower: text(limits.nameMax + 1) }), 'deny'],
    ['name yalnızca boşluk', touch({ name: '   ' }), 'deny'],
    ['avatarSeed boş', touch({ avatarSeed: '' }), 'deny'],
    ['avatarSeed avatarSeedMax + 1 (herkese açık belgede sınırsız alan yok)', touch({ avatarSeed: text(limits.avatarSeedMax + 1) }), 'deny'],
    ['avatarPath başkasının klasörü', touch({ avatarPath: payloads.avatarPathOf('u_member') }), 'deny'],
    ['avatarPath dosya adı şema dışı', touch({ avatarPath: `users/${UID}/${text(64)}.jpg` }), 'deny'],
    ['avatarPath: null (kaldırma — açık null)', touch({ avatarPath: null }), 'allow', { patch: { [USER]: { avatarPath: payloads.avatarPathOf(UID) } } }],
    ['avatarPath alanı kaldırılır (anahtar yok)', touch({ avatarPath: deleteField() }), 'allow', { patch: { [USER]: { avatarPath: payloads.avatarPathOf(UID) } } }],
    ['year enum dışı', touch({ year: 'hazırlık' }), 'deny'],
    ['year: null — profil tamamken sınıf kaldırılamaz (öğrenci)', touch({ year: null }), 'deny'],
    ['year: null — personel (staff: true) sınıfsız kalabilir', touch({ year: null }), 'allow', { patch: { [USER]: { staff: true } } }],
    ['department: null — profil tamamken bölüm kaldırılamaz', touch({ department: null }), 'deny'],
    ['department biçim dışı', touch({ department: 'd1' }), 'deny'],
    ['profileComplete bool değil', touch({ profileComplete: 'true' }), 'deny'],
    ['profileComplete: true — bölüm ve sınıf yokken (AUT-05 atlanamaz)', touch({ profileComplete: true }), 'deny', INCOMPLETE],
    ['profileComplete: true — yalnızca bölüm (öğrenci)', touch({ profileComplete: true, department: 'd02' }), 'deny', INCOMPLETE],
    ['profileComplete: true — bölüm + sınıf', touch({ profileComplete: true, department: 'd02', year: '2' }), 'allow', INCOMPLETE],
    ['profileComplete: true — personel: bölüm yeter', touch({ profileComplete: true, department: 'd02' }), 'allow', INCOMPLETE_STAFF],
    ['profileComplete: true → false (tamamlanan profil geri alınamaz)', touch({ profileComplete: false }), 'deny'],
    ['profil tamamlanmadan bölüm / sınıf boş kalabilir (kısmi güncelleme)', touch({ bio: 'Yeni bio.' }), 'allow', INCOMPLETE],
    ['istemci biçimli belge (null alanların anahtarı yok) güncellenir (W-51)', touch({ bio: 'Yeni bio.' }), 'allow', CLIENT_FORM],
    ['istemci biçimli belgede ilk kez avatarPath yazılır (W-51)', touch({ avatarPath: payloads.avatarPathOf(UID) }), 'allow', CLIENT_FORM],
  ])('%s', async (_title, payload, expected, edit = NO_EDIT) => {
    await seedOnly([USER], edit);
    const before = await readDoc(USER);
    await expectWrite(updateDoc(doc(studentDb(), USER), payload), expected);
    if (expected === 'deny') expect(await readDoc(USER)).toEqual(before);
  });
});

// ── kayıt akışı: createProfile → updateProfile ───────────────────────────────────────────────

describe('users · kayıt akışı (PLAN §10.4 createProfile → updateProfile)', () => {
  test('createProfile tek batch (users + private/account + settings) geçer; AUT-05 güncellemesi profili tamamlar', async () => {
    const db = studentDb();
    const batch = writeBatch(db);
    batch.set(doc(db, USER), payloads.userCreate(UID));
    batch.set(doc(db, ACCOUNT), payloads.accountCreate(EMAIL));
    batch.set(doc(db, SETTINGS), payloads.settingsCreate());
    await assertSucceeds(batch.commit());

    const created = await readDoc(USER);
    expect(created).toMatchObject({ status: 'active', staff: false, profileComplete: false, interests: [], isDeleted: false });
    expect(created.createdAt.toMillis()).toBe(created.updatedAt.toMillis());
    // İstemci belgesi null alanların anahtarını hiç taşımaz (W-51).
    for (const key of ['avatarPath', 'department', 'year', 'suspendReason']) expect(created).not.toHaveProperty(key);
    expect(await readDoc(ACCOUNT)).toMatchObject({ email: EMAIL, emailLower: EMAIL, fcmTokens: [] });
    expect(await readDoc(ACCOUNT)).not.toHaveProperty('suspendReason');

    // Profil tamamlanmadan (interests boş) tek alan güncellemesi reddedilir: öğrencide en az bir ilgi alanı.
    await assertFails(updateDoc(doc(db, USER), { bio: 'Merhaba.', ...payloads.baseUpdate() }));
    await assertSucceeds(updateDoc(doc(db, USER), payloads.userProfileUpdate(UID)));
    expect(await readDoc(USER)).toMatchObject({ profileComplete: true, status: 'active', department: 'd02', year: '2', interests: ['i01', 'i05'] });
  });

  test('batch\'in bir parçası reddedilirse (başkasının hesabı) hiçbiri yazılmaz', async () => {
    const db = studentDb();
    const batch = writeBatch(db);
    batch.set(doc(db, USER), payloads.userCreate(UID));
    batch.set(doc(db, 'users/u_new/private/account'), payloads.accountCreate(EMAIL));
    await assertFails(batch.commit());
    expect(await readDoc(USER)).toBeNull();
  });
});

// ── profil ↔ hesap belgesi birlikte oluşur ───────────────────────────────────────────────────

describe('users ↔ private/account · biri olmadan diğeri oluşturulamaz (existsAfter; CD-133 madde 14)', () => {
  // Saldırı: doğrulanmış kullanıcı yalnızca `users/{uid}` yazar ve profili tamamlar → hesap belgesi
  // olmadığından askıya alma batch'i (T-37: users.status + account.suspendReason update) `not-found`
  // ile düşer, kullanıcı ADM-05 e-posta aramasında da görünmez.
  test('yalnızca users/{uid} (hesap belgesi yok) → deny', async () => {
    await assertFails(setDoc(doc(studentDb(), USER), payloads.userCreate(UID)));
    expect(await readDoc(USER)).toBeNull();
  });

  test('yalnızca private/account (profil belgesi yok) → deny', async () => {
    await assertFails(setDoc(doc(studentDb(), ACCOUNT), payloads.accountCreate(EMAIL)));
    expect(await readDoc(ACCOUNT)).toBeNull();
  });

  test('ikisi aynı batch\'te (settings olmadan) → allow', async () => {
    const db = studentDb();
    const batch = writeBatch(db);
    batch.set(doc(db, USER), payloads.userCreate(UID));
    batch.set(doc(db, ACCOUNT), payloads.accountCreate(EMAIL));
    await assertSucceeds(batch.commit());
    expect(await readDoc(USER)).not.toBeNull();
    expect(await readDoc(ACCOUNT)).not.toBeNull();
  });
});

// ── users · sorgu sözleşmesi ─────────────────────────────────────────────────────────────────

describe('users · sorgu sözleşmesi (rules-spec §6 ADM-05; PLAN §10.4 getUsers)', () => {
  const adm05 = (db) => query(collection(db, 'users'), where('isDeleted', '==', false), orderBy('nameLower'));
  const seedWithAnonymized = () =>
    seedOnly(['users/u_student', 'users/u_member', 'users/u_deleted'], {
      patch: { 'users/u_deleted': { name: 'Silinmiş kullanıcı', isDeleted: true, deletedBy: 'u_deleted' } },
    });

  test.each(['student', 'super', 'susp'])('%s · ADM-05 sorgusu (isDeleted == false, nameLower) geçer ve silinmişi içermez', async (role) => {
    await seedWithAnonymized();
    const snapshot = await assertSucceeds(getDocs(adm05(contextFor(role).firestore())));
    expect(snapshot.docs.map((d) => d.id)).toEqual(['u_member', 'u_student']);
  });

  test.each(['anon', 'unver', 'outsideDomain'])('%s · ADM-05 sorgusu → deny', async (role) => {
    await seedWithAnonymized();
    await assertFails(getDocs(adm05(contextFor(role).firestore())));
  });

  test('getUsers: whereIn(documentId) anonimleştirilmiş (isDeleted: true) yazarı da döndürür', async () => {
    await seedWithAnonymized();
    const q = query(collection(studentDb(), 'users'), where(documentId(), 'in', ['u_member', 'u_deleted']));
    const snapshot = await assertSucceeds(getDocs(q));
    expect(snapshot.docs.map((d) => d.id).sort()).toEqual(['u_deleted', 'u_member']);
    expect(snapshot.docs.find((d) => d.id === 'u_deleted').data()).toMatchObject({ status: 'deleted', isDeleted: true });
  });
});

// ── users/private/account · create ───────────────────────────────────────────────────────────

describe('users/private/account · create — alan beyaz listesi, tipler, sınırlar (rules-spec §3.2 C)', () => {
  const OTHER_EMAIL = 'baska@ogr.gumushane.edu.tr';

  test.each([
    ['lastLoginAt sunucu zamanı', { lastLoginAt: serverTimestamp() }, [], 'allow'],
    ['lastLoginAt istemci saati', { lastLoginAt: clientTime() }, [], 'deny'],
    ['suspendReason dolu — sahibi yazamaz (CD-133)', { suspendReason: payloads.SUSPEND_REASON }, [], 'deny'],
    ['email token ile farklı', { email: OTHER_EMAIL, emailLower: OTHER_EMAIL }, [], 'deny'],
    ['emailLower token e-postasının küçük harflisi değil', { emailLower: OTHER_EMAIL }, [], 'deny'],
    ['emailLower yok', {}, ['emailLower'], 'deny'],
    ['fcmTokens fcmTokensMax', { fcmTokens: tokens(limits.fcmTokensMax) }, [], 'allow'],
    ['fcmTokens fcmTokensMax + 1', { fcmTokens: tokens(limits.fcmTokensMax + 1) }, [], 'deny'],
    ['fcmTokens liste değil', { fcmTokens: {} }, [], 'deny'],
    // Eleman biçimi (FcmTokenModel): bozuk eleman süper adminin okumasını ayrıştırma hatasına düşürür.
    ['fcmTokens elemanı map değil ([42])', { fcmTokens: [42] }, [], 'deny'],
    ['fcmTokens[].token dizgi değil', { fcmTokens: [token({ token: 1 })] }, [], 'deny'],
    ['fcmTokens[].token boş', { fcmTokens: [token({ token: '' })] }, [], 'deny'],
    ['fcmTokens[].token fcmTokenMax', { fcmTokens: [token({ token: text(limits.fcmTokenMax) })] }, [], 'allow'],
    ['fcmTokens[].token fcmTokenMax + 1', { fcmTokens: [token({ token: text(limits.fcmTokenMax + 1) })] }, [], 'deny'],
    ['fcmTokens[].platform tablo dışı (web)', { fcmTokens: [token({ platform: 'web' })] }, [], 'deny'],
    ['fcmTokens[].updatedAt zaman damgası değil', { fcmTokens: [token({ updatedAt: '2026-10-08' })] }, [], 'deny'],
    ['fcmTokens elemanında fazladan anahtar', { fcmTokens: [token({ evil: text(64) })] }, [], 'deny'],
    ['fcmTokens elemanında eksik anahtar (updatedAt yok)', { fcmTokens: [omit(token(), ['updatedAt'])] }, [], 'deny'],
    ['fcmTokens son eleman (indeks fcmTokensMax − 1) bozuk', { fcmTokens: [...tokens(limits.fcmTokensMax - 1), 42] }, [], 'deny'],
    ['beyaz liste dışı alan (phone)', { phone: '+90' }, [], 'deny'],
    ['isDeleted: true', { isDeleted: true }, [], 'deny'],
    ['createdAt istemci saati', { createdAt: clientTime() }, [], 'deny'],
    ['updatedAt yok', {}, ['updatedAt'], 'deny'],
  ])('%s', async (_title, extra, removed, expected) => {
    // Profil belgesi yerindedir: ret `existsAfter(users/{uid})` yüzünden değil satırın koşulu yüzünden gelir.
    await seedOnly([USER]);
    const payload = omit(payloads.accountCreate(EMAIL, extra), removed);
    await expectWrite(setDoc(doc(studentDb(), ACCOUNT), payload), expected);
    if (expected === 'deny') expect(await readDoc(ACCOUNT)).toBeNull();
  });
});

// ── users/private/account · update (sahibi) ──────────────────────────────────────────────────

describe('users/private/account · update (sahibi) — alan beyaz listesi ve sınırlar (rules-spec §3.2 U)', () => {
  const touch = (fields) => ({ ...fields, ...payloads.baseUpdate() });
  const OTHER_EMAIL = 'baska@ogr.gumushane.edu.tr';
  const CLIENT_FORM = { unset: { [ACCOUNT]: ['lastLoginAt', 'suspendReason'] } };

  test.each([
    ['fcmTokens yazımı (Mod F hazırlığı)', touch({ fcmTokens: tokens(1) }), 'allow'],
    ['fcmTokens fcmTokensMax + 1', touch({ fcmTokens: tokens(limits.fcmTokensMax + 1) }), 'deny'],
    ['fcmTokens elemanı map değil ([42])', touch({ fcmTokens: [42] }), 'deny'],
    ['fcmTokens ikinci eleman bozuk (fazladan anahtar)', touch({ fcmTokens: [token(), token({ evil: true })] }), 'deny'],
    ['lastLoginAt istemci saati', touch({ lastLoginAt: clientTime() }), 'deny'],
    ['lastLoginAt alanı kaldırılamaz', touch({ lastLoginAt: deleteField() }), 'deny', { patch: { [ACCOUNT]: { lastLoginAt: clientTime() } } }],
    ['updatedAt yok', { lastLoginAt: serverTimestamp() }, 'deny'],
    ['updatedAt istemci saati', { lastLoginAt: serverTimestamp(), updatedAt: clientTime() }, 'deny'],
    ['email başka adrese çevrilemez', touch({ email: OTHER_EMAIL, emailLower: OTHER_EMAIL }), 'deny'],
    ['createdAt', touch({ createdAt: serverTimestamp() }), 'deny'],
    ['isDeleted: true', touch({ isDeleted: true }), 'deny'],
    ['beyaz liste dışı alan (phone)', touch({ phone: '+90' }), 'deny'],
    ['istemci biçimli belgede touchLastLogin (anahtarlar yok — W-51)', payloads.accountTouchLastLogin(), 'allow', CLIENT_FORM],
    ['istemci biçimli belgeye suspendReason anahtarı eklenemez (null bile)', touch({ suspendReason: null }), 'deny', CLIENT_FORM],
  ])('%s', async (_title, payload, expected, edit = NO_EDIT) => {
    await seedOnly([ACCOUNT], edit);
    const before = await readDoc(ACCOUNT);
    await expectWrite(updateDoc(doc(studentDb(), ACCOUNT), payload), expected);
    if (expected === 'deny') expect(await readDoc(ACCOUNT)).toEqual(before);
  });
});

// ── suspendReason (CD-133) ───────────────────────────────────────────────────────────────────

describe('suspendReason görünürlüğü (CD-133)', () => {
  const SUSP_USER = 'users/u_susp';
  const SUSP_ACCOUNT = `${SUSP_USER}/private/account`;

  test('askıdaki kullanıcı gerekçesini kendi hesabından okur; herkese açık users belgesinde gerekçe yoktur', async () => {
    await seedOnly([SUSP_USER, SUSP_ACCOUNT]);
    const db = contextFor('susp').firestore();
    const account = await assertSucceeds(getDoc(doc(db, SUSP_ACCOUNT)));
    expect(account.data().suspendReason).toBe(payloads.SUSPEND_REASON);
    const profile = await assertSucceeds(getDoc(doc(contextFor('member').firestore(), SUSP_USER)));
    expect(profile.data()).toMatchObject({ status: 'suspended' });
    expect(profile.data()).not.toHaveProperty('suspendReason');
  });

  test('askıdaki kullanıcı gerekçe alanını kaldıramaz (FieldValue.delete) ve touchLastLogin gerekçeyi korur', async () => {
    await seedOnly([SUSP_USER, SUSP_ACCOUNT]);
    const ref = doc(contextFor('susp').firestore(), SUSP_ACCOUNT);
    await assertFails(updateDoc(ref, { suspendReason: deleteField(), ...payloads.baseUpdate() }));
    await assertSucceeds(updateDoc(ref, payloads.accountTouchLastLogin()));
    expect((await readDoc(SUSP_ACCOUNT)).suspendReason).toBe(payloads.SUSPEND_REASON);
  });
});
