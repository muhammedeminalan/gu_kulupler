'use strict';
// T-30 — `memberships` yönetici geçişleri M5, M6, M9, M10, M11, M12 (rules-spec §3.4; domain-model §5;
// sözleşme docs/plans/T-30.md §4 a–e). Rol × işlem matrisi (hiyerarşi, danışman, başka kulübün yöneticisi,
// askıdaki hesap / kulüp, W-89) `expectations/memberships.json` dosyasındadır (`memberships.test.js` koşar);
// burada taban yazımların sonucu ve matrise sığmayan koşullar:
//  1. Taban işlemler (repository'nin transaction'ıyla aynı yazımlar, tek batch): durum, sayaç, yan belge,
//     günlük ve bildirim birlikte yazılır.
//  2. Karar alanları: sunucu zamanı, aktör, beyaz liste, `retryAfter` (+7 gün ± 5 dk), neden / not sınırı.
//  3. 30 sn geri al (M12): yalnızca kararı veren, sunucu saatiyle pencere içinde; rolü değişmiş onay ve
//     yetkisini yitiren yönetici geri alamaz.
//  4. Hiyerarşi uçları: başkan / danışman hedef olamaz, kimse kendini çıkaramaz, yönetim kurulu yönetim kurulunu
//     çıkaramaz, `president` / `advisor` M10 ile verilemez.
//  5. Başkanlık devri tek işlem: eksik parça, uygunsuz hedef ve tutarsız `presidentId` reddedilir.
//  6. Günlük (yönetici türleri) sabit kimlik ve olay bağı.
// Sayaç işaretçisi (W-64) `counters.test.js`, bildirim dalları `notifications.test.js`, erişim bütçesi
// `budget/approve_budget.test.js` ve `budget/transfer_budget.test.js`.
const path = require('node:path');
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { Timestamp, doc, getDoc } = require('firebase/firestore');
const budget = require('../helpers/budget');
const { CONTEXTS, contextFor, uidOf, CLUB } = require('../helpers/contexts');
const { readDoc, seedFixture } = require('../helpers/fixtures');
const payloads = require('../helpers/payloads');

const REPO_ROOT = path.resolve(__dirname, '..', '..', '..');
const LIMITS = require(path.join(REPO_ROOT, 'tool', 'lib', 'dart_sources.js')).readLimits(REPO_ROOT).ints;

const SECOND_MS = 1000;
const MINUTE_MS = 60 * SECOND_MS;
const DAY_MS = 24 * 60 * MINUTE_MS;
/** Temel veri kümesinde c01'in aktif, danışman olmayan üye sayısı. */
const BASE_COUNT = 5;
const CLUB_PATH = `clubs/${CLUB}`;
const M = (uid) => payloads.membershipPath(CLUB, uid);
const NO_EDIT = Object.freeze({});

const commit = (role, writes) => budget.buildBatch(contextFor(role).firestore(), Object.values(writes)).commit();
const expectWrite = (request, expected) => (expected === 'allow' ? assertSucceeds(request) : assertFails(request));
const drop = (writes, name) => Object.fromEntries(Object.entries(writes).filter(([key]) => key !== name));
/** Adlı yazımın yüküne alan ekler / ezer. */
const withData = (writes, name, extra) => ({ ...writes, [name]: { ...writes[name], data: { ...writes[name].data, ...extra } } });
const memberCount = async () => (await readDoc(CLUB_PATH)).memberCount;

const approve = (uid = 'u_board', extra) => payloads.approveWrites({ club: CLUB, uid, ...extra });
const reject = (uid = 'u_board', extra) => payloads.rejectWrites({ club: CLUB, uid, ...extra });
const remove = (uid = 'u_president', extra) => payloads.removeWrites({ club: CLUB, uid, ...extra });
const changeRole = (uid = 'u_president', extra) => payloads.roleWrites({ club: CLUB, uid, ...extra });
const transfer = (uid = 'u_president', extra) => payloads.transferWrites({ club: CLUB, uid, ...extra });

/** Kararı `ageMs` önce `decidedBy` tarafından verilmiş üyelik (geri al vakaları; istemci saatiyle). */
const decided = (uid, status, decidedBy, ageMs, extra) => ({
  patch: { [M(uid)]: { status, decidedBy, decidedAt: Timestamp.fromMillis(Date.now() - ageMs), ...extra } },
});

describe('M5 / M6 / M9 / M10 / M11 — taban işlemler (sayaç, yan belge, günlük, bildirim aynı işlemde)', () => {
  test('M5 onay: active + member, karar alanları sunucu zamanı; memberCount +1; günlük ve bildirim yazılır', async () => {
    await seedFixture('base');
    await assertSucceeds(commit('board', approve()));
    const m = await readDoc(M('u_pending'));
    expect(m).toMatchObject({ status: 'active', role: 'member', decidedBy: 'u_board' });
    expect(m.decidedAt.toMillis()).toBe(m.updatedAt.toMillis());
    expect(await memberCount()).toBe(BASE_COUNT + 1);
    expect(await readDoc(payloads.clubCounterPath(CLUB))).toMatchObject({ lastMembershipRef: M('u_pending') });
    expect(await readDoc(payloads.managerActivityPath(CLUB, 'u_board', 'application_approved', 'u_pending'))).toMatchObject({ refs: { userId: 'u_pending' } });
    expect(await readDoc(payloads.notificationPath('application_approved', payloads.EVENT_KEY, 'u_pending'))).toMatchObject({ userId: 'u_pending', read: false });
  });

  test('M6 red: rejected + retryAfter (+7 gün) + neden / not; sayaç değişmez', async () => {
    await seedFixture('base');
    await assertSucceeds(commit('president', reject('u_president')));
    const m = await readDoc(M('u_pending'));
    expect(m).toMatchObject({ status: 'rejected', decidedBy: 'u_president', rejectReason: 'quota', rejectNote: payloads.REJECT_NOTE });
    expect(Math.abs(m.retryAfter.toMillis() - (m.decidedAt.toMillis() + 7 * DAY_MS))).toBeLessThan(5 * MINUTE_MS);
    expect(await memberCount()).toBe(BASE_COUNT);
  });

  test('M9 çıkar → M12b geri al: removed (−1) sonra active member (+1); karar alanları boşalır', async () => {
    await seedFixture('base');
    await assertSucceeds(commit('president', remove()));
    expect(await readDoc(M('u_member'))).toMatchObject({ status: 'removed', rejectReason: 'other', decidedBy: 'u_president' });
    expect(await memberCount()).toBe(BASE_COUNT - 1);
    await assertSucceeds(commit('president', payloads.undoRemovalWrites({ club: CLUB })));
    expect(await readDoc(M('u_member'))).toMatchObject({ status: 'active', role: 'member', decidedAt: null, decidedBy: null, retryAfter: null });
    expect(await memberCount()).toBe(BASE_COUNT);
  });

  test('M5 → M12a ve M6 → M12a: karar 30 sn içinde geri alınır (onayda −1, retde sayaç yok)', async () => {
    await seedFixture('base');
    await assertSucceeds(commit('board', approve()));
    await assertSucceeds(commit('board', payloads.undoDecisionWrites({ club: CLUB })));
    expect(await readDoc(M('u_pending'))).toMatchObject({ status: 'pending', decidedBy: null });
    expect(await memberCount()).toBe(BASE_COUNT);
    // Geri alınan kararın günlüğü kalır: aynı yöneticinin aynı kararı yeni kayıt açmaz (kimlik dolu → update → ret).
    await assertFails(commit('board', approve()));
    await assertSucceeds(commit('board', drop(approve(undefined, { key: payloads.EVENT_KEY_2 }), 'activity')));
    await seedFixture('base');
    await assertSucceeds(commit('board', reject()));
    await assertSucceeds(commit('board', payloads.undoDecisionWrites({ club: CLUB, approved: false })));
    expect(await readDoc(M('u_pending'))).toMatchObject({ status: 'pending', rejectReason: null, retryAfter: null });
  });

  test('M10 rol: member → board → member (günlük kimliği rolü taşır: gidip gelme iki kayıt)', async () => {
    await seedFixture('base');
    await assertSucceeds(commit('president', changeRole()));
    expect((await readDoc(M('u_member'))).role).toBe('board');
    await assertSucceeds(commit('president', changeRole('u_president', { role: 'member', key: payloads.EVENT_KEY_2 })));
    expect(await readDoc(M('u_member'))).toMatchObject({ status: 'active', role: 'member' });
    expect(await memberCount()).toBe(BASE_COUNT);
  });

  test('M11 devir tek işlem: eski başkan board, yeni başkan president, clubs.presidentId; iki bildirim', async () => {
    await seedFixture('base');
    await assertSucceeds(commit('president', transfer()));
    expect((await readDoc(M('u_president'))).role).toBe('board');
    expect((await readDoc(M('u_board'))).role).toBe('president');
    expect(await readDoc(CLUB_PATH)).toMatchObject({ presidentId: 'u_board', memberCount: BASE_COUNT });
    expect(await readDoc(payloads.notificationPath('role_changed', payloads.EVENT_KEY_2, 'u_president'))).toMatchObject({ refs: { clubId: CLUB, role: 'board' } });
    // Yeni başkan devri hemen sürdürebilir; eski başkan artık devredemez.
    await assertFails(commit('president', transfer('u_president', { from: 'u_president', to: 'u_member' })));
    await assertSucceeds(commit('board', transfer('u_board', { from: 'u_board', to: 'u_president' })));
  });
});

describe('karar alanları — sunucu zamanı, aktör, beyaz liste, retryAfter, neden / not', () => {
  const clientTime = () => Timestamp.fromMillis(Date.now() - MINUTE_MS);
  // Satır: [başlık, taban, yazımları değiştiren işlev].
  test.each([
    ['M5 decidedAt istemci saati', approve, (w) => withData(w, 'membership', { decidedAt: clientTime() })],
    ['M5 decidedBy başka yönetici', approve, (w) => withData(w, 'membership', { decidedBy: 'u_board' })],
    ['M5 rol board olarak onay', approve, (w) => withData(w, 'membership', { role: 'board' })],
    ['M5 beyaz liste dışı alan (note — CD-137)', approve, (w) => withData(w, 'membership', { note: 'x' })],
    ['M5 sayaçsız onay', approve, (w) => drop(w, 'club')],
    ['M6 retryAfter +6 gün', reject, (w) => withData(w, 'membership', { retryAfter: payloads.cooldownFromNow(-DAY_MS) })],
    ['M6 retryAfter +7 gün + 10 dk (tolerans dışı)', reject, (w) => withData(w, 'membership', { retryAfter: payloads.cooldownFromNow(10 * MINUTE_MS) })],
    ['M6 retryAfter yok', reject, (w) => withData(w, 'membership', { retryAfter: null })],
    ['M6 tanımsız neden', reject, (w) => withData(w, 'membership', { rejectReason: 'spam' })],
    ['M6 not 201 karakter (rejectNoteMax)', reject, (w) => withData(w, 'membership', { rejectNote: 'a'.repeat(201) })],
    ['M6 redde sayaç düşürülüyor', reject, (w) => ({ ...w, club: { op: 'update', path: CLUB_PATH, data: payloads.memberCountBump(-1) } })],
    ['M9 neden other değil', remove, (w) => withData(w, 'membership', { rejectReason: 'quota' })],
    ['M9 retryAfter geçmişte (hemen yeniden başvuru)', remove, (w) => withData(w, 'membership', { retryAfter: Timestamp.fromMillis(Date.now() - MINUTE_MS) })],
    ['M9 rol de değiştiriliyor', remove, (w) => withData(w, 'membership', { role: 'board' })],
  ])('%s → deny', async (_title, base, mutate) => {
    await seedFixture('base');
    await assertFails(commit('president', mutate(base('u_president'))));
    expect(await memberCount()).toBe(BASE_COUNT);
  });

  test.each([
    ['M6 not yok (istemci boş notu yazmaz — W-51)', () => reject('u_president', { note: null })],
    ['M6 not tam 200 karakter', () => reject('u_president', { note: 'a'.repeat(200) })],
    ['M6 retryAfter +7 gün − 4 dk (tolerans içi)', () => withData(reject('u_president'), 'membership', { retryAfter: payloads.cooldownFromNow(-4 * MINUTE_MS) })],
  ])('%s → allow', async (_title, build) => {
    await seedFixture('base');
    await assertSucceeds(commit('president', build()));
  });
});

describe('M12 — 30 sn geri al (sunucu saati, yalnızca kararı veren)', () => {
  // Satır: [başlık, aktör, yazımlar, veri düzenlemesi, beklenti].
  test.each([
    ['onay 20 sn önce → geri al', 'board', () => payloads.undoDecisionWrites({ club: CLUB }), decided('u_pending', 'active', 'u_board', 20 * SECOND_MS), 'allow'],
    ['onay 31 sn önce → pencere kapandı', 'board', () => payloads.undoDecisionWrites({ club: CLUB }), decided('u_pending', 'active', 'u_board', 31 * SECOND_MS), 'deny'],
    ['red 31 sn önce → pencere kapandı', 'board', () => payloads.undoDecisionWrites({ club: CLUB, approved: false }), decided('u_pending', 'rejected', 'u_board', 31 * SECOND_MS), 'deny'],
    ['başka yöneticinin onayı (decidedBy ≠ uid)', 'president', () => payloads.undoDecisionWrites({ club: CLUB }), decided('u_pending', 'active', 'u_board', 5 * SECOND_MS), 'deny'],
    ['onaydan sonra rolü board olmuş üyelik', 'board', () => payloads.undoDecisionWrites({ club: CLUB }), decided('u_pending', 'active', 'u_board', 5 * SECOND_MS, { role: 'board' }), 'deny'],
    ['onayı geri alırken sayaç düşmüyor', 'board', () => drop(payloads.undoDecisionWrites({ club: CLUB }), 'club'), decided('u_pending', 'active', 'u_board', 5 * SECOND_MS), 'deny'],
    ['yetkisini yitiren yönetici (artık sıradan üye)', 'board', () => payloads.undoDecisionWrites({ club: CLUB }),
      { patch: { ...decided('u_pending', 'active', 'u_board', 5 * SECOND_MS).patch, [M('u_board')]: { role: 'member' } } }, 'deny'],
    ['danışman kendi adına yazılmış kararı geri alamaz (Q-09)', 'advisor', () => payloads.undoDecisionWrites({ club: CLUB }), decided('u_pending', 'active', 'u_advisor', 5 * SECOND_MS), 'deny'],
    ['süper admin karar geri almaz (karar vermez)', 'super', () => payloads.undoDecisionWrites({ club: CLUB }), decided('u_pending', 'active', 'u_super', 5 * SECOND_MS), 'deny'],
    ['çıkarma 20 sn önce → geri al', 'president', () => payloads.undoRemovalWrites({ club: CLUB }), decided('u_member', 'removed', 'u_president', 20 * SECOND_MS), 'allow'],
    ['çıkarma 31 sn önce → pencere kapandı', 'president', () => payloads.undoRemovalWrites({ club: CLUB }), decided('u_member', 'removed', 'u_president', 31 * SECOND_MS), 'deny'],
    ['süper admin kendi çıkarmasını geri alır', 'super', () => payloads.undoRemovalWrites({ club: CLUB }), decided('u_member', 'removed', 'u_super', 5 * SECOND_MS), 'allow'],
    ['başkanın çıkarmasını yönetim kurulu geri alamaz', 'board', () => payloads.undoRemovalWrites({ club: CLUB }), decided('u_member', 'removed', 'u_president', 5 * SECOND_MS), 'deny'],
    ['geri alırken rol yükseltme (member → board)', 'president', () => payloads.undoRemovalWrites({ club: CLUB, role: 'board' }), decided('u_member', 'removed', 'u_president', 5 * SECOND_MS), 'deny'],
    ['çıkarılan board üyesi eski rolüyle döner', 'president', () => payloads.undoRemovalWrites({ club: CLUB, target: 'u_board', role: 'board' }), decided('u_board', 'removed', 'u_president', 5 * SECOND_MS), 'allow'],
    ['ayrılmış üye (left) geri alınamaz', 'president', () => payloads.undoRemovalWrites({ club: CLUB }), decided('u_member', 'left', 'u_president', 5 * SECOND_MS), 'deny'],
  ])('%s → %s', async (_title, role, build, edit, expected) => {
    await seedFixture('base', undefined, edit);
    await expectWrite(commit(role, build()), expected);
  });
});

// Güvenlik incelemesi (T-30): M12a / M12b rol × durum matrisi. Kararı her bağlamın KENDİSİ vermiş sayılır
// (`decidedBy = uid`, 5 sn önce) — ret yalnızca aktörün yetkisinden gelir. Göreli sunucu zamanı JSON
// matrisinde (`expectations/memberships.json`) ifade edilemediği için tablo buradadır.
describe('M12 — rol × durum matrisi (aktör kararı kendisi vermiş)', () => {
  const undoApproval = () => payloads.undoDecisionWrites({ club: CLUB });
  const undoRejection = () => payloads.undoDecisionWrites({ club: CLUB, approved: false });
  const undoRemoval = () => payloads.undoRemovalWrites({ club: CLUB });
  const by = (role) => uidOf(role);
  const plus = (edit, extra) => ({ patch: { ...edit.patch, ...extra } });
  const MANAGERS = ['board', 'president'];
  // Satır: [başlık, aktör, yazımlar, veri düzenlemesi, beklenti].
  const rows = CONTEXTS.flatMap((role) => [
    ['M12a onayı geri al', role, undoApproval, decided('u_pending', 'active', by(role), 5 * SECOND_MS), MANAGERS.includes(role) ? 'allow' : 'deny'],
    ['M12a reddi geri al', role, undoRejection, decided('u_pending', 'rejected', by(role), 5 * SECOND_MS), MANAGERS.includes(role) ? 'allow' : 'deny'],
    ['M12b çıkarmayı geri al', role, undoRemoval, decided('u_member', 'removed', by(role), 5 * SECOND_MS), [...MANAGERS, 'super'].includes(role) ? 'allow' : 'deny'],
  ]);
  const suspendedUser = { 'users/u_board': { status: 'suspended' } };
  const suspendedClub = { [CLUB_PATH]: { status: 'suspended' } };
  const deletedClub = { [CLUB_PATH]: { isDeleted: true } };
  test.each([
    ...rows,
    ['M12a askıdaki hesap (yönetim kurulu)', 'board', undoApproval, plus(decided('u_pending', 'active', 'u_board', 5 * SECOND_MS), suspendedUser), 'deny'],
    ['M12b askıdaki hesap (yönetim kurulu)', 'board', undoRemoval, plus(decided('u_member', 'removed', 'u_board', 5 * SECOND_MS), suspendedUser), 'deny'],
    ['M12a askıdaki kulüp', 'president', undoApproval, plus(decided('u_pending', 'active', 'u_president', 5 * SECOND_MS), suspendedClub), 'deny'],
    ['M12a silinmiş kulüp (red)', 'president', undoRejection, plus(decided('u_pending', 'rejected', 'u_president', 5 * SECOND_MS), deletedClub), 'deny'],
    ['M12b askıdaki kulüp', 'president', undoRemoval, plus(decided('u_member', 'removed', 'u_president', 5 * SECOND_MS), suspendedClub), 'deny'],
    ['M12b silinmiş kulüp', 'board', undoRemoval, plus(decided('u_member', 'removed', 'u_board', 5 * SECOND_MS), deletedClub), 'deny'],
    ['M12b askıdaki kulüpte süper admin (süper dalı clubLive istemez)', 'super', undoRemoval, plus(decided('u_member', 'removed', 'u_super', 5 * SECOND_MS), suspendedClub), 'allow'],
  ])('%s · %s → %s', async (_title, role, build, edit, expected) => {
    await seedFixture('base', undefined, edit);
    await expectWrite(commit(role, build()), expected);
  });
});

describe('hiyerarşi uçları (sözleşme §4 c)', () => {
  const asBoard = (uid) => ({ patch: { [M(uid)]: { role: 'board' } } });
  // Satır: [başlık, aktör, yazımlar, veri düzenlemesi?].
  test.each([
    ['yönetim kurulu başka bir yönetim kurulu üyesini çıkaramaz', 'board', () => remove('u_board'), asBoard('u_member')],
    ['başkan çıkarılamaz (süper admin dahil — önce devir)', 'super', () => remove('u_super', { target: 'u_president' })],
    ['başkan kendini çıkaramaz', 'president', () => remove('u_president', { target: 'u_president' })],
    ['danışman çıkarılamaz (M13)', 'president', () => remove('u_president', { target: 'u_advisor' })],
    ['bekleyen başvuru çıkarılamaz (red M6)', 'president', () => remove('u_president', { target: 'u_pending' })],
    ['M10 başkanlık rolü verilemez (yalnızca devir)', 'president', () => changeRole('u_president', { role: 'president' })],
    ['M10 danışman rolü verilemez (M13)', 'super', () => changeRole('u_super', { role: 'advisor' })],
    ['M10 başkanın rolü düşürülemez', 'super', () => changeRole('u_super', { target: 'u_president', role: 'board' })],
    ['M10 danışmanın rolü değiştirilemez', 'president', () => changeRole('u_president', { target: 'u_advisor', role: 'board' })],
    ['M10 aynı rol (değişiklik yok)', 'president', () => changeRole('u_president', { target: 'u_board', role: 'board' })],
    ['M10 etkin olmayan üyelik (left)', 'president', () => changeRole('u_president', { target: 'u_former' })],
    ['M10 durumla birlikte (removed + board)', 'president', () => withData(changeRole(), 'membership', { status: 'removed' })],
  ])('%s → deny', async (_title, role, build, edit = NO_EDIT) => {
    await seedFixture('base', undefined, edit);
    await assertFails(commit(role, build()));
  });
});

describe('M11 başkanlık devri — tek işlem, eksik parça ret, uygun hedef', () => {
  test.each([
    ['eski başkanın yazımı eksik (iki başkan kalırdı)', () => drop(transfer(), 'from')],
    ['yeni başkanın yazımı eksik (kulüp başkansız kalırdı)', () => drop(transfer(), 'to')],
    ['kulübün presidentId yazımı eksik', () => drop(transfer(), 'club')],
    ['presidentId üçüncü kişiyi gösteriyor', () => withData(transfer(), 'club', { presidentId: 'u_member' })],
    ['eski başkan member yapılıyor (board değil)', () => withData(transfer(), 'from', { role: 'member' })],
    ['hedef bekleyen başvuru', () => transfer('u_president', { to: 'u_pending' })],
    ['hedef eski üye (left)', () => transfer('u_president', { to: 'u_former' })],
    ['hedef danışman', () => transfer('u_president', { to: 'u_advisor' })],
    ['hedef askıdaki hesap (W-89)', () => transfer('u_president', { to: 'u_susp' })],
    ['hedef silinmiş hesap (W-89)', () => transfer('u_president', { to: 'u_deleted' })],
  ])('%s → deny', async (_title, build) => {
    await seedFixture('base');
    await assertFails(commit('president', build()));
    expect(await readDoc(CLUB_PATH)).toMatchObject({ presidentId: 'u_president' });
    expect((await readDoc(M('u_president'))).role).toBe('president');
  });

  test('sıradan üye de devralabilir (member → president)', async () => {
    await seedFixture('base');
    await assertSucceeds(commit('president', transfer('u_president', { to: 'u_member' })));
    expect(await readDoc(CLUB_PATH)).toMatchObject({ presidentId: 'u_member' });
  });

  test('süper admin başkan adına devreder; askıdaki başkanın devri reddedilir (yalnızca süper admin)', async () => {
    await seedFixture('base', undefined, { patch: { 'users/u_president': { status: 'suspended' } } });
    await assertFails(commit('president', transfer()));
    await assertSucceeds(commit('super', transfer('u_super')));
    expect(await readDoc(CLUB_PATH)).toMatchObject({ presidentId: 'u_board' });
  });
});

describe('günlük — yönetici türleri sabit kimlik ve aynı işlemdeki geçiş', () => {
  // Satır: [başlık, aktör, yazımlar].
  test.each([
    ['onay günlüğü yanlış priorCount kimliği', 'board', () => ({ ...approve(), activity: { ...approve().activity, path: payloads.managerActivityPath(CLUB, 'u_board', 'application_approved', 'u_pending', 1) } })],
    ['onay günlüğü başka aktör kimliğiyle', 'board', () => ({ ...approve(), activity: { ...approve().activity, path: payloads.managerActivityPath(CLUB, 'u_president', 'application_approved', 'u_pending') } })],
    ['onay günlüğü ret türüyle', 'board', () => withData({ ...approve(), activity: { ...approve().activity, path: payloads.managerActivityPath(CLUB, 'u_board', 'application_rejected', 'u_pending') } }, 'activity', { kind: 'application_rejected' })],
    ['onay günlüğü refs başka hedef', 'board', () => withData(approve(), 'activity', { refs: { userId: 'u_member' } })],
    ['karar olmadan karar günlüğü', 'board', () => ({ activity: approve().activity })],
    ['rol günlüğü rol değişmeden', 'president', () => ({ activity: changeRole().activity })],
    ['ayar günlüğü kulüp yazılmadan', 'board', () => ({ activity: payloads.settingsWrites({ club: CLUB, uid: 'u_board' }).activity })],
    ['ayar günlüğünü danışman yazamaz', 'advisor', () => payloads.settingsWrites({ club: CLUB, uid: 'u_advisor' })],
  ])('%s → deny', async (_title, role, build) => {
    await seedFixture('base');
    await assertFails(commit(role, build()));
  });

  test('ayar güncellemesi + settings_changed (otomatik kimlik) aynı işlemde geçer; günlük yönetime okunur', async () => {
    await seedFixture('base');
    await assertSucceeds(commit('board', payloads.settingsWrites({ club: CLUB, uid: 'u_board' })));
    expect(await readDoc(CLUB_PATH)).toMatchObject({ summary: 'Güncel özet.', applicationsOpen: false });
    await assertSucceeds(getDoc(doc(contextFor('advisor').firestore(), payloads.SETTINGS_ACTIVITY_PATH)));
  });
});

describe('kulüp ayarları — tip ve sınırlar (birleşmiş belge doğrulanır)', () => {
  const EMAIL_TAIL = '@gu.edu.tr';
  const WEB_HEAD = 'https://gu.edu.tr/';
  const settings = (extra) => ({ club: { op: 'update', path: CLUB_PATH, data: payloads.clubSettingsPatch(extra) } });
  test.each([
    ['özet 161 karakter (clubSummaryMax)', { summary: 'a'.repeat(161) }, 'deny'],
    ['özet 160 karakter (clubSummaryMax — T-45 sınır tam değeri)', { summary: 'a'.repeat(160) }, 'allow'],
    ['hakkında 1001 karakter (clubAboutMax)', { about: 'a'.repeat(1001) }, 'deny'],
    ['hakkında 1000 karakter (clubAboutMax — T-45 sınır tam değeri)', { about: 'a'.repeat(1000) }, 'allow'],
    ['11 koşul (conditionsMax)', { conditions: Array.from({ length: 11 }, (_, i) => `Koşul ${i}`) }, 'deny'],
    ['10 koşul, sonuncusu 121 karakter (conditionTextMax)', { conditions: [...Array.from({ length: 9 }, (_, i) => `Koşul ${i}`), 'a'.repeat(121)] }, 'deny'],
    ['boş koşul maddesi', { conditions: ['Öğrenci olmak', '  '] }, 'deny'],
    ['dizgi olmayan koşul maddesi (sayı)', { conditions: ['Öğrenci olmak', 5] }, 'deny'],
    ['satır sonu içeren madde (birleşim ayırıcısı)', { conditions: ['a\nb'] }, 'deny'],
    ['iki uzun madde (birleşik 201 karakter; madde başına sınır)', { conditions: ['a'.repeat(100), 'b'.repeat(100)] }, 'allow'],
    ['10 koşul, her biri 120 karakter', { conditions: Array.from({ length: 10 }, () => 'a'.repeat(120)) }, 'allow'],
    ['geçersiz Instagram adı', { social: { instagram: 'bad handle!' } }, 'deny'],
    ['social beyaz liste dışı anahtar', { social: { twitter: 'x' } }, 'deny'],
    ['sosyal bağlantılar (istemci biçimi: yalnızca dolu anahtarlar)', { social: { instagram: '@gu.kulup', web: 'https://gu.edu.tr' } }, 'allow'],
    ['tanımsız palet', { palette: 'green' }, 'deny'],
    ['tanımsız desen', { pattern: 'stars' }, 'deny'],
    ['boş kapak tohumu', { coverSeed: '' }, 'deny'],
    // T-45 F1: kulüp belgesi doğrulanmış herkese açık — `social.email` / `social.web` / `coverSeed` üst sınırlı
    // (Limits.socialEmailMax / socialWebMax / coverSeedMax; önceden yalnızca tip — ~300 KB'lık alan yazılabiliyordu).
    [`social.email ${LIMITS.socialEmailMax} karakter (socialEmailMax)`, { social: { email: `${'a'.repeat(LIMITS.socialEmailMax - EMAIL_TAIL.length)}${EMAIL_TAIL}` } }, 'allow'],
    [`social.email ${LIMITS.socialEmailMax + 1} karakter`, { social: { email: `${'a'.repeat(LIMITS.socialEmailMax + 1 - EMAIL_TAIL.length)}${EMAIL_TAIL}` } }, 'deny'],
    [`social.web ${LIMITS.socialWebMax} karakter (socialWebMax)`, { social: { web: `${WEB_HEAD}${'a'.repeat(LIMITS.socialWebMax - WEB_HEAD.length)}` } }, 'allow'],
    [`social.web ${LIMITS.socialWebMax + 1} karakter`, { social: { web: `${WEB_HEAD}${'a'.repeat(LIMITS.socialWebMax + 1 - WEB_HEAD.length)}` } }, 'deny'],
    ['social.web ~300 KB (saldırı yükü)', { social: { web: `${WEB_HEAD}${'a'.repeat(300000)}` } }, 'deny'],
    [`kapak tohumu ${LIMITS.coverSeedMax} karakter (coverSeedMax)`, { coverSeed: 'a'.repeat(LIMITS.coverSeedMax) }, 'allow'],
    [`kapak tohumu ${LIMITS.coverSeedMax + 1} karakter`, { coverSeed: 'a'.repeat(LIMITS.coverSeedMax + 1) }, 'deny'],
    ['approvalRequired dizgi', { approvalRequired: 'true' }, 'deny'],
    ['palet + desen + tohum (kapak şablonu)', { palette: 'slate', pattern: 'waves', coverSeed: 'club-c01-2' }, 'allow'],
    ['logoPath (T-36 akışı)', { logoPath: 'clubs/c01/logo.jpg' }, 'deny'],
    ['memberCount yönetim yamasında', { memberCount: 99 }, 'deny'],
  ])('%s → %s', async (_title, extra, expected) => {
    await seedFixture('base');
    await expectWrite(commit('president', settings(extra)), expected);
  });
});
