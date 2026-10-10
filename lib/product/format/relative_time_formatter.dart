import 'dart:ui' show Locale;

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/format/app_date_formats.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';

/// Göreli zaman, gün etiketi, geri sayım ve süre metinleri (PLAN §14.7;
/// CD-106(c), CD-114). Metinler ARB'den, "şu an" [AppClock]'tan gelir
/// (`DateTime.now()` yok); gün sınırları Istanbul gününe göredir.
final class RelativeTimeFormatter {
  /// [_l10n] etkin dilin metinleri, [_clock] saat kaynağıdır.
  RelativeTimeFormatter(this._l10n, this._clock)
    : _formats = AppDateFormats(Locale(_l10n.localeName), _clock);

  final AppLocalizations _l10n;
  final AppClock _clock;
  final AppDateFormats _formats;

  /// Geçmiş bir anın göreli metni — 7 eşik (prototip `fmt.rel`):
  /// `< 1 dk` "Az önce" · `< 60 dk` "12 dk önce" · `< 24 sa` "2 saat önce" ·
  /// `1 gün` "Dün" · `< 7 gün` "3 gün önce" · `< 30 gün` "2 hafta önce" ·
  /// sonrası kısa tarih ("12 Eki"). Gelecekteki an "Az önce" sayılır.
  String format(DateTime instant) {
    final elapsed = _clock.nowUtc().difference(instant.toUtc());
    final minutes = (elapsed.inMilliseconds / Duration.millisecondsPerMinute)
        .round();
    if (minutes < 1) return _l10n.timeJustNow;
    if (minutes < Duration.minutesPerHour) {
      return _l10n.timeMinutesAgo(minutes);
    }
    final hours = (minutes / Duration.minutesPerHour).round();
    if (hours < Duration.hoursPerDay) return _l10n.timeHoursAgo(hours);
    final days = (hours / Duration.hoursPerDay).round();
    if (days == 1) return _l10n.timeYesterday;
    if (days < DateTime.daysPerWeek) return _l10n.timeDaysAgo(days);
    if (days < _monthDays) {
      return _l10n.timeWeeksAgo(days ~/ DateTime.daysPerWeek);
    }
    return _formats.dateShort(instant);
  }

  /// Gün etiketi: "Bugün" / "Yarın" / "Dün", diğer günlerde uzun tarih
  /// ("12 Ekim Pazartesi").
  String dayLabel(DateTime instant) => switch (_dayDiff(instant)) {
    0 => _l10n.timeToday,
    1 => _l10n.timeTomorrow,
    -1 => _l10n.timeYesterday,
    _ => _formats.dateLong(instant),
  };

  /// Gün etiketi + saat: "Bugün 19:30" (ARB `timeDayAt`; K-14).
  String dayTime(DateTime instant) =>
      _l10n.timeDayAt(dayLabel(instant), _formats.time(instant));

  /// Hedef ana kalan gün ("3 gün", "bugün"): yukarı yuvarlanır, geçmiş hedef
  /// `0` sayılır (ARB `timeInDays`).
  String countdown(DateTime instant) {
    final remaining = instant.toUtc().difference(_clock.nowUtc());
    final days = (remaining.inMilliseconds / Duration.millisecondsPerDay)
        .ceil();
    return _l10n.timeInDays(days < 0 ? 0 : days);
  }

  /// İki an arasındaki süre: 60 dakikadan kısaysa "45 dk", değilse bir
  /// ondalık basamağa yuvarlanmış saat ("1 sa", "1.5 sa").
  String duration(DateTime start, DateTime end) {
    final minutes =
        (end.difference(start).inMilliseconds / Duration.millisecondsPerMinute)
            .round();
    if (minutes < Duration.minutesPerHour) return _l10n.timeMinutes(minutes);
    final tenths = (minutes / Duration.minutesPerHour * _tenth).round();
    // Tam saat tam sayı olarak verilir: "2 sa" ("2.0 sa" değil).
    return _l10n.timeHours(
      tenths % _tenth == 0 ? tenths ~/ _tenth : tenths / _tenth,
    );
  }

  /// [instant] gününün bugüne (Istanbul) göre gün farkı; yarın `1`, dün `-1`.
  int _dayDiff(DateTime instant) => _clock
      .istanbulStartOfDay(instant)
      .difference(_clock.istanbulStartOfDay(_clock.nowUtc()))
      .inDays;

  /// Haftalık göreli metnin üst sınırı; sonrası tarih gösterilir.
  static const int _monthDays = 30;

  /// Bir ondalık basamak çarpanı.
  static const int _tenth = 10;
}
