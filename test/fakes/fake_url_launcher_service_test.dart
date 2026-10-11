// T-13 · FakeUrlLauncherService sözleşmesi (PLAN §16.3).
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_kulupler/product/service/url_launcher_service.dart';

import 'fake_base.dart';
import 'fake_url_launcher_service.dart';
import 'register_fakes.dart';

void main() {
  final mail = Uri(scheme: 'mailto', path: 'destek@example.org');
  final web = Uri.parse('https://example.org/kulupler');

  group('T-13 · FakeUrlLauncherService', () {
    test(
      'UrlLauncherService arayüzünü uygular; registerDefaultFakes kaydeder',
      () {
        addTearDown(GetIt.I.reset);
        registerDefaultFakes();
        expect(GetIt.I<UrlLauncherService>(), isA<FakeUrlLauncherService>());
      },
    );

    test('open: adresi sırasıyla kaydeder ve true döner', () async {
      final fake = FakeUrlLauncherService();

      expect(await fake.open(mail), isTrue);
      expect(await fake.open(web), isTrue);

      expect(fake.opened, [mail, web]);
      expect(fake.calls, [
        FakeCall('open', [mail]),
        FakeCall('open', [web]),
      ]);
    });

    test('canOpen false: adres kaydedilir, sonuç false', () async {
      final fake = FakeUrlLauncherService()..canOpen = false;

      expect(await fake.open(mail), isFalse);
      expect(fake.opened, [mail]);
    });

    test('failNext: fırlatmaz, tek seferlik false döner', () async {
      final fake = FakeUrlLauncherService()..failNext();

      expect(await fake.open(mail), isFalse);
      expect(await fake.open(mail), isTrue);
      expect(fake.opened, [mail, mail]);
    });

    test('resetFake: günlüğü ve canOpen değerini sıfırlar', () async {
      final fake = FakeUrlLauncherService()..canOpen = false;
      await fake.open(mail);

      fake.resetFake();

      expect(fake.opened, isEmpty);
      expect(fake.calls, isEmpty);
      expect(fake.canOpen, isTrue);
    });
  });
}
