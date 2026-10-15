/** CD-165 b3 — `going → cancelled` sonrası otomatik terfi (gövde: lib/waitlist_promotion.ts). */
import { onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { REGION } from '../lib/config';
import { runtimeDeps } from '../lib/runtime';
import { handleRsvpUpdated } from '../lib/waitlist_promotion';

export const promoteWaitlistOnCancel = onDocumentUpdated(
  {
    document: 'rsvps/{rsvpId}',
    region: REGION,
    retry: false,
    memory: '256MiB',
    timeoutSeconds: 60,
    maxInstances: 10,
  },
  async (event) => {
    await handleRsvpUpdated(runtimeDeps(), event.id, event.data?.before.data(), event.data?.after.data());
  },
);
