'use strict';
// tool/check_hardcode.js öz-testi: HC12c — overlay primitifleri (showGuSheet / showGuDialog / showGuPopMenu ve Flutter
// eşdeğerleri) lib/features ve lib/product/widget içinden doğrudan çağrılamaz; tek giriş FeedbackService (CD-113, CD-79).
//
// fixtures/check_hardcode/violating  view + ortak widget + ViewModel'de doğrudan çağrılar (ifade başı, await, return, =>, üçlü)
// fixtures/check_hardcode/clean      FeedbackService çağrıları, yorum / string / gerekçeli istisna / metot bildirimi,
//                                    kapsam dışı dosyalar (lib/product/feedback, gu_ui overlay)
const test = require('node:test');
const assert = require('node:assert/strict');
const { fixture, runTool, runJson } = require('./helpers');

const VIOLATING = fixture('check_hardcode', 'violating');
const CLEAN = fixture('check_hardcode', 'clean');
const hc12c = (json) => json.filter((v) => v.rule === 'HC12c').map((v) => `${v.file}:${v.line}`);

test('check_hardcode · --list HC12c kuralını tanımlar', () => {
  const r = runTool('check_hardcode.js', ['--list']);
  assert.equal(r.code, 0);
  assert.match(r.stdout, /HC12c\t.*FeedbackService/);
});

test('check_hardcode · HC12c: features ve product/widget içinde doğrudan overlay çağrısı yakalanır', () => {
  const { code, json } = runJson('check_hardcode.js', ['--root', VIOLATING]);
  assert.equal(code, 1);
  assert.deepEqual(hc12c(json), [
    'lib/features/clubs/provider/club_view_model.dart:4',
    'lib/features/clubs/provider/club_view_model.dart:7',
    'lib/features/clubs/view/club_view.dart:6',
    'lib/features/clubs/view/club_view.dart:7',
    'lib/features/clubs/view/club_view.dart:8',
    'lib/features/clubs/view/club_view.dart:9',
    'lib/features/clubs/view/club_view.dart:10',
    'lib/features/clubs/view/club_view.dart:11',
    'lib/features/clubs/view/club_view.dart:12',
    'lib/product/widget/club/club_cta.dart:4',
    'lib/product/widget/club/club_cta.dart:5',
  ]);
  assert.match(json.find((v) => v.rule === 'HC12c').msg, /FeedbackService\.showSheet\/showDialog\/showMenu \(CD-113\)/);
});

test('check_hardcode · HC12c: servis üzerinden çağrı, yorum, string, bildirim ve kapsam dışı dosyalar temiz', () => {
  const { code, json } = runJson('check_hardcode.js', ['--root', CLEAN]);
  assert.deepEqual(json, []);
  assert.equal(code, 0);
});
