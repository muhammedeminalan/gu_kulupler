#!/usr/bin/env node
'use strict';
/**
 * K-A / M13 · danışman hesabını kulübe bağlar ya da bağı kaldırır (T-37). Yazımlar uygulamadaki
 * `AdminRepository.setAdvisor` ile AYNI belgelerdir: `memberships/{clubId}_{uid}` (`active` + `advisor`), iletişim
 * belgesi (hesap e-postası) ve `clubs/{clubId}.advisor.userId` TEK transaction'da; `memberCount` değişmez.
 * Kurallar: tool/admin/lib/advisor_link.js. Kulübün danışman kaydı (ad / ünvan) ADM-03'te önceden girilmiş olmalı.
 *
 *   node tool/admin/set_advisor.js --club <clubId> --email <e-posta>            [--project <id>] [--key <json>] [--yes]
 *   node tool/admin/set_advisor.js --club <clubId> --email <e-posta> --remove   ...
 *   node tool/admin/set_advisor.js --emulator --project demo-gu-kulupler --club c01 --email … --yes
 *
 * Güvenlik:
 *  - Varsayılan KURU çalıştırmadır (plan basılır); `--yes` uygular. Gerçek projede yalnızca TTY'de, proje kimliği
 *    yazılarak; anahtar REPO DIŞINDA (D-36). Belge silinmez (D-10): kaldırma üyeliği `left` yapar.
 *  - Danışman yetkisi custom claim DEĞİLDİR: üyelik rolüdür (salt okunur yönetim — Q-09).
 */
const fs = require('fs');
const { UsageError, describeWrites, materialize, parseArgs } = require('./lib/admin_cli');
const { buildAdvisorPlan } = require('./lib/advisor_link');
const { confirmApply, initApp, loadAdmin, plain, run } = require('./lib/admin_runtime');

const NAME = 'set_advisor';
const SPEC = { values: ['--club', '--email', '--project', '--key'], flags: ['--remove', '--emulator', '--yes'] };

/** Planlayıcının girdisi; `read` ya doğrudan okuma ya da transaction okumasıdır. */
async function readState(db, read, clubId, uid, remove) {
  const get = async (path) => {
    const snap = await read(db.doc(path));
    return snap.exists ? plain(snap.data()) : null;
  };
  const membershipPath = `memberships/${clubId}_${uid}`;
  return {
    clubId,
    uid,
    remove,
    club: await get(`clubs/${clubId}`),
    membership: await get(membershipPath),
    contact: await get(`${membershipPath}/private/contact`),
    user: await get(`users/${uid}`),
    account: await get(`users/${uid}/private/account`),
  };
}

async function main() {
  const argv = process.argv.slice(2);
  if (argv.length === 0 || argv.includes('-h') || argv.includes('--help')) {
    console.log(fs.readFileSync(__filename, 'utf8').split('\n').slice(3, 18).join('\n').replace(/^ \* ?/gm, ''));
    return;
  }
  const args = parseArgs(argv, SPEC);
  if (!args.club || !args.email) throw new UsageError('--club <clubId> ve --email <e-posta> gerekli');
  const admin = loadAdmin(NAME);
  const target = initApp(NAME, admin, args);
  const db = admin.firestore();
  const { uid } = await admin.auth().getUserByEmail(args.email);

  const preview = buildAdvisorPlan(await readState(db, (ref) => ref.get(), args.club, uid, args.remove));
  console.log(`Proje      : ${target.projectId}${target.emulator ? ' (emülatör)' : ''}`);
  console.log(`Kulüp      : ${args.club}`);
  console.log(`Kullanıcı  : ${uid}  ${args.email}`);
  if (preview.error) throw new Error(preview.error);
  if (preview.noop) {
    console.log('Zaten bağlı; değişiklik yok.');
    return;
  }
  console.log(describeWrites(preview.writes));
  const message = args.remove ? 'Danışman bağı KALDIRILACAK.' : 'Kullanıcı kulübün DANIŞMANI olarak bağlanacak.';
  if (!(await confirmApply(NAME, target, args.yes, message))) return;
  // Uygulama: okuma + yazım tek transaction (araya giren değişiklik planı yeniden hesaplatır).
  await db.runTransaction(async (tx) => {
    const plan = buildAdvisorPlan(await readState(db, (ref) => tx.get(ref), args.club, uid, args.remove));
    if (plan.error) throw new Error(plan.error);
    const fieldValue = admin.firestore.FieldValue;
    for (const write of plan.writes) {
      const data = materialize(write.data, fieldValue);
      if (write.op === 'set') tx.set(db.doc(write.path), data);
      else tx.update(db.doc(write.path), data);
    }
  });
  console.log(args.remove ? 'Danışman bağı kaldırıldı.' : 'Danışman bağlandı.');
}

if (require.main === module) run(NAME, main);
