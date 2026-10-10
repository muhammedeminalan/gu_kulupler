// T-11 · Android şifresiz trafik izni yalnızca debug derlemesinde (W-53,
// CD-131): Firebase emülatörü düz HTTP konuşur.
import 'package:flutter_test/flutter_test.dart';

import '../helpers/design_files.dart';

void main() {
  const attribute = 'android:usesCleartextTraffic';

  group('T-11 · Android şifresiz trafik izni', () {
    test('debug manifest emülatör için izin verir', () {
      final manifest = readText('android/app/src/debug/AndroidManifest.xml');
      expect(
        RegExp(
          r'<application\s+android:usesCleartextTraffic="true"\s*/?>',
        ).hasMatch(manifest),
        isTrue,
      );
    });

    test("main ve profile manifest'leri izni taşımaz (release şifresiz "
        'trafik gönderemez)', () {
      for (final variant in const ['main', 'profile']) {
        final manifest = readText(
          'android/app/src/$variant/AndroidManifest.xml',
        );
        expect(manifest, isNot(contains(attribute)), reason: variant);
      }
    });

    test('ağ güvenlik yapılandırmasıyla genel bir izin açılmamıştır', () {
      final manifest = readText('android/app/src/main/AndroidManifest.xml');
      expect(manifest, isNot(contains('networkSecurityConfig')));
    });
  });
}
