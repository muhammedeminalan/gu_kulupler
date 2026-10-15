// CD-165 e · duman testi: index.ts'teki bağlı tetikleyici firebase-functions-test ile sarılıp çalışır; emülatör
// ortamında LoggingPushSender seçilir (gerçek FCM çağrısı YOK).
import functionsTest from 'firebase-functions-test';
import { Timestamp } from 'firebase-admin/firestore';
import { isOfflineEnvironment } from '../src/lib/runtime';
import { emulatorDb, PROJECT, uniq } from './helpers/emulator';

process.env.FUNCTIONS_EMULATOR = 'true';
const db = emulatorDb();
const fft = functionsTest({ projectId: PROJECT });

afterAll(() => fft.cleanup());

describe('index (duman)', () => {
  test('sendPushOnNotificationCreated sarılıp tetiklenir; makbuz yazılır; gönderici çevrimdışı', async () => {
    expect(isOfflineEnvironment()).toBe(true);
    expect(isOfflineEnvironment({ GCLOUD_PROJECT: 'gu-kulupler' })).toBe(false);
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const { sendPushOnNotificationCreated } = require('../src/index') as typeof import('../src/index');
    const uid = uniq('u');
    await db.doc(`users/${uid}`).set({ status: 'active' });
    await db.doc(`users/${uid}/private/account`).set({ fcmTokens: [{ token: 'emu', platform: 'android', updatedAt: Timestamp.now() }] });
    const id = `system_${uniq('k')}_${uid}`;
    const snap = fft.firestore.makeDocumentSnapshot(
      { userId: uid, type: 'system', refs: { textKey: 'welcome' }, read: false, isDeleted: false },
      `notifications/${id}`,
    );

    await fft.wrap(sendPushOnNotificationCreated)({ data: snap, params: { notificationId: id } } as never);

    expect((await db.doc(`pushReceipts/${id}`).get()).data()).toMatchObject({ status: 'sent', successCount: 1 });
  });
});
