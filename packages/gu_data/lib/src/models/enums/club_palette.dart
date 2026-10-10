import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';

/// Kulüp kapak paleti (`clubs.palette`; PLAN §9.7, domain-model §2.3;
/// `design/extracted/registry.json#palettes`).
@JsonEnum(valueField: 'json')
enum ClubPalette {
  /// Kırmızı.
  red('red'),

  /// Arduvaz.
  slate('slate'),

  /// Bordo.
  bordeaux('bordeaux');

  const ClubPalette(this.json);

  /// Firestore'daki dizgi karşılığı.
  final String json;

  /// Firestore dizgisinden değer üretir.
  ///
  /// Eşleşme birebirdir (büyük/küçük harf ve boşluk duyarlı). Bilinmeyen
  /// değer [ArgumentError] fırlatır; bu enum'da `unknown` üyesi yoktur
  /// (model ayrıştırmasında `CheckedFromJsonException` →
  /// `FirestoreError.parse`).
  static ClubPalette fromJson(String json) =>
      values.firstWhereOrNull((value) => value.json == json) ??
      (throw ArgumentError.value(
        json,
        'json',
        'ClubPalette: bilinmeyen değer',
      ));
}
