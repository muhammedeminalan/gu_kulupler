import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// packages.md §5: native splash renkleri `bg.canvas` tokenından türetilmiş sabitlerdir;
/// YAML'daki her renk (üst düzey + android_12) registry ile testle eşleştirilir.
void main() {
  group('T-00 · native splash ↔ registry.json#tokens', () {
    final yaml = File('flutter_native_splash.yaml').readAsStringSync();

    /// `key:` satırlarının TÜM değerlerini döndürür (üst düzey ve android_12 bloğu).
    List<String> values(String key) => RegExp(
      '^\\s*$key:\\s*"?(#[0-9A-Fa-f]{6})"?',
      multiLine: true,
    ).allMatches(yaml).map((m) => m.group(1)!.toUpperCase()).toList();

    test('color / color_dark her iki blokta bg.canvas ile aynı', () {
      final registry =
          jsonDecode(
                File('design/extracted/registry.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final tokens = registry['tokens'] as Map<String, dynamic>;
      final colors = tokens['COLORS'] as Map<String, dynamic>;
      final canvas = (colors['bg.canvas'] as List<dynamic>).cast<String>();
      final light = canvas[0].toUpperCase();
      final dark = canvas[1].toUpperCase();

      final lightValues = values('color');
      final darkValues = values('color_dark');
      expect(lightValues, hasLength(2), reason: 'üst düzey + android_12');
      expect(darkValues, hasLength(2), reason: 'üst düzey + android_12');
      expect(lightValues, everyElement(light));
      expect(darkValues, everyElement(dark));
      expect(values('icon_background_color'), equals([light]));
      expect(values('icon_background_color_dark'), equals([dark]));
    });

    test('splash görselleri assets/logo altında mevcut', () {
      final images = RegExp(
        r'^\s*image(?:_dark)?:\s*"?([^"\n]+)"?',
        multiLine: true,
      ).allMatches(yaml).map((m) => m.group(1)!.trim()).toSet();
      expect(images, isNotEmpty);
      for (final path in images) {
        expect(path, startsWith('assets/logo/'));
        expect(File(path).existsSync(), isTrue, reason: '$path yok');
      }
    });

    test(
      'flutter_launcher_icons.yaml uygulama ikonunu assets/logo içinden alır',
      () {
        final icons = File('flutter_launcher_icons.yaml').readAsStringSync();
        expect(icons, contains('image_path: "assets/logo/app-icon-1024.png"'));
        expect(File('assets/logo/app-icon-1024.png').existsSync(), isTrue);
      },
    );
  });
}
