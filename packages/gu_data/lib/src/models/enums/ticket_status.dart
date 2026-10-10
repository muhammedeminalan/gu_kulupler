import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';

/// Destek talebi durumu (`supportTickets.status`; PLAN §9.7,
/// domain-model §2.15).
///
/// Yalnızca destek talebi içindir; etkinlik bileti rozeti `TicketState`'tir.
@JsonEnum(valueField: 'json')
enum TicketStatus {
  /// Açık.
  open('open'),

  /// Kapatıldı.
  closed('closed');

  const TicketStatus(this.json);

  /// Firestore'daki dizgi karşılığı.
  final String json;

  /// Firestore dizgisinden değer üretir.
  ///
  /// Eşleşme birebirdir (büyük/küçük harf ve boşluk duyarlı). Bilinmeyen
  /// değer [ArgumentError] fırlatır; bu enum'da `unknown` üyesi yoktur
  /// (model ayrıştırmasında `CheckedFromJsonException` →
  /// `FirestoreError.parse`).
  static TicketStatus fromJson(String json) =>
      values.firstWhereOrNull((value) => value.json == json) ??
      (throw ArgumentError.value(
        json,
        'json',
        'TicketStatus: bilinmeyen değer',
      ));
}
