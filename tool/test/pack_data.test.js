'use strict';
// tool/lib/pack_data.js#patternFile öz-testi (muaf/dinamik aksiyon dosyalarının ortak okuyucusu) — CD-79, CD-86, CD-122.
const test = require('node:test');
const assert = require('node:assert/strict');
const data = require('../lib/pack_data');
const { FIXTURES } = require('./helpers');

test('pack_data.patternFile · kalıp, gerekçe ve joker; boş/yorum satırları atlanır', () => {
  const list = data.patternFile(FIXTURES, 'pack_data/patterns.txt');
  assert.deepEqual(list.map(({ pattern, reason }) => ({ pattern, reason })), [
    { pattern: 'AUT-01.demoAccount.*', reason: 'Demo hesap — K-02 # ikinci diyez gerekçede kalır' },
    { pattern: 'EVT-03.demoScan', reason: '' },
    { pattern: 'MGT-*.switchClub', reason: 'boşluklu gerekçe' },
    { pattern: 'CLB-01.status.*', reason: 'CRLF satırı' },
  ]);
  const [demo, scan, sw, status] = list;
  assert.ok(demo.re.test('AUT-01.demoAccount.ayse'));
  assert.ok(!demo.re.test('AUT-01.demoAccountX'));
  assert.ok(scan.re.test('EVT-03.demoScan'));
  assert.ok(!scan.re.test('EVT-03.demoScan.x'), 'joker yoksa tam eşleşme');
  assert.ok(!scan.re.test('EVT-03xdemoScan'), '. joker değil, düz nokta');
  assert.ok(sw.re.test('MGT-02.switchClub'));
  assert.ok(status.re.test('CLB-01.status.*'), 'bulunan anahtardaki `*` (interpolasyon) da eşleşir');
});

test('pack_data.patternFile · dosya yoksa boş dizi', () => {
  assert.deepEqual(data.patternFile(FIXTURES, 'pack_data/yok.txt'), []);
});

test('pack_data.patternFile · globToRe ile aynı joker anlamı', () => {
  const [entry] = data.patternFile(FIXTURES, 'pack_data/patterns.txt');
  assert.equal(entry.re.source, data.globToRe('AUT-01.demoAccount.*').source);
});
