import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

/// Firestore `Timestamp` ↔ UTC [DateTime] dönüştürücüsü, null olabilen alanlar
/// için (PLAN §9.3, D-26).
///
/// Sunucu zamanı alanlarında (`createdAt`, `updatedAt`, `deletedAt` …)
/// kullanılır: bekleyen yazımda değer henüz `null` gelebilir.
///
/// `fromJson` şunları kabul eder: `null`; `Timestamp`; [DateTime] (UTC'ye
/// çevrilir); ISO-8601 dizgisi (seed verisi ve fixture'lar). Saat dilimi
/// belirtilmemiş dizgi UTC sayılır — sonuç cihazın saat diliminden bağımsızdır.
/// Başka her tip [FormatException] fırlatır. Dönen her [DateTime] UTC'dir
/// (`isUtc == true`).
final class TimestampConverter implements JsonConverter<DateTime?, Object?> {
  /// Alan açıklaması olarak kullanılır: `@TimestampConverter()`.
  const TimestampConverter();

  @override
  DateTime? fromJson(Object? json) =>
      json == null ? null : _toUtcDateTime(json, 'TimestampConverter');

  @override
  Object? toJson(DateTime? object) =>
      object == null ? null : Timestamp.fromDate(object.toUtc());
}

/// Firestore `Timestamp` ↔ UTC [DateTime] dönüştürücüsü, zorunlu alanlar için
/// (PLAN §9.3).
///
/// İstemcinin kendi girdiği zamanlarda (`startsAt`, `endsAt`, `poll.endsAt`)
/// kullanılır. Kabul ettiği tipler [TimestampConverter] ile aynıdır; `null`
/// kabul etmez (üretilen `fromJson` eksik alanı `CheckedFromJsonException`
/// olarak alan adıyla bildirir).
final class RequiredTimestampConverter
    implements JsonConverter<DateTime, Object> {
  /// Alan açıklaması olarak kullanılır: `@RequiredTimestampConverter()`.
  const RequiredTimestampConverter();

  @override
  DateTime fromJson(Object json) =>
      _toUtcDateTime(json, 'RequiredTimestampConverter');

  @override
  Object toJson(DateTime object) => Timestamp.fromDate(object.toUtc());
}

/// [value] değerini UTC [DateTime]'a çevirir; desteklenmeyen tipte
/// `'<converter>: <runtimeType>'` mesajlı [FormatException] fırlatır.
DateTime _toUtcDateTime(Object value, String converter) => switch (value) {
  Timestamp() => value.toDate().toUtc(),
  DateTime() => value.toUtc(),
  String() => _parseIsoUtc(value),
  _ => throw FormatException('$converter: ${value.runtimeType}'),
};

/// ISO-8601 dizgisini UTC ana çevirir.
///
/// `Z` ya da `±HH:mm` taşıyan dizgi o ana karşılık gelir. Saat dilimi
/// taşımayan dizgi (`2026-10-08T20:15:01`, `2026-10-08`) **UTC** olarak
/// okunur: [DateTime.parse] böyle bir dizgiyi cihazın yerel saatiyle
/// yorumladığı için dizgi, yerel saate hiç uğramadan açık `Z` ile yeniden
/// ayrıştırılır.
DateTime _parseIsoUtc(String value) {
  final parsed = DateTime.parse(value);
  if (parsed.isUtc) return parsed;
  final hasTime = value.contains('T') || value.contains(' ');
  return DateTime.parse(hasTime ? '${value}Z' : '${value}T00:00:00Z');
}
