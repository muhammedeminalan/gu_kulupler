import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';

/// Kulüp durumu (`clubs.status`; PLAN §9.7, domain-model §2.3).
@JsonEnum(valueField: 'json')
enum ClubStatus {
  /// Kulüp etkin.
  active('active'),

  /// Kulüp süper admin tarafından askıya alındı.
  suspended('suspended');

  const ClubStatus(this.json);

  /// Firestore'daki dizgi karşılığı.
  final String json;

  /// Firestore dizgisinden değer üretir.
  ///
  /// Eşleşme birebirdir (büyük/küçük harf ve boşluk duyarlı). Bilinmeyen
  /// değer [ArgumentError] fırlatır; bu enum'da `unknown` üyesi yoktur
  /// (model ayrıştırmasında `CheckedFromJsonException` →
  /// `FirestoreError.parse`).
  static ClubStatus fromJson(String json) =>
      values.firstWhereOrNull((value) => value.json == json) ??
      (throw ArgumentError.value(json, 'json', 'ClubStatus: bilinmeyen değer'));
}
