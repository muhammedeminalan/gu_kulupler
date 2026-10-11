'use strict';
// Emülatör adresleri — tek kaynak kökteki firebase.rules-test.json `emulators` bloğudur.
// Rules testleri geliştirme emülatöründen (firebase.json: 9099/8080/9199) AYRI portlarda koşar
// (9098/8088/9198): testler her testten önce veriyi boşalttığı için, açık duran geliştirme
// emülatörüyle çakışmaz ve onun seed verisini silmez (CD-133). Kural dosyası yolları iki
// yapılandırmada aynıdır (test/config_parity.test.js).
// `firebase emulators:exec` ortam değişkenlerini (FIRESTORE_EMULATOR_HOST …) de verir; verdiyse
// test yapılandırmasıyla AYNI portu göstermek zorundadır (sapma = yanlış emülatöre konuşma riski → hata).
const fs = require('node:fs');
const path = require('node:path');

const FIREBASE_JSON = path.resolve(__dirname, '..', '..', '..', 'firebase.rules-test.json');
/** Geliştirme emülatörünün yapılandırması (uygulama + seed). */
const DEV_FIREBASE_JSON = path.resolve(__dirname, '..', '..', '..', 'firebase.json');
const DEFAULT_HOST = '127.0.0.1';

/** Emülatörün dinlediği yerel adresler; başka bir makineye asla bağlanılmaz. */
const LOOPBACK_HOSTS = ['127.0.0.1', 'localhost', '[::1]', '::1'];

const ENV_VARS = {
  auth: 'FIREBASE_AUTH_EMULATOR_HOST',
  firestore: 'FIRESTORE_EMULATOR_HOST',
  storage: 'FIREBASE_STORAGE_EMULATOR_HOST',
};

function readConfig() {
  const config = JSON.parse(fs.readFileSync(FIREBASE_JSON, 'utf8'));
  if (!config.emulators) throw new Error('firebase.rules-test.json: `emulators` bloğu yok');
  return config;
}

/** `host:port` → { host, port }; IPv6 köşeli parantezli biçim desteklenir. */
function splitHostPort(value) {
  const at = value.lastIndexOf(':');
  if (at < 0) throw new Error(`geçersiz emülatör adresi: ${value}`);
  return { host: value.slice(0, at), port: Number(value.slice(at + 1)) };
}

/**
 * Bir emülatörün adresi: port firebase.json'dan, host ortam değişkeninden (yoksa 127.0.0.1).
 * @param {'auth'|'firestore'|'storage'} name
 * @returns {{host: string, port: number}}
 */
function emulator(name) {
  const block = readConfig().emulators[name];
  if (!block || !Number.isInteger(block.port)) throw new Error(`firebase.rules-test.json: emulators.${name}.port yok`);
  const fromEnv = process.env[ENV_VARS[name]];
  if (!fromEnv) return { host: block.host || DEFAULT_HOST, port: block.port };
  const env = splitHostPort(fromEnv);
  if (env.port !== block.port) {
    throw new Error(`${ENV_VARS[name]}=${fromEnv} portu firebase.rules-test.json (${block.port}) ile farklı`);
  }
  if (!LOOPBACK_HOSTS.includes(env.host)) {
    throw new Error(`${ENV_VARS[name]}=${fromEnv} yerel adres değil — Rules testleri yalnızca yerel emülatörde koşar`);
  }
  return env;
}

/** firebase.json'daki Rules dosyasının mutlak yolu (`firestore.rules` / `storage.rules`). */
function rulesPath(service) {
  const block = readConfig()[service];
  if (!block || !block.rules) throw new Error(`firebase.rules-test.json: ${service}.rules yok`);
  return path.resolve(path.dirname(FIREBASE_JSON), block.rules);
}

module.exports = { FIREBASE_JSON, DEV_FIREBASE_JSON, emulator, rulesPath, splitHostPort };
