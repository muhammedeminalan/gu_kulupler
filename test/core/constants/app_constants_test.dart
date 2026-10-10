// T-08 · AppConstants.allowedEmailDomains: `gu_data` EmailDomainPolicy'ye
// delegasyon — ikinci kopya yok (CD-76, D-27).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/constants/app_constants.dart';

import '../../helpers/design_files.dart';

void main() {
  group('T-08 · AppConstants.allowedEmailDomains', () {
    test('EmailDomainPolicy.allowedDomains ile aynı liste', () {
      expect(
        AppConstants.allowedEmailDomains,
        EmailDomainPolicy.allowedDomains,
      );
    });

    test('kopya değil delegasyon: aynı const örnek', () {
      expect(
        identical(
          AppConstants.allowedEmailDomains,
          EmailDomainPolicy.allowedDomains,
        ),
        isTrue,
      );
    });

    test('izinli iki alan adı, sırayla', () {
      expect(AppConstants.allowedEmailDomains, [
        'ogr.gumushane.edu.tr',
        'gumushane.edu.tr',
      ]);
    });

    test('tasarım sabiti ALLOWED_EMAIL_DOMAINS ile birebir', () {
      final constants =
          readJsonMap('design/extracted/registry.json')['constants']
              as Map<String, dynamic>;

      expect(
        AppConstants.allowedEmailDomains,
        constants['ALLOWED_EMAIL_DOMAINS'],
      );
    });

    test('liste değiştirilemez', () {
      expect(
        () => AppConstants.allowedEmailDomains.add('example.com'),
        throwsUnsupportedError,
      );
    });

    test(
      'her alan adı EmailDomainPolicy.isAllowed tarafından kabul edilir',
      () {
        for (final domain in AppConstants.allowedEmailDomains) {
          expect(EmailDomainPolicy.isAllowed('ad.soyad@$domain'), isTrue);
        }
      },
    );

    test(
      'app_constants.dart alan adı dizgisi taşımaz (tek kaynak gu_data)',
      () {
        final source = readText('lib/core/constants/app_constants.dart');

        for (final domain in EmailDomainPolicy.allowedDomains) {
          expect(source, isNot(contains("'$domain'")), reason: domain);
        }
        expect(
          source,
          contains(
            'static const List<String> allowedEmailDomains =\n'
            '      EmailDomainPolicy.allowedDomains;',
          ),
        );
      },
    );
  });
}
