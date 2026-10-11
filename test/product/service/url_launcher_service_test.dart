// T-13 · DeviceUrlLauncherService: url_launcher çağrısı ve hata davranışı
// (CD-08).
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/core/constants/app_constants.dart';
import 'package:gu_kulupler/product/service/url_launcher_service.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  final mail = Uri(scheme: 'mailto', path: AppConstants.supportEmail);

  setUp(() {
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) {};
    addTearDown(() => debugPrint = original);
  });

  group('T-13 · DeviceUrlLauncherService', () {
    test('open: adresi uygulama dışında açar ve platform sonucunu '
        'döndürür', () async {
      final launched = <(Uri, LaunchMode)>[];
      final service = DeviceUrlLauncherService(
        launch: (uri, {mode = LaunchMode.platformDefault}) async {
          launched.add((uri, mode));
          return true;
        },
      );

      expect(await service.open(mail), isTrue);
      expect(launched, [(mail, LaunchMode.externalApplication)]);
    });

    test('open: açabilecek uygulama yoksa false', () async {
      final service = DeviceUrlLauncherService(
        launch: (uri, {mode = LaunchMode.platformDefault}) async => false,
      );

      expect(await service.open(mail), isFalse);
    });

    test('open: platform hatası fırlatılmaz, false döner', () async {
      final service = DeviceUrlLauncherService(
        launch: (uri, {mode = LaunchMode.platformDefault}) async =>
            throw StateError('kanal yok'),
      );

      expect(await service.open(mail), isFalse);
    });

    test('varsayılan kurucu const kurulur (platform çağrısı launchUrl)', () {
      expect(
        const DeviceUrlLauncherService(),
        isA<UrlLauncherService>(),
      );
    });
  });
}
