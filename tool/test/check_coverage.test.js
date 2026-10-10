'use strict';
// tool/check_coverage.js öz-testi: ölçülebilir satırı olmayan grup n/a (CD-77) ve eşik altı hata — CD-79.
const test = require('node:test');
const assert = require('node:assert/strict');
const { fixture, runTool, runJson } = require('./helpers');

const row = (json, group) => json.rows.find((r) => r.group === group);

test('check_coverage · ölçülebilir satırı olmayan barrel/iskelet grubu n/a ("—") ile geçer (CD-77)', () => {
  const root = fixture('check_coverage', 'na');
  const { code, json } = runJson('check_coverage.js', ['--root', root]);
  assert.deepEqual(json.errors, []);
  assert.deepEqual(json.warnings, []);
  assert.equal(code, 0);
  // gu_data: lcov'da LF:0 barrel + lcov'da olmayan yalnızca-yorum dosyası → n/a
  assert.equal(row(json, 'gu_data').pct, null);
  // view: lcov'da hiç yok ama yalnızca export satırı → n/a (hata değil)
  assert.equal(row(json, 'view').pct, null);
  // ölçülen grup eşik üstünde
  assert.equal(row(json, 'gu_ui').pct, 95);
  const text = runTool('check_coverage.js', ['--root', root]).stdout;
  assert.match(text, /^gu_data\s+—\s+\(eşik 90%\)/m);
  assert.match(text, /check_coverage: temiz/);
});

test('check_coverage · eşik altı grup ve yüklenmemiş çalıştırılabilir kod (%0) hata', () => {
  const { code, json } = runJson('check_coverage.js', ['--root', fixture('check_coverage', 'below')]);
  assert.equal(code, 1);
  assert.equal(row(json, 'gu_data').pct, 50);
  assert.equal(row(json, 'view').pct, 0);
  assert.deepEqual(json.errors, ['gu_data: %50.0 < %90 (5/10 satır)', 'view: %0.0 < %80 (0/0 satır)']);
  assert.equal(json.warnings.length, 1);
  assert.match(json.warnings[0], /lib\/features\/clubs\/view\/club_list_view\.dart hiçbir testte yüklenmiyor/);
});
