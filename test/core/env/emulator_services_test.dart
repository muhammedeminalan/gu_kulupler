// T-11 · Emülatör ortamının yerel servisleri (W-53, CD-131): Remote Config
// ve çökme raporlama gerçek projeye gitmez.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/env/emulator_services.dart';

import '../../helpers/design_files.dart';

void main() {
  group('T-11 · EmulatorRemoteConfigService', () {
    const service = EmulatorRemoteConfigService();

    test(
      'değerler kod içi varsayılanlardır: kapı kapalı, bakım mesajı yok',
      () {
        expect(service.minSupportedBuild, 0);
        expect(service.maintenanceMessage, isEmpty);
        expect(service.announcementDailyLimit, Limits.announcementDailyLimit);
        expect(service.reapplyCooldownDays, Limits.reapplyCooldown.inDays);
      },
    );

    test(
      'fetchAndActivate ağa çıkmadan başarı döner (değişiklik yok)',
      () async {
        final result = await service.fetchAndActivate();
        expect(result, isA<FirebaseSuccess<bool, RemoteConfigError>>());
        expect(result.dataOrNull, isFalse);
      },
    );

    test('onConfigUpdated olay yayınlamadan kapanır', () async {
      expect(await service.onConfigUpdated.isEmpty, isTrue);
    });
  });

  group('T-11 · EmulatorCrashService', () {
    const service = EmulatorCrashService();
    late List<String> console;

    setUp(() {
      console = <String>[];
      final original = debugPrint;
      debugPrint = (message, {wrapWidth}) => console.add(message ?? '');
      addTearDown(() => debugPrint = original);
    });

    test('recordError yalnızca konsola yazar; fırlatmaz', () async {
      await service.recordError(StateError('x'), StackTrace.empty);
      await service.recordError('y', null, fatal: true);
      await service.recordError('z', null, reason: 'neden');
      expect(console, hasLength(3));
      expect(console[0], startsWith('[E] Hata'));
      expect(console[1], startsWith('[E] Yakalanmamış hata'));
      expect(console[2], startsWith('[E] neden'));
    });

    test('log / setUserId / setCollectionEnabled etkisizdir', () async {
      service.log('satır');
      await service.setUserId('u1');
      await service.setUserId(null);
      await service.setCollectionEnabled(true);
      expect(console, isEmpty);
    });
  });

  group('T-11 · emülatör servisleri · kaynak denetimi', () {
    test("dosya hiçbir Firebase SDK'sını içe aktarmaz", () {
      final source = readText('lib/core/env/emulator_services.dart');
      expect(
        RegExp(
          r'''^import\s+['"]package:(firebase_|cloud_)''',
          multiLine: true,
        ).hasMatch(source),
        isFalse,
      );
    });
  });
}
