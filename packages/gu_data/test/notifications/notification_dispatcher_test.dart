// T-15 · NotificationDispatcher arayüzü (PLAN §10.5 / §15.2 ile aynı üyeler),
// NoopNotificationDispatcher (hiçbir şey yazmaz, hedeflenen alıcı sayısını
// bildirir) ve test çifti FakeNotificationDispatcher (çağrı kaydı, fan-out
// hatası) — CD-36, CD-37.
import 'package:cloud_firestore/cloud_firestore.dart' show WriteBatch;
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../fakes/fake_notification_dispatcher.dart';
import '../fakes/sdk_firestore_stubs.dart';
import '../helpers/plan_service_table.dart';
import '../helpers/repo_sources.dart';

const String _interface =
    'packages/gu_data/lib/src/notifications/notification_dispatcher.dart';

/// Her `notifyX` üyesini [batch] ile bir kez çağırır; sonuçlar üye adıyla.
Future<Map<String, FirestoreResult<DispatchReport>>> _callAll(
  NotificationDispatcher dispatcher,
  WriteBatch batch,
) async => {
  'notifyApplicationReceived': await dispatcher.notifyApplicationReceived(
    clubId: 'c01',
    applicantId: 'u1',
    sequence: 0,
  ),
  'notifyApplicationDecided': await dispatcher.notifyApplicationDecided(
    clubId: 'c01',
    applicantId: 'u1',
    approved: true,
    batch: batch,
  ),
  'notifyRemoved': await dispatcher.notifyRemoved(
    clubId: 'c01',
    userId: 'u1',
    batch: batch,
  ),
  'notifyRoleChanged': await dispatcher.notifyRoleChanged(
    clubId: 'c01',
    userId: 'u1',
    role: ClubRole.board,
    batch: batch,
  ),
  'notifyAnnouncement': await dispatcher.notifyAnnouncement(
    postId: 'p01',
    clubId: 'c01',
    recipients: const ['u1', 'u2', 'u3'],
  ),
  'notifyPostNew': await dispatcher.notifyPostNew(
    postId: 'p02',
    clubId: 'c01',
    recipients: const ['u1', 'u2'],
  ),
  'notifyCommentNew': await dispatcher.notifyCommentNew(
    postId: 'p02',
    clubId: 'c01',
    commentId: 'cm01',
    recipients: const ['u1'],
  ),
  'notifyEventNew': await dispatcher.notifyEventNew(
    eventId: 'e01',
    clubId: 'c01',
    recipients: const ['u1', 'u2'],
  ),
  'notifyEventCancelled': await dispatcher.notifyEventCancelled(
    eventId: 'e01',
    clubId: 'c01',
    recipients: const ['u1'],
  ),
  'notifyWaitlistPromoted': await dispatcher.notifyWaitlistPromoted(
    eventId: 'e01',
    clubId: 'c01',
    userId: 'u1',
    batch: batch,
  ),
  'notifyReportResolved': await dispatcher.notifyReportResolved(
    reportGroupKey: 'post_p01',
    reporterIds: const ['u1', 'u2'],
    batch: batch,
  ),
  'notifyNewReport': await dispatcher.notifyNewReport(reportId: 'r01'),
  'notifySystem': await dispatcher.notifySystem(
    userIds: const ['u1', 'u2', 'u3', 'u4'],
    textKey: 'notifSystemMaintenance',
  ),
};

/// Üye adı → hedeflenen alıcı sayısı ([_callAll] argümanlarına göre).
const Map<String, int> _requested = {
  'notifyApplicationReceived': 0,
  'notifyApplicationDecided': 1,
  'notifyRemoved': 1,
  'notifyRoleChanged': 1,
  'notifyAnnouncement': 3,
  'notifyPostNew': 2,
  'notifyCommentNew': 1,
  'notifyEventNew': 2,
  'notifyEventCancelled': 1,
  'notifyWaitlistPromoted': 1,
  'notifyReportResolved': 2,
  'notifyNewReport': 0,
  'notifySystem': 4,
};

/// Kritik üyelerin transaction karşılıkları (T-30): karar, çıkarma, rol,
/// terfi. Davranışları `client_fan_out_dispatcher_test` sınar.
const int _transactionMembers = 4;

void main() {
  group('T-15 · NotificationDispatcher · sözleşme', () {
    test('arayüz PLAN §10.5 tanımındaki 17 üyeyi (13 + T-30 `…InTransaction` '
        'karşılıkları) aynı adlandırılmış parametrelerle taşır; hepsi '
        'DispatchReport döner', () {
      final plan = RegExp(
        r'^\s+(notify\w+)\(\{(.*?)\}\);',
        multiLine: true,
      ).allMatches(readRepoFile('docs/PLAN.md').split('### 10.5').last);
      final expected = {
        for (final match in plan.take(
          _requested.length + _transactionMembers,
        ))
          normalizeDartSource(
            'Future<FirestoreResult<DispatchReport>> '
            '${match.group(1)}({${match.group(2)}})',
          ),
      };
      final source = normalizeDartSource(readRepoFile(_interface));
      final body = source.substring(
        source.indexOf('abstractinterfaceclassNotificationDispatcher{') +
            'abstractinterfaceclassNotificationDispatcher{'.length,
        source.indexOf('}finalclassDispatchReport'),
      );

      expect(expected, hasLength(_requested.length + _transactionMembers));
      expect(
        expected.where((member) => member.contains('InTransaction(')),
        hasLength(_transactionMembers),
      );
      expect(body.split(';').where((member) => member.isNotEmpty).toSet(), {
        ...expected,
      });
    });

    test('DispatchReport alanlarıyla eşittir', () {
      const report = DispatchReport(requested: 3, written: 2, failedChunks: 1);

      expect(
        report,
        const DispatchReport(requested: 3, written: 2, failedChunks: 1),
      );
      expect(report.props, [3, 2, 1]);
    });
  });

  group('T-15 · NoopNotificationDispatcher', () {
    test(
      'hiçbir üye batch içine yazım eklemez; rapor hedeflenen alıcı sayısını '
      've sıfır yazımı bildirir',
      () async {
        final batch = StubWriteBatch();

        final results = await _callAll(
          const NoopNotificationDispatcher(),
          batch,
        );

        expect(batch.writes, 0);
        expect(batch.commits, 0);
        expect(
          {
            for (final MapEntry(:key, :value) in results.entries)
              key: value.dataOrNull,
          },
          {
            for (final MapEntry(:key, :value) in _requested.entries)
              key: DispatchReport(
                requested: value,
                written: 0,
                failedChunks: 0,
              ),
          },
        );
      },
    );
  });

  group('T-15 · FakeNotificationDispatcher', () {
    test(
      'her çağrıyı adı, argümanları ve alıcılarıyla kaydeder; batch nesnesine '
      'dokunmaz',
      () async {
        final dispatcher = FakeNotificationDispatcher();
        final batch = StubWriteBatch();

        final results = await _callAll(dispatcher, batch);

        expect(results.values.every((result) => result.isSuccess), isTrue);
        expect([
          for (final call in dispatcher.calls) call.kind,
        ], _requested.keys);
        expect(
          dispatcher.calls.first,
          const DispatchCall(
            kind: 'notifyApplicationReceived',
            args: {'clubId': 'c01', 'applicantId': 'u1', 'sequence': 0},
          ),
        );
        expect(
          dispatcher.calls[3],
          const DispatchCall(
            kind: 'notifyRoleChanged',
            args: {'clubId': 'c01', 'userId': 'u1', 'role': ClubRole.board},
            recipients: ['u1'],
          ),
        );
        expect(dispatcher.calls[4].recipients, ['u1', 'u2', 'u3']);
        expect(dispatcher.calls[5].recipients, ['u1', 'u2']);
        expect(dispatcher.calls[10].recipients, ['u1', 'u2']);
        expect(dispatcher.batches, hasLength(5));
        expect(
          dispatcher.batches.every((item) => identical(item, batch)),
          isTrue,
        );
        expect(batch.writes, 0);
      },
    );

    test(
      'failNextFanOut yalnızca bir sonraki fan-out çağrısını düşürür',
      () async {
        final dispatcher = FakeNotificationDispatcher()
          ..failNextFanOut = FirestoreError.unavailable;

        final inBatch = await dispatcher.notifyRemoved(
          clubId: 'c01',
          userId: 'u1',
          batch: StubWriteBatch(),
        );
        final failed = await dispatcher.notifyAnnouncement(
          postId: 'p01',
          clubId: 'c01',
          recipients: const ['u1'],
        );
        final next = await dispatcher.notifyAnnouncement(
          postId: 'p01',
          clubId: 'c01',
          recipients: const ['u1'],
        );

        expect(inBatch.isSuccess, isTrue);
        expect(failed.errorOrNull, FirestoreError.unavailable);
        expect(
          next.dataOrNull,
          const DispatchReport(requested: 1, written: 1, failedChunks: 0),
        );
        expect(dispatcher.calls, hasLength(3));
        expect(dispatcher.failNextFanOut, isNull);
      },
    );
  });
}
