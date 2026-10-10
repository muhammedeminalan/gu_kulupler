// PLAN §10.1 hata eşleme tablolarını ve §4.2 ağaç satırlarındaki enum üye
// listelerini testler için okur. Hata enum'ları bu iki kaynakla birebir
// olmalıdır; PLAN değişirse parite testleri kırılır.
import 'repo_sources.dart';

/// PLAN §10.1'deki bir "kod → enum" tablosunun ayrıştırılmış hali.
final class PlanErrorTable {
  /// Tablo oluşturur.
  const PlanErrorTable({
    required this.sdkCodes,
    required this.appMembers,
    required this.fallbackMember,
  });

  /// SDK hata kodu → enum üye adı (ör. `permission-denied` →
  /// `permissionDenied`).
  final Map<String, String> sdkCodes;

  /// SDK dışı (ilk hücresi `—` ile başlayan) satırların enum üye adları,
  /// tablo sırasıyla.
  final List<String> appMembers;

  /// "diğer" / "eşleşmeyen" satırının enum üye adı.
  final String fallbackMember;

  /// Tabloda adı geçen tüm enum üyeleri.
  Set<String> get members => {
    ...sdkCodes.values,
    ...appMembers,
    fallbackMember,
  };
}

/// PLAN §10.1'de [enumName] enum'unun başlık satırını (kalın, `(enum, …`
/// ile devam eden) izleyen eşleme tablosunu okur.
///
/// İlk sütun SDK kodlarını (ters tırnaklı), ikinci sütun enum üyesini taşır.
/// Aynı kod iki satırda geçerse ya da "diğer" satırı tek değilse [StateError].
PlanErrorTable readPlanErrorTable(String enumName) {
  final table = markdownTable(
    readRepoFile('docs/PLAN.md'),
    heading: '**`$enumName` (enum,',
  );
  final sdkCodes = <String, String>{};
  final appMembers = <String>[];
  final fallbacks = <String>[];

  for (final row in table.rows) {
    final source = row[0];
    final member = codeSpans(row[1]).first;
    if (source.startsWith('—')) {
      appMembers.add(member);
      continue;
    }
    for (final code in codeSpans(source)) {
      if (sdkCodes.containsKey(code)) {
        throw StateError('$enumName tablosunda "$code" iki kez geçiyor.');
      }
      sdkCodes[code] = member;
    }
    if (source.contains('diğer') || source.contains('eşleşmeyen')) {
      fallbacks.add(member);
    }
  }

  if (fallbacks.length != 1) {
    throw StateError(
      '$enumName tablosunda tam bir "diğer" satırı olmalı; bulunan: '
      '${fallbacks.length}.',
    );
  }
  return PlanErrorTable(
    sdkCodes: sdkCodes,
    appMembers: appMembers,
    fallbackMember: fallbacks.single,
  );
}

/// PLAN §10.1 `ruleViolation` satırındaki `FirestoreRuleCode` üye listesi.
List<String> readPlanRuleCodes() {
  final table = markdownTable(
    readRepoFile('docs/PLAN.md'),
    heading: '**`FirestoreError` (enum,',
  );
  final cell = table.rows.singleWhere(
    (row) => codeSpans(row[1]).first == 'ruleViolation',
  )[1];
  final spans = codeSpans(cell);
  if (spans.length != 3 || spans[1] != 'FirestoreRuleCode') {
    throw StateError('ruleViolation hücresi beklenen biçimde değil: $cell');
  }
  return [for (final name in spans[2].split(',')) name.trim()];
}

/// PLAN §4.2 ağacında [file] satırındaki `enum Ad n üye (…)` bildirimi
/// ([enumName] için): beyan edilen üye sayısı ve üye adları (sırayla).
///
/// Üye listesi içindeki açıklama parantezleri (`unavailable (… eşlenir)`) ve
/// baştaki bölüm göndermesi (`§10.1:`) atılır.
({int count, List<String> members}) readPlanTreeEnum({
  required String file,
  required String enumName,
}) {
  final line = readRepoFile(
    'docs/PLAN.md',
  ).split('\n').singleWhere((line) => line.contains('── $file'));
  final head = RegExp('enum $enumName (\\d+) üye \\(').firstMatch(line);
  if (head == null) {
    throw StateError('$file satırında "enum $enumName <n> üye (" yok.');
  }

  var depth = 1;
  var end = head.end;
  while (depth > 0) {
    final char = line[end];
    if (char == '(') depth++;
    if (char == ')') depth--;
    end++;
  }
  final inner = line
      .substring(head.end, end - 1)
      .replaceAll(RegExp(r'\([^()]*\)'), '')
      .replaceFirst(RegExp(r'^§[\d.]+:'), '');

  return (
    count: int.parse(head.group(1)!),
    members: [for (final name in inner.split(',')) name.trim()],
  );
}
