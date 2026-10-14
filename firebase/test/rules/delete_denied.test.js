'use strict';
// T-10 — `delete` her koleksiyonda ve her alt koleksiyonda reddedilir, süper admin dahil (D-10,
// rules-spec §1.2; PLAN §11.1: 18 yol × 12 bağlam = 216 ret vakası; T-22: + `events/{id}/private/counter`
// yan belgesi = 19 yol; T-30: + `clubs/{id}/private/counter` = 20 yol × 12 bağlam = 240).
//
// Koleksiyon adları elle yazılmaz: Dart `FirestoreCollections` sabitleri
// (packages/gu_data/lib/src/constants/firestore_collections.dart) ile `firestore.rules` `match`
// blokları karşılaştırılır. Dart'a eklenen bir koleksiyon Rules'ta bloksuz kalırsa ya da Rules'ta
// sabiti olmayan bir blok açılırsa bu dosya kırmızıya döner.
//
// Bu test kalıcıdır: koleksiyonlar sahibi task'ta açıldıkça da her yol için ret beklenmeye devam eder.
// `deleteDoc` / `batch.delete` çağrıları yalnızca reddedildiklerini kanıtlamak için buradadır.
const fs = require('node:fs');
const { assertFails } = require('@firebase/rules-unit-testing');
const { deleteDoc, doc, runTransaction, writeBatch } = require('firebase/firestore');
const { rulesPath } = require('../setup/emulator_ports');
const { CONTEXTS, VARIANTS, contextFor } = require('../helpers/contexts');
const { readDoc, seedDocs, targetDoc } = require('../helpers/fixtures');
const { FIRESTORE_PREFIX, dartCollections, parseMatches } = require('../helpers/matrix');

const dart = dartCollections();
const rulesText = fs.readFileSync(rulesPath('firestore'), 'utf8');
const matches = parseMatches(rulesText, FIRESTORE_PREFIX);
const collectionMatches = matches.filter((m) => !m.recursive);

/**
 * `private` alt koleksiyonunun sabit belge adı: users → account, memberships → contact, events ve clubs →
 * counter (yönetici sayaç işaretçisi — W-64; Dart `FirestoreCollections.counterDoc`, T-30).
 */
const PRIVATE_DOC = { users: dart.docs.accountDoc, memberships: dart.docs.contactDoc, events: dart.docs.counterDoc, clubs: dart.docs.counterDoc };

/** `/users/{uid}/private/{docId}` → `users/d1/private/account` (silinecek somut belge yolu). */
function concretePath(match) {
  const [root] = match.names;
  let index = 0;
  return match.pattern
    .split('/')
    .filter(Boolean)
    .map((part, position, parts) => {
      if (!part.startsWith('{')) return part;
      index += 1;
      const collection = parts[position - 1];
      if (collection === 'private' && PRIVATE_DOC[root]) return PRIVATE_DOC[root];
      return `d${index}`;
    })
    .join('/');
}

const targets = collectionMatches.map((m) => [m.pattern, concretePath(m)]);

describe('delete-denied · FirestoreCollections ↔ firestore.rules match adları', () => {
  test('Dart sabitleri: 15 kök koleksiyon, 2 alt koleksiyon, 3 sabit belge adı', () => {
    expect(dart.roots).toHaveLength(15);
    expect(dart.subs.sort()).toEqual(['private', 'votes']);
    expect(dart.docs).toEqual({ accountDoc: 'account', contactDoc: 'contact', counterDoc: 'counter' });
  });

  test('her kök koleksiyonun Rules\'ta kendi match bloğu vardır ve fazlası yoktur', () => {
    const rulesRoots = collectionMatches.filter((m) => m.names.length === 1).map((m) => m.names[0]);
    expect(rulesRoots.sort()).toEqual([...dart.roots].sort());
  });

  test('alt koleksiyon blokları yalnızca Dart\'taki alt koleksiyon adlarını kullanır', () => {
    const nested = collectionMatches.filter((m) => m.names.length > 1);
    expect(nested.map((m) => m.names.join('/')).sort()).toEqual(['clubs/private', 'events/private', 'memberships/private', 'posts/votes', 'users/private']);
    for (const m of nested) {
      expect(dart.roots).toContain(m.names[0]);
      expect(dart.subs).toContain(m.names[1]);
    }
    const groups = matches.filter((m) => m.recursive && m.names.length > 0).map((m) => m.names[0]);
    expect(groups.sort()).toEqual([...dart.subs].sort());
  });

  test('toplam 20 yol (PLAN §11.1 + events/private + clubs/private) ve her blokta açık `allow delete: if false`', () => {
    expect(targets).toHaveLength(20);
    const denies = rulesText.match(/^\s*allow delete: if false;\s*$/gm) || [];
    expect(denies).toHaveLength(20);
  });
});

describe.each(targets)('delete-denied · %s', (_pattern, path) => {
  test.each(CONTEXTS)('%s · delete → deny (belge yerinde kalır)', async (role) => {
    await seedDocs({ [path]: targetDoc() });
    await assertFails(deleteDoc(doc(contextFor(role).firestore(), path)));
    expect(await readDoc(path)).toMatchObject({ isDeleted: false });
  });
});

describe('delete-denied · süper admin ve alt varyantlar için başka yollardan silme', () => {
  const sample = targets.map(([, path]) => path);

  test('süper admin: tek batch ile 20 yolun hiçbiri silinemez', async () => {
    await seedDocs(Object.fromEntries(sample.map((p) => [p, targetDoc()])));
    const db = contextFor('super').firestore();
    for (const p of sample) {
      const batch = writeBatch(db);
      batch.delete(doc(db, p));
      await assertFails(batch.commit());
    }
    for (const p of sample) expect(await readDoc(p)).not.toBeNull();
  });

  test('süper admin: transaction içinde silme reddedilir', async () => {
    await seedDocs({ 'clubs/d1': targetDoc() });
    const db = contextFor('super').firestore();
    await assertFails(runTransaction(db, async (tx) => tx.delete(doc(db, 'clubs/d1'))));
    expect(await readDoc('clubs/d1')).not.toBeNull();
  });

  test.each([...VARIANTS, 'super'])('%s · tanımsız yolda delete → deny (varsayılan ret)', async (role) => {
    await seedDocs({ 'unknownCollection/x': targetDoc() });
    await assertFails(deleteDoc(doc(contextFor(role).firestore(), 'unknownCollection/x')));
    expect(await readDoc('unknownCollection/x')).not.toBeNull();
  });

  test.each(VARIANTS)('%s · 20 yolun hiçbiri silinemez', async (role) => {
    await seedDocs(Object.fromEntries(sample.map((p) => [p, targetDoc()])));
    const db = contextFor(role).firestore();
    for (const p of sample) await assertFails(deleteDoc(doc(db, p)));
  });
});
