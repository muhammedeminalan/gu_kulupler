'use strict';
// Bakım / güncelleme planı ve salt okunur rapor biçimleyicileri (firebase-admin yüklenmez).
const test = require('node:test');
const assert = require('node:assert/strict');
const { KEYS, MAINTENANCE_MAX, describeState, planRemoteConfig } = require('../admin/lib/remote_config_plan');
const { formatStats, formatUserReport } = require('../admin/lib/admin_reports');

const template = () => ({
  version: { versionNumber: '7' },
  parameters: {
    [KEYS.maintenance]: { defaultValue: { value: '' }, valueType: 'STRING' },
    [KEYS.minBuild]: { defaultValue: { value: '1' }, valueType: 'NUMBER' },
    announcement_daily_limit: { defaultValue: { value: '2' }, valueType: 'NUMBER' },
  },
});

test('planRemoteConfig: bakımı aç / kapat, min build; girdi şablonu değişmez, diğer parametreler korunur', () => {
  const base = template();
  const on = planRemoteConfig(base, { maintenance: '  Bakım 22:00  ' });
  assert.deepEqual(on.changes, [{ key: KEYS.maintenance, from: '', to: 'Bakım 22:00' }]);
  assert.equal(on.template.parameters[KEYS.maintenance].defaultValue.value, 'Bakım 22:00');
  assert.equal(on.template.parameters.announcement_daily_limit.defaultValue.value, '2');
  assert.equal(base.parameters[KEYS.maintenance].defaultValue.value, '', 'girdi değişmedi');

  const off = planRemoteConfig(on.template, { maintenanceOff: true });
  assert.deepEqual(off.changes, [{ key: KEYS.maintenance, from: 'Bakım 22:00', to: '' }]);
  assert.deepEqual(planRemoteConfig(base, { maintenanceOff: true }).changes, [], 'zaten kapalı → değişiklik yok');
  assert.deepEqual(planRemoteConfig(base, { minBuild: '2' }).changes, [{ key: KEYS.minBuild, from: '1', to: '2' }]);
  assert.deepEqual(planRemoteConfig(base, {}).changes, []);
});

test('planRemoteConfig: geçersiz girdiler reddedilir', () => {
  assert.throws(() => planRemoteConfig(template(), { maintenance: 'x', maintenanceOff: true }), /birlikte/);
  assert.throws(() => planRemoteConfig(template(), { maintenance: '   ' }), /boş/);
  assert.throws(() => planRemoteConfig(template(), { maintenance: 'a'.repeat(MAINTENANCE_MAX + 1) }), /en çok/);
  for (const bad of ['0', '-1', '1.5', 'iki', '100001']) {
    assert.throws(() => planRemoteConfig(template(), { minBuild: bad }), /tam sayı/, bad);
  }
  assert.throws(() => planRemoteConfig({ parameters: {} }, { minBuild: '2' }), /parametresi yok/);
});

test('describeState: bakım açık / kapalı ve min build', () => {
  assert.match(describeState(template()).join('\n'), /Bakım bandı : kapalı[\s\S]*build 1 altı/);
  const on = planRemoteConfig(template(), { maintenance: 'Bakım' }).template;
  assert.match(describeState(on)[0], /AÇIK — "Bakım"/);
});

test('formatUserReport: profil yoksa uyarı; jeton sayısı ve platformlar (jetonun kendisi basılmaz); silinmiş üyelik sayılmaz', () => {
  const auth = { uid: 'u1', email: 'a@gmail.com', emailVerified: true, disabled: false, customClaims: { superadmin: true },
    metadata: { creationTime: '2026-10-17T06:44:28Z', lastSignInTime: null } };
  const none = formatUserReport({ auth, profile: null, account: null, memberships: [], rsvps: [] }).join('\n');
  assert.match(none, /süper admin: EVET/);
  assert.match(none, /Profil       : YOK/);
  assert.match(none, /0 cihaz — push gitmez/);

  const full = formatUserReport({
    auth: { ...auth, customClaims: {} },
    profile: { name: 'Ayşe', status: 'active', profileComplete: true, department: 'd01', year: '2' },
    account: { fcmTokens: [{ token: 'GIZLI-JETON', platform: 'ios' }, { token: 't2', platform: 'android' }] },
    memberships: [{ clubId: 'c01', role: 'member', status: 'active' }, { clubId: 'c02', role: 'member', status: 'left', isDeleted: true }],
    rsvps: [{ status: 'going' }],
  }).join('\n');
  assert.match(full, /2 cihaz \(ios 1 · android 1\)/);
  assert.doesNotMatch(full, /GIZLI-JETON/);
  assert.match(full, /Üyelik       : 1 \(active 1\)/);
  assert.match(full, /c01  member  active/);
  assert.doesNotMatch(full, /c02/);
  assert.match(full, /Etkinlik     : 1 \(going 1\)/);
});

test('formatStats: eksik sayı — ile gösterilir', () => {
  const lines = formatStats({ authUsers: 230, activeUsers: 226, pushUsers: 3, pushDevices: 4 }).join('\n');
  assert.match(lines, /230 hesap  ·  226 etkin profil/);
  assert.match(lines, /3 kullanıcı \/ 4 cihaz/);
  assert.match(lines, /Kulüp        : — etkin/);
});
