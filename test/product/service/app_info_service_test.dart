// T-11 · PackageAppInfoService: package_info_plus değerleri (CD-08).
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/product/service/app_info_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  setUp(() {
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) {};
    addTearDown(() => debugPrint = original);
  });

  group('T-11 · PackageAppInfoService', () {
    test('load platform değerlerini taşır', () async {
      final service = await PackageAppInfoService.load(
        read: () async => PackageInfo(
          appName: 'GÜ Kulüpler',
          packageName: 'tr.edu.gumushane.kulupler',
          version: '1.4.2',
          buildNumber: '37',
        ),
      );
      expect(service.version, '1.4.2');
      expect(service.buildNumber, '37');
      expect(service.buildCode, 37);
    });

    test('platform okunamazsa fırlatmaz: boş değerler, buildCode 0', () async {
      final service = await PackageAppInfoService.load(
        read: () async => throw StateError('kanal yok'),
      );
      expect(service.version, isEmpty);
      expect(service.buildNumber, isEmpty);
      expect(service.buildCode, 0);
    });

    test('buildCode: boşluk kırpılır; sayı olmayan değer 0', () {
      PackageAppInfoService of(String build) =>
          PackageAppInfoService(version: '1.0.0', buildNumber: build);
      expect(of(' 12 ').buildCode, 12);
      expect(of('12a').buildCode, 0);
      expect(of('').buildCode, 0);
    });
  });
}
