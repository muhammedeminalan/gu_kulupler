'use strict';
// Emülatör adresleri — tek kaynak kökteki firebase.json `emulators` bloğudur (PLAN §11.6).
// `firebase emulators:exec` ortam değişkenlerini (FIRESTORE_EMULATOR_HOST …) de verir; verdiyse
// firebase.json ile AYNI portu göstermek zorundadır (sapma = yanlış emülatöre konuşma riski → hata).
const fs = require('node:fs');
const path = require('node:path');

const FIREBASE_JSON = path.resolve(__dirname, '..', '..', '..', 'firebase.json');
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
  if (!config.emulators) throw new Error('firebase.json: `emulators` bloğu yok');
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
  if (!block || !Number.isInteger(block.port)) throw new Error(`firebase.json: emulators.${name}.port yok`);
  const fromEnv = process.env[ENV_VARS[name]];
  if (!fromEnv) return { host: block.host || DEFAULT_HOST, port: block.port };
  const env = splitHostPort(fromEnv);
  if (env.port !== block.port) {
    throw new Error(`${ENV_VARS[name]}=${fromEnv} portu firebase.json (${block.port}) ile farklı`);
  }
  if (!LOOPBACK_HOSTS.includes(env.host)) {
    throw new Error(`${ENV_VARS[name]}=${fromEnv} yerel adres değil — Rules testleri yalnızca yerel emülatörde koşar`);
  }
  return env;
}

/** firebase.json'daki Rules dosyasının mutlak yolu (`firestore.rules` / `storage.rules`). */
function rulesPath(service) {
  const block = readConfig()[service];
  if (!block || !block.rules) throw new Error(`firebase.json: ${service}.rules yok`);
  return path.resolve(path.dirname(FIREBASE_JSON), block.rules);
}

module.exports = { FIREBASE_JSON, emulator, rulesPath, splitHostPort };
