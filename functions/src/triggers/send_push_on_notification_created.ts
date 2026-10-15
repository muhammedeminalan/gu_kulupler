/** CD-165 b1 — yeni bildirim belgesi → push (gövde: lib/send_push.ts). */
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { REGION } from '../lib/config';
import { runtimeDeps } from '../lib/runtime';
import { handleNotificationCreated } from '../lib/send_push';

export const sendPushOnNotificationCreated = onDocumentCreated(
  {
    document: 'notifications/{notificationId}',
    region: REGION,
    retry: false,
    memory: '256MiB',
    timeoutSeconds: 60,
    maxInstances: 20,
  },
  async (event) => {
    await handleNotificationCreated(runtimeDeps(), event.params.notificationId, event.data?.data());
  },
);
