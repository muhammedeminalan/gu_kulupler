#!/usr/bin/env node
'use strict';
/**
 * W-91 · yarım kalan hesap silme temizliğini tamamlar (T-37; sözleşme docs/plans/T-37.md §4 e). Yalnızca
 * `users.status == 'deleted'` hesaplar: kalan açık katılım (+ etkinlik sayacı), üyelik anonimleştirme (M14; etkin
 * üye `left` + `memberCount −1`, bekleyen `cancelled`, danışman `left`), iletişim belgesi, hesap belgesi ve kişisel
 * belgeler (bildirim / kayıt / engel — soft delete). Kurallar: tool/admin/lib/account_cleanup.js; koşucu:
 * tool/admin/lib/account_cleanup_runner.js.
 *
 *   node tool/admin/finish_account_deletion.js --uid <uid>          [--project <id>] [--key <servis-hesabı.json>] [--yes]
 *   node tool/admin/finish_account_deletion.js --all-deleted        ...
 *   node tool/admin/finish_account_deletion.js --emulator --project demo-gu-kulupler --all-deleted --yes
 *
 * Güvenlik:
 *  - Varsayılan KURU çalıştırmadır: plan basılır (kişisel belgeler yalnızca sayı), hiçbir şey yazılmaz. `--yes` uygular.
 *  - T-45: iki geçiş (önce tüm hesapların kritik temizliği, sonra kişisel belgeler), sayfalı okuma, kişisel yazımlar
 *    ≤ 450'lik gruplu batch; her yazım okunduğu sürüm önkoşuluyla (lib/account_cleanup_runner.js). Reddedilen batch
 *    (eşzamanlı değişiklik) yarım yazım bırakmaz: betiği yeniden çalıştır.
 *  - Gerçek projede yalnızca etkileşimli terminalde (TTY) ve proje kimliği yazılarak onaylanır; anahtar REPO DIŞINDA.
 *  - Hiçbir belge, dosya ya da Auth kimliği silinmez (D-10, Q-11); yeniden çalıştırmak güvenlidir (idempotent).
 *  - Etkin BAŞKAN üyeliği kapatılmaz: önce ADM-03'te başkan ata (W-90), sonra betiği yeniden çalıştır.
 */
const fs = require('fs');
const { UsageError, parseArgs } = require('./lib/admin_cli');
const { listDeletedUids, runFinishDeletion } = require('./lib/account_cleanup_runner');
const { confirmApply, initApp, loadAdmin, run } = require('./lib/admin_runtime');

const NAME = 'finish_account_deletion';
const SPEC = { values: ['--uid', '--project', '--key'], flags: ['--all-deleted', '--emulator', '--yes'] };

async function main() {
  const argv = process.argv.slice(2);
  if (argv.length === 0 || argv.includes('-h') || argv.includes('--help')) {
    const lines = fs.readFileSync(__filename, 'utf8').split('\n');
    console.log(lines.slice(3, lines.indexOf(' */')).join('\n').replace(/^ \* ?/gm, ''));
    return;
  }
  const args = parseArgs(argv, SPEC);
  if (!args.uid === !args.allDeleted) throw new UsageError('--uid <uid> ya da --all-deleted ver (yalnızca biri)');
  const admin = loadAdmin(NAME);
  const target = initApp(NAME, admin, args);
  const db = admin.firestore();
  const documentId = () => admin.firestore.FieldPath.documentId();

  const uids = args.uid ? [args.uid] : await listDeletedUids(db, documentId);
  console.log(`Proje      : ${target.projectId}${target.emulator ? ' (emülatör)' : ''}`);
  console.log(`Hesaplar   : ${uids.length}`);
  await runFinishDeletion({
    db,
    fieldValue: admin.firestore.FieldValue,
    documentId,
    uids,
    confirm: (message) => confirmApply(NAME, target, args.yes, message),
  });
}

if (require.main === module) run(NAME, main);
