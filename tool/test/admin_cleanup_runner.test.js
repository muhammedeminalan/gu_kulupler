'use strict';
// T-45 · WF1 fixes[1] "Uygulanmayanlar" — tool/admin/finish_account_deletion.js koşucusu (lib/account_cleanup_runner.js),
// functions A5-02 çözümüyle aynı ilke: iki geçiş (önce TÜM hesapların kritik birimleri, sonra kişisel belgeler), sayfalı
// okuma (limitsiz sorgu yok), kişisel yazımlar ≤ sayfa boyu gruplu batch + her yazım kendi `lastUpdateTime` önkoşuluyla,
// kritik birim ayrı batch + ilk yazım önkoşullu (eşzamanlı istemci temizliğiyle çift sayaç düşüşü yok). Betik
// ÇALIŞTIRILMAZ, `firebase-admin` yüklenmez: bellek içi sahte Firestore (fake_firestore.js).
const test = require('node:test');
const assert = require('node:assert/strict');
const { FakeFirestore, FakeTimestamp, fieldValue } = require('./fake_firestore');
const { PERSONAL_PAGE, listDeletedUids, runFinishDeletion } = require('../admin/lib/account_cleanup_runner');

const NOW = new Date('2026-10-15T09:00:00Z');
const DAY = 24 * 60 * 60 * 1000;
const PERSONAL = new Set(['notifications', 'savedPosts', 'blocks']);
const applicant = (uid) => ({ name: 'Ayşe Işık', department: 'd02', year: '2', avatarSeed: uid });

/** Silinmiş hesap: hesap belgesi dolu, etkin üyelik + iletişim, açık katılım, [notifications] kişisel bildirim. */
function seedDeleted(docs, uid, { notifications = 0, blocks = 0 } = {}) {
  docs[`users/${uid}`] = { status: 'deleted', isDeleted: true };
  docs[`users/${uid}/private/account`] = { email: `${uid}@ogr.gumushane.edu.tr`, emailLower: `${uid}@ogr.gumushane.edu.tr`, fcmTokens: ['t'] };
  docs[`clubs/c_${uid}`] = { memberCount: 3 };
  docs[`memberships/c_${uid}_${uid}`] = { clubId: `c_${uid}`, userId: uid, status: 'active', role: 'member', applicant: applicant(uid) };
  docs[`memberships/c_${uid}_${uid}/private/contact`] = { email: `${uid}@ogr.gumushane.edu.tr`, emailLower: `${uid}@ogr.gumushane.edu.tr`, note: 'not' };
  docs[`events/e_${uid}`] = { goingCount: 2, waitlistCount: 0, endsAt: new FakeTimestamp(NOW.getTime() + DAY) };
  docs[`rsvps/e_${uid}_${uid}`] = { eventId: `e_${uid}`, userId: uid, status: 'going' };
  for (let i = 0; i < notifications; i += 1) {
    docs[`notifications/system_${String(i).padStart(4, '0')}_${uid}`] = { userId: uid, type: 'system', isDeleted: false };
  }
  for (let i = 0; i < blocks; i += 1) docs[`blocks/${uid}_v${i}`] = { blockerId: uid, blockedId: `v${i}`, isDeleted: false };
  return docs;
}

const run = (db, uids, options = {}) => {
  const lines = [];
  const promise = runFinishDeletion({
    db,
    fieldValue,
    documentId: FakeFirestore.documentId,
    uids,
    now: () => NOW,
    confirm: async () => true,
    print: (line) => lines.push(line),
    ...options,
  });
  return promise.then((summary) => ({ summary, out: lines.join('\n') }));
};
const isPersonalPath = (p) => PERSONAL.has(p.split('/')[0]);

test('T-45 · finish_account_deletion: sayfalı okuma (limitsiz kişisel sorgu yok), iki geçiş (tüm kritik birimler '
  + 'kişisel belgelerden önce), kişisel gruplu batch ≤ sayfa + her yazım önkoşullu; ikinci koşu boş', async () => {
  // Önde 1000 kişisel belgeli hesap (kullanıcı sınırsız üretebilir — A5-02), arkada e-postası dolu kurban.
  const docs = seedDeleted(seedDeleted({}, 'u_a', { notifications: 1000, blocks: 3 }), 'u_b');
  const db = new FakeFirestore(docs);

  const { summary, out } = await run(db, ['u_a', 'u_b']);

  const personalQueries = db.queries.filter((q) => PERSONAL.has(q.collection) && !q.count);
  assert.ok(personalQueries.length > 0);
  assert.ok(
    personalQueries.every((q) => q.limit !== null && q.limit <= PERSONAL_PAGE && q.returned <= PERSONAL_PAGE),
    'kişisel okuma sayfalı',
  );

  const commits = db.commits.filter((c) => !c.rejected);
  const lastCritical = commits.map((c) => c.paths.some((p) => !isPersonalPath(p))).lastIndexOf(true);
  const firstPersonal = commits.findIndex((c) => c.paths.some(isPersonalPath));
  assert.ok(lastCritical >= 0 && firstPersonal > lastCritical, 'kurbanın kritik temizliği kişisel kümenin arkasında kalmaz');
  for (const c of commits.slice(firstPersonal)) {
    assert.ok(c.paths.every(isPersonalPath), 'kişisel batch yalnızca kişisel yazım');
    assert.ok(c.paths.length <= PERSONAL_PAGE);
    assert.ok(c.preconditioned.every(Boolean), 'her kişisel yazım kendi önkoşuluyla');
  }
  for (const c of commits.slice(0, lastCritical + 1)) assert.equal(c.preconditioned[0], true, 'kritik birimin ilk yazımı önkoşullu');

  // Sonuç: hepsi soft delete (silme yok), sayaçlar bir kez düştü, hesaplar boşaldı.
  const notes = [...db.store.keys()].filter((p) => p.startsWith('notifications/'));
  assert.equal(notes.length, 1000);
  assert.ok(notes.every((p) => db.data(p).isDeleted === true && db.data(p).deletedBy === 'u_a'));
  assert.ok([0, 1, 2].every((i) => db.data(`blocks/u_a_v${i}`).isDeleted === true));
  for (const uid of ['u_a', 'u_b']) {
    assert.deepEqual(db.data(`users/${uid}/private/account`).fcmTokens, []);
    assert.equal(db.data(`users/${uid}/private/account`).email, '');
    assert.equal(db.data(`clubs/c_${uid}`).memberCount, 2);
    assert.equal(db.data(`events/e_${uid}`).goingCount, 1);
    assert.equal(db.data(`memberships/c_${uid}_${uid}/private/contact`).note, '');
  }
  assert.equal(summary.personal.written, 1003);
  assert.deepEqual([summary.critical.rejected, summary.personal.rejected], [0, 0]);
  assert.match(out, /u_a: 6 kritik yazım/);
  assert.match(out, /notifications 1000/);

  // İdempotent: ikinci koşu yazmaz.
  const before = db.commits.length;
  const again = await run(db, ['u_a', 'u_b']);
  assert.equal(db.commits.length, before);
  assert.match(again.out, /Yapılacak iş yok/);
});

test('T-45 · finish_account_deletion: okunduktan (onay beklerken) sonra değişen belgenin kritik birimi reddedilir — '
  + 'çift sayaç düşüşü yok; diğer birimler yazılır, yeniden koşu tamamlar', async () => {
  const db = new FakeFirestore(seedDeleted({}, 'u_c'));
  const confirm = async () => {
    // İstemcinin eşzamanlı resumeCleanup'ı aynı katılımı kapattı (kayıt + sayaç).
    db.patch('rsvps/e_u_c_u_c', { status: 'cancelled' });
    db.patch('events/e_u_c', { goingCount: { fakeIncrement: -1 } });
    return true;
  };
  const { summary, out } = await run(db, ['u_c'], { confirm });
  assert.equal(summary.critical.rejected, 1);
  assert.equal(db.data('events/e_u_c').goingCount, 1, 'sayaç bir kez düştü');
  assert.equal(db.data('memberships/c_u_c_u_c').status, 'left');
  assert.equal(db.data('clubs/c_u_c').memberCount, 2);
  assert.match(out, /önkoşul.*yeniden çalıştır/);
  const again = await run(db, ['u_c']);
  assert.match(again.out, /Yapılacak iş yok/);
});

test('T-45 · finish_account_deletion: kişisel gruplu batch atomik — parçadaki tek belge eşzamanlı değişirse parça '
  + 'reddedilir, diğer parçalar yazılır; yeniden koşu kalanı bitirir', async () => {
  const docs = seedDeleted({}, 'u_d', { notifications: 7 });
  const db = new FakeFirestore(docs);
  let touched = false;
  db.beforeCommit = (paths) => {
    if (!touched && paths.every(isPersonalPath)) {
      touched = true;
      db.patch(paths[1], { read: true }); // istemci bildirimi okudu
    }
  };
  const { summary } = await run(db, ['u_d'], { page: 3 });
  assert.deepEqual(summary.personal, { applied: 2, rejected: 1, written: 4 });
  const live = () => [...db.store.keys()].filter((p) => p.startsWith('notifications/') && db.data(p).isDeleted === false);
  assert.equal(live().length, 3, 'reddedilen parçanın hiçbir yazımı uygulanmadı');
  const personalQueries = db.queries.filter((q) => q.collection === 'notifications' && !q.count);
  assert.ok(personalQueries.every((q) => q.limit === 3));

  db.beforeCommit = null;
  const again = await run(db, ['u_d'], { page: 3 });
  assert.deepEqual(again.summary.personal, { applied: 1, rejected: 0, written: 3 });
  assert.equal(live().length, 0);
});

test('T-45 · finish_account_deletion: kuru çalıştırma hiçbir şey yazmaz; kişisel belgeler sayılır (count), tek tek '
  + 'okunmaz ve basılmaz', async () => {
  const db = new FakeFirestore(seedDeleted({}, 'u_e', { notifications: 600 }));
  const { summary, out } = await run(db, ['u_e'], { confirm: async () => false });
  assert.equal(db.commits.length, 0);
  assert.equal(summary.dry, true);
  assert.ok(db.queries.filter((q) => PERSONAL.has(q.collection)).every((q) => q.count === true));
  assert.match(out, /notifications 600/);
  assert.ok(!out.includes('notifications/system_0001_u_e'), 'kişisel yazımlar tek tek basılmaz');
  assert.match(out, /rsvps\/e_u_e_u_e/, 'kritik yazımlar basılır');
});

test('T-45 · finish_account_deletion --all-deleted: silinmiş hesap listesi sayfalı; geçersiz uid okumadan reddedilir', async () => {
  const docs = {};
  for (let i = 0; i < 5; i += 1) docs[`users/d${i}`] = { status: 'deleted' };
  docs['users/a1'] = { status: 'active' };
  const db = new FakeFirestore(docs);
  assert.deepEqual(await listDeletedUids(db, FakeFirestore.documentId, 2), ['d0', 'd1', 'd2', 'd3', 'd4']);
  assert.ok(db.queries.every((q) => q.collection === 'users' && q.limit === 2));

  const empty = new FakeFirestore({});
  await assert.rejects(run(empty, ['a/b']), /geçersiz uid/);
  assert.equal(empty.queries.length, 0);
});
