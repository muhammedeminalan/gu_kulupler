'use strict';
// Jest `setupFilesAfterEnv`: her test dosyası için Rules test ortamını kurar (PLAN §11.6).
//  - Proje kimliği sabit `demo-gu-kulupler`: `demo-` önekli projeler yalnızca emülatörde yaşar;
//    gerçek `gu-kulupler` projesine bu testlerden hiçbir istek gidemez (Q-01, Q-03).
//  - Kurallar firebase.json'ın gösterdiği dosyalardan yüklenir (firebase/firestore.rules, storage.rules).
//  - Her testten önce Firestore ve Storage boşaltılır (emülatör API'si; uygulama kodunda silme yoktur).
const fs = require('node:fs');
const { initializeTestEnvironment } = require('@firebase/rules-unit-testing');
const { setLogLevel } = require('firebase/firestore');
const { emulator, rulesPath } = require('./emulator_ports');

const PROJECT_ID = 'demo-gu-kulupler';

let testEnv = null;

/** Dosya boyunca açık tutulan "kurallar kapalı" bağlamı: { context, release, done }. */
let admin = null;

/** Geçerli test dosyasının `RulesTestEnvironment` örneği. */
function getTestEnv() {
  if (!testEnv) throw new Error('Rules test ortamı kurulmadı (jest.config.js setupFilesAfterEnv)');
  return testEnv;
}

/**
 * Kuralları atlayan bağlam (veri kurma ve doğrulama okumaları için). `withSecurityRulesDisabled`
 * her çağrıda yeni bir istemci açıp kapatır (~70 ms); bunun yerine tek bir çağrının geri çağrısı
 * dosyanın sonuna kadar açık tutulur ve aynı istemci yeniden kullanılır.
 * @returns {Promise<{firestore: Function, storage: Function}>}
 */
async function getAdminContext() {
  if (admin) return admin.context;
  const env = getTestEnv();
  let release;
  const held = new Promise((resolve) => {
    release = resolve;
  });
  const holder = { release, done: null, context: null };
  const raw = await new Promise((resolve, reject) => {
    holder.done = env.withSecurityRulesDisabled((ctx) => {
      resolve(ctx);
      return held;
    });
    holder.done.catch(reject);
  });
  // firestore()/storage() her çağrıda emülatör ayarını yeniden uygular; örnekler bir kez alınır.
  const firestore = raw.firestore();
  const storage = raw.storage();
  holder.context = { firestore: () => firestore, storage: () => storage };
  admin = holder;
  return admin.context;
}

function assertDemoProject() {
  const fromCli = process.env.GCLOUD_PROJECT;
  if (fromCli && !fromCli.startsWith('demo-')) {
    throw new Error(`Rules testleri yalnızca demo- projesinde koşar; GCLOUD_PROJECT=${fromCli}`);
  }
}

beforeAll(async () => {
  assertDemoProject();
  // Beklenen ret vakaları SDK'nın uyarı günlüğünü doldurmasın.
  setLogLevel('error');
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { ...emulator('firestore'), rules: fs.readFileSync(rulesPath('firestore'), 'utf8') },
    storage: { ...emulator('storage'), rules: fs.readFileSync(rulesPath('storage'), 'utf8') },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.clearStorage();
});

afterAll(async () => {
  if (admin) {
    admin.release();
    await admin.done;
    admin = null;
  }
  if (testEnv) await testEnv.cleanup();
  testEnv = null;
});

module.exports = { PROJECT_ID, getTestEnv, getAdminContext };
