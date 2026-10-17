#!/usr/bin/env node
'use strict';
/**
 * Kullanıcı bilgisi (salt okunur): Auth hesabı, profil, bildirim cihazı sayısı, üyelikler, etkinlik kayıtları.
 *
 *   node tool/admin/user_info.js --email <e-posta>
 *   node tool/admin/user_info.js --uid <uid> [--project <id>] [--key <json>]
 *
 * Hiçbir şey yazmaz. FCM jetonları basılmaz (yalnızca sayı / platform). Anahtar REPO DIŞINDA (D-36).
 */
const fs = require('fs');
const { UsageError, parseArgs } = require('./lib/admin_cli');
const { formatUserReport } = require('./lib/admin_reports');
const { initApp, loadAdmin, run } = require('./lib/admin_runtime');

const NAME = 'user_info';
const SPEC = { values: ['--email', '--uid', '--project', '--key'], flags: ['--emulator'] };

async function main() {
  const argv = process.argv.slice(2);
  if (argv.length === 0 || argv.includes('-h') || argv.includes('--help')) {
    console.log(fs.readFileSync(__filename, 'utf8').split('\n').slice(3, 10).join('\n').replace(/^ \* ?/gm, ''));
    return;
  }
  const args = parseArgs(argv, SPEC);
  if (!args.email === !args.uid) throw new UsageError('--email ya da --uid ver (yalnızca biri)');
  const admin = loadAdmin(NAME);
  initApp(NAME, admin, args);
  const db = admin.firestore();
  let auth;
  try {
    auth = args.uid ? await admin.auth().getUser(args.uid) : await admin.auth().getUserByEmail(args.email.trim());
  } catch (e) {
    if (e.code === 'auth/user-not-found') throw new UsageError('bu e-posta / uid ile hesap yok');
    throw e;
  }
  const [profile, account, memberships, rsvps] = await Promise.all([
    db.doc(`users/${auth.uid}`).get(),
    db.doc(`users/${auth.uid}/private/account`).get(),
    db.collection('memberships').where('userId', '==', auth.uid).limit(200).get(),
    db.collection('rsvps').where('userId', '==', auth.uid).limit(500).get(),
  ]);
  const lines = formatUserReport({
    auth,
    profile: profile.exists ? profile.data() : null,
    account: account.exists ? account.data() : null,
    memberships: memberships.docs.map((d) => d.data()),
    rsvps: rsvps.docs.map((d) => d.data()),
  });
  for (const line of lines) console.log(line);
}

if (require.main === module) run(NAME, main);
