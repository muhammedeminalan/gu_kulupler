import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';

/// Etkinlik durumu (`events.status`; PLAN §9.7, domain-model §2.7).
///
/// "Geçmiş" bir üye değildir: `endsAt < now` ile türetilir.
@JsonEnum(valueField: 'json')
enum EventStatus {
  /// Taslak (yalnızca yöneticiler görür).
  draft('draft'),

  /// Yayında.
  published('published'),

  /// İptal edildi.
  cancelled('cancelled');

  const EventStatus(this.json);

  /// Firestore'daki dizgi karşılığı.
  final String json;

  /// Firestore dizgisinden değer üretir.
  ///
  /// Eşleşme birebirdir (büyük/küçük harf ve boşluk duyarlı). Bilinmeyen
  /// değer [ArgumentError] fırlatır; bu enum'da `unknown` üyesi yoktur
  /// (model ayrıştırmasında `CheckedFromJsonException` →
  /// `FirestoreError.parse`).
  static EventStatus fromJson(String json) =>
      values.firstWhereOrNull((value) => value.json == json) ??
      (throw ArgumentError.value(
        json,
        'json',
        'EventStatus: bilinmeyen değer',
      ));
}
