import 'package:gu_data/gu_data.dart';

/// Elle kurulan ve ilerletilen sahte saat (PLAN §9.1, §10.3).
///
/// "Şu an" yalnızca [advance] ve [set] ile değişir; testler gerçek zamana
/// bağlı kalmaz. Istanbul günü hesapları üretimdeki [SystemAppClock] ile
/// **aynı** koddur (kopya değil, delegasyon) — sahte saat yalnızca "şu an"ı
/// değiştirir, takvim kuralını değil.
final class FakeAppClock implements AppClock {
  /// Saati [nowUtc] anına kurar (UTC değilse aynı anın UTC karşılığına).
  FakeAppClock(DateTime nowUtc) : _nowUtc = nowUtc.toUtc();

  static const SystemAppClock _calendar = SystemAppClock();

  DateTime _nowUtc;

  @override
  DateTime nowUtc() => _nowUtc;

  /// Saati [by] kadar ilerletir (negatif süre geri alır).
  void advance(Duration by) => _nowUtc = _nowUtc.add(by);

  /// Saati [nowUtc] anına kurar (UTC değilse aynı anın UTC karşılığına).
  void set(DateTime nowUtc) => _nowUtc = nowUtc.toUtc();

  @override
  String istanbulDayKey(DateTime utc) => _calendar.istanbulDayKey(utc);

  @override
  String istanbulDay(DateTime utc) => _calendar.istanbulDay(utc);

  @override
  DateTime istanbulStartOfDay(DateTime utc) =>
      _calendar.istanbulStartOfDay(utc);
}
