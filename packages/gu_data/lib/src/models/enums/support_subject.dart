import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';

/// Destek talebi konusu (`supportTickets.subject`; PLAN §9.7,
/// domain-model §2.15).
@JsonEnum(valueField: 'json')
enum SupportSubject {
  /// Hata bildirimi.
  bug('bug'),

  /// Öneri.
  suggestion('suggestion'),

  /// Hesap.
  account('account'),

  /// Kulüp.
  club('club'),

  /// Diğer.
  other('other');

  const SupportSubject(this.json);

  /// Firestore'daki dizgi karşılığı.
  final String json;

  /// Firestore dizgisinden değer üretir.
  ///
  /// Eşleşme birebirdir (büyük/küçük harf ve boşluk duyarlı). Bilinmeyen
  /// değer [ArgumentError] fırlatır; bu enum'da `unknown` üyesi yoktur
  /// (model ayrıştırmasında `CheckedFromJsonException` →
  /// `FirestoreError.parse`).
  static SupportSubject fromJson(String json) =>
      values.firstWhereOrNull((value) => value.json == json) ??
      (throw ArgumentError.value(
        json,
        'json',
        'SupportSubject: bilinmeyen değer',
      ));
}
