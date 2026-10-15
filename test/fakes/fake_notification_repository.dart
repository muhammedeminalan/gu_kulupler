// `NotificationRepository` fake'i (PLAN §16.3; docs/plans/T-25.md §6 g):
// bildirimleri bellekte tutar, gelen kutusunu canlı yayar.
//
//   final inbox = FakeNotificationRepository(clock)..put(notification);
//   await inbox.markRead(notification.id);
//   expect(inbox.notifications[notification.id]!.read, isTrue);
//
// Gerçek repository + Security Rules'un birlikte verdiği sonuçları izler:
// gelen kutusu sahibinin silinmemiş bildirimleridir (en yeni üstte, `limit`);
// silme soft delete'tir (D-10), Geri al yalnızca silen sahibine açıktır;
// `createSelf` belge varsa (silinmiş olsa da) yazmaz. Rules'un reddettiği
// yazımlar `permissionDenied` döner: olmayan ya da başkasının bildirimini
// toplu okundu / silme, silinmemişi geri alma. Tek bildirimin okundu
// işaretinde olmayan belge `notFound`'dur (Firestore `update`).
import 'dart:async';

import 'package:gu_data/gu_data.dart';

import 'fake_base.dart';

final class FakeNotificationRepository extends FakeBase
    implements NotificationRepository {
  /// "Şu an" [_clock] saatidir (`createdAt`, `updatedAt`, `deletedAt`).
  FakeNotificationRepository(this._clock);

  final AppClock _clock;

  /// `notifications/{id}` belgeleri (anahtar = belge kimliği). Test ön
  /// veriyi [put] ile yazar.
  final Map<String, NotificationModel> notifications =
      <String, NotificationModel>{};

  /// Her değişiklikte `null`, enjekte edilen hatada hata olayı.
  final StreamController<FirestoreError?> _changes =
      StreamController<FirestoreError?>.broadcast();

  /// [notification]'ı yazar (varsa üzerine) ve gelen kutularını yeniler.
  void put(NotificationModel notification) {
    notifications[notification.id] = notification;
    _changes.add(null);
  }

  /// Açık gelen kutusu akışlarına [error] olayı yayar (akış kapanmaz).
  void emitInboxError(FirestoreError error) => _changes.add(error);

  @override
  Stream<FirestoreResult<List<NotificationModel>>> watchInbox(
    String userId, {
    int limit = Limits.notificationInboxLimit,
  }) async* {
    record('watchInbox', [userId, limit]);
    if (_rejected<List<NotificationModel>>([userId]) case final failure?) {
      yield failure;
      return;
    }
    if (limit < 1) {
      yield const FirebaseFailure(FirestoreError.invalidArgument);
      return;
    }
    yield FirebaseSuccess(_inboxOf(userId, limit));
    yield* _changes.stream.map(
      (error) => error == null
          ? FirebaseSuccess(_inboxOf(userId, limit))
          : FirebaseFailure(error),
    );
  }

  @override
  Future<FirestoreResult<NotificationModel?>> getNotification(
    String notificationId,
  ) async {
    record('getNotification', [notificationId]);
    if (_rejected<NotificationModel?>([notificationId]) case final failure?) {
      return failure;
    }
    final existing = notifications[notificationId];
    if (existing != null && existing.isDeleted) {
      return const FirebaseFailure(FirestoreError.notFound);
    }
    return FirebaseSuccess(existing);
  }

  @override
  Future<FirestoreResult<void>> markRead(String notificationId) async {
    record('markRead', [notificationId]);
    if (_rejected<void>([notificationId]) case final failure?) return failure;
    final existing = notifications[notificationId];
    if (existing == null) {
      return const FirebaseFailure(FirestoreError.notFound);
    }
    put(existing.copyWith(read: true, updatedAt: _clock.nowUtc()));
    return const FirebaseSuccess(null);
  }

  @override
  Future<FirestoreResult<void>> markAllRead(
    String userId,
    List<String> unreadIds,
  ) async {
    record('markAllRead', [userId, unreadIds]);
    final ids = unreadIds.toSet().toList();
    if (_rejected<void>([userId, ...ids]) case final failure?) return failure;
    // Tek parça (≤ batchMaxWrites) gibi: biri yazılamazsa hiçbiri.
    if (!ids.every((id) => notifications[id]?.userId == userId)) {
      return _denied();
    }
    final now = _clock.nowUtc();
    for (final id in ids) {
      notifications[id] = notifications[id]!.copyWith(
        read: true,
        updatedAt: now,
      );
    }
    if (ids.isNotEmpty) _changes.add(null);
    return const FirebaseSuccess(null);
  }

  @override
  Future<FirestoreResult<void>> softDeleteNotification(
    String notificationId, {
    required String actorId,
  }) async {
    record('softDeleteNotification', [notificationId, actorId]);
    if (_rejected<void>([notificationId, actorId]) case final failure?) {
      return failure;
    }
    final existing = notifications[notificationId];
    if (existing == null || existing.isDeleted || existing.userId != actorId) {
      return _denied();
    }
    final now = _clock.nowUtc();
    put(
      existing.copyWith(
        isDeleted: true,
        deletedAt: now,
        deletedBy: actorId,
        updatedAt: now,
      ),
    );
    return const FirebaseSuccess(null);
  }

  @override
  Future<FirestoreResult<void>> restoreNotification(
    String notificationId,
  ) async {
    record('restoreNotification', [notificationId]);
    if (_rejected<void>([notificationId]) case final failure?) return failure;
    final existing = notifications[notificationId];
    if (existing == null ||
        !existing.isDeleted ||
        existing.deletedBy != existing.userId) {
      return _denied();
    }
    put(
      existing.copyWith(
        isDeleted: false,
        clearDeletedAt: true,
        clearDeletedBy: true,
        updatedAt: _clock.nowUtc(),
      ),
    );
    return const FirebaseSuccess(null);
  }

  @override
  Future<FirestoreResult<void>> createSelf({
    required String userId,
    required String eventId,
    required String clubId,
  }) async {
    record('createSelf', [userId, eventId, clubId]);
    if (_rejected<void>([userId, eventId, clubId]) case final failure?) {
      return failure;
    }
    final id = FirestoreIds.notification(
      NotificationType.eventReminder.json,
      eventId,
      userId,
    );
    if (notifications.containsKey(id)) return const FirebaseSuccess(null);
    final now = _clock.nowUtc();
    put(
      NotificationModel(
        id: id,
        userId: userId,
        type: NotificationType.eventReminder,
        refs: NotificationRefsModel(clubId: clubId, eventId: eventId),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return const FirebaseSuccess(null);
  }

  /// [userId]'nin silinmemiş bildirimleri, `createdAt` azalan, en çok
  /// [limit].
  List<NotificationModel> _inboxOf(String userId, int limit) {
    final mine = [
      for (final notification in notifications.values)
        if (notification.userId == userId && !notification.isDeleted)
          notification,
    ]..sort(_latestFirst);
    return mine.take(limit).toList(growable: false);
  }

  /// `createdAt` azalan; zamanı olmayan bildirim sonda.
  static int _latestFirst(NotificationModel a, NotificationModel b) {
    final left = a.createdAt;
    final right = b.createdAt;
    if (left == null || right == null) {
      return left == right ? 0 : (left == null ? 1 : -1);
    }
    return right.compareTo(left);
  }

  static FirestoreResult<T> _denied<T>() =>
      const FirebaseFailure(FirestoreError.permissionDenied);

  /// Bekleyen hata ya da geçersiz kimlik varsa başarısızlık; yoksa `null`.
  FirestoreResult<T>? _rejected<T>(List<String> ids) {
    final failure = switch (takeFailure()) {
      null => null,
      final FirestoreError error => error,
      _ => FirestoreError.unknown,
    };
    if (failure != null) return FirebaseFailure(failure);
    if (!ids.every(RepositoryHelpers.isValidId)) {
      return const FirebaseFailure(FirestoreError.invalidArgument);
    }
    return null;
  }
}
