'use strict';
/**
 * W-91 · `finish_account_deletion.js` koşucusu (T-45 — WF1 A5-02 düzeltmesinin betik karşılığı; ilke
 * `functions/src/lib/account_cleanup_runner.ts` ile aynı). `firebase-admin`'i YÜKLEMEZ: `db` (Admin SDK Firestore),
 * `fieldValue` (`admin.firestore.FieldValue`) ve `documentId` (`admin.firestore.FieldPath.documentId`) dışarıdan
 * verilir → saf testle sınanır (tool/test/admin_cleanup_runner.test.js, bellek içi sahte Firestore).
 *
 * - **Neden:** kişisel belgeleri (`notifications` / `savedPosts` / `blocks`) kullanıcı sınırsız üretebilir (A5-02).
 *   Eski betik hepsini limitsiz tek sorguyla belleğe alıyor, kuru çalıştırmada her yazımı basıyor ve hesap hesap
 *   ilerlediği için büyük kümeli bir hesap arkasındaki hesapların e-posta / iletişim temizliğini geciktiriyordu.
 * - **İki geçiş:** 1. geçiş TÜM hesapların kritik birimlerini (hesap belgesi, katılım + sayaç, üyelik + sayaç +
 *   danışman + iletişim) yazar; 2. geçiş kişisel belgeleri soft delete eder.
 * - **Sayfalı okuma:** silinmiş hesap listesi ve kişisel belgeler `orderBy(documentId()).limit(...)` + `startAfter`
 *   sayfalarıyla okunur (eşitlik süzgeçleri + `__name__` sırası → yeni indeks gerekmez). Kuru çalıştırma kişisel
 *   belgeleri tek tek okumaz, `count()` ile sayar ve yalnızca sayıyı basar.
 * - **Önkoşul:** kritik her birim AYRI batch'tir, ilk yazımı belgenin okunduğu andaki `lastUpdateTime` önkoşuluyla
 *   (onay beklerken istemcinin `resumeCleanup`'ı belgeyi değiştirdiyse birim reddedilir → çift sayaç düşüşü yok).
 *   Kişisel yazımlar ≤ [PERSONAL_PAGE] yazımlık gruplu batch'tir (bir sayfa = bir batch), HER yazım kendi önkoşuluyla;
 *   biri tutmazsa parça atomik olarak reddedilir. Reddedilen iş betik yeniden çalıştırılınca yapılır (idempotent).
 * - Hiçbir belge, dosya ya da Auth kimliği silinmez (D-10, Q-11). Planlayıcı değişmez ([buildCleanupPlan]).
 */
const { buildCleanupPlan } = require('./account_cleanup');
const { BATCH_MAX_WRITES, describeWrites, isValidId, materialize } = require('./admin_cli');
const { plain } = require('./admin_runtime');

/** Kişisel okuma sayfası = gruplu yazım batch'i (Firestore batch sınırı 500; `BATCH_MAX_WRITES`). */
const PERSONAL_PAGE = BATCH_MAX_WRITES;
/** `--all-deleted` hesap listesinin sayfası (yalnızca kimlikler bellekte tutulur). */
const USERS_PAGE = 500;

/** Kişisel koleksiyonlar ve sahiplik alanı (planlayıcı girdisindeki sırayla). */
const PERSONAL_SOURCES = Object.freeze([
  ['notifications', 'userId'],
  ['savedPosts', 'userId'],
  ['blocks', 'blockerId'],
]);

/** `lastUpdateTime` önkoşulu tutmadı (Admin SDK sayısal `code`, bazı yollarda dizge). */
const isFailedPrecondition = (error) => !!error && (error.code === 9 || error.code === 'failed-precondition');

/** `users.status == 'deleted'` hesapların kimlikleri, `documentId()` sırasıyla sayfa sayfa. */
async function listDeletedUids(db, documentId, page = USERS_PAGE) {
  const base = db.collection('users').where('status', '==', 'deleted').orderBy(documentId()).limit(page);
  const uids = [];
  let cursor;
  for (;;) {
    const snapshot = await (cursor ? base.startAfter(cursor) : base).get();
    uids.push(...snapshot.docs.map((d) => d.id));
    if (snapshot.size < page) return uids;
    cursor = snapshot.docs[snapshot.docs.length - 1];
  }
}

/** Hesabın kritik belgeleri (yalnızca okuma; `personal` boş) + okunan her belgenin sürümü. */
async function readCriticalState(db, uid, now) {
  const versions = new Map();
  const get = async (path) => {
    const snap = await db.doc(path).get();
    if (!snap.exists) return null;
    versions.set(path, snap.updateTime);
    return plain(snap.data());
  };
  const docsOf = (collection, snapshot) => {
    const out = {};
    for (const doc of snapshot.docs) {
      versions.set(`${collection}/${doc.id}`, doc.updateTime);
      out[doc.id] = plain(doc.data());
    }
    return out;
  };
  const memberships = docsOf('memberships', await db.collection('memberships').where('userId', '==', uid).get());
  const rsvps = docsOf('rsvps', await db.collection('rsvps').where('userId', '==', uid).get());
  const contacts = {};
  const clubs = {};
  for (const [id, m] of Object.entries(memberships)) {
    contacts[id] = await get(`memberships/${id}/private/contact`);
    if (isValidId(m.clubId) && !(m.clubId in clubs)) clubs[m.clubId] = await get(`clubs/${m.clubId}`);
  }
  const events = {};
  for (const r of Object.values(rsvps)) {
    if (isValidId(r.eventId) && !(r.eventId in events)) events[r.eventId] = await get(`events/${r.eventId}`);
  }
  const input = {
    uid,
    now,
    user: await get(`users/${uid}`),
    account: await get(`users/${uid}/private/account`),
    memberships,
    contacts,
    clubs,
    rsvps,
    events,
    personal: {},
  };
  return { input, versions };
}

const personalQuery = (db, collection, field, uid) =>
  db.collection(collection).where(field, '==', uid).where('isDeleted', '==', false);

/** Silinmemiş kişisel belge sayıları (`count()` — belgeler okunmaz). */
async function countPersonal(db, uid) {
  const counts = {};
  for (const [collection, field] of PERSONAL_SOURCES) {
    counts[collection] = (await personalQuery(db, collection, field, uid).count().get()).data().count;
  }
  return counts;
}

/** Kişisel belgeler sayfa sayfa: `{collection, docs, versions}` (bir sayfa bellekte). */
async function* personalPages(db, documentId, uid, page) {
  for (const [collection, field] of PERSONAL_SOURCES) {
    const base = personalQuery(db, collection, field, uid).orderBy(documentId()).limit(page);
    let cursor;
    for (;;) {
      const snapshot = await (cursor ? base.startAfter(cursor) : base).get();
      if (snapshot.size === 0) break;
      const docs = {};
      const versions = new Map();
      for (const doc of snapshot.docs) {
        docs[doc.id] = plain(doc.data());
        versions.set(`${collection}/${doc.id}`, doc.updateTime);
      }
      yield { collection, docs, versions };
      if (snapshot.size < page) break;
      cursor = snapshot.docs[snapshot.docs.length - 1];
    }
  }
}

/** 2. geçişin planlayıcı girdisi: yalnızca kişisel belgeler (kritik alanlar boş → yalnızca kişisel birim üretir). */
const personalOnly = (uid, now, user, collection, docs) => ({
  uid,
  now,
  user,
  account: null,
  memberships: {},
  contacts: {},
  clubs: {},
  rsvps: {},
  events: {},
  personal: { [collection]: docs },
});

/**
 * Tek batch: [each] → her yazım, değilse yalnızca ilk yazım okunan sürüm önkoşuluyla. Döner `true` uygulandı,
 * `false` önkoşul tutmadı (atomik ret); başka hata fırlar.
 */
async function commitPreconditioned(db, fieldValue, writes, versions, each) {
  const batch = db.batch();
  writes.forEach((write, index) => {
    if (write.op !== 'update') throw new Error(`desteklenmeyen işlem: ${write.op}`);
    const ref = db.doc(write.path);
    const data = materialize(write.data, fieldValue);
    const version = each || index === 0 ? versions.get(write.path) : undefined;
    if (version) batch.update(ref, data, { lastUpdateTime: version });
    else batch.update(ref, data);
  });
  try {
    await batch.commit();
    return true;
  } catch (error) {
    if (isFailedPrecondition(error)) return false;
    throw error;
  }
}

const sum = (counts) => Object.values(counts).reduce((a, b) => a + b, 0);
const withoutPersonal = ({ personal: _personal, ...rest }) => rest;

/**
 * @param {{db: object, fieldValue: object, documentId: () => unknown, uids: string[], now?: () => Date,
 *   confirm: (message: string) => Promise<boolean>, print?: (line: string) => void, page?: number}} options
 *   `confirm` kuru çalıştırmada `false` döner (betikte `confirmApply`).
 */
async function runFinishDeletion({ db, fieldValue, documentId, uids, now = () => new Date(), confirm, print = console.log, page = PERSONAL_PAGE }) {
  const size = Math.max(1, Math.min(page, PERSONAL_PAGE));
  for (const uid of uids) if (!isValidId(uid)) throw new Error(`geçersiz uid: ${uid}`);
  const summary = {
    accounts: 0,
    dry: true,
    critical: { applied: 0, rejected: 0 },
    personal: { applied: 0, rejected: 0, written: 0 },
  };

  // Plan (yalnızca okuma): kritik birimler tam, kişisel belgeler yalnızca sayı.
  const accounts = [];
  let criticalWrites = 0;
  let personalTotal = 0;
  for (const uid of uids) {
    const { input, versions } = await readCriticalState(db, uid, now());
    const plan = buildCleanupPlan(input);
    if (plan.skip) {
      print(`\n— ${uid}: atlandı (${plan.skip})`);
      continue;
    }
    const writes = plan.units.flat();
    const personal = await countPersonal(db, uid);
    const personalLine = PERSONAL_SOURCES.map(([c]) => `${c} ${personal[c]}`).join(', ');
    print(`\n— ${uid}: ${writes.length} kritik yazım ${JSON.stringify(withoutPersonal(plan.counts))} · kişisel soft delete: ${personalLine}`);
    if (writes.length > 0) print(describeWrites(writes));
    for (const warning of plan.warnings) print(`  ! ${warning}`);
    if (writes.length + sum(personal) === 0) continue;
    accounts.push({ uid, user: input.user, plan, versions });
    criticalWrites += writes.length;
    personalTotal += sum(personal);
  }
  summary.accounts = accounts.length;
  if (accounts.length === 0) {
    print('\nYapılacak iş yok.');
    return summary;
  }
  const message = `${accounts.length} silinmiş hesabın temizliği YAZILACAK (kritik ${criticalWrites} yazım, kişisel ${personalTotal} belge).`;
  if (!(await confirm(message))) return summary;
  summary.dry = false;

  // 1. geçiş — TÜM hesapların kritik birimleri (her birim ayrı batch, ilk yazım önkoşullu).
  for (const { uid, plan, versions } of accounts) {
    let applied = 0;
    for (const unit of plan.units) {
      if (unit.length === 0) continue;
      if (await commitPreconditioned(db, fieldValue, unit, versions, false)) {
        applied += unit.length;
        summary.critical.applied += 1;
      } else summary.critical.rejected += 1;
    }
    if (applied > 0) print(`${uid}: ${applied} kritik yazım uygulandı.`);
  }

  // 2. geçiş — kişisel belgeler (sayfa = gruplu batch, her yazım önkoşullu).
  for (const { uid, user } of accounts) {
    let written = 0;
    for await (const { collection, docs, versions } of personalPages(db, documentId, uid, size)) {
      const writes = buildCleanupPlan(personalOnly(uid, now(), user, collection, docs)).units.flat();
      if (writes.length === 0) continue;
      if (await commitPreconditioned(db, fieldValue, writes, versions, true)) {
        written += writes.length;
        summary.personal.applied += 1;
      } else summary.personal.rejected += 1;
    }
    summary.personal.written += written;
    if (written > 0) print(`${uid}: ${written} kişisel belge soft delete edildi.`);
  }

  const rejected = summary.critical.rejected + summary.personal.rejected;
  if (rejected > 0) {
    print(`\n! ${rejected} batch önkoşul tutmadığı için reddedildi (belge okunduktan sonra değişti — eşzamanlı temizlik). Hiçbir yarım yazım yok; betiği yeniden çalıştır.`);
  }
  return summary;
}

module.exports = {
  PERSONAL_PAGE,
  PERSONAL_SOURCES,
  USERS_PAGE,
  countPersonal,
  listDeletedUids,
  readCriticalState,
  runFinishDeletion,
};
