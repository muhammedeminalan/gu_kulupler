// T-10 · RemoteConfigService: çekme + etkinleştirme, SDK ayarları, değer
// okuyucular ve Limits varsayılanları, canlı güncelleme akışı, hata →
// FirebaseFailure eşlemesi ve zaman aşımı (PLAN §10.1–§10.2;
// architecture §11; Q-10).
//
// `firebase_remote_config` için hazır sahte paket yoktur; el yazımı SDK çifti
// kullanılır (`test/fakes/sdk_platform_stubs.dart`).
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../fakes/sdk_platform_stubs.dart';
import '../helpers/plan_service_table.dart';
import '../helpers/repo_sources.dart';

const String _source =
    'packages/gu_data/lib/src/services/remote_config_service.dart';

FirebaseException _exception(String code, {String? message}) =>
    FirebaseException(
      plugin: 'firebase_remote_config',
      code: code,
      message: message,
    );

void main() {
  late StubRemoteConfig config;
  late RemoteConfigService service;

  setUp(() {
    config = StubRemoteConfig();
    service = FirebaseRemoteConfigService(config);
  });

  group('T-10 · RemoteConfigService · fetchAndActivate', () {
    test('SDK sonucunu (değişti mi) başarı olarak döndürür', () async {
      final changed = await service.fetchAndActivate();
      config.fetchResult = false;
      final unchanged = await service.fetchAndActivate();

      expect(changed.dataOrNull, isTrue);
      expect(unchanged.dataOrNull, isFalse);
      expect(config.fetches, 2);
    });

    test('ilk çağrıda SDK ayarlarını bir kez yazar: çekim aralığı 1 saat, '
        'zaman aşımı 10 sn', () async {
      await service.fetchAndActivate();
      await service.fetchAndActivate();

      final settings = config.appliedSettings.single;
      expect(settings.minimumFetchInterval, const Duration(hours: 1));
      expect(settings.fetchTimeout, const Duration(seconds: 10));
    });

    test(
      'emülatör ortamı için çekim aralığı kurucudan sıfırlanabilir',
      () async {
        await FirebaseRemoteConfigService(
          config,
          minimumFetchInterval: Duration.zero,
        ).fetchAndActivate();

        expect(
          config.appliedSettings.single.minimumFetchInterval,
          Duration.zero,
        );
      },
    );
  });

  group('T-10 · RemoteConfigService · hata eşlemesi', () {
    test(
      'SDK kodu RemoteConfigError.fromCode ile çevrilir; ham mesaj taşınır',
      () async {
        const codes = {
          'throttled': RemoteConfigError.fetchThrottled,
          'network-error': RemoteConfigError.network,
          'fetch-timeout': RemoteConfigError.timeout,
          'internal': RemoteConfigError.unknown,
          'forbidden': RemoteConfigError.unknown,
        };

        for (final MapEntry(key: code, value: expected) in codes.entries) {
          config.fetchError = _exception(code, message: 'ham $code');

          final result = await service.fetchAndActivate();

          expect(result.errorOrNull, expected, reason: code);
          expect(
            (result as FirebaseFailure).message,
            'ham $code',
            reason: code,
          );
        }
      },
    );

    test('SDK dışı istisna → unknown (fırlatılmaz)', () async {
      config.fetchError = StateError('x');

      final result = await service.fetchAndActivate();

      expect(result.errorOrNull, RemoteConfigError.unknown);
      expect((result as FirebaseFailure).message, contains('x'));
    });

    testWidgets('çekim zaman aşımı içinde dönmezse timeout', (tester) async {
      config.fetchHangs = true;
      RemoteConfigResult<bool>? result;
      unawaited(service.fetchAndActivate().then((r) => result = r));

      await tester.pump(
        FirebaseRemoteConfigService.defaultFetchTimeout -
            const Duration(milliseconds: 1),
      );
      expect(result, isNull);
      await tester.pump(const Duration(milliseconds: 1));

      expect(result!.errorOrNull, RemoteConfigError.timeout);
    });
  });

  group('T-10 · RemoteConfigService · değerler', () {
    test('uzaktan değer yokken kod içi varsayılanlar (Limits) döner', () {
      expect(service.minSupportedBuild, 0);
      expect(service.maintenanceMessage, '');
      expect(service.announcementDailyLimit, Limits.announcementDailyLimit);
      expect(service.reapplyCooldownDays, Limits.reapplyCooldown.inDays);
      expect(service.reapplyCooldownDays, 7);
    });

    test('uzaktan değer varsayılanı geçersiz kılar', () {
      config.values.addAll({
        RemoteConfigKeys.minSupportedBuild: '42',
        RemoteConfigKeys.maintenanceMessage: '  Bakım 02:00–03:00  ',
        RemoteConfigKeys.announcementDailyLimit: '3',
        RemoteConfigKeys.reapplyCooldownDays: '14',
      });

      expect(service.minSupportedBuild, 42);
      expect(service.maintenanceMessage, 'Bakım 02:00–03:00');
      expect(service.announcementDailyLimit, 3);
      expect(service.reapplyCooldownDays, 14);
    });

    test('geçersiz uzaktan değer (sayı değil, sıfır, negatif) varsayılana '
        'düşer', () {
      for (final bad in ['abc', '', '0', '-1', '2.5']) {
        config.values
          ..[RemoteConfigKeys.announcementDailyLimit] = bad
          ..[RemoteConfigKeys.reapplyCooldownDays] = bad;

        expect(
          service.announcementDailyLimit,
          Limits.announcementDailyLimit,
          reason: bad,
        );
        expect(
          service.reapplyCooldownDays,
          Limits.reapplyCooldown.inDays,
          reason: bad,
        );
      }
      for (final bad in ['abc', '', '-5']) {
        config.values[RemoteConfigKeys.minSupportedBuild] = bad;

        expect(service.minSupportedBuild, 0, reason: bad);
      }
    });

    test('SDK okuması fırlatırsa okuyucular fırlatmaz, varsayılan döner', () {
      config.readError = StateError('başlatılmadı');

      expect(service.minSupportedBuild, 0);
      expect(service.maintenanceMessage, '');
      expect(service.announcementDailyLimit, Limits.announcementDailyLimit);
      expect(service.reapplyCooldownDays, Limits.reapplyCooldown.inDays);
    });
  });

  group('T-10 · RemoteConfigService · onConfigUpdated', () {
    test(
      'güncelleme gelince yapılandırmayı etkinleştirir ve olay yayınlar',
      () async {
        var events = 0;
        final subscription = service.onConfigUpdated.listen((_) => events++);

        config.updates
          ..add(RemoteConfigUpdate({RemoteConfigKeys.minSupportedBuild}))
          ..add(RemoteConfigUpdate({RemoteConfigKeys.maintenanceMessage}));
        await pumpEventQueue();
        await subscription.cancel();

        expect(config.activations, 2);
        expect(events, 2);
      },
    );

    test('etkinleştirme ya da SDK akışı hata verirse olay da hata da '
        'yayınlanmaz; akış sürer', () async {
      var events = 0;
      final errors = <Object>[];
      final subscription = service.onConfigUpdated.listen(
        (_) => events++,
        onError: errors.add,
      );

      config.updates.addError(_exception('internal'));
      config.activateError = _exception('internal');
      config.updates.add(RemoteConfigUpdate(const {}));
      await pumpEventQueue();
      config.activateError = null;
      config.updates.add(RemoteConfigUpdate(const {}));
      await pumpEventQueue();
      await subscription.cancel();

      expect(errors, isEmpty);
      expect(config.activations, 2);
      expect(events, 1);
    });
  });

  group('T-10 · RemoteConfigService · PLAN paritesi', () {
    test('PLAN §10.2 tablosundaki her üye arayüzde aynı imzayla var', () {
      final source = normalizeDartSource(readRepoFile(_source));
      final members = readPlanServiceMembers('RemoteConfigService');

      expect(members.map((m) => m.member), [
        'fetchAndActivate',
        'minSupportedBuild',
        'maintenanceMessage',
        'announcementDailyLimit',
        'reapplyCooldownDays',
        'onConfigUpdated',
      ]);
      for (final member in members) {
        expect(
          source,
          contains('${normalizeDartSource(member.signature)};'),
          reason: member.member,
        );
      }
      expect(
        readPlanServiceImplementation('RemoteConfigService'),
        '$FirebaseRemoteConfigService',
      );
    });
  });
}
