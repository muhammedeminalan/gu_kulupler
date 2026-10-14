'use strict';
// T-29 — hesap silme (anonimleştirme) Security Rules testleri. Kaynak: domain-model §11 (5 adım), rules-spec
// §3.1 (`deleted` dalı), §3.2 (anonimleştirme), §3.4 M14 + contact U(c), §3.8 (vazgeçme — W-80), §3.12–§3.14;
// sözleşme docs/plans/T-29.md §4 (dizi, durum geçişi, başkan engeli, kalanlar, Rules dalları).
//
//  1. Tam dizi (uçtan uca, repository'nin yazım sırası): markDeleted → rsvp parçası (transaction) → üyelik
//     parçası (transaction) — yarıda kesilip yeniden başlatılır — → kişisel parça; son durum domain-model §11
//     alan listesiyle karşılaştırılır (ne anonimleşir, ne soft delete edilir, ne kalır).
//  2. Adım 1 alan listesi: fazla / eksik / farklı değer, `avatarSeed` / `staff` / `profileComplete` /
//     `suspendReason` / `lastLoginAt` ret; başkasının hesabı ret.
//  3. M14: etkin hesapta ret, etkin başkan `left` olamaz ama durum değişmeden anonimleşir, danışman sayaçsız,
//     üye sayaçlı, geçiş tablosu, başkasının üyeliği.
//  4. Vazgeçme (W-80): bitmiş etkinlik ve `attended` kaydı iptal edilemez; okunamayan (ayrılınan kulübün üyelere
//     özel) etkinlikteki kayıt okumadan vazgeçilir; temizlik dalları oturumsuz / doğrulanmamış / alan adı dışı
//     jetona kapalı.
//  5. Kişisel belgeler: silinmiş sahibi yalnızca soft delete eder (restore / başkasının belgesi ret).
//  6. "Silinmiş kullanıcı yazamaz" (roadmap): her yazım yolu için temsilî vaka — aynı yük, aynı kullanıcı;
//     hesap etkinken GEÇER (kontrol), `status == 'deleted'` iken REDDEDİLİR (M7, yorum kaldırma ve Storage users/ · events/ · posts/ · support/ dahil).
//  7. Parite: Rules literalleri = Dart `Anonymization` sabitleri.
// Erişim çağrısı bütçesi ayrı dosyadadır: budget/account_deletion_budget.test.js (RP06).
const fs = require('node:fs');
const path = require('node:path');
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { Timestamp, doc, getDoc, increment, runTransaction, serverTimestamp, setDoc, updateDoc } = require('firebase/firestore');
const { ref, uploadBytes } = require('firebase/storage');
const budget = require('../helpers/budget');
const { contextFor, CLUB, OTHER_CLUB } = require('../helpers/contexts');
const { DAY_MS, HOUR_MS, baseDocs, eventDoc, fromNow, readDoc, rsvpDoc, seedDocs } = require('../helpers/fixtures');
const payloads = require('../helpers/payloads');
const { getTestEnv, resetStorage } = require('../setup/env');

const REPO_ROOT = path.resolve(__dirname, '..', '..', '..');
const ANONYMIZATION_DART = path.join(REPO_ROOT, 'packages/gu_data/lib/src/constants/anonymization.dart');
const RULES = path.join(REPO_ROOT, 'firebase/firestore.rules');

const MEMBER = 'u_member';
const DELETED = 'u_deleted';
const THIRD_CLUB = 'c03';

const dbOf = (role) => contextFor(role).firestore();
const commit = (role, writes) => budget.buildBatch(dbOf(role), Object.values(writes)).commit();
const expectWrite = (request, expected) => (expected === 'allow' ? assertSucceeds(request) : assertFails(request));
const clientTime = () => Timestamp.fromMillis(Date.now() - 60 * 1000);
const omit = (object, keys) => Object.fromEntries(Object.entries(object).filter(([key]) => !keys.includes(key)));

/** Temel veri kümesini `edit(docs)` ile değiştirip yazar (kurallar kapalı); yazılan belgeleri döndürür. */
async function seed(edit) {
  const docs = baseDocs();
  if (edit) edit(docs);
  await seedDocs(docs);
  return docs;
}

/** Belgenin alanlarını değiştirir (yoksa hata — yazım hatası sessizce "yeşil" olmasın). */
function patch(docs, docPath, fields) {
  if (!docs[docPath]) throw new Error(`veri kümesinde olmayan belge: ${docPath}`);
  docs[docPath] = { ...docs[docPath], ...fields };
}

/** Kullanıcının hesabı adım 1'den geçmiş gibi (kurallar kapalı): profil anonim + `deleted`, e-posta boş. */
function markedDeleted(docs, uid) {
  patch(docs, `users/${uid}`, {
    name: payloads.DELETED_USER_NAME,
    nameLower: payloads.DELETED_USER_NAME_LOWER,
    bio: '',
    interests: [],
    avatarPath: null,
    department: null,
    year: null,
    status: 'deleted',
    isDeleted: true,
    deletedAt: clientTime(),
    deletedBy: uid,
  });
  patch(docs, `users/${uid}/private/account`, { email: '', emailLower: '', fcmTokens: [] });
}

/** Bir üyeliğin (ve contact'ının) başka bir kulüpte kopyası. */
function copyMembership(docs, uid, club, fields) {
  docs[`memberships/${club}_${uid}`] = { ...docs[`memberships/${CLUB}_${uid}`], clubId: club, ...fields };
  docs[`memberships/${club}_${uid}/private/contact`] = { ...docs[`memberships/${CLUB}_${uid}/private/contact`], note: 'Serbest metin notu.' };
}

// ── 1 · Tam dizi ────────────────────────────────────────────────────────────────────────────

/**
 * `u_member` (c01 etkin üye) için silinecek / kalacak her şeyin bulunduğu veri kümesi: c02'de bekleyen başvuru,
 * c03'te reddedilmiş geçmiş üyelik, herkese açık + üyelere özel + şu an süren etkinlikte `going` kaydı, BİTMİŞ
 * etkinlikte `going` kaydı (W-80: kalır), gelen kutusu, kayıt, engel, yazdığı yorum, ayarlar.
 */
function fullFixture(docs) {
  docs[`clubs/${THIRD_CLUB}`] = { ...docs[`clubs/${OTHER_CLUB}`], name: 'Test Kulübü c03', nameLower: 'test kulübü c03', memberCount: 0, presidentId: 'u_mgr2' };
  copyMembership(docs, MEMBER, OTHER_CLUB, { status: 'pending', decidedAt: null, decidedBy: null });
  copyMembership(docs, MEMBER, THIRD_CLUB, { status: 'rejected', rejectReason: 'quota', rejectNote: '' });
  patch(docs, `memberships/${CLUB}_${MEMBER}/private/contact`, { note: 'Kimliği ele veren not.' });
  patch(docs, `users/${MEMBER}`, { bio: 'Merhaba.', avatarPath: payloads.avatarPathOf(MEMBER), interests: ['i01', 'i05'] });
  patch(docs, `users/${MEMBER}/private/account`, {
    fcmTokens: [{ token: 'fcm-token-1', platform: 'android', updatedAt: clientTime() }],
    lastLoginAt: clientTime(),
  });
  patch(docs, 'events/e_members', { goingCount: 1 });
  docs['rsvps/e_members_u_member'] = rsvpDoc('e_members', MEMBER, 'going', { ticketCode: 'GU-MBRS-2345' });
  docs['events/e_past'] = eventDoc('public', 'published', 1, { startsAt: fromNow(-2 * DAY_MS), endsAt: fromNow(-2 * DAY_MS + 2 * HOUR_MS) });
  docs['rsvps/e_past_u_member'] = rsvpDoc('e_past', MEMBER, 'going', { ticketCode: 'GU-PAST-2345' });
}

/** Adım 2 — `cancelRsvpChunk`: transaction; her kayıt işlem içinde yeniden okunur, `going | waitlist` olan vazgeçirilir. */
function cancelRsvpChunk(role, uid, eventIds) {
  const db = dbOf(role);
  return runTransaction(db, async (tx) => {
    const snapshots = [];
    for (const eventId of eventIds) snapshots.push(await tx.get(doc(db, payloads.rsvpPath(eventId, uid))));
    snapshots.forEach((snapshot, i) => {
      const status = snapshot.data().status;
      if (!['going', 'waitlist'].includes(status)) return;
      tx.update(snapshot.ref, { status: 'cancelled', updatedAt: serverTimestamp() });
      const counter = status === 'going' ? 'goingCount' : 'waitlistCount';
      tx.update(doc(db, `events/${eventIds[i]}`), { [counter]: increment(-1), updatedAt: serverTimestamp() });
    });
  });
}

/** Adım 3 — `anonymizeChunk`: transaction; üyelik + contact işlem içinde okunur, güncel durumdan yazılır. */
function anonymizeChunk(role, uid, clubs) {
  const db = dbOf(role);
  return runTransaction(db, async (tx) => {
    const read = [];
    for (const club of clubs) {
      const membership = await tx.get(doc(db, payloads.membershipPath(club, uid)));
      const contact = await tx.get(doc(db, payloads.contactPath(club, uid)));
      read.push({ club, membership: membership.data(), contact: contact.exists() });
    }
    const writes = payloads.anonymizeMembershipWrites({
      uid,
      memberships: read.map(({ club, membership, contact }) => ({ club, from: membership.status, role: membership.role, contact })),
    });
    for (const w of Object.values(writes)) tx.update(doc(db, w.path), w.data);
  });
}

const PERSONAL = ['notifications/n01', `savedPosts/${MEMBER}_p01`, `blocks/${MEMBER}_u_student`];

/** Tam diziyi `u_member` adına koşar (her adım ayrı istek; aradaki her noktada kesilebilir). */
async function runFullDeletion() {
  await assertSucceeds(commit('member', payloads.markDeletedWrites({ uid: MEMBER })));
  // Plan okuması (buildPlan) üyelik henüz etkinken yapılır: üyelere özel etkinlik okunabilir.
  await assertSucceeds(getDoc(doc(dbOf('member'), 'events/e_members')));
  await assertSucceeds(cancelRsvpChunk('member', MEMBER, ['e_public', 'e_members', 'e_live']));
  // Yarıda kesilme: yalnızca ilk üyelik parçası kesinleşir …
  await assertSucceeds(anonymizeChunk('member', MEMBER, [CLUB]));
  // … yeniden başlatılan dizi güncel durumdan devam eder (zaten anonim `left` üyelik yeniden yazılabilir).
  await assertSucceeds(anonymizeChunk('member', MEMBER, [CLUB, OTHER_CLUB, THIRD_CLUB]));
  await assertSucceeds(commit('member', payloads.personalSoftDeleteWrites({ uid: MEMBER, paths: PERSONAL })));
}

describe('hesap silme · tam dizi (uçtan uca, yarıda kesilip yeniden başlatma dahil)', () => {
  test('dizi geçer; son durum domain-model §11 ile aynıdır (anonim / soft delete / kalan)', async () => {
    const before = await seed(fullFixture);
    await runFullDeletion();

    // users: anonim + `deleted`; avatarSeed, staff, profileComplete, createdAt dokunulmaz.
    const user = await readDoc(`users/${MEMBER}`);
    expect(user).toMatchObject({
      name: 'Silinmiş kullanıcı', nameLower: 'silinmiş kullanıcı', bio: '', interests: [],
      avatarPath: null, department: null, year: null, status: 'deleted', isDeleted: true, deletedBy: MEMBER,
      avatarSeed: before[`users/${MEMBER}`].avatarSeed, staff: false, profileComplete: true,
    });
    // private/account: e-posta + jetonlar boş; lastLoginAt / suspendReason dokunulmaz.
    const account = await readDoc(`users/${MEMBER}/private/account`);
    expect(account).toMatchObject({ email: '', emailLower: '', fcmTokens: [], suspendReason: null, isDeleted: false });
    expect(account.lastLoginAt).not.toBeNull();

    // Üyelikler: active → left (−1 BİR kez), pending → cancelled, geçmiş durum aynı; hepsinde anonim anlık görüntü.
    for (const [club, status] of [[CLUB, 'left'], [OTHER_CLUB, 'cancelled'], [THIRD_CLUB, 'rejected']]) {
      expect(await readDoc(payloads.membershipPath(club, MEMBER))).toMatchObject({ status, role: 'member', applicant: payloads.ANONYMIZED_APPLICANT });
      expect(await readDoc(payloads.contactPath(club, MEMBER))).toMatchObject({ email: '', emailLower: '', note: '' });
    }
    expect((await readDoc(`clubs/${CLUB}`)).memberCount).toBe(before[`clubs/${CLUB}`].memberCount - 1);
    expect((await readDoc(`clubs/${OTHER_CLUB}`)).memberCount).toBe(before[`clubs/${OTHER_CLUB}`].memberCount);

    // Katılım: bitmemiş etkinlikler cancelled + sayaç −1; bitmiş etkinliğin kaydı ve sayacı kalır (W-80).
    for (const eventId of ['e_public', 'e_members', 'e_live']) {
      expect((await readDoc(payloads.rsvpPath(eventId, MEMBER))).status).toBe('cancelled');
      expect((await readDoc(`events/${eventId}`)).goingCount).toBe(before[`events/${eventId}`].goingCount - 1);
    }
    expect((await readDoc('rsvps/e_past_u_member')).status).toBe('going');
    expect((await readDoc('events/e_past')).goingCount).toBe(1);

    // Kişisel belgeler soft delete (silen = hesap sahibi); hiçbiri kaldırılmadı.
    for (const p of PERSONAL) expect(await readDoc(p)).toMatchObject({ isDeleted: true, deletedBy: MEMBER });

    // Kalanlar: yorum (yazar "Silinmiş kullanıcı" görünür), gönderi beğenisi, şikayet, ayarlar.
    expect(await readDoc('comments/cm01')).toMatchObject({ authorId: MEMBER, isDeleted: false });
    expect((await readDoc('posts/p02')).likes).toContain(MEMBER);
    expect(await readDoc('reports/u_member_post_p01')).toMatchObject({ reporterId: MEMBER, status: 'open' });
    expect(await readDoc(`settings/${MEMBER}`)).toEqual(expect.objectContaining({ announcements: true }));

    // Üyelik ayrıldıktan sonra üyelere özel etkinlik okunamaz — dizi sırası bu yüzden rsvp → üyelik.
    await assertFails(getDoc(doc(dbOf('member'), 'events/e_members')));
  });

  test('silindikten sonra geri dönüş yok: status → active, restore ve ikinci markDeleted ret; anonim e-posta yeniden boşaltılabilir', async () => {
    await seed(fullFixture);
    await runFullDeletion();
    const userRef = doc(dbOf('member'), `users/${MEMBER}`);
    await assertFails(updateDoc(userRef, { status: 'active', ...payloads.baseUpdate() }));
    await assertFails(updateDoc(userRef, { ...payloads.restore(), status: 'active', name: 'Eski Ad', nameLower: 'eski ad' }));
    await assertFails(commit('member', payloads.markDeletedWrites({ uid: MEMBER })));
    await assertSucceeds(updateDoc(doc(dbOf('member'), `users/${MEMBER}/private/account`), payloads.anonymizedAccount()));
    expect(await readDoc(`users/${MEMBER}`)).toMatchObject({ status: 'deleted', isDeleted: true });
  });
});

// ── 2 · Adım 1: alan listesi ──────────────────────────────────────────────────────────────────

describe('hesap silme · adım 1 markDeleted — alan listesi (rules-spec §3.1, §3.2)', () => {
  const user = (extra) => payloads.anonymizedUser(MEMBER, extra);
  const account = (extra) => payloads.anonymizedAccount(extra);
  const WITH_TOKEN = (docs) => patch(docs, `users/${MEMBER}/private/account`, {
    fcmTokens: [{ token: 'fcm-token-1', platform: 'ios', updatedAt: clientTime() }],
  });

  // Satır: [başlık, {user?, account?, only?}, beklenti, veri düzenlemesi?]. `only: 'user'` hesap belgesi yazılmaz.
  test.each([
    ['tam yük (Anonymization.userPayload + accountPayload)', {}, 'allow'],
    ['istemci biçimi: avatarPath anahtarsız belgeye null yazılır (W-51)', {}, 'allow', (docs) => {
      docs[`users/${MEMBER}`] = omit(docs[`users/${MEMBER}`], ['avatarPath']);
    }],
    ['sahte ad', { user: user({ name: 'Ali Veli' }) }, 'deny'],
    ['nameLower farklı', { user: user({ nameLower: 'silinmis kullanici' }) }, 'deny'],
    ['bio boşaltılmamış', { user: user({ bio: 'Merhaba.' }) }, 'deny'],
    ['interests boşaltılmamış', { user: user({ interests: ['i01'] }) }, 'deny'],
    ['avatarPath bırakılmış', { user: user({ avatarPath: payloads.avatarPathOf(MEMBER) }) }, 'deny'],
    ['department anahtarı yok (eski değer kalır)', { user: omit(user(), ['department']) }, 'deny'],
    ['year sahte değer', { user: user({ year: '2' }) }, 'deny'],
    ['status suspended', { user: user({ status: 'suspended' }) }, 'deny'],
    ['soft delete alanları yok', { user: omit(user(), ['isDeleted', 'deletedAt', 'deletedBy']) }, 'deny'],
    ['deletedBy başkası', { user: user({ deletedBy: 'u_student' }) }, 'deny'],
    ['deletedAt istemci saati', { user: user({ deletedAt: clientTime() }) }, 'deny'],
    ['avatarSeed değişemez', { user: user({ avatarSeed: 'deleted' }) }, 'deny'],
    ['staff değişemez', { user: user({ staff: true }) }, 'deny'],
    ['profileComplete değişemez', { user: user({ profileComplete: false }) }, 'deny'],
    ['suspendReason users belgesine yazılamaz (CD-133)', { user: user({ suspendReason: 'x' }) }, 'deny'],
    ['hesap belgesi boşaltılmadan yalnız users', { only: 'user' }, 'deny'],
    ['e-posta bırakılmış (yalnız jetonlar boş)', { account: { fcmTokens: [], ...payloads.baseUpdate() } }, 'deny'],
    ['emailLower sahte', { account: account({ emailLower: 'x@ogr.gumushane.edu.tr' }) }, 'deny'],
    ['fcmTokens boşaltılmamış (anahtar yok)', { account: omit(account(), ['fcmTokens']) }, 'deny', WITH_TOKEN],
    ['account suspendReason değişemez', { account: account({ suspendReason: 'x' }) }, 'deny'],
    ['account lastLoginAt değişemez', { account: account({ lastLoginAt: serverTimestamp() }) }, 'deny'],
    ['account isDeleted değişemez', { account: account({ isDeleted: true, deletedAt: serverTimestamp(), deletedBy: MEMBER }) }, 'deny'],
  ])('%s → %s', async (...row) => {
    // Rest parametresi: satırdaki eksik son öğe jest'te `done` geri çağrısı sayılmasın.
    const [, { user: u, account: a, only }, expected, edit] = row;
    await seed(edit);
    const writes = payloads.markDeletedWrites({ uid: MEMBER, user: u, account: a });
    if (only === 'user') delete writes.account;
    await expectWrite(commit('member', writes), expected);
    expect((await readDoc(`users/${MEMBER}`)).status).toBe(expected === 'allow' ? 'deleted' : 'active');
  });

  test('başkasının hesabı silinemez / anonimleştirilemez (aynı yük, başka uid)', async () => {
    await seed();
    await assertFails(commit('member', payloads.markDeletedWrites({ uid: 'u_student' })));
    await assertFails(commit('super', payloads.markDeletedWrites({ uid: 'u_student' })));
    expect((await readDoc('users/u_student')).status).toBe('active');
  });
});

// ── 3 · M14 ───────────────────────────────────────────────────────────────────────────────────

describe('hesap silme · M14 üyelik parçası (rules-spec §3.4; sözleşme §4 c)', () => {
  const mPath = payloads.membershipPath(CLUB, MEMBER);
  const chunk = (spec, extra) => {
    const writes = payloads.anonymizeMembershipWrites({ uid: MEMBER, memberships: [{ club: CLUB, ...spec }] });
    if (extra) writes.membership0.data = { ...writes.membership0.data, ...extra };
    return writes;
  };
  const as = (fields) => (docs) => patch(docs, mPath, fields);

  // Satır: [başlık, parça, beklenti, üyelik düzenlemesi?]. Aktör: hesabı silinmiş `u_member`.
  test.each([
    ['üye: active → left + memberCount −1', chunk({ from: 'active' }), 'allow'],
    ['üye: memberCount −1 olmadan left', chunk({ from: 'active', counter: false }), 'deny'],
    ['yönetim kurulu: active → left + −1', chunk({ from: 'active', role: 'board' }), 'allow', as({ role: 'board' })],
    ['danışman: sayaçsız left (memberCount dışı)', chunk({ from: 'active', role: 'advisor' }), 'allow', as({ role: 'advisor' })],
    ['danışman: −1 ile ret (kulübün −1 dalı danışmana kapalı)', chunk({ from: 'active', role: 'advisor', counter: true }), 'deny', as({ role: 'advisor' })],
    // Etkin başkan (güvenlik incelemesi T-29): `left` olamaz (önce devir), ama kişisel verisi boşalır — durum
    // AYNI kalır, yalnızca anlık görüntü (+ contact) anonimleşir, sayaç oynamaz.
    ['etkin başkan: durum aynı, yalnızca anlık görüntü + contact (sayaçsız)', chunk({ from: 'active', role: 'president' }), 'allow', as({ role: 'president' })],
    ['etkin başkan: anlık görüntü + −1 ret', chunk({ from: 'active', role: 'president', counter: true }), 'deny', as({ role: 'president' })],
    ['etkin başkan: active → left ret (önce devir)', chunk({ from: 'active', role: 'president' }, { status: 'left' }), 'deny', as({ role: 'president' })],
    ['etkin başkan: active → left + −1 ret', chunk({ from: 'active', role: 'president', counter: true }, { status: 'left' }), 'deny', as({ role: 'president' })],
    ['etkin üye: durum aynı (active → active) ret', chunk({ from: 'active', counter: false }, { status: 'active' }), 'deny'],
    ['geçmiş başkan üyeliği (left): yalnızca anlık görüntü boşalır', chunk({ from: 'left', role: 'president' }), 'allow', as({ role: 'president', status: 'left' })],
    ['pending → cancelled (sayaç yok)', chunk({ from: 'pending' }), 'allow', as({ status: 'pending' })],
    ['pending → left ret', chunk({ from: 'pending' }, { status: 'left' }), 'deny', as({ status: 'pending' })],
    ['active → cancelled ret', chunk({ from: 'active' }, { status: 'cancelled' }), 'deny'],
    ['geçmiş (rejected): durum aynı kalır', chunk({ from: 'rejected' }), 'allow', as({ status: 'rejected' })],
    ['geçmiş (removed) → active ret', chunk({ from: 'removed' }, { status: 'active' }), 'deny', as({ status: 'removed' })],
    ['applicant sahte ad', chunk({ from: 'active' }, { applicant: { ...payloads.ANONYMIZED_APPLICANT, name: 'Ali Veli' } }), 'deny'],
    ['applicant eksik anahtar (avatarSeed)', chunk({ from: 'active' }, { applicant: omit(payloads.ANONYMIZED_APPLICANT, ['avatarSeed']) }), 'deny'],
    ['applicant boşaltılmadan yalnız durum', chunk({ from: 'active' }, { applicant: payloads.applicantOf(MEMBER) }), 'deny'],
    ['rol değişemez', chunk({ from: 'active' }, { role: 'board' }), 'deny'],
    ['karar alanları değişemez', chunk({ from: 'active' }, { decidedBy: MEMBER }), 'deny'],
  ])('%s → %s', async (...row) => {
    const [, writes, expected, edit] = row;
    await seed((docs) => {
      markedDeleted(docs, MEMBER);
      if (edit) edit(docs);
    });
    await expectWrite(commit('member', writes), expected);
  });

  test('etkin hesap M14 yazamaz (önce markDeleted); başkasının üyeliği ve contact\'ı anonimleştirilemez', async () => {
    await seed((docs) => markedDeleted(docs, MEMBER));
    // Silinmiş u_member, etkin u_board'un üyeliğini / contact'ını yazamaz.
    await assertFails(commit('member', payloads.anonymizeMembershipWrites({ uid: 'u_board', memberships: [{ club: CLUB, from: 'active', role: 'board' }] })));
    await assertFails(updateDoc(doc(dbOf('member'), payloads.contactPath(CLUB, 'u_board')), payloads.anonymizedContact()));
    // Etkin u_board kendi üyeliğini M14 ile `left` yapamaz.
    await assertFails(commit('board', payloads.anonymizeMembershipWrites({ uid: 'u_board', memberships: [{ club: CLUB, from: 'active', role: 'board' }] })));
    expect((await readDoc(payloads.membershipPath(CLUB, 'u_board'))).status).toBe('active');
  });

  test('silinmiş hesap M14 geçişine `member_left` günlüğü ekleyemez; günlüksüz parça geçer', async () => {
    await seed((docs) => markedDeleted(docs, MEMBER));
    const log = payloads.activityPath(CLUB, MEMBER, 'member_left');
    const withLog = { ...chunk({ from: 'active' }), activity: { op: 'set', path: log, data: payloads.activityOwn(CLUB, MEMBER, 'member_left') } };
    await assertFails(commit('member', withLog));
    await assertSucceeds(commit('member', chunk({ from: 'active' })));
    expect(await readDoc(log)).toBeNull();
  });
});

// ── 4 · Vazgeçme (W-80) ─────────────────────────────────────────────────────────────────────────

describe('hesap silme · katılımdan vazgeçme — yalnızca bitmemiş etkinlik (W-80; rules-spec §3.8)', () => {
  test('bitmemiş etkinlikte geçer; bitmiş etkinlikte ve yoklaması alınmış kayıtta reddedilir', async () => {
    await seed((docs) => {
      fullFixture(docs);
      markedDeleted(docs, MEMBER);
      patch(docs, 'rsvps/e_live_u_member', { status: 'attended', scannedAt: clientTime(), scannedBy: 'u_president' });
      patch(docs, 'events/e_live', { attendedCount: 2 });
    });
    await assertSucceeds(commit('member', payloads.rsvpCancelWrites({ uid: MEMBER, eventId: 'e_public' })));
    await assertFails(commit('member', payloads.rsvpCancelWrites({ uid: MEMBER, eventId: 'e_past' })));
    await assertFails(commit('member', payloads.rsvpCancelWrites({ uid: MEMBER, eventId: 'e_live' })));
    expect((await readDoc('rsvps/e_past_u_member')).status).toBe('going');
    expect((await readDoc('rsvps/e_live_u_member')).status).toBe('attended');
  });
});

describe('hesap silme · okunamayan etkinlikteki kayıt — etkinlik okunmadan vazgeçilir (güvenlik incelemesi T-29)', () => {
  // Ayrılınan kulübün üyelere özel etkinliği (M8 katılımı iptal etmez): silinmiş sahibi etkinliği OKUYAMAZ,
  // ama `canCancelRsvp` okuma izni istemez — kayıt + sayaç tek batch'te (`cancelUnreadableRsvp`) geçer.
  const leftClub = (docs) => {
    fullFixture(docs);
    markedDeleted(docs, MEMBER);
    patch(docs, payloads.membershipPath(CLUB, MEMBER), { status: 'left' });
  };

  test('bitmemiş üyelere özel etkinlik: okuma ret, okumasız vazgeçme geçer (going −1)', async () => {
    await seed(leftClub);
    await assertFails(getDoc(doc(dbOf('member'), 'events/e_members')));
    await assertSucceeds(commit('member', payloads.rsvpCancelWrites({ uid: MEMBER, eventId: 'e_members' })));
    expect((await readDoc('rsvps/e_members_u_member')).status).toBe('cancelled');
    expect((await readDoc('events/e_members')).goingCount).toBe(0);
  });

  test('bitmiş üyelere özel etkinlik (W-80): okumasız vazgeçme de reddedilir; sayaçsız / çift −1 ret', async () => {
    await seed((docs) => {
      leftClub(docs);
      patch(docs, 'events/e_members', { startsAt: fromNow(-2 * DAY_MS), endsAt: fromNow(-2 * DAY_MS + 2 * HOUR_MS) });
    });
    await assertFails(commit('member', payloads.rsvpCancelWrites({ uid: MEMBER, eventId: 'e_members' })));
    expect((await readDoc('rsvps/e_members_u_member')).status).toBe('going');
  });

  test('sayaçsız vazgeçme ve zaten vazgeçilmiş kayıtta ikinci −1 ret', async () => {
    await seed(leftClub);
    const { rsvp } = payloads.rsvpCancelWrites({ uid: MEMBER, eventId: 'e_members' });
    await assertFails(commit('member', { rsvp }));
    await assertSucceeds(commit('member', payloads.rsvpCancelWrites({ uid: MEMBER, eventId: 'e_members' })));
    await assertFails(commit('member', payloads.rsvpCancelWrites({ uid: MEMBER, eventId: 'e_members' })));
    expect((await readDoc('events/e_members')).goingCount).toBe(0);
  });
});

describe('hesap silme · temizlik dalları emailOk ister (oturumsuz / doğrulanmamış / alan adı dışı jeton)', () => {
  // Aynı kişi (`u_member`, belgeleri silinmiş), jetonu geçersiz: hiçbir temizlik dalı geçmez. Kontrol: geçerli
  // jetonla aynı yükler geçer (ret yalnızca jetondan gelir).
  const tokens = [
    ['oturumsuz', null],
    ['doğrulanmamış e-posta', { email: 'member@ogr.gumushane.edu.tr', email_verified: false }],
    ['alan adı dışı', { email: 'member@hotmail.com', email_verified: true }],
  ];
  const dbFor = (token) => (token ? getTestEnv().authenticatedContext(MEMBER, token) : getTestEnv().unauthenticatedContext()).firestore();
  const batchOf = (db, writes) => budget.buildBatch(db, Object.values(writes)).commit();

  test.each(tokens)('%s: markDeleted ret (hesap etkin)', async (_title, token) => {
    await seed();
    await assertFails(batchOf(dbFor(token), payloads.markDeletedWrites({ uid: MEMBER })));
    expect((await readDoc(`users/${MEMBER}`)).status).toBe('active');
  });

  test.each(tokens)('%s: M14, contact, hesap e-postası, kişisel soft delete ve vazgeçme ret', async (_title, token) => {
    await seed((docs) => {
      fullFixture(docs);
      markedDeleted(docs, MEMBER);
    });
    const db = dbFor(token);
    await assertFails(batchOf(db, payloads.anonymizeMembershipWrites({ uid: MEMBER, memberships: [{ club: CLUB, from: 'active' }] })));
    await assertFails(updateDoc(doc(db, payloads.contactPath(OTHER_CLUB, MEMBER)), payloads.anonymizedContact()));
    await assertFails(updateDoc(doc(db, `users/${MEMBER}/private/account`), payloads.anonymizedAccount()));
    for (const p of PERSONAL) await assertFails(updateDoc(doc(db, p), payloads.softDelete(MEMBER)));
    await assertFails(batchOf(db, payloads.rsvpCancelWrites({ uid: MEMBER, eventId: 'e_public' })));
    // Kontrol: geçerli jetonla aynı yükler geçer.
    await assertSucceeds(commit('member', payloads.anonymizeMembershipWrites({ uid: MEMBER, memberships: [{ club: CLUB, from: 'active' }] })));
    await assertSucceeds(commit('member', payloads.personalSoftDeleteWrites({ uid: MEMBER, paths: PERSONAL })));
    await assertSucceeds(commit('member', payloads.rsvpCancelWrites({ uid: MEMBER, eventId: 'e_public' })));
  });
});

// ── 5 · Kişisel belgeler ──────────────────────────────────────────────────────────────────────

describe('hesap silme · kişisel belgeler — silinmiş sahibi yalnızca soft delete eder (rules-spec §3.9, §3.13, §3.14)', () => {
  const removed = (docPath) => (docs) => patch(docs, docPath, { isDeleted: true, deletedBy: MEMBER, deletedAt: clientTime() });

  test('bildirim + kayıt + engel tek batch\'te soft delete edilir', async () => {
    await seed((docs) => markedDeleted(docs, MEMBER));
    await assertSucceeds(commit('member', payloads.personalSoftDeleteWrites({ uid: MEMBER, paths: PERSONAL })));
    for (const p of PERSONAL) expect(await readDoc(p)).toMatchObject({ isDeleted: true, deletedBy: MEMBER });
  });

  test.each([
    ['engel restore', `blocks/${MEMBER}_u_student`],
    ['kayıt restore', `savedPosts/${MEMBER}_p01`],
  ])('%s ret (geri alma activeUser ister)', async (_title, docPath) => {
    await seed((docs) => {
      markedDeleted(docs, MEMBER);
      removed(docPath)(docs);
    });
    await assertFails(updateDoc(doc(dbOf('member'), docPath), payloads.restore()));
  });

  test('başkasının engeli / kaydı ve soft delete dışı alan ret', async () => {
    await seed((docs) => markedDeleted(docs, MEMBER));
    await assertFails(updateDoc(doc(dbOf('member'), 'blocks/u_susp_u_student'), payloads.softDelete(MEMBER)));
    await assertFails(updateDoc(doc(dbOf('member'), 'savedPosts/u_susp_p01'), payloads.softDelete(MEMBER)));
    await assertFails(updateDoc(doc(dbOf('member'), `blocks/${MEMBER}_u_student`), { ...payloads.softDelete(MEMBER), blockedId: 'u_board' }));
  });
});

// ── 6 · Silinmiş kullanıcı yazamaz ─────────────────────────────────────────────────────────────

describe('hesap silme · silinmiş kullanıcı yazamaz (roadmap T-29; domain-model §11 adım 4)', () => {
  // Aktör `deleted` bağlamı (`u_deleted`: c01 etkin üye). Her vaka aynı yükü iki kez gönderir: hesap
  // `active` iken GEÇER (yük ve yol doğru — ret yalnızca hesabın durumundan gelir), `deleted` iken REDDEDİLİR.
  const at = (p) => doc(dbOf('deleted'), p);
  const removed = (docPath) => ({ [docPath]: { isDeleted: true, deletedBy: DELETED, deletedAt: clientTime() } });
  const OWN_M = payloads.membershipPath(CLUB, DELETED);
  /** Kulüp kökleri (events/, posts/) üst verisi: `clubId` + yükleyenin kendi kimliği (CD-39). */
  const clubImage = () => ({ contentType: 'image/png', customMetadata: { clubId: CLUB, uploaderId: DELETED } });
  const PNG = Uint8Array.from(Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==', 'base64'));

  // Satır: [yazım yolu, istek üreticisi, ek / değişen belgeler (kurallar kapalı)].
  const CASES = [
    ['profil güncelleme (UserRepository.updateProfile)', () => updateDoc(at(`users/${DELETED}`), payloads.userProfileUpdate(DELETED))],
    ['giriş zamanı (touchLastLogin)', () => updateDoc(at(`users/${DELETED}/private/account`), payloads.accountTouchLastLogin())],
    ['ayarlar (updateSettings)', () => updateDoc(at(`settings/${DELETED}`), payloads.settingsUpdate())],
    ['yeniden başvuru (M3)', () => commit('deleted', payloads.reapplyWrites({ club: CLUB, uid: DELETED })), { [OWN_M]: { status: 'left' } }],
    ['ayrılma (M8)', () => commit('deleted', payloads.leaveWrites({ club: CLUB, uid: DELETED }))],
    ['gönderi (yönetim kurulu)', () => commit('deleted', payloads.createPostWrites({ club: CLUB, uid: DELETED })), { [OWN_M]: { role: 'board' } }],
    ['yorum', () => commit('deleted', payloads.addCommentWrites({ club: CLUB, uid: DELETED }))],
    ['beğeni', () => updateDoc(at('posts/p01'), payloads.postLike(DELETED))],
    ['oy', () => setDoc(at(`posts/p01/votes/${DELETED}`), payloads.voteCreate('o1'))],
    ['katılım', () => commit('deleted', payloads.rsvpJoinWrites({ club: CLUB, uid: DELETED }))],
    ['hatırlatma (rsvp reminder)', () => updateDoc(at(payloads.rsvpPath('e_public', DELETED)), payloads.rsvpReminder()),
      { [payloads.rsvpPath('e_public', DELETED)]: rsvpDoc('e_public', DELETED, 'going', { ticketCode: 'GU-DLTD-2345' }) }],
    ['kendi hatırlatma bildirimi (createSelf)', () => setDoc(at(payloads.reminderPath('e_public', DELETED)),
      payloads.notificationCreate('event_reminder', DELETED, { clubId: CLUB, eventId: 'e_public' }))],
    ['şikayet', () => setDoc(at(`reports/${DELETED}_post_p01`), payloads.reportCreate(DELETED, payloads.REPORT_TARGET))],
    ['destek talebi', () => setDoc(at(`supportTickets/${payloads.NEW_TICKET_NO}`), payloads.ticketCreate({ uid: DELETED }))],
    ['engel oluşturma', () => setDoc(at(`blocks/${DELETED}_u_board`), payloads.blockCreate(DELETED, 'u_board'))],
    ['engel restore', () => updateDoc(at(`blocks/${DELETED}_u_student`), payloads.restore()),
      { [`blocks/${DELETED}_u_student`]: { ...baseDocs()['blocks/u_member_u_student'], blockerId: DELETED, isDeleted: true, deletedBy: DELETED } }],
    ['gönderi kaydetme', () => setDoc(at(`savedPosts/${DELETED}_p01`), payloads.savedCreate({ club: CLUB, uid: DELETED }))],
    ['kayıt restore', () => updateDoc(at(`savedPosts/${DELETED}_p01`), payloads.restore()),
      { [`savedPosts/${DELETED}_p01`]: { ...baseDocs()['savedPosts/u_member_p01'], userId: DELETED, isDeleted: true, deletedBy: DELETED } }],
    ['avatar yükleme (Storage users/{uid}/)', () => uploadBytes(ref(contextFor('deleted').storage(), `users/${DELETED}/20261014T090000Z_0a1b2c3d4e5f6071.png`), PNG, { contentType: 'image/png' })],
    // Güvenlik incelemesi T-29 (eksik test): M7, yorum kaldırma (`mayRemove`) ve diğer Storage kökleri.
    ['başvuru iptali (M7)', () => updateDoc(at(OWN_M), payloads.payloadFor('membershipCancel', {})), { [OWN_M]: { status: 'pending' } }],
    ['yorum kaldırma (mayRemove)', () => commit('deleted', payloads.removeCommentWrites({ uid: DELETED })), { 'comments/cm01': { authorId: DELETED } }],
    ['etkinlik kapağı (Storage events/, yönetim kurulu)', () => uploadBytes(ref(contextFor('deleted').storage(), 'events/e_yeni_01/20261014T090000Z_0a1b2c3d4e5f6071.png'), PNG, clubImage()), { [OWN_M]: { role: 'board' } }],
    ['gönderi görseli (Storage posts/, yönetim kurulu)', () => uploadBytes(ref(contextFor('deleted').storage(), 'posts/pYeni_01/20261014T090000Z_0a1b2c3d4e5f6071.png'), PNG, clubImage()), { [OWN_M]: { role: 'board' } }],
    ['destek eki (Storage support/)', () => uploadBytes(ref(contextFor('deleted').storage(), payloads.supportAttachmentPath(payloads.NEW_TICKET_NO, '20261014T090000Z_0a1b2c3d4e5f6071.png')), PNG,
      { contentType: 'image/png', customMetadata: { uploaderId: DELETED } })],
  ];

  /** `u_deleted` hesabını `status` ile kurar; ek belgeler (yoksa eklenir, varsa birleştirilir). */
  const seedAs = (status, extra = {}) => seed((docs) => {
    patch(docs, `users/${DELETED}`, { status, isDeleted: status === 'deleted' });
    for (const [p, fields] of Object.entries(extra)) docs[p] = { ...(docs[p] || {}), ...fields };
  });

  test.each(CASES)('%s: etkin hesapta geçer, silinmiş hesapta reddedilir', async (...row) => {
    const [, request, extra] = row;
    await seedAs('active', extra);
    await assertSucceeds(request());
    // Kontrol yazımının bıraktığı belge / dosya ikinci denemeyi "var olan belge" yüzünden düşürmesin.
    await getTestEnv().clearFirestore();
    await resetStorage();
    await seedAs('deleted', extra);
    await assertFails(request());
  });

  test('askıdaki hesaba açık sahip yazımları (ayarlar, giriş zamanı) silinmiş hesaba kapalı; askıdaki yazmaya devam eder', async () => {
    await seed((docs) => {
      patch(docs, `users/${DELETED}`, { status: 'deleted' });
      delete docs[`settings/${DELETED}`];
    });
    await assertFails(setDoc(at(`settings/${DELETED}`), payloads.settingsCreate()));
    await assertSucceeds(updateDoc(doc(dbOf('susp'), 'settings/u_susp'), payloads.settingsUpdate()));
    await assertSucceeds(updateDoc(doc(dbOf('susp'), 'users/u_susp/private/account'), payloads.accountTouchLastLogin()));
  });
});

// ── 7 · Parite ────────────────────────────────────────────────────────────────────────────────

describe('parite · Dart Anonymization ↔ Rules literalleri ↔ helpers/payloads.js', () => {
  test('ad, küçük harfli ad ve anonim avatar tohumu üç yerde aynıdır', () => {
    const dart = fs.readFileSync(ANONYMIZATION_DART, 'utf8');
    const constant = (name) => {
      const m = new RegExp(`static const String ${name} = '([^']*)';`).exec(dart);
      if (!m) throw new Error(`Anonymization.${name} bulunamadı`);
      return m[1];
    };
    const name = constant('deletedUserName');
    const lower = constant('_deletedUserNameLower');
    const seedValue = constant('_deletedAvatarSeed');
    expect([payloads.DELETED_USER_NAME, payloads.DELETED_USER_NAME_LOWER, payloads.ANONYMIZED_APPLICANT.avatarSeed]).toEqual([name, lower, seedValue]);
    expect(payloads.ANONYMIZED_APPLICANT).toEqual({ name, department: null, year: null, avatarSeed: seedValue });

    const rules = fs.readFileSync(RULES, 'utf8');
    expect(rules).toContain(`d.name == '${name}' && d.nameLower == '${lower}'`);
    expect(rules).toContain(`{'name': '${name}', 'department': null,`);
    expect(rules).toContain(`'year': null, 'avatarSeed': '${seedValue}'}`);
    expect(constant('_deletedStatus')).toBe('deleted');
  });
});
