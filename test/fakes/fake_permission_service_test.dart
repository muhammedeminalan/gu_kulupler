// T-14 · FakePermissionService sözleşmesi (PLAN §16.3): `results`,
// `openedSettings`; sistem penceresi açmaz.
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_kulupler/product/service/permission_service.dart';

import 'fake_base.dart';
import 'fake_permission_service.dart';
import 'register_fakes.dart';

void main() {
  group('T-14 · FakePermissionService', () {
    test('PermissionService arayüzünü uygular; registerDefaultFakes '
        'kaydeder', () {
      addTearDown(GetIt.I.reset);
      registerDefaultFakes();
      expect(GetIt.I<PermissionService>(), isA<FakePermissionService>());
    });

    test('varsayılan: henüz sorulmamış izin — durum denied, istek granted ve '
        'sonuç kalıcı', () async {
      final fake = FakePermissionService();

      expect(await fake.status(Permission.camera), PermissionStatus.denied);
      expect(await fake.isGranted(Permission.camera), isFalse);

      expect(await fake.requestCamera(), PermissionStatus.granted);

      expect(await fake.status(Permission.camera), PermissionStatus.granted);
      expect(await fake.isGranted(Permission.camera), isTrue);
      expect(fake.requested, [Permission.camera]);
      // Bildirim izni ayrıdır.
      expect(await fake.isGranted(Permission.notification), isFalse);
      expect(await fake.requestNotifications(), PermissionStatus.granted);
      expect(fake.requested, [Permission.camera, Permission.notification]);
    });

    test('results: verilen durum hem okumada hem istekte döner', () async {
      final fake = FakePermissionService()
        ..results[Permission.camera] = PermissionStatus.permanentlyDenied
        ..results[Permission.notification] = PermissionStatus.provisional;

      expect(
        await fake.status(Permission.camera),
        PermissionStatus.permanentlyDenied,
      );
      expect(await fake.requestCamera(), PermissionStatus.permanentlyDenied);
      expect(await fake.isGranted(Permission.camera), isFalse);
      // iOS sessiz bildirim izni kullanılabilir sayılır.
      expect(await fake.isGranted(Permission.notification), isTrue);
      expect(await fake.requestNotifications(), PermissionStatus.provisional);
    });

    test(
      'çağrı günlüğü: status / isGranted / request / openAppSettings',
      () async {
        final fake = FakePermissionService();

        await fake.status(Permission.camera);
        await fake.isGranted(Permission.notification);
        await fake.requestCamera();
        await fake.openAppSettings();

        expect(fake.calls, [
          const FakeCall('status', [Permission.camera]),
          const FakeCall('isGranted', [Permission.notification]),
          const FakeCall('request', [Permission.camera]),
          const FakeCall('openAppSettings'),
        ]);
      },
    );

    test('openAppSettings: sayar; canOpenSettings false → false', () async {
      final fake = FakePermissionService();

      expect(await fake.openAppSettings(), isTrue);
      fake.canOpenSettings = false;
      expect(await fake.openAppSettings(), isFalse);

      expect(fake.openedSettings, 2);
    });

    test('failNext: fırlatmaz — istek denied (kalıcı değil), ayarlar '
        'false', () async {
      final fake = FakePermissionService()..failNext();

      expect(await fake.requestCamera(), PermissionStatus.denied);
      expect(await fake.requestCamera(), PermissionStatus.granted);

      fake.failNext();
      expect(await fake.openAppSettings(), isFalse);
      expect(await fake.openAppSettings(), isTrue);
    });

    test('resetFake: durumları, günlüğü ve sayaçları sıfırlar', () async {
      final fake = FakePermissionService()
        ..results[Permission.camera] = PermissionStatus.granted
        ..canOpenSettings = false;
      await fake.requestCamera();
      await fake.openAppSettings();

      fake.resetFake();

      expect(fake.results, isEmpty);
      expect(fake.requested, isEmpty);
      expect(fake.calls, isEmpty);
      expect(fake.openedSettings, 0);
      expect(fake.canOpenSettings, isTrue);
    });
  });
}
