// T-15 · FakeNotificationDispatcher (kök kopya) sözleşmesi (PLAN §10.5,
// §16.3): `calls`, `failNextFanOut`; hiçbir belge yazmaz.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';

import 'fake_firestore_service.dart';
import 'fake_notification_dispatcher.dart';
import 'register_fakes.dart';

void main() {
  late FakeNotificationDispatcher fake;

  setUp(() => fake = FakeNotificationDispatcher());

  group('T-15 · FakeNotificationDispatcher', () {
    test('NotificationDispatcher arayüzünü uygular; registerDefaultFakes '
        'kaydeder', () {
      addTearDown(GetIt.I.reset);
      registerDefaultFakes();
      expect(
        GetIt.I<NotificationDispatcher>(),
        isA<FakeNotificationDispatcher>(),
      );
    });

    test('fan-out çağrısı ad, argüman ve alıcılarıyla `calls`e yazılır; '
        'rapor alıcı sayısını taşır', () async {
      final received = await fake.notifyApplicationReceived(
        clubId: 'c01',
        applicantId: 'u1',
        sequence: 0,
      );
      final announced = await fake.notifyAnnouncement(
        postId: 'p01',
        clubId: 'c01',
        recipients: const ['u2', 'u3'],
      );

      expect(fake.calls, const [
        DispatchCall(
          kind: 'notifyApplicationReceived',
          args: {'clubId': 'c01', 'applicantId': 'u1', 'sequence': 0},
        ),
        DispatchCall(
          kind: 'notifyAnnouncement',
          args: {'postId': 'p01', 'clubId': 'c01'},
          recipients: ['u2', 'u3'],
        ),
      ]);
      expect(received.dataOrNull?.requested, 0);
      expect(announced.dataOrNull?.written, 2);
    });

    test('batch alan çağrı batch’i kaydeder, batch’e yazım eklemez', () async {
      final firestore = FakeFirestoreService();

      final result = await firestore.commitBatch((batch) {
        unawaited(
          fake.notifyRemoved(clubId: 'c01', userId: 'u2', batch: batch),
        );
      });

      expect(result.isSuccess, isTrue);
      expect(fake.batches, hasLength(1));
      expect(fake.calls.single.recipients, ['u2']);
      expect(
        (await firestore.db.collection('notifications').get()).docs,
        isEmpty,
      );
    });

    test('failNextFanOut bir sonraki fan-out çağrısını düşürür (tek '
        'seferlik); çağrı yine kaydedilir', () async {
      fake.failNextFanOut = FirestoreError.unavailable;

      final failed = await fake.notifySystem(
        userIds: const ['u1'],
        textKey: 'welcome',
      );
      final next = await fake.notifyNewReport(reportId: 'r1');

      expect(failed.errorOrNull, FirestoreError.unavailable);
      expect(next.isSuccess, isTrue);
      expect(fake.calls, hasLength(2));
    });
  });
}
