// gu_ui widget golden'ları (Q-16, testing.md §7, PLAN §16.2/§16.5).
//
// Tek konum: `packages/gu_ui/test/goldens/<ad>__<durum>__<tema>.png` —
// test dosyasının yanında `goldens/` açılmaz. Yol `Directory.current`
// (= paket kökü) üzerinden mutlak verilir; test dosyasının derinliği
// önemsizdir.
import 'dart:io';

import 'package:flutter/material.dart';
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

/// `goldenForWidget` çerçevesinin `RepaintBoundary` anahtarı.
const Key kGoldenFrameKey = ValueKey<String>('golden.frame');

/// Golden'da yer alan temalar (sırasıyla).
const List<ThemeMode> kGoldenThemes = [ThemeMode.light, ThemeMode.dark];

/// `test/goldens/<name>__<state>__<light|dark>.png` (paket köküne göre).
String widgetGoldenPath(String name, String state, ThemeMode theme) =>
    '${GoldenPolicy.directory}/${name}__${state}__${goldenThemeName(theme)}.png';

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

/// Paket köküne göre [relative] yolun mutlak `file:` URI'si
/// (`matchesGoldenFile` anahtarı).
Uri goldenUri(String relative) =>
    Uri.file('${Directory.current.absolute.path}/$relative');

/// [states] (durum adı → widget) için açık + koyu golden: her durum
/// `GuTheme` zemininde (`bgCanvas`), `GuInsets.all16` dolgulu bir `Material`
/// çerçeve içinde, [size] görünümde (varsayılan 390×844) çizilir; yalnızca
/// çerçeve yakalanır.
Future<void> goldenForWidget(
  WidgetTester tester,
  String name,
  Map<String, Widget> states, {
  Size? size,
}) async {
  for (final MapEntry(key: state, value: widget) in states.entries) {
    for (final theme in kGoldenThemes) {
      await tester.pumpApp(
        GoldenFrame(child: widget),
        theme: theme,
        size: size ?? const Size(390, 844),
      );
      await tester.pump(GuMotion.base);
      await expectLater(
        find.byKey(kGoldenFrameKey),
        matchesGoldenFile(goldenUri(widgetGoldenPath(name, state, theme))),
      );
    }
  }
}

/// Widget golden çerçevesi: ortalanmış `RepaintBoundary` → tema zemini
/// `Material` → `GuInsets.all16`.
class GoldenFrame extends StatelessWidget {
  const GoldenFrame({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: RepaintBoundary(
      key: kGoldenFrameKey,
      child: Material(
        color: context.gu.colors.bgCanvas,
        child: Padding(padding: GuInsets.all16, child: child),
      ),
    ),
  );
}
