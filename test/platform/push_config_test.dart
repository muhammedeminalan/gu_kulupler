// T-42 · push yapılandırması (Mod F, CD-165): FCM otomatik başlatma kapalı
// (jeton yalnızca etkin oturumda açılır), iOS arka plan kipi
// `remote-notification`, `aps-environment` yetkisi (Runner hedefinin üç
// yapılandırmasında bağlı), Android varsayılan push kanalı = uygulamanın
// kurduğu `gu_push`; `firebase_messaging` yalnızca gu_data'da (B04 —
// uygulama SDK'yı doğrudan içe aktarmaz), `cloud_functions` yok.
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/core/constants/app_constants.dart';

import '../helpers/design_files.dart';

void main() {
  group('T-42 · push yapılandırması', () {
    test('iOS: UIBackgroundModes = [remote-notification]; Runner.entitlements '
        'aps-environment; Runner hedefinin Debug / Release / Profile '
        'yapılandırmaları yetki dosyasını bağlar', () {
      final plist = readText('ios/Runner/Info.plist');
      final modes = RegExp(
        r'<key>UIBackgroundModes</key>\s*<array>(.*?)</array>',
        dotAll: true,
      ).firstMatch(plist);
      expect(modes, isNotNull);
      expect(
        RegExp(
          '<string>([^<]*)</string>',
        ).allMatches(modes!.group(1)!).map((m) => m.group(1)),
        ['remote-notification'],
      );

      expect(
        plist,
        matches(
          RegExp(r'<key>FirebaseMessagingAutoInitEnabled</key>\s*<false/>'),
        ),
      );

      final entitlements = readText('ios/Runner/Runner.entitlements');
      expect(
        entitlements,
        matches(
          RegExp(r'<key>aps-environment</key>\s*<string>development</string>'),
        ),
      );
      final pbx = readText('ios/Runner.xcodeproj/project.pbxproj');
      expect(
        'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;'
            .allMatches(pbx)
            .length,
        3,
      );
    });

    test('Android: varsayılan push kanalı AppConstants.pushChannelId, küçük '
        'ikon mevcut kaynak, otomatik başlatma kapalı', () {
      final manifest = readText('android/app/src/main/AndroidManifest.xml');
      String? metaValue(String name, String attribute) => RegExp(
        '<meta-data\\s+android:name="$name"\\s+android:$attribute="([^"]+)"',
      ).firstMatch(manifest)?.group(1);

      expect(
        metaValue(
          'com.google.firebase.messaging.default_notification_channel_id',
          'value',
        ),
        AppConstants.pushChannelId,
      );
      expect(
        metaValue(
          'com.google.firebase.messaging.default_notification_icon',
          'resource',
        ),
        '@drawable/ic_stat_notification',
      );
      expect(
        metaValue(
          'com.google.firebase.messaging.default_notification_color',
          'resource',
        ),
        '@color/notification_accent',
      );
      expect(
        metaValue('firebase_messaging_auto_init_enabled', 'value'),
        'false',
      );
    });

    test('sunucunun gönderdiği Android kanalları (functions config.ts) '
        'uygulamanın kurduğu kanallardır', () {
      final config = readText('functions/src/lib/config.ts');
      String? constant(String name) => RegExp(
        "export const $name = '([^']+)';",
      ).firstMatch(config)?.group(1);

      expect(constant('ANDROID_CHANNEL'), AppConstants.pushChannelId);
      expect(
        constant('ANDROID_QUIET_CHANNEL'),
        AppConstants.pushQuietChannelId,
      );
    });

    test('firebase_messaging yalnızca gu_data bağımlılığıdır; cloud_functions '
        'eklenmez (callable yok)', () {
      final data = readText('packages/gu_data/pubspec.yaml');
      final root = readText('pubspec.yaml');
      expect(data, contains('  firebase_messaging: ^16.7.0'));
      expect(root, isNot(contains('\n  firebase_messaging:')));
      expect('$root$data', isNot(contains('cloud_functions:')));
    });
  });
}
