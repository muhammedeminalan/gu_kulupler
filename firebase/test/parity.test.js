'use strict';
// T-10 iskelet → T-45 nihai (PLAN §11.6 "Parite testleri"). Dart tarafıyla ortak sözleşmelerin
// Rules test düzeneğindeki karşılığı. Dart kaynağı tool/lib/dart_sources.js ile okunur
// (tool/check_rules_parity.js ile aynı okuyucu — ikinci kopya yok).
//
//  (b) EmailDomainPolicy.allowedDomains ↔ Rules e-posta regex'i (firestore.rules + storage.rules)
//  (d) SoftDelete / BaseFieldsPayload anahtarları ↔ helpers/payloads.js (JS eşleniği)
//  (c) RolePolicy tablosu ↔ expectations/role_policy.json ↔ expectations/roles.json bağlamları
//  (a) Limits ↔ Rules sayıları: statik olarak tool/check_rules_parity.js RP01/RP02 (her kapı);
//      davranış düzeyi karşılığı koleksiyon testlerindeki sınır vakalarıdır (T-12+).
//
// role_policy.json nasıl güncellenir: tek kaynak docs/domain-model.md §3 tablosudur. Tablo değişince
// JSON elle güncellenir; bu test Dart `RolePolicy._holdersOf` ile, Dart tarafındaki
// packages/gu_data/test/core/role_policy_parity_test.dart ise `RolePolicy.can(...)` ile aynı JSON'u
// hücre hücre karşılaştırır. Dart tablosundan JSON'u yeniden üretmek için:
//   node -e "console.log(JSON.stringify(require('./tool/lib/dart_sources').readRolePolicy('.'), null, 2))"
const fs = require('node:fs');
const path = require('node:path');
const { rulesPath } = require('./setup/emulator_ports');
const { CONTEXTS, VARIANTS, definition } = require('./helpers/contexts');
const payloads = require('./helpers/payloads');
const rolePolicy = require('./expectations/role_policy.json');
const roles = require('./expectations/roles.json');

const REPO_ROOT = path.resolve(__dirname, '..', '..');
const dart = require(path.join(REPO_ROOT, 'tool', 'lib', 'dart_sources.js'));

const firestoreRules = fs.readFileSync(rulesPath('firestore'), 'utf8');
const storageRules = fs.readFileSync(rulesPath('storage'), 'utf8');

describe('parite (b) · EmailDomainPolicy ↔ Rules e-posta regex\'i', () => {
  const domains = dart.readEmailDomains(REPO_ROOT);
  const regex = dart.emailRulesRegex(domains);
  const literal = `matches('${dart.toRulesLiteral(regex)}')`;

  test('firestore.rules emailOk() ve storage.rules signedInVerified() aynı deseni taşır', () => {
    expect(domains).toEqual(['ogr.gumushane.edu.tr', 'gumushane.edu.tr']);
    expect(firestoreRules).toContain(literal);
    expect(storageRules).toContain(literal);
  });

  test('desen yalnızca izinli alan adlarını tam eşler (Rules `matches` tüm dizgiyi eşler)', () => {
    const full = new RegExp(`^(?:${regex})$`);
    for (const domain of domains) expect(full.test(`ad.soyad@${domain}`)).toBe(true);
    for (const email of [
      'x@gmail.com',
      'x@evilgumushane.edu.tr',
      'x@sub.gumushane.edu.tr',
      'x@gumushane.edu.tr.evil.com',
      'x@ogr.gumushane.edu.tr ',
      'gumushane.edu.tr',
    ]) {
      expect(full.test(email)).toBe(false);
    }
  });

  test('bağlam e-postaları tanımlarıyla tutarlı: outsideDomain dışında hepsi izinli alan adında', () => {
    const full = new RegExp(`^(?:${regex})$`);
    for (const name of [...CONTEXTS, ...VARIANTS]) {
      const def = definition(name);
      if (!def.token) continue;
      expect([name, full.test(def.token.email)]).toEqual([name, name !== 'outsideDomain']);
    }
  });
});

describe('parite (d) · SoftDelete / BaseFieldsPayload ↔ helpers/payloads.js', () => {
  const sorted = (keys) => [...keys].sort();

  test('softDelete ve restore yükleri SoftDelete.affectedKeys ile aynı anahtarları yazar', () => {
    const keys = sorted(dart.readSoftDeleteKeys(REPO_ROOT));
    expect(sorted(payloads.SOFT_DELETE_KEYS)).toEqual(keys);
    expect(sorted(Object.keys(payloads.softDelete('u_member')))).toEqual(keys);
    expect(sorted(Object.keys(payloads.restore()))).toEqual(keys);
    expect(payloads.softDelete('u_member')).toMatchObject({ isDeleted: true, deletedBy: 'u_member' });
    expect(payloads.restore()).toMatchObject({ isDeleted: false, deletedAt: null, deletedBy: null });
    expect(() => payloads.softDelete('')).toThrow(/actorId/);
  });

  test('baseCreate yükü BaseFieldsPayload.create ile aynı anahtarları yazar (createdBy isteğe bağlı)', () => {
    const { required, optional } = dart.readBaseCreateKeys(REPO_ROOT);
    expect(optional).toEqual(['createdBy']);
    expect(sorted(payloads.BASE_CREATE_KEYS)).toEqual(sorted(required));
    expect(sorted(Object.keys(payloads.baseCreate()))).toEqual(sorted(required));
    expect(sorted(Object.keys(payloads.baseCreate({ createdBy: 'u_board' })))).toEqual(sorted([...required, ...optional]));
    expect(() => payloads.baseCreate({ createdBy: '' })).toThrow(/createdBy/);
    expect(Object.keys(payloads.baseUpdate())).toEqual(['updatedAt']);
  });

  test('sayaç yükü sayaç alanı + last*Ref + updatedAt yazar; bilinmeyen varyant hatadır', () => {
    const bump = payloads.counterBump('memberCount', 1, 'lastMembershipRef', 'memberships/c01_u_member');
    expect(Object.keys(bump).sort()).toEqual(['lastMembershipRef', 'memberCount', 'updatedAt']);
    expect(bump.lastMembershipRef).toBe('memberships/c01_u_member');
    expect(() => payloads.payloadFor('yok', {})).toThrow(/bilinmeyen yük varyantı/);
    expect(() => payloads.registerVariant('genericCreate', () => ({}))).toThrow(/zaten kayıtlı/);
  });
});

describe('parite (c) · RolePolicy ↔ expectations/role_policy.json ↔ roles.json', () => {
  test('role_policy.json, Dart RolePolicy._holdersOf tablosuyla hücre hücre aynıdır', () => {
    const table = dart.readRolePolicy(REPO_ROOT);
    expect(Object.keys(rolePolicy.permissions).sort()).toEqual(Object.keys(table).sort());
    for (const [permission, holders] of Object.entries(table)) {
      expect([permission, [...rolePolicy.permissions[permission]].sort()]).toEqual([permission, [...holders].sort()]);
    }
    expect(rolePolicy.roles).toEqual(['student', 'member', 'board', 'president', 'advisor', 'superadmin']);
  });

  test('roles.json: 12 bağlam §11.1 sütun sırasındadır ve her tanım rol alanlarını taşır', () => {
    expect(CONTEXTS).toEqual([
      'anon', 'unver', 'student', 'former', 'pending', 'member', 'board', 'president', 'advisor', 'super',
      'otherManager', 'susp',
    ]);
    for (const name of [...CONTEXTS, ...VARIANTS]) {
      const def = definition(name);
      expect(Object.keys(def)).toEqual(expect.arrayContaining(['uid', 'token', 'user', 'membership', 'activeUser', 'clubRole', 'isSuper']));
      // clubRole yalnızca `club` içindeki AKTİF üyelikten gelir (RolePolicy.activeRole / Rules mActive)
      const active = def.membership && def.membership.clubId === roles.club && def.membership.status === 'active';
      expect([name, def.clubRole]).toEqual([name, active ? def.membership.role : null]);
      expect([name, def.isSuper]).toEqual([name, Boolean(def.token && def.token.superadmin === true)]);
    }
    expect(definition('superadmin')).toBe(definition('super'));
    expect(definition('otherMgr')).toBe(definition('otherManager'));
  });

  // T-12+: koleksiyon beklentileri dolunca role_policy.json'dan türetilebilirlik doğrulanır
  // (viewInside ⇒ posts.get allow · comment ⇒ comments.create allow · manageEvents ⇒ events.create allow).
  test.todo('expectations/*.json üyelik vakaları role_policy.json ile tutarlı (T-19, T-22; nihai T-45)');
});

describe('parite (a) · Limits ↔ Rules sayıları', () => {
  test('Rules\'taki her `// limit:` etiketi bir Limits sabitine çözülür (statik denetim: check_rules_parity RP01)', () => {
    const limits = dart.readLimits(REPO_ROOT);
    const known = new Set([...Object.keys(limits.ints), ...Object.keys(limits.durations), ...Object.keys(limits.intLists), ...Object.keys(limits.strings)]);
    const labels = [...`${firestoreRules}\n${storageRules}`.matchAll(/\/\/\s*limit:\s*([A-Za-z_]\w*)/g)].map((m) => m[1]);
    expect(labels).toContain('imageMaxBytes');
    for (const label of labels) {
      const base = label.replace(/(Minutes|Hours|Days|Seconds)$/, '');
      expect([label, known.has(label) || known.has(base)]).toEqual([label, true]);
    }
    expect(limits.ints.imageMaxBytes).toBe(5 * 1024 * 1024);
  });

  test.todo('sınır değerleri emülatörde: Limits.<ad> geçer, Limits.<ad> + 1 reddedilir (koleksiyon task\'ları; nihai T-45)');
});
