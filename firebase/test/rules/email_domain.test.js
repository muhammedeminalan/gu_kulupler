'use strict';
// T-12 — e-posta alan adı kısıtı Rules'ta (D-27, rules-spec §1.10; PLAN §11.6 `email_domain.test.js`).
//
// `emailOk()` = oturum + `email_verified == true` + izinli alan adı (EmailDomainPolicy.allowedDomains:
// `ogr.gumushane.edu.tr`, `gumushane.edu.tr`; desen paritesi statik olarak RP03 ve parity.test.js'te).
// Bu dosya davranışı emülatörde kanıtlar: aynı token ile T-12'nin üç koleksiyonunda okuma ve
// `createProfile` batch'i (users + private/account + settings) birlikte geçer ya da birlikte reddedilir.
// Ayrıca belgeleri ZATEN VAR olan kullanıcı doğrulamayı / izinli alan adını yitirince (token) yazamaz ve
// özel belgelerini okuyamaz: ret "belge yok" yüzünden değil `emailOk()` yüzünden gelir.
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, getDoc, updateDoc, writeBatch } = require('firebase/firestore');
const { getTestEnv } = require('../setup/env');
const { baseDocs, readDoc, seedDocs } = require('../helpers/fixtures');
const payloads = require('../helpers/payloads');

const UID = 'u_domain';
const PROFILE = 'users/u_student';

/** Verilen token claim'leriyle yeni bir istemci (roles.json bağlamlarının dışındaki e-postalar için). */
function dbWith(token) {
  return getTestEnv().authenticatedContext(UID, token).firestore();
}

/** `createProfile` batch'i: üç belge tek commit. `email` token'daki adresle aynı yazılır. */
function createProfile(db, email) {
  const batch = writeBatch(db);
  batch.set(doc(db, `users/${UID}`), payloads.userCreate(UID));
  batch.set(doc(db, `users/${UID}/private/account`), payloads.accountCreate(email));
  batch.set(doc(db, `settings/${UID}`), payloads.settingsCreate());
  return batch.commit();
}

const verified = (email) => ({ email, email_verified: true });

describe('e-posta alan adı (D-27) · users / private/account / settings', () => {
  test.each([
    ['öğrenci alan adı (ogr.gumushane.edu.tr)', verified('ad.soyad@ogr.gumushane.edu.tr'), 'allow'],
    ['personel alan adı (gumushane.edu.tr)', verified('ad.soyad@gumushane.edu.tr'), 'allow'],
    ['büyük harfli adres (alan adı küçük harfe çevrilerek eşlenir)', verified('Ad.Soyad@OGR.Gumushane.EDU.TR'), 'allow'],
    ['gmail.com', verified('ad.soyad@gmail.com'), 'deny'],
    ['sonu benzeyen alan adı (evilgumushane.edu.tr)', verified('ad@evilgumushane.edu.tr'), 'deny'],
    ['izinsiz alt alan adı (sub.gumushane.edu.tr)', verified('ad@sub.gumushane.edu.tr'), 'deny'],
    ['izinli ad önek olarak (gumushane.edu.tr.evil.com)', verified('ad@gumushane.edu.tr.evil.com'), 'deny'],
    ['@ işaretsiz adres', verified('ogr.gumushane.edu.tr'), 'deny'],
    ['izinli alan adı ama email_verified: false', { email: 'ad@ogr.gumushane.edu.tr', email_verified: false }, 'deny'],
    ['izinli alan adı ama email_verified claim\'i yok', { email: 'ad@ogr.gumushane.edu.tr' }, 'deny'],
    ['email claim\'i yok', { email_verified: true }, 'deny'],
    ['süper admin claim\'i alan adı kısıtını aşmaz', { ...verified('ad@gmail.com'), superadmin: true }, 'deny'],
  ])('%s → %s', async (_title, token, expected) => {
    await seedDocs({ [PROFILE]: baseDocs()[PROFILE] });
    const db = dbWith(token);
    const check = expected === 'allow' ? assertSucceeds : assertFails;

    await check(getDoc(doc(db, PROFILE)));
    await check(createProfile(db, token.email || 'ad@ogr.gumushane.edu.tr'));

    const written = await readDoc(`users/${UID}`);
    if (expected === 'deny') {
      expect(written).toBeNull();
      expect(await readDoc(`settings/${UID}`)).toBeNull();
      return;
    }
    expect(written).toMatchObject({ status: 'active', profileComplete: false });
    // Hesap belgesi token'daki adresi olduğu gibi, küçük harflisini `emailLower`'da taşır.
    expect(await readDoc(`users/${UID}/private/account`)).toMatchObject({
      email: token.email,
      emailLower: token.email.toLowerCase(),
    });
    await check(getDoc(doc(db, `users/${UID}/private/account`)));
    await check(getDoc(doc(db, `settings/${UID}`)));
  });

  test('hesap belgesinde emailLower küçük harfe çevrilmemişse ret (token e-postası büyük harfli)', async () => {
    const email = 'Ad.Soyad@OGR.Gumushane.EDU.TR';
    const db = dbWith(verified(email));
    const ref = doc(db, `users/${UID}/private/account`);
    const batch = writeBatch(db);
    // Profil belgesi aynı batch'tedir: ret `existsAfter(users/{uid})` yüzünden değil `emailLower` yüzünden gelir.
    batch.set(doc(db, `users/${UID}`), payloads.userCreate(UID));
    batch.set(ref, payloads.accountCreate(email, { emailLower: email }));
    await assertFails(batch.commit());
    expect(await readDoc(`users/${UID}/private/account`)).toBeNull();
  });
});

describe('e-posta alan adı (D-27) · belgeleri var olan kullanıcı: emailOk() yoksa yazma ve özel okuma yok', () => {
  const ALLOWED = 'ad.soyad@ogr.gumushane.edu.tr';
  const USER = `users/${UID}`;
  const ACCOUNT = `${USER}/private/account`;
  const SETTINGS = `settings/${UID}`;

  /** `u_domain` kullanıcısının üç belgesi (kayıt daha önce izinli adresle tamamlanmış). */
  function seedOwnDocs() {
    const all = baseDocs();
    return seedDocs({
      [USER]: all['users/u_student'],
      [ACCOUNT]: { ...all['users/u_student/private/account'], email: ALLOWED, emailLower: ALLOWED },
      [SETTINGS]: all['settings/u_student'],
    });
  }

  test.each([
    ['izinli alan adı, doğrulanmış (kontrol)', verified(ALLOWED), 'allow'],
    ['aynı adres ama email_verified: false', { email: ALLOWED, email_verified: false }, 'deny'],
    ['hesap e-postası izinsiz alan adına taşınmış', verified('ad.soyad@gmail.com'), 'deny'],
  ])('%s → %s', async (_title, token, expected) => {
    await seedOwnDocs();
    const db = dbWith(token);
    const check = expected === 'allow' ? assertSucceeds : assertFails;

    await check(updateDoc(doc(db, USER), { bio: 'Yeni bio.', ...payloads.baseUpdate() }));
    await check(updateDoc(doc(db, ACCOUNT), payloads.accountTouchLastLogin()));
    await check(updateDoc(doc(db, SETTINGS), { quiet: true, ...payloads.baseUpdate() }));
    await check(getDoc(doc(db, ACCOUNT)));
    await check(getDoc(doc(db, SETTINGS)));

    expect((await readDoc(USER)).bio).toBe(expected === 'allow' ? 'Yeni bio.' : '');
    expect((await readDoc(SETTINGS)).quiet).toBe(expected === 'allow');
  });
});
