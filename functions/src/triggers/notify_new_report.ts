/** CD-165 b2 — yeni şikayet → etkin süper adminlere `new_report` (gövde: lib/new_report.ts). */
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { REGION } from '../lib/config';
import { log } from '../lib/log';
import { handleReportCreated } from '../lib/new_report';
import { runtimeDeps } from '../lib/runtime';

export const notifyNewReport = onDocumentCreated(
  {
    document: 'reports/{reportId}',
    region: REGION,
    retry: false,
    memory: '256MiB',
    timeoutSeconds: 60,
    maxInstances: 10,
  },
  async (event) => {
    try {
      await handleReportCreated(runtimeDeps(), event.params.reportId, event.data?.data());
    } catch (error) {
      log.error('new_report başarısız', error);
    }
  },
);
