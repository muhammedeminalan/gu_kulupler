'use strict';
// tool/check_arb_parity.js öz-testi: ARB15 (çoğul dalında '#', K-28) ve l10n.yaml use-escaping (CD-51, K-23) — CD-79.
const test = require('node:test');
const assert = require('node:assert/strict');
const { fixture, runJson } = require('./helpers');

const arb = (name) => runJson('check_arb_parity.js', ['--root', fixture('check_arb_parity', name), '--strict']);
const rules = (json) => json.errors.map((e) => `${e.rule}:${e.key}`).sort();

test('check_arb_parity · ARB15: çoğul dalındaki # hata, {sayaç} önerilir', () => {
  const { code, json } = arb('hash');
  assert.equal(code, 1);
  assert.deepEqual(rules(json), ['ARB15:memberCount']);
  assert.match(json.errors[0].msg, /^TR: çoğul dalında '#' \(1×\)/);
  assert.match(json.errors[0].msg, /`\{count\}` kullan/);
});

test('check_arb_parity · ARB15: dalda {sayaç} kullanan çoğul temiz', () => {
  const { code, json } = arb('clean');
  assert.deepEqual(json.errors, []);
  assert.deepEqual(json.warnings, []);
  assert.equal(code, 0);
});

test('check_arb_parity · use-escaping yok/false: tırnak düz karakter, \'{q}\' yer tutucudur', () => {
  const { code, json } = arb('escaping_off');
  assert.deepEqual(json.errors, []);
  assert.deepEqual(json.warnings, []);
  assert.equal(code, 0);
});

test('check_arb_parity · use-escaping: true: \'{q}\' tırnaklı literal → ARB08 (kullanılmayan yer tutucu)', () => {
  const { code, json } = arb('escaping_on');
  assert.equal(code, 1);
  assert.deepEqual(rules(json), ['ARB08:searchNoResults']);
  assert.match(json.errors[0].msg, /placeholders\.q tanımlı ama metinde kullanılmıyor/);
  assert.match(json.errors[0].msg, /use-escaping:true/);
});
