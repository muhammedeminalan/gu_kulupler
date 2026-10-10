// T-09 · Grup B (kulüp modelleri) testleri için ortak yardımcılar:
// PLAN §9.6 alan tablosu okuyucusu (alan adı · JSON anahtarı · tip · null ·
// varsayılan docs/PLAN.md'den OKUNUR) ve alan başına copyWith / props
// denetimi. Tablo değişirse model testleri kırılır.
import 'package:equatable/equatable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_annotation/json_annotation.dart';

import 'repo_sources.dart';

final String _plan = readRepoFile('docs/PLAN.md');

const String _absent = '—';
const String _baseHeading = '### 9.2 ';
const String _baseFieldsLabel = 'BaseFields';
const String _createdBy = 'createdBy';

/// PLAN §9.6 tablosunun bir alan satırı.
///
/// `jsonKey == null` ⇒ alan JSON'a yazılmaz (belge kimliği);
/// `defaultCode == null` ⇒ alan zorunludur (tabloda `—`).
typedef PlanFieldRow = ({
  String field,
  String? jsonKey,
  String type,
  bool nullable,
  String? defaultCode,
});

/// `copyWith` ile **tek alanı** değişmiş bir kopya: `read` o alanı okur,
/// `expected` kopyada beklenen değerdir.
typedef FieldCase<M> = ({
  String field,
  M copy,
  Object? Function(M model) read,
  Object? expected,
});

/// Bir modelin PLAN §9.6 alan tablosu.
///
/// Tablonun "BaseFields (n alan)" satırı §9.2 tablosundan açılır (`createdBy`
/// hariç: onu taşıyan model tablosunda ayrı satırı vardır). Beklenmeyen
/// biçim [StateError] fırlatır — sessizce eksik küme dönmez.
final class ClubGroupPlanTable {
  ClubGroupPlanTable._(this.rows);

  /// PLAN §[section] (ör. `9.6.3`) tablosunu okur.
  factory ClubGroupPlanTable.read(String section) {
    final rows = <PlanFieldRow>[];
    for (final row in markdownTable(_plan, heading: '#### $section ').rows) {
      if (!row.first.startsWith(_baseFieldsLabel)) {
        rows.add(_parse(row));
        continue;
      }
      final base = [
        for (final baseRow in markdownTable(_plan, heading: _baseHeading).rows)
          if (codeSpans(baseRow.first).single != _createdBy) _parse(baseRow),
      ];
      if (!row.first.contains('(${base.length} alan)')) {
        throw StateError(
          'PLAN §$section "${row.first}" §9.2 ile uyuşmuyor '
          '(${base.length} alan).',
        );
      }
      rows.addAll(base);
    }
    final names = {for (final row in rows) row.field};
    if (names.length != rows.length) {
      throw StateError('PLAN §$section tablosunda yinelenen alan var.');
    }
    return ClubGroupPlanTable._(rows);
  }

  /// Tablonun satırları, sırasıyla.
  final List<PlanFieldRow> rows;

  /// Tüm Dart alan adları (belge kimliği dahil).
  Set<String> get fields => {for (final row in rows) row.field};

  /// JSON'a yazılan anahtarlar (belge kimliği hariç).
  Set<String> get jsonKeys => {
    for (final row in rows) ?row.jsonKey,
  };

  /// Null olabilen alanların adları.
  Set<String> get nullableFields => {
    for (final row in rows)
      if (row.nullable) row.field,
  };

  /// Varsayılanı olmayan (zorunlu) alanların JSON anahtarları.
  Set<String> get requiredJsonKeys => {
    for (final row in rows)
      if (row.defaultCode == null) ?row.jsonKey,
  };

  /// Tipi [type] ile başlayan alanların JSON anahtarları (ör. `DateTime`).
  Set<String> jsonKeysOfType(String type) => {
    for (final row in rows)
      if (row.type.startsWith(type)) ?row.jsonKey,
  };

  /// Varsayılanı olan her alanın gerçek değerini ([actual]: alan adı → değer)
  /// tablodaki varsayılan koduyla karşılaştırır.
  ///
  /// `null`, `true`, `false`, `0` ve `''` kodları yerleşiktir; diğer kodların
  /// (enum üyeleri, `const X()`, hesaplanan kimlikler) karşılığı [codes] ile
  /// verilir. [actual] varsayılanı olan alanların **tamamını** içermelidir.
  void expectDefaults(
    Map<String, Object?> actual, {
    Map<String, Object?> codes = const {},
  }) {
    final known = <String, Object?>{..._literalCodes, ...codes};
    final defaulted = [
      for (final row in rows)
        if (row.defaultCode != null) row,
    ];
    expect(
      actual.keys.toSet(),
      {for (final row in defaulted) row.field},
      reason: 'varsayılanı olan her alan sınanmalı',
    );
    for (final row in defaulted) {
      final code = row.defaultCode!;
      expect(known.containsKey(code), isTrue, reason: 'çözülemeyen kod: $code');
      expect(actual[row.field], known[code], reason: '${row.field} = $code');
    }
  }

  /// PLAN §9.6'daki gömülü [model] tanımının JSON anahtarları.
  ///
  /// Tanım biçimi: `` `XModel` (`models/x_model.dart`): `a` (…) · `b` (…) ``
  /// — anahtarlar satır başında ya da ` · ` ayracından sonra gelen, hemen
  /// ardından parantez açılan kod parçalarıdır.
  static Set<String> embeddedKeys(String model) {
    final definition = RegExp(
      '^`$model` \\(`models/\\w+\\.dart`\\): (.*)\$',
      multiLine: true,
    );
    final matches = definition.allMatches(_plan).toList();
    if (matches.length != 1) {
      throw StateError(
        'PLAN §9.6: $model tanımı tam bir kez geçmeli; bulunan: '
        '${matches.length}.',
      );
    }
    final keys = {
      for (final key in RegExp(
        r'(?:^| · )`(\w+)` \(',
      ).allMatches(matches.single.group(1)!))
        key.group(1)!,
    };
    if (keys.isEmpty) {
      throw StateError('PLAN §9.6: $model tanımında anahtar bulunamadı.');
    }
    return keys;
  }

  static const Map<String, Object?> _literalCodes = {
    'null': null,
    'true': true,
    'false': false,
    '0': 0,
    "''": '',
  };

  static PlanFieldRow _parse(List<String> row) {
    final nullCell = row[3];
    if (!nullCell.startsWith('evet') && !nullCell.startsWith('hayır')) {
      throw StateError('"${row.first}" satırında Null sütunu: "$nullCell".');
    }
    return (
      field: codeSpans(row[0]).single,
      jsonKey: row[1].startsWith(_absent) ? null : codeSpans(row[1]).single,
      type: codeSpans(row[2]).single,
      nullable: nullCell.startsWith('evet'),
      defaultCode: row[4] == _absent ? null : codeSpans(row[4]).single,
    );
  }
}

/// Belge verisi ayrıştırılamadı: üretilen kod `checked: true` ile
/// [CheckedFromJsonException], onsuz enum için [ArgumentError], tip uyuşmazlığı
/// için [TypeError] fırlatır (PLAN §9.10 `checked` ayarından bağımsız sınama).
final Matcher throwsParseError = throwsA(
  anyOf(
    isA<CheckedFromJsonException>(),
    isA<ArgumentError>(),
    isA<TypeError>(),
  ),
);

/// Her vakada `copyWith`'in alanı değiştirdiğini ve değişikliğin eşitliği
/// bozduğunu (alan `props` içinde) doğrular; vakalar [fields] kümesini
/// **tam** karşılamalıdır (alan başına tek vaka).
void expectFieldCases<M extends Equatable>(
  M full,
  List<FieldCase<M>> cases, {
  required Set<String> fields,
}) {
  expect(cases, hasLength(fields.length), reason: 'alan başına tek vaka');
  expect({for (final c in cases) c.field}, fields);
  for (final c in cases) {
    expect(
      c.read(full),
      isNot(c.expected),
      reason: '${c.field}: vaka değeri değiştirmiyor',
    );
    expect(c.read(c.copy), c.expected, reason: '${c.field}: değer taşınmadı');
    expect(c.copy, isNot(full), reason: '${c.field}: props içinde değil');
  }
}
