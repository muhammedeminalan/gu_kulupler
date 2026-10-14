'use strict';
// T-22 — `events/{eventId}` (rules-spec §3.7; PLAN §11.1 satır 9; sözleşme docs/plans/T-22.md §6.2, §6.6, §6.7).
//
//  1. Rol × işlem matrisi: `expectations/events.json` (okuma: public / members / taslak; yazım yalnızca kulüp
//     yönetimi; durum makinesi; soft delete yalnızca taslak; sayaç tek başına yazılamaz; delete ret).
//  2. Oluşturma (C): alan beyaz listesi, tipler, sınırlar (Limits paritesi), W-51 iki biçim, W-64.
//  3. İçerik dalı (U): kontenjan ≥ kayıtlı, `coverPath` yol denetimi (CD-47), değişmez alanlar.
//  4. Durum makinesi: yayın (başlangıç gelecekte, `publishedAt`), yayından çekme (K-F), iptal (neden).
//  5. Günlük (activity `event_published` / `event_cancelled`): yalnızca geçişle aynı işlemde, sabit kimlik.
// Sayaç–katılım eşliği `counters.test.js`, katılım kuralları `rsvps.test.js`, sorgular `queries.test.js`.
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { Timestamp, doc, increment, serverTimestamp, setDoc, updateDoc } = require('firebase/firestore');
const budget = require('../helpers/budget');
const { contextFor, CLUB, OTHER_CLUB } = require('../helpers/contexts');
const { DAY_MS, HOUR_MS, fromNow, readDoc, seedFixture } = require('../helpers/fixtures');
const { runMatrix } = require('../helpers/matrix');
const payloads = require('../helpers/payloads');

const BOARD = 'u_board';
const E_PUBLIC = 'events/e_public';
const E_DRAFT = 'events/e_draft';
const NEW_PATH = 'events/e_new';
const NO_EDIT = Object.freeze({});
/** İstemci biçimi (W-51): null olabilen alanların anahtarı yok. */
const CLIENT_FORM = ['placeText', 'capacity', 'cancelReason', 'coverPath'];

const db = (role) => contextFor(role).firestore();
const commit = (role, writes) => budget.buildBatch(db(role), Object.values(writes)).commit();
const expectWrite = (request, expected) => (expected === 'allow' ? assertSucceeds(request) : assertFails(request));
const without = (data, ...keys) => Object.fromEntries(Object.entries(data).filter(([key]) => !keys.includes(key)));
const at = (ms) => Timestamp.fromMillis(Date.now() + ms);
/** Yöneticinin taslak yükü; `extra` alanları ezer / ekler, `drop` anahtarları çıkarır. */
const draft = (extra, { drop = [], eventId = 'e_new', status = 'draft' } = {}) =>
  without(payloads.eventCreate({ club: CLUB, uid: BOARD, eventId, status }, extra), ...drop);
const create = (role, data, path = NEW_PATH) => setDoc(doc(db(role), path), data);
const edit = (data, path = E_PUBLIC, role = 'board') => updateDoc(doc(db(role), path), { ...payloads.baseUpdate(), ...data });

runMatrix('events.json');

describe('events · create — biçim, sınırlar ve beyaz liste (rules-spec §3.7 C)', () => {
  test('taslak yalnızca beklenen alanları taşır (istemci biçimi; lastRsvpRef / coverPath / cancelReason / publishedAt yok)', async () => {
    await seedFixture('base');
    await assertSucceeds(create('board', draft()));
    const event = await readDoc(NEW_PATH);
    expect(Object.keys(event).sort()).toEqual([
      'attendedCount', 'autoReminder', 'clubId', 'coverPalette', 'coverPattern', 'coverSeed', 'createdAt', 'createdBy',
      'deletedAt', 'deletedBy', 'desc', 'endsAt', 'goingCount', 'isDeleted', 'placeId', 'registrationOpen', 'startsAt',
      'status', 'title', 'type', 'updatedAt', 'visibility', 'waitlistCount',
    ]);
    expect(event).toMatchObject({ clubId: CLUB, createdBy: BOARD, status: 'draft', coverSeed: 'event-e_new', goingCount: 0, waitlistCount: 0, attendedCount: 0 });
  });

  // Satır: [başlık, alan ezmesi, beklenti, seçenekler?]. Sınırlar: Limits.eventTitleMax 80 · eventDescMax 1000 ·
  // placeTextMax 120 (parite: tool/check_rules_parity.js RP01).
  test.each([
    ['başlık tam sınırda (80)', { title: 'a'.repeat(80) }, 'allow'],
    ['açıklama tam sınırda (1000) / boş açıklama', { desc: 'a'.repeat(1000) }, 'allow'],
    ['serbest metin mekân tam sınırda (120), mekân kimliği yok', { placeText: 'a'.repeat(120) }, 'allow', { drop: ['placeId'] }],
    ['kontenjan 1 (alt sınır)', { capacity: 1 }, 'allow'],
    ['seed biçimi: null alanlar açık null (W-51)', payloads.EVENT_NULLS, 'allow'],
    ['üyelere özel, konferans, bordo / dalga kapak', { visibility: 'members', type: 'konferans', coverPalette: 'bordeaux', coverPattern: 'waves' }, 'allow'],
    ['doğrudan yayın: publishedAt sunucu zamanı, başlangıç gelecekte', {}, 'allow', { status: 'published' }],
    ['boş başlık', { title: '' }, 'deny'],
    ['yalnızca boşluktan oluşan başlık', { title: ' \n ' }, 'deny'],
    ['başlık sınırın üstünde (81)', { title: 'a'.repeat(81) }, 'deny'],
    ['açıklama sınırın üstünde (1001)', { desc: 'a'.repeat(1001) }, 'deny'],
    ['bilinmeyen tür', { type: 'workshop' }, 'deny'],
    ['bitiş başlangıca eşit', { startsAt: at(DAY_MS), endsAt: at(DAY_MS) }, 'deny'],
    ['bitiş başlangıçtan önce', { endsAt: at(HOUR_MS) }, 'deny'],
    ['başlangıç zaman damgası değil (dizgi)', { startsAt: '2026-10-20T10:00:00Z' }, 'deny'],
    ['mekân kimliği tablo biçiminde değil', { placeId: 'salon' }, 'deny'],
    ['serbest metin mekân sınırın üstünde (121)', { placeText: 'a'.repeat(121) }, 'deny'],
    ['kontenjan 0', { capacity: 0 }, 'deny'],
    ['kontenjan negatif', { capacity: -5 }, 'deny'],
    ['kontenjan tam sayı değil (2.5)', { capacity: 2.5 }, 'deny'],
    ['kontenjan dizgi', { capacity: '10' }, 'deny'],
    ['bilinmeyen görünürlük', { visibility: 'private' }, 'deny'],
    ['bilinmeyen palet', { coverPalette: 'blue' }, 'deny'],
    ['bilinmeyen desen', { coverPattern: 'zigzag' }, 'deny'],
    ['registrationOpen bool değil', { registrationOpen: 'evet' }, 'deny'],
    ['autoReminder yok', {}, 'deny', { drop: ['autoReminder'] }],
    ['iptal edilmiş doğan etkinlik', { status: 'cancelled', cancelReason: 'x' }, 'deny'],
    ['yayında ama publishedAt yok', { status: 'published' }, 'deny'],
    ['yayında, publishedAt istemci saati', { publishedAt: at(-60 * 1000) }, 'deny', { status: 'published' }],
    ['taslakta publishedAt dolu', { publishedAt: serverTimestamp() }, 'deny'],
    ['yayında, başlangıç geçmişte', { startsAt: at(-HOUR_MS), endsAt: at(HOUR_MS) }, 'deny', { status: 'published' }],
    ['goingCount sıfır değil', { goingCount: 1 }, 'deny'],
    ['waitlistCount sıfır değil', { waitlistCount: 1 }, 'deny'],
    ['attendedCount sıfır değil', { attendedCount: 1 }, 'deny'],
    ['kapak yolu oluştururken dolu (kapak sonradan yüklenir — CD-47)', { coverPath: payloads.eventCoverPath('e_new') }, 'deny'],
    ['iptal nedeni oluştururken dolu', { cancelReason: 'x' }, 'deny'],
    ['coverSeed etkinlik kimliğinden türemiyor', { coverSeed: 'event-baska' }, 'deny'],
    ['başkası adına (createdBy)', { createdBy: 'u_president' }, 'deny'],
    ['yöneticisi olmadığı kulüp adına (clubId)', { clubId: OTHER_CLUB }, 'deny'],
    ['beyaz liste dışı alan: lastRsvpRef (W-64 — işaretçi herkese açık belgede durmaz)', { lastRsvpRef: null }, 'deny'],
    ['beyaz liste dışı alan (likeCount)', { likeCount: 0 }, 'deny'],
    ['silinmiş doğan etkinlik', { isDeleted: true }, 'deny'],
    ['createdAt istemci saati', { createdAt: at(-60 * 1000) }, 'deny'],
  ])('%s → %s', async (_title, extra, expected, options = {}) => {
    await seedFixture('base');
    await expectWrite(create('board', draft(extra, options)), expected);
    if (expected === 'deny') expect(await readDoc(NEW_PATH)).toBeNull();
    else expect((await readDoc(NEW_PATH)).createdBy).toBe(BOARD);
  });

  test.each([['e.new'], ['e new'], ['e(1)'], ['ü-etkinlik']])('kimlik belge kimliği deseninde değil (%s) → deny', async (eventId) => {
    await seedFixture('base');
    await assertFails(create('board', draft({}, { eventId }), `events/${eventId}`));
    expect(await readDoc(`events/${eventId}`)).toBeNull();
  });

  test('var olan etkinliğin üzerine yeniden yazım (set) reddedilir', async () => {
    await seedFixture('base');
    await assertFails(create('board', draft({}, { eventId: 'e_draft' }), E_DRAFT));
    expect((await readDoc(E_DRAFT)).title).toBe('Etkinlik public/draft');
  });
});

describe('events · update — içerik dalı (rules-spec §3.7 U; kontenjan, coverPath, değişmez alanlar)', () => {
  // `e_public`: yayında, 2 kayıtlı, kontenjan 40 (seed biçimi). Satır: [başlık, yama, beklenti, veri düzenlemesi?].
  test.each([
    ['kontenjan kayıtlı sayısına eşit (2)', { capacity: 2 }, 'allow'],
    ['kontenjan kaldırılır (açık null = sınırsız)', { capacity: null }, 'allow'],
    ['istemci biçimli belgede (kontenjan anahtarı yok — W-51) kontenjan konur', { capacity: 10 }, 'allow', { unset: { [E_PUBLIC]: CLIENT_FORM } }],
    ['istemci biçimli belgede başlık düzenlenir (W-51)', { title: 'Yeni başlık' }, 'allow', { unset: { [E_PUBLIC]: CLIENT_FORM } }],
    ['mekân: tablo kimliği boşalır, serbest metin gelir', { placeId: null, placeText: 'Kütüphane önü' }, 'allow'],
    ['tarih, görünürlük ve kapak şablonu değişir', { startsAt: at(5 * DAY_MS), endsAt: at(5 * DAY_MS + HOUR_MS), visibility: 'members', coverPalette: 'slate', coverPattern: 'waves' }, 'allow'],
    ['özel kapak: etkinliğin kendi klasörü (CD-47)', { coverPath: payloads.eventCoverPath('e_public') }, 'allow'],
    ['özel kapak kaldırılır (açık null)', { coverPath: null }, 'allow', { patch: { [E_PUBLIC]: { coverPath: payloads.eventCoverPath('e_public') } } }],
    ['kontenjan kayıtlı sayısının altında (1 < 2)', { capacity: 1 }, 'deny'],
    ['kontenjan 0', { capacity: 0 }, 'deny'],
    ['özel kapak: başka etkinliğin klasörü', { coverPath: payloads.eventCoverPath('e_members') }, 'deny'],
    ['özel kapak: gönderi klasörü', { coverPath: payloads.postImage('e_public').path }, 'deny'],
    ['özel kapak: alt klasör', { coverPath: 'events/e_public/alt/20261008T201500Z_3f9a1c2b7d4e5f60.jpg' }, 'deny'],
    ['özel kapak: şema dışı dosya adı', { coverPath: 'events/e_public/cover.jpg' }, 'deny'],
    ['özel kapak: izinsiz uzantı', { coverPath: 'events/e_public/20261008T201500Z_3f9a1c2b7d4e5f60.gif' }, 'deny'],
    ['özel kapak: dizgi değil', { coverPath: 42 }, 'deny'],
    ['başlık sınırın üstünde (81)', { title: 'a'.repeat(81) }, 'deny'],
    ['bitiş, var olan başlangıçtan önceye çekilir', { endsAt: at(HOUR_MS) }, 'deny'],
    // Güvenlik incelemesi (CD-144; domain-model §2.7 "yayında başlangıç gelecekte"): bitmiş etkinliğin bitişi ileri
    // alınıp katılım / yoklama penceresi (K-G) yeniden açılamaz; yayın koşulu başlangıç geçmişe çekilerek atlatılamaz.
    ['yayında, bitmiş etkinliğin bitişi ileri alınır (yoklama penceresi yeniden açılır)', { endsAt: at(DAY_MS) }, 'deny', { patch: { [E_PUBLIC]: { startsAt: fromNow(-3 * HOUR_MS), endsAt: fromNow(-HOUR_MS) } } }],
    ['yayında, süren etkinliğin bitişi uzatılır', { endsAt: at(3 * HOUR_MS) }, 'deny', { patch: { [E_PUBLIC]: { startsAt: fromNow(-HOUR_MS), endsAt: fromNow(HOUR_MS) } } }],
    ['yayında, başlangıç geçmişe çekilir', { startsAt: at(-HOUR_MS) }, 'deny'],
    ['yayında, bitmiş etkinlikte zaman dışı içerik düzenlenir', { title: 'Yeni başlık' }, 'allow', { patch: { [E_PUBLIC]: { startsAt: fromNow(-3 * HOUR_MS), endsAt: fromNow(-HOUR_MS) } } }],
    ['içerikle birlikte durum geçişi (status)', { title: 'x', status: 'cancelled', cancelReason: 'x' }, 'deny'],
    ['içerikle birlikte sayaç (goingCount)', { title: 'x', goingCount: increment(1) }, 'deny'],
    ['içerikle birlikte sayaç (attendedCount mutlak)', { title: 'x', attendedCount: 2 }, 'deny'],
    ['kulüp değiştirme (clubId)', { clubId: OTHER_CLUB }, 'deny'],
    ['oluşturan değiştirme (createdBy)', { createdBy: 'u_president' }, 'deny'],
    ['coverSeed değiştirme', { coverSeed: 'event-x' }, 'deny'],
    ['publishedAt değiştirme', { publishedAt: serverTimestamp() }, 'deny'],
    ['yayındaki etkinliğe iptal nedeni', { cancelReason: 'x' }, 'deny'],
    ['createdAt değiştirme', { createdAt: serverTimestamp() }, 'deny'],
    ['beyaz liste dışı alan: lastRsvpRef (W-64)', { lastRsvpRef: 'rsvps/e_public_u_member' }, 'deny'],
    ['updatedAt istemci saati', { title: 'x', updatedAt: at(-60 * 1000) }, 'deny'],
  ])('%s → %s', async (_title, patch, expected, seedEdit = NO_EDIT) => {
    const seeded = await seedFixture('base', undefined, seedEdit);
    await expectWrite(edit(patch), expected);
    const event = await readDoc(E_PUBLIC);
    if (expected === 'deny') expect(event.title).toBe(seeded[E_PUBLIC].title);
    expect(event).toMatchObject({ clubId: CLUB, createdBy: BOARD, status: 'published', goingCount: 2, coverSeed: 'event-test' });
  });

  test('taslakta zaman serbest: başlangıcı geçmiş taslağın tarihi değişir (yayın ayrıca startsAt > request.time ister)', async () => {
    await seedFixture('base', undefined, { patch: { [E_DRAFT]: { startsAt: fromNow(-3 * HOUR_MS), endsAt: fromNow(-HOUR_MS) } } });
    await assertSucceeds(edit({ endsAt: at(HOUR_MS) }, E_DRAFT));
    await assertSucceeds(edit({ startsAt: at(DAY_MS), endsAt: at(DAY_MS + HOUR_MS) }, E_DRAFT));
  });

  test('updatedAt taşımayan düzenleme reddedilir', async () => {
    await seedFixture('base');
    await assertFails(updateDoc(doc(db('board'), E_PUBLIC), { title: 'x' }));
  });

  test('uploadCover yükü (yalnızca coverPath + updatedAt): yönetici iliştirir; başka kulübün yöneticisi iliştiremez', async () => {
    await seedFixture('base');
    const cover = { coverPath: payloads.eventCoverPath('e_public') };
    await assertFails(edit(cover, E_PUBLIC, 'otherManager'));
    await assertFails(edit(cover, E_PUBLIC, 'advisor'));
    await assertSucceeds(edit(cover));
    expect((await readDoc(E_PUBLIC)).coverPath).toBe(cover.coverPath);
  });
});

describe('events · durum makinesi (sözleşme §6.6: draft → published → cancelled; K-F)', () => {
  const PAST = { startsAt: fromNow(-HOUR_MS), endsAt: fromNow(HOUR_MS) };

  // Satır: [başlık, hedef, yük, beklenti, veri düzenlemesi?].
  test.each([
    ['yayın: başlangıcı geçmiş taslak', E_DRAFT, () => payloads.eventPublish(), 'deny', { patch: { [E_DRAFT]: PAST } }],
    ['yayın: publishedAt yok', E_DRAFT, () => ({ status: 'published', ...payloads.baseUpdate() }), 'deny'],
    ['yayın: publishedAt istemci saati', E_DRAFT, () => payloads.eventPublish({ publishedAt: at(-60 * 1000) }), 'deny'],
    ['yayın: aynı yazımda içerik (title)', E_DRAFT, () => payloads.eventPublish({ title: 'x' }), 'deny'],
    ['yayın: aynı yazımda sayaç', E_DRAFT, () => payloads.eventPublish({ goingCount: 5 }), 'deny'],
    ['yayın: silinmiş taslak', E_DRAFT, () => payloads.eventPublish(), 'deny', { patch: { [E_DRAFT]: { isDeleted: true, deletedBy: BOARD } } }],
    ['yayın: istemci biçimli taslak (publishedAt anahtarı yok — W-51)', E_DRAFT, () => payloads.eventPublish(), 'allow', { unset: { [E_DRAFT]: [...CLIENT_FORM, 'publishedAt'] } }],
    ['yayından çek: bekleyen var, kayıtlı yok (K-F harfiyen goingCount == 0)', E_PUBLIC, () => payloads.eventUnpublish(), 'allow', { patch: { [E_PUBLIC]: { goingCount: 0, waitlistCount: 1 } } }],
    ['yayından çek: 1 kayıtlı (K-F)', E_PUBLIC, () => payloads.eventUnpublish(), 'deny', { patch: { [E_PUBLIC]: { goingCount: 1 } } }],
    ['yayından çek: publishedAt silinir', 'events/e_members', () => payloads.eventUnpublish({ publishedAt: null }), 'deny'],
    ['yayından çek: aynı yazımda içerik', 'events/e_members', () => payloads.eventUnpublish({ title: 'x' }), 'deny'],
    ['iptal: neden tam sınırda (300)', E_PUBLIC, () => payloads.eventCancel('a'.repeat(300)), 'allow'],
    ['iptal: neden yok', E_PUBLIC, () => ({ status: 'cancelled', ...payloads.baseUpdate() }), 'deny'],
    ['iptal: boş neden', E_PUBLIC, () => payloads.eventCancel(''), 'deny'],
    ['iptal: yalnızca boşluktan oluşan neden', E_PUBLIC, () => payloads.eventCancel('  \n'), 'deny'],
    ['iptal: neden sınırın üstünde (301)', E_PUBLIC, () => payloads.eventCancel('a'.repeat(301)), 'deny'],
    ['iptal: aynı yazımda sayaç sıfırlama', E_PUBLIC, () => payloads.eventCancel('x', { goingCount: 0 }), 'deny'],
    ['iptal: istemci biçimli etkinlik (cancelReason anahtarı yok — W-51)', E_PUBLIC, () => payloads.eventCancel(), 'allow', { unset: { [E_PUBLIC]: CLIENT_FORM } }],
    ['soft delete: aynı yazımda başka alan (title)', E_DRAFT, () => ({ ...payloads.softDelete(BOARD), title: 'x' }), 'deny'],
    ['soft delete: deletedBy başkası', E_DRAFT, () => payloads.softDelete('u_president'), 'deny'],
    ['soft delete: yayından çekilmiş taslak (publishedAt dolu)', E_DRAFT, () => payloads.softDelete(BOARD), 'allow', { patch: { [E_DRAFT]: { publishedAt: fromNow(-DAY_MS) } } }],
  ])('%s → %s', async (_title, path, build, expected, seedEdit = NO_EDIT) => {
    const seeded = await seedFixture('base', undefined, seedEdit);
    await expectWrite(updateDoc(doc(db('board'), path), build()), expected);
    if (expected === 'deny') expect(await readDoc(path)).toMatchObject({ status: seeded[path].status, isDeleted: seeded[path].isDeleted });
  });

  test('yayın → yayından çek → yeniden yayın: publishedAt korunur ve yenilenir; iptal geri dönmez', async () => {
    await seedFixture('base');
    await assertSucceeds(commit('board', payloads.publishEventWrites({ club: CLUB, uid: BOARD })));
    const first = (await readDoc(E_DRAFT)).publishedAt;
    expect(first).not.toBeNull();

    await assertSucceeds(updateDoc(doc(db('board'), E_DRAFT), payloads.eventUnpublish()));
    expect(await readDoc(E_DRAFT)).toMatchObject({ status: 'draft', publishedAt: first });

    // Yeniden yayın günlüksüzdür (kimlik sabit; ilk yayının kaydı durur) — günlüklü deneme reddedilir.
    await assertFails(commit('board', payloads.publishEventWrites({ club: CLUB, uid: BOARD })));
    await assertFails(commit('president', payloads.publishEventWrites({ club: CLUB, uid: 'u_president' })));
    await assertSucceeds(commit('board', payloads.publishEventWrites({ club: CLUB, uid: BOARD, first: false })));

    await assertSucceeds(commit('president', payloads.cancelEventWrites({ club: CLUB, uid: 'u_president', eventId: 'e_draft' })));
    expect(await readDoc(E_DRAFT)).toMatchObject({ status: 'cancelled', cancelReason: payloads.CANCEL_REASON });
    for (const next of [payloads.eventPublish(), payloads.eventUnpublish(), payloads.eventEdit(), payloads.softDelete(BOARD)]) {
      await assertFails(updateDoc(doc(db('board'), E_DRAFT), next));
    }
  });
});

describe('activity · etkinlik türleri (rules-spec §3.11; sözleşme §6.2 günlük kuralı)', () => {
  const PUBLISHED = payloads.eventActivityPath(CLUB, BOARD, 'event_published', 'e_draft');
  const CANCELLED = payloads.eventActivityPath(CLUB, BOARD, 'event_cancelled', 'e_public');
  const publish = () => payloads.publishEventWrites({ club: CLUB, uid: BOARD });
  const cancel = () => payloads.cancelEventWrites({ club: CLUB, uid: BOARD });
  const log = (writes, extra, path) => ({ ...writes, activity: { op: 'set', path: path || writes.activity.path, data: { ...writes.activity.data, ...extra } } });

  test('yayın ve iptal günlüğü asıl yazımla aynı işlemde geçer; kimlik sabittir, refs yalnızca eventId', async () => {
    await seedFixture('base');
    await assertSucceeds(commit('board', publish()));
    await assertSucceeds(commit('board', cancel()));
    expect(await readDoc(PUBLISHED)).toMatchObject({ clubId: CLUB, actorId: BOARD, kind: 'event_published', refs: { eventId: 'e_draft' } });
    expect(Object.keys(await readDoc(CANCELLED)).sort()).toEqual(['actorId', 'clubId', 'createdAt', 'kind', 'refs']);
  });

  // Satır: [başlık, yazımlar]. Taban: yöneticinin `e_draft` yayını / `e_public` iptali.
  test.each([
    ['geçiş yok: tek başına event_published', () => ({ activity: publish().activity })],
    ['geçiş yok: tek başına event_cancelled', () => ({ activity: cancel().activity })],
    ['serbest kimlik', () => log(publish(), {}, 'activity/serbest_kimlik')],
    ['kimlikte başka aktör', () => log(publish(), {}, payloads.eventActivityPath(CLUB, 'u_president', 'event_published', 'e_draft'))],
    ['actorId başkası', () => log(publish(), { actorId: 'u_president' })],
    ['clubId etkinliğin kulübü değil', () => log(publish(), { clubId: OTHER_CLUB }, payloads.eventActivityPath(OTHER_CLUB, BOARD, 'event_published', 'e_draft'))],
    ['refs fazladan userId taşır', () => log(publish(), { refs: { eventId: 'e_draft', userId: BOARD } })],
    ['refs başka etkinliği gösterir', () => log(publish(), { refs: { eventId: 'e_public' } })],
    ['createdAt istemci saati', () => log(publish(), { createdAt: at(-60 * 1000) })],
    ['beyaz liste dışı alan', () => log(publish(), { note: 'x' })],
    ['yayın işleminde event_cancelled günlüğü', () => ({ event: publish().event, activity: { op: 'set', path: payloads.eventActivityPath(CLUB, BOARD, 'event_cancelled', 'e_draft'), data: payloads.eventActivity(CLUB, BOARD, 'event_cancelled', 'e_draft') } })],
    ['iptal işleminde event_published günlüğü', () => ({ event: cancel().event, activity: { op: 'set', path: payloads.eventActivityPath(CLUB, BOARD, 'event_published', 'e_public'), data: payloads.eventActivity(CLUB, BOARD, 'event_published', 'e_public') } })],
    ['içerik düzenlemesiyle event_published (yayın bu işlemde değil)', () => ({ event: { op: 'update', path: E_PUBLIC, data: payloads.eventEdit() }, activity: { op: 'set', path: payloads.eventActivityPath(CLUB, BOARD, 'event_published', 'e_public'), data: payloads.eventActivity(CLUB, BOARD, 'event_published', 'e_public') } })],
  ])('%s → deny', async (_title, build) => {
    await seedFixture('base');
    await assertFails(commit('board', build()));
    expect(await readDoc(PUBLISHED)).toBeNull();
    expect(await readDoc(E_DRAFT)).toMatchObject({ status: 'draft' });
    expect(await readDoc(E_PUBLIC)).toMatchObject({ status: 'published' });
  });

  test('günlük değiştirilemez: aynı kimliğe ikinci yazım reddedilir', async () => {
    await seedFixture('base');
    await assertSucceeds(commit('board', cancel()));
    await assertFails(setDoc(doc(db('board'), CANCELLED), payloads.eventActivity(CLUB, BOARD, 'event_cancelled', 'e_public')));
  });
});
