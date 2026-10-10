// T-10 · CrashService: hata kaydı, günlük, kullanıcı kimliği, toplama anahtarı
// ve "asla fırlatmaz" sözleşmesi (PLAN §10.2; architecture §12; D-23).
//
// `firebase_crashlytics` için hazır sahte paket yoktur; el yazımı SDK çifti
// kullanılır (`test/fakes/sdk_platform_stubs.dart`).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../fakes/sdk_platform_stubs.dart';
import '../helpers/plan_service_table.dart';
import '../helpers/repo_sources.dart';

const String _source = 'packages/gu_data/lib/src/services/crash_service.dart';

void main() {
  late StubCrashlytics crashlytics;
  late CrashService service;

  setUp(() {
    crashlytics = StubCrashlytics();
    service = FirebaseCrashService(crashlytics);
  });

  group('T-10 · CrashService', () {
    test(
      'recordError: hata, yığın, neden ve fatal bayrağı SDK çağrısına iletilir',
      () async {
        final error = StateError('boom');
        final stack = StackTrace.current;

        await service.recordError(
          error,
          stack,
          fatal: true,
          reason: 'bootstrap',
        );
        await service.recordError(error, null);

        expect(crashlytics.crashes, [
          (error: error, stack: stack, reason: 'bootstrap', fatal: true),
          (error: error, stack: null, reason: null, fatal: false),
        ]);
      },
    );

    test('log: satır SDK günlüğüne yazılır', () async {
      service
        ..log('ilk')
        ..log('ikinci');
      await pumpEventQueue();

      expect(crashlytics.logs, ['ilk', 'ikinci']);
    });

    test(
      'setUserId: uid iletilir; null kimliği temizler (boş dizgi)',
      () async {
        await service.setUserId('u_ayse');
        await service.setUserId(null);

        expect(crashlytics.userIds, ['u_ayse', '']);
      },
    );

    test('setCollectionEnabled: bayrak SDK çağrısına iletilir', () async {
      await service.setCollectionEnabled(false);
      await service.setCollectionEnabled(true);

      expect(crashlytics.collectionFlags, [false, true]);
    });

    test(
      'SDK fırlatsa da hiçbir metot fırlatmaz (raporlama döngüye girmez)',
      () async {
        crashlytics.error = StateError('crashlytics kapalı');

        await expectLater(
          service.recordError(StateError('x'), null),
          completes,
        );
        await expectLater(service.setUserId('u_ayse'), completes);
        await expectLater(service.setCollectionEnabled(true), completes);
        service.log('satır');
        await pumpEventQueue();

        expect(crashlytics.crashes, isEmpty);
        expect(crashlytics.logs, isEmpty);
      },
    );

    test('PLAN §10.2 tablosundaki her üye arayüzde aynı imzayla var', () {
      final source = normalizeDartSource(readRepoFile(_source));
      final members = readPlanServiceMembers('CrashService');

      expect(members.map((m) => m.member), [
        'recordError',
        'log',
        'setUserId',
        'setCollectionEnabled',
      ]);
      for (final member in members) {
        expect(
          source,
          contains('${normalizeDartSource(member.signature)};'),
          reason: member.member,
        );
      }
      expect(
        readPlanServiceImplementation('CrashService'),
        '$FirebaseCrashService',
      );
    });

    test('bekleyen raporları silen SDK çağrısı kullanılmaz (D-10)', () {
      expect(deleteIdentifiersIn(_source), isEmpty);
    });
  });
}
