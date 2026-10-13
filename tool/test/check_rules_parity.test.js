'use strict';
// tool/check_rules_parity.js öz-testi (RP01–RP06, PLAN §11.6) — CD-79.
// Fixture'lar: tool/test/fixtures/check_rules_parity/{clean,violating} (küçük Limits + Rules ağaçları).
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { TOOL_DIR, fixture, runTool, runJson } = require('./helpers');
const dart = require('../lib/dart_sources');

const CLEAN = fixture('check_rules_parity', 'clean');
const VIOLATING = fixture('check_rules_parity', 'violating');
const REPO = path.resolve(TOOL_DIR, '..');

const at = (json, file, line) => json.filter((v) => v.file === file && v.line === line);
const rulesAt = (json, file, line) => at(json, file, line).map((v) => v.rule);

test('check_rules_parity · --list altı kuralı (RP01–RP06) tanımlar', () => {
  const r = runTool('check_rules_parity.js', ['--list']);
  assert.equal(r.code, 0);
  assert.deepEqual(r.stdout.trim().split('\n').map((l) => l.split('\t')[0]), ['RP01', 'RP02', 'RP03', 'RP04', 'RP05', 'RP06']);
});

test('check_rules_parity · temiz ağaç: etiketli sayı/süre/desen, çarpım, çift etiket, bütçe dosyaları geçer', () => {
  const r = runTool('check_rules_parity.js', ['--root', CLEAN]);
  assert.equal(r.stderr, '');
  assert.equal(r.stdout, 'check_rules_parity: temiz\n');
  assert.equal(r.code, 0);
});

test('check_rules_parity · ihlalli ağaç: her kural kendi satırında yakalanır', () => {
  const { code, json } = runJson('check_rules_parity.js', ['--root', VIOLATING]);
  assert.equal(code, 1);
  const FS = 'firebase/firestore.rules';
  const ST = 'firebase/storage.rules';
  const found = json.map((v) => `${v.file}:${v.line}:${v.rule}`);
  assert.deepEqual(found, [
    `${FS}:5:RP03`, // e-posta regex'i farklı alan adı
    `${FS}:7:RP04`, // touches 'updatedAt' eklemiyor
    `${FS}:13:RP04`, // isRestore listesinde deletedBy yok
    `${FS}:18:RP01`, // 61 ≠ nameMax 60
    `${FS}:19:RP02`, // etiketsiz 300
    `${FS}:20:RP01`, // bilinmeyen etiket
    `${FS}:21:RP01`, // etiket karşılıksız (0 serbest ama nameMin 2 yok)
    `${FS}:22:RP03`, // etiketli desen farklı
    `${FS}:24:RP01`, // 8 gün ≠ reapplyCooldown 7 gün
    `${FS}:25:RP02`, // etiketsiz duration.value(1,'d')
    `${FS}:26:RP01`, // 2 gün ∉ pollDurationsDays
    `${FS}:27:RP06`, // // budget: chunk=7
    `${ST}:4:RP03`, // signedInVerified içinde regex yok
    `${ST}:8:RP01`, // 4 MB ≠ imageMaxBytes
    'firebase/test/budget/account_deletion_result.json:1:RP06',
    'firebase/test/budget/fanout_result.json:1:RP05',
  ]);
  assert.match(at(json, FS, 18)[0].msg, /sayı 61, Limits\.nameMax \(60\)/);
  assert.match(at(json, FS, 20)[0].msg, /bilinmeyen Limits sabiti: postTextMaks/);
  assert.match(at(json, FS, 24)[0].msg, /duration\.value\(8, 'd'\) = 691200 sn, Limits\.reapplyCooldown \(604800 sn\)/);
  assert.match(at(json, ST, 8)[0].msg, /sayı 4194304, Limits\.imageMaxBytes \(5242880\)/);
  // isSoftDelete listesi doğru: yalnızca isRestore (13) ve touches (7) işaretlenir
  assert.deepEqual(rulesAt(json, FS, 10), []);
});

/** Kalıcı + geçici liste biçimindeki (CD-136) `email_domain_policy.dart` kaynağı. */
const spreadPolicy = (temporary) => `abstract final class EmailDomainPolicy {
  static const List<String> universityDomains = [
    'ogr.gumushane.edu.tr',
    'gumushane.edu.tr',
  ];

  /// Yorumdaki \`temporaryTestDomains = ['yorum.com']\` okunmaz.
  static const List<String> temporaryTestDomains = ${temporary};

  static const List<String> allowedDomains = [
    ...universityDomains,
    ...temporaryTestDomains,
  ];
}
`;

/** Temiz ağacın, `email_domain_policy.dart` dosyası [source] ile değiştirilmiş geçici kopyası. */
function withPolicy(source) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'gu-rp-policy-'));
  fs.cpSync(CLEAN, root, { recursive: true });
  fs.writeFileSync(path.join(root, dart.PATHS.emailDomainPolicy), source);
  return root;
}

test('dart_sources.readEmailDomains · yayılımlı liste çözülür; geçici liste boşalınca kalıcı liste aynen kalır (CD-136)', () => {
  const university = ['ogr.gumushane.edu.tr', 'gumushane.edu.tr'];
  assert.deepEqual(dart.readEmailDomains(withPolicy(spreadPolicy("['gmail.com']"))), [...university, 'gmail.com']);
  assert.deepEqual(dart.readEmailDomains(withPolicy(spreadPolicy('[]'))), university);
  assert.deepEqual(dart.readEmailDomains(withPolicy(spreadPolicy('<String>[]'))), university);
  // düz literal liste (fixture'lardaki biçim) okunmaya devam eder
  assert.deepEqual(dart.readEmailDomains(CLEAN), university);
  // deponun gerçek kaynağı: üniversite alan adları başta ve sırayla
  assert.deepEqual(dart.readEmailDomains(REPO).slice(0, university.length), university);

  // okuyucu sessizce boş dönmez: eksik liste, çözülemeyen öğe, boş sonuç
  const broken = (body) => withPolicy(`abstract final class EmailDomainPolicy {\n  static const List<String> allowedDomains = ${body};\n}\n`);
  assert.throws(() => dart.readEmailDomains(broken('[...missingDomains]')), /missingDomains bulunamadı/);
  assert.throws(() => dart.readEmailDomains(broken('[...allowedDomains]')), /allowedDomains kendine yayılıyor/);
  assert.throws(() => dart.readEmailDomains(broken('[kDomain]')), /allowedDomains öğesi çözülemedi \(kDomain\)/);
  assert.throws(() => dart.readEmailDomains(broken('[]')), /allowedDomains bulunamadı/);
});

test('check_rules_parity · geçici alan adı Dart listesinde olup Rules deseninde yoksa (ya da tersi) RP03', () => {
  // Dart'a gmail.com eklendi, Rules eski desende kaldı → iki dosyada da RP03
  const added = runJson('check_rules_parity.js', ['--root', withPolicy(spreadPolicy("['gmail.com']"))]);
  assert.equal(added.code, 1);
  assert.deepEqual([...new Set(added.json.map((v) => `${v.file}:${v.rule}`))], ['firebase/firestore.rules:RP03', 'firebase/storage.rules:RP03']);
  for (const v of added.json) assert.ok(v.msg.includes('gumushane\\\\.edu\\\\.tr|gmail\\\\.com)'), v.msg);

  // geçici liste boşaltıldı, Rules eski (iki alan adlı) desende → temiz
  const emptied = runTool('check_rules_parity.js', ['--root', withPolicy(spreadPolicy('[]'))]);
  assert.equal(emptied.code, 0, emptied.stdout + emptied.stderr);
  assert.match(emptied.stdout, /check_rules_parity: temiz/);

  // geri alma yarım kaldı: Dart listesi boş ama Rules'ta gmail duruyor → RP03 (ihlalli fixture, satır 5)
  const leftover = runJson('check_rules_parity.js', ['--root', VIOLATING]);
  assert.ok(leftover.json.some((v) => v.rule === 'RP03' && v.file === 'firebase/firestore.rules' && v.line === 5));
});

test('check_rules_parity · Rules dosyası yoksa uyarıyla atlar; bütçe dosyası yoksa RP05/RP06 atlanır', () => {
  const empty = fs.mkdtempSync(path.join(os.tmpdir(), 'gu-rp-empty-'));
  const none = runTool('check_rules_parity.js', ['--root', empty]);
  assert.equal(none.code, 0);
  assert.match(none.stdout, /^UYARI: Rules dosyası yok .* atlandı$/m);

  // temiz ağacın bütçe dosyasız kopyası
  const copy = fs.mkdtempSync(path.join(os.tmpdir(), 'gu-rp-nobudget-'));
  fs.cpSync(CLEAN, copy, { recursive: true, filter: (src) => !src.endsWith('_result.json') });
  const r = runTool('check_rules_parity.js', ['--root', copy]);
  assert.equal(r.code, 0);
  assert.match(r.stdout, /^UYARI: RP05 atlandı: .*fanout_result\.json yok/m);
  assert.match(r.stdout, /^UYARI: RP06 atlandı: .*account_deletion_result\.json yok/m);
  assert.match(r.stdout, /check_rules_parity: temiz/);
});

test('check_rules_parity · Rules var ama Limits kaynağı yoksa sessizce geçmez (çıkış 2)', () => {
  const broken = fs.mkdtempSync(path.join(os.tmpdir(), 'gu-rp-nolimits-'));
  fs.cpSync(CLEAN, broken, { recursive: true, filter: (src) => !src.endsWith('limits.dart') });
  const r = runTool('check_rules_parity.js', ['--root', broken]);
  assert.equal(r.code, 2);
  assert.match(r.stderr, /Dart kaynağı yok: packages\/gu_data\/lib\/src\/constants\/limits\.dart/);
});

test('check_rules_parity · deponun gerçek Rules iskeleti temizdir ve kapıya bağlıdır', () => {
  const r = runTool('check_rules_parity.js', ['--root', REPO]);
  assert.equal(r.code, 0, r.stderr);
  assert.match(r.stdout, /check_rules_parity: temiz/);
  const gate = fs.readFileSync(path.join(TOOL_DIR, 'quality_gate.sh'), 'utf8');
  const hardDelete = gate.indexOf('step hard-delete 0 node tool/check_no_hard_delete.js');
  const parity = gate.indexOf('step rules-parite 0 node tool/check_rules_parity.js');
  assert.ok(hardDelete > 0 && parity > hardDelete, 'rules-parite adımı hard-delete adımından sonra olmalı');
});
