'use strict';
/**
 * Remote Config değişiklik planı (set_remote_config.js) — saf (firebase-admin yüklemez; tool/test ile sınanır).
 * Parametreler firebase/remoteconfig.template.json ile aynıdır; uygulama `RemoteConfigKeys` ile okur.
 */

const KEYS = Object.freeze({ maintenance: 'maintenance_message', minBuild: 'min_supported_build' });
const MAINTENANCE_MAX = 200;
const MIN_BUILD_MAX = 100000;

/** Şablondaki parametrenin varsayılan değeri (yoksa `null`). */
const valueOf = (template, key) => template?.parameters?.[key]?.defaultValue?.value ?? null;

/**
 * İstenen değişiklikleri doğrular ve uygular (şablonun kopyası döner; girdi değişmez).
 * @param {object} template Remote Config şablonu (`getTemplate()` — `parameters` alanı)
 * @param {{maintenance?: string|null, maintenanceOff?: boolean, minBuild?: string|null}} input
 * @returns {{changes: Array<{key: string, from: string|null, to: string}>, template: object}}
 */
function planRemoteConfig(template, { maintenance = null, maintenanceOff = false, minBuild = null }) {
  if (maintenance !== null && maintenanceOff) throw new Error('--maintenance ve --maintenance-off birlikte verilemez');
  const wanted = {};
  if (maintenance !== null) {
    const text = maintenance.trim();
    if (!text) throw new Error('--maintenance boş olamaz (kapatmak için --maintenance-off)');
    if (text.length > MAINTENANCE_MAX) throw new Error(`--maintenance en çok ${MAINTENANCE_MAX} karakter (${text.length})`);
    wanted[KEYS.maintenance] = text;
  }
  if (maintenanceOff) wanted[KEYS.maintenance] = '';
  if (minBuild !== null) {
    const n = Number(String(minBuild).trim());
    if (!Number.isInteger(n) || n < 1 || n > MIN_BUILD_MAX) throw new Error(`--min-build 1–${MIN_BUILD_MAX} arası tam sayı olmalı`);
    wanted[KEYS.minBuild] = String(n);
  }
  const next = JSON.parse(JSON.stringify(template));
  next.parameters = next.parameters || {};
  const changes = [];
  for (const [key, to] of Object.entries(wanted)) {
    const from = valueOf(template, key);
    if (from === to) continue;
    if (!next.parameters[key]) throw new Error(`şablonda ${key} parametresi yok (önce firebase/remoteconfig.template.json yüklenmeli)`);
    next.parameters[key].defaultValue = { value: to };
    changes.push({ key, from, to });
  }
  return { changes, template: next };
}

/** Panel / terminal için okunur durum satırları. */
function describeState(template) {
  const maintenance = valueOf(template, KEYS.maintenance) || '';
  return [
    `Bakım bandı : ${maintenance ? `AÇIK — "${maintenance}"` : 'kapalı'}`,
    `Zorunlu güncelleme: build ${valueOf(template, KEYS.minBuild) ?? '—'} altı güncellemeye zorlanır`,
  ];
}

module.exports = { KEYS, MAINTENANCE_MAX, MIN_BUILD_MAX, describeState, planRemoteConfig, valueOf };
