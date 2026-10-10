import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';

/// Etkinlik hatırlatıcı seçeneği (`rsvps.reminder`, `settings.reminderTime`;
/// PLAN §9.7, CD-34).
///
/// Projenin **tek** hatırlatıcı enum'udur. `rsvps.reminder` dört değeri de
/// taşır (SHT-13); `settings.reminderTime` yalnızca [oneHour] ve [oneDay]
/// kabul eder.
@JsonEnum(valueField: 'json')
enum ReminderOption {
  /// Hatırlatıcı yok.
  none('none'),

  /// Başlangıçtan 15 dakika önce.
  fifteenMinutes('15m'),

  /// Başlangıçtan 1 saat önce.
  oneHour('1h'),

  /// Başlangıçtan 1 gün önce.
  oneDay('1d');

  const ReminderOption(this.json);

  /// Firestore'daki dizgi karşılığı.
  final String json;

  /// Firestore dizgisinden değer üretir.
  ///
  /// Eşleşme birebirdir (büyük/küçük harf ve boşluk duyarlı). Bilinmeyen
  /// değer [ArgumentError] fırlatır; bu enum'da `unknown` üyesi yoktur
  /// (model ayrıştırmasında `CheckedFromJsonException` →
  /// `FirestoreError.parse`).
  static ReminderOption fromJson(String json) =>
      values.firstWhereOrNull((value) => value.json == json) ??
      (throw ArgumentError.value(
        json,
        'json',
        'ReminderOption: bilinmeyen değer',
      ));
}
