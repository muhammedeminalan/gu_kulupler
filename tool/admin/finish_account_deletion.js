#!/usr/bin/env node
'use strict';
/**
 * W-91 · yarım kalan hesap silme temizliğini tamamlar (T-37; sözleşme docs/plans/T-37.md §4 e). Yalnızca
 * `users.status == 'deleted'` hesaplar: kalan açık katılım (+ etkinlik sayacı), üyelik anonimleştirme (M14; etkin
 * üye `left` + `memberCount −1`, bekleyen `cancelled`, danışman `left`), iletişim belgesi, hesap belgesi ve kişisel
 * belgeler (bildirim / kayıt / engel — soft delete). Kurallar: tool/admin/lib/account_cleanup.js.
 *
 *   node tool/admin/finish_account_deletion.js --uid <uid>          [--project <id>] [--key <servis-hesabı.json>] [--yes]
 *   node tool/admin/finish_account_deletion.js --all-deleted        ...
 *   node tool/admin/finish_account_deletion.js --emulator --project demo-gu-kulupler --all-deleted --yes
 *
 * Güvenlik:
 *  - Varsayılan KURU çalıştırmadır: plan basılır, hiçbir şey yazılmaz. `--yes` uygular.
 *  - Gerçek projede yalnızca etkileşimli terminalde (TTY) ve proje kimliği yazılarak onaylanır; anahtar REPO DIŞINDA.
 *  - Hiçbir belge, dosya ya da Auth kimliği silinmez (D-10, Q-11); yeniden çalıştırmak güvenlidir (idempotent).
 *  - Etkin BAŞKAN üyeliği kapatılmaz: önce ADM-03'te başkan ata (W-90), sonra betiği yeniden çalıştır.
 */
const fs = require('fs');
const { BATCH_MAX_WRITES, UsageError, describeWrites, packUnits, parseArgs } = require('./lib/admin_cli');
const { buildCleanupPlan } = require('./lib/account_cleanup');
const { commitBatches, confirmApply, initApp, loadAdmin, plain, run } = require('./lib/admin_runtime');

const NAME = 'finish_account_deletion';
const SPEC = { values: ['--uid', '--project', '--key'], flags: ['--all-deleted', '--emulator', '--yes'] };

const docsOf = (snapshot) => Object.fromEntries(snapshot.docs.map((d) => [d.id, plain(d.data())]));

/** Planlayıcının girdisi: hesabın kalan belgeleri (okuma; yazım yok). */
async function readState(db, uid) {
  const get = async (path) => {
    const snap = await db.doc(path).get();
    return snap.exists ? plain(snap.data()) : null;
  };
  const memberships = docsOf(await db.collection('memberships').where('userId', '==', uid).get());
  const rsvps = docsOf(await db.collection('rsvps').where('userId', '==', uid).get());
  const contacts = {};
  const clubs = {};
  for (const [id, m] of Object.entries(memberships)) {
    contacts[id] = await get(`memberships/${id}/private/contact`);
    if (!(m.clubId in clubs)) clubs[m.clubId] = await get(`clubs/${m.clubId}`);
  }
  const events = {};
  for (const r of Object.values(rsvps)) if (!(r.eventId in events)) events[r.eventId] = await get(`events/${r.eventId}`);
  const live = (q) => q.where('isDeleted', '==', false).get().then(docsOf);
  return {
    uid,
    now: new Date(),
    user: await get(`users/${uid}`),
    account: await get(`users/${uid}/private/account`),
    memberships,
    contacts,
    clubs,
    rsvps,
    events,
    personal: {
      notifications: await live(db.collection('notifications').where('userId', '==', uid)),
      savedPosts: await live(db.collection('savedPosts').where('userId', '==', uid)),
      blocks: await live(db.collection('blocks').where('blockerId', '==', uid)),
    },
  };
}

async function main() {
  const argv = process.argv.slice(2);
  if (argv.length === 0 || argv.includes('-h') || argv.includes('--help')) {
    console.log(fs.readFileSync(__filename, 'utf8').split('\n').slice(3, 20).join('\n').replace(/^ \* ?/gm, ''));
    return;
  }
  const args = parseArgs(argv, SPEC);
  if (!args.uid === !args.allDeleted) throw new UsageError('--uid <uid> ya da --all-deleted ver (yalnızca biri)');
  const admin = loadAdmin(NAME);
  const target = initApp(NAME, admin, args);
  const db = admin.firestore();

  const uids = args.uid
    ? [args.uid]
    : (await db.collection('users').where('status', '==', 'deleted').get()).docs.map((d) => d.id);
  console.log(`Proje      : ${target.projectId}${target.emulator ? ' (emülatör)' : ''}`);
  console.log(`Hesaplar   : ${uids.length}`);

  const plans = [];
  for (const uid of uids) {
    const plan = buildCleanupPlan(await readState(db, uid));
    const writes = plan.units.flat();
    console.log(`\n— ${uid}: ${plan.skip ? `atlandı (${plan.skip})` : `${writes.length} yazım ${JSON.stringify(plan.counts)}`}`);
    if (writes.length > 0) console.log(describeWrites(writes));
    for (const warning of plan.warnings) console.log(`  ! ${warning}`);
    if (!plan.skip && writes.length > 0) plans.push({ uid, plan });
  }
  if (plans.length === 0) {
    console.log('\nYapılacak iş yok.');
    return;
  }
  if (!(await confirmApply(NAME, target, args.yes, `${plans.length} silinmiş hesabın temizliği YAZILACAK.`))) return;
  for (const { uid, plan } of plans) {
    const written = await commitBatches(admin, db, packUnits(plan.units, BATCH_MAX_WRITES));
    console.log(`${uid}: ${written} yazım uygulandı.`);
  }
}

if (require.main === module) run(NAME, main);
