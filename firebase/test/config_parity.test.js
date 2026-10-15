'use strict';
// firebase.rules-test.json ↔ firebase.json: aynı kural/indeks dosyaları, farklı portlar (CD-133).
// T-42 (CD-165 e, f): firebase.functions-test.json (functions/ testleri) de aynı kural/indeks dosyalarını kullanır;
// üç yapılandırmanın açık portları birbirinden ayrıktır (geliştirme emülatörü, Rules testleri ve Functions testleri
// aynı anda koşabilir, birbirinin verisini silmez). firebase.json `functions` bölümü functions/package.json ile uyumlu.
const fs = require('node:fs');
const path = require('node:path');
const { FIREBASE_JSON, DEV_FIREBASE_JSON } = require('./setup/emulator_ports');

const read = (file) => JSON.parse(fs.readFileSync(file, 'utf8'));
const REPO_ROOT = path.resolve(__dirname, '..', '..');
const FUNCTIONS_TEST_JSON = path.join(REPO_ROOT, 'firebase.functions-test.json');

/** Yapılandırmanın açıkça yazılmış emülatör portları (`port`, `websocketPort`). */
function explicitPorts(config) {
  const out = [];
  for (const [name, block] of Object.entries(config.emulators || {})) {
    if (!block || typeof block !== 'object') continue;
    for (const key of ['port', 'websocketPort']) {
      if (Number.isInteger(block[key])) out.push({ name: `${name}.${key}`, port: block[key] });
    }
  }
  return out;
}

describe('T-12 · Rules test yapılandırması', () => {
  const test_ = read(FIREBASE_JSON);
  const dev = read(DEV_FIREBASE_JSON);

  test('kural ve indeks dosyaları geliştirme yapılandırmasıyla aynı', () => {
    expect(test_.firestore).toEqual(dev.firestore);
    expect(test_.storage).toEqual(dev.storage);
  });

  test('portlar geliştirme emülatöründen farklı (çakışma ve veri silme yok)', () => {
    for (const name of ['auth', 'firestore', 'storage']) {
      expect(Number.isInteger(test_.emulators[name].port)).toBe(true);
      expect(test_.emulators[name].port).not.toBe(dev.emulators[name].port);
    }
    expect(test_.emulators.ui.enabled).toBe(false);
  });
});

describe('T-42 · Functions yapılandırması (Mod F, CD-165)', () => {
  const dev = read(DEV_FIREBASE_JSON);
  const rulesTest = read(FIREBASE_JSON);
  const functionsTest = read(FUNCTIONS_TEST_JSON);
  const functionsPackage = read(path.join(REPO_ROOT, 'functions', 'package.json'));

  test('firebase.json functions bölümü: tek kod tabanı, functions/ kaynağı, Node sürümü package.json ile aynı, deploy öncesi derleme', () => {
    expect(dev.functions).toHaveLength(1);
    const [fn] = dev.functions;
    expect(fn).toMatchObject({ source: 'functions', codebase: 'default' });
    expect(fn.runtime).toBe(`nodejs${functionsPackage.engines.node}`);
    expect(fn.predeploy.join(' ')).toMatch(/run build/);
    for (const pattern of ['node_modules', 'test']) expect(fn.ignore).toContain(pattern);
    expect(Number.isInteger(dev.emulators.functions.port)).toBe(true);
  });

  test('Functions testleri aynı kural / indeks dosyalarını kullanır ve arayüz kapalıdır', () => {
    expect(functionsTest.firestore).toEqual(dev.firestore);
    expect(functionsTest.emulators.ui.enabled).toBe(false);
    expect(functionsTest.emulators.firestore.port).toBeDefined();
  });

  test('üç yapılandırmanın açık portları ayrıktır (geliştirme + Rules testleri + Functions testleri aynı anda)', () => {
    const all = [
      ...explicitPorts(dev).map((p) => ({ ...p, config: 'firebase.json' })),
      ...explicitPorts(rulesTest).map((p) => ({ ...p, config: 'firebase.rules-test.json' })),
      ...explicitPorts(functionsTest).map((p) => ({ ...p, config: 'firebase.functions-test.json' })),
    ];
    const byPort = new Map();
    for (const p of all) byPort.set(p.port, [...(byPort.get(p.port) || []), `${p.config}:${p.name}`]);
    const clashes = [...byPort.entries()].filter(([, users]) => users.length > 1);
    expect(clashes).toEqual([]);
  });
});
