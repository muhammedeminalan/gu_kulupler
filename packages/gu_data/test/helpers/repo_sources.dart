// Depo belgelerini ve tasarım/seed kaynaklarını (docs/PLAN.md,
// docs/domain-model.md, design/extracted/registry.json,
// tool/seed/demo-data.json …) testler için okur. Parite testleri sabitleri bu
// kaynaklarla karşılaştırır; kaynak değişirse test kırılır.
import 'dart:convert';
import 'dart:io';

/// Depo kökü: çalışma dizininden yukarı doğru `docs/PLAN.md` içeren ilk dizin.
///
/// `flutter test` paket kökünde (`packages/gu_data`) koşar; kök iki üsttedir.
/// Yukarı yürüyerek aramak, testi depo kökünden tek dosya olarak koşmayı da
/// destekler.
final String repoRoot = _findRepoRoot();

String _findRepoRoot() {
  var dir = Directory.current.absolute;
  while (true) {
    if (File('${dir.path}/docs/PLAN.md').existsSync()) return dir.path;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError(
        'Depo kökü bulunamadı: ${Directory.current.path} üzerinde '
        'docs/PLAN.md yok.',
      );
    }
    dir = parent;
  }
}

/// Depo köküne göreli [relative] dosyasının metni.
String readRepoFile(String relative) =>
    File('$repoRoot/$relative').readAsStringSync();

/// Depo köküne göreli [relative] JSON dosyasının kök nesnesi.
Map<String, Object?> readRepoJson(String relative) =>
    jsonDecode(readRepoFile(relative)) as Map<String, Object?>;

/// Bir Markdown tablosu: başlık hücreleri ve veri satırları.
final class MarkdownTable {
  /// Tablo oluşturur.
  const MarkdownTable({required this.header, required this.rows});

  /// Başlık satırının hücreleri.
  final List<String> header;

  /// Veri satırları (başlık ve ayırıcı hariç); her satır hücre listesidir.
  final List<List<String>> rows;

  /// İlk hücresi [firstCell] olan tek satır; yoksa ya da birden çoksa
  /// [StateError].
  List<String> rowWhereFirstCell(String firstCell) =>
      rows.singleWhere((row) => row.first == firstCell);
}

/// [markdown] içinde [heading] ile başlayan (tek) başlık satırından sonraki
/// ilk tabloyu ayrıştırır.
///
/// Hücreler kırpılır; tablo içi kaçışlı boru (`\|`) gerçek `|` karakterine
/// çevrilir. Başlık bulunamazsa, birden çok kez geçerse ya da bir sonraki
/// başlıktan önce tablo yoksa [StateError] fırlatır — sessizce boş tablo
/// dönmez.
MarkdownTable markdownTable(String markdown, {required String heading}) {
  final lines = const LineSplitter().convert(markdown);
  final starts = [
    for (var i = 0; i < lines.length; i++)
      if (lines[i].startsWith(heading)) i,
  ];
  if (starts.length != 1) {
    throw StateError(
      'Başlık "$heading" tam bir kez geçmeli; bulunan: ${starts.length}.',
    );
  }

  var index = starts.single + 1;
  while (index < lines.length && !lines[index].startsWith('|')) {
    if (lines[index].startsWith('#')) {
      throw StateError('Başlık "$heading" altında tablo yok.');
    }
    index++;
  }

  final tableLines = <String>[];
  while (index < lines.length && lines[index].startsWith('|')) {
    tableLines.add(lines[index]);
    index++;
  }
  if (tableLines.length < 2 || !_isSeparator(tableLines[1])) {
    throw StateError('Başlık "$heading" altında geçerli tablo yok.');
  }

  return MarkdownTable(
    header: _cells(tableLines.first),
    rows: [for (final line in tableLines.skip(2)) _cells(line)],
  );
}

/// [text] içindeki satır içi kod parçaları (ters tırnak arası), sırasıyla.
List<String> codeSpans(String text) => [
  for (final match in RegExp('`([^`]+)`').allMatches(text)) match.group(1)!,
];

bool _isSeparator(String line) =>
    _cells(line).every((cell) => RegExp(r'^:?-+:?$').hasMatch(cell));

/// Satırı kaçışsız borulardan böler (`\|` hücre içinde kalır).
List<String> _cells(String line) {
  final trimmed = line.trim();
  final inner = trimmed.substring(
    1,
    trimmed.endsWith('|') ? trimmed.length - 1 : trimmed.length,
  );
  return [
    for (final cell in inner.split(RegExp(r'(?<!\\)\|')))
      cell.trim().replaceAll(r'\|', '|'),
  ];
}
