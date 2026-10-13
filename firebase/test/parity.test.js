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
//  (g) StaticTables / enum değerleri ↔ Rules değer listeleri (T-12: users.interests, year, department,
//      avatarPath dosya adı deseni, fcmTokens[].platform, settings.reminderTime) — Dart tablosu değişip Rules listesi eski kalırsa üretimde
//      `permission-denied` olur; bu test o sapmayı yakalar.
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
    // Kalıcı liste (D-27) başta ve sırayla; ardından yalnızca geçici test alan adları gelir.
    expect(domains.slice(0, 2)).toEqual(['ogr.gumushane.edu.tr', 'gumushane.edu.tr']);
    // GEÇİCİ (W-61, CD-136): `gmail.com` — geri almada bu beklenti `[]` olur.
    expect(domains.slice(2)).toEqual(['gmail.com']);
    expect(firestoreRules).toContain(literal);
    expect(storageRules).toContain(literal);
  });

  test('desen yalnızca izinli alan adlarını tam eşler (Rules `matches` tüm dizgiyi eşler)', () => {
    const full = new RegExp(`^(?:${regex})$`);
    for (const domain of domains) expect(full.test(`ad.soyad@${domain}`)).toBe(true);
    for (const email of [
      'x@hotmail.com',
      'x@outlook.com',
      // gmail benzerleri: geçici izin (W-61) yalnızca tam `gmail.com` alan adınadır.
      'x@gmail.com.evil.com',
      'x@xgmail.com',
      'x@mail.gmail.com',
      'x@googlemail.com',
      'x@gmailXcom',
      'x@gmail.com ',
      'gmail.com',
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
    const bump = payloads.counterBump('commentCount', 1, 'lastCommentRef', 'comments/cm01');
    expect(Object.keys(bump).sort()).toEqual(['commentCount', 'lastCommentRef', 'updatedAt']);
    expect(bump.lastCommentRef).toBe('comments/cm01');
    // `clubs.memberCount` işaretçi taşımaz (CD-137 madde 8q): üyeliğin yolu herkese açık belgeye yazılmaz.
    expect(Object.keys(payloads.memberCountBump(1)).sort()).toEqual(['memberCount', 'updatedAt']);
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

describe('parite (g) · StaticTables / enum değerleri ↔ Rules değer listeleri (T-12)', () => {
  const readDart = (rel) => fs.readFileSync(path.join(REPO_ROOT, 'packages', 'gu_data', 'lib', 'src', rel), 'utf8');
  const quoted = (source) => [...source.matchAll(/'([^']*)'/g)].map((m) => m[1]);
  /** Rules'ta `anchor` ifadesinden sonraki ilk `[ … ]` listesinin dizgi elemanları. */
  const rulesList = (anchor) => {
    const at = firestoreRules.indexOf(anchor);
    if (at < 0) throw new Error(`firestore.rules: "${anchor}" bulunamadı`);
    const open = firestoreRules.indexOf('[', at);
    return quoted(firestoreRules.slice(open, firestoreRules.indexOf(']', open)));
  };
  /** Dart enum'unun tel değerleri: `ad('değer')` satırları. */
  const enumValues = (rel) => [...readDart(rel).matchAll(/^\s+\w+\('([^']+)'\)[,;]/gm)].map((m) => m[1]);
  const staticTables = readDart('constants/static_tables.dart');
  const tableIds = (model) => [...staticTables.matchAll(new RegExp(`${model}\\(id: '([^']+)'`, 'g'))].map((m) => m[1]);

  test('users.interests değer listesi = StaticTables.interests kimlikleri (16)', () => {
    const ids = tableIds('InterestModel');
    expect(ids).toHaveLength(16);
    expect(rulesList('d.interests.hasOnly(')).toEqual(ids);
  });

  test('users.year değer listesi = YearLevel değerleri (8)', () => {
    const values = enumValues('models/enums/year_level.dart');
    expect(values).toHaveLength(8);
    expect(rulesList('d.year in ')).toEqual(values);
  });

  test('users.department deseni StaticTables.departments kimliklerinin tamamını kabul eder (24)', () => {
    const ids = tableIds('DepartmentModel');
    expect(ids).toHaveLength(24);
    const literal = /d\.department\.matches\('([^']*)'\)/.exec(firestoreRules);
    expect(literal).not.toBeNull();
    const full = new RegExp(`^(?:${literal[1]})$`);
    for (const id of ids) expect([id, full.test(id)]).toEqual([id, true]);
    for (const other of ['d1', 'd001', 'x01', 'D01', '']) expect([other, full.test(other)]).toEqual([other, false]);
  });

  test('users.avatarPath deseni = users/{uid}/ + StoragePaths.fileNamePattern (Rules yazımıyla)', () => {
    const pattern = /static const String fileNamePattern =\s*r'([^']+)'/.exec(readDart('constants/storage_paths.dart'));
    expect(pattern).not.toBeNull();
    expect(firestoreRules).toContain(`d.avatarPath.matches('users/' + uid + '/${dart.toRulesLiteral(pattern[1])}')`);
    // Rules `matches` tüm dizgiyi eşler: desen StoragePaths.newFileName çıktısını kabul eder, ekini etmez.
    const full = new RegExp(`^(?:${pattern[1]})$`);
    expect(full.test('20261008T201501Z_3f9a1c2b7d4e5f60.jpg')).toBe(true);
    for (const other of ['x.jpg', '20261008T201501Z_3f9a1c2b7d4e5f60.gif', '20261008T201501Z_3f9a1c2b7d4e5f60.jpgx', 'a/20261008T201501Z_3f9a1c2b7d4e5f60.jpg']) {
      expect([other, full.test(other)]).toEqual([other, false]);
    }
  });

  test('storage.rules dosya adı deseni = StoragePaths.fileNamePattern (firestore.rules avatarPath ile aynı yazım)', () => {
    const pattern = /static const String fileNamePattern =\s*r'([^']+)'/.exec(readDart('constants/storage_paths.dart'));
    expect(pattern).not.toBeNull();
    const literal = dart.toRulesLiteral(pattern[1]);
    expect(storageRules).toContain(`file.matches('${literal}')`);
    expect(firestoreRules).toContain(`/${literal}')`);
  });

  test('storage.rules içerik türleri ve uzantı eşlemesi = StoragePaths.extensionByContentType', () => {
    const table = /extensionByContentType = \{([^}]*)\}/.exec(readDart('constants/storage_paths.dart'));
    expect(table).not.toBeNull();
    const pairs = [...table[1].matchAll(/'([^']+)':\s*'([^']+)'/g)].map((m) => [m[1], m[2]]);
    expect(pairs).toEqual([
      ['image/jpeg', 'jpg'],
      ['image/png', 'png'],
      ['image/webp', 'webp'],
    ]);
    // imageOk(): yalnızca tablodaki türler
    const subtypes = pairs.map(([type]) => type.replace('image/', ''));
    expect(storageRules).toContain(`request.resource.contentType.matches('image/(${subtypes.join('|')})')`);
    // fileNameOk(): her tür kendi uzantısıyla
    for (const [type, extension] of pairs) {
      expect(storageRules).toContain(`(request.resource.contentType == '${type}' && file.matches('.*\\\\.${extension}'))`);
    }
    const mapped = storageRules.match(/request\.resource\.contentType == '[^']+'/g) || [];
    expect(mapped).toHaveLength(pairs.length);
  });

  test('storage.rules üst veri koşulları = FirebaseStorageService.upload\'ın gönderdiği üst veri (T-14 güvenlik incelemesi)', () => {
    // İstemci yalnızca `contentType` (+ boş değilse özel üst veri) gönderir; Rules `contentEncoding` /
    // `contentDisposition` taşıyan yüklemeyi reddeder. Servis bu alanlardan birini göndermeye başlarsa
    // üretimde her yükleme `unauthorized` olur — bu test o sapmayı yakalar.
    const service = readDart('services/storage_service.dart');
    const settable = /SettableMetadata\(([^)]*)\)/.exec(service);
    expect(settable).not.toBeNull();
    const sent = [...settable[1].matchAll(/(\w+):/g)].map((m) => m[1]);
    expect(sent).toEqual(['contentType', 'customMetadata']);
    expect(settable[1]).toContain('customMetadata: customMetadata.isEmpty ? null : customMetadata');
    for (const field of ['contentEncoding', 'contentDisposition']) {
      expect(service).not.toContain(field);
      expect(storageRules).toContain(`request.resource.${field} == null`);
    }
    // `users/` yolu özel üst veri kabul etmez: updateAvatar `customMetadata` vermez.
    expect(storageRules).toContain('function noCustomMetadata()');
    const repository = readDart('repositories/firebase_user_repository.dart');
    expect(repository).toContain('_storage.upload(');
    expect(repository).not.toContain('customMetadata');
    // Boş dosya: servis ağ çağrısından önce `noFile` döner; Rules `size > 0` ister.
    expect(service).toContain('if (bytes.isEmpty) return StorageError.noFile;');
    expect(storageRules).toContain('request.resource.size > 0');
  });

  test('account.fcmTokens[].platform değer listesi = Limits.platforms', () => {
    const platforms = /static const Set<String> platforms = \{([^}]*)\}/.exec(readDart('constants/limits.dart'));
    expect(platforms).not.toBeNull();
    expect(rulesList('t.platform in ')).toEqual(quoted(platforms[1]));
  });

  test('settings.reminderTime değer listesi ⊂ ReminderOption ve yalnızca 1h, 1d (CD-34)', () => {
    const values = enumValues('models/enums/reminder_option.dart');
    const allowed = rulesList('d.reminderTime in ');
    expect(allowed).toEqual(['1h', '1d']);
    for (const value of allowed) expect(values).toContain(value);
  });
});

describe('parite (g) · enum değerleri ↔ Rules değer listeleri (T-15)', () => {
  const ENUMS = path.join(REPO_ROOT, 'packages', 'gu_data', 'lib', 'src', 'models', 'enums');
  /** Dart enum'unun tel değerleri (ilk argüman): `ad('değer')` ya da `ad('değer', …)` satırları. */
  const enumValues = (file) => [...fs.readFileSync(path.join(ENUMS, file), 'utf8').matchAll(/^\s+\w+\('([^']+)'[,)]/gm)].map((m) => m[1]);
  const quoted = (source) => [...source.matchAll(/'([^']*)'/g)].map((m) => m[1]);
  /** Rules'ta `anchor` ifadesinden sonraki ilk `[ … ]` listesinin dizgi elemanları. */
  const listAfter = (anchor) => {
    const at = firestoreRules.indexOf(anchor);
    if (at < 0) throw new Error(`firestore.rules: "${anchor}" bulunamadı`);
    const open = firestoreRules.indexOf('[', at);
    return quoted(firestoreRules.slice(open, firestoreRules.indexOf(']', open)));
  };
  /** `<alan> == '…'`, `<alan> != '…'` ve `<alan> in [ … ]` karşılaştırmalarındaki tüm literal'ler. */
  const literalsOf = (field) => {
    const single = [...firestoreRules.matchAll(new RegExp(`\\b${field}\\s*[!=]=\\s*'([^']*)'`, 'g'))].map((m) => m[1]);
    const lists = [...firestoreRules.matchAll(new RegExp(`\\b${field}\\s+in\\s+\\[([^\\]]*)\\]`, 'g'))].flatMap((m) => quoted(m[1]));
    return [...new Set([...single, ...lists])];
  };

  test('reports.reason değer listesi = ReportReason (6) ve reports.targetType = ReportTargetType (5) — CD-33', () => {
    expect(listAfter('// ReportReason (6')).toEqual(enumValues('report_reason.dart'));
    expect(listAfter('// ReportTargetType (5')).toEqual(enumValues('report_target_type.dart'));
  });

  test('Rules\'taki her `status` / `role` / `kind` literal\'i bir Dart enum değeridir (yazım hatası = sessiz ret)', () => {
    // MembershipStatus ve ClubRole tel değerleri `constants/role_codes.dart` sabitlerinden gelir.
    const roleCodes = fs.readFileSync(path.join(REPO_ROOT, 'packages', 'gu_data', 'lib', 'src', 'constants', 'role_codes.dart'), 'utf8');
    const codesOf = (className) => {
      const body = roleCodes.slice(roleCodes.indexOf(`abstract final class ${className} {`));
      return [...body.slice(0, body.indexOf('\n}')).matchAll(/static const String \w+ = '([^']+)';/g)].map((m) => m[1]);
    };
    const membershipStatuses = codesOf('MembershipStatusCodes');
    const clubRoles = codesOf('RoleCodes').filter((value) => value !== 'superadmin');
    expect(membershipStatuses.sort()).toEqual(['active', 'cancelled', 'left', 'pending', 'rejected', 'removed']);
    expect(clubRoles.sort()).toEqual(['advisor', 'board', 'member', 'president']);

    const statuses = [...membershipStatuses, ...['club_status.dart', 'user_status.dart', 'report_status.dart'].flatMap(enumValues)];
    const used = { status: literalsOf('status'), role: literalsOf('role'), kind: literalsOf('kind') };
    expect(used.status).toEqual(expect.arrayContaining([...membershipStatuses, 'open']));
    for (const value of used.status) expect([value, statuses.includes(value)]).toEqual([value, true]);
    expect(used.role.sort()).toEqual(clubRoles);
    expect(used.kind.sort()).toEqual(['application_received', 'member_joined', 'member_left']);
    for (const value of used.kind) expect([value, enumValues('activity_kind.dart').includes(value)]).toEqual([value, true]);
  });
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
