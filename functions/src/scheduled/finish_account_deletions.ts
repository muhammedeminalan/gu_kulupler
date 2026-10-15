/** CD-165 b4 — günlük yarım hesap silme temizliği (gövde: lib/account_cleanup_runner.ts). */
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { REGION, TIME_ZONE } from '../lib/config';
import { runAccountCleanup } from '../lib/account_cleanup_runner';
import { log } from '../lib/log';
import { runtimeDeps } from '../lib/runtime';

export const finishAccountDeletions = onSchedule(
  {
    schedule: 'every day 03:30',
    timeZone: TIME_ZONE,
    region: REGION,
    retryCount: 0,
    memory: '256MiB',
    timeoutSeconds: 540,
    maxInstances: 1,
  },
  async () => {
    try {
      await runAccountCleanup(runtimeDeps());
    } catch (error) {
      log.error('hesap silme temizliği başarısız', error);
    }
  },
);
