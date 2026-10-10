'use strict';
// tool/check_design_coverage.js öz-testi: aksiyon envanteri (AKS01/AKS02/AKS03), dinamik kalıplar (CD-86),
// muaf dosyası (CD-122(4)) ve NAV.* sekme kökü kuralı (K-17, CD-53, PLAN §19.10) — CD-79.
//
// fixtures/check_design_coverage/repo   tool/design_{exempt,dynamic}_actions.txt var; task başına bir senaryo:
//   T-01 CLB-01 + EVT-01 (sekme kökleri) temiz · T-02 CLB-02 (kök değil, envanterinde NAV var) temiz ·
//   T-03 AUT-01 muaf uygulanmış · T-04 FED-01 eksik + fazla + fixture'a özgü muaf
// fixtures/check_design_coverage/bare   kalıp dosyaları yok; kabukta NAV eksiği ve fazlası
// fixtures/check_design_coverage/catalog      T-07 katalogları (ToastId · SheetId · DialogId · MenuId — CD-113) temiz;
//   T-08 sahip task: katalog dosyalarındaki iz / kullanım kanıt sayılmaz (EVT-MENU izi yok, TST-X1 yalnızca katalogda)
// fixtures/check_design_coverage/catalog_bad  MenuId: evtMenu eksik, sht01 izi yanlış, clbMenu fazla
const test = require('node:test');
const assert = require('node:assert/strict');
const { fixture, runTool, runJson } = require('./helpers');

const REPO = fixture('check_design_coverage', 'repo');
const BARE = fixture('check_design_coverage', 'bare');
const CATALOG = fixture('check_design_coverage', 'catalog');
const CATALOG_BAD = fixture('check_design_coverage', 'catalog_bad');
const rules = (json) => json.errors.map((e) => `${e.rule} ${e.id}`).sort();
const cov = (root, ...args) => runJson('check_design_coverage.js', ['--root', root, ...args]);
const aks = (json) => json.errors.filter((e) => /^AKS/.test(e.rule)).map((e) => `${e.rule} ${e.id}`).sort();
const rowOf = (json, id) => json.actions.find((r) => r.id === id);

test('check_design_coverage · --map muaf sayısını tool/design_exempt_actions.txt\'ten okur', () => {
  const r = runTool('check_design_coverage.js', ['--root', REPO, '--map']);
  assert.equal(r.code, 0, r.stderr);
  // 3 muaf = AUT-01.demoAccount.ayse + AUT-01.demoToggle + FED-01.demoOnly (yalnızca fixture dosyasındaki kalıp)
  assert.match(r.stdout, /15 aksiyon, 3 muaf/);
  const bare = runTool('check_design_coverage.js', ['--root', BARE, '--map']);
  assert.equal(bare.code, 0, bare.stderr);
  assert.match(bare.stdout, /6 aksiyon, 0 muaf/, 'muaf dosyası yoksa muaf yok (gömülü liste kalmadı)');
});

test('check_design_coverage · --list muafları dosyadan sayar', () => {
  const r = runTool('check_design_coverage.js', ['--root', REPO, '--task', 'T-03', '--list']);
  assert.equal(r.code, 0);
  assert.match(r.stdout, /AUT-01 .*· 3 aksiyon \(2 muaf\)/);
});

test('check_design_coverage · NAV.* sekme kökünde kabuktan sayılır (K-17, CD-53)', () => {
  const { code, json } = cov(REPO, '--task', 'T-01', '--actions');
  assert.deepEqual(json.errors, []);
  assert.equal(code, 0);
  assert.deepEqual(rowOf(json, 'CLB-01'), { id: 'CLB-01', expected: 4, found: 4, missing: 0, extra: 0, dynamic: 1 });
  assert.deepEqual(rowOf(json, 'EVT-01'), { id: 'EVT-01', expected: 3, found: 3, missing: 0, extra: 0, dynamic: 0 });
});

test('check_design_coverage · NAV.* sekme kökü olmayan ekranda beklenmez ve AKS02 üretmez', () => {
  // CLB-02 envanterinde NAV.tab.clubs var (K-17 çift sayım) ama CLB-02 registry.tabRoot değil
  const { code, json } = cov(REPO, '--task', 'T-02', '--actions');
  assert.deepEqual(json.errors, []);
  assert.equal(code, 0);
  assert.deepEqual(rowOf(json, 'CLB-02'), { id: 'CLB-02', expected: 1, found: 1, missing: 0, extra: 0, dynamic: 0 });
});

test('check_design_coverage · NAV.* eksiği her sekme kökünde AKS01, hiçbir kök envanterinde olmayan NAV.* bir kez AKS02', () => {
  const { code, json } = cov(BARE, '--task', 'T-01', '--actions');
  assert.equal(code, 1);
  const nav = json.errors.filter((e) => /^NAV\./.test(e.id));
  assert.deepEqual(nav.map((e) => `${e.rule} ${e.id}`).sort(), ['AKS01 NAV.tab.events', 'AKS01 NAV.tab.events', 'AKS02 NAV.tab.bogus']);
  assert.deepEqual(nav.filter((e) => e.rule === 'AKS01').map((e) => /\((\w+-\d+)\)$/.exec(e.msg)[1]).sort(), ['CLB-01', 'EVT-01']);
  assert.match(nav.find((e) => e.rule === 'AKS02').msg, /app_shell_view\.dart:4 hiçbir sekme kökü/);
});

test('check_design_coverage · AKS01 eksik anahtar, AKS02 fazla anahtar', () => {
  const { code, json } = cov(REPO, '--task', 'T-04', '--actions');
  assert.equal(code, 1);
  assert.ok(aks(json).includes('AKS01 FED-01.comment.p01'));
  assert.ok(aks(json).includes('AKS02 FED-01.bogus'));
  assert.deepEqual(rowOf(json, 'FED-01'), { id: 'FED-01', expected: 2, found: 1, missing: 1, extra: 1, dynamic: 0 });
});

test('check_design_coverage · AKS03 muaf (demo) aksiyon uygulanmış; muaf anahtar beklenmez', () => {
  const t03 = cov(REPO, '--task', 'T-03', '--actions');
  assert.equal(t03.code, 1);
  assert.deepEqual(aks(t03.json), ['AKS03 AUT-01.demoToggle']); // AUT-01.demoAccount.ayse uygulanmadı → AKS01 de yok
  assert.deepEqual(rowOf(t03.json, 'AUT-01'), { id: 'AUT-01', expected: 1, found: 1, missing: 0, extra: 0, dynamic: 0 });
  // fixture'a özgü muaf kalıp (FED-01.demoOnly) da dosyadan okunur
  const t04 = cov(REPO, '--task', 'T-04', '--actions');
  assert.deepEqual(aks(t04.json), ['AKS01 FED-01.comment.p01', 'AKS02 FED-01.bogus', 'AKS03 FED-01.demoOnly']);
});

test('check_design_coverage · dinamik kalıba uyan fazla anahtar AKS02 sayılmaz; dosya yoksa sayılır (CD-86)', () => {
  // repo: CLB-01.myClub.* ↔ tool/design_dynamic_actions.txt `CLB-01.myClub.*`
  const repo = cov(REPO, '--task', 'T-01', '--actions');
  assert.ok(!repo.json.errors.some((e) => e.id === 'CLB-01.myClub.*'));
  assert.equal(rowOf(repo.json, 'CLB-01').dynamic, 1);
  // bare: aynı anahtar, dinamik dosya yok → AKS02
  const bare = cov(BARE, '--task', 'T-01', '--actions');
  assert.ok(aks(bare.json).includes('AKS02 CLB-01.myClub.*'));
  assert.equal(rowOf(bare.json, 'CLB-01').extra, 1);
});

test('check_design_coverage · dinamik kalıp AKS01\'i aklamaz', () => {
  // repo dinamik dosyasında `FED-01.comment.*` var; envanterdeki FED-01.comment.p01 kodda yok → yine AKS01
  const { json } = cov(REPO, '--task', 'T-04', '--actions');
  assert.ok(json.errors.some((e) => e.rule === 'AKS01' && e.id === 'FED-01.comment.p01'));
  assert.equal(rowOf(json, 'FED-01').missing, 1);
});

test('check_design_coverage · KAT: MenuId registry.json#menus ile denetlenir (CD-113)', () => {
  const map = runTool('check_design_coverage.js', ['--root', CATALOG, '--map']);
  assert.equal(map.code, 0, map.stderr);
  // T-07 kapsamında kimlik yok; katalog denetimi (ToastId · SheetId · DialogId · MenuId) temiz
  const ok = cov(CATALOG, '--task', 'T-07');
  assert.deepEqual(ok.json.errors, []);
  assert.equal(ok.code, 0);
  // evtMenu üyesi yok → KAT02; clbMenu registry'de yok → KAT03; sht01 üstündeki iz SHT-02 → KAT04
  const bad = cov(CATALOG_BAD, '--task', 'T-07');
  assert.equal(bad.code, 1);
  assert.deepEqual(rules(bad.json), ['KAT02 EVT-MENU', 'KAT03 clbMenu', 'KAT04 SHT-01']);
  assert.match(bad.json.errors.find((e) => e.rule === 'KAT02').msg, /MenuId\.evtMenu üyesi yok/);
  assert.match(bad.json.errors.find((e) => e.rule === 'KAT04').msg, /menu_id\.dart:\d+ MenuId\.sht01/);
});

test('check_design_coverage · KAT01: registry\'de menü yoksa `enum MenuId` aranmaz', () => {
  // repo fixture'ı: registry.menus boş, MenuId yok → --all katalog denetiminde MenuId için KAT01 üretilmez
  const repo = cov(REPO, '--all');
  const kat01 = repo.json.errors.filter((e) => e.rule === 'KAT01').map((e) => e.id).sort();
  assert.deepEqual(kat01, ['DialogId', 'SheetId', 'ToastId']);
});

test('check_design_coverage · katalog dosyaları (enum + catalogs/toasts|dialogs) iz ve kullanım kanıtı değildir', () => {
  const { code, json } = cov(CATALOG, '--task', 'T-08');
  assert.equal(code, 1);
  // EVT-MENU: menu_id.dart ve catalogs/dialogs içindeki `/// Design:` satırları sınıf izi sayılmaz → IZ01
  // TST-X1: yalnızca catalogs/toasts/toast_catalog.dart içinde geçiyor → ölü toast (KUL01)
  assert.deepEqual(rules(json), ['IZ01 EVT-MENU', 'KUL01 TST-X1']);
  const row = (id) => json.rows.find((r) => r.id === id);
  assert.deepEqual([row('TST-01').trace, row('TST-01').usage], [true, true]);
  assert.deepEqual([row('TST-X1').trace, row('TST-X1').usage], [true, false]);
  assert.deepEqual([row('SHT-01').trace, row('SHT-01').usage], [true, true]);
  assert.deepEqual([row('DLG-01').trace, row('DLG-01').usage], [true, true]);
  assert.deepEqual(json.warnings, []);
});
