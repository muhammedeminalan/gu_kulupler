'use strict';
// T-15 — `activity/{id}` (rules-spec §3.11; PLAN §11.1 satır 13). Değiştirilemez günlük.
//
//  1. Rol × işlem matrisi: `expectations/activity.json` (okuma yalnızca kulüp yönetimi / danışman /
//     süper admin; eşlik eden yazım olmadan create ret; yönetici türleri T-30'a kadar kapalı;
//     update / soft delete herkese ret).
//  2. T-15 türleri — oturumun KENDİ üyelik geçişi, aynı batch'teki üyelik yazımıyla doğrulanır:
//     `application_received` (M1 / M3 / M4) · `member_joined` (M2 / M3) · `member_left` (M8).
//  3. Biçim: alan beyaz listesi, `actorId == uid`, `refs.userId == uid`, `createdAt == request.time`.
//  4. Sabit kimlik (CD-137 madde 8t): `{clubId}_{uid}_{kind}_{priorCount}` — bir geçişe tek günlük belgesi;
//     serbest kimlik, aynı batch'te ikinci günlük ve sonraki batch'te yeniden yazım reddedilir.
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { Timestamp, serverTimestamp } = require('firebase/firestore');
const budget = require('../helpers/budget');
const { contextFor, CLUB, OTHER_CLUB } = require('../helpers/contexts');
const { readDoc, seedFixture } = require('../helpers/fixtures');
const { runMatrix } = require('../helpers/matrix');
const payloads = require('../helpers/payloads');

const STUDENT = 'u_student';
const MEMBER = 'u_member';
const PENDING = 'u_pending';
const CLUB_PATH = `clubs/${CLUB}`;
const INSTANT = { patch: { [CLUB_PATH]: { approvalRequired: false } } };
const NO_EDIT = Object.freeze({});

const commit = (role, writes) => budget.buildBatch(contextFor(role).firestore(), Object.values(writes)).commit();
const expectWrite = (request, expected) => (expected === 'allow' ? assertSucceeds(request) : assertFails(request));
const clientTime = () => Timestamp.fromMillis(Date.now() - 60 * 1000);
/**
 * Günlük yazımının alanlarını ezer; belge yolu ezilmiş `clubId` / `kind` ile yeniden kurulur (kimlik
 * alanlardan türetilir — ret, kimlik uyuşmazlığından değil sınanan koşuldan gelsin).
 */
const withActivity = (writes, extra) => {
  const data = { ...writes.activity.data, ...extra };
  const uid = writes.activity.data.actorId;
  return { ...writes, activity: { ...writes.activity, path: payloads.activityPath(data.clubId, uid, data.kind), data } };
};

const apply = () => payloads.applyWrites({ club: CLUB, uid: STUDENT, email: payloads.emailOf('student') });
const join = () => payloads.joinWrites({ club: CLUB, uid: STUDENT, email: payloads.emailOf('student') });
const leave = () => payloads.leaveWrites({ club: CLUB, uid: MEMBER });

runMatrix('activity.json');

describe('activity · create — oturumun kendi üyelik geçişi (rules-spec §3.11 C)', () => {
  test('başvuru batch\'i `application_received` kaydını yazar: yalnızca beş alan, sunucu zamanı', async () => {
    await seedFixture('base');
    const writes = apply();
    await assertSucceeds(commit('student', writes));

    const entry = await readDoc(writes.activity.path);
    expect(Object.keys(entry).sort()).toEqual(['actorId', 'clubId', 'createdAt', 'kind', 'refs']);
    expect(entry).toMatchObject({ clubId: CLUB, actorId: STUDENT, kind: 'application_received', refs: { userId: STUDENT } });
    expect(entry.createdAt.toMillis()).toBe((await readDoc(payloads.membershipPath(CLUB, STUDENT))).createdAt.toMillis());
  });

  // Satır: [başlık, bağlam, taban batch üreticisi, günlük alanı ezmesi, beklenti, veri düzenlemesi?].
  test.each([
    ['katılım → member_joined', 'student', join, {}, 'allow', INSTANT],
    ['ayrılma → member_left', 'member', leave, {}, 'allow'],
    ['başvuru + yanlış tür (member_joined)', 'student', apply, { kind: 'member_joined' }, 'deny'],
    ['başvuru + yanlış tür (member_left)', 'student', apply, { kind: 'member_left' }, 'deny'],
    ['katılım + yanlış tür (application_received)', 'student', join, { kind: 'application_received' }, 'deny', INSTANT],
    ['ayrılma + yanlış tür (member_joined)', 'member', leave, { kind: 'member_joined' }, 'deny'],
    ['başvuru + yönetici türü (application_approved)', 'student', apply, { kind: 'application_approved' }, 'deny'],
    ['başvuru + tanımsız tür', 'student', apply, { kind: 'unknown' }, 'deny'],
    ['actorId başka kullanıcı', 'student', apply, { actorId: MEMBER }, 'deny'],
    ['refs.userId başka kullanıcı', 'student', apply, { refs: { userId: MEMBER } }, 'deny'],
    ['refs boş', 'student', apply, { refs: {} }, 'deny'],
    ['refs fazladan dolu alan (role)', 'student', apply, { refs: { userId: STUDENT, role: 'board' } }, 'deny'],
    ['refs beyaz liste dışı anahtar', 'student', apply, { refs: { userId: STUDENT, note: 'x' } }, 'deny'],
    ['refs açık null alanlar (seed biçimi — W-51)', 'student', apply, { refs: { userId: STUDENT, eventId: null, postId: null, role: null } }, 'allow'],
    ['başka kulübün günlüğüne yazım (clubId: c02)', 'student', apply, { clubId: OTHER_CLUB }, 'deny'],
    ['createdAt istemci saati', 'student', apply, { createdAt: clientTime() }, 'deny'],
    ['beyaz liste dışı alan (updatedAt)', 'student', apply, { updatedAt: serverTimestamp() }, 'deny'],
    ['beyaz liste dışı alan (text)', 'student', apply, { text: 'serbest metin' }, 'deny'],
  ])('%s', async (_title, role, build, extra, expected, edit = NO_EDIT) => {
    await seedFixture('base', undefined, edit);
    const writes = withActivity(build(), extra);
    await expectWrite(commit(role, writes), expected);
    if (expected === 'deny') expect(await readDoc(writes.activity.path)).toBeNull();
    else expect(await readDoc(writes.activity.path)).toMatchObject({ actorId: role === 'member' ? MEMBER : STUDENT });
  });

  test('başvuru iptali (M7) günlük türü taşımaz: iptal + member_left reddedilir', async () => {
    await seedFixture('base');
    const path = payloads.membershipPath(CLUB, PENDING);
    const logPath = payloads.activityPath(CLUB, PENDING, 'member_left');
    const writes = {
      membership: { op: 'update', path, data: { status: 'cancelled', ...payloads.baseUpdate() } },
      activity: { op: 'set', path: logPath, data: payloads.activityOwn(CLUB, PENDING, 'member_left') },
    };
    await assertFails(commit('pending', writes));
    expect((await readDoc(path)).status).toBe('pending');
    expect(await readDoc(logPath)).toBeNull();
  });
});

describe('activity · sabit kimlik — bir geçişe tek günlük belgesi (CD-137 madde 8t)', () => {
  const entry = (kind = 'application_received') => payloads.activityOwn(CLUB, STUDENT, kind);
  const extraLog = (path) => ({ op: 'set', path, data: entry() });

  // Satır: [başlık, yazımları değiştiren işlev]. Taban: öğrencinin başvuru batch'i (M1, priorCount 0).
  test.each([
    ['serbest (otomatik) kimlik', (w) => ({ ...w, activity: { ...w.activity, path: 'activity/a_serbest' } })],
    ['kimlikte başka priorCount', (w) => ({ ...w, activity: { ...w.activity, path: payloads.activityPath(CLUB, STUDENT, 'application_received', 1) } })],
    ['kimlikte başka kullanıcı', (w) => ({ ...w, activity: { ...w.activity, path: payloads.activityPath(CLUB, MEMBER, 'application_received') } })],
    ['kimlikte başka kulüp', (w) => ({ ...w, activity: { ...w.activity, path: payloads.activityPath(OTHER_CLUB, STUDENT, 'application_received') } })],
    ['tek geçişe ikinci günlük (aynı batch, serbest kimlikli ek belge)', (w) => ({ ...w, extra: extraLog('activity/a_ek_1') })],
    ['tek geçişe 50 ek günlük (günlük şişirme)', (w) => ({ ...w, ...Object.fromEntries(Array.from({ length: 50 }, (_, i) => [`extra${i}`, extraLog(`activity/a_ek_${i}`)])) })],
  ])('%s → deny', async (_title, mutate) => {
    await seedFixture('base');
    await assertFails(commit('student', mutate(apply())));
    expect(await readDoc(payloads.membershipPath(CLUB, STUDENT))).toBeNull();
    expect(await readDoc(apply().activity.path)).toBeNull();
  });

  test('geçişten sonra aynı kimliğe yeniden yazım (update) ve geçişsiz ek günlük reddedilir', async () => {
    await seedFixture('base');
    const writes = apply();
    await assertSucceeds(commit('student', writes));
    const before = await readDoc(writes.activity.path);

    // Aynı kimlik = update (`allow update: if false`); başka kimlik = kimlik uyuşmazlığı + geçiş yok.
    await assertFails(commit('student', { again: extraLog(writes.activity.path) }));
    await assertFails(commit('student', { other: extraLog('activity/a_sonradan') }));

    expect(await readDoc(writes.activity.path)).toEqual(before);
    expect(await readDoc('activity/a_sonradan')).toBeNull();
  });

  test('yeniden başvuru yeni kimlik alır: iptal → yeniden başvuru (priorCount 1) günlüğü geçer', async () => {
    await seedFixture('base');
    await assertSucceeds(commit('student', apply()));
    const membership = payloads.membershipPath(CLUB, STUDENT);
    await assertSucceeds(commit('student', { m: { op: 'update', path: membership, data: { status: 'cancelled', ...payloads.baseUpdate() } } }));
    const again = payloads.reapplyWrites({ club: CLUB, uid: STUDENT, status: 'pending' });
    await assertSucceeds(commit('student', again));

    expect(again.activity.path).toBe(payloads.activityPath(CLUB, STUDENT, 'application_received', 1));
    expect(await readDoc(again.activity.path)).toMatchObject({ kind: 'application_received', actorId: STUDENT });
    expect(await readDoc(apply().activity.path)).not.toBeNull();
  });

  test('istemci biçimli üyelikte (`priorCount` anahtarı yok — W-51) ayrılma günlüğü `…_0` kimliğiyle geçer', async () => {
    await seedFixture('base', undefined, { unset: { [payloads.membershipPath(CLUB, MEMBER)]: ['priorCount'] } });
    const writes = leave();
    await assertSucceeds(commit('member', writes));
    expect(await readDoc(writes.activity.path)).toMatchObject({ kind: 'member_left', actorId: MEMBER });
  });
});
