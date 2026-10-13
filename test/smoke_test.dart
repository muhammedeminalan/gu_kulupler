import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/core/constants/app_constants.dart';

// `GuApp`'in pump testi `test/core/bootstrap/gu_app_test.dart`'tadır (T-11).
void main() {
  group('T-00 · depo iskeleti', () {
    test('AppConstants tek kaynak (D-01, K-D, K-N)', () {
      expect(AppConstants.appName, 'GÜ Kulüpler');
      expect(AppConstants.appNameDative, startsWith(AppConstants.appName));
      // CD-76: Rules regex paritesinin çapası — kalıcı liste sabitlenir
      // (ardından yalnızca geçici test alan adları gelebilir: CD-136, W-61).
      expect(
        AppConstants.allowedEmailDomains.take(2),
        equals(const ['ogr.gumushane.edu.tr', 'gumushane.edu.tr']),
      );
      expect(AppConstants.shareBaseUrl, startsWith('https://'));
      expect(AppConstants.supportEmail, contains('@'));
    });
  });
}
