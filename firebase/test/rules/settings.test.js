'use strict';
// T-12 — `settings/{uid}` (rules-spec §3.12; PLAN §11.1 satır 14).
//
//  1. Rol × işlem matrisi: `expectations/settings.json` (yalnızca sahibi; süper admin dahil başkası
//     okuyamaz / yazamaz; askıdaki kullanıcı için `emailOk()` yeter).
//  2. Alan beyaz listesi ve tipler: on bir alan + `updatedAt`; ortak alan (BaseFields) YOK.
//  3. `reminderTime ∈ {1h, 1d}` (CD-34) ve `quietFrom` / `quietTo` `HH:mm` deseni — desen Dart
//     `Limits.timeOfDayPattern` ile aynı sonucu verir (örnek değerler iki tarafta da sınanır).
//  4. Sunucu zamanı: `updatedAt` istemci saatiyle yazılamaz, atlanamaz.
//  5. T-45 F4 (CD-133 madde 8 "bilinen açık"): `clubs` haritası — değer tam `ClubNotificationPrefsModel.toJson()`
//     biçimi (dört bool, başka anahtar yok), anahtar kulüp kimliği deseni, en çok `Limits.settingsClubsMax` kayıt.
//     Sunucu her push'ta belgeyi okur (send_push / preference_filter) — biçimsiz / büyük değer yazılamaz.
const path = require('node:path');
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { Timestamp, doc, serverTimestamp, setDoc, updateDoc } = require('firebase/firestore');
const { contextFor } = require('../helpers/contexts');
const { baseDocs, readDoc, seedDocs } = require('../helpers/fixtures');
const { runMatrix } = require('../helpers/matrix');
const payloads = require('../helpers/payloads');

const REPO_ROOT = path.resolve(__dirname, '..', '..', '..');
const limits = require(path.join(REPO_ROOT, 'tool', 'lib', 'dart_sources.js')).readLimits(REPO_ROOT);

const UID = 'u_student';
const SETTINGS = `settings/${UID}`;

const studentDb = () => contextFor('student').firestore();
const clientTime = () => Timestamp.fromMillis(Date.now() - 60 * 1000);
const omit = (object, keys) => Object.fromEntries(Object.entries(object).filter(([key]) => !keys.includes(key)));
const expectWrite = (request, expected) => (expected === 'allow' ? assertSucceeds(request) : assertFails(request));
const CLUB_PREFS = { announcements: true, events: false, posts: true, muted: false };
/** `n` geçerli kulüp tercihi (`k000`, `k001`, …). */
const manyClubs = (n) => Object.fromEntries(Array.from({ length: n }, (_, i) => [`k${String(i).padStart(3, '0')}`, CLUB_PREFS]));
/** Kulüp tercihi biçim satırları (T-45 F4): [başlık, kulüp anahtarı, değer, beklenti]. */
const CLUB_SHAPES = [
  ['değer büyük dizgi (~500 KB)', 'c01', 'a'.repeat(500000), 'deny'],
  ['değer dizi', 'c01', [1, 2, 3], 'deny'],
  ['değer iç içe harita', 'c01', { ...CLUB_PREFS, muted: { deep: { deeper: true } } }, 'deny'],
  ['değerde eksik alan (muted)', 'c01', omit(CLUB_PREFS, ['muted']), 'deny'],
  ['değerde fazla alan', 'c01', { ...CLUB_PREFS, theme: 'dark' }, 'deny'],
  ['değerde bool olmayan alan', 'c01', { ...CLUB_PREFS, posts: 'true' }, 'deny'],
  ['boş değer', 'c01', {}, 'deny'],
  ['anahtar desen dışı (c-01)', 'c-01', CLUB_PREFS, 'deny'],
  ['anahtar 21 karakter', 'a'.repeat(21), CLUB_PREFS, 'deny'],
  ['tüm alanlar false (geçerli birleşim)', 'c01', { announcements: false, events: false, posts: false, muted: false }, 'allow'],
  ['muted true (geçerli birleşim)', 'c01', { ...CLUB_PREFS, muted: true }, 'allow'],
  ['anahtar 20 karakter (otomatik kimlik)', 'AbCdEfGhIjKlMnOpQr01', CLUB_PREFS, 'allow'],
];

runMatrix('settings.json');

describe('settings · create — alan beyaz listesi ve tipler (rules-spec §3.12 C)', () => {
  // Taban yük `payloads.settingsCreate` = `UserSettingsModel.defaults(uid).toJson()` + `updatedAt`.
  test.each([
    ['alan eksik (quiet)', {}, ['quiet'], 'deny'],
    ['alan eksik (clubs)', {}, ['clubs'], 'deny'],
    ['beyaz liste dışı alan (theme)', { theme: 'dark' }, [], 'deny'],
    ['ortak alan (isDeleted) — settings BaseFields taşımaz', { isDeleted: false }, [], 'deny'],
    ['createdAt — settings yalnızca updatedAt taşır', { createdAt: serverTimestamp() }, [], 'deny'],
    ['reminderTime 1d', { reminderTime: '1d' }, [], 'allow'],
    ['reminderTime 15m (yalnızca rsvps.reminder — CD-34)', { reminderTime: '15m' }, [], 'deny'],
    ['reminderTime none', { reminderTime: 'none' }, [], 'deny'],
    ['announcements bool değil', { announcements: 'true' }, [], 'deny'],
    ['quiet bool değil', { quiet: 1 }, [], 'deny'],
    ['quietFrom dizgi değil', { quietFrom: 2200 }, [], 'deny'],
    ['clubs map değil', { clubs: [] }, [], 'deny'],
    ['clubs dolu map', { clubs: { c01: CLUB_PREFS } }, [], 'allow'],
    // T-45 F4
    ...CLUB_SHAPES.map(([title, key, value, expected]) => [`clubs: ${title}`, { clubs: { [key]: value } }, [], expected]),
    [`clubs: ${limits.ints.settingsClubsMax} kayıt (settingsClubsMax)`, { clubs: manyClubs(limits.ints.settingsClubsMax) }, [], 'allow'],
    [`clubs: ${limits.ints.settingsClubsMax + 1} kayıt`, { clubs: manyClubs(limits.ints.settingsClubsMax + 1) }, [], 'deny'],
    ['updatedAt istemci saati', { updatedAt: clientTime() }, [], 'deny'],
    ['updatedAt yok', {}, ['updatedAt'], 'deny'],
  ])('%s', async (_title, extra, removed, expected) => {
    const payload = omit(payloads.settingsCreate(extra), removed);
    await expectWrite(setDoc(doc(studentDb(), SETTINGS), payload), expected);
    if (expected === 'deny') expect(await readDoc(SETTINGS)).toBeNull();
  });
});

describe('settings · update — alan beyaz listesi ve tipler (rules-spec §3.12 U)', () => {
  const touch = (fields) => ({ ...fields, ...payloads.baseUpdate() });

  test.each([
    ['tek alan (quiet)', touch({ quiet: true }), 'allow'],
    ['clubs.<clubId> içindeki tek tercih', touch({ 'clubs.c01': CLUB_PREFS, 'clubs.c02': { ...CLUB_PREFS, muted: true } }), 'allow'],
    ['reminderTime 15m', touch({ reminderTime: '15m' }), 'deny'],
    ['quietTo desen dışı (25:00)', touch({ quietTo: '25:00' }), 'deny'],
    ['clubs map değil', touch({ clubs: 'c01' }), 'deny'],
    // T-45 F4: noktalı alan yolu (updateClubSettings) ve bütün harita yazımı aynı biçimle sınanır.
    ...CLUB_SHAPES.map(([title, key, value, expected]) => [`clubs.<id>: ${title}`, touch({ [`clubs.${key}`]: value }), expected]),
    ['clubs.c01.muted iç içe harita (alt alan yolu)', touch({ 'clubs.c01.muted': { deep: true } }), 'deny'],
    ['saldırı yükü: bütün harita biçimsiz (dizgi + dizi + iç içe)', touch({ clubs: { x: 'a'.repeat(500000), y: [1, 2, 3], z: { deep: { deeper: true } } } }), 'deny'],
    ['bütün harita geçerli (iki kulüp)', touch({ clubs: { c01: CLUB_PREFS, c02: { ...CLUB_PREFS, muted: true } } }), 'allow'],
    ['harita boşaltılır (clubs: {})', touch({ clubs: {} }), 'allow'],
    ['beyaz liste dışı alan (theme)', touch({ theme: 'dark' }), 'deny'],
    ['ortak alan (isDeleted)', touch({ isDeleted: true }), 'deny'],
    ['updatedAt yok', { quiet: true }, 'deny'],
    ['updatedAt istemci saati', { quiet: true, updatedAt: clientTime() }, 'deny'],
  ])('%s', async (_title, payload, expected) => {
    await seedDocs({ [SETTINGS]: baseDocs()[SETTINGS] });
    const before = await readDoc(SETTINGS);
    await expectWrite(updateDoc(doc(studentDb(), SETTINGS), payload), expected);
    if (expected === 'deny') expect(await readDoc(SETTINGS)).toEqual(before);
  });
});

describe('settings · clubs kayıt sayısı (T-45 F4: Limits.settingsClubsMax — belge boyutu sınırı)', () => {
  const MAX = limits.ints.settingsClubsMax;
  test.each([
    [`${MAX - 1} kayıtlı belgeye bir kulüp eklenir (${MAX})`, MAX - 1, 'allow'],
    [`${MAX} kayıtlı belgeye bir kulüp eklenir (${MAX + 1})`, MAX, 'deny'],
  ])('%s → %s', async (_title, seeded, expected) => {
    await seedDocs({ [SETTINGS]: { ...baseDocs()[SETTINGS], clubs: manyClubs(seeded) } });
    const request = updateDoc(doc(studentDb(), SETTINGS), { 'clubs.zz01': CLUB_PREFS, ...payloads.baseUpdate() });
    await expectWrite(request, expected);
    expect(Object.keys((await readDoc(SETTINGS)).clubs)).toHaveLength(expected === 'allow' ? seeded + 1 : seeded);
  });

  test(`${MAX} kayıtlı belgede var olan kayıt değişir (sayı artmaz) → allow`, async () => {
    await seedDocs({ [SETTINGS]: { ...baseDocs()[SETTINGS], clubs: manyClubs(MAX) } });
    await assertSucceeds(updateDoc(doc(studentDb(), SETTINGS), { 'clubs.k000': { ...CLUB_PREFS, muted: true }, ...payloads.baseUpdate() }));
  });
});

describe('settings · HH:mm deseni Limits.timeOfDayPattern ile aynı sonucu verir', () => {
  const dartPattern = new RegExp(limits.strings.timeOfDayPattern);
  const SAMPLES = ['00:00', '08:00', '19:59', '23:59', '24:00', '7:00', '07:60', '22:00 ', ' 22:00', '22.00', '2200', ''];

  test('örnek değerler iki uçta da sınanıyor (geçen ve reddedilen)', () => {
    const results = SAMPLES.map((value) => dartPattern.test(value));
    expect(results.filter(Boolean)).toHaveLength(4);
    expect(results.filter((ok) => !ok)).toHaveLength(SAMPLES.length - 4);
  });

  test.each(SAMPLES.map((value) => [JSON.stringify(value), value]))('quietFrom / quietTo = %s', async (_label, value) => {
    const expected = dartPattern.test(value) ? 'allow' : 'deny';
    await seedDocs({ [SETTINGS]: baseDocs()[SETTINGS] });
    const ref = doc(studentDb(), SETTINGS);
    await expectWrite(updateDoc(ref, { quietFrom: value, ...payloads.baseUpdate() }), expected);
    await expectWrite(updateDoc(ref, { quietTo: value, ...payloads.baseUpdate() }), expected);
  });
});
