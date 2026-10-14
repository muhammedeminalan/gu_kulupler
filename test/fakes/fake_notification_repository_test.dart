// T-25 · FakeNotificationRepository sözleşmesi (PLAN §16.3): `notifications`;
// gerçek repository + Security Rules sonuçlarını izler (yalnızca sahibi,
// silme = soft delete — D-10; docs/plans/T-25.md §6 g).
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';

import '../helpers/fake_app_clock.dart';
import 'fake_notification_repository.dart';
import 'register_fakes.dart';

const String _me = 'u_mehmet';
const String _other = 'u_ayse';

void main() {
  late FakeAppClock clock;
  late FakeNotificationRepository fake;

  NotificationModel note(String id, String userId, {int minutesAgo = 0}) =>
      NotificationModel(
        id: id,
        userId: userId,
        type: NotificationType.announcement,
        refs: const NotificationRefsModel(clubId: 'c01', postId: 'p01'),
        createdAt: clock.nowUtc().subtract(Duration(minutes: minutesAgo)),
      );

  setUp(() {
    clock = FakeAppClock(DateTime.utc(2026, 10, 13, 9));
    fake = FakeNotificationRepository(clock)
      ..put(note('n_old', _me, minutesAgo: 30))
      ..put(note('n_new', _me))
      ..put(note('n_theirs', _other));
  });

  group('T-25 · FakeNotificationRepository', () {
    test('NotificationRepository arayüzünü uygular; registerDefaultFakes '
        'kaydeder', () async {
      await GetIt.I.reset();
      addTearDown(GetIt.I.reset);
      registerDefaultFakes();
      expect(
        GetIt.I<NotificationRepository>(),
        isA<FakeNotificationRepository>(),
      );
    });

    test('watchInbox: yalnızca sahibinin silinmemişleri, en yeni üstte, '
        'limit; değişiklik ve hata canlı yayılır', () async {
      final events = <FirestoreResult<List<NotificationModel>>>[];
      final subscription = fake.watchInbox(_me).listen(events.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await fake.softDeleteNotification('n_old', actorId: _me);
      fake.emitInboxError(FirestoreError.unavailable);
      await pumpEventQueue();

      expect(
        [for (final n in events.first.dataOrNull!) n.id],
        [
          'n_new',
          'n_old',
        ],
      );
      expect([for (final n in events[1].dataOrNull!) n.id], ['n_new']);
      expect(events.last.errorOrNull, FirestoreError.unavailable);
      expect(
        [
          for (final n
              in (await fake.watchInbox(_me, limit: 1).first).dataOrNull!)
            n.id,
        ],
        ['n_new'],
      );
    });

    test('markRead / markAllRead: okundu; başkasının bildirimi parçada '
        'permissionDenied ve hiçbiri yazılmaz', () async {
      await fake.markRead('n_new');
      expect(fake.notifications['n_new']!.read, isTrue);
      expect(
        (await fake.markRead('yok')).errorOrNull,
        FirestoreError.notFound,
      );

      expect(
        (await fake.markAllRead(_me, ['n_old', 'n_theirs'])).errorOrNull,
        FirestoreError.permissionDenied,
      );
      expect(fake.notifications['n_old']!.read, isFalse);
      expect((await fake.markAllRead(_me, ['n_old'])).isSuccess, isTrue);
      expect(fake.notifications['n_old']!.read, isTrue);
    });

    test('soft delete yalnızca sahibine; Geri al yalnızca silinmişe', () async {
      expect(
        (await fake.softDeleteNotification(
          'n_theirs',
          actorId: _me,
        )).errorOrNull,
        FirestoreError.permissionDenied,
      );
      await fake.softDeleteNotification('n_new', actorId: _me);
      expect(fake.notifications['n_new']!.deletedBy, _me);
      expect(
        (await fake.restoreNotification('n_old')).errorOrNull,
        FirestoreError.permissionDenied,
      );
      await fake.restoreNotification('n_new');
      expect(fake.notifications['n_new']!.isDeleted, isFalse);
    });

    test('createSelf: kimlik event_reminder_{eventId}_{uid}; belge varsa '
        '(silinmiş olsa da) yazmaz', () async {
      await fake.createSelf(userId: _me, eventId: 'e01', clubId: 'c01');
      const id = 'event_reminder_e01_u_mehmet';
      expect(fake.notifications[id]!.type, NotificationType.eventReminder);
      expect(fake.notifications[id]!.refs.clubId, 'c01');

      await fake.softDeleteNotification(id, actorId: _me);
      await fake.createSelf(userId: _me, eventId: 'e01', clubId: 'c01');
      expect(fake.notifications[id]!.isDeleted, isTrue);
      expect(
        (await fake.createSelf(
          userId: '',
          eventId: 'e01',
          clubId: 'c01',
        )).errorOrNull,
        FirestoreError.invalidArgument,
      );
    });
  });
}
