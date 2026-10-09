import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/core/constants/app_constants.dart';

/// D-01: ürün adı tek kaynaktan; platform dosyaları bu sabitle aynı olmalı.
/// Q-13: dikey kilit; CD-59: iOS 15.0.
void main() {
  group('T-00 · platform paritesi', () {
    test('Info.plist CFBundleDisplayName == AppConstants.appName', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      final match = RegExp(
        r'<key>CFBundleDisplayName</key>\s*<string>([^<]*)</string>',
      ).firstMatch(plist);
      expect(match, isNotNull);
      expect(match!.group(1), AppConstants.appName);
    });

    test('Info.plist yalnızca dikey yönlendirme (Q-13)', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      List<String> orientations(String key) {
        final m = RegExp(
          '<key>$key</key>\\s*<array>(.*?)</array>',
          dotAll: true,
        ).firstMatch(plist);
        expect(m, isNotNull, reason: '$key anahtarı yok');
        return RegExp(
          '<string>([^<]*)</string>',
        ).allMatches(m!.group(1)!).map((e) => e.group(1)!).toList();
      }

      expect(
        orientations('UISupportedInterfaceOrientations'),
        equals(const ['UIInterfaceOrientationPortrait']),
      );
      expect(
        orientations('UISupportedInterfaceOrientations~ipad'),
        equals(const ['UIInterfaceOrientationPortrait']),
      );
    });

    test('Xcode projesi iOS 15.0 hedefler (CD-59)', () {
      final pbx = File(
        'ios/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync();
      expect(pbx, isNot(contains('IPHONEOS_DEPLOYMENT_TARGET = 13.0')));
      expect(
        RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = 15\.0;').allMatches(pbx).length,
        greaterThanOrEqualTo(3),
      );
    });

    test(
      'AndroidManifest label == AppConstants.appName, dikey, predictive back',
      () {
        final manifest = File(
          'android/app/src/main/AndroidManifest.xml',
        ).readAsStringSync();
        expect(manifest, contains('android:label="${AppConstants.appName}"'));
        expect(manifest, contains('android:screenOrientation="portrait"'));
        expect(
          manifest,
          contains('android:enableOnBackInvokedCallback="true"'),
        );
      },
    );
  });
}
