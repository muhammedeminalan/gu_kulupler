// T-42 bağlama · uçtan uca (yalnızca yerel): Functions emülatörü index.ts'teki GERÇEK tetikleyicileri bağlar; test
// yalnızca istemcinin / sunucunun yazacağı belgeleri yazar ve tetikleyicilerin sonucunu bekler. Gönderici emülatörde
// LoggingPushSender'dır (gerçek FCM çağrısı YOK); push'un gittiği `pushReceipts/{id}` makbuzundan okunur. Yükün
// biçimi send_push.emu.test.ts (sahte gönderici) ve push_contract.test.ts (istemciyle ortak dosya) içindedir.
// Zamanlanmış temizlik emülatörde kendiliğinden koşmaz: gövdesi doğrudan çağrılır, zincirin geri kalanı (rsvp iptali →
// terfi → bildirim → push) bağlı tetikleyicilerden geçer.
import { getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { DocumentData, FieldValue, Timestamp } from 'firebase-admin/firestore';
import { runAccountCleanup } from '../src/lib/account_cleanup_runner';
import { emulatorDb, PROJECT, uniq } from '../test/helpers/emulator';

const db = emulatorDb();

beforeAll(() => {
  const auth = process.env.FIREBASE_AUTH_EMULATOR_HOST ?? '';
  if (!/^(127\.0\.0\.1|localhost):\d+$/.test(auth) || auth.endsWith(':9099')) {
    throw new Error(`FIREBASE_AUTH_EMULATOR_HOST yerel e2e emülatörü değil (${auth || 'yok'})`);
  }
  if (getApps().length === 0) initializeApp({ projectId: PROJECT });
});

const DAY_MS = 86_400_000;

/** [read] koşulu sağlayana dek yoklar (tetikleyiciler eşzamansız). */
async function waitFor<T>(read: () => Promise<T | null | undefined>, label: string, timeoutMs = 30_000): Promise<T> {
  const deadline = Date.now() + timeoutMs;
  for (;;) {
    const value = await read();
    if (value !== null && value !== undefined) return value;
    if (Date.now() > deadline) throw new Error(`zaman aşımı: ${label}`);
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
}

const settle = (ms = 2_500) => new Promise((resolve) => setTimeout(resolve, ms));

/** Makbuz `pending` dışına çıkınca verisi. */
const receiptOf = (notificationId: string) =>
  waitFor(async () => {
    const data = (await db.doc(`pushReceipts/${notificationId}`).get()).data();
    return data && data.status !== 'pending' ? data : null;
  }, `pushReceipts/${notificationId}`);

async function seedUser(uid: string, tokens: Array<{ token: string; platform: string; locale?: string }>) {
  await db.doc(`users/${uid}`).set({ status: 'active', isDeleted: false });
  await db.doc(`users/${uid}/private/account`).set({
    email: `${uid}@ogr.gumushane.edu.tr`,
    emailLower: `${uid}@ogr.gumushane.edu.tr`,
    fcmTokens: tokens.map((t) => ({ ...t, updatedAt: Timestamp.now() })),
    isDeleted: false,
  });
}

/** İstemcinin (ClientFanOutDispatcher) yazdığı T-25 şemalı bildirim belgesi. */
const clientNotification = (userId: string, type: string, refs: Record<string, string>) => ({
  userId,
  type,
  refs,
  read: false,
  createdAt: FieldValue.serverTimestamp(),
  updatedAt: FieldValue.serverTimestamp(),
  isDeleted: false,
  deletedAt: null,
  deletedBy: null,
});

async function notificationsOf(userId: string, type: string): Promise<Array<{ id: string; data: DocumentData }>> {
  const snap = await db.collection('notifications').where('userId', '==', userId).where('type', '==', type).get();
  return snap.docs.map((doc) => ({ id: doc.id, data: doc.data() }));
}

async function seedEvent(capacity: number, going: number, waitlist: number) {
  const eventId = uniq('e');
  const clubId = uniq('c');
  await db.doc(`clubs/${clubId}`).set({ name: 'E2E Kulübü', status: 'active', isDeleted: false });
  await db.doc(`events/${eventId}`).set({
    clubId,
    title: 'E2E Etkinlik',
    status: 'published',
    isDeleted: false,
    capacity,
    goingCount: going,
    waitlistCount: waitlist,
    endsAt: Timestamp.fromMillis(Date.now() + 7 * DAY_MS),
  });
  const rsvp = (userId: string, status: string, waitlistMinutesAgo?: number) =>
    db.doc(`rsvps/${eventId}_${userId}`).set({
      eventId,
      clubId,
      userId,
      status,
      ticketCode: 'T',
      isDeleted: false,
      ...(waitlistMinutesAgo !== undefined
        ? { waitlistAt: Timestamp.fromMillis(Date.now() - waitlistMinutesAgo * 60_000) }
        : {}),
    });
  return { eventId, clubId, rsvp };
}

describe('uçtan uca — bağlı tetikleyiciler (Functions emülatörü, sahte FCM)', () => {
  test('istemcinin yazdığı bildirim → push makbuzu: gönderilir / hatırlatıcı makbuzsuz atlanır / tercih süzer', async () => {
    const uid = uniq('u');
    await seedUser(uid, [
      { token: 'e2e-tr', platform: 'android', locale: 'tr' },
      { token: 'e2e-en', platform: 'ios', locale: 'en' },
    ]);
    await db.doc(`settings/${uid}`).set({ announcements: false });
    const eventId = uniq('e');
    // Push freni: event_cancelled yalnızca katılımı olana (rsvpUsersOf ile aynı küme).
    await db.doc(`rsvps/${eventId}_${uid}`).set({ eventId, clubId: 'c01', userId: uid, status: 'going', isDeleted: false });
    const sent = `event_cancelled_${eventId}_${uid}`;
    const reminder = `event_reminder_${eventId}_${uid}`;
    const filtered = `announcement_${uniq('p')}_${uid}`;

    await db.doc(`notifications/${sent}`).create(clientNotification(uid, 'event_cancelled', { clubId: 'c01', eventId }));
    await db.doc(`notifications/${reminder}`).create(clientNotification(uid, 'event_reminder', { clubId: 'c01', eventId }));
    await db.doc(`notifications/${filtered}`).create(clientNotification(uid, 'announcement', { clubId: 'c01', postId: 'p' }));

    expect(await receiptOf(sent)).toMatchObject({ userId: uid, type: 'event_cancelled', status: 'sent', successCount: 2, failureCount: 0 });
    expect(await receiptOf(filtered)).toMatchObject({ status: 'filtered', successCount: 0 });
    // T-45: push üretmeyen tür makbuzdan önce elenir → hatırlatıcı için `pushReceipts` yazılmaz.
    await settle();
    expect((await db.doc(`pushReceipts/${reminder}`).get()).exists).toBe(false);
  });

  test('rsvp iptali (going → cancelled) → en eski bekleyen terfi eder + waitlist_promoted + push; zincir kendini yeniden tetiklemez', async () => {
    const { eventId, clubId, rsvp } = await seedEvent(1, 1, 2);
    const [leaver, older, newer] = [uniq('u'), uniq('u'), uniq('u')];
    await seedUser(older, [{ token: 'e2e-older', platform: 'android' }]);
    await rsvp(leaver, 'going');
    await rsvp(older, 'waitlist', 60);
    await rsvp(newer, 'waitlist', 5);

    // İstemcinin RsvpRepository.cancel yazımı: kayıt + sayaç tek batch.
    const batch = db.batch();
    batch.update(db.doc(`rsvps/${eventId}_${leaver}`), { status: 'cancelled', updatedAt: FieldValue.serverTimestamp() });
    batch.update(db.doc(`events/${eventId}`), { goingCount: FieldValue.increment(-1) });
    await batch.commit();

    await waitFor(async () => {
      const status = (await db.doc(`rsvps/${eventId}_${older}`).get()).get('status');
      return status === 'going' ? status : null;
    }, 'terfi');
    const [promoted] = await waitFor(async () => {
      const list = await notificationsOf(older, 'waitlist_promoted');
      return list.length > 0 ? list : null;
    }, 'waitlist_promoted');
    expect(promoted.id).toMatch(new RegExp(`^waitlist_promoted_[0-9a-f]{20}_${older}$`));
    expect(promoted.data).toMatchObject({ refs: { clubId, eventId }, read: false, isDeleted: false });
    expect(await receiptOf(promoted.id)).toMatchObject({ status: 'sent', successCount: 1 });

    await settle();
    expect((await db.doc(`rsvps/${eventId}_${newer}`).get()).get('status')).toBe('waitlist');
    expect((await db.doc(`events/${eventId}`).get()).data()).toMatchObject({ goingCount: 1, waitlistCount: 1 });
    expect((await db.doc(`events/${eventId}/private/counter`).get()).data()).toMatchObject({
      clubId,
      lastRsvpRef: `rsvps/${eventId}_${older}`,
    });
    expect(await notificationsOf(newer, 'waitlist_promoted')).toHaveLength(0);
  });

  test('yeni şikayet → etkin süper admine new_report (grup anahtarı) + push; aynı hedefin ikinci şikayeti bildirim üretmez', async () => {
    const admin = uniq('admin');
    const reporter = uniq('u');
    await getAuth().createUser({ uid: admin, email: `${admin}@ogr.gumushane.edu.tr` });
    await getAuth().setCustomUserClaims(admin, { superadmin: true });
    await seedUser(admin, [{ token: 'e2e-admin', platform: 'ios', locale: 'en' }]);
    const postId = uniq('p');
    const report = (id: string, reporterId: string) =>
      db.doc(`reports/${id}`).create({
        targetType: 'post',
        targetId: postId,
        targetClubId: 'c01',
        reporterId,
        reason: 'spam',
        note: 'kişisel not',
        status: 'open',
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        isDeleted: false,
        deletedAt: null,
        deletedBy: null,
      });

    await report(`post_${postId}_${reporter}`, reporter);
    const [note] = await waitFor(async () => {
      const list = await notificationsOf(admin, 'new_report');
      return list.length > 0 ? list : null;
    }, 'new_report');
    expect(note.data).toMatchObject({ refs: { reportId: `post_${postId}` }, read: false, isDeleted: false });
    expect(note.data.refs).toEqual({ reportId: `post_${postId}` });
    expect(await receiptOf(note.id)).toMatchObject({ status: 'sent', successCount: 1 });

    const second = uniq('u');
    await report(`post_${postId}_${second}`, second);
    await settle();
    expect(await notificationsOf(admin, 'new_report')).toHaveLength(1);
  });

  test('silinmiş hesap → sunucu temizliği (gövde) → katılım iptali → bağlı terfi + bildirim + push', async () => {
    const { eventId, rsvp } = await seedEvent(1, 1, 1);
    const deleted = uniq('u');
    const waiting = uniq('u');
    await db.doc(`users/${deleted}`).set({
      status: 'deleted',
      isDeleted: false,
      deletedAt: Timestamp.fromMillis(Date.now() - 2 * 60 * 60 * 1000),
    });
    await db.doc(`users/${deleted}/private/account`).set({
      email: 'x@ogr.gumushane.edu.tr',
      emailLower: 'x@ogr.gumushane.edu.tr',
      fcmTokens: [{ token: 'e2e-gone', platform: 'android', updatedAt: Timestamp.now() }],
    });
    await seedUser(waiting, [{ token: 'e2e-waiting', platform: 'android' }]);
    await rsvp(deleted, 'going');
    await rsvp(waiting, 'waitlist', 10);

    const summary = await runAccountCleanup({ db, now: () => new Date() });
    expect(summary).toMatchObject({ failed: 0, rejected: 0 });
    expect(summary.applied).toBeGreaterThanOrEqual(2);

    expect((await db.doc(`users/${deleted}/private/account`).get()).data()).toMatchObject({
      email: '',
      emailLower: '',
      fcmTokens: [],
    });
    expect((await db.doc(`rsvps/${eventId}_${deleted}`).get()).get('status')).toBe('cancelled');
    await waitFor(async () => {
      const status = (await db.doc(`rsvps/${eventId}_${waiting}`).get()).get('status');
      return status === 'going' ? status : null;
    }, 'temizlik sonrası terfi');
    const [promoted] = await waitFor(async () => {
      const list = await notificationsOf(waiting, 'waitlist_promoted');
      return list.length > 0 ? list : null;
    }, 'temizlik sonrası waitlist_promoted');
    expect(await receiptOf(promoted.id)).toMatchObject({ status: 'sent', successCount: 1 });
    // İkinci koşu idempotent: yeni birim yok.
    expect(await runAccountCleanup({ db, now: () => new Date() })).toMatchObject({ applied: 0, failed: 0 });
  });
});
