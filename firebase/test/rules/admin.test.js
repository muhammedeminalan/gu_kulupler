'use strict';
// T-37 — süper admin arka ucu (rules-spec §3.1–§3.4, §3.9–§3.11, koleksiyon grubu `private`; PLAN §10.4
// AdminRepository + MembershipRepository.setAdvisor; sözleşme docs/plans/T-37.md §4).
//
//  1. Claim olmadan hiçbir admin işlemi geçmez (roadmap): süper admin dışındaki 11 bağlam + 2 alt varyant + sahte
//     claim'ler (geri alınmış, `false`, dizgi, sayı, başka ad, Firestore alanı) × bütün süper admin işlemleri → ret;
//     süper admin her işlemi geçer. Yetki yalnızca jeton claim'idir (D-28).
//  2. Kulüp: oluşturma (tek batch; W-51 iki biçim; eksik parça / biçim ret), kimlik, medya, askı / etkinleştirme.
//  3. Başkan atama (yeni hedef + geçmiş üye; W-94 yan belge; sayaç / presidentId tutarlılığı) ve M13 danışman.
//  4. Kullanıcı askısı (CD-133 iki yönlü bağ; silinmiş hesap; kullanıcı kendi askısını kaldıramaz).
//  5. Şikayet grubu çözümü (tek batch; `removed` ⇒ hedef gizli; `report_resolved` alıcıları ve biçimi).
//  6. collectionGroup('private') e-posta araması (yalnızca süper admin; başka private belgeleri açılmaz).
//  7. Askının etkisi: askıdaki kulüpte ve askıdaki kullanıcıyla yazım ret (roadmap).
// Erişim bütçesi: budget/admin_budget.test.js. İndeks: queries.test.js (`adminUpcomingEvents`).
const path = require('node:path');
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const {
  Timestamp,
  collection,
  collectionGroup,
  doc,
  getDoc,
  getDocs,
  increment,
  query,
  updateDoc,
  where,
} = require('firebase/firestore');
const budget = require('../helpers/budget');
const { CONTEXTS, VARIANTS, contextFor, uidOf } = require('../helpers/contexts');
const { readDoc, seedDocs, seedFixture } = require('../helpers/fixtures');
const payloads = require('../helpers/payloads');
const admin = require('../helpers/admin_payloads');
const { getTestEnv } = require('../setup/env');

const { ADMIN, ADVISOR, NEW_CLUB, REASON, MEDIA_PATH } = admin;
const REPO_ROOT = path.resolve(__dirname, '..', '..', '..');
const LIMITS = require(path.join(REPO_ROOT, 'tool', 'lib', 'dart_sources.js')).readLimits(REPO_ROOT).ints;
const CLUB = 'c01';
const OTHER = 'c02';

/**
 * Ortak veri: `c01` danışmanı hesabıyla bağlı (`u_advisor`), `c02` askıda ve danışman kaydı hesapsız; iki şikayet
 * grubu — gönderi `p01` (u_member + u_board) ve kullanıcı `u_student` (u_member).
 */
const EDIT = Object.freeze({
  patch: {
    [`clubs/${CLUB}`]: { advisor: { ...ADVISOR, userId: 'u_advisor' } },
    [`clubs/${OTHER}`]: { status: 'suspended', suspendReason: REASON, advisor: { ...ADVISOR, userId: null } },
  },
});
const EXTRA = Object.freeze({
  'reports/u_board_post_p01': admin.reportDoc('u_board', 'post', 'p01', CLUB),
  'reports/u_member_user_u_student': admin.reportDoc('u_member', 'user', 'u_student'),
});
async function seed(edit = EDIT) {
  const docs = await seedFixture('base', undefined, edit);
  await seedDocs(EXTRA);
  return docs;
}

const dbOf = (role) => contextFor(role).firestore();
const commitOn = (db, writes) => budget.buildBatch(db, Object.values(writes)).commit();
const commit = (role, writes) => commitOn(dbOf(role), writes);
const expectWrite = (request, expected) => (expected === 'allow' ? assertSucceeds(request) : assertFails(request));
const omit = (writes, ...names) => Object.fromEntries(Object.entries(writes).filter(([name]) => !names.includes(name)));
const withData = (writes, name, extra) => ({ ...writes, [name]: { ...writes[name], data: { ...writes[name].data, ...extra } } });
const dropField = (writes, name, field) => {
  const { [field]: _dropped, ...rest } = writes[name].data;
  return { ...writes, [name]: { ...writes[name], data: rest } };
};
const BASE_COUNT = 5; // c01 memberCount (fixtures: member, board, president, susp, deleted)

/** E-posta araması — `AdminRepository.findUserByEmail` sorgusu (`emailLower` öneki). */
const emailSearch = (db, prefix = 'member@') =>
  getDocs(query(collectionGroup(db, 'private'), where('emailLower', '>=', prefix), where('emailLower', '<', `${prefix}`)));

// ── 1. Claim olmadan hiçbir admin işlemi geçmez ──────────────────────────────────────────────

/** Süper admin işlemleri: [ad, (db, actor) => istek]. Hepsi yalnızca süper admine açıktır (başka rolün meşru yolu değil). */
const ADMIN_OPS = Object.freeze([
  ['kulüp oluştur (createClub)', (db, actor) => commitOn(db, admin.createClubWrites({ actor }))],
  ['kimlik düzenle (updateClubIdentity)', (db) => commitOn(db, admin.identityWrites())],
  // askıdaki c02: kendi başkanı (otherManager) da `clubLive` yüzünden yazamaz — süper dal `clubLive` istemez
  ['medya yolu (updateClubMedia, askıdaki kulüp)', (db) => commitOn(db, admin.mediaWrites({ club: OTHER }))],
  ['kulübü askıya al (suspendClub)', (db) => commitOn(db, admin.suspendClubWrites())],
  ['kulübü etkinleştir (activateClub)', (db) => commitOn(db, admin.activateClubWrites({ club: OTHER }))],
  ['başkan ata — yeni hedef (assignPresident, W-94)', (db, actor) => commitOn(db, admin.assignWrites({ actor }))],
  ['danışman bağla (M13)', (db) => commitOn(db, admin.advisorLinkWrites({ club: OTHER }))],
  ['danışman kaldır (M13)', (db) => commitOn(db, admin.advisorUnlinkWrites())],
  ['kullanıcıyı askıya al (suspendUser)', (db) => commitOn(db, admin.suspendUserWrites())],
  ['askıyı kaldır (activateUser)', (db) => commitOn(db, admin.activateUserWrites())],
  ['şikayet grubu çöz — removed + gizle + bildirim', (db, actor) => commitOn(db, admin.resolveWrites({ reporters: ['u_member', 'u_board'], actor }))],
  ['şikayet çöz — dismissed', (db, actor) => commitOn(db, admin.resolveWrites({ reporters: ['u_member'], type: 'user', id: 'u_student', action: 'dismissed', actor }))],
  ['gönderi gizle (T-19 süper dalı)', (db, actor) => updateDoc(doc(db, 'posts/p02'), payloads.hidePayload(actor))],
  ['e-posta araması (collectionGroup private)', (db) => emailSearch(db)],
]);

/** Süper admin bağlamının hesabıyla (aynı Firestore durumu) ama sahte / eksik claim'le jeton. */
const SUPER_EMAIL = { email: 'super@gumushane.edu.tr', email_verified: true };
const FAKE_CLAIMS = Object.freeze([
  ['claim yok (geri alınmış)', SUPER_EMAIL],
  ['superadmin: false', { ...SUPER_EMAIL, superadmin: false }],
  ['superadmin: "true" (dizgi)', { ...SUPER_EMAIL, superadmin: 'true' }],
  ['superadmin: 1 (sayı)', { ...SUPER_EMAIL, superadmin: 1 }],
  ['admin: true (başka ad)', { ...SUPER_EMAIL, admin: true }],
  ['superAdmin: true (büyük harf)', { ...SUPER_EMAIL, superAdmin: true }],
]);

async function expectNothingChanged() {
  expect(await readDoc(`clubs/${CLUB}`)).toMatchObject({ status: 'active', presidentId: 'u_president', memberCount: BASE_COUNT, name: `Test Kulübü ${CLUB}` });
  expect(await readDoc(`clubs/${OTHER}`)).toMatchObject({ status: 'suspended', advisor: { ...ADVISOR, userId: null } });
  expect(await readDoc(`clubs/${NEW_CLUB}`)).toBeNull();
  expect(await readDoc('users/u_member')).toMatchObject({ status: 'active' });
  expect(await readDoc('users/u_susp')).toMatchObject({ status: 'suspended' });
  expect(await readDoc('reports/u_member_post_p01')).toMatchObject({ status: 'open' });
  expect(await readDoc('posts/p02')).toMatchObject({ isHidden: false });
  expect(await readDoc(`memberships/${CLUB}_u_advisor`)).toMatchObject({ status: 'active', role: 'advisor' });
}

async function denyAll(db, actor) {
  for (const [name, run] of ADMIN_OPS) {
    await assertFails(run(db, actor)).catch((error) => {
      throw new Error(`${name}: ${error.message}`);
    });
  }
  await expectNothingChanged();
}

describe('admin · claim olmadan hiçbir admin işlemi geçmez (roadmap T-37; D-28)', () => {
  const others = [...CONTEXTS.filter((role) => role !== 'super'), ...VARIANTS];
  test.each(others)('%s · bütün süper admin işlemleri → deny', async (role) => {
    await seed();
    await denyAll(dbOf(role), uidOf(role));
  });

  test.each(FAKE_CLAIMS)('süper adminin hesabı, %s → bütün işlemler deny', async (_title, token) => {
    await seed();
    await denyAll(getTestEnv().authenticatedContext(ADMIN, token).firestore(), ADMIN);
  });

  test('Firestore alanı yetki vermez: users/{uid}.superadmin = true / role = superadmin, claim yok → deny', async () => {
    await seed({ patch: { ...EDIT.patch, [`users/${ADMIN}`]: { superadmin: true, role: 'superadmin' } } });
    await denyAll(getTestEnv().authenticatedContext(ADMIN, SUPER_EMAIL).firestore(), ADMIN);
  });

  test.each(ADMIN_OPS)('super · %s → allow', async (_name, run) => {
    await seed();
    await assertSucceeds(run(dbOf('super'), ADMIN));
  });
});

// ── 2. Kulüp ─────────────────────────────────────────────────────────────────────────────────

describe('admin · createClub (tek batch: kulüp + başkan üyeliği + contact; §4 a.1)', () => {
  test.each([
    ['istemci biçimi (null alanların anahtarı yok)', {}],
    ['seed biçimi (açık null — W-51)', { seedNulls: true }],
    ['danışman kaydıyla (ad + ünvan, hesap bağlanmaz — K-A)', { advisor: ADVISOR }],
    ['danışmanlı seed biçimi (advisor.userId: null)', { advisor: ADVISOR, seedNulls: true }],
  ])('%s → allow; kulüp memberCount 1, başkan üyeliği active/president, contact hesap e-postası', async (_title, options) => {
    await seed();
    await assertSucceeds(commit('super', admin.createClubWrites(options)));
    expect(await readDoc(`clubs/${NEW_CLUB}`)).toMatchObject({ memberCount: 1, presidentId: 'u_student', status: 'active', createdBy: ADMIN });
    expect(await readDoc(`memberships/${NEW_CLUB}_u_student`)).toMatchObject({ status: 'active', role: 'president', decidedBy: ADMIN, priorCount: 0 });
    expect(await readDoc(`memberships/${NEW_CLUB}_u_student/private/contact`)).toMatchObject({ email: 'student@ogr.gumushane.edu.tr', note: '' });
    expect(await readDoc(`clubs/${NEW_CLUB}/private/counter`)).toBeNull();
  });

  const W = () => admin.createClubWrites();
  test.each([
    ['başkan üyeliği yok (eksik parça)', () => omit(W(), 'membership')],
    ['başkanın contact belgesi yok (eksik parça)', () => omit(W(), 'contact')],
    ['kulüp belgesi yok (yalnızca üyelik + contact)', () => omit(W(), 'club')],
    ['memberCount 2', () => withData(W(), 'club', { memberCount: 2 })],
    ['askıda doğar', () => withData(W(), 'club', { status: 'suspended', suspendReason: REASON })],
    ['coverSeed yok (sonraki ayar yazımları birleşmiş belgeyi doğrular)', () => dropField(W(), 'club', 'coverSeed')],
    ['logo yolu oluşturmada (medya sonradan)', () => withData(W(), 'club', { logoPath: MEDIA_PATH(NEW_CLUB) })],
    ['danışman hesabı oluşturmada bağlanır (K-A)', () => withData(W(), 'club', { advisor: { ...ADVISOR, userId: 'u_advisor' } })],
    ['createdBy başkası', () => withData(W(), 'club', { createdBy: 'u_president' })],
    ['beyaz liste dışı alan (lastMembershipRef — CD-137 8q)', () => withData(W(), 'club', { lastMembershipRef: `memberships/${NEW_CLUB}_u_student` })],
    ['kuruluş yılı gelecekte', () => withData(W(), 'club', { founded: 2999 })],
    ['bilinmeyen kategori', () => withData(W(), 'club', { categoryId: 'k99' })],
    ['ad yalnızca boşluk', () => withData(W(), 'club', { name: '   ' })],
    ['ad 61 karakter', () => withData(W(), 'club', { name: 'x'.repeat(61) })],
    // T-45 F1: kimlik / danışman / kapak alanları üst sınırlı (kulüp belgesi doğrulanmış herkese açık).
    [`iconName ${LIMITS.iconNameMax + 1} karakter (iconNameMax)`, () => withData(W(), 'club', { iconName: 'x'.repeat(LIMITS.iconNameMax + 1) })],
    [`advisor.title ${LIMITS.advisorTitleMax + 1} karakter (advisorTitleMax)`, () => withData(W(), 'club', { advisor: { ...ADVISOR, title: 'x'.repeat(LIMITS.advisorTitleMax + 1) } })],
    [`coverSeed ${LIMITS.coverSeedMax + 1} karakter (coverSeedMax)`, () => withData(W(), 'club', { coverSeed: 'x'.repeat(LIMITS.coverSeedMax + 1) })],
    [`social.web ${LIMITS.socialWebMax + 1} karakter (socialWebMax)`, () => withData(W(), 'club', { social: { web: `https://gu.edu.tr/${'a'.repeat(LIMITS.socialWebMax + 1 - 18)}` } })],
    ['başkan üyeliği member rolünde', () => withData(W(), 'membership', { role: 'member' })],
    ['başkanın anlık görüntüsü profille uyuşmuyor', () => withData(W(), 'membership', { applicant: { ...payloads.applicantOf('u_student'), name: 'Sahte Ad' } })],
    ['contact başka e-posta', () => withData(W(), 'contact', { email: 'baska@ogr.gumushane.edu.tr', emailLower: 'baska@ogr.gumushane.edu.tr' })],
    ['contact başvuru notu taşır', () => withData(W(), 'contact', { note: 'Not.' })],
    ['kulüp kimliğinde alt çizgi (üyelik / günlük kimliği belirsizliği)', () => admin.createClubWrites({ club: 'c_new' })],
    ['başkanın hesabı askıda', () => admin.createClubWrites({ president: 'u_susp' })],
  ])('%s → deny', async (_title, build) => {
    await seed();
    await assertFails(commit('super', build()));
    expect(await readDoc(`clubs/${NEW_CLUB}`)).toBeNull();
  });

  // T-45 (F5 / F1): sınırın tam değeri geçer (N+1 ret satırları yukarıda).
  test.each([
    [`ad ${LIMITS.clubNameMax} karakter (clubNameMax)`, () => withData(W(), 'club', { name: 'x'.repeat(LIMITS.clubNameMax), nameLower: 'x'.repeat(LIMITS.clubNameMax) })],
    [`iconName ${LIMITS.iconNameMax} karakter (iconNameMax)`, () => withData(W(), 'club', { iconName: 'x'.repeat(LIMITS.iconNameMax) })],
    [`advisor.title ${LIMITS.advisorTitleMax} karakter (advisorTitleMax)`, () => withData(W(), 'club', { advisor: { ...ADVISOR, title: 'x'.repeat(LIMITS.advisorTitleMax) } })],
    [`coverSeed ${LIMITS.coverSeedMax} karakter (coverSeedMax)`, () => withData(W(), 'club', { coverSeed: 'x'.repeat(LIMITS.coverSeedMax) })],
  ])('%s → allow', async (_title, build) => {
    await seed();
    await assertSucceeds(commit('super', build()));
  });

  // CD-63 (kilitli): ad benzersizliği Rules'ta DENETLENMEZ — istemcinin `nameLower` eşitlik sorgusu (yalnızca süper
  // admine açık: queries.test.js `isNameTaken`); kilit belgesi yok, yarış kabul (rules-spec §9.4).
  test('aynı ad (nameLower) Rules\'ta reddedilmez — benzersizlik istemci sorgusundadır (CD-63)', async () => {
    await seed();
    const taken = withData(admin.createClubWrites(), 'club', { name: `Test Kulübü ${CLUB}`, nameLower: `test kulübü ${CLUB}` });
    await assertSucceeds(commit('super', taken));
  });
});

describe('admin · updateClubIdentity / updateClubMedia / askı (§4 a.2, a.5, g-3, g-4)', () => {
  test('kimlik + form alanları + danışman adı (bağlı hesap korunur) → allow; hesapsız danışman kaldırılır → allow', async () => {
    await seed();
    await assertSucceeds(commit('super', admin.identityWrites({}, { advisor: { name: 'Mehmet Kaya', title: 'Prof. Dr.', userId: 'u_advisor' } })));
    expect(await readDoc(`clubs/${CLUB}`)).toMatchObject({ name: 'Robotik Topluluğu', categoryId: 'k03', advisor: { name: 'Mehmet Kaya', userId: 'u_advisor' } });
    await assertSucceeds(commit('super', admin.identityWrites({ club: OTHER }, { advisor: null })));
  });

  test.each([
    ['bağlı danışman kaldırılır (advisor: null)', { advisor: null }],
    ['danışmanın hesabı değişir', { advisor: { ...ADVISOR, userId: 'u_student' } }],
    ['danışmanın hesabı ayrılır (M13 dışında)', { advisor: { ...ADVISOR, userId: null } }],
    ['status', { status: 'suspended' }],
    ['presidentId', { presidentId: 'u_board' }],
    ['memberCount', { memberCount: 9 }],
    ['conditions (yönetim alanı — beyaz listede yok)', { conditions: ['Kural.'] }],
    ['logoPath (medya dalında)', { logoPath: MEDIA_PATH(CLUB) }],
    ['ad 61 karakter', { name: 'x'.repeat(61) }],
    // T-45 F1
    [`iconName ${LIMITS.iconNameMax + 1} karakter`, { iconName: 'x'.repeat(LIMITS.iconNameMax + 1) }],
    [`advisor.title ${LIMITS.advisorTitleMax + 1} karakter`, { advisor: { ...ADVISOR, title: 'x'.repeat(LIMITS.advisorTitleMax + 1), userId: 'u_advisor' } }],
    [`coverSeed ${LIMITS.coverSeedMax + 1} karakter`, { coverSeed: 'x'.repeat(LIMITS.coverSeedMax + 1) }],
  ])('kimlik yamasında %s → deny', async (_title, extra) => {
    await seed();
    await assertFails(commit('super', admin.identityWrites({}, extra)));
  });

  test.each([
    [`ad ${LIMITS.clubNameMax} karakter`, { name: 'x'.repeat(LIMITS.clubNameMax), nameLower: 'x'.repeat(LIMITS.clubNameMax) }],
    [`iconName ${LIMITS.iconNameMax} karakter`, { iconName: 'x'.repeat(LIMITS.iconNameMax) }],
    [`advisor.title ${LIMITS.advisorTitleMax} karakter`, { advisor: { ...ADVISOR, title: 'x'.repeat(LIMITS.advisorTitleMax), userId: 'u_advisor' } }],
    [`coverSeed ${LIMITS.coverSeedMax} karakter`, { coverSeed: 'x'.repeat(LIMITS.coverSeedMax) }],
  ])('kimlik yamasında %s → allow (sınırın tam değeri — T-45)', async (_title, extra) => {
    await seed();
    await assertSucceeds(commit('super', admin.identityWrites({}, extra)));
  });

  // W-102 — ClubIdentityPatch.clearCoverPath: yüklenmiş kapak bırakılır (SHT-31 şablona dönüş); süper dal
  // `coverClearOk` (yalnızca null ya da eski değer — yönetim dalıyla aynı). Yeni yol yalnızca medya dalındadır.
  const COVERED = Object.freeze({ patch: { ...EDIT.patch, [`clubs/${CLUB}`]: { ...EDIT.patch[`clubs/${CLUB}`], coverPath: MEDIA_PATH(CLUB) } } });
  const TEMPLATE = Object.freeze({ palette: 'slate', pattern: 'dots', coverSeed: 'sablon-1' });
  /** Kulüp belgesinde yalnızca [data] alanları (+ `updatedAt`) — tek güncelleme. */
  const clubUpdate = (data) => ({ club: { op: 'update', path: `clubs/${CLUB}`, data: { ...data, ...payloads.baseUpdate() } } });

  test('W-102 kapak bırak: süper admin coverPath: null (şablonla; tek başına; kimlik alanlarıyla) → allow', async () => {
    await seed(COVERED);
    await assertSucceeds(commit('super', clubUpdate({ ...TEMPLATE, coverPath: null })));
    expect(await readDoc(`clubs/${CLUB}`)).toMatchObject({ coverPath: null, palette: 'slate', logoPath: null });
    await seed(COVERED);
    await assertSucceeds(commit('super', clubUpdate({ coverPath: null })));
    await seed(COVERED);
    await assertSucceeds(commit('super', admin.identityWrites({}, { ...TEMPLATE, coverPath: null })));
    expect(await readDoc(`clubs/${CLUB}`)).toMatchObject({ coverPath: null, categoryId: 'k03', name: 'Robotik Topluluğu' });
  });

  test.each([
    ['bu kulübün yeni yolu (yalnızca medya dalında)', () => MEDIA_PATH(CLUB, 'png')],
    ['başka kulübün yolu', () => MEDIA_PATH(OTHER)],
    ['desen dışı yol', () => `clubs/${CLUB}/kapak.png`],
    ['dizgi olmayan değer', () => 0],
  ])('W-102 kimlik yamasında coverPath %s → deny', async (_title, value) => {
    await seed(COVERED);
    await assertFails(commit('super', admin.identityWrites({}, { ...TEMPLATE, coverPath: value() })));
    expect(await readDoc(`clubs/${CLUB}`)).toMatchObject({ coverPath: MEDIA_PATH(CLUB) });
  });

  test.each([...CONTEXTS.filter((role) => role !== 'super'), ...VARIANTS])(
    'W-102 claim yok: %s · kimlik yaması + coverPath: null → deny',
    async (role) => {
      await seed(COVERED);
      await assertFails(commit(role, admin.identityWrites({}, { ...TEMPLATE, coverPath: null })));
      expect(await readDoc(`clubs/${CLUB}`)).toMatchObject({ coverPath: MEDIA_PATH(CLUB), name: `Test Kulübü ${CLUB}` });
    },
  );

  test('W-102 yönetici olmayan üye / danışman yalnızca coverPath: null → deny (yönetim dalı etkin yöneticiye)', async () => {
    for (const role of ['member', 'advisor', 'student']) {
      await seed(COVERED);
      await assertFails(commit(role, clubUpdate({ coverPath: null })));
    }
  });

  test('medya: süper admin askıdaki kulübün logosunu yazar; desen dışı yol → deny', async () => {
    await seed();
    await assertSucceeds(commit('super', admin.mediaWrites({ club: OTHER })));
    await assertFails(commit('super', withData(admin.mediaWrites({ club: OTHER }), 'club', { logoPath: 'clubs/c01/logo.jpg' })));
  });

  test.each([
    ['askıya al', admin.suspendClubWrites(), 'allow'],
    ['300 karakter gerekçe', admin.suspendClubWrites({ reason: 'x'.repeat(300) }), 'allow'],
    ['askıdaki kulübün gerekçesini yenile', admin.suspendClubWrites({ club: OTHER, reason: 'Yeni gerekçe.' }), 'allow'],
    ['etkinleştir', admin.activateClubWrites({ club: OTHER }), 'allow'],
    ['gerekçesiz askı', admin.suspendClubWrites({ reason: null }), 'deny'],
    ['yalnızca boşluk gerekçe', admin.suspendClubWrites({ reason: '   ' }), 'deny'],
    ['301 karakter gerekçe', admin.suspendClubWrites({ reason: 'x'.repeat(301) }), 'deny'],
    ['etkinleştirmede gerekçe kalır', withData(admin.activateClubWrites({ club: OTHER }), 'club', { suspendReason: REASON }), 'deny'],
    ['status: deleted', withData(admin.suspendClubWrites(), 'club', { status: 'deleted' }), 'deny'],
    ['askıyla birlikte başka alan (name)', withData(admin.suspendClubWrites(), 'club', { name: 'Başka' }), 'deny'],
  ])('kulüp %s → %s', async (_title, writes, expected) => {
    await seed();
    await expectWrite(commit('super', writes), expected);
  });
});

// ── 3. Başkan atama ve M13 ───────────────────────────────────────────────────────────────────

describe('admin · assignPresident yeni hedef (§4 a.3, W-94, W-90)', () => {
  test('üyeliği olmayan hedef: tek işlemde president + contact, eski başkan board, presidentId + memberCount +1, yan belge hedefi gösterir', async () => {
    await seed();
    await assertSucceeds(commit('super', admin.assignWrites()));
    expect(await readDoc(`clubs/${CLUB}`)).toMatchObject({ presidentId: 'u_student', memberCount: BASE_COUNT + 1 });
    expect(await readDoc(`memberships/${CLUB}_u_student`)).toMatchObject({ status: 'active', role: 'president', decidedBy: ADMIN });
    expect(await readDoc(`memberships/${CLUB}_u_president`)).toMatchObject({ status: 'active', role: 'board' });
    expect(await readDoc(`clubs/${CLUB}/private/counter`)).toMatchObject({ lastMembershipRef: `memberships/${CLUB}_u_student` });
    expect(await readDoc(`memberships/${CLUB}_u_student/private/contact`)).toMatchObject({ email: 'student@ogr.gumushane.edu.tr' });
  });

  test('geçmiş üye (left) hedef: üyelik yeniden etkinleşir, priorCount ve başvuru notu korunur', async () => {
    await seed({ patch: { ...EDIT.patch, [`memberships/${CLUB}_u_former`]: { priorCount: 2 }, [`memberships/${CLUB}_u_former/private/contact`]: { note: 'Eski not.' } } });
    await assertSucceeds(commit('super', admin.assignWrites({ to: 'u_former', existing: true, priorCount: 2 })));
    expect(await readDoc(`memberships/${CLUB}_u_former`)).toMatchObject({ status: 'active', role: 'president', priorCount: 2 });
    expect(await readDoc(`memberships/${CLUB}_u_former/private/contact`)).toMatchObject({ note: 'Eski not.' });
    expect(await readDoc(`clubs/${CLUB}`)).toMatchObject({ presidentId: 'u_former', memberCount: BASE_COUNT + 1 });
  });

  test('silinmiş eski başkan da board olur (W-90)', async () => {
    await seed({ patch: { ...EDIT.patch, 'users/u_president': { status: 'deleted' } } });
    await assertSucceeds(commit('super', admin.assignWrites()));
  });

  const W = () => admin.assignWrites();
  test.each([
    ['yan belge yok', () => omit(W(), 'counter')],
    ['yan belge başka üyeliği gösterir', () => withData(W(), 'counter', { lastMembershipRef: `memberships/${CLUB}_u_member` })],
    ['sayaç artmaz', () => dropField(W(), 'club', 'memberCount')],
    ['sayaç +2', () => withData(W(), 'club', { memberCount: increment(2) })],
    ['eski başkan board olmaz (iki başkan)', () => omit(W(), 'from')],
    ['hedefin contact belgesi yok', () => omit(W(), 'contact')],
    ['hedef üyelik yazılmaz', () => omit(W(), 'to', 'contact')],
    ['hedef üyelik board rolünde', () => withData(W(), 'to', { role: 'board' })],
    ['hedefin bekleyen başvurusu (pending)', () => admin.assignWrites({ to: 'u_pending', existing: true })],
    ['hedef zaten etkin üye (sayaçlı yol yerine M11)', () => admin.assignWrites({ to: 'u_member', existing: true })],
    ['hedefin profil belgesi yok', () => admin.assignWrites({ to: 'u_outside' })],
  ])('%s → deny', async (_title, build) => {
    await seed();
    await assertFails(commit('super', build()));
    expect(await readDoc(`clubs/${CLUB}`)).toMatchObject({ presidentId: 'u_president', memberCount: BASE_COUNT });
  });

  test('hedefin hesabı askıda → deny', async () => {
    await seed({ patch: { ...EDIT.patch, 'users/u_student': { status: 'suspended' } } });
    await assertFails(commit('super', admin.assignWrites()));
  });
});

describe('admin · setAdvisor (M13; §4 a.4, K-A)', () => {
  test('bağla (üyeliği yok): üyelik active/advisor, advisor.userId, ad / ünvan ve sayaç değişmez', async () => {
    await seed();
    const before = await readDoc(`clubs/${OTHER}`);
    await assertSucceeds(commit('super', admin.advisorLinkWrites({ club: OTHER })));
    expect(await readDoc(`clubs/${OTHER}`)).toMatchObject({ advisor: { ...ADVISOR, userId: 'u_student' }, memberCount: before.memberCount });
    expect(await readDoc(`memberships/${OTHER}_u_student`)).toMatchObject({ status: 'active', role: 'advisor', decidedBy: null });
  });

  test('bağla (geçmiş üyelik) → allow; kaldır → üyelik left, advisor.userId null', async () => {
    await seed({ patch: { ...EDIT.patch, [`clubs/${CLUB}`]: { advisor: { ...ADVISOR, userId: null } } } });
    await assertSucceeds(commit('super', admin.advisorLinkWrites({ uid: 'u_former', existing: true })));
    await assertSucceeds(commit('super', admin.advisorUnlinkWrites({ uid: 'u_former' })));
    expect(await readDoc(`clubs/${CLUB}`)).toMatchObject({ advisor: { ...ADVISOR, userId: null } });
    expect(await readDoc(`memberships/${CLUB}_u_former`)).toMatchObject({ status: 'left', role: 'advisor' });
  });

  test('bayat bağ (güvenlik incelemesi T-37): danışman hesabını sildi, üyelik zaten left → bağ tek başına ayrılır, '
    + 'sonra yeni danışman bağlanır; etkin danışmanın bağı üyeliksiz ayrılmaz', async () => {
    await seed();
    await assertFails(commit('super', omit(admin.advisorUnlinkWrites(), 'membership')));
    await seed({ patch: { ...EDIT.patch, [`memberships/${CLUB}_u_advisor`]: { status: 'left' } } });
    await assertFails(commit('super', admin.advisorLinkWrites({ club: CLUB })));
    await assertSucceeds(commit('super', omit(admin.advisorUnlinkWrites(), 'membership')));
    await assertSucceeds(commit('super', admin.advisorLinkWrites({ club: CLUB })));
    expect(await readDoc(`clubs/${CLUB}`)).toMatchObject({ advisor: { ...ADVISOR, userId: 'u_student' } });
    expect(await readDoc(`memberships/${CLUB}_u_advisor`)).toMatchObject({ status: 'left', role: 'advisor' });
  });

  test('kulüp kaydı bağlı değilken (tutarsız seed) danışman üyeliği yine kapanır', async () => {
    await seedFixture('base');
    await assertSucceeds(commit('super', admin.advisorUnlinkWrites({ clubLinked: false })));
  });

  const L = () => admin.advisorLinkWrites({ club: OTHER });
  test.each([
    ['başka hesap bağlıyken bağlama (önce kaldır)', () => admin.advisorLinkWrites({ club: CLUB })],
    ['üyelik yazılmadan bağ', () => omit(L(), 'membership', 'contact')],
    ['bağ yazılmadan üyelik', () => omit(L(), 'club')],
    ['contact yok', () => omit(L(), 'contact')],
    ['danışman adı da değişir', () => withData(L(), 'club', { 'advisor.name': 'Başka Ad' })],
    ['sayaç oynar', () => withData(L(), 'club', { memberCount: increment(1) })],
    ['üyelik president rolünde', () => withData(L(), 'membership', { role: 'president' })],
    ['kaldırmada üyelik left olmadan bağ kopar', () => omit(admin.advisorUnlinkWrites(), 'membership')],
    ['kaldırmada üyelik removed olur', () => withData(admin.advisorUnlinkWrites(), 'membership', { status: 'removed' })],
  ])('%s → deny', async (_title, build) => {
    await seed();
    await assertFails(commit('super', build()));
  });

  test('danışman kaydı olmayan kulüpte bağlama → deny', async () => {
    await seed({ patch: { ...EDIT.patch, [`clubs/${OTHER}`]: { advisor: null } } });
    await assertFails(commit('super', admin.advisorLinkWrites({ club: OTHER })));
  });
});

// ── 4. Kullanıcı askısı ──────────────────────────────────────────────────────────────────────

describe('admin · suspendUser / activateUser (§4 a.5, CD-133)', () => {
  test.each([
    ['askıya al (users + account tek batch)', admin.suspendUserWrites(), 'allow'],
    ['askıdaki hesabın gerekçesini yenile', admin.suspendUserWrites({ uid: 'u_susp', reason: 'Yeni gerekçe.' }), 'allow'],
    ['etkinleştir', admin.activateUserWrites(), 'allow'],
    ['yalnızca users (eksik parça)', omit(admin.suspendUserWrites(), 'account'), 'deny'],
    ['yalnızca account (eksik parça)', omit(admin.suspendUserWrites(), 'user'), 'deny'],
    ['etkinleştirmede yalnızca users', omit(admin.activateUserWrites(), 'account'), 'deny'],
    ['gerekçesiz askı', admin.suspendUserWrites({ reason: null }), 'deny'],
    ['yalnızca boşluk gerekçe', admin.suspendUserWrites({ reason: ' ' }), 'deny'],
    ['301 karakter gerekçe', admin.suspendUserWrites({ reason: 'x'.repeat(301) }), 'deny'],
    ['etkinleştirmede gerekçe kalır', admin.suspendUserWrites({ uid: 'u_susp', status: 'active' }), 'deny'],
    ['silinmiş hesap askıya alınmaz', admin.suspendUserWrites({ uid: 'u_deleted' }), 'deny'],
    ['silinmiş hesap etkinleştirilmez', admin.activateUserWrites({ uid: 'u_deleted' }), 'deny'],
    ['süper admin status: deleted yazamaz', admin.suspendUserWrites({ status: 'deleted', reason: null }), 'deny'],
    ['gerekçe users belgesine yazılır (CD-133)', withData(admin.suspendUserWrites(), 'user', { suspendReason: REASON }), 'deny'],
    ['askıyla birlikte e-posta değişir', withData(admin.suspendUserWrites(), 'account', { email: 'x@ogr.gumushane.edu.tr' }), 'deny'],
  ])('%s → %s', async (_title, writes, expected) => {
    await seed();
    await expectWrite(commit('super', writes), expected);
  });

  test('süper admin kendi hesabını askıya alamaz; askıya alınmış süper admin (claim duruyor) kendi askısını '
    + 'kaldıramaz (güvenlik incelemesi T-37)', async () => {
    await seed();
    await assertFails(commit('super', admin.suspendUserWrites({ uid: 'u_super' })));
    await seed({ patch: { ...EDIT.patch, 'users/u_super': { status: 'suspended' }, 'users/u_super/private/account': { suspendReason: REASON } } });
    await assertFails(commit('super', admin.activateUserWrites({ uid: 'u_super' })));
    await assertFails(updateDoc(doc(dbOf('super'), 'users/u_super/private/account'), { suspendReason: null, ...payloads.baseUpdate() }));
    expect(await readDoc('users/u_super')).toMatchObject({ status: 'suspended' });
  });

  test('askıdaki kullanıcı kendi askısını kaldıramaz (users.status + account.suspendReason)', async () => {
    await seed();
    await assertFails(commit('susp', admin.activateUserWrites()));
    expect(await readDoc('users/u_susp')).toMatchObject({ status: 'suspended' });
  });
});

// ── 5. Şikayet grubu çözümü ──────────────────────────────────────────────────────────────────

describe('admin · resolveReports (grup tek batch; §4 a.6, W-84)', () => {
  test('removed: iki şikayet + gizleme + şikayetçi başına report_resolved → allow; durum', async () => {
    await seed();
    await assertSucceeds(commit('super', admin.resolveWrites({ reporters: ['u_member', 'u_board'] })));
    for (const reporter of ['u_member', 'u_board']) {
      expect(await readDoc(`reports/${reporter}_post_p01`)).toMatchObject({ status: 'resolved', action: 'removed', resolvedBy: ADMIN });
      expect(await readDoc(payloads.notificationPath('report_resolved', payloads.EVENT_KEY, reporter))).toMatchObject({
        userId: reporter,
        type: 'report_resolved',
        refs: { reportId: 'post_p01' },
      });
    }
    expect(await readDoc('posts/p01')).toMatchObject({ isHidden: true, hiddenBy: ADMIN });
  });

  const R = (extra) => admin.resolveWrites({ reporters: ['u_member'], type: 'user', id: 'u_student', ...extra });
  test.each([
    ['dismissed (yan yazım yok)', () => R({ action: 'dismissed' }), 'allow'],
    ['suspended (askı ayrı çağrıdır — §4 g-2)', () => R({ action: 'suspended' }), 'allow'],
    ['removed gizleme olmadan (eksik parça)', () => admin.resolveWrites({ reporters: ['u_member', 'u_board'], hide: false }), 'deny'],
    ['removed kullanıcı hedefinde (yalnızca gönderi / yorum)', () => R({ action: 'removed', hide: false }), 'deny'],
    ['bilinmeyen işlem', () => R({ action: 'deleted' }), 'deny'],
    ['resolvedBy başkası', () => withData(R({ action: 'dismissed' }), 'report_u_member', { resolvedBy: 'u_board' }), 'deny'],
    ['istemci saati (resolvedAt)', () => withData(R({ action: 'dismissed' }), 'report_u_member', { resolvedAt: Timestamp.now() }), 'deny'],
    ['şikayet notu değişir', () => withData(R({ action: 'dismissed' }), 'report_u_member', { note: 'Değişti.' }), 'deny'],
  ])('%s → %s', async (_title, build, expected) => {
    await seed();
    await expectWrite(commit('super', build()), expected);
  });

  test('çözülmüş şikayet yeniden çözülmez; hedef zaten gizliyse removed gizlemesiz geçer (parçalı çözümün sonraki parçası)', async () => {
    await seed();
    await assertSucceeds(commit('super', admin.resolveWrites({ reporters: ['u_member'] })));
    await assertFails(commit('super', admin.resolveWrites({ reporters: ['u_member'], hide: false, key: payloads.EVENT_KEY_2 })));
    await assertSucceeds(commit('super', admin.resolveWrites({ reporters: ['u_board'], hide: false, key: payloads.EVENT_KEY_2 })));
  });

  const notice = (refs, path) => ({
    n: { op: 'set', path: path || payloads.notificationPath('report_resolved', payloads.EVENT_KEY, 'u_member'), data: payloads.notificationCreate('report_resolved', 'u_member', refs) },
  });
  test.each([
    ['süper admin, tek bildirim (alıcı ↔ şikayet bağı aranmaz — §4 a.6)', 'super', notice({ reportId: 'post_p01' }), 'allow'],
    ['yorum / kulüp / etkinlik grup anahtarı', 'super', notice({ reportId: 'comment_cm01' }), 'allow'],
    ['kulüp yöneticisi', 'president', notice({ reportId: 'post_p01' }), 'deny'],
    ['şikayetçinin kendisi', 'member', notice({ reportId: 'post_p01' }), 'deny'],
    ['grup anahtarı biçimsiz (şikayet kimliği)', 'super', notice({ reportId: 'u_member_post_p01' }), 'deny'],
    ['refs fazladan clubId', 'super', notice({ reportId: 'post_p01', clubId: CLUB }), 'deny'],
    ['sabit kimlik (rastgele olay anahtarı değil)', 'super', notice({ reportId: 'post_p01' }, 'notifications/report_resolved_post_p01_u_member'), 'deny'],
  ])('report_resolved: %s (%s) → %s', async (_title, role, writes, expected) => {
    await seed();
    await expectWrite(commit(role, writes), expected);
  });
});

// ── 6. collectionGroup('private') ────────────────────────────────────────────────────────────

describe('admin · collectionGroup(private) e-posta araması (ADM-05; §4 b)', () => {
  test('süper admin: emailLower öneki account ve contact belgelerini döndürür (istemci yalnızca users/*/private/account alır)', async () => {
    await seed();
    const snapshot = await assertSucceeds(emailSearch(dbOf('super')));
    expect(snapshot.docs.map((d) => d.ref.path).sort()).toEqual([`memberships/${CLUB}_u_member/private/contact`, 'users/u_member/private/account']);
  });

  test('başka private belgeleri açılmaz: sahibi kendi alt koleksiyonunu listeleyemez, yönetici / üye tekil okuyamaz', async () => {
    await seed();
    await assertFails(getDocs(collection(dbOf('member'), 'users/u_member/private')));
    await assertFails(getDoc(doc(dbOf('student'), 'users/u_member/private/account')));
    await assertFails(getDoc(doc(dbOf('member'), `clubs/${CLUB}/private/counter`)));
    await assertFails(getDoc(doc(dbOf('member'), 'events/e_live/private/counter')));
    await assertFails(getDoc(doc(dbOf('member'), `memberships/${CLUB}_u_board/private/contact`)));
    await assertFails(getDocs(collectionGroup(dbOf('president'), 'private')));
    // Kendi tekil okumaları kendi match'lerinde kalır (sahibi hesabını, yönetim contact'ı okur).
    await assertSucceeds(getDoc(doc(dbOf('member'), 'users/u_member/private/account')));
    await assertSucceeds(getDoc(doc(dbOf('board'), `memberships/${CLUB}_u_member/private/contact`)));
  });
});

// ── 7. Askının etkisi ────────────────────────────────────────────────────────────────────────

describe('admin · askının etkisi (roadmap: askıdaki kulüpte yazım ret, askıdaki kullanıcı yazamaz; §4 c)', () => {
  test('askıdaki kulüp: yayın, etkinlik, ayar, başvuru, onay ve katılım reddedilir; etkinleştirilince yayın geçer', async () => {
    await seedFixture('base');
    await assertSucceeds(commit('super', admin.suspendClubWrites()));
    await assertFails(commit('board', payloads.createPostWrites({ club: CLUB, uid: 'u_board' })));
    await assertFails(commit('board', payloads.createEventWrites({ club: CLUB, uid: 'u_board' })));
    await assertFails(commit('president', payloads.settingsWrites({ club: CLUB, uid: 'u_president' })));
    await assertFails(commit('student', payloads.applyWrites({ club: CLUB, uid: 'u_student', email: payloads.emailOf('student') })));
    await assertFails(commit('board', payloads.approveWrites({ club: CLUB, uid: 'u_board' })));
    await assertFails(commit('student', payloads.rsvpJoinWrites({ club: CLUB, uid: 'u_student' })));
    expect(await readDoc(`clubs/${CLUB}`)).toMatchObject({ status: 'suspended', suspendReason: REASON });
    await assertSucceeds(commit('super', admin.activateClubWrites()));
    await assertSucceeds(commit('board', payloads.createPostWrites({ club: CLUB, uid: 'u_board' })));
  });

  test('askıdaki kullanıcı: yorum, şikayet, başvuru, katılım ve profil yazımı reddedilir; etkinleştirilince yorum geçer', async () => {
    await seedFixture('base');
    await assertSucceeds(commit('super', admin.suspendUserWrites()));
    await assertFails(commit('member', payloads.addCommentWrites({ club: CLUB, uid: 'u_member' })));
    await assertFails(commit('member', payloads.reportWrites({ uid: 'u_member', target: { type: 'post', id: 'p02', clubId: CLUB } })));
    await assertFails(commit('member', payloads.applyWrites({ club: OTHER, uid: 'u_member', email: payloads.emailOf('member') })));
    await assertFails(commit('member', payloads.rsvpJoinWrites({ club: CLUB, uid: 'u_member', eventId: 'e_members' })));
    await assertFails(updateDoc(doc(dbOf('member'), 'users/u_member'), payloads.userProfileUpdate('u_member')));
    // Askı gerekçesini sahibi okur (DLG-01 / SuspendedAccountMixin), başkası okuyamaz.
    expect((await assertSucceeds(getDoc(doc(dbOf('member'), 'users/u_member/private/account')))).data()).toMatchObject({ suspendReason: REASON });
    await assertSucceeds(commit('super', admin.activateUserWrites({ uid: 'u_member' })));
    await assertSucceeds(commit('member', payloads.addCommentWrites({ club: CLUB, uid: 'u_member' })));
  });
});
