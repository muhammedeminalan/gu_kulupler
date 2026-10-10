// Ekran/sheet/dialog golden'ları (Q-16, testing.md §7, PLAN §16.2/§16.5).
//
// Tek konum: `test/goldens/<ad>__<tema>__<dil>.png` (kök paket) — test
// dosyasının yanında `goldens/` açılmaz; yol `Directory.current` (= kök)
// üzerinden mutlak verilir. Widget golden'ları gu_ui'dadır
// (`packages/gu_ui/test/helpers/golden_helper.dart` `goldenForWidget`).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import 'pump_app.dart';

/// Golden politikası (Q-16): varsayılan `LocalFileComparator`, tolerans yok;
/// üretim yalnızca macOS'ta ve bilinçli `--update-goldens` ile; `skip` yok.
abstract final class GoldenPolicy {
  /// Piksel farkı toleransı (0 = birebir).
  static const double tolerance = 0;

  /// Paket köküne göre golden klasörü.
  static const String directory = 'test/goldens';
}

/// Golden'da yer alan temalar (sırasıyla).
const List<ThemeMode> kGoldenThemes = [ThemeMode.light, ThemeMode.dark];

/// `light` / `dark`; `ThemeMode.system` golden'da kullanılmaz.
String goldenThemeName(ThemeMode theme) => switch (theme) {
  ThemeMode.light => 'light',
  ThemeMode.dark => 'dark',
  ThemeMode.system => throw ArgumentError.value(
    theme,
    'theme',
    'golden açık ya da koyu olmalı',
  ),
};

/// `test/goldens/<name>__<light|dark>__<dil>.png` (paket köküne göre).
String goldenPath(String name, ThemeMode theme, Locale locale) =>
    '${GoldenPolicy.directory}/${name}__${goldenThemeName(theme)}__'
    '${locale.languageCode}.png';

/// Paket köküne göre [relative] yolun mutlak `file:` URI'si
/// (`matchesGoldenFile` anahtarı).
Uri goldenUri(String relative) =>
    Uri.file('${Directory.current.absolute.path}/$relative');

/// [widget] için açık + koyu tam ekran golden'ı ([locales] her biri için;
/// varsayılan yalnızca TR). `pumpApp` → `pump(GuMotion.base)` →
/// `kPumpAppBoundaryKey` (MaterialApp + overlay katmanları) yakalanır.
Future<void> goldenForThemes(
  WidgetTester tester,
  String name,
  Widget widget, {
  List<Locale> locales = const [Locale('tr')],
  Size size = const Size(390, 844),
  List<Override> overrides = const [],
}) async {
  for (final locale in locales) {
    for (final theme in kGoldenThemes) {
      await tester.pumpApp(
        widget,
        locale: locale,
        theme: theme,
        size: size,
        overrides: overrides,
      );
      await tester.pump(GuMotion.base);
      await expectLater(
        find.byKey(kPumpAppBoundaryKey),
        matchesGoldenFile(goldenUri(goldenPath(name, theme, locale))),
      );
    }
  }
}
