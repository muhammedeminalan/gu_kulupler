// T-11 · FakeAppInfoService sözleşmesi (PLAN §16.3).
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_kulupler/product/service/app_info_service.dart';

import 'fake_app_info_service.dart';
import 'register_fakes.dart';

void main() {
  group('T-11 · FakeAppInfoService', () {
    test('AppInfoService arayüzünü uygular; registerDefaultFakes kaydeder', () {
      addTearDown(GetIt.I.reset);
      registerDefaultFakes();
      expect(GetIt.I<AppInfoService>(), isA<FakeAppInfoService>());
    });

    test('varsayılan sürüm 1.0.0, derleme 1', () {
      final fake = FakeAppInfoService();
      expect(fake.version, '1.0.0');
      expect(fake.buildNumber, '1');
      expect(fake.buildCode, 1);
    });

    test('buildCode gerçek servisle aynı kural: sayı değilse 0', () {
      final fake = FakeAppInfoService()..buildNumber = ' 42 ';
      expect(fake.buildCode, 42);
      fake.buildNumber = '';
      expect(fake.buildCode, 0);
      fake.buildNumber = '1.2';
      expect(fake.buildCode, 0);
    });
  });
}
