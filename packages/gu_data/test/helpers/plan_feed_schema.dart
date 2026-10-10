// PLAN §9.6 alan tablolarını model testleri için okur (T-09, akış modelleri):
// alan adları, JSON anahtarları, kurucu varsayılanları ve gömülü model
// tanımları docs/PLAN.md'den türetilir; tablo değişirse test kırılır.
import 'package:flutter_test/flutter_test.dart';

import 'repo_sources.dart';

final String _plan = readRepoFile('docs/PLAN.md');

/// §9.6 tablolarının sütunları.
const int _fieldColumn = 0;
const int _jsonColumn = 1;
const int _defaultColumn = 4;

/// Tablolardaki ortak alan satırı: §9.2'nin altı alanından `createdBy`
/// dışındaki beşi (`createdBy` yalnızca kulüp ve etkinlikte bildirilir).
const String _baseFieldsRow = 'BaseFields (5 alan)';
const String _createdBy = 'createdBy';

/// "Değer yok" hücresi: zorunlu parametre (varsayılan sütunu) ya da JSON'a
/// yazılmayan belge kimliği (JSON sütunu).
const String _none = '—';

/// §9.2 `BaseFields` tablosu: alan adı → kurucu varsayılanı (`createdBy`
/// hariç beş alan; alan adı JSON anahtarıyla aynıdır).
Map<String, String> _baseDefaults() {
  final table = markdownTable(_plan, heading: '### 9.2 ');
  return {
    for (final row in table.rows)
      if (codeSpans(row[_fieldColumn]).single != _createdBy)
        codeSpans(row[_fieldColumn]).single: codeSpans(
          row[_defaultColumn],
        ).single,
  };
}

/// [heading] ile başlayan §9.6 tablosunun (örn. `'#### 9.6.6 '`) alan
/// adları, sırasıyla — belge kimliği dahil, `BaseFields` satırı açılmış.
List<String> planFieldNames(String heading) => [
  for (final row in markdownTable(_plan, heading: heading).rows)
    if (row[_fieldColumn] == _baseFieldsRow)
      ..._baseDefaults().keys
    else
      codeSpans(row[_fieldColumn]).single,
];

/// [heading] tablosunun JSON anahtarları — belge kimliği satırı (`—`) hariç,
/// `BaseFields` satırı açılmış.
Set<String> planJsonKeys(String heading) => {
  for (final row in markdownTable(_plan, heading: heading).rows)
    if (row[_fieldColumn] == _baseFieldsRow)
      ..._baseDefaults().keys
    else if (!row[_jsonColumn].startsWith(_none))
      codeSpans(row[_jsonColumn]).single,
};

/// [heading] tablosunun "Varsayılan" sütunu: alan adı → Dart ifadesi
/// (`false`, `0`, `null`, `const []`, `PostType.post` …). Zorunlu alanlar
/// (`—`) yer almaz; `BaseFields` satırı §9.2 varsayılanlarıyla açılır.
Map<String, String> planDefaults(String heading) => {
  for (final row in markdownTable(_plan, heading: heading).rows)
    if (row[_fieldColumn] == _baseFieldsRow)
      ..._baseDefaults()
    else if (row[_defaultColumn] != _none)
      codeSpans(row[_fieldColumn]).single: codeSpans(
        row[_defaultColumn],
      ).single,
};

/// §9.6 metnindeki gömülü model tanımının JSON anahtarları, sırasıyla.
///
/// Tanım biçimi: `` `XModel` (`models/x_model.dart`): `a` (…) · `b` (…) `` —
/// anahtarlar tanımın başında ya da ` · ` ayracından sonra gelen, hemen
/// ardından parantez açılan kod parçalarıdır. Tanım tam bir kez geçmelidir.
List<String> planEmbeddedKeys(String model) {
  final definition = RegExp(
    '^`${RegExp.escape(model)}` '
    r'\(`models/\w+\.dart`\): (.*)$',
    multiLine: true,
  );
  final body = definition.allMatches(_plan).single.group(1)!;
  return [
    for (final key in RegExp(r'(?:^| · )`(\w+)` \(').allMatches(body))
      key.group(1)!,
  ];
}

/// [value] değerinin PLAN "Varsayılan" sütunundaki yazımı.
///
/// Yalnızca tabloda geçen biçimleri bilir: `null`, `bool`, `int`, boş liste
/// (`const []`) ve enum (`Tip.ad`); başka değer [ArgumentError] fırlatır.
String planLiteral(Object? value) => switch (value) {
  null => 'null',
  bool() || int() => '$value',
  List<Object?>(isEmpty: true) => 'const []',
  Enum() => '${value.runtimeType}.${value.name}',
  _ => throw ArgumentError.value(value, 'value', 'PLAN yazımı bilinmiyor'),
};

/// [changed] modeli [base]'e göre **yalnızca** [field] alanında farklı olmalı,
/// o alan [value] olmalı ve eşitlik bozulmalı (`props` alanı taşıyor).
///
/// [fields] modelin tüm alanlarını ad → değer olarak verir; değişmeyen
/// alanların aynı kaldığı bu haritadan doğrulanır.
void expectSingleFieldChange<T extends Object>({
  required T base,
  required T changed,
  required Map<String, Object?> Function(T model) fields,
  required String field,
  required Object? value,
}) {
  final before = fields(base);
  final after = fields(changed);
  expect(before.keys, contains(field));
  expect(after[field], value, reason: field);
  expect(
    [
      for (final key in after.keys)
        if (after[key] != before[key]) key,
    ],
    [field],
    reason: 'yalnızca $field değişmeli',
  );
  expect(changed, isNot(base), reason: 'props $field alanını taşımalı');
}
