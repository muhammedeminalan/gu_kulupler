// T-11 · Crashlytics otomatik toplama yerel tarafta kapalı başlar (W-53,
// CD-132): yerel SDK Dart'tan önce ve varsayılan (gerçek) Firebase
// uygulamasıyla açıldığından, toplamayı yalnızca Dart açar
// (`AppBootstrap.configureCrashlytics`).
import 'package:flutter_test/flutter_test.dart';

import '../helpers/design_files.dart';

void main() {
  const androidKey = 'firebase_crashlytics_collection_enabled';
  const iosKey = 'FirebaseCrashlyticsCollectionEnabled';

  group('T-11 · Crashlytics otomatik toplama (platform dosyaları)', () {
    test('Android debug manifest toplamayı kapalı başlatır', () {
      final manifest = readText('android/app/src/debug/AndroidManifest.xml');
      final application = RegExp(
        r'<application\b[^>]*>(.*?)</application>',
        dotAll: true,
      ).firstMatch(manifest);
      expect(application, isNotNull, reason: '<application> gövdesi yok');
      expect(
        RegExp(
          '<meta-data\\s+android:name="$androidKey"\\s+'
          r'android:value="false"\s*/>',
        ).hasMatch(application!.group(1)!),
        isTrue,
      );
    });

    test("Android main ve profile manifest'leri anahtarı taşımaz (release "
        'derlemede SDK varsayılanı + Dart anahtarı geçerlidir)', () {
      for (final variant in const ['main', 'profile']) {
        final manifest = readText(
          'android/app/src/$variant/AndroidManifest.xml',
        );
        expect(manifest, isNot(contains(androidKey)), reason: variant);
      }
    });

    test('iOS Info.plist toplamayı kapalı başlatır', () {
      final plist = readText('ios/Runner/Info.plist');
      expect(
        RegExp('<key>$iosKey</key>\\s*<false\\s*/>').hasMatch(plist),
        isTrue,
      );
    });

    test('toplamayı Dart açar: açılış sırası anahtarı her açılışta yazar', () {
      // iOS'ta plist tüm yapılandırmalar için ortaktır; release derlemede
      // toplama yalnızca bu çağrıyla açılır.
      final source = readText('lib/core/bootstrap/app_bootstrap.dart');
      expect(source, contains('await configureCrashlytics();'));
      expect(
        source,
        contains('setCrashlyticsCollectionEnabled(enabled)'),
      );
    });
  });
}
