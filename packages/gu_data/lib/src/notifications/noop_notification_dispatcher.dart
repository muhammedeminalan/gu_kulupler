import 'package:cloud_firestore/cloud_firestore.dart'
    show Transaction, WriteBatch;
import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/models/enums/club_role.dart';
import 'package:gu_data/src/notifications/notification_dispatcher.dart';

/// Hiçbir bildirim yazmayan [NotificationDispatcher] (PLAN §10.5, CD-36).
///
/// Gerçek dağıtıcı (`ClientFanOutDispatcher`) yazılana kadar kompozisyon
/// kökünde bağlıdır: `batch` alan üyeler batch'e hiçbir şey eklemez, fan-out
/// üyeleri hiçbir belge yazmaz. Her üye hedeflenen alıcı sayısını
/// `requested`, sıfırı `written` olarak bildirir.
final class NoopNotificationDispatcher implements NotificationDispatcher {
  /// Durumsuz dağıtıcı.
  const NoopNotificationDispatcher();

  /// Tek alıcılı bildirimin alıcı sayısı.
  static const int _single = 1;

  /// Alıcıları dağıtıcının çözeceği ya da hiç üretilmeyen bildirimde
  /// bilinen alıcı sayısı.
  static const int _unresolved = 0;

  @override
  Future<FirestoreResult<DispatchReport>> notifyApplicationReceived({
    required String clubId,
    required String applicantId,
    required int sequence,
  }) => _skipped(_unresolved);

  @override
  Future<FirestoreResult<DispatchReport>> notifyApplicationDecided({
    required String clubId,
    required String applicantId,
    required bool approved,
    required WriteBatch batch,
  }) => _skipped(_single);

  @override
  Future<FirestoreResult<DispatchReport>> notifyRemoved({
    required String clubId,
    required String userId,
    required WriteBatch batch,
  }) => _skipped(_single);

  @override
  Future<FirestoreResult<DispatchReport>> notifyRoleChanged({
    required String clubId,
    required String userId,
    required ClubRole role,
    required WriteBatch batch,
  }) => _skipped(_single);

  @override
  Future<FirestoreResult<DispatchReport>>
  notifyApplicationDecidedInTransaction({
    required String clubId,
    required String applicantId,
    required bool approved,
    required Transaction transaction,
  }) => _skipped(_single);

  @override
  Future<FirestoreResult<DispatchReport>> notifyRemovedInTransaction({
    required String clubId,
    required String userId,
    required Transaction transaction,
  }) => _skipped(_single);

  @override
  Future<FirestoreResult<DispatchReport>> notifyRoleChangedInTransaction({
    required String clubId,
    required String userId,
    required ClubRole role,
    required Transaction transaction,
  }) => _skipped(_single);

  @override
  Future<FirestoreResult<DispatchReport>> notifyAnnouncement({
    required String postId,
    required String clubId,
    required List<String> recipients,
  }) => _skipped(recipients.length);

  @override
  Future<FirestoreResult<DispatchReport>> notifyEventNew({
    required String eventId,
    required String clubId,
    required List<String> recipients,
  }) => _skipped(recipients.length);

  @override
  Future<FirestoreResult<DispatchReport>> notifyEventCancelled({
    required String eventId,
    required String clubId,
    required List<String> recipients,
  }) => _skipped(recipients.length);

  @override
  Future<FirestoreResult<DispatchReport>> notifyWaitlistPromoted({
    required String eventId,
    required String clubId,
    required String userId,
    required WriteBatch batch,
  }) => _skipped(_single);

  @override
  Future<FirestoreResult<DispatchReport>> notifyWaitlistPromotedInTransaction({
    required String eventId,
    required String clubId,
    required String userId,
    required Transaction transaction,
  }) => _skipped(_single);

  @override
  Future<FirestoreResult<DispatchReport>> notifyReportResolved({
    required String reportGroupKey,
    required List<String> reporterIds,
    required WriteBatch batch,
  }) => _skipped(reporterIds.length);

  @override
  Future<FirestoreResult<DispatchReport>> notifyNewReport({
    required String reportId,
  }) => _skipped(_unresolved);

  @override
  Future<FirestoreResult<DispatchReport>> notifySystem({
    required List<String> userIds,
    required String textKey,
  }) => _skipped(userIds.length);

  /// [requested] alıcının hiçbirine yazılmadığını bildiren başarı.
  static Future<FirestoreResult<DispatchReport>> _skipped(int requested) =>
      Future.value(
        FirebaseSuccess(
          DispatchReport(requested: requested, written: 0, failedChunks: 0),
        ),
      );
}
