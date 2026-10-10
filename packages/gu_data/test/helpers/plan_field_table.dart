// docs/PLAN.md §9.6 koleksiyon tablolarını (Alan · JSON · Tip · Null ·
// Varsayılan) model testleri için okur. Model testleri alan kümesini, JSON
// anahtarlarını, tipleri, null olabilirliği ve varsayılanları bu tabloyla
// karşılaştırır; tablo değişirse test kırılır.
import 'package:flutter_test/flutter_test.dart';

import 'repo_sources.dart';

/// PLAN §9.6 tablosunun bir alan satırı.
final class PlanField {
  /// Alan satırı oluşturur.
  const PlanField({
    required this.name,
    required this.jsonKey,
    required this.type,
    required this.nullable,
    required this.defaultCode,
  });

  /// Dart alan adı ("Alan" sütunu).
  final String name;

  /// JSON anahtarı; `null` ise alan JSON'a yazılmaz (belge kimliği, `—`).
  final String? jsonKey;

  /// Dart tipi ("Tip" sütunu; `String?`, `EventType` …).
  final String type;

  /// "Null" sütunu `evet` mi?
  final bool nullable;

  /// "Varsayılan" sütunundaki kod; `null` ise alan zorunludur (`—`).
  final String? defaultCode;
}

/// Bir modelin PLAN §9.6 alan tablosu.
///
/// Tablonun "BaseFields (n alan)" satırı §9.2 tablosundan açılır
/// (`createdBy` hariç: onu taşıyan modellerin tablosunda ayrı satırı vardır);
/// `n`, açılan satır sayısıyla eşleşmezse [StateError] fırlatır.
final class PlanFieldTable {
  PlanFieldTable._(this.fields);

  /// docs/PLAN.md içinde [heading] ile başlayan başlığın altındaki tabloyu
  /// okur (örn. `'#### 9.6.9 '`).
  factory PlanFieldTable.read(String heading) {
    final plan = readRepoFile('docs/PLAN.md');
    final fields = <PlanField>[];
    for (final row in markdownTable(plan, heading: heading).rows) {
      if (!row.first.startsWith(_baseFieldsLabel)) {
        fields.add(_parse(row));
        continue;
      }
      final base = [
        for (final baseRow in markdownTable(plan, heading: _baseHeading).rows)
          if (codeSpans(baseRow.first).single != _createdBy) _parse(baseRow),
      ];
      final declared = RegExp(r'\((\d+) alan\)').firstMatch(row.first);
      if (declared == null || int.parse(declared.group(1)!) != base.length) {
        throw StateError(
          '"${row.first}" §9.2 tablosuyla uyuşmuyor (${base.length} alan).',
        );
      }
      fields.addAll(base);
    }
    return PlanFieldTable._(fields);
  }

  static const String _baseHeading = '### 9.2 ';
  static const String _baseFieldsLabel = 'BaseFields';
  static const String _createdBy = 'createdBy';
  static const String _absent = '—';

  /// Tablonun satırları, sırasıyla.
  final List<PlanField> fields;

  /// Tüm Dart alan adları.
  Set<String> get names => {for (final field in fields) field.name};

  /// JSON'a yazılan anahtarlar (belge kimliği hariç).
  Set<String> get jsonKeys => {
    for (final field in fields) ?field.jsonKey,
  };

  /// Null olabilen alanların adları.
  Set<String> get nullableNames => {
    for (final field in fields)
      if (field.nullable) field.name,
  };

  /// Varsayılanı olmayan (zorunlu) alanların JSON anahtarları.
  Set<String> get requiredJsonKeys => {
    for (final field in fields)
      if (field.defaultCode == null) ?field.jsonKey,
  };

  /// Tipi [type] ile başlayan alanların JSON anahtarları (örn. `DateTime`).
  Set<String> jsonKeysOfType(String type) => {
    for (final field in fields)
      if (field.type.startsWith(type)) ?field.jsonKey,
  };

  static PlanField _parse(List<String> row) {
    final nullCell = row[3];
    if (!nullCell.startsWith('evet') && !nullCell.startsWith('hayır')) {
      throw StateError('"${row.first}" satırında Null sütunu: "$nullCell".');
    }
    return PlanField(
      name: codeSpans(row[0]).single,
      jsonKey: row[1] == _absent ? null : codeSpans(row[1]).single,
      type: codeSpans(row[2]).single,
      nullable: nullCell.startsWith('evet'),
      defaultCode: row[4] == _absent ? null : codeSpans(row[4]).single,
    );
  }
}

/// Tablodaki varsayılan kodunu ([code]) karşılayan değer eşleştiricisi.
///
/// `null`, `true` / `false`, tam sayı, `''` ve `Enum.deger` kodlarını kendisi
/// çözer; hesaplanan varsayılanlar (`FirestoreIds.rsvp(eventId, userId)` …)
/// [computed] ile verilir. Çözülemeyen kod [StateError] fırlatır — sessizce
/// geçmez.
Matcher matchesPlanDefault(
  String code, {
  Map<String, Object?> computed = const {},
}) {
  if (computed.containsKey(code)) return equals(computed[code]);
  final number = int.tryParse(code);
  if (number != null) return equals(number);
  if (RegExp(r'^[A-Z]\w*\.\w+$').hasMatch(code)) {
    return predicate<Object?>((value) => '$value' == code, code);
  }
  return switch (code) {
    'null' => isNull,
    'true' => isTrue,
    'false' => isFalse,
    "''" => equals(''),
    _ => throw StateError('Çözülemeyen tablo varsayılanı: $code'),
  };
}
