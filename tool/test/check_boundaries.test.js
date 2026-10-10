'use strict';
// tool/check_boundaries.js öz-testi: B07 (kompozisyon kökü dışı core/product) ve B08 (gu_data barrel/arayüz) — CD-06, CD-79.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { TOOL_DIR, fixture, runTool, runJson } = require('./helpers');

/** Kural tanımı betikten okunur (fixture'lar kuralla birlikte değişsin diye kopya regex yok). */
function ruleRegex(name) {
  const src = fs.readFileSync(path.join(TOOL_DIR, 'check_boundaries.js'), 'utf8');
  const m = new RegExp(`const ${name} = /(.+)/([a-z]*);`).exec(src);
  assert.ok(m, `check_boundaries.js içinde ${name} tanımı bulunamadı`);
  return new RegExp(m[1], m[2]);
}

/** fixture kökündeki .dart dosyalarının göreli yolları */
function dartFiles(root) {
  const out = [];
  const walk = (dir) => {
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, e.name);
      if (e.isDirectory()) walk(full);
      else if (e.name.endsWith('.dart')) out.push(path.relative(root, full).split(path.sep).join('/'));
    }
  };
  walk(root);
  return out.sort();
}

const VIOLATING = fixture('check_boundaries', 'violating');
const CLEAN = fixture('check_boundaries', 'clean');

test('check_boundaries · --list B07 ve B08 kurallarını tanımlar', () => {
  const r = runTool('check_boundaries.js', ['--list']);
  assert.equal(r.code, 0);
  assert.match(r.stdout, /B07 [^·]*core\/product→features/);
  assert.match(r.stdout, /B08 gu_data barrel\/arayüz→Firebase/);
});

test('check_boundaries · fixture yolları betiğin B07 beyaz listesi ve B08 arayüz kalıbıyla uyumlu', () => {
  const whitelist = ruleRegex('B07_WHITELIST');
  const iface = ruleRegex('GU_DATA_INTERFACE');
  // temiz ağaçtaki kompozisyon kökleri beyaz listede, ihlalli ağaçtakiler değil
  for (const rel of ['lib/main.dart', 'lib/core/di/project_dependency.dart', 'lib/core/bootstrap/app_bootstrap.dart', 'lib/core/env/app_environment.dart', 'lib/product/navigation/routes/app_routes.dart', 'lib/product/navigation/shell/app_shell_view.dart']) {
    assert.ok(dartFiles(CLEAN).includes(rel), `temiz fixture'da ${rel} yok`);
    assert.match(rel, whitelist, `${rel} B07 beyaz listesinde olmalı`);
  }
  for (const rel of ['lib/core/util/club_helper.dart', 'lib/product/widget/club_badge.dart']) {
    assert.ok(dartFiles(VIOLATING).includes(rel), `ihlalli fixture'da ${rel} yok`);
    assert.doesNotMatch(rel, whitelist);
  }
  // B08: barrel ve firebase_ öneksiz repository arayüzü kapsamda; impl dosyası değil
  assert.match('packages/gu_data/lib/gu_data.dart', iface);
  assert.match('packages/gu_data/lib/src/repositories/club_repository.dart', iface);
  assert.doesNotMatch('packages/gu_data/lib/src/repositories/firebase_club_repository.dart', iface);
});

test('check_boundaries · B07: core/product feature import\'u ve core Firebase import\'u yakalanır', () => {
  const { code, json } = runJson('check_boundaries.js', ['--root', VIOLATING]);
  assert.equal(code, 1);
  const b07 = json.filter((v) => v.rule === 'B07').map((v) => `${v.file}:${v.line}`);
  assert.deepEqual(b07.sort(), [
    'lib/core/util/club_helper.dart:2', // ../../features/… (core → feature)
    'lib/core/util/club_helper.dart:3', // package:cloud_firestore (core → Firebase)
    'lib/product/widget/club_badge.dart:2', // ../../features/… (product → feature)
  ]);
  assert.ok(json.find((v) => v.file === 'lib/core/util/club_helper.dart' && v.line === 3).msg.includes('Firebase SDK'));
});

test('check_boundaries · B08: gu_data barrel export\'u ve repository arayüzü import\'u yakalanır', () => {
  const { json } = runJson('check_boundaries.js', ['--root', VIOLATING]);
  const b08 = json.filter((v) => v.rule === 'B08').map((v) => `${v.file}:${v.line}`);
  assert.deepEqual(b08.sort(), [
    'packages/gu_data/lib/gu_data.dart:2',
    'packages/gu_data/lib/src/repositories/club_repository.dart:2',
  ]);
  // ihlalli ağaçta B07/B08 dışında kural tetiklenmez (fixture yalıtımı)
  assert.deepEqual([...new Set(json.map((v) => v.rule))].sort(), ['B07', 'B08']);
});

test('check_boundaries · temiz ağaç: beyaz liste, firebase_ impl ve SDK\'sız barrel ihlal üretmez', () => {
  const { code, json } = runJson('check_boundaries.js', ['--root', CLEAN]);
  assert.deepEqual(json, []);
  assert.equal(code, 0);
});
