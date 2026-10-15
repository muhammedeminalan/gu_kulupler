/**
 * GÜ Kulüpler Cloud Functions (Mod F — T-42; sözleşme docs/plans/T-42.md §4, CD-165). Yalnızca bağlar; gövdeler
 * `lib/` altında, enjekte edilebilir handler'lardır.
 *
 *   triggers/  — sendPushOnNotificationCreated, notifyNewReport, promoteWaitlistOnCancel
 *   scheduled/ — finishAccountDeletions
 *
 * Zamanlanmış hatırlatıcı YOK (Q-07: cihazda yerel; `event_reminder` belgesine push gönderilmez).
 * Deploy YALNIZCA kullanıcı onayıyla (`firebase deploy` bu depoda Claude için yasak).
 */
export { sendPushOnNotificationCreated } from './triggers/send_push_on_notification_created';
export { notifyNewReport } from './triggers/notify_new_report';
export { promoteWaitlistOnCancel } from './triggers/promote_waitlist_on_cancel';
export { finishAccountDeletions } from './scheduled/finish_account_deletions';
