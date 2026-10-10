// PLAN §10.2 servis tablosunu testler için okur: servis arayüzlerinin üye
// adları ve imzaları bu tabloyla birebir olmalıdır; PLAN değişirse parite
// testleri kırılır.
import 'repo_sources.dart';

/// PLAN §10.2 tablosunun bir üye satırı: servis adı, üye adı ve tam imza.
typedef PlanServiceMember = ({String service, String member, String signature});

final MarkdownTable _table = markdownTable(
  readRepoFile('docs/PLAN.md'),
  heading: '### 10.2 Servisler',
);

/// Tablodaki "YOK" hücresi (arayüzde bulunmaması gereken üye satırı).
const String _absent = '**YOK**';

/// Satırların servis adları: ilk hücre boşsa bir önceki satırın servisi.
Iterable<({String service, List<String> row})> _rows() sync* {
  var service = '';
  for (final row in _table.rows) {
    if (row.first.isNotEmpty) service = codeSpans(row.first).first;
    yield (service: service, row: row);
  }
}

/// [service] servisinin tabloda imzasıyla verilen üyeleri, tablo sırasıyla.
///
/// Üye hücresi tek kod parçası, imza hücresi kod parçasıyla başlayan satırlar
/// alınır; "YOK" satırları ve düz yazı satırları atlanır. Hiç satır
/// bulunamazsa [StateError] (sessizce boş liste dönmez).
List<PlanServiceMember> readPlanServiceMembers(String service) {
  final members = [
    for (final entry in _rows())
      if (entry.service == service &&
          codeSpans(entry.row[1]).length == 1 &&
          entry.row[2].startsWith('`'))
        (
          service: service,
          member: codeSpans(entry.row[1]).single,
          signature: codeSpans(entry.row[2]).first,
        ),
  ];
  if (members.isEmpty) {
    throw StateError('PLAN §10.2 tablosunda "$service" üyesi yok.');
  }
  return members;
}

/// [service] servisinin tabloda "YOK" olarak işaretlenen satırları (üye
/// hücresinin düz metni, ör. `delete`, `delete / update`, `user.delete`).
List<String> readPlanAbsentMembers(String service) => [
  for (final entry in _rows())
    if (entry.service == service && entry.row[2] == _absent)
      entry.row[1].replaceAll('*', ''),
];

/// [service] satırının ilk hücresinde "uygulama `X`" olarak verilen
/// uygulama sınıfının adı.
String readPlanServiceImplementation(String service) {
  final cell = _table.rows
      .map((row) => row.first)
      .firstWhere((cell) => cell.startsWith('`$service`'));
  final match = RegExp('uygulama `([A-Za-z]+)`').firstMatch(cell);
  if (match == null) {
    throw StateError('PLAN §10.2 "$service" satırında uygulama adı yok.');
  }
  return match.group(1)!;
}

/// Dart kaynağını imza karşılaştırması için sadeleştirir: yorumlar ve tüm
/// boşluklar atılır, biçimleyicinin eklediği sondaki virgüller kaldırılır.
String normalizeDartSource(String source) => source
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join()
    .replaceAll(RegExp(r'\s+'), '')
    .replaceAll(',)', ')')
    .replaceAll(',}', '}');

/// [relative] kaynak dosyasında (depo köküne göre) yorum dışı satırlarda
/// geçen ve `delete` ile başlayan tanımlayıcılar (büyük/küçük harf duyarsız).
/// Silme üyesi olmadığını kanıtlayan kaynak taraması içindir (D-10).
List<String> deleteIdentifiersIn(String relative) => [
  for (final line in readRepoFile(relative).split('\n'))
    if (!line.trimLeft().startsWith('//'))
      for (final match in RegExp(
        r'\bdelete\w*',
        caseSensitive: false,
      ).allMatches(line.split('//').first))
        match.group(0)!,
];
