// Tasarım kaynaklarını (registry, token JSON'ları, CSS, prototip JS) testler için okur.
// `flutter test` gu_ui paket kökünde koşar; depo kökü iki üst dizindir.
import 'dart:convert';
import 'dart:io';

/// Depo kökü (packages/gu_ui → ../..).
final String repoRoot = Directory('../..').absolute.path;

String _read(String relative) => File('$repoRoot/$relative').readAsStringSync();

/// `design/extracted/registry.json`.
Map<String, dynamic> registry() =>
    jsonDecode(_read('design/extracted/registry.json')) as Map<String, dynamic>;

/// `registry.json#tokens`.
Map<String, dynamic> registryTokens() =>
    registry()['tokens'] as Map<String, dynamic>;

/// `design/generated-reference/colors/tokens.json`.
Map<String, dynamic> tokensJson() =>
    jsonDecode(_read('design/generated-reference/colors/tokens.json'))
        as Map<String, dynamic>;

/// `design/generated-reference/typography.json`.
Map<String, dynamic> typographyJson() =>
    jsonDecode(_read('design/generated-reference/typography.json'))
        as Map<String, dynamic>;

/// `design/extracted/component-css.css` (ham metin).
String componentCss() => _read('design/extracted/component-css.css');

/// `design/prototype/app/<name>` (ör. `core.js`, `art.js`).
String prototypeJs(String name) => _read('design/prototype/app/$name');

/// Kök `pubspec.yaml` (ham metin; font kaydı `flutter: fonts:` bloğunda).
String rootPubspec() => _read('pubspec.yaml');

/// Prototip uygulama bileşen/ekran dosyaları (bundle, pages-*, core, i18n,
/// seed hariç) — JS taramaları bu listeyi okur.
const List<String> prototypeAppFiles = [
  'ui.js',
  'cards.js',
  'shell.js',
  'sheets.js',
  'dialogs.js',
  'art.js',
  'screens-admin.js',
  'screens-auth.js',
  'screens-clubs.js',
  'screens-events.js',
  'screens-manage.js',
  'screens-profile.js',
];

/// CSS renk literali → ARGB tamsayı (`Color.toARGB32()` ile karşılaştırılır).
///
/// Desteklenen biçimler: `#RGB` (kısa; `#fff` → `#ffffff`), `#RRGGBB`,
/// `rgba(r,g,b,a)` (`AA = round(a × 255)`; `.48` → `0x7A`, `.12` → `0x1F`).
/// Diğerleri (`var(--x)`, `rgb(…)`, ad) `FormatException`.
int parseCssColor(String value) {
  final v = value.trim();
  final short = RegExp(
    r'^#([0-9a-fA-F])([0-9a-fA-F])([0-9a-fA-F])$',
  ).firstMatch(v);
  if (short != null) {
    final hex = [1, 2, 3].map((i) => short.group(i)! * 2).join();
    return 0xFF000000 | int.parse(hex, radix: 16);
  }
  final hex = RegExp(r'^#([0-9a-fA-F]{6})$').firstMatch(v);
  if (hex != null) return 0xFF000000 | int.parse(hex.group(1)!, radix: 16);
  final rgba = RegExp(
    r'^rgba\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*([\d.]+)\s*\)$',
  ).firstMatch(v);
  if (rgba != null) {
    final a = (double.parse(rgba.group(4)!) * 255).round();
    final r = int.parse(rgba.group(1)!);
    final g = int.parse(rgba.group(2)!);
    final b = int.parse(rgba.group(3)!);
    return (a << 24) | (r << 16) | (g << 8) | b;
  }
  throw FormatException('Desteklenmeyen CSS rengi: $value');
}
