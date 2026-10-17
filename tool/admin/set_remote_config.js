#!/usr/bin/env node
'use strict';
/**
 * Bakım bandı ve zorunlu güncelleme (Remote Config) — Firebase Console'a girmeden.
 *
 *   node tool/admin/set_remote_config.js                                   # şu anki durum
 *   node tool/admin/set_remote_config.js --maintenance "Bakım 22:00'de" [--yes]   # bakım bandını aç
 *   node tool/admin/set_remote_config.js --maintenance-off [--yes]                # bakım bandını kapat
 *   node tool/admin/set_remote_config.js --min-build 2 [--yes]                    # build 2 altı güncellemeye zorlanır
 *
 * Güvenlik:
 *  - Varsayılan KURU çalıştırmadır (değişiklik basılır); `--yes` yayınlar. Gerçek projede TTY'de ya da yerel admin
 *    panelinde proje kimliğiyle onaylanır; anahtar REPO DIŞINDA (D-36). Remote Config'in emülatörü yoktur.
 *  - Uygulamalar değişikliği anlık alır (realtime). `firebase deploy --only remoteconfig` şablon dosyasındaki
 *    değerleri geri yükler; dosyayı da güncel tut.
 */
const fs = require('fs');
const { UsageError, parseArgs } = require('./lib/admin_cli');
const { describeState, planRemoteConfig } = require('./lib/remote_config_plan');
const { confirmApply, initApp, loadAdmin, run } = require('./lib/admin_runtime');

const NAME = 'set_remote_config';
const SPEC = { values: ['--maintenance', '--min-build', '--project', '--key'], flags: ['--maintenance-off', '--emulator', '--yes'] };

async function main() {
  const argv = process.argv.slice(2);
  if (argv.includes('-h') || argv.includes('--help')) {
    console.log(fs.readFileSync(__filename, 'utf8').split('\n').slice(3, 17).join('\n').replace(/^ \* ?/gm, ''));
    return;
  }
  const args = parseArgs(argv, SPEC);
  if (args.emulator) throw new UsageError("Remote Config'in emülatörü yok; gerçek projede çalıştır");
  const admin = loadAdmin(NAME);
  const target = initApp(NAME, admin, args);
  const rc = admin.remoteConfig();
  const template = await rc.getTemplate();
  const plan = planRemoteConfig(template, { maintenance: args.maintenance, maintenanceOff: args.maintenanceOff, minBuild: args.minBuild });
  console.log(`Proje      : ${target.projectId}  ·  şablon sürümü ${template.version?.versionNumber ?? '—'}`);
  for (const line of describeState(template)) console.log(line);
  if (plan.changes.length === 0) {
    if (args.maintenance !== null || args.maintenanceOff || args.minBuild !== null) console.log('Değişiklik yok.');
    return;
  }
  console.log('Değişecek  :');
  for (const c of plan.changes) console.log(`  ${c.key}: ${JSON.stringify(c.from)} → ${JSON.stringify(c.to)}`);
  if (plan.changes.some((c) => c.key === 'min_supported_build')) {
    console.log('  ! Bu numaranın altındaki tüm sürümler "Güncelle" ekranına düşer (TestFlight / APK dahil).');
  }
  if (!(await confirmApply(NAME, target, args.yes, 'Remote Config YAYINLANACAK (uygulamalar anlık alır).'))) return;
  const validated = await rc.validateTemplate(plan.template);
  const published = await rc.publishTemplate(validated);
  console.log(`Yayınlandı : şablon sürümü ${published.version?.versionNumber ?? '—'}`);
  for (const line of describeState(published)) console.log(line);
}

if (require.main === module) run(NAME, main);
