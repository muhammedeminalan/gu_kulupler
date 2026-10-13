// T-08 · AppConstants.allowedEmailDomains: `gu_data` EmailDomainPolicy'ye
// delegasyon — ikinci kopya yok (CD-76, D-27).
import 'package:flutter/foundation.dart' show TargetPlatform;
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

    test('iki üniversite alan adı başta ve sırayla; ardından yalnızca '
        'geçici test alan adları (CD-136)', () {
      expect(AppConstants.allowedEmailDomains.take(2), [
        'ogr.gumushane.edu.tr',
        'gumushane.edu.tr',
      ]);
      expect(
        AppConstants.allowedEmailDomains.skip(2),
        EmailDomainPolicy.temporaryTestDomains,
      );
      // AUT-01 / AUT-02 yer tutucusu ilk alan adını kullanır.
      expect(AppConstants.allowedEmailDomains.first, 'ogr.gumushane.edu.tr');
    });

    test('tasarım sabiti ALLOWED_EMAIL_DOMAINS ile birebir', () {
      final constants =
          readJsonMap('design/extracted/registry.json')['constants']
              as Map<String, dynamic>;

      expect(
        AppConstants.allowedEmailDomains.take(
          EmailDomainPolicy.universityDomains.length,
        ),
        constants['ALLOWED_EMAIL_DOMAINS'],
      );
      expect(
        EmailDomainPolicy.universityDomains,
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

  group('T-13 · AppConstants.supportMailUri', () {
    test(
      'destek adresine `mailto:` bağlantısıdır (DLG-01, SET-04 / SET-05)',
      () {
        final uri = AppConstants.supportMailUri;

        expect(uri.scheme, 'mailto');
        expect(uri.path, AppConstants.supportEmail);
        expect(uri.toString(), 'mailto:${AppConstants.supportEmail}');
        expect(uri.hasQuery, isFalse);
      },
    );
  });

  group('T-13 · AppConstants.storeUri (DLG-26 "Güncelle", W-55)', () {
    test('Android ve diğer platformlar: Google Play sayfası', () {
      for (final platform in [
        TargetPlatform.android,
        TargetPlatform.fuchsia,
        TargetPlatform.linux,
        TargetPlatform.windows,
      ]) {
        final uri = AppConstants.storeUri(platform);

        expect(uri.scheme, 'https', reason: platform.name);
        expect(uri.host, 'play.google.com');
        expect(uri.path, '/store/apps/details');
        expect(uri.queryParameters, {'id': AppConstants.androidApplicationId});
      }
    });

    test('Apple platformları: App Store sayfası', () {
      for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
        final uri = AppConstants.storeUri(platform);

        expect(
          uri.toString(),
          'https://apps.apple.com/app/id${AppConstants.appStoreId}',
          reason: platform.name,
        );
      }
    });

    test('androidApplicationId, Gradle `applicationId` ile aynıdır', () {
      final gradle = readText('android/app/build.gradle.kts');

      expect(
        gradle,
        contains('applicationId = "${AppConstants.androidApplicationId}"'),
      );
    });
  });
}
