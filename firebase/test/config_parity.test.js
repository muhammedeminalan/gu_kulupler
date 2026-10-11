'use strict';
// firebase.rules-test.json ↔ firebase.json: aynı kural/indeks dosyaları, farklı portlar (CD-133).
const fs = require('node:fs');
const { FIREBASE_JSON, DEV_FIREBASE_JSON } = require('./setup/emulator_ports');

const read = (file) => JSON.parse(fs.readFileSync(file, 'utf8'));

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
