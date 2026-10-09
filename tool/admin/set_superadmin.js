#!/usr/bin/env node
'use strict';
/**
 * Süper admin custom claim atama / geri alma / listeleme (D-28, docs/firestore-rules-spec.md §7).
 * Firestore alanıyla yetki yükseltme YOKTUR; yetki yalnızca ID token'daki `superadmin: true` claim'idir.
 *
 *   node tool/admin/set_superadmin.js --uid <uid>   [--project <id>] [--key <servis-hesabı.json>] [--yes]
 *   node tool/admin/set_superadmin.js --email <e-posta> ...
 *   node tool/admin/set_superadmin.js --uid <uid> --revoke ...
 *   node tool/admin/set_superadmin.js --list ...
 *   node tool/admin/set_superadmin.js --emulator --project demo-gu --email ayse@… --yes     # Auth emülatörü (127.0.0.1:9099)
 *
 * Güvenlik:
 *  - Servis hesabı anahtarı (JSON) REPO DIŞINDA durur; repo içindeki yol reddedilir. Yol: --key ya da GOOGLE_APPLICATION_CREDENTIALS.
 *  - Gerçek projede komut yalnızca etkileşimli terminalde (TTY) çalışır ve proje kimliğini yazarak onay ister.
 *    Claude Code gibi TTY'siz ortamlar gerçek projede claim atayamaz (kasıtlı). Emülatörde onay gerekmez.
 *  - Mevcut diğer claim'ler korunur; yalnızca `superadmin` eklenir/çıkarılır. Belge/hesap silinmez.
 *  - Claim, kullanıcının token'ı yenilenince geçerli olur (çıkış-giriş ya da getIdToken(true)).
 */
const fs = require('fs');
const path = require('path');
const readline = require('readline');

const argv = process.argv.slice(2);
const has = (f) => argv.includes(f);
const val = (f) => { const i = argv.indexOf(f); return i >= 0 && argv[i + 1] && !argv[i + 1].startsWith('--') ? argv[i + 1] : null; };
const fail = (m, c) => { console.error('set_superadmin: ' + m); process.exit(c || 1); };
const REPO = path.resolve(__dirname, '..', '..');

if (has('-h') || has('--help') || argv.length === 0) {
  console.log(fs.readFileSync(__filename, 'utf8').split('\n').slice(3, 19).join('\n').replace(/^ \* ?/gm, ''));
  process.exit(0);
}

let admin;
try { admin = require('firebase-admin'); } catch (e) { fail('firebase-admin kurulu değil: (cd tool/admin && npm install)', 2); }

const emulator = has('--emulator');
let projectId = val('--project');

function initApp() {
  if (emulator) {
    process.env.FIREBASE_AUTH_EMULATOR_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';
    projectId = projectId || 'demo-gu';
    admin.initializeApp({ projectId });
    return;
  }
  const keyPath = val('--key') || process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (!keyPath) fail('servis hesabı anahtarı gerekli: --key <yol> ya da GOOGLE_APPLICATION_CREDENTIALS (anahtar repo DIŞINDA durmalı)', 2);
  const abs = path.resolve(keyPath);
  const rel = path.relative(REPO, abs);
  if (!rel.startsWith('..') && !path.isAbsolute(rel)) fail(`anahtar repo içinde: ${rel}. Repo dışına taşı (D-36); asla commit edilmez`, 2);
  if (!fs.existsSync(abs)) fail(`anahtar dosyası yok: ${abs}`, 2);
  let json;
  try { json = JSON.parse(fs.readFileSync(abs, 'utf8')); } catch (e) { fail('anahtar dosyası geçerli JSON değil', 2); }
  if (projectId && json.project_id && projectId !== json.project_id) fail(`--project (${projectId}) anahtardaki proje (${json.project_id}) ile uyuşmuyor`, 2);
  projectId = projectId || json.project_id;
  admin.initializeApp({ credential: admin.credential.cert(json), projectId });
}

async function confirmReal(msg) {
  if (emulator) return true;
  if (!process.stdin.isTTY || !process.stdout.isTTY) fail('GERÇEK projede claim değişikliği yalnızca etkileşimli terminalde yapılır (TTY yok). Komutu kendi terminalinde çalıştır.', 3);
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  const answer = await new Promise((res) => rl.question(`${msg}\nOnaylamak için proje kimliğini yaz (${projectId}): `, res));
  rl.close();
  return answer.trim() === projectId;
}

async function main() {
  initApp();
  const auth = admin.auth();

  if (has('--list')) {
    let token;
    let n = 0;
    do {
      const page = await auth.listUsers(1000, token);
      for (const u of page.users) if (u.customClaims && u.customClaims.superadmin === true) { n++; console.log(`${u.uid}\t${u.email || '-'}\t${u.disabled ? 'devre dışı' : 'aktif'}`); }
      token = page.pageToken;
    } while (token);
    console.log(`${n} süper admin (${projectId})`);
    return;
  }

  const uid = val('--uid'), email = val('--email');
  if (!uid && !email) fail('--uid ya da --email ver (ya da --list)', 2);
  const user = uid ? await auth.getUser(uid) : await auth.getUserByEmail(email);
  const claims = Object.assign({}, user.customClaims || {});
  const revoke = has('--revoke');
  const next = Object.assign({}, claims);
  if (revoke) { delete next.superadmin; } else { next.superadmin = true; }
  console.log(`Proje      : ${projectId}${emulator ? ' (emülatör)' : ''}`);
  console.log(`Kullanıcı  : ${user.uid}  ${user.email || '-'}`);
  console.log(`Mevcut     : ${JSON.stringify(claims)}`);
  console.log(`Yeni       : ${JSON.stringify(next)}`);
  if ((claims.superadmin === true) === !revoke) { console.log('Değişiklik yok.'); return; }
  if (!has('--yes')) fail('uygulamak için --yes ekle (gerçek projede ayrıca TTY onayı istenir)', 3);
  if (!(await confirmReal(revoke ? 'Süper admin yetkisi GERİ ALINACAK.' : 'Kullanıcıya TAM YETKİLİ süper admin claim\'i VERİLECEK.'))) fail('onay eşleşmedi; işlem iptal', 3);
  await auth.setCustomUserClaims(user.uid, next);
  console.log(revoke ? 'Claim kaldırıldı.' : 'Claim atandı.');
  console.log('Kullanıcı çıkış-giriş yapınca (ya da getIdToken(true) ile) yeni yetki geçerli olur.');
}

main().then(() => process.exit(0)).catch((e) => fail(e && e.message ? e.message : String(e), 1));
