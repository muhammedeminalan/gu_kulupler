'use strict';
// Sorgu sözleşmesi (rules-spec §1.7, §6; PLAN §11.4): repository'lerin koştuğu GERÇEK sorgular
// (aynı `where` / `orderBy`) kurallar AÇIKKEN koşulur ve her sorgunun bileşik indeksi
// `firebase/firestore.indexes.json` içinde aranır. Emülatör eksik indekste hata vermez; bu yüzden indeks
// dosyası burada ayrıca denetlenir (eksik indeks üretimde `failed-precondition` olur).
// Rol × liste matrisi ve süzgeçsiz ikizler koleksiyon dosyalarındadır (`expectations/*.json`); burada
// sorgu BİÇİMLERİ sınanır.
//
// T-15: CLB-01 / getClubs · oturum üyelikleri / listMine · CLB-06 / MGT-03 / listManagers · MGT-02 ·
// MGT-10 · ADM-04 · SET-02. T-19 (FED-01/02, MGT-08, PRF-04), T-22 (EVT-01, MGT-04, EVT-04, MGT-06) ve
// T-25 (`listByInterests`) kendi satırlarını ekler.
const path = require('node:path');
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { collection, doc, documentId, getDoc, getDocs, limit, orderBy, query, where } = require('firebase/firestore');
const { contextFor, CLUB, OTHER_CLUB } = require('../helpers/contexts');
const { seedFixture } = require('../helpers/fixtures');

const indexes = require(path.resolve(__dirname, '..', '..', 'firestore.indexes.json')).indexes;

/** Sorgu tanımı: { collection, equals: [alan…], inField?, order?: [alan, 'asc'|'desc'] }. */
const QUERIES = Object.freeze({
  listMineByStatus: { collection: 'memberships', equals: ['userId'], inField: 'status' },
  listActiveMembers: { collection: 'memberships', equals: ['clubId', 'status'], order: ['appliedAt', 'desc'] },
  listPending: { collection: 'memberships', equals: ['clubId', 'status'], order: ['appliedAt', 'desc'] },
  listActiveMembersByRole: { collection: 'memberships', equals: ['clubId', 'status', 'role'] },
  listManagers: { collection: 'memberships', equals: ['clubId', 'status'], inField: 'role' },
  listActivity: { collection: 'activity', equals: ['clubId'], order: ['createdAt', 'desc'] },
  listActivityByCategory: { collection: 'activity', equals: ['clubId'], inField: 'kind', order: ['createdAt', 'desc'] },
  listOpenReports: { collection: 'reports', equals: ['status'], order: ['createdAt', 'desc'] },
  listReportsForTarget: { collection: 'reports', equals: ['targetType', 'targetId', 'status'] },
  fetchActiveBlocks: { collection: 'blocks', equals: ['blockerId', 'isDeleted'] },
});

/**
 * Sorguyu karşılayan bileşik indeks: eşitlik (ve `in`) alanları herhangi bir sırayla başta, sıralama alanı
 * yönüyle sonda.
 */
function hasIndex(spec) {
  const equality = [...spec.equals, ...(spec.inField ? [spec.inField] : [])].sort();
  return indexes.some((index) => {
    if (index.collectionGroup !== spec.collection || index.queryScope !== 'COLLECTION') return false;
    const fields = index.fields.map((f) => [f.fieldPath, f.order]);
    const head = fields.slice(0, equality.length).map(([name]) => name).sort();
    const tail = fields.slice(equality.length);
    if (head.join() !== equality.join()) return false;
    if (!spec.order) return tail.length === 0;
    const direction = spec.order[1] === 'desc' ? 'DESCENDING' : 'ASCENDING';
    return tail.length === 1 && tail[0][0] === spec.order[0] && tail[0][1] === direction;
  });
}

const dbOf = (role) => contextFor(role).firestore();
const ids = (snapshot) => snapshot.docs.map((d) => d.id).sort();

describe('indeksler · firestore.indexes.json sorguları karşılar (PLAN §11.4 T-15 satırları)', () => {
  test.each(Object.entries(QUERIES))('%s', (_name, spec) => {
    expect(hasIndex(spec)).toBe(true);
  });

  test('her bileşik indeks tekildir ve en az iki alan taşır', () => {
    const keys = indexes.map((index) => `${index.collectionGroup}:${index.fields.map((f) => `${f.fieldPath} ${f.order}`).join(',')}`);
    expect(new Set(keys).size).toBe(keys.length);
    for (const index of indexes) expect(index.fields.length).toBeGreaterThanOrEqual(2);
  });
});

describe('clubs · sorgu biçimleri (rules-spec §6 CLB-01; PLAN §10.4 ClubRepository)', () => {
  test('fetchActiveClubs: isDeleted == false → silinmiş kulübü içermez', async () => {
    await seedFixture('base', undefined, { patch: { [`clubs/${OTHER_CLUB}`]: { isDeleted: true, deletedBy: 'u_super' } } });
    const snapshot = await assertSucceeds(getDocs(query(collection(dbOf('student'), 'clubs'), where('isDeleted', '==', false))));
    expect(ids(snapshot)).toEqual([CLUB]);
  });

  // Kimlik listeli sorgu belge belge değerlendirilir (süzgeç kanıtı aranmaz): listedeki silinmiş ya da
  // olmayan TEK kimlik sorgunun tamamını düşürür — `isDeleted == false` süzgeci de kurtarmaz. Kulüp
  // kimlikleri üyeliklerden gelir ve kulüp silme akışı yoktur (askı `status`'tur); repository yine de
  // ret halinde tekil okumaya düşebilmelidir (tekil `get` olmayan kulüpte boş döner).
  test('getClubs: documentId in […] canlı kulüplerde geçer; silinmiş ya da olmayan kimlik sorguyu düşürür (süper admin hariç)', async () => {
    await seedFixture('base');
    const byIds = (role, list) => query(collection(dbOf(role), 'clubs'), where(documentId(), 'in', list), where('isDeleted', '==', false));
    expect(ids(await assertSucceeds(getDocs(byIds('student', [CLUB, OTHER_CLUB]))))).toEqual([CLUB, OTHER_CLUB]);
    await assertFails(getDocs(byIds('student', [CLUB, 'c_missing'])));

    await seedFixture('base', undefined, { patch: { [`clubs/${OTHER_CLUB}`]: { isDeleted: true, deletedBy: 'u_super' } } });
    await assertFails(getDocs(byIds('student', [CLUB, OTHER_CLUB])));
    expect(ids(await assertSucceeds(getDocs(byIds('student', [CLUB]))))).toEqual([CLUB]);
    expect(ids(await assertSucceeds(getDocs(byIds('super', [CLUB, OTHER_CLUB]))))).toEqual([CLUB]);
  });

  test('isNameTaken (nameLower eşitliği, süzgeçsiz) yalnızca süper admine açıktır (ADM-03, T-37)', async () => {
    await seedFixture('base');
    const byName = (role) => query(collection(dbOf(role), 'clubs'), where('nameLower', '==', `test kulübü ${CLUB}`), limit(1));
    expect(ids(await assertSucceeds(getDocs(byName('super'))))).toEqual([CLUB]);
    await assertFails(getDocs(byName('president')));
  });
});

describe('memberships · sorgu biçimleri (rules-spec §6; PLAN §10.4 MembershipRepository)', () => {
  const memberships = (role) => collection(dbOf(role), 'memberships');

  test('watchMyMemberships / listMine: userId == uid (+ status in […]) yalnızca kendi belgelerini döndürür', async () => {
    await seedFixture('base');
    const mine = await assertSucceeds(getDocs(query(memberships('member'), where('userId', '==', 'u_member'))));
    expect(ids(mine)).toEqual(['c01_u_member']);
    const byStatus = query(memberships('pending'), where('userId', '==', 'u_pending'), where('status', 'in', ['active', 'pending']));
    expect(ids(await assertSucceeds(getDocs(byStatus)))).toEqual(['c01_u_pending']);
    await assertFails(getDocs(query(memberships('member'), where('userId', '==', 'u_board'), where('status', 'in', ['active']))));
  });

  test('listActiveMembers (CLB-06): üye yalnızca aktif üyelikleri görür; sonuç e-posta ve başvuru notu taşımaz (CD-137)', async () => {
    await seedFixture('base', undefined, { patch: { 'memberships/c01_u_pending/private/contact': { note: 'Gizli başvuru notu.' } } });
    const active = query(memberships('member'), where('clubId', '==', CLUB), where('status', '==', 'active'), orderBy('appliedAt', 'desc'));
    const snapshot = await assertSucceeds(getDocs(active));
    expect(ids(snapshot)).toEqual(['c01_u_advisor', 'c01_u_board', 'c01_u_deleted', 'c01_u_member', 'c01_u_president', 'c01_u_susp']);
    for (const d of snapshot.docs) {
      for (const key of ['email', 'emailLower', 'note']) expect(d.data()).not.toHaveProperty(key);
      expect(d.data().status).toBe('active');
    }
  });

  test('üye, durum süzgecini genişleterek başvuruları göremez (status in [active, pending])', async () => {
    await seedFixture('base');
    const widened = query(memberships('member'), where('clubId', '==', CLUB), where('status', 'in', ['active', 'pending']));
    await assertFails(getDocs(widened));
    await assertFails(getDocs(query(memberships('member'), where('clubId', '==', CLUB), where('status', '==', 'pending'))));
    await assertFails(getDocs(query(memberships('member'), where('clubId', '==', CLUB), where('status', '==', 'left'))));
  });

  test('listActiveMembers(role:) ve listManagers: rol süzgeçli üye listesi (üye ve yönetici)', async () => {
    await seedFixture('base');
    const byRole = query(memberships('member'), where('clubId', '==', CLUB), where('status', '==', 'active'), where('role', '==', 'board'));
    expect(ids(await assertSucceeds(getDocs(byRole)))).toEqual(['c01_u_board']);
    const managers = (role) => query(memberships(role), where('clubId', '==', CLUB), where('status', '==', 'active'), where('role', 'in', ['board', 'president']));
    expect(ids(await assertSucceeds(getDocs(managers('board'))))).toEqual(['c01_u_board', 'c01_u_president']);
  });

  test('listManagers (CD-139): üye olmayan aktif kullanıcı yalnızca etkin yöneticileri okur; üye listesi ve başvurular kapalı kalır', async () => {
    await seedFixture('base', undefined, { patch: { 'memberships/c01_u_pending/private/contact': { note: 'Gizli başvuru notu.' } } });
    const inClub = (role, ...filters) => query(memberships(role), where('clubId', '==', CLUB), ...filters);
    const active = where('status', '==', 'active');
    const managers = (role) => inClub(role, active, where('role', 'in', ['board', 'president']));
    // Üye olmayan, eski üye, başvuran ve başka kulübün yöneticisi: aynı iki belge (CLB-03 "Yönetim kurulu", kulüp kartı).
    for (const role of ['student', 'former', 'pending', 'otherManager']) {
      const snapshot = await assertSucceeds(getDocs(managers(role)));
      expect(ids(snapshot)).toEqual(['c01_u_board', 'c01_u_president']);
      for (const d of snapshot.docs) {
        for (const key of ['email', 'emailLower', 'note']) expect(d.data()).not.toHaveProperty(key);
        expect(d.data().status).toBe('active');
      }
    }
    // Danışman da görünür yöneticidir (rol süzgeci üç role kadar genişler).
    const withAdvisor = inClub('student', active, where('role', 'in', ['president', 'board', 'advisor']));
    expect(ids(await assertSucceeds(getDocs(withAdvisor)))).toEqual(['c01_u_advisor', 'c01_u_board', 'c01_u_president']);

    // Tam üye listesi, sıradan üyeler ve başvurular üye olmayana kapalıdır; süzgeç eksilirse / genişlerse sorgu reddedilir.
    await assertFails(getDocs(inClub('student', active)));
    await assertFails(getDocs(inClub('student', active, where('role', '==', 'member'))));
    await assertFails(getDocs(inClub('student', active, where('role', 'in', ['board', 'president', 'member']))));
    await assertFails(getDocs(inClub('student', where('role', 'in', ['board', 'president']))));
    await assertFails(getDocs(inClub('student', where('status', '==', 'pending'), where('role', 'in', ['board', 'president']))));
    await assertFails(getDocs(inClub('student')));
    await assertFails(getDocs(memberships('student')));
    await assertFails(getDoc(doc(dbOf('student'), 'memberships/c01_u_member')));
    await assertFails(getDoc(doc(dbOf('student'), 'memberships/c01_u_pending')));

    // `private/contact` yönetici belgesinde de kapalı kalır (e-posta sızmaz).
    await assertSucceeds(getDoc(doc(dbOf('student'), 'memberships/c01_u_board')));
    await assertFails(getDoc(doc(dbOf('student'), 'memberships/c01_u_board/private/contact')));

    // Doğrulanmamış, alan adı dışı ve oturumsuz istek reddedilir.
    for (const role of ['anon', 'unver', 'outsideDomain']) await assertFails(getDocs(managers(role)));
  });

  test('listManagers (CD-139): askıdaki ya da profili eksik (üye olmayan) kullanıcı yönetici listesini okuyamaz', async () => {
    const managers = query(memberships('student'), where('clubId', '==', CLUB), where('status', '==', 'active'), where('role', 'in', ['board', 'president']));
    await seedFixture('base', undefined, { patch: { 'users/u_student': { status: 'suspended' } } });
    await assertFails(getDocs(managers));
    await seedFixture('base', undefined, { patch: { 'users/u_student': { profileComplete: false } } });
    await assertFails(getDocs(managers));
    await seedFixture('base');
    await assertSucceeds(getDocs(managers));
  });

  test('listPending (MGT-02): yönetim başvuruları sıralı okur; başka kulübün yöneticisi kendi kulübünü okur, c01\'i okuyamaz', async () => {
    await seedFixture('base');
    const pendingOf = (role, club) => query(memberships(role), where('clubId', '==', club), where('status', '==', 'pending'), orderBy('appliedAt', 'desc'));
    expect(ids(await assertSucceeds(getDocs(pendingOf('board', CLUB))))).toEqual(['c01_u_pending']);
    expect(ids(await assertSucceeds(getDocs(pendingOf('otherManager', OTHER_CLUB))))).toEqual([]);
    await assertFails(getDocs(pendingOf('otherManager', CLUB)));
    // Yönetici kendi kulübü dışına taşan sorgu kuramaz.
    await assertFails(getDocs(query(memberships('board'), where('clubId', 'in', [CLUB, OTHER_CLUB]), where('status', '==', 'pending'))));
  });
});

describe('activity · sorgu biçimleri (rules-spec §6 MGT-10; PLAN §10.4 ActivityRepository.listActivity)', () => {
  test('clubId (+ kind in […]) createdAt azalan: yönetim okur; başka kulübün günlüğü ve kulüpsüz sorgu reddedilir', async () => {
    await seedFixture('base');
    const activity = (role) => collection(dbOf(role), 'activity');
    const all = query(activity('board'), where('clubId', '==', CLUB), orderBy('createdAt', 'desc'));
    expect(ids(await assertSucceeds(getDocs(all)))).toEqual(['a01']);
    const byKind = query(activity('advisor'), where('clubId', '==', CLUB), where('kind', 'in', ['post_created', 'announcement', 'poll']), orderBy('createdAt', 'desc'));
    expect(ids(await assertSucceeds(getDocs(byKind)))).toEqual(['a01']);
    await assertFails(getDocs(query(activity('otherManager'), where('clubId', '==', CLUB), orderBy('createdAt', 'desc'))));
    // `clubId` süzgeci olmayan tür sorgusu (ADM-01 grafiği, T-38) yalnızca süper admine açıktır.
    await assertFails(getDocs(query(activity('board'), where('kind', 'in', ['member_joined']), orderBy('createdAt', 'desc'))));
    await assertSucceeds(getDocs(query(activity('super'), where('kind', 'in', ['member_joined']), orderBy('createdAt', 'desc'))));
  });
});

describe('reports ve blocks · sorgu biçimleri (rules-spec §6 ADM-04, SET-02)', () => {
  test('listOpenReports / listReportsForTarget yalnızca süper admine; şikayetçi kendi belgelerini okur', async () => {
    await seedFixture('base');
    const reports = (role) => collection(dbOf(role), 'reports');
    const open = (role) => query(reports(role), where('status', '==', 'open'), orderBy('createdAt', 'desc'));
    const forTarget = (role) => query(reports(role), where('targetType', '==', 'post'), where('targetId', '==', 'p01'), where('status', '==', 'open'));
    expect(ids(await assertSucceeds(getDocs(open('super'))))).toEqual(['u_member_post_p01']);
    expect(ids(await assertSucceeds(getDocs(forTarget('super'))))).toEqual(['u_member_post_p01']);
    await assertFails(getDocs(forTarget('president')));
    await assertFails(getDocs(forTarget('member')));
    expect(ids(await assertSucceeds(getDocs(query(reports('member'), where('reporterId', '==', 'u_member')))))).toEqual(['u_member_post_p01']);
  });

  test('fetchActiveBlocks (SET-02): blockerId == uid, isDeleted == false → kaldırılmış engel dönmez', async () => {
    await seedFixture('base', undefined, {
      patch: { 'blocks/u_member_u_student': { isDeleted: true, deletedBy: 'u_member' } },
    });
    const active = (role, uid) => query(collection(dbOf(role), 'blocks'), where('blockerId', '==', uid), where('isDeleted', '==', false));
    expect(ids(await assertSucceeds(getDocs(active('member', 'u_member'))))).toEqual([]);
    expect(ids(await assertSucceeds(getDocs(active('susp', 'u_susp'))))).toEqual(['u_susp_u_student']);
    // Engellenen kullanıcı kendisini engelleyenleri sorgulayamaz.
    await assertFails(getDocs(query(collection(dbOf('student'), 'blocks'), where('blockedId', '==', 'u_student'), where('isDeleted', '==', false))));
  });
});
