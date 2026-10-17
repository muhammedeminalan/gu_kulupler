#!/usr/bin/env node
'use strict';
/**
 * App Store inceleme hesabı açar: Auth hesabı, e-postası DOĞRULANMIŞ, rastgele şifreli. Firestore'a yazmaz;
 * profili ilk girişte uygulamanın profil ekranında tamamla.
 *
 *   node tool/admin/create_review_account.js --email <e-posta>                    # kuru: ne yapılacağını basar
 *   node tool/admin/create_review_account.js --email <e-posta> --yes              # aç (şifre bir kez basılır)
 *   node tool/admin/create_review_account.js --email <e-posta> --reset-password --yes   # var olanın şifresini yenile
 *
 * Güvenlik:
 *  - Varsayılan KURU çalıştırmadır; `--yes` gerçek projede TTY'de proje kimliği sorar. Şifre argüman olarak
 *    alınmaz (kabuk geçmişi); betik üretir ve YALNIZCA terminale bir kez basar. Kimseyle paylaşma.
 *  - Alan adı uygulamanın izinli listesinden (EmailDomainPolicy.allowedDomains). Var olan hesap silinmez;
 *    yalnızca doğrulanır / istenirse şifresi yenilenir; devre dışı hesaba dokunulmaz. Anahtar REPO DIŞINDA (D-36).
 */
const crypto = require('crypto');
const fs = require('fs');
const { REPO, UsageError, parseArgs } = require('./lib/admin_cli');
const { generatePassword, planAccount, validateEmail } = require('./lib/review_account');
const { confirmApply, initApp, loadAdmin, run } = require('./lib/admin_runtime');
const { readEmailDomains } = require('../lib/dart_sources');

const NAME = 'create_review_account';
const SPEC = { values: ['--email', '--project', '--key'], flags: ['--reset-password', '--emulator', '--yes'] };

async function main() {
  const argv = process.argv.slice(2);
  if (argv.length === 0 || argv.includes('-h') || argv.includes('--help')) {
    console.log(fs.readFileSync(__filename, 'utf8').split('\n').slice(3, 15).join('\n').replace(/^ \* ?/gm, ''));
    return;
  }
  const args = parseArgs(argv, SPEC);
  const email = validateEmail(args.email, readEmailDomains(REPO));
  const admin = loadAdmin(NAME);
  const target = initApp(NAME, admin, args);
  const auth = admin.auth();

  let existing = null;
  try {
    existing = await auth.getUserByEmail(email);
  } catch (e) {
    if (e.code !== 'auth/user-not-found') throw e;
  }
  const plan = planAccount(existing, { resetPassword: args.resetPassword });
  console.log(`Proje      : ${target.projectId}`);
  console.log(`E-posta    : ${email}`);
  if (plan.action === 'blocked') throw new UsageError(`hesap devre dışı (uid ${existing.uid}); betik etkinleştirmez`);
  if (plan.action === 'create') console.log('İşlem      : YENİ hesap (doğrulanmış) + yeni şifre');
  else if (plan.action === 'none') {
    console.log(`İşlem      : yok — hesap var ve doğrulanmış (uid ${existing.uid}). Şifre için --reset-password ekle.`);
    return;
  } else {
    const steps = [plan.verify && 'e-postayı doğrula', plan.resetPassword && 'yeni şifre'].filter(Boolean);
    console.log(`İşlem      : var olan hesap (uid ${existing.uid}) → ${steps.join(' + ')}`);
  }
  if (!(await confirmApply(NAME, target, args.yes, 'Hesap YAZILACAK.'))) return;

  const password = plan.resetPassword ? generatePassword(crypto.randomBytes) : null;
  let uid;
  if (plan.action === 'create') {
    ({ uid } = await auth.createUser({ email, password, emailVerified: true }));
  } else {
    uid = existing.uid;
    await auth.updateUser(uid, {
      ...(plan.verify && { emailVerified: true }),
      ...(password && { password }),
    });
  }
  console.log(`Tamam      : uid ${uid}`);
  if (password) {
    console.log(`Şifre      : ${password}`);
    console.log('             ↑ yalnızca bir kez basılır; App Store Connect › App Review Information alanına yaz, kimseyle paylaşma.');
  }
  console.log('Sonraki    : uygulamada bu hesapla giriş yap → profili tamamla → 1–2 açık kulübe katıl.');
}

if (require.main === module) run(NAME, main);
