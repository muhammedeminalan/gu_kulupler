/**
 * `notifyNewReport` gövdesi (CD-165 b2; CD-37'nin Mod F karşılığı): yeni şikayet → etkin süper adminlere
 * `new_report` bildirimi (push'u `sendPushOnNotificationCreated` gönderir).
 *
 * - Alıcılar: [SuperAdminDirectory] ∩ `users.status == 'active'`, şikayet eden hariç.
 * - Aynı hedefin (`targetType`, `targetId`) açık grubu zaten bildirildiyse yazılmaz. **Sözleşmeye küçük ek:**
 *   "başka açık şikayet varsa yok" yerine "bundan ÖNCE açılmış açık şikayet varsa yok" (`createdAt`, eşitlikte belge
 *   kimliği). Aynı anda açılan iki şikayet birbirini görüp ikisi de susmasın; grubun ilki tam bir kez bildirir.
 * - Belge `notifications/new_report_{sha256(reportId)[0:20]}_{adminUid}`, `refs.reportId` = grup anahtarı
 *   `{targetType}_{targetId}` (CD-163); `create()` → yeniden teslimde ALREADY_EXISTS yutulur (çift belge yok).
 */
import { FieldPath, Timestamp } from 'firebase-admin/firestore';
import { Col, REPORT_GROUP_SCAN, REPORT_TARGET_ID, REPORT_TARGET_TYPES } from './config';
import { Deps } from './deps';
import { eventKeyOf, notificationData, notificationId } from './ids';
import { isAlreadyExists, isValidId } from './model';
import { log } from './log';

export interface NewReportResult {
  written: number;
  reason?: 'invalid' | 'not_open' | 'group_notified' | 'no_recipients';
}

/** [a] şikayeti [b]'den önce mi açıldı? (`createdAt`; eksik zaman en sona; eşitlikte belge kimliği) */
function openedBefore(a: { id: string; at: Timestamp | null }, b: { id: string; at: Timestamp | null }): boolean {
  if (a.at && b.at && !a.at.isEqual(b.at)) return a.at.toMillis() < b.at.toMillis();
  if (a.at && !b.at) return true;
  if (!a.at && b.at) return false;
  return a.id < b.id;
}

const timestampOf = (value: unknown): Timestamp | null => (value instanceof Timestamp ? value : null);

export async function handleReportCreated(
  deps: Pick<Deps, 'db' | 'superAdmins'>,
  reportId: string,
  data: Record<string, unknown> | undefined,
): Promise<NewReportResult> {
  const targetType = data?.targetType;
  const targetId = data?.targetId;
  const reporterId = data?.reporterId;
  if (
    !data ||
    !isValidId(reportId) ||
    typeof targetType !== 'string' ||
    !REPORT_TARGET_TYPES.has(targetType) ||
    typeof targetId !== 'string' ||
    !REPORT_TARGET_ID.test(targetId) ||
    !isValidId(reporterId)
  ) {
    return { written: 0, reason: 'invalid' };
  }
  if (data.status !== 'open' || data.isDeleted === true) return { written: 0, reason: 'not_open' };

  const { db } = deps;
  const self = { id: reportId, at: timestampOf(data.createdAt) };
  const group = await db
    .collection(Col.reports)
    .where('targetType', '==', targetType)
    .where('targetId', '==', targetId)
    .where('status', '==', 'open')
    .select('createdAt', 'isDeleted')
    .limit(REPORT_GROUP_SCAN)
    .get();
  const earlier = group.docs.some(
    (doc) =>
      doc.id !== reportId &&
      doc.get('isDeleted') !== true &&
      openedBefore({ id: doc.id, at: timestampOf(doc.get('createdAt')) }, self),
  );
  if (earlier) return { written: 0, reason: 'group_notified' };

  const admins = [...new Set(await deps.superAdmins.list())].filter((uid) => isValidId(uid) && uid !== reporterId);
  if (admins.length === 0) return { written: 0, reason: 'no_recipients' };
  const users = await db.getAll(...admins.map((uid) => db.collection(Col.users).doc(uid)), {
    fieldMask: [new FieldPath('status')],
  });
  const recipients = users.filter((snap) => snap.exists && snap.get('status') === 'active').map((snap) => snap.id);
  if (recipients.length === 0) return { written: 0, reason: 'no_recipients' };

  const key = eventKeyOf(reportId);
  const refs = { reportId: `${targetType}_${targetId}` };
  const results = await Promise.allSettled(
    recipients.map((uid) =>
      db
        .collection(Col.notifications)
        .doc(notificationId('new_report', key, uid))
        .create(notificationData('new_report', uid, refs)),
    ),
  );
  let written = 0;
  let failed = 0;
  for (const result of results) {
    if (result.status === 'fulfilled') written += 1;
    else if (!isAlreadyExists(result.reason)) failed += 1;
  }
  // Şikayet kimliği şikayet edenin uid'ini içerir: log yalnızca türetilmiş anahtarı taşır.
  if (failed > 0) log.warn('new_report bildirimi eksik yazıldı', { key, written, failed });
  log.info('new_report', { key, recipients: recipients.length, written });
  return { written };
}
