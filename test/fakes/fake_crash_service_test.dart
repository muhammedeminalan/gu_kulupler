// T-10 · FakeCrashService sözleşmesi (PLAN §16.3).
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';

import 'fake_base.dart';
import 'fake_crash_service.dart';
import 'register_fakes.dart';

void main() {
  group('T-10 · FakeCrashService', () {
    test('CrashService arayüzünü uygular; registerDefaultFakes kaydeder', () {
      addTearDown(GetIt.I.reset);
      registerDefaultFakes();
      expect(GetIt.I<CrashService>(), isA<FakeCrashService>());
      expect(GetIt.I<CrashService>(), isA<FakeBase>());
    });

    test(
      'recordError: (hata, yığın) + fatal + reason sırayla tutulur',
      () async {
        final fake = FakeCrashService();
        final error = StateError('x');
        final stack = StackTrace.current;

        await fake.recordError(error, stack, fatal: true, reason: 'zone');
        await fake.recordError('y', null);

        expect(fake.recorded, [(error, stack), ('y', null)]);
        expect(fake.fatals, [true, false]);
        expect(fake.reasons, ['zone', null]);
        expect(fake.callsTo('recordError'), hasLength(2));
      },
    );

    test('log, setUserId ve setCollectionEnabled son değeri saklar', () async {
      final fake = FakeCrashService()
        ..log('a')
        ..log('b');
      expect(fake.collectionEnabled, isNull);

      await fake.setUserId('u1');
      await fake.setCollectionEnabled(false);
      expect(fake.logs, ['a', 'b']);
      expect(fake.userId, 'u1');
      expect(fake.collectionEnabled, isFalse);

      await fake.setUserId(null);
      expect(fake.userId, isNull);
    });
  });
}
