import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';

/// Etkinlik görünürlüğü (`events.visibility`; PLAN §9.7, domain-model §2.7).
@JsonEnum(valueField: 'json')
enum EventVisibility {
  /// Herkese açık.
  public('public'),

  /// Yalnızca kulüp üyelerine açık.
  membersOnly('members');

  const EventVisibility(this.json);

  /// Firestore'daki dizgi karşılığı.
  final String json;

  /// Firestore dizgisinden değer üretir.
  ///
  /// Eşleşme birebirdir (büyük/küçük harf ve boşluk duyarlı). Bilinmeyen
  /// değer [ArgumentError] fırlatır; bu enum'da `unknown` üyesi yoktur
  /// (model ayrıştırmasında `CheckedFromJsonException` →
  /// `FirestoreError.parse`).
  static EventVisibility fromJson(String json) =>
      values.firstWhereOrNull((value) => value.json == json) ??
      (throw ArgumentError.value(
        json,
        'json',
        'EventVisibility: bilinmeyen değer',
      ));
}
