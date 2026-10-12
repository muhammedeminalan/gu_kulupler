// T-14 · DevicePermissionService: permission_handler çağrıları, durum yorumu
// ve hata davranışı (CD-08, CD-16).
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/product/service/permission_service.dart';

void main() {
  setUp(() {
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) {};
    addTearDown(() => debugPrint = original);
  });

  group('T-14 · PermissionStatusX', () {
    test('isUsable: granted, limited, provisional', () {
      expect(
        {
          for (final status in PermissionStatus.values)
            if (status.isUsable) status,
        },
        {
          PermissionStatus.granted,
          PermissionStatus.limited,
          PermissionStatus.provisional,
        },
      );
    });

    test('needsSettings: permanentlyDenied, restricted', () {
      expect(
        {
          for (final status in PermissionStatus.values)
            if (status.needsSettings) status,
        },
        {PermissionStatus.permanentlyDenied, PermissionStatus.restricted},
      );
    });

    test('hiçbir durum hem kullanılabilir hem "ayarlara git" değildir', () {
      for (final status in PermissionStatus.values) {
        expect(status.isUsable && status.needsSettings, isFalse);
      }
    });
  });

  group('T-14 · DevicePermissionService', () {
    late List<(String, Permission)> log;

    DevicePermissionService service({
      PermissionStatus status = PermissionStatus.denied,
      PermissionStatus requested = PermissionStatus.granted,
      bool settings = true,
    }) => DevicePermissionService(
      read: (permission) async {
        log.add(('read', permission));
        return status;
      },
      request: (permission) async {
        log.add(('request', permission));
        return requested;
      },
      openSettings: () async => settings,
    );

    setUp(() => log = []);

    test('status: izni okur, istemez', () async {
      final result = await service(
        status: PermissionStatus.permanentlyDenied,
      ).status(Permission.camera);

      expect(result, PermissionStatus.permanentlyDenied);
      expect(log, [('read', Permission.camera)]);
    });

    test('isGranted: kullanılabilir durumlar true (istek yapılmaz)', () async {
      for (final status in PermissionStatus.values) {
        expect(
          await service(status: status).isGranted(Permission.notification),
          status.isUsable,
          reason: status.name,
        );
      }
      expect(log.map((entry) => entry.$1).toSet(), {'read'});
    });

    test('requestCamera: yalnızca kamera iznini ister ve sonucu '
        'döndürür', () async {
      expect(await service().requestCamera(), PermissionStatus.granted);
      expect(
        await service(requested: PermissionStatus.denied).requestCamera(),
        PermissionStatus.denied,
      );
      expect(log, [
        ('request', Permission.camera),
        ('request', Permission.camera),
      ]);
    });

    test('requestNotifications: yalnızca bildirim iznini ister', () async {
      expect(
        await service(
          requested: PermissionStatus.provisional,
        ).requestNotifications(),
        PermissionStatus.provisional,
      );
      expect(log, [('request', Permission.notification)]);
    });

    test('galeri / fotoğraf izni hiçbir metotta istenmez (CD-16)', () async {
      final device = service();
      await device.requestCamera();
      await device.requestNotifications();

      expect(log.map((entry) => entry.$2), [
        Permission.camera,
        Permission.notification,
      ]);
    });

    test('openAppSettings: platform sonucunu döndürür', () async {
      expect(await service().openAppSettings(), isTrue);
      expect(await service(settings: false).openAppSettings(), isFalse);
    });

    test('platform hatası fırlatılmaz: durum ve istek denied, ayarlar '
        'false', () async {
      Future<PermissionStatus> broken(Permission _) async =>
          throw StateError('kanal yok');
      final device = DevicePermissionService(
        read: broken,
        request: broken,
        openSettings: () async => throw StateError('kanal yok'),
      );

      expect(await device.status(Permission.camera), PermissionStatus.denied);
      expect(await device.isGranted(Permission.camera), isFalse);
      expect(await device.requestCamera(), PermissionStatus.denied);
      expect(await device.requestNotifications(), PermissionStatus.denied);
      expect(await device.openAppSettings(), isFalse);
    });

    test('varsayılan kurucu const kurulur (platform çağrıları '
        'permission_handler)', () {
      expect(const DevicePermissionService(), isA<PermissionService>());
    });
  });
}
