import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';

/// Etkinlik türü (`events.type`; PLAN §9.7, domain-model §2.7).
///
/// Bildirim sırası `design/extracted/registry.json#eventTypes` sırasıdır. JSON
/// değerleri şemadaki Türkçe kodlardır; Dart adları İngilizcedir (D-02).
@JsonEnum(valueField: 'json')
enum EventType {
  /// Eğitim.
  training('egitim'),

  /// Sosyal etkinlik.
  social('sosyal'),

  /// Gezi.
  trip('gezi'),

  /// Yarışma.
  competition('yarisma'),

  /// Konferans.
  conference('konferans');

  const EventType(this.json);

  /// Firestore'daki dizgi karşılığı.
  final String json;

  /// Firestore dizgisinden değer üretir.
  ///
  /// Eşleşme birebirdir (büyük/küçük harf ve boşluk duyarlı). Bilinmeyen
  /// değer [ArgumentError] fırlatır; bu enum'da `unknown` üyesi yoktur
  /// (model ayrıştırmasında `CheckedFromJsonException` →
  /// `FirestoreError.parse`).
  static EventType fromJson(String json) =>
      values.firstWhereOrNull((value) => value.json == json) ??
      (throw ArgumentError.value(json, 'json', 'EventType: bilinmeyen değer'));
}
