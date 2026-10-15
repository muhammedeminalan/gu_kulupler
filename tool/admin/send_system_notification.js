#!/usr/bin/env node
'use strict';
/**
 * PLAN §21.1 #14b · `system` bildirimi gönderir (T-37). Mod C'de bu türü yalnızca bu betik (Admin SDK) yazar;
 * uygulama içi üretici yoktur (Rules istemciye kapalı). Belge: `notifications/system_{eventKey}_{uid}`,
 * `refs: {textKey}` — metin uygulamanın ARB'sindedir (TR / EN). Kurallar: tool/admin/lib/system_notification.js.
 *
 *   node tool/admin/send_system_notification.js --text-key <welcome|maintenance> --email <e-posta> [--yes]
 *   node tool/admin/send_system_notification.js --text-key maintenance --all [--project <id>] [--key <json>] [--yes]
 *   node tool/admin/send_system_notification.js --emulator --project demo-gu-kulupler --text-key welcome --all --yes
 *
 * Güvenlik:
 *  - Varsayılan KURU çalıştırmadır (alıcı sayısı ve örnek yazım basılır); `--yes` uygular. Gerçek projede yalnızca
 *    TTY'de, proje kimliği yazılarak; anahtar REPO DIŞINDA (D-36).
 *  - `--all` = etkin, silinmemiş hesaplar (askıdaki / silinmiş hesaba yazılmaz). Tek koşum tek olay anahtarı
 *    kullanır: aynı koşum yeniden denenirse alıcı başına aynı belgeye yazar.
 */
const fs = require('fs');
const { BATCH_MAX_WRITES, UsageError, describeWrites, packUnits, parseArgs } = require('./lib/admin_cli');
const { buildSystemNotifications, newEventKey } = require('./lib/system_notification');
const { commitBatches, confirmApply, initApp, loadAdmin, run } = require('./lib/admin_runtime');

const NAME = 'send_system_notification';
const SPEC = { values: ['--text-key', '--email', '--project', '--key'], flags: ['--all', '--emulator', '--yes'] };

async function main() {
  const argv = process.argv.slice(2);
  if (argv.length === 0 || argv.includes('-h') || argv.includes('--help')) {
    console.log(fs.readFileSync(__filename, 'utf8').split('\n').slice(3, 18).join('\n').replace(/^ \* ?/gm, ''));
    return;
  }
  const args = parseArgs(argv, SPEC);
  if (!args.textKey) throw new UsageError('--text-key <welcome|maintenance> gerekli');
  if (!args.email === !args.all) throw new UsageError('--email <e-posta> ya da --all ver (yalnızca biri)');
  const admin = loadAdmin(NAME);
  const target = initApp(NAME, admin, args);
  const db = admin.firestore();

  let uids;
  if (args.all) {
    const snap = await db.collection('users').where('status', '==', 'active').where('isDeleted', '==', false).get();
    uids = snap.docs.map((d) => d.id);
  } else {
    const { uid } = await admin.auth().getUserByEmail(args.email);
    const user = await db.doc(`users/${uid}`).get();
    if (!user.exists || user.get('status') !== 'active' || user.get('isDeleted') === true) {
      throw new Error(`users/${uid}: hesap etkin değil`);
    }
    uids = [uid];
  }
  const writes = buildSystemNotifications({ textKey: args.textKey, uids, eventKey: newEventKey() });
  console.log(`Proje      : ${target.projectId}${target.emulator ? ' (emülatör)' : ''}`);
  console.log(`Alıcı      : ${writes.length}  (textKey: ${args.textKey})`);
  console.log(describeWrites(writes.slice(0, 3)));
  if (writes.length > 3) console.log(`  … +${writes.length - 3}`);
  if (!(await confirmApply(NAME, target, args.yes, `${writes.length} kullanıcıya system bildirimi YAZILACAK.`))) return;
  const written = await commitBatches(admin, db, packUnits(writes.map((w) => [w]), BATCH_MAX_WRITES));
  console.log(`${written} bildirim yazıldı.`);
}

if (require.main === module) run(NAME, main);
