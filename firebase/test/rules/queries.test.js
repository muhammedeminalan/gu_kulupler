'use strict';
// Sorgu sözleşmesi (rules-spec §1.7, §6; PLAN §11.4): repository'lerin koştuğu GERÇEK sorgular
// (aynı `where` / `orderBy`) kurallar AÇIKKEN koşulur ve her sorgunun bileşik indeksi
// `firebase/firestore.indexes.json` içinde aranır. Emülatör eksik indekste hata vermez; bu yüzden indeks
// dosyası burada ayrıca denetlenir (eksik indeks üretimde `failed-precondition` olur).
// Rol × liste matrisi ve süzgeçsiz ikizler koleksiyon dosyalarındadır (`expectations/*.json`); burada
// sorgu BİÇİMLERİ sınanır.
//
// T-15: CLB-01 / getClubs · oturum üyelikleri / listMine · CLB-06 / MGT-03 / listManagers · MGT-02 ·
// MGT-10 · ADM-04 · SET-02. T-19: FED-01 / listFeed · MGT-08 / listForManagement · FED-02 / watchComments ·
// PRF-04 / listSaved · countVotes. T-22: EVT-01 / listPublicUpcoming · listMembersUpcoming · MGT-04 / CLB-03 /
// listClubEvents (üç biçim) · EVT-04 / listMine · MGT-06 katılımcılar · waitlistPosition · findByTicket.
// T-25: NTF-01 / watchInbox (`notifications`) · CD-38 / listByInterests (`users`, `interests` CONTAINS).
// Gelen kutusunun rol × liste matrisi `expectations/notifications.json`, sorgu biçimi `notifications.test.js`.
const path = require('node:path');
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { collection, doc, documentId, getCountFromServer, getDoc, getDocs, limit, orderBy, query, where } = require('firebase/firestore');
const { contextFor, CLUB, OTHER_CLUB } = require('../helpers/contexts');
const { fromNow, eventDoc, rsvpDoc, seedDocs, seedFixture, DAY_MS, HOUR_MS } = require('../helpers/fixtures');

const indexes = require(path.resolve(__dirname, '..', '..', 'firestore.indexes.json')).indexes;

/** Sorgu tanımı: { collection, equals: [alan…], inField?, order?: [alan, 'asc'|'desc'] }. */
const QUERIES = Object.freeze({
  listMineByStatus: { collection: 'memberships', equals: ['userId'], inField: 'status' },
  listActiveMembers: { collection: 'memberships', equals: ['clubId', 'status'], order: ['appliedAt', 'desc'] },
  listPending: { collection: 'memberships', equals: ['clubId', 'status'], order: ['appliedAt', 'desc'] },
  // T-33 (W-98): `listByStatus` — MGT-02 "Reddedilen"; `listPending` ile aynı indeks.
  listByStatus: { collection: 'memberships', equals: ['clubId', 'status'], order: ['appliedAt', 'desc'] },
  listActiveMembersByRole: { collection: 'memberships', equals: ['clubId', 'status', 'role'] },
  listManagers: { collection: 'memberships', equals: ['clubId', 'status'], inField: 'role' },
  listActivity: { collection: 'activity', equals: ['clubId'], order: ['createdAt', 'desc'] },
  listActivityByCategory: { collection: 'activity', equals: ['clubId'], inField: 'kind', order: ['createdAt', 'desc'] },
  listOpenReports: { collection: 'reports', equals: ['status'], order: ['createdAt', 'desc'] },
  listReportsForTarget: { collection: 'reports', equals: ['targetType', 'targetId', 'status'] },
  fetchActiveBlocks: { collection: 'blocks', equals: ['blockerId', 'isDeleted'] },
  // T-19 (sözleşme docs/plans/T-19.md §6.e)
  listFeed: { collection: 'posts', equals: ['clubId', 'isDeleted', 'isHidden'], order: ['createdAt', 'desc'] },
  listForManagement: { collection: 'posts', equals: ['clubId', 'isDeleted'], order: ['createdAt', 'desc'] },
  watchComments: { collection: 'comments', equals: ['postId', 'clubId', 'isDeleted', 'isHidden'], order: ['createdAt', 'asc'] },
  listSaved: { collection: 'savedPosts', equals: ['userId', 'isDeleted'], order: ['savedAt', 'desc'] },
  // T-22 (sözleşme docs/plans/T-22.md §6.8) — `startsAt >= from` aralığı sıralama alanıyla aynıdır.
  listPublicUpcoming: { collection: 'events', equals: ['visibility', 'isDeleted'], inField: 'status', order: ['startsAt', 'asc'] },
  listMembersUpcoming: { collection: 'events', equals: ['clubId', 'visibility', 'isDeleted'], inField: 'status', order: ['startsAt', 'asc'] },
  listClubEventsManagement: { collection: 'events', equals: ['clubId', 'isDeleted'], order: ['startsAt', 'desc'] },
  listClubEventsMember: { collection: 'events', equals: ['clubId', 'isDeleted'], inField: 'status', order: ['startsAt', 'desc'] },
  listClubEventsPublic: { collection: 'events', equals: ['clubId', 'visibility', 'isDeleted'], inField: 'status', order: ['startsAt', 'desc'] },
  listMyRsvps: { collection: 'rsvps', equals: ['userId', 'isDeleted'], order: ['createdAt', 'desc'] },
  // `waitlistPosition` (`waitlistAt < t` aralığı) ve T-30 `watchParticipants` (`orderBy status, waitlistAt`) aynı indeksi kullanır.
  waitlistPosition: { collection: 'rsvps', equals: ['eventId', 'clubId', 'status'], order: ['waitlistAt', 'asc'] },
  // T-25 (sözleşme docs/plans/T-25.md §6.g)
  watchInbox: { collection: 'notifications', equals: ['userId', 'isDeleted'], order: ['createdAt', 'desc'] },
  // T-28: SupportRepository.listMine (talepler soft delete edilmez — `isDeleted` süzgeci istemcide).
  listMyTickets: { collection: 'supportTickets', equals: ['userId'], order: ['createdAt', 'desc'] },
  // T-37 (sözleşme docs/plans/T-37.md §4 a.7, a.8, b): AdminRepository.stats yaklaşan etkinlik sayımı (`startsAt >= şimdi`
  // aralığı = sıralama alanı) · listUsersByName (`nameLower` önek aralığı) · listReports (`status` + `createdAt↓`).
  // Kulüp / kullanıcı / şikayet sayımları ve listManagerUserIds yalnızca eşitlik süzgecidir (tek alan indeksleri).
  adminUpcomingEvents: { collection: 'events', equals: ['status', 'isDeleted'], order: ['startsAt', 'asc'] },
  listUsersByName: { collection: 'users', equals: ['isDeleted'], order: ['nameLower', 'asc'] },
  listReports: { collection: 'reports', equals: ['status'], order: ['createdAt', 'desc'] },
  // T-38 (CD-46): ActivityRepository.countByWeek — ADM-01 grafiği, `clubId` süzgeci yok (`createdAt` aralığı = sıralama alanı).
  countByWeek: { collection: 'activity', equals: [], inField: 'kind', order: ['createdAt', 'desc'] },
  // T-42 (Mod F, sözleşme docs/plans/T-42.md §4 b; CD-165): Cloud Functions sorguları — Admin SDK Rules'u atlar ama
  // bileşik indeks yine gerekir. `promoteWaitlistOnCancel` en eski bekleyen (`waitlistPosition` indeksi) ·
  // `notifyNewReport` aynı hedefin açık şikayetleri (`listReportsForTarget` indeksi) · `finishAccountDeletions`
  // `status == 'deleted'` + `deletedAt` aralığı (aralık alanı = sıralama alanı; yeni indeks).
  fnPromoteOldestWaitlist: { collection: 'rsvps', equals: ['eventId', 'clubId', 'status'], order: ['waitlistAt', 'asc'] },
  fnOpenReportsForTarget: { collection: 'reports', equals: ['targetType', 'targetId', 'status'] },
  fnDeletedAccountsWindow: { collection: 'users', equals: ['status'], order: ['deletedAt', 'asc'] },
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

describe('indeksler · firestore.indexes.json sorguları karşılar (PLAN §11.4 T-15 / T-19 / T-22 satırları)', () => {
  test.each(Object.entries(QUERIES))('%s', (_name, spec) => {
    expect(hasIndex(spec)).toBe(true);
  });

  // `arrayContainsAny` + eşitlik: dizi alanı CONTAINS yapılandırmasıyla (hasIndex yalnızca sıralı alanlara bakar).
  test('listByInterests (T-25, CD-38): users (interests CONTAINS, isDeleted ↑)', () => {
    const match = indexes.filter((index) => index.collectionGroup === 'users' && index.queryScope === 'COLLECTION'
      && JSON.stringify(index.fields) === JSON.stringify([{ fieldPath: 'interests', arrayConfig: 'CONTAINS' }, { fieldPath: 'isDeleted', order: 'ASCENDING' }]));
    expect(match).toHaveLength(1);
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

  test('listByStatus (MGT-02 "Reddedilen", T-33): yönetim, danışman ve süper admin okur; üye, reddedilenin kendisi, üye olmayan ve başka kulübün yöneticisi okuyamaz', async () => {
    await seedFixture('base', { formerStatus: 'rejected' });
    const rejectedOf = (role, club = CLUB) => query(memberships(role), where('clubId', '==', club), where('status', '==', 'rejected'), orderBy('appliedAt', 'desc'));
    for (const role of ['board', 'president', 'advisor', 'super']) {
      const snapshot = await assertSucceeds(getDocs(rejectedOf(role)));
      expect(ids(snapshot)).toEqual(['c01_u_former']);
      for (const d of snapshot.docs) for (const key of ['email', 'emailLower', 'note']) expect(d.data()).not.toHaveProperty(key);
    }
    expect(ids(await assertSucceeds(getDocs(rejectedOf('otherManager', OTHER_CLUB))))).toEqual([]);
    for (const role of ['member', 'former', 'student', 'pending', 'otherManager', 'susp', 'anon']) {
      await assertFails(getDocs(rejectedOf(role)));
    }
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

describe('posts · sorgu biçimleri (rules-spec §6 FED-01, MGT-08; PLAN §10.4 PostRepository)', () => {
  const posts = (role) => collection(dbOf(role), 'posts');
  const live = [where('isDeleted', '==', false)];
  const feed = (role, club = CLUB) => query(posts(role), where('clubId', '==', club), ...live, where('isHidden', '==', false), orderBy('createdAt', 'desc'), limit(20));
  const management = (role) => query(posts(role), where('clubId', '==', CLUB), ...live, orderBy('createdAt', 'desc'), limit(20));
  const HIDDEN_AND_DELETED = {
    patch: { 'posts/p01': { isHidden: true, hiddenBy: 'u_super' }, 'posts/p02': { isDeleted: true, deletedBy: 'u_board' } },
  };

  test('listFeed: üye silinmemiş ve gizlenmemiş gönderileri görür; gizli / silinmiş gönderi sonuçta yoktur', async () => {
    await seedFixture('base');
    expect(ids(await assertSucceeds(getDocs(feed('member'))))).toEqual(['p01', 'p02']);
    await seedFixture('base', undefined, HIDDEN_AND_DELETED);
    expect(ids(await assertSucceeds(getDocs(feed('member'))))).toEqual([]);
    expect(ids(await assertSucceeds(getDocs(feed('advisor'))))).toEqual([]);
  });

  test('listForManagement: yönetim gizli gönderiyi de görür (silinmiş hariç); üye bu sorguyu kuramaz', async () => {
    await seedFixture('base', undefined, HIDDEN_AND_DELETED);
    expect(ids(await assertSucceeds(getDocs(management('board'))))).toEqual(['p01']);
    expect(ids(await assertSucceeds(getDocs(management('super'))))).toEqual(['p01']);
    await assertFails(getDocs(management('member')));
    await assertFails(getDocs(management('advisor')));
  });

  test('kulüp süzgeci zorunludur: üye başka kulübü, kulüpsüz ya da çok kulüplü sorguyu kuramaz', async () => {
    await seedFixture('base');
    await assertFails(getDocs(feed('member', OTHER_CLUB)));
    await assertFails(getDocs(query(posts('member'), ...live, where('isHidden', '==', false))));
    await assertFails(getDocs(query(posts('member'), where('clubId', 'in', [CLUB, OTHER_CLUB]), ...live, where('isHidden', '==', false))));
    await assertFails(getDocs(query(posts('member'), where('authorId', '==', 'u_board'))));
    await assertFails(getDocs(posts('board')));
  });
});

describe('comments, votes ve savedPosts · sorgu biçimleri (rules-spec §6 FED-02, PRF-04)', () => {
  test('watchComments: postId + clubId + isDeleted + isHidden, createdAt artan; gizli yorum üyenin listesinde yoktur', async () => {
    const thread = (role, postId) =>
      query(collection(dbOf(role), 'comments'), where('postId', '==', postId), where('clubId', '==', CLUB), where('isDeleted', '==', false), where('isHidden', '==', false), orderBy('createdAt', 'asc'));
    await seedFixture('base', undefined, { patch: { 'comments/cm02': { isHidden: true, hiddenBy: 'u_super' } } });
    expect(ids(await assertSucceeds(getDocs(thread('member', 'p01'))))).toEqual(['cm01']);
    expect(ids(await assertSucceeds(getDocs(thread('member', 'p02'))))).toEqual([]);
    // Kulüp süzgeci gönderinin kulübü değilse sonuç boştur; üyesi olmadığı kulüple sorgu reddedilir.
    const elsewhere = query(collection(dbOf('member'), 'comments'), where('postId', '==', 'p01'), where('clubId', '==', OTHER_CLUB), where('isDeleted', '==', false), where('isHidden', '==', false));
    await assertFails(getDocs(elsewhere));
  });

  test('countVotes: seçenek başına `where optionId == x` + count(); üye olmayan sayamaz', async () => {
    await seedFixture('base');
    const votesOf = (role, optionId) => query(collection(dbOf(role), 'posts/p01/votes'), where('optionId', '==', optionId));
    expect((await assertSucceeds(getCountFromServer(votesOf('advisor', 'o1')))).data().count).toBe(1);
    expect((await assertSucceeds(getCountFromServer(votesOf('member', 'o2')))).data().count).toBe(0);
    await assertFails(getCountFromServer(votesOf('student', 'o1')));
  });

  test('listSaved (PRF-04): userId == uid, isDeleted == false, savedAt azalan → kaldırılmış kayıt dönmez', async () => {
    const mine = (role, uid) => query(collection(dbOf(role), 'savedPosts'), where('userId', '==', uid), where('isDeleted', '==', false), orderBy('savedAt', 'desc'), limit(20));
    await seedFixture('base', undefined, { patch: { 'savedPosts/u_member_p01': { isDeleted: true, deletedBy: 'u_member' } } });
    expect(ids(await assertSucceeds(getDocs(mine('member', 'u_member'))))).toEqual([]);
    expect(ids(await assertSucceeds(getDocs(mine('former', 'u_former'))))).toEqual(['u_former_p01']);
    // Gönderiye göre "kim kaydetti" sorgusu kurulamaz (yönetici ve süper admin dahil).
    for (const role of ['board', 'super']) {
      await assertFails(getDocs(query(collection(dbOf(role), 'savedPosts'), where('postId', '==', 'p01'), where('isDeleted', '==', false))));
    }
  });
});

describe('events · sorgu biçimleri (rules-spec §6 EVT-01, MGT-04; PLAN §10.4 EventRepository)', () => {
  const events = (role) => collection(dbOf(role), 'events');
  const shown = [where('status', 'in', ['published', 'cancelled']), where('isDeleted', '==', false)];
  /** `fromUtc`: süren etkinlik (`e_live`, 1 sa önce başladı) listede kalır; 3 gün önceki `e_past` düşer. */
  const from = () => where('startsAt', '>=', fromNow(-2 * HOUR_MS));
  const publicUpcoming = (role) => query(events(role), where('visibility', '==', 'public'), ...shown, from(), orderBy('startsAt', 'asc'), limit(200));
  const membersUpcoming = (role, club = CLUB) =>
    query(events(role), where('clubId', '==', club), where('visibility', '==', 'members'), ...shown, from(), orderBy('startsAt', 'asc'), limit(200));
  const clubEvents = (role, ...extra) => query(events(role), where('clubId', '==', CLUB), ...extra, where('isDeleted', '==', false), orderBy('startsAt', 'desc'), limit(20));
  /** Ek veri: iptal edilmiş, geçmiş ve silinmiş herkese açık etkinlikler + başka kulübün üyelere özel etkinliği. */
  const seedMore = async () => {
    await seedFixture('base');
    await seedDocs({
      'events/e_cancelled': eventDoc('public', 'cancelled', 0, { cancelReason: 'Salon kapalı.' }),
      'events/e_past': eventDoc('public', 'published', 0, { startsAt: fromNow(-3 * DAY_MS), endsAt: fromNow(-3 * DAY_MS + HOUR_MS) }),
      'events/e_removed': eventDoc('public', 'published', 0, { isDeleted: true, deletedBy: 'u_board' }),
      'events/e_other_members': eventDoc('members', 'published', 0, { clubId: OTHER_CLUB }),
    });
  };

  test('listPublicUpcoming: herkese açık, yayında / iptal, silinmemiş, yaklaşan — taslak, üyelere özel, geçmiş ve silinmiş dönmez', async () => {
    await seedMore();
    for (const role of ['student', 'member', 'susp']) {
      expect(ids(await assertSucceeds(getDocs(publicUpcoming(role))))).toEqual(['e_cancelled', 'e_live', 'e_public']);
    }
    // Süzgeç zorunludur: görünürlüksüz, durumsuz ya da taslakları da isteyen sorgu üye olmayana kapalıdır.
    await assertFails(getDocs(query(events('student'), ...shown, from(), orderBy('startsAt', 'asc'))));
    await assertFails(getDocs(query(events('student'), where('visibility', '==', 'public'), where('isDeleted', '==', false))));
    await assertFails(getDocs(query(events('student'), where('visibility', '==', 'public'), where('status', 'in', ['draft', 'published']), where('isDeleted', '==', false))));
    await assertFails(getDocs(query(events('student'), where('visibility', '==', 'public'), where('status', 'in', ['published', 'cancelled']))));
  });

  test('listMembersUpcoming: kulüp başına ayrı sorgu — üye kendi kulübünü okur; üye olmayan ve çok kulüplü sorgu reddedilir', async () => {
    await seedMore();
    expect(ids(await assertSucceeds(getDocs(membersUpcoming('member'))))).toEqual(['e_members']);
    expect(ids(await assertSucceeds(getDocs(membersUpcoming('otherManager', OTHER_CLUB))))).toEqual(['e_other_members']);
    // members-only görünürlük: üye olmayan (öğrenci, başka kulübün yöneticisi, ayrılmış üye) bu sorguyu çalıştıramaz.
    for (const role of ['student', 'otherManager', 'former', 'pending']) await assertFails(getDocs(membersUpcoming(role)));
    await assertFails(getDocs(membersUpcoming('member', OTHER_CLUB)));
    await assertFails(getDocs(query(events('member'), where('visibility', '==', 'members'), ...shown)));
    await assertFails(getDocs(query(events('member'), where('clubId', 'in', [CLUB, OTHER_CLUB]), where('visibility', '==', 'members'), ...shown)));
  });

  test('listClubEvents: yönetim taslakları da görür; üye yayın / iptal; ziyaretçi yalnızca herkese açık (publicOnly)', async () => {
    await seedMore();
    const visible = where('status', 'in', ['published', 'cancelled']);
    const open = where('visibility', '==', 'public');
    const all = ['e_cancelled', 'e_draft', 'e_live', 'e_members', 'e_past', 'e_public'];
    for (const role of ['board', 'advisor', 'super']) expect(ids(await assertSucceeds(getDocs(clubEvents(role))))).toEqual(all);
    expect(ids(await assertSucceeds(getDocs(clubEvents('member', visible))))).toEqual(all.filter((id) => id !== 'e_draft'));
    expect(ids(await assertSucceeds(getDocs(clubEvents('student', open, visible))))).toEqual(['e_cancelled', 'e_live', 'e_past', 'e_public']);
    // Yetkisinden geniş sorgu: üye taslakları, ziyaretçi üyelere özel etkinlikleri isteyemez.
    await assertFails(getDocs(clubEvents('member')));
    await assertFails(getDocs(clubEvents('student', visible)));
    await assertFails(getDocs(clubEvents('otherManager', visible)));
    await assertFails(getDocs(clubEvents('student', where('visibility', '==', 'members'), visible)));
  });

  // Kimlik listeli sorgu belge belge değerlendirilir: listedeki okunamayan TEK etkinlik (üyelere özel, taslak,
  // silinmiş, olmayan) sorgunun tamamını düşürür. Bu yüzden getEvents tekil okumalar yapar ve okunamayanı atlar
  // (sözleşme §6.10 madde 5).
  test('getEvents: `documentId in […]` okunamayan tek etkinlikte tümden reddedilir; tekil okuma okunabileni döndürür', async () => {
    await seedFixture('base');
    const byIds = (role, list) => query(events(role), where(documentId(), 'in', list));
    expect(ids(await assertSucceeds(getDocs(byIds('student', ['e_public', 'e_live']))))).toEqual(['e_live', 'e_public']);
    for (const hidden of ['e_members', 'e_draft', 'e_missing']) await assertFails(getDocs(byIds('student', ['e_public', hidden])));
    await assertSucceeds(getDoc(doc(dbOf('student'), 'events/e_public')));
    await assertFails(getDoc(doc(dbOf('student'), 'events/e_members')));
  });
});

describe('rsvps · sorgu biçimleri (rules-spec §6 EVT-04, MGT-06; PLAN §10.4 RsvpRepository)', () => {
  const rsvps = (role) => collection(dbOf(role), 'rsvps');
  const participants = [where('eventId', '==', 'e_live'), where('clubId', '==', CLUB)];

  test('listMine (EVT-04 / PRF-03): userId == uid, isDeleted == false, createdAt azalan — yalnızca kendi kayıtları (vazgeçilmiş dahil)', async () => {
    await seedFixture('base', undefined, { patch: { 'rsvps/e_public_u_member': { status: 'cancelled' } } });
    const mine = (role, uid) => query(rsvps(role), where('userId', '==', uid), where('isDeleted', '==', false), orderBy('createdAt', 'desc'));
    expect(ids(await assertSucceeds(getDocs(mine('member', 'u_member'))))).toEqual(['e_live_u_member', 'e_public_u_member']);
    expect(ids(await assertSucceeds(getDocs(mine('susp', 'u_susp'))))).toEqual(['e_public_u_susp']);
    await assertFails(getDocs(mine('member', 'u_susp')));
    // Etkinliğe göre "kim katıldı" sorgusu katılımcıya kapalıdır (bilet kodu ve kimlik sızmaz).
    await assertFails(getDocs(query(rsvps('member'), where('eventId', '==', 'e_public'))));
    await assertFails(getDocs(query(rsvps('member'), where('eventId', '==', 'e_public'), where('clubId', '==', CLUB))));
  });

  test('katılımcılar (MGT-06): eventId + clubId, status / waitlistAt sıralı — yalnızca yönetim, danışman ve süper admin', async () => {
    await seedFixture('base');
    const listed = (role) => query(rsvps(role), ...participants, orderBy('status'), orderBy('waitlistAt'));
    for (const role of ['board', 'advisor', 'super']) {
      expect(ids(await assertSucceeds(getDocs(listed(role))))).toEqual(['e_live_u_board', 'e_live_u_member', 'e_live_u_student']);
    }
    for (const role of ['member', 'student', 'otherManager', 'susp']) await assertFails(getDocs(listed(role)));
    // Kulüp süzgeci etkinliğin kulübü olmalıdır: başka kulübün yöneticisi kendi kulüp kimliğiyle yabancı etkinliği soramaz
    // (sonuç boştur — kayıtların clubId'si c01'dir), c01 kimliğiyle de reddedilir.
    expect(ids(await assertSucceeds(getDocs(query(rsvps('otherManager'), where('eventId', '==', 'e_live'), where('clubId', '==', OTHER_CLUB)))))).toEqual([]);
  });

  test('waitlistPosition: count() — eventId, clubId, status == waitlist, waitlistAt < t; katılımcıya kapalı (sözleşme §6.10 madde 6)', async () => {
    await seedFixture('base');
    const pendingAt = fromNow(-HOUR_MS);
    await seedDocs({ 'rsvps/e_live_u_pending': rsvpDoc('e_live', 'u_pending', 'waitlist', { ticketCode: 'GU-LVPN-2345', waitlistAt: pendingAt }) });
    const before = (role, t) => query(rsvps(role), ...participants, where('status', '==', 'waitlist'), where('waitlistAt', '<', t));
    // u_student −2 sa, u_pending −1 sa bekliyor: ikincinin sırası = ondan önce girenler (1) + 1.
    expect((await assertSucceeds(getCountFromServer(before('board', pendingAt)))).data().count).toBe(1);
    expect((await assertSucceeds(getCountFromServer(before('advisor', fromNow(0))))).data().count).toBe(2);
    for (const role of ['student', 'pending', 'member']) await assertFails(getCountFromServer(before(role, fromNow(0))));
  });

  // limit 2: Rules bilet kodunda tekillik aramaz (kodu istemci üretir) — kopyalanmış kod iki kayıt döndürür,
  // FirebaseRsvpRepository.findByTicket bunu belirsiz eşleşme sayar (güvenlik incelemesi, CD-144; saldırı: rsvps.test.js).
  test('findByTicket: eventId + clubId + ticketCode, limit 2 — yalnızca yönetim; bilet kodu etkinliğe kapsamlıdır', async () => {
    await seedFixture('base');
    const byTicket = (role, code, eventId = 'e_live') => query(rsvps(role), where('eventId', '==', eventId), where('clubId', '==', CLUB), where('ticketCode', '==', code), limit(2));
    expect(ids(await assertSucceeds(getDocs(byTicket('board', 'GU-LVME-2345'))))).toEqual(['e_live_u_member']);
    expect(ids(await assertSucceeds(getDocs(byTicket('board', 'GU-LVME-2345', 'e_public'))))).toEqual([]);
    await assertFails(getDocs(byTicket('member', 'GU-LVME-2345')));
    await assertFails(getDocs(query(rsvps('board'), where('ticketCode', '==', 'GU-LVME-2345'))));
  });
});

describe('admin · sorgu biçimleri (T-37; PLAN §10.4 AdminRepository.stats / listManagerUserIds)', () => {
  test('stats: dört count() süper admine açık (belge okunmaz); şikayet sayımı başkasına kapalı', async () => {
    await seedFixture('base');
    const count = async (role, coll, ...constraints) => (await getCountFromServer(query(collection(dbOf(role), coll), ...constraints))).data().count;
    expect(await count('super', 'clubs', where('isDeleted', '==', false), where('status', '==', 'active'))).toBe(2);
    expect(await count('super', 'users', where('isDeleted', '==', false))).toBeGreaterThan(0);
    expect(await count('super', 'reports', where('status', '==', 'open'))).toBe(1);
    const upcoming = [where('status', '==', 'published'), where('isDeleted', '==', false), where('startsAt', '>=', fromNow(0))];
    expect(await count('super', 'events', ...upcoming)).toBe(2);
    await assertFails(getCountFromServer(query(collection(dbOf('president'), 'reports'), where('status', '==', 'open'))));
  });

  test('listManagerUserIds: kulüp süzgeçsiz status == active + role in [board, president] süper admine açık', async () => {
    await seedFixture('base');
    const managers = (role) => getDocs(query(collection(dbOf(role), 'memberships'), where('status', '==', 'active'), where('role', 'in', ['board', 'president'])));
    const snapshot = await assertSucceeds(managers('super'));
    expect(snapshot.docs.map((d) => d.data().userId).sort()).toEqual(['u_board', 'u_mgr2', 'u_president']);
  });
});

describe('users · sorgu biçimi (T-25, CD-38; PLAN §10.4 UserRepository.listByInterests)', () => {
  test('listByInterests: interests arrayContainsAny + isDeleted == false + limit — yöneticinin event_new alıcı çözümü', async () => {
    await seedFixture('base', undefined, { patch: { 'users/u_student': { interests: ['i02'] }, 'users/u_former': { isDeleted: true, deletedBy: 'u_former' } } });
    const byInterests = query(collection(dbOf('board'), 'users'), where('interests', 'array-contains-any', ['i02', 'i01']),
      where('isDeleted', '==', false), limit(200));
    const found = ids(await assertSucceeds(getDocs(byInterests)));
    expect(found).toContain('u_student');
    expect(found).not.toContain('u_former');
    // Doğrulanmamış oturum kullanıcıları listeleyemez (emailOk).
    await assertFails(getDocs(query(collection(dbOf('unver'), 'users'), where('interests', 'array-contains-any', ['i01']), where('isDeleted', '==', false))));
  });
});
