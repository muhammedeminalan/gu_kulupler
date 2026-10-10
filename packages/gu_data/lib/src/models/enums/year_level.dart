import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';

/// Sınıf / öğrenim düzeyi (`users.year`, `memberships.applicant.year`;
/// PLAN §9.7, domain-model §2.1).
///
/// Bildirim sırası `design/extracted/registry.json#years` sırasıdır.
@JsonEnum(valueField: 'json')
enum YearLevel {
  /// Hazırlık.
  prep('prep'),

  /// 1. sınıf.
  first('1'),

  /// 2. sınıf.
  second('2'),

  /// 3. sınıf.
  third('3'),

  /// 4. sınıf.
  fourth('4'),

  /// 5. sınıf ve üzeri.
  fivePlus('5plus'),

  /// Yüksek lisans.
  master('master'),

  /// Doktora.
  phd('phd');

  const YearLevel(this.json);

  /// Firestore'daki dizgi karşılığı.
  final String json;

  /// Firestore dizgisinden değer üretir.
  ///
  /// Eşleşme birebirdir (büyük/küçük harf ve boşluk duyarlı). Bilinmeyen
  /// değer [ArgumentError] fırlatır; bu enum'da `unknown` üyesi yoktur
  /// (model ayrıştırmasında `CheckedFromJsonException` →
  /// `FirestoreError.parse`).
  static YearLevel fromJson(String json) =>
      values.firstWhereOrNull((value) => value.json == json) ??
      (throw ArgumentError.value(json, 'json', 'YearLevel: bilinmeyen değer'));
}
