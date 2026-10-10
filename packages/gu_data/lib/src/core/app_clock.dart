import 'package:gu_data/src/constants/limits.dart';

/// Saat ve Istanbul günü sözleşmesi (PLAN §9.1, §10.3; D-26).
///
/// `gu_data` içinde "şu an" yalnızca bu arayüzden okunur; sistem saati
/// doğrudan çağrılmaz. Tüm anlar **UTC**'dir; "gün" sınırı gerektiren her şey
/// (duyuru sayacı) Europe/Istanbul gününe göredir (UTC+3 sabit, DST yok —
/// domain-model §1.5).
abstract interface class AppClock {
  /// Şu an, UTC (`isUtc == true`).
  DateTime nowUtc();

  /// [utc] anının Istanbul günü, `yyyyMMdd` (sayaç belge ID'si).
  String istanbulDayKey(DateTime utc);

  /// [utc] anının Istanbul günü, `yyyy-MM-dd` (`day` alanı).
  String istanbulDay(DateTime utc);

  /// [utc] anının içinde bulunduğu Istanbul gününün başlangıcı (UTC an).
  DateTime istanbulStartOfDay(DateTime utc);
}

/// Sistem saatini okuyan [AppClock] uygulaması (PLAN §9.1, §10.3).
///
/// Istanbul günü [Limits.istanbulUtcOffset] (UTC+3) sabit kaymasıyla
/// hesaplanır: Türkiye yaz saati uygulamadığı için saat dilimi veritabanına
/// gerek yoktur (domain-model §1.5). Security Rules aynı hesabı
/// `request.time + duration.value(3, 'h')` ile yapar.
///
/// `gu_data` içinde sistem saatinin okunduğu **tek** yer [nowUtc]'tur. Gün
/// hesapları saf fonksiyondur (yalnızca verilen ana bağlıdır); verilen an UTC
/// değilse önce UTC'ye çevrilir, yani sonuç cihazın saat diliminden
/// bağımsızdır.
final class SystemAppClock implements AppClock {
  /// Sistem saatine bağlı saat oluşturur.
  const SystemAppClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();

  @override
  String istanbulDayKey(DateTime utc) {
    final day = _istanbulWallClock(utc);
    return '${_pad(day.year, 4)}${_pad(day.month, 2)}${_pad(day.day, 2)}';
  }

  @override
  String istanbulDay(DateTime utc) {
    final day = _istanbulWallClock(utc);
    return '${_pad(day.year, 4)}-${_pad(day.month, 2)}-${_pad(day.day, 2)}';
  }

  @override
  DateTime istanbulStartOfDay(DateTime utc) {
    final day = _istanbulWallClock(utc);
    return DateTime.utc(
      day.year,
      day.month,
      day.day,
    ).subtract(Limits.istanbulUtcOffset);
  }

  /// [instant] anında Istanbul'da duvar saatinin gösterdiği tarih ve saat.
  ///
  /// Dönen değer UTC işaretlidir ama alanları (yıl, ay, gün …) Istanbul yerel
  /// zamanını taşır; yalnızca takvim alanlarını okumak için kullanılır.
  static DateTime _istanbulWallClock(DateTime instant) =>
      instant.toUtc().add(Limits.istanbulUtcOffset);

  static String _pad(int value, int width) =>
      value.toString().padLeft(width, '0');
}
