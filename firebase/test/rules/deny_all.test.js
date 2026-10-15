'use strict';
// T-10 — varsayılan ret (rules-spec §1.1): Rules iskeletinde her koleksiyon × her bağlam için
// get / list / create / update reddedilir. Koleksiyon listesi `expectations/*.json` dosyalarından
// (PLAN §11.1'in 18 satırı + T-22'nin yan belgesi `events/{id}/private/counter` + T-30'un `clubs/{id}/private/counter` = 20 yol) gelir ve
// `firestore.rules` `match` bloklarıyla karşılaştırılır.
// Bir koleksiyon sahibi task'ta açıldığında o satır buradan düşer (aşağıdaki OPENED listesi) ve
// kendi `rules/<koleksiyon>.test.js` matrisine taşınır; kalanlar kapalı kalmaya devam eder.
// T-28 ile 19 satırın tamamı açıldı (T-30'un yan belgesi açık doğar): koleksiyon bazlı ret bloğu boş kalır (yalnızca tanımsız
// yollar ve koleksiyon grupları kapalıdır — T-37 `private` grubunu yalnızca süper admine açtı; aşağıdaki bloklar onları sınar).
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { assertFails } = require('@firebase/rules-unit-testing');
const { collectionGroup, doc, getDoc, getDocs, setDoc } = require('firebase/firestore');
const { rulesPath } = require('../setup/emulator_ports');
const { CLUB, CONTEXTS, OTHER_CLUB, VARIANTS, contextFor, definition, uidOf } = require('../helpers/contexts');
const { baseDocs, readDoc, seedBase, seedDocs, targetDoc } = require('../helpers/fixtures');
const {
  FIRESTORE_PREFIX,
  fillPath,
  loadAllExpectations,
  loadExpectations,
  parseMatches,
  runCase,
  runCases,
} = require('../helpers/matrix');
const payloads = require('../helpers/payloads');
const budget = require('../helpers/budget');

/**
 * Kuralları açılmış koleksiyonlar (`expectations` `collection` değeri); matrisleri kendi
 * `rules/<koleksiyon>.test.js` dosyasındadır. T-12: `users`, `users/private`, `settings`.
 * T-15: `clubs`, `memberships`, `memberships/private`, `reports`, `blocks`, `activity`.
 * T-19: `posts`, `posts/votes`, `comments`, `savedPosts`, `announcementCounters`.
 * T-22: `events`, `events/private` (yönetici sayaç işaretçisi — W-64), `rsvps`. T-25: `notifications`.
 * T-28: `supportTickets`. T-30: `clubs/private` (yönetici sayaç işaretçisi — W-64).
 */
const OPENED = [
  'users', 'users/private', 'settings',
  'clubs', 'memberships', 'memberships/private', 'reports', 'blocks', 'activity',
  'posts', 'posts/votes', 'comments', 'savedPosts', 'announcementCounters',
  'events', 'events/private', 'rsvps',
  'notifications',
  'supportTickets',
  'clubs/private',
];

const DENY_OPS = ['get', 'list', 'create', 'update'];
const VARIANT_OF = { create: 'genericCreate', update: 'genericUpdate' };
const ALL_CONTEXTS = [...CONTEXTS, ...VARIANTS];

const expectations = loadAllExpectations();
const matches = parseMatches(fs.readFileSync(rulesPath('firestore'), 'utf8'), FIRESTORE_PREFIX);
const collectionMatches = matches.filter((m) => !m.recursive);
const groupMatches = matches.filter((m) => m.recursive && m.names.length > 0);

/** Hedef belge VAR olmalı: ret, "belge yok" yüzünden değil kural yüzünden gelmelidir. */
const seedTarget = (exp) => seedDocs({ [exp.docPath]: targetDoc() });

describe('deny-all · beklenti dosyaları ↔ firestore.rules', () => {
  test('20 koleksiyon satırı vardır ve her biri kendi match bloğuna sahiptir (PLAN §11.1 + events/private — T-22, clubs/private — T-30)', () => {
    expect(expectations.map((e) => e.row)).toEqual(Array.from({ length: 20 }, (_, i) => i + 1));
    expect(expectations.map((e) => e.match).sort()).toEqual(collectionMatches.map((m) => m.pattern).sort());
  });

  test('açılmış koleksiyonlar beklenti dosyalarında vardır ve vaka taşır; kapalı olanlar vakasızdır', () => {
    const byCollection = new Map(expectations.map((e) => [e.collection, e]));
    for (const name of OPENED) expect([name, byCollection.get(name)?.cases.length > 0]).toEqual([name, true]);
    for (const e of expectations) {
      if (!OPENED.includes(e.collection)) expect([e.collection, e.cases.length]).toEqual([e.collection, 0]);
    }
  });

  test('son kural varsayılan rettir: match /{document=**}', () => {
    expect(matches[matches.length - 1].pattern).toBe('/{document=**}');
  });

  test('12 bağlam + 2 alt varyant tanımlıdır', () => {
    expect(CONTEXTS).toHaveLength(12);
    expect([...VARIANTS].sort()).toEqual(['deleted', 'outsideDomain']);
    for (const name of ALL_CONTEXTS) expect(definition(name)).toBeDefined();
  });
});

const CLOSED = expectations.filter((e) => !OPENED.includes(e.collection));

test('T-28 sonrası kapalı koleksiyon satırı kalmadı (20 / 20 açık)', () => {
  expect(CLOSED.map((e) => e.collection)).toEqual([]);
});

// `describe.each` boş tabloyu reddeder: kapalı satır kalmadığında blok kurulmaz.
(CLOSED.length ? describe.each(CLOSED.map((e) => [e.collection, e])) : () => {})(
  'deny-all · %s',
  (_name, exp) => {
    // Bağlam başına tek test, dört işlem (18 × 12 × 4 = 864 istek): hedef belge bir kez kurulur.
    test.each(CONTEXTS)(`%s · ${DENY_OPS.join(' / ')} → deny`, async (role) => {
      await seedTarget(exp);
      for (const op of DENY_OPS) {
        const c = { role, op, variant: VARIANT_OF[op] || null, expect: 'deny', ref: 'T-10 varsayılan ret' };
        await runCase(exp, c, { seed: false }).catch((error) => {
          throw new Error(`${exp.collection} · ${role} · ${op}: ${error.message}`);
        });
      }
      // update reddedildi: hedef belge kurulduğu gibi durur
      const target = await readDoc(exp.docPath);
      expect(target).toMatchObject({ ownerId: 'u_owner', isDeleted: false });
      expect(target).not.toHaveProperty('touched');
      // create reddedildi: yeni yol boş kalır (yol hedef belgeyle aynıysa hedef değişmeden durur)
      const created = fillPath(exp.newDocPath, { uid: uidOf(role), club: CLUB, otherClub: OTHER_CLUB });
      if (created !== exp.docPath) expect(await readDoc(created)).toBeNull();
    });
  },
);

describe('deny-all · matris koşucusu (helpers/matrix.js): süzgeçli list vakası süzgeçsiz ikiziyle koşar', () => {
  // Kurallarda tanımsız bir koleksiyon (varsayılan ret — T-28 ile bütün satırlar açıldı): süzgeçli sorgu
  // da süzgeçsiz ikizi de reddedilir.
  const posts = {
    ...loadExpectations('support_tickets.json'),
    collection: 'unknownCollection',
    docPath: 'unknownCollection/x',
    newDocPath: 'unknownCollection/y',
    listPath: 'unknownCollection',
  };
  const filtered = { where: [['isDeleted', '==', false]], orderBy: [['createdAt', 'desc']] };
  runCases(
    posts,
    ['anon', 'member', 'superadmin'].map((role) => ({ role, op: 'list', query: filtered, expect: 'deny', ref: 'SET-04' })),
    { seed: seedTarget },
  );

  test('geçersiz vaka (bilinmeyen işlem / bağlam / eksik varyant) yüklenirken reddedilir', () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'gu-exp-'));
    const write = (c) => {
      const file = path.join(dir, 'bad.json');
      fs.writeFileSync(file, JSON.stringify({ ...posts, cases: [c] }));
      return file;
    };
    expect(() => loadExpectations(write({ role: 'member', op: 'remove', expect: 'deny' }))).toThrow(/geçersiz op/);
    expect(() => loadExpectations(write({ role: 'uye', op: 'get', expect: 'deny' }))).toThrow(/bilinmeyen Rules bağlamı/);
    expect(() => loadExpectations(write({ role: 'member', op: 'create', expect: 'allow' }))).toThrow(/variant zorunlu/);
    expect(() => loadExpectations(write({ role: 'member', op: 'get', expect: 'maybe' }))).toThrow(/geçersiz expect/);
    expect(() => loadExpectations(write({ role: 'member', op: 'update', variant: 'x', batch: 'y', expect: 'deny' }))).toThrow(/birlikte verilemez/);
    expect(() => loadExpectations(write({ role: 'member', op: 'get', batch: 'y', expect: 'deny' }))).toThrow(/yalnızca create\/update/);
  });
});

/** Koleksiyon grubu → listeyi kurabilen bağlamlar (T-37: `private` — ADM-05 e-posta araması, rules/admin.test.js). */
const GROUP_READERS = Object.freeze({ private: ['super'] });

describe.each(groupMatches.map((m) => [m.names[m.names.length - 1]]))('deny-all · collectionGroup(%s)', (group) => {
  test.each(CONTEXTS.filter((role) => !(GROUP_READERS[group] || []).includes(role)))('%s · list → deny', async (role) => {
    await assertFails(getDocs(collectionGroup(contextFor(role).firestore(), group)));
  });
});

describe('deny-all · tanımsız yol (match /{document=**})', () => {
  test.each(ALL_CONTEXTS)('%s · get ve create → deny', async (role) => {
    await seedDocs({ 'unknownCollection/x': targetDoc() });
    const db = contextFor(role).firestore();
    await assertFails(getDoc(doc(db, 'unknownCollection/x')));
    await assertFails(setDoc(doc(db, 'unknownCollection/y'), payloads.baseCreate({ createdBy: uidOf(role) })));
    await assertFails(setDoc(doc(db, 'unknownCollection/x/nested/z'), payloads.baseCreate()));
  });
});

describe('deny-all · gerçekçi veriyle (fixtures.seedBase): ret, eksik belge yüzünden değildir', () => {
  // Süper admin dışındaki her bağlam süper admine izinli okumayı dener: `private` koleksiyon grubu (ADM-05 e-posta
  // araması — T-37; süper adminin geçen vakası rules/admin.test.js). Üyelik, kullanıcı ve gizli hesap belgeleri
  // yerindeyken de sonuç rettir. (Kendi kullanıcı / hesap / ayar belgesi T-12'de; kulüp ve üyelik T-15'te; gönderi, yorum, oy,
  // kayıt ve duyuru sayacı T-19'da; etkinlik ve katılım T-22'de; bildirim T-25'te; destek talebi T-28'de
  // açıldı.)
  test.each(ALL_CONTEXTS.filter((role) => role !== 'super'))('%s · private koleksiyon grubu → deny', async (role) => {
    const docs = await seedBase();
    const uid = uidOf(role);
    const db = contextFor(role).firestore();
    const membership = definition(role).membership;
    expect(Object.keys(docs).some((p) => /\/private\/(account|contact)$/.test(p))).toBe(true);
    await assertFails(getDocs(collectionGroup(db, 'private')));
    if (membership) expect(docs[`memberships/${membership.clubId}_${uid}`].status).toBe(membership.status);
  });

  test('temel veri kümesi 20 koleksiyon satırının her birinde hedef belgeyi içerir', async () => {
    const docs = baseDocs();
    for (const exp of expectations) expect(Object.keys(docs)).toContain(exp.docPath);
    await seedBase();
    expect(await readDoc('clubs/c01')).toMatchObject({ presidentId: 'u_president', memberCount: 5, isDeleted: false });
    expect(await readDoc('clubs/c02')).toMatchObject({ presidentId: 'u_mgr2', memberCount: 1 });
  });

  test('former bağlamı dört eski durumla kurulabilir; geçersiz durum hatadır', () => {
    for (const status of ['left', 'cancelled', 'rejected', 'removed']) {
      expect(baseDocs({ formerStatus: status })['memberships/c01_u_former'].status).toBe(status);
    }
    expect(() => baseDocs({ formerStatus: 'active' })).toThrow(/formerStatus/);
  });
});

describe('yardımcı iskeleti (T-10): budget.js', () => {
  test('süper adminin çok yazımlı batch\'i de reddedilir ve "permission-denied" olarak sınıflanır', async () => {
    const db = contextFor('super').firestore();
    const batch = budget.buildBatch(db, [
      { op: 'set', path: 'clubs/c_new', data: payloads.baseCreate({ createdBy: 'u_super' }) },
      { op: 'set', path: 'memberships/c_new_u_president', data: payloads.baseCreate() },
    ]);
    const result = await budget.classify(batch.commit());
    expect(result.outcome).toBe(budget.Outcome.permissionDenied);
    expect(await readDoc('clubs/c_new')).toBeNull();
  });

  test('buildBatch silme işlemini kabul etmez (D-10)', () => {
    const db = contextFor('super').firestore();
    expect(() => budget.buildBatch(db, [{ op: 'delete', path: 'clubs/c01', data: {} }])).toThrow(/silme yok/);
  });

  test('writeResult ölçümü anahtarları sıralı JSON olarak yazar', () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'gu-budget-'));
    const file = budget.writeResult('fanout_result.json', { measured: [10, 20], chunkSize: 50 }, dir);
    expect(fs.readFileSync(file, 'utf8')).toBe('{\n  "chunkSize": 50,\n  "measured": [\n    10,\n    20\n  ]\n}\n');
    expect(() => budget.writeResult('../x.json', {}, dir)).toThrow(/geçersiz sonuç dosyası adı/);
  });
});
