#!/usr/bin/env node
'use strict';
/**
 * Serbest metinli push bildirimi gönderir (Firebase Cloud Messaging, Admin SDK). Yalnızca telefona gider;
 * uygulama içi bildirim kutusuna YAZMAZ. Jetonlar users/{uid}/private/account.fcmTokens (T-42).
 *
 *   node tool/admin/send_push.js --title "GÜ Kulüpler" --body "Mesaj" --all [--yes]
 *   node tool/admin/send_push.js --title "GÜ Kulüpler" --body "Mesaj" --email <e-posta> [--yes]
 *   node tool/admin/send_push.js ... [--project <id>] [--key <json>]
 *
 * Güvenlik:
 *  - Varsayılan KURU çalıştırmadır (alıcı ve jeton sayısı basılır, gönderilmez); `--yes` gönderir. Gerçek
 *    projede yalnızca TTY'de, proje kimliği yazılarak; anahtar REPO DIŞINDA (D-36). Emülatörde çalışmaz (FCM yok).
 *  - `--all` = etkin, silinmemiş hesaplar. Jetonu olmayan (uygulamaya hiç girmemiş / bildirim izni vermemiş)
 *    hesaba gönderilemez. Sınırlar: başlık 60, metin 300 karakter.
 */
const fs = require('fs');
const { UsageError, parseArgs } = require('./lib/admin_cli');
const { buildMulticasts, collectTokens, validateText } = require('./lib/push_broadcast');
const { confirmApply, initApp, loadAdmin, run } = require('./lib/admin_runtime');

const NAME = 'send_push';
const SPEC = { values: ['--title', '--body', '--email', '--project', '--key'], flags: ['--all', '--emulator', '--yes'] };

async function main() {
  const argv = process.argv.slice(2);
  if (argv.length === 0 || argv.includes('-h') || argv.includes('--help')) {
    console.log(fs.readFileSync(__filename, 'utf8').split('\n').slice(3, 16).join('\n').replace(/^ \* ?/gm, ''));
    return;
  }
  const args = parseArgs(argv, SPEC);
  if (args.emulator) throw new UsageError('emülatörde FCM yok; gerçek projede çalıştır');
  if (!args.email === !args.all) throw new UsageError('--email <e-posta> ya da --all ver (yalnızca biri)');
  const { title, body } = validateText(args.title, args.body);
  const admin = loadAdmin(NAME);
  const target = initApp(NAME, admin, args);
  const db = admin.firestore();

  let uids;
  if (args.all) {
    const snap = await db.collection('users').where('status', '==', 'active').where('isDeleted', '==', false).get();
    uids = snap.docs.map((d) => d.id);
  } else {
    const { uid } = await admin.auth().getUserByEmail(args.email);
    uids = [uid];
  }
  const refs = uids.map((uid) => db.doc(`users/${uid}/private/account`));
  const accounts = [];
  for (let i = 0; i < refs.length; i += 300) {
    const snaps = await db.getAll(...refs.slice(i, i + 300));
    for (const s of snaps) if (s.exists) accounts.push(s.data());
  }
  const tokens = collectTokens(accounts);
  console.log(`Proje      : ${target.projectId}`);
  console.log(`Hesap      : ${uids.length}  ·  jeton (cihaz): ${tokens.length}`);
  console.log(`Başlık     : ${title}`);
  console.log(`Metin      : ${body}`);
  if (tokens.length === 0) {
    console.log('Gönderilecek cihaz yok (kullanıcılar uygulamaya giriş yapıp bildirim izni vermeli).');
    return;
  }
  if (!(await confirmApply(NAME, target, args.yes, `${tokens.length} cihaza push GÖNDERİLECEK.`))) return;
  let ok = 0;
  let fail = 0;
  for (const message of buildMulticasts({ title, body, tokens })) {
    const res = await admin.messaging().sendEachForMulticast(message);
    ok += res.successCount;
    fail += res.failureCount;
  }
  console.log(`Gönderildi: ${ok}  ·  başarısız: ${fail}${fail ? ' (geçersiz / eski jeton olabilir)' : ''}`);
}

if (require.main === module) run(NAME, main);
