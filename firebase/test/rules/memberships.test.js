'use strict';
// T-15 — `memberships/{clubId}_{userId}` ve `memberships/{id}/private/contact` (rules-spec §3.4;
// domain-model §5; PLAN §11.1 satır 4–5, §11.2 M1–M4, M7, M8).
//
//  1. Rol × işlem matrisi: `expectations/memberships.json`, `expectations/private_contact.json`
//     (12 bağlam + alt varyantlar; `former` dört eski durumla; yönetici geçişleri M5–M10 kapalı).
//  2. Geçiş başına alan beyaz listesi, sunucu zamanı ve eşlik eden yazımlar: tablo testleri. Taban yük
//     repository'nin gönderdiği batch'tir (helpers/payloads.js `applyWrites` …); satır bir yazımı
//     değiştirir ya da çıkarır.
//  3. Başvuru notu ve e-posta (CD-137, D-29): üyelik belgesi `note` taşıyamaz; `requireNote` kulübünde
//     not aynı batch'teki `private/contact`'tan okunur; yeniden başvuruda not yeniden yazılır.
//  4. `retryAfter` (M4): bekleme süresi dolmadan yeniden başvuru reddedilir; başvuran süreyi kendisi
//     sıfırlayamaz.
//  5. Null alanın iki biçimi (W-51, CD-130): belge anahtarsız (istemci) ve açık `null` (seed) kurulur.
//  6. Yetki yükseltme: başvuran kendi başvurusunu onaylayamaz, üye rolünü değiştiremez.
//  7. Onay dolanması (CD-137 madde 8s): çıkarılan / reddedilen kullanıcı başvur (M4) → iptal (M7) →
//     anında katıl (M3) zinciriyle onaysız kulübe yönetici kararı olmadan giremez.
//  8. Yönetim okuması (CD-137 madde 8r): doğrulanmamış / alan adı dışı jetonlu yönetici başvuruları,
//     `private/contact` belgesini ve günlüğü okuyamaz (askıdaki yönetici matristedir).
//
//  9. Not düzenleme (T-16; `private/contact` U(b) `canEditNote()`): bekleyen başvurunun sahibi yalnızca
//     `note` + `updatedAt` yazar; üyelik önce ve sonra `pending`; `requireNote` kulübünde not boşaltılamaz.
//
// Sayaç eşliği (`memberCount ±1`, üyelik yolu oturumdan türetilir) `counters.test.js`, günlük `activity.test.js`,
// sorgu sözleşmesi ve indeksler `queries.test.js` dosyasındadır.
const path = require('node:path');
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { Timestamp, collection, deleteField, doc, getDoc, getDocs, query, serverTimestamp, updateDoc, where } = require('firebase/firestore');
const { getTestEnv } = require('../setup/env');
const budget = require('../helpers/budget');
const { contextFor, CLUB } = require('../helpers/contexts');
const { readDoc, seedFixture } = require('../helpers/fixtures');
const { runMatrix } = require('../helpers/matrix');
const payloads = require('../helpers/payloads');

const REPO_ROOT = path.resolve(__dirname, '..', '..', '..');
const limits = require(path.join(REPO_ROOT, 'tool', 'lib', 'dart_sources.js')).readLimits(REPO_ROOT).ints;

const MINUTE_MS = 60 * 1000;
const DAY_MS = 24 * 60 * MINUTE_MS;

const STUDENT = 'u_student';
const FORMER = 'u_former';
const PENDING = 'u_pending';
const MEMBER = 'u_member';
const CLUB_PATH = `clubs/${CLUB}`;
const M_STUDENT = payloads.membershipPath(CLUB, STUDENT);
const M_FORMER = payloads.membershipPath(CLUB, FORMER);
const M_PENDING = payloads.membershipPath(CLUB, PENDING);
const M_MEMBER = payloads.membershipPath(CLUB, MEMBER);
const C_STUDENT = payloads.contactPath(CLUB, STUDENT);
const C_FORMER = payloads.contactPath(CLUB, FORMER);
const C_PENDING = payloads.contactPath(CLUB, PENDING);
const C_MEMBER = payloads.contactPath(CLUB, MEMBER);
const DECISION_KEYS = Object.keys(payloads.DECISION_NULLS);

const dbOf = (role) => contextFor(role).firestore();
/** İstemci saatinden üretilmiş zaman damgası (`request.time` ile eşleşmez). */
const clientTime = () => Timestamp.fromMillis(Date.now() - MINUTE_MS);
const fromNow = (ms) => Timestamp.fromMillis(Date.now() + ms);
const text = (length) => 'a'.repeat(length);
const expectWrite = (request, expected) => (expected === 'allow' ? assertSucceeds(request) : assertFails(request));
const commit = (role, writes) => budget.buildBatch(dbOf(role), Object.values(writes)).commit();
/** Bir yazımın yüküne alan ekler / ezer. */
const withData = (write, extra) => ({ ...write, data: { ...write.data, ...extra } });
/** Bir yazımın yükünden anahtar çıkarır. */
const withoutKeys = (write, keys) => ({
  ...write,
  data: Object.fromEntries(Object.entries(write.data).filter(([key]) => !keys.includes(key))),
});
/** Batch'ten adlı yazımı çıkarır. */
const drop = (writes, name) => Object.fromEntries(Object.entries(writes).filter(([key]) => key !== name));
const NO_EDIT = Object.freeze({});
const INSTANT = { patch: { [CLUB_PATH]: { approvalRequired: false } } };
const REQUIRE_NOTE = { patch: { [CLUB_PATH]: { requireNote: true } } };

const studentApply = (options) =>
  payloads.applyWrites({ club: CLUB, uid: STUDENT, email: payloads.emailOf('student'), ...options });
const studentJoin = () => payloads.joinWrites({ club: CLUB, uid: STUDENT, email: payloads.emailOf('student') });
const formerReapply = (options) => payloads.reapplyWrites({ club: CLUB, uid: FORMER, ...options });

runMatrix('memberships.json');
runMatrix('private_contact.json');

// ── M1 · create pending (Başvur) ─────────────────────────────────────────────────────────────

describe('M1 apply creates pending — alan beyaz listesi, eşlik eden contact, kulüp koşulları', () => {
  test('taban batch: üyelik `pending` (not ve e-posta TAŞIMAZ), contact e-posta + not, günlük kaydı', async () => {
    await seedFixture('base');
    await assertSucceeds(commit('student', studentApply()));

    const membership = await readDoc(M_STUDENT);
    expect(membership).toMatchObject({ clubId: CLUB, userId: STUDENT, status: 'pending', role: 'member', priorCount: 0 });
    expect(membership.appliedAt.toMillis()).toBe(membership.createdAt.toMillis());
    for (const key of ['note', 'email', 'emailLower']) expect(membership).not.toHaveProperty(key);
    expect(await readDoc(C_STUDENT)).toMatchObject({ email: payloads.emailOf('student'), note: payloads.APPLICATION_NOTE });
    // Sayaç değişmez: başvuru üye sayısına girmez.
    expect((await readDoc(CLUB_PATH)).memberCount).toBe(5);
  });

  // Satır: [başlık, yazımları değiştiren işlev, beklenti, veri düzenlemesi?].
  const m = (extra) => (w) => ({ ...w, membership: withData(w.membership, extra) });
  const c = (extra) => (w) => ({ ...w, contact: withData(w.contact, extra) });
  test.each([
    ['üyelik belgesinde `note` anahtarı (CD-137)', m({ note: 'Not.' }), 'deny'],
    ['üyelik belgesinde `email` (D-29)', m({ email: payloads.emailOf('student') }), 'deny'],
    ['açık null karar alanları (seed biçimi — W-51)', m(payloads.DECISION_NULLS), 'allow'],
    ['status: active (onaylı kulüpte kendini üye yapma)', m({ status: 'active' }), 'deny'],
    ['status: rejected', m({ status: 'rejected' }), 'deny'],
    ['role: board', m({ role: 'board' }), 'deny'],
    ['role: president', m({ role: 'president' }), 'deny'],
    ['role: advisor', m({ role: 'advisor' }), 'deny'],
    ['priorCount: 1', m({ priorCount: 1 }), 'deny'],
    ['appliedAt istemci saati', m({ appliedAt: clientTime() }), 'deny'],
    ['createdAt istemci saati', m({ createdAt: clientTime() }), 'deny'],
    ['updatedAt istemci saati', m({ updatedAt: clientTime() }), 'deny'],
    ['isDeleted: true', m({ isDeleted: true }), 'deny'],
    ['decidedBy dolu', m({ decidedBy: STUDENT }), 'deny'],
    ['decidedAt dolu', m({ decidedAt: serverTimestamp() }), 'deny'],
    ['retryAfter dolu', m({ retryAfter: fromNow(DAY_MS) }), 'deny'],
    ['rejectReason dolu', m({ rejectReason: 'other' }), 'deny'],
    ['applicant.name kullanıcı belgesindeki ad değil', m({ applicant: { ...payloads.applicantOf(STUDENT), name: 'Başka Ad' } }), 'deny'],
    ['applicant.department kullanıcı belgesiyle farklı', m({ applicant: { ...payloads.applicantOf(STUDENT), department: 'd02' } }), 'deny'],
    ['applicant.year kullanıcı belgesiyle farklı', m({ applicant: { ...payloads.applicantOf(STUDENT), year: 'phd' } }), 'deny'],
    ['applicant.avatarSeed kullanıcı belgesiyle farklı', m({ applicant: { ...payloads.applicantOf(STUDENT), avatarSeed: 'x' } }), 'deny'],
    ['applicant fazladan anahtar (email)', m({ applicant: { ...payloads.applicantOf(STUDENT), email: 'x@y.z' } }), 'deny'],
    ['applicant map değil', m({ applicant: 'Test u_student' }), 'deny'],
    ['beyaz liste dışı alan', m({ staff: true }), 'deny'],
    ['contact yazımı yok', (w) => drop(w, 'contact'), 'deny'],
    ['günlük (activity) yazımı yok — isteğe bağlı', (w) => drop(w, 'activity'), 'allow'],
    ['contact.email token e-postası değil', c({ email: 'baska@ogr.gumushane.edu.tr', emailLower: 'baska@ogr.gumushane.edu.tr' }), 'deny'],
    ['contact.emailLower token e-postasının küçük harflisi değil', c({ emailLower: 'x@ogr.gumushane.edu.tr' }), 'deny'],
    ['contact.note applicationNoteMax', c({ note: text(limits.applicationNoteMax) }), 'allow'],
    ['contact.note applicationNoteMax + 1', c({ note: text(limits.applicationNoteMax + 1) }), 'deny'],
    ['contact.note dizgi değil', c({ note: 42 }), 'deny'],
    ['contact.note anahtarı yok', (w) => ({ ...w, contact: withoutKeys(w.contact, ['note']) }), 'deny'],
    ['contact beyaz liste dışı alan (phone)', c({ phone: '+90' }), 'deny'],
    ['contact createdAt istemci saati', c({ createdAt: clientTime() }), 'deny'],
    ['not boş, kulüp not istemiyor', c({ note: '' }), 'allow'],
    ['not boş, kulüp not istiyor (requireNote)', c({ note: '' }), 'deny', REQUIRE_NOTE],
    ['not yalnızca boşluk, kulüp not istiyor (requireNote)', c({ note: ' ' }), 'deny', REQUIRE_NOTE],
    ['not yalnızca satır sonu / sekme, kulüp not istiyor (requireNote)', c({ note: '\n\t \n' }), 'deny', REQUIRE_NOTE],
    ['not yalnızca boşluk, kulüp not istemiyor', c({ note: ' ' }), 'allow'],
    ['not dolu, kulüp not istiyor (requireNote)', c({ note: 'Katılmak istiyorum.' }), 'allow', REQUIRE_NOTE],
    ['kulüp başvurulara kapalı (applicationsOpen: false)', (w) => w, 'deny', { patch: { [CLUB_PATH]: { applicationsOpen: false } } }],
    ['kulüp askıda', (w) => w, 'deny', { patch: { [CLUB_PATH]: { status: 'suspended' } } }],
    ['kulüp silinmiş', (w) => w, 'deny', { patch: { [CLUB_PATH]: { isDeleted: true } } }],
    ['başvuranın profili tamamlanmamış (activeUser)', (w) => w, 'deny', { patch: { [`users/${STUDENT}`]: { profileComplete: false } } }],
  ])('%s', async (_title, mutate, expected, edit = NO_EDIT) => {
    await seedFixture('base', undefined, edit);
    await expectWrite(commit('student', mutate(studentApply())), expected);
    if (expected === 'deny') {
      expect(await readDoc(M_STUDENT)).toBeNull();
      expect(await readDoc(C_STUDENT)).toBeNull();
    }
  });

  test('başkası adına başvuru (userId ≠ oturum) ve kimliği alanlarıyla uyuşmayan belge reddedilir', async () => {
    await seedFixture('base');
    const asMember = payloads.applyWrites({ club: CLUB, uid: 'u_nobody', email: payloads.emailOf('member') });
    await assertFails(commit('member', asMember));

    // Belge yolu c02 üyeliği, alanlar c01: `membershipId == clubId_userId` tutmaz.
    const mismatched = studentApply();
    mismatched.membership = { ...mismatched.membership, path: payloads.membershipPath('c02', STUDENT) };
    mismatched.contact = { ...mismatched.contact, path: payloads.contactPath('c02', STUDENT) };
    await assertFails(commit('student', mismatched));

    const noClub = payloads.applyWrites({ club: 'c_missing', uid: STUDENT, email: payloads.emailOf('student') });
    await assertFails(commit('student', noClub));
    expect(await readDoc(payloads.membershipPath('c_missing', STUDENT))).toBeNull();
  });
});

// ── M2 · create active (anında katıl) ────────────────────────────────────────────────────────

describe('M2 join instant — onaysız kulüp', () => {
  test('taban batch: üyelik `active`, karar alanı yok, contact notu boş', async () => {
    await seedFixture('base', undefined, INSTANT);
    await assertSucceeds(commit('student', studentJoin()));

    const membership = await readDoc(M_STUDENT);
    expect(membership).toMatchObject({ status: 'active', role: 'member', priorCount: 0 });
    for (const key of [...DECISION_KEYS, 'note']) expect(membership).not.toHaveProperty(key);
    expect(await readDoc(C_STUDENT)).toMatchObject({ email: payloads.emailOf('student'), note: '' });
  });

  test.each([
    ['decidedAt dolu (karar yoktur)', (w) => ({ ...w, membership: withData(w.membership, { decidedAt: serverTimestamp() }) })],
    ['role: board', (w) => ({ ...w, membership: withData(w.membership, { role: 'board' }) })],
    ['contact yazımı yok (yönetim e-postayı okuyamaz)', (w) => drop(w, 'contact')],
    ['kulüp başvurulara kapalı', (w) => w, { patch: { [CLUB_PATH]: { approvalRequired: false, applicationsOpen: false } } }],
  ])('%s → deny', async (_title, mutate, edit = INSTANT) => {
    await seedFixture('base', undefined, edit);
    await assertFails(commit('student', mutate(studentJoin())));
    expect(await readDoc(M_STUDENT)).toBeNull();
    expect((await readDoc(CLUB_PATH)).memberCount).toBe(5);
  });
});

// ── M3 · left / cancelled → pending | active ─────────────────────────────────────────────────

describe('M3 reapply after left — alan beyaz listesi, priorCount, not yeniden yazılır', () => {
  /** İstemci biçimli eski üyelik: null karar alanlarının anahtarı yok (W-51). */
  const CLIENT_FORM = { unset: { [M_FORMER]: DECISION_KEYS } };
  const m = (extra) => (w) => ({ ...w, membership: withData(w.membership, extra) });

  test('M3 reapply rewrites note in contact: üyelik `pending`, priorCount +1, contact notu yeni, e-posta aynı', async () => {
    const docs = await seedFixture('base', undefined, { patch: { [C_FORMER]: { note: 'Eski başvurunun notu.' } } });
    await assertSucceeds(commit('former', formerReapply({ note: 'Yeni not.' })));

    const membership = await readDoc(M_FORMER);
    expect(membership).toMatchObject({ status: 'pending', role: 'member', priorCount: 1, ...payloads.DECISION_NULLS });
    expect(membership.createdAt.toMillis()).toBeLessThan(membership.updatedAt.toMillis());
    expect(membership).not.toHaveProperty('note');
    expect(await readDoc(C_FORMER)).toMatchObject({ note: 'Yeni not.', email: docs[C_FORMER].email });
  });

  test.each([
    ['istemci biçimli belge (karar anahtarları yok) + açık null yazan yük (W-51)', (w) => w, 'allow', CLIENT_FORM],
    ['istemci biçimli belge + karar alanlarına hiç dokunmayan yük (W-51)', (w) => ({ ...w, membership: withoutKeys(w.membership, DECISION_KEYS) }), 'allow', CLIENT_FORM],
    ['karar alanları dolu belgede yük onları temizlemiyor', (w) => ({ ...w, membership: withoutKeys(w.membership, DECISION_KEYS) }), 'deny'],
    ['priorCount değişmiyor', m({ priorCount: 0 }), 'deny'],
    ['priorCount +2', m({ priorCount: 2 }), 'deny'],
    ['role: board (eski rolünü geri alma)', m({ role: 'board' }), 'deny'],
    ['appliedAt istemci saati', m({ appliedAt: clientTime() }), 'deny'],
    ['updatedAt istemci saati', m({ updatedAt: clientTime() }), 'deny'],
    ['`note` anahtarı üyelik belgesinde (CD-137)', m({ note: 'Not.' }), 'deny'],
    ['clubId değişiyor', m({ clubId: 'c02' }), 'deny'],
    ['userId değişiyor', m({ userId: MEMBER }), 'deny'],
    ['createdAt değişiyor', m({ createdAt: serverTimestamp() }), 'deny'],
    ['applicant.name kullanıcı belgesindeki ad değil', m({ applicant: { ...payloads.applicantOf(FORMER), name: 'Başka Ad' } }), 'deny'],
    ['contact yeniden yazılmıyor (eski not yeni başvuruya taşınmaz)', (w) => drop(w, 'contact'), 'deny'],
    ['contact güncellemesi e-postayı değiştiriyor', (w) => ({ ...w, contact: withData(w.contact, { email: 'x@ogr.gumushane.edu.tr' }) }), 'deny'],
    ['contact.note applicationNoteMax + 1', (w) => ({ ...w, contact: withData(w.contact, { note: text(limits.applicationNoteMax + 1) }) }), 'deny'],
    ['not boş, kulüp not istiyor (requireNote)', (w) => ({ ...w, contact: withData(w.contact, { note: '' }) }), 'deny', REQUIRE_NOTE],
    ['not yalnızca boşluk, kulüp not istiyor (requireNote)', (w) => ({ ...w, contact: withData(w.contact, { note: ' ' }) }), 'deny', REQUIRE_NOTE],
    ['not dolu, kulüp not istiyor (requireNote)', (w) => w, 'allow', REQUIRE_NOTE],
    ['kulüp başvurulara kapalı', (w) => w, 'deny', { patch: { [CLUB_PATH]: { applicationsOpen: false } } }],
  ])('%s', async (_title, mutate, expected, edit = NO_EDIT) => {
    await seedFixture('base', undefined, edit);
    const before = await readDoc(M_FORMER);
    await expectWrite(commit('former', mutate(formerReapply())), expected);
    if (expected === 'deny') expect(await readDoc(M_FORMER)).toEqual(before);
  });

  test('contact belgesi olmayan eski üyelikte (yönetici eliyle açılmış) contact aynı batch\'te oluşturulur', async () => {
    await seedFixture('base', undefined, { without: [C_FORMER] });
    const writes = formerReapply();
    writes.contact = { op: 'set', path: C_FORMER, data: payloads.contactCreate(payloads.emailOf('former'), 'İlk not.') };
    await assertSucceeds(commit('former', writes));
    expect(await readDoc(C_FORMER)).toMatchObject({ email: payloads.emailOf('former'), note: 'İlk not.' });
  });

  test('başkası eski üyenin belgesiyle yeniden başvuramaz', async () => {
    await seedFixture('base');
    const before = await readDoc(M_FORMER);
    await assertFails(commit('member', formerReapply()));
    await assertFails(commit('board', formerReapply()));
    expect(await readDoc(M_FORMER)).toEqual(before);
  });
});

// ── M4 · rejected / removed → pending (bekleme süresi) ───────────────────────────────────────

describe('M4 reapply after cooldown — retryAfter', () => {
  const rejected = (fields, extra = {}) => ({
    patch: { [M_FORMER]: { status: 'rejected', rejectReason: 'quota', rejectNote: 'Kontenjan doldu.', ...fields } },
    ...extra,
  });
  const removed = (fields) => ({ patch: { [M_FORMER]: { status: 'removed', rejectReason: 'other', ...fields } } });

  // Satır: [başlık, eski durum, veri düzenlemesi üreticisi (zaman test anında hesaplanır), beklenti].
  test.each([
    ['retryAfter geçmişte (1 dk önce)', 'rejected', () => rejected({ retryAfter: fromNow(-MINUTE_MS) }), 'allow'],
    ['retryAfter anahtarı yok (istemci biçimi — W-51)', 'rejected', () => rejected({}, { unset: { [M_FORMER]: ['retryAfter'] } }), 'allow'],
    ['M4 rejects inside cooldown: retryAfter 1 gün sonra', 'rejected', () => rejected({ retryAfter: fromNow(DAY_MS) }), 'deny'],
    ['M4 rejects inside cooldown: retryAfter 5 dk sonra', 'rejected', () => rejected({ retryAfter: fromNow(5 * MINUTE_MS) }), 'deny'],
    ['çıkarılmış üye (removed), retryAfter gelecekte', 'removed', () => removed({ retryAfter: fromNow(DAY_MS) }), 'deny'],
    ['çıkarılmış üye (removed), retryAfter geçmişte', 'removed', () => removed({ retryAfter: fromNow(-DAY_MS) }), 'allow'],
  ])('%s', async (_title, from, edit, expected) => {
    await seedFixture('base', undefined, edit());
    await expectWrite(commit('former', formerReapply()), expected);
    const after = await readDoc(M_FORMER);
    if (expected === 'allow') expect(after).toMatchObject({ status: 'pending', priorCount: 1, ...payloads.DECISION_NULLS });
    else expect(after.status).toBe(from);
  });

  // `noteGiven` kırpılmış metni ölçer (CD-138 madde 3): bekleme dolmuş olsa da boş / yalnızca boşluk not geçmez.
  test.each([
    ['not boş', '', 'deny'],
    ['not yalnızca boşluk', ' ', 'deny'],
    ['not yalnızca satır sonu', '\n\n', 'deny'],
    ['not dolu', 'Yeniden başvuruyorum.', 'allow'],
  ])('bekleme dolmuş, kulüp not istiyor (requireNote): %s', async (_title, value, expected) => {
    await seedFixture('base', undefined, {
      patch: { ...rejected({ retryAfter: fromNow(-MINUTE_MS) }).patch, ...REQUIRE_NOTE.patch },
    });
    await expectWrite(commit('former', formerReapply({ note: value })), expected);
    expect((await readDoc(M_FORMER)).status).toBe(expected === 'allow' ? 'pending' : 'rejected');
  });

  test('başvuran bekleme süresini kendisi sıfırlayamaz (retryAfter / status tek başına yazılamaz)', async () => {
    await seedFixture('base', undefined, rejected({ retryAfter: fromNow(DAY_MS) }));
    const ref = doc(dbOf('former'), M_FORMER);
    const before = await readDoc(M_FORMER);

    await assertFails(updateDoc(ref, { retryAfter: null, ...payloads.baseUpdate() }));
    await assertFails(updateDoc(ref, { retryAfter: deleteField(), ...payloads.baseUpdate() }));
    await assertFails(updateDoc(ref, { retryAfter: fromNow(-DAY_MS), ...payloads.baseUpdate() }));
    // `rejected → cancelled / left` yolu yoktur: M3 üzerinden bekleme atlanamaz.
    await assertFails(updateDoc(ref, { status: 'cancelled', ...payloads.baseUpdate() }));
    await assertFails(updateDoc(ref, { status: 'left', ...payloads.baseUpdate() }));

    expect(await readDoc(M_FORMER)).toEqual(before);
  });
});

// ── M4 → M7 → M3 · yönetici onayının dolanması (CD-137 madde 8s) ─────────────────────────────

describe('M4 → M7 → M3 — iptal edilen başvuru anında katılıma dönüşemez', () => {
  const cancel = () => ({ m: { op: 'update', path: M_FORMER, data: { status: 'cancelled', ...payloads.baseUpdate() } } });

  test.each([['removed'], ['rejected']])(
    'onaysız kulüpte %s → başvur → iptal → anında katıl reddedilir; yeniden başvuru yönetici onayına gider',
    async (from) => {
      await seedFixture('base', undefined, {
        patch: { [CLUB_PATH]: { approvalRequired: false }, [M_FORMER]: { status: from, rejectReason: 'other', retryAfter: fromNow(-DAY_MS) } },
      });
      // M4: bekleme dolmuş → `pending` (onaysız kulüpte de yönetici onayı).
      await assertSucceeds(commit('former', formerReapply({ priorCount: 1 })));
      // M7: başvuran isteğini geri çeker.
      await assertSucceeds(commit('former', cancel()));
      // M3 `active`: reddedilir — `cancelled` yalnızca `pending`'e gider.
      await assertFails(commit('former', formerReapply({ status: 'active', priorCount: 2 })));

      expect(await readDoc(M_FORMER)).toMatchObject({ status: 'cancelled', priorCount: 1 });
      expect((await readDoc(CLUB_PATH)).memberCount).toBe(5);

      await assertSucceeds(commit('former', formerReapply({ priorCount: 2 })));
      expect(await readDoc(M_FORMER)).toMatchObject({ status: 'pending', priorCount: 2 });
      expect((await readDoc(CLUB_PATH)).memberCount).toBe(5);
    },
  );
});

// ── Yönetim okuması · doğrulanmamış / alan adı dışı jeton (CD-137 madde 8r) ──────────────────

describe('yönetim okuması — emailOk() olmayan yönetici jetonu (üyeliği active)', () => {
  const BOARD = 'u_board';
  const pendingQuery = (db) => query(collection(db, 'memberships'), where('clubId', '==', CLUB), where('status', '==', 'pending'));
  const activeQuery = (db) => query(collection(db, 'memberships'), where('clubId', '==', CLUB), where('status', '==', 'active'));
  const activityQuery = (db) => query(collection(db, 'activity'), where('clubId', '==', CLUB));

  test.each([
    ['e-posta doğrulanmamış', { email: payloads.emailOf('board'), email_verified: false }],
    ['alan adı dışı (hotmail.com)', { email: 'board@hotmail.com', email_verified: true }],
  ])('%s: başvurular, private/contact, üye listesi ve günlük okunamaz', async (_title, token) => {
    await seedFixture('base');
    const db = getTestEnv().authenticatedContext(BOARD, token).firestore();

    await assertFails(getDoc(doc(db, M_PENDING)));
    await assertFails(getDocs(pendingQuery(db)));
    await assertFails(getDoc(doc(db, payloads.contactPath(CLUB, PENDING))));
    await assertFails(getDoc(doc(db, M_MEMBER)));
    await assertFails(getDocs(activeQuery(db)));
    await assertFails(getDoc(doc(db, 'activity/a01')));
    await assertFails(getDocs(activityQuery(db)));
  });

  test('aynı yönetici doğrulanmış jetonla hepsini okur (ret jetondan gelir)', async () => {
    await seedFixture('base');
    const db = dbOf('board');

    await assertSucceeds(getDoc(doc(db, M_PENDING)));
    await assertSucceeds(getDocs(pendingQuery(db)));
    await assertSucceeds(getDoc(doc(db, payloads.contactPath(CLUB, PENDING))));
    await assertSucceeds(getDocs(activeQuery(db)));
    await assertSucceeds(getDocs(activityQuery(db)));
  });
});

// ── M7 · pending → cancelled ─────────────────────────────────────────────────────────────────

describe('M7 cancel own application — yalnızca status', () => {
  const touch = (fields) => ({ ...fields, ...payloads.baseUpdate() });

  test.each([
    ['istemci biçimli belge (karar anahtarları yok — W-51)', touch({ status: 'cancelled' }), 'allow', { unset: { [M_PENDING]: DECISION_KEYS } }],
    ['updatedAt yok', { status: 'cancelled' }, 'deny'],
    ['updatedAt istemci saati', { status: 'cancelled', updatedAt: clientTime() }, 'deny'],
    ['status ile birlikte role', touch({ status: 'cancelled', role: 'board' }), 'deny'],
    ['status ile birlikte `note` (CD-137: not bu belgede değil)', touch({ status: 'cancelled', note: 'x' }), 'deny'],
    ['status ile birlikte priorCount', touch({ status: 'cancelled', priorCount: 5 }), 'deny'],
    ['pending → active (kendi başvurusunu onaylama)', touch({ status: 'active' }), 'deny'],
    ['pending → active + karar alanları (onay taklidi)', touch({ status: 'active', role: 'member', decidedAt: serverTimestamp(), decidedBy: PENDING }), 'deny'],
    ['pending → left', touch({ status: 'left' }), 'deny'],
    ['pending → rejected', touch({ status: 'rejected' }), 'deny'],
    ['pending → removed', touch({ status: 'removed' }), 'deny'],
    ['yalnızca role (durum değişmeden)', touch({ role: 'president' }), 'deny'],
  ])('%s', async (_title, payload, expected, edit = NO_EDIT) => {
    await seedFixture('base', undefined, edit);
    const before = await readDoc(M_PENDING);
    await expectWrite(updateDoc(doc(dbOf('pending'), M_PENDING), payload), expected);
    const after = await readDoc(M_PENDING);
    if (expected === 'deny') expect(after).toEqual(before);
    else expect(after).toMatchObject({ status: 'cancelled', role: before.role, priorCount: before.priorCount });
  });

  test('bekleyen başvuran kendini sayaçla birlikte üye yapamaz (onay M5 yalnızca yöneticidedir — T-30)', async () => {
    await seedFixture('base');
    const writes = {
      membership: { op: 'update', path: M_PENDING, data: { status: 'active', role: 'member', ...payloads.baseUpdate() } },
      club: { op: 'update', path: CLUB_PATH, data: payloads.memberCountBump(1) },
    };
    await assertFails(commit('pending', writes));
    expect((await readDoc(M_PENDING)).status).toBe('pending');
    expect((await readDoc(CLUB_PATH)).memberCount).toBe(5);
  });
});

// ── M7 · not düzenleme (private/contact U(b)) — T-16 ─────────────────────────────────────────

describe('M7 edit note while pending — private/contact U(b): yalnızca note, üyelik pending kalır', () => {
  const note = (value, extra) => ({ note: value, ...payloads.baseUpdate(), ...extra });
  const OTHER_EMAIL = { email: 'baska@ogr.gumushane.edu.tr', emailLower: 'baska@ogr.gumushane.edu.tr' };

  test('taban yazım: not değişir; e-posta, üyelik belgesi ve sayaç aynı kalır', async () => {
    const docs = await seedFixture('base');
    const membership = await readDoc(M_PENDING);
    await assertSucceeds(updateDoc(doc(dbOf('pending'), C_PENDING), note('Güncel not.')));

    const contact = await readDoc(C_PENDING);
    expect(contact).toMatchObject({ note: 'Güncel not.', email: docs[C_PENDING].email, emailLower: docs[C_PENDING].emailLower });
    expect(contact.createdAt.toMillis()).toBeLessThan(contact.updatedAt.toMillis());
    expect(await readDoc(M_PENDING)).toEqual(membership);
    expect((await readDoc(CLUB_PATH)).memberCount).toBe(5);
  });

  // Satır: [başlık, yük üreticisi (zaman test anında hesaplanır), beklenti, veri düzenlemesi?].
  test.each([
    ['not applicationNoteMax', () => note(text(limits.applicationNoteMax)), 'allow'],
    ['not applicationNoteMax + 1', () => note(text(limits.applicationNoteMax + 1)), 'deny'],
    ['not boş, kulüp not istemiyor', () => note(''), 'allow'],
    ['not boş, kulüp not istiyor (requireNote)', () => note(''), 'deny', REQUIRE_NOTE],
    ['not yalnızca boşluk, kulüp not istiyor (requireNote)', () => note(' '), 'deny', REQUIRE_NOTE],
    ['not yalnızca satır sonu, kulüp not istiyor (requireNote)', () => note('\n\n'), 'deny', REQUIRE_NOTE],
    ['not yalnızca sekme / boşluk, kulüp not istiyor (requireNote)', () => note('\t  \t'), 'deny', REQUIRE_NOTE],
    ['not yalnızca boşluk, kulüp not istemiyor', () => note(' '), 'allow'],
    ['not baştan / sondan boşluklu ama dolu, kulüp not istiyor (requireNote)', () => note('  Katılmak istiyorum.  '), 'allow', REQUIRE_NOTE],
    ['not dolu, kulüp not istiyor (requireNote)', () => note('Katılmak istiyorum.'), 'allow', REQUIRE_NOTE],
    ['not dizgi değil', () => note(42), 'deny'],
    ['not null', () => note(null), 'deny'],
    ['not anahtarı kaldırılıyor', () => note(deleteField()), 'deny'],
    ['updatedAt yok', () => ({ note: 'Güncel not.' }), 'deny'],
    ['updatedAt istemci saati', () => note('Güncel not.', { updatedAt: clientTime() }), 'deny'],
    ['not ile birlikte e-posta', () => note('Güncel not.', OTHER_EMAIL), 'deny'],
    ['yalnızca e-posta', () => ({ ...OTHER_EMAIL, ...payloads.baseUpdate() }), 'deny'],
    ['beyaz liste dışı alan (phone)', () => note('Güncel not.', { phone: '+90' }), 'deny'],
    ['not ile birlikte isDeleted (silme taklidi)', () => note('Güncel not.', { isDeleted: true }), 'deny'],
    ['not ile birlikte createdAt', () => note('Güncel not.', { createdAt: serverTimestamp() }), 'deny'],
    ['başvuru onaylanmış (active)', () => note('Güncel not.'), 'deny', { patch: { [M_PENDING]: { status: 'active' } } }],
    ['başvuru iptal edilmiş (cancelled)', () => note('Güncel not.'), 'deny', { patch: { [M_PENDING]: { status: 'cancelled' } } }],
    ['başvuru reddedilmiş (rejected)', () => note('Güncel not.'), 'deny', { patch: { [M_PENDING]: { status: 'rejected' } } }],
    ['üyelikten çıkarılmış (removed)', () => note('Güncel not.'), 'deny', { patch: { [M_PENDING]: { status: 'removed' } } }],
    ['ayrılmış (left)', () => note('Güncel not.'), 'deny', { patch: { [M_PENDING]: { status: 'left' } } }],
    ['başvuranın hesabı askıda (activeUser)', () => note('Güncel not.'), 'deny', { patch: { [`users/${PENDING}`]: { status: 'suspended' } } }],
    ['başvuranın profili tamamlanmamış (activeUser)', () => note('Güncel not.'), 'deny', { patch: { [`users/${PENDING}`]: { profileComplete: false } } }],
    // Not düzenleme yeni başvuru değildir: kulüp başvuruya kapansa da bekleyen başvurunun notu düzenlenir.
    ['kulüp başvurulara kapalı', () => note('Güncel not.'), 'allow', { patch: { [CLUB_PATH]: { applicationsOpen: false } } }],
    ['kulüp askıda', () => note('Güncel not.'), 'allow', { patch: { [CLUB_PATH]: { status: 'suspended' } } }],
  ])('%s', async (_title, payload, expected, edit = NO_EDIT) => {
    await seedFixture('base', undefined, edit);
    const before = await readDoc(C_PENDING);
    await expectWrite(updateDoc(doc(dbOf('pending'), C_PENDING), payload()), expected);
    if (expected === 'deny') expect(await readDoc(C_PENDING)).toEqual(before);
    else expect((await readDoc(C_PENDING)).email).toBe(before.email);
  });

  test('aktif üye kendi notunu düzenleyemez (başvuru bitmiştir)', async () => {
    await seedFixture('base');
    const before = await readDoc(C_MEMBER);
    await assertFails(updateDoc(doc(dbOf('member'), C_MEMBER), note('Güncel not.')));
    expect(await readDoc(C_MEMBER)).toEqual(before);
  });

  test('doğrulanmamış / alan adı dışı jetonla sahibi notunu düzenleyemez', async () => {
    await seedFixture('base');
    const before = await readDoc(C_PENDING);
    for (const token of [
      { email: payloads.emailOf('pending'), email_verified: false },
      { email: 'pending@hotmail.com', email_verified: true },
    ]) {
      const db = getTestEnv().authenticatedContext(PENDING, token).firestore();
      await assertFails(updateDoc(doc(db, C_PENDING), note('Güncel not.')));
    }
    expect(await readDoc(C_PENDING)).toEqual(before);
  });

  test('aynı batch\'te iptal (M7) + not: yazım-sonrası üyelik pending değildir → ikisi de reddedilir', async () => {
    await seedFixture('base');
    const before = [await readDoc(M_PENDING), await readDoc(C_PENDING)];
    const writes = {
      membership: { op: 'update', path: M_PENDING, data: { status: 'cancelled', ...payloads.baseUpdate() } },
      contact: { op: 'update', path: C_PENDING, data: note('Son söz.') },
    };
    await assertFails(commit('pending', writes));
    expect([await readDoc(M_PENDING), await readDoc(C_PENDING)]).toEqual(before);
  });

  test('yönetim başvuranın notunu okur ama yazamaz; not üyelik belgesine yazılamaz', async () => {
    await seedFixture('base');
    const before = await readDoc(C_PENDING);
    for (const role of ['board', 'president', 'advisor', 'super']) {
      await assertSucceeds(getDoc(doc(dbOf(role), C_PENDING)));
      await assertFails(updateDoc(doc(dbOf(role), C_PENDING), note('Yönetici notu.')));
    }
    expect(await readDoc(C_PENDING)).toEqual(before);

    // CD-137: `note` üyelik belgesinin alanı değildir (M7 yalnızca `status` yazar).
    const membership = await readDoc(M_PENDING);
    await assertFails(updateDoc(doc(dbOf('pending'), M_PENDING), note('Güncel not.')));
    expect(await readDoc(M_PENDING)).toEqual(membership);
  });
});

// ── M8 · active → left ───────────────────────────────────────────────────────────────────────

describe('M8 leave — yalnızca status; rol ve durum yükseltme yok', () => {
  const leave = (extra) => {
    const writes = payloads.leaveWrites({ club: CLUB, uid: MEMBER });
    return { ...writes, membership: withData(writes.membership, extra) };
  };

  test.each([
    ['istemci biçimli belge (karar anahtarları yok — W-51)', leave({}), 'allow', { unset: { [M_MEMBER]: DECISION_KEYS } }],
    ['status ile birlikte role', leave({ role: 'board' }), 'deny'],
    ['status ile birlikte applicant', leave({ applicant: { ...payloads.applicantOf(MEMBER), name: 'Başka' } }), 'deny'],
    ['updatedAt istemci saati', leave({ updatedAt: clientTime() }), 'deny'],
    ['active → removed (kendi kendini çıkarma)', leave({ status: 'removed' }), 'deny'],
    ['active → cancelled', leave({ status: 'cancelled' }), 'deny'],
    ['active → pending', leave({ status: 'pending' }), 'deny'],
  ])('%s', async (_title, writes, expected, edit = NO_EDIT) => {
    await seedFixture('base', undefined, edit);
    await expectWrite(commit('member', writes), expected);
    expect((await readDoc(M_MEMBER)).status).toBe(expected === 'allow' ? 'left' : 'active');
  });

  test.each([
    ['role: board', { role: 'board' }],
    ['role: president', { role: 'president' }],
    ['role: advisor', { role: 'advisor' }],
    ['priorCount', { priorCount: 9 }],
    ['decidedBy', { decidedBy: MEMBER }],
  ])('aktif üye durum değiştirmeden %s yazamaz', async (_title, fields) => {
    await seedFixture('base');
    const before = await readDoc(M_MEMBER);
    await assertFails(updateDoc(doc(dbOf('member'), M_MEMBER), { ...fields, ...payloads.baseUpdate() }));
    expect(await readDoc(M_MEMBER)).toEqual(before);
  });
});
