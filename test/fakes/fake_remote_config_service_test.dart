// T-10 · FakeRemoteConfigService sözleşmesi (PLAN §16.3).
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';

import 'fake_remote_config_service.dart';
import 'register_fakes.dart';

void main() {
  group('T-10 · FakeRemoteConfigService', () {
    test('RemoteConfigService arayüzünü uygular; '
        'registerDefaultFakes kaydeder', () {
      addTearDown(GetIt.I.reset);
      registerDefaultFakes();
      expect(GetIt.I<RemoteConfigService>(), isA<FakeRemoteConfigService>());
    });

    test('values boşken gerçek servisin varsayılanları döner', () {
      final fake = FakeRemoteConfigService();
      expect(fake.minSupportedBuild, 0);
      expect(fake.maintenanceMessage, isEmpty);
      expect(fake.announcementDailyLimit, Limits.announcementDailyLimit);
      expect(fake.reapplyCooldownDays, Limits.reapplyCooldown.inDays);
    });

    test('values RemoteConfigKeys anahtarlarıyla okunur; '
        'yanlış tip varsayılana düşer', () {
      final fake = FakeRemoteConfigService()
        ..values[RemoteConfigKeys.minSupportedBuild] = 42
        ..values[RemoteConfigKeys.maintenanceMessage] = 'Bakım'
        ..values[RemoteConfigKeys.announcementDailyLimit] = 5
        ..values[RemoteConfigKeys.reapplyCooldownDays] = 'yedi';

      expect(fake.minSupportedBuild, 42);
      expect(fake.maintenanceMessage, 'Bakım');
      expect(fake.announcementDailyLimit, 5);
      expect(fake.reapplyCooldownDays, Limits.reapplyCooldown.inDays);
    });

    test(
      'fetchAndActivate: activated değeri; failNext tek seferlik hata',
      () async {
        final fake = FakeRemoteConfigService()..activated = false;
        expect(
          await fake.fetchAndActivate(),
          isA<FirebaseSuccess<bool, RemoteConfigError>>().having(
            (r) => r.data,
            'data',
            isFalse,
          ),
        );

        fake.failNext(RemoteConfigError.fetchThrottled);
        expect(
          await fake.fetchAndActivate(),
          isA<FirebaseFailure<bool, RemoteConfigError>>().having(
            (r) => r.error,
            'error',
            RemoteConfigError.fetchThrottled,
          ),
        );
        fake.failNext();
        expect(
          await fake.fetchAndActivate(),
          isA<FirebaseFailure<bool, RemoteConfigError>>().having(
            (r) => r.error,
            'error',
            RemoteConfigError.unknown,
          ),
        );
        expect(
          await fake.fetchAndActivate(),
          isA<FirebaseSuccess<bool, RemoteConfigError>>(),
        );
        expect(fake.callsTo('fetchAndActivate'), hasLength(4));
      },
    );

    test('onConfigUpdated denetleyiciden yayınlanır', () async {
      final fake = FakeRemoteConfigService();
      var events = 0;
      final subscription = fake.onConfigUpdated.listen((_) => events++);
      addTearDown(subscription.cancel);

      fake.configUpdatedController.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(events, 1);
    });
  });
}
