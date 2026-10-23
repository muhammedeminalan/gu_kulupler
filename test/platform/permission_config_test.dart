// T-14 · izin yapılandırması paritesi (PLAN §5.6.1, §5.6.2; CD-16):
// iOS izin metinleri (Info.plist + TR/EN InfoPlist.strings, Xcode projesine
// kayıtlı), Android izinleri (kamera + bildirim; depolama / fotoğraf izni
// YOK) ve pubspec bağımlılıkları.
import 'package:flutter_test/flutter_test.dart';

import '../helpers/design_files.dart';

/// Uygulamanın kullandığı iOS izin açıklaması anahtarları.
const List<String> _usageKeys = [
  'NSCameraUsageDescription',
  'NSPhotoLibraryUsageDescription',
];

/// `"anahtar" = "değer";` satırları.
Map<String, String> _strings(String relative) => {
  for (final match in RegExp(
    r'^"([^"]+)"\s*=\s*"([^"]*)";\s*$',
    multiLine: true,
  ).allMatches(readText(relative)))
    match.group(1)!: match.group(2)!,
};

/// Info.plist içindeki `<key>…</key><string>…</string>` değeri.
String? _plistString(String plist, String key) => RegExp(
  '<key>$key</key>\\s*<string>([^<]*)</string>',
).firstMatch(plist)?.group(1);

void main() {
  group('T-14 · iOS izin metinleri', () {
    final plist = readText('ios/Runner/Info.plist');

    test('Info.plist iki izin açıklamasını taşır (boş değil)', () {
      for (final key in _usageKeys) {
        expect(_plistString(plist, key), isNotEmpty, reason: key);
      }
    });

    test('yalnızca kullanılan izinlerin açıklaması vardır (mikrofon, konum, '
        'kişiler, fotoğraf ekleme … yok)', () {
      final keys = RegExp(
        '<key>(NS[A-Za-z]+UsageDescription)</key>',
      ).allMatches(plist).map((match) => match.group(1)).toList();
      expect(keys, unorderedEquals(_usageKeys));
    });

    test('CFBundleLocalizations = [tr, en]', () {
      final block = RegExp(
        r'<key>CFBundleLocalizations</key>\s*<array>(.*?)</array>',
        dotAll: true,
      ).firstMatch(plist);
      expect(block, isNotNull);
      expect(
        RegExp(
          '<string>([^<]*)</string>',
        ).allMatches(block!.group(1)!).map((match) => match.group(1)),
        ['tr', 'en'],
      );
    });

    test('TR ve EN InfoPlist.strings aynı anahtarları taşır; Info.plist '
        'varsayılanı EN metniyle aynıdır', () {
      final tr = _strings('ios/Runner/tr.lproj/InfoPlist.strings');
      final en = _strings('ios/Runner/en.lproj/InfoPlist.strings');

      expect(tr.keys, unorderedEquals(_usageKeys));
      expect(en.keys, unorderedEquals(_usageKeys));
      for (final key in _usageKeys) {
        expect(tr[key], isNotEmpty, reason: key);
        expect(en[key], _plistString(plist, key), reason: key);
        expect(tr[key], isNot(en[key]), reason: key);
      }
    });

    test('InfoPlist.strings Xcode projesine kayıtlıdır: tr + en varyantları, '
        'Resources aşaması, knownRegions', () {
      final pbx = readText('ios/Runner.xcodeproj/project.pbxproj');

      expect(pbx, contains('path = tr.lproj/InfoPlist.strings;'));
      expect(pbx, contains('path = en.lproj/InfoPlist.strings;'));
      expect(pbx, contains('/* InfoPlist.strings in Resources */,'));
      final group = RegExp(
        r'/\* InfoPlist\.strings \*/ = \{\s*isa = PBXVariantGroup;\s*'
        r'children = \((.*?)\);',
        dotAll: true,
      ).firstMatch(pbx);
      expect(group, isNotNull);
      expect(
        group!.group(1),
        allOf(contains('/* tr */'), contains('/* en */')),
      );
      final regions = RegExp(
        r'knownRegions = \((.*?)\);',
        dotAll: true,
      ).firstMatch(pbx)!.group(1)!;
      expect(
        regions
            .split(',')
            .map((region) => region.trim())
            .where(
              (region) => region.isNotEmpty,
            ),
        containsAll(<String>['en', 'tr']),
      );
    });
  });

  group('T-14 · Android izinleri', () {
    final manifest = readText('android/app/src/main/AndroidManifest.xml');
    final permissions = RegExp(
      r'<uses-permission\s+android:name="([^"]+)"',
    ).allMatches(manifest).map((match) => match.group(1)).toList();

    test('internet (1.1.0: release manifestinde açıkça), kamera (DLG-04), '
        'bildirim (DLG-03) ve — T-23 — yeniden başlatma (yerel hatırlatıcı) '
        'izni bildirilir; başka izin yok', () {
      expect(permissions, [
        'android.permission.INTERNET',
        'android.permission.CAMERA',
        'android.permission.POST_NOTIFICATIONS',
        'android.permission.RECEIVE_BOOT_COMPLETED',
      ]);
    });

    test('T-23 · kesin alarm izni YOK (inexactAllowWhileIdle — CD-09); '
        'flutter_local_notifications alıcıları kayıtlı', () {
      expect(permissions, isNot(contains(endsWith('SCHEDULE_EXACT_ALARM'))));
      expect(permissions, isNot(contains(endsWith('USE_EXACT_ALARM'))));
      const receivers = 'com.dexterous.flutterlocalnotifications';
      expect(manifest, contains('$receivers.ScheduledNotificationReceiver"'));
      expect(
        manifest,
        contains('$receivers.ScheduledNotificationBootReceiver"'),
      );
      expect(manifest, contains('android.intent.action.BOOT_COMPLETED'));
      final gradle = readText('android/app/build.gradle.kts');
      expect(gradle, contains('isCoreLibraryDesugaringEnabled = true'));
      expect(gradle, contains('coreLibraryDesugaring("com.android.tools:'));
      expect(
        readText('ios/Runner/AppDelegate.swift'),
        contains('UNUserNotificationCenter.current().delegate = self'),
      );
    });

    test('depolama / fotoğraf izni YOK: galeri sistem fotoğraf seçicisiyle '
        'açılır (CD-16)', () {
      for (final forbidden in const [
        'READ_MEDIA_IMAGES',
        'READ_MEDIA_VISUAL_USER_SELECTED',
        'READ_EXTERNAL_STORAGE',
        'WRITE_EXTERNAL_STORAGE',
      ]) {
        expect(
          permissions.where((name) => name!.endsWith(forbidden)),
          isEmpty,
          reason: forbidden,
        );
      }
    });

    test("debug ve profile manifest'leri ek izin bildirmez", () {
      for (final variant in const ['debug', 'profile']) {
        expect(
          readText('android/app/src/$variant/AndroidManifest.xml'),
          isNot(
            contains(
              '<uses-permission android:name="android.permission.CAMERA"',
            ),
          ),
          reason: variant,
        );
      }
    });
  });

  group('T-14 · paketler', () {
    final pubspec = readText('pubspec.yaml');

    test('izin, görsel seçici ve sıkıştırma paketleri kök uygulamadadır '
        '(PLAN §5.1 sürüm alt sınırları)', () {
      for (final line in const [
        'permission_handler: ^13.0.2',
        'image_picker: ^1.2.4',
        'flutter_image_compress: ^2.5.1',
      ]) {
        expect(pubspec, contains('  $line'), reason: line);
      }
    });

    test('gu_data ve gu_ui bu paketleri almaz (B01, B06)', () {
      for (final package in const ['gu_data', 'gu_ui']) {
        final source = readText('packages/$package/pubspec.yaml');
        for (final plugin in const [
          'permission_handler',
          'image_picker',
          'flutter_image_compress',
        ]) {
          expect(source, isNot(contains(plugin)), reason: '$package/$plugin');
        }
      }
    });

    test('uygulama kodu `Permission.photos` / `Permission.storage` '
        'kullanmaz (CD-16)', () {
      final sources = [
        readText('lib/product/service/permission_service.dart'),
        readText('lib/product/mixin/permission_prompt_mixin.dart'),
        readText('lib/product/service/image_picker_service.dart'),
      ].join();
      for (final forbidden in const [
        'Permission.photos',
        'Permission.storage',
        'Permission.mediaLibrary',
        'Permission.photosAddOnly',
      ]) {
        expect(source(sources), isNot(contains(forbidden)), reason: forbidden);
      }
    });
  });
}

/// Yorum satırları atılmış kaynak (belge yorumundaki adlar sayılmaz).
String source(String text) => [
  for (final line in text.split('\n'))
    if (!line.trimLeft().startsWith('//')) line,
].join('\n');
