import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/core/constants/app_constants.dart';
import 'package:gu_kulupler/main.dart';

void main() {
  group('T-00 · depo iskeleti', () {
    testWidgets('GuApp istisnasız pump edilir', (tester) async {
      await tester.pumpWidget(const GuApp());
      expect(tester.takeException(), isNull);
      expect(find.byType(GuApp), findsOneWidget);
    });

    test('AppConstants tek kaynak (D-01, K-D, K-N)', () {
      expect(AppConstants.appName, 'GÜ Kulüpler');
      expect(AppConstants.appNameDative, startsWith(AppConstants.appName));
      // CD-76: Rules regex paritesinin çapası — tam liste sabitlenir.
      expect(
        AppConstants.allowedEmailDomains,
        equals(const ['ogr.gumushane.edu.tr', 'gumushane.edu.tr']),
      );
      expect(AppConstants.shareBaseUrl, startsWith('https://'));
      expect(AppConstants.supportEmail, contains('@'));
    });
  });
}
