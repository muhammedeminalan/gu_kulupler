import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';

/// Kulüp kapak deseni (`clubs.pattern`; PLAN §9.7, domain-model §2.3;
/// `design/extracted/registry.json#patterns`).
@JsonEnum(valueField: 'json')
enum ClubPattern {
  /// Nokta ızgarası.
  dots('dots'),

  /// Çizgi.
  lines('lines'),

  /// Dağ silüeti.
  mountain('mountain'),

  /// Dalga.
  waves('waves');

  const ClubPattern(this.json);

  /// Firestore'daki dizgi karşılığı.
  final String json;

  /// Firestore dizgisinden değer üretir.
  ///
  /// Eşleşme birebirdir (büyük/küçük harf ve boşluk duyarlı). Bilinmeyen
  /// değer [ArgumentError] fırlatır; bu enum'da `unknown` üyesi yoktur
  /// (model ayrıştırmasında `CheckedFromJsonException` →
  /// `FirestoreError.parse`).
  static ClubPattern fromJson(String json) =>
      values.firstWhereOrNull((value) => value.json == json) ??
      (throw ArgumentError.value(
        json,
        'json',
        'ClubPattern: bilinmeyen değer',
      ));
}
