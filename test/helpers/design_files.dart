// Depo dosyası okuyucuları (kök testleri; `flutter test` kökte koşar →
// `Directory.current` = depo kökü). Tasarım envanteri, araç kalıp dosyaları
// ve pubspec buradan okunur; JSON/metin yolu başka yerde kurulmaz.
import 'dart:convert';
import 'dart:io';

/// Depo kökü (mutlak yol).
String get repoRoot => Directory.current.absolute.path;

/// Depo köküne göre [relative] dosya.
File repoFile(String relative) => File('$repoRoot/$relative');

/// Depo köküne göre [relative] metin dosyası.
String readText(String relative) => repoFile(relative).readAsStringSync();

/// Depo köküne göre [relative] JSON dosyası (çözülmüş değer).
Object? readJson(String relative) => jsonDecode(readText(relative));

/// Depo köküne göre [relative] JSON nesnesi.
Map<String, dynamic> readJsonMap(String relative) =>
    readJson(relative)! as Map<String, dynamic>;

/// Kalıp dosyası biçimi (`tool/arb_dynamic_keys.txt`,
/// `tool/design_exempt_actions.txt`, `tool/design_dynamic_actions.txt`):
/// satır başına bir kalıp, `#` sonrası yorum, boş satırlar atlanır.
/// `tool/lib/pack_data.js` `patternFile` ile aynı kural.
List<String> parsePatterns(String text) => [
  for (final line in const LineSplitter().convert(text))
    if (line.replaceFirst(RegExp('#.*'), '').trim() case final p
        when p.isNotEmpty)
      p,
];

/// Depo köküne göre [relative] kalıp dosyası ([parsePatterns]).
List<String> readPatterns(String relative) => parsePatterns(readText(relative));

/// `*` joker → tam eşleşen `RegExp` (`tool/lib/pack_data.js` `globToRe`).
RegExp globToRegExp(String glob) =>
    RegExp('^${glob.split('*').map(RegExp.escape).join('.*')}\$');

/// [value] kalıplardan birine ([globToRegExp]) uyuyor mu.
bool matchesAnyGlob(Iterable<String> globs, String value) =>
    globs.any((g) => globToRegExp(g).hasMatch(value));

/// Enum kaynağındaki `/// Design: <ID>` izleri: üye adı → üstündeki kimlik
/// (`tool/check_design_coverage.js` KAT04 ile aynı kural: iz, üyenin hemen
/// üstündeki belge yorumu bloğundadır; kimlikten sonraki açıklama atlanır).
Map<String, String> parseEnumDesignTraces(String source) => {
  for (final m in RegExp(
    r'^[ \t]*/// Design: (\S+)[^\n]*\n(?:[ \t]*///[^\n]*\n)*[ \t]*(\w+)\s*[,;(]',
    multiLine: true,
  ).allMatches(source))
    m.group(2)!: m.group(1)!,
};

/// Kök `pubspec.yaml` `flutter: fonts:` bloğu → aile → `assets/fonts/*.ttf`
/// yolları (sırasıyla). yaml paketi olmadan: blok, 2 boşluk girintili
/// `fonts:` satırından bir sonraki aynı ya da daha az girintili satıra kadar
/// (`packages/gu_ui/test/helpers/test_fonts_test.dart` ile aynı kural).
Map<String, List<String>> pubspecFontFamilies(String pubspec) {
  final start = RegExp(r'^  fonts:\s*$', multiLine: true).firstMatch(pubspec);
  if (start == null) {
    throw const FormatException('pubspec flutter: fonts: bloğu yok');
  }
  final rest = pubspec.substring(start.end);
  final end = RegExp(r'^ {0,2}\S', multiLine: true).firstMatch(rest);
  final block = end == null ? rest : rest.substring(0, end.start);
  final families = <String, List<String>>{};
  String? family;
  final line = RegExp(
    r'^\s*-\s*family:\s*(\S+)\s*$|^\s*-\s*asset:\s*(\S+\.ttf)\s*$',
    multiLine: true,
  );
  for (final m in line.allMatches(block)) {
    if (m.group(1) case final name?) {
      family = name;
      families[name] = [];
    } else if (family == null) {
      throw FormatException('asset ailesiz: ${m.group(2)}');
    } else {
      families[family]!.add(m.group(2)!);
    }
  }
  return families;
}
