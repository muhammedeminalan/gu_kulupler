#!/usr/bin/env node
'use strict';
/**
 * Demo içeriği GERÇEK projeye yazar (App Store incelemesi / tanıtım): 14 kulüp, üyelikler, gönderiler,
 * yorumlar, etkinlikler, katılımlar ve demo profiller + kulüp / gönderi yer tutucu görselleri (Storage).
 *
 *   node tool/admin/seed_demo_content.js            # kuru: yazılacak belge ve görsel sayıları
 *   node tool/admin/seed_demo_content.js --yes      # yaz (TTY'de proje kimliği sorulur)
 *   node tool/admin/seed_demo_content.js ... [--project <id>] [--key <json>] [--bucket <ad>]
 *
 * Güvenlik:
 *  - Varsayılan KURU çalıştırmadır. Demo kulüplerinden biri zaten varsa HİÇBİR ŞEY yazmadan durur (çift tohum yok).
 *  - Bildirim ve şikayet yazılmaz (Functions push tetiklerdi); Auth kullanıcısı açılmaz (demo profillerle giriş
 *    yapılamaz). Silme yok (D-10). Anahtar REPO DIŞINDA (D-36).
 */
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const { UsageError, parseArgs } = require('./lib/admin_cli');
const { buildDemoContent, toBatches } = require('./lib/demo_content');
const { commitBatches, confirmApply, initApp, loadAdmin, run } = require('./lib/admin_runtime');
const { placeholderPng } = require('../seed/placeholder_png');

const NAME = 'seed_demo_content';
const SPEC = { values: ['--project', '--key', '--bucket'], flags: ['--emulator', '--yes'] };
const SEED_DIR = path.join(__dirname, '..', 'seed');
const readJson = (file) => JSON.parse(fs.readFileSync(path.join(SEED_DIR, file), 'utf8'));

async function main() {
  const argv = process.argv.slice(2);
  if (argv.includes('-h') || argv.includes('--help')) {
    console.log(fs.readFileSync(__filename, 'utf8').split('\n').slice(3, 14).join('\n').replace(/^ \* ?/gm, ''));
    return;
  }
  const args = parseArgs(argv, SPEC);
  if (args.emulator) throw new UsageError('emülatör için tool/seed/seed_emulator.js kullan');
  const plan = buildDemoContent(
    { data: readJson('demo-data.json'), extraNotifications: readJson('demo-notifications.json'), management: readJson('demo-management.json') },
    { now: new Date(), randomHex: () => crypto.randomBytes(8).toString('hex') },
  );
  const admin = loadAdmin(NAME);
  const target = initApp(NAME, admin, args);
  const db = admin.firestore();
  const bucketName = args.bucket || `${target.projectId}.firebasestorage.app`;

  const existing = (await db.getAll(...plan.clubIds.map((id) => db.doc(`clubs/${id}`)))).filter((s) => s.exists);
  console.log(`Proje      : ${target.projectId}  ·  kova: ${bucketName}`);
  for (const [key, count] of Object.entries(plan.counts)) console.log(`  ${key.padEnd(28)} ${count}`);
  console.log(`Toplam     : ${plan.writes.length} belge  ·  ${plan.images.length} görsel`);
  if (existing.length > 0) {
    throw new UsageError(`demo içerik zaten var (${existing.map((s) => s.id).join(', ')}); hiçbir şey yazılmadı`);
  }
  if (!(await confirmApply(NAME, target, args.yes, `${plan.writes.length} belge ve ${plan.images.length} görsel YAZILACAK.`))) return;

  const written = await commitBatches(admin, db, toBatches(plan.writes));
  console.log(`Firestore  : ${written} belge yazıldı`);
  const bucket = admin.storage().bucket(bucketName);
  for (const image of plan.images) {
    await bucket.file(image.path).save(placeholderPng(image.seed, image.width, image.height), {
      contentType: 'image/png',
      resumable: false,
      // Uygulamanın yüklediği üst veriyle aynı (storage.rules `clubMetadataOnly()`) + indirme jetonu (getDownloadURL).
      metadata: { metadata: { clubId: image.clubId, uploaderId: image.uploaderId, firebaseStorageDownloadTokens: crypto.randomUUID() } },
    });
  }
  console.log(`Storage    : ${plan.images.length} görsel yüklendi`);
}

if (require.main === module) run(NAME, main);
