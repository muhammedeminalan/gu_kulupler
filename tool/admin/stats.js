#!/usr/bin/env node
'use strict';
/**
 * İstatistik özeti (salt okunur): hesaplar, push alabilen cihazlar, kulüpler, üyelikler, yaklaşan etkinlikler,
 * son gönderiler, açık şikayet / destek talepleri.
 *
 *   node tool/admin/stats.js [--project <id>] [--key <json>] [--json]
 *
 * Hiçbir şey yazmaz. Sayımlar Firestore `count()` ile (belge başına okuma ücreti yok, sorgu başına 1); push cihaz
 * sayısı etkin kullanıcıların hesap belgelerinden okunur. Anahtar REPO DIŞINDA (D-36).
 */
const fs = require('fs');
const { parseArgs } = require('./lib/admin_cli');
const { collectTokens } = require('./lib/push_broadcast');
const { formatStats, jsonLine } = require('./lib/admin_reports');
const { initApp, loadAdmin, run } = require('./lib/admin_runtime');

const NAME = 'stats';
const SPEC = { values: ['--project', '--key'], flags: ['--json', '--emulator'] };
const WEEK_MS = 7 * 24 * 60 * 60 * 1000;

async function main() {
  const argv = process.argv.slice(2);
  if (argv.includes('-h') || argv.includes('--help')) {
    console.log(fs.readFileSync(__filename, 'utf8').split('\n').slice(3, 11).join('\n').replace(/^ \* ?/gm, ''));
    return;
  }
  const args = parseArgs(argv, SPEC);
  const admin = loadAdmin(NAME);
  const target = initApp(NAME, admin, args);
  const db = admin.firestore();
  const now = new Date();
  const count = async (query) => (await query.count().get()).data().count;

  let authUsers = 0;
  let pageToken;
  do {
    const page = await admin.auth().listUsers(1000, pageToken);
    authUsers += page.users.length;
    pageToken = page.pageToken;
  } while (pageToken);

  const activeUserSnap = await db.collection('users').where('status', '==', 'active').where('isDeleted', '==', false).select().get();
  const refs = activeUserSnap.docs.map((d) => db.doc(`users/${d.id}/private/account`));
  let pushUsers = 0;
  const accounts = [];
  for (let i = 0; i < refs.length; i += 300) {
    for (const s of await db.getAll(...refs.slice(i, i + 300))) {
      if (!s.exists) continue;
      accounts.push(s.data());
      if (collectTokens([s.data()]).length > 0) pushUsers += 1;
    }
  }

  const [activeClubs, activeMemberships, upcomingEvents, recentPosts, openReports, openTickets] = await Promise.all([
    count(db.collection('clubs').where('status', '==', 'active').where('isDeleted', '==', false)),
    count(db.collection('memberships').where('status', '==', 'active').where('isDeleted', '==', false)),
    count(db.collection('events').where('startsAt', '>=', now).where('startsAt', '<', new Date(now.getTime() + WEEK_MS))),
    count(db.collection('posts').where('createdAt', '>=', new Date(now.getTime() - WEEK_MS))),
    count(db.collection('reports').where('status', '==', 'open')),
    count(db.collection('supportTickets').where('status', '==', 'open')),
  ]);

  const counts = {
    authUsers,
    activeUsers: activeUserSnap.size,
    pushUsers,
    pushDevices: collectTokens(accounts).length,
    activeClubs,
    activeMemberships,
    upcomingEvents,
    recentPosts,
    openReports,
    openTickets,
  };
  if (args.json) {
    console.log(jsonLine({ kind: 'stats', projectId: target.projectId, generatedAt: now.toISOString(), counts }));
    return;
  }
  console.log(`Proje        : ${target.projectId}  ·  ${now.toISOString().slice(0, 16).replace('T', ' ')} UTC`);
  for (const line of formatStats(counts)) console.log(line);
}

if (require.main === module) run(NAME, main);
