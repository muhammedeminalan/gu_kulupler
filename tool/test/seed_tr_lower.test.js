'use strict';
// tool/seed/lib/tr_lower.js öz-testi (PLAN §14.8, CD-11): tohumlayıcının kendi Türkçe küçük harf
// fonksiyonu, gu_ui `trLower()` ile AYNI sonucu vermelidir. Vektörler
// packages/gu_ui/test/extensions/string_x_test.dart ile aynıdır (dört vektör + boş dizgi).
const test = require('node:test');
const assert = require('node:assert/strict');
const { trLower } = require('../seed/lib/tr_lower');

const VECTORS = [
  ['ISPARTA', 'ısparta'],
  ['İSTANBUL', 'istanbul'],
  ['ÇAĞŞÖÜ', 'çağşöü'],
  ['Iğdır İli', 'ığdır ili'],
];

test('seed trLower · Dart trLower() ile aynı dört vektör', () => {
  for (const [input, expected] of VECTORS) assert.equal(trLower(input), expected, input);
  assert.equal(trLower(''), '');
});

test('seed trLower · İ → i dönüşümünde birleşik nokta (U+0307) kalmaz', () => {
  // Düz toLowerCase() 'İ' için 'i̇' (i + U+0307) üretir; nameLower aramasını bozar (PLAN R-15).
  assert.equal('İ'.toLowerCase().length, 2);
  const lower = trLower('İSTANBUL');
  assert.equal(lower.includes('̇'), false);
  assert.equal(lower.length, 'istanbul'.length);
});
