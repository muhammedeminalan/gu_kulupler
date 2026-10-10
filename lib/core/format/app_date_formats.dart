import 'dart:ui' show Locale;

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

/// Tarih / saat / sayı biçimleri (PLAN §14.7; D-26, CD-56, CD-101, CD-114).
///
/// - **Girdi her zaman bir andır** (Firestore `Timestamp` → `DateTime`);
///   gösterim Istanbul duvar saatiyledir ([toIstanbul]: UTC+3 sabit, DST yok).
///   Cihazın saat dilimi sonucu etkilemez.
/// - Yerel ayar: `tr` → `tr_TR`, `en` → `en_GB` ([intlLocale]) — gün-ay
///   sırası ve 24 saat İngiliz biçimi (prototip `Intl.DateTimeFormat`).
/// - Yalnızca `intl` kalıpları kullanılır. Sözcük içeren birleşimler
///   ([dateTime], [range]) ARB yer tutuculu anahtarla kurulur; `AppLocalizations`
///   parametre olarak gelir. Göreli zaman ve süre `RelativeTimeFormatter`'dadır.
/// - `initializeDateFormatting('tr_TR' / 'en_GB')` açılışta çağrılmış
///   olmalıdır (`AppBootstrap`).
final class AppDateFormats {
  /// [locale] uygulama dilidir; [_clock] aynı gün denetimi içindir.
  AppDateFormats(Locale locale, this._clock) : _loc = intlLocale(locale);

  final AppClock _clock;
  final String _loc;

  /// Uygulama dilinin `intl` yerel ayarı: `en` → `en_GB`, diğer her şey
  /// `tr_TR` (varsayılan dil).
  static String intlLocale(Locale locale) =>
      locale.languageCode == 'en' ? 'en_GB' : 'tr_TR';

  /// [instant] anında Istanbul'da duvar saatinin gösterdiği tarih-saat.
  /// Dönen değer UTC işaretlidir; yalnızca takvim alanları okunur.
  static DateTime toIstanbul(DateTime instant) =>
      instant.toUtc().add(Limits.istanbulUtcOffset);

  /// Takvim başlığı gün kısaltmaları, Pazartesi'den başlayarak 7 öğe
  /// (`Pz Sa Ça Pe Cu Cm Pa` / `Mo Tu We Th Fr Sa Su`).
  static List<String> weekdayInitials(Locale locale) {
    final format = DateFormat.E(intlLocale(locale));
    return [
      for (var day = 0; day < DateTime.daysPerWeek; day++)
        _firstTwo(format.format(_referenceMonday.add(Duration(days: day)))),
    ];
  }

  /// İki haneli sıfır dolgulu sayı (`7` → `07`); saat / dakika tekerleği.
  String twoDigits(int n) => NumberFormat('00', _loc).format(n);

  /// `19:30`.
  String time(DateTime dt) => DateFormat.Hm(_loc).format(toIstanbul(dt));

  /// `12 Eki` / `12 Oct`.
  String dateShort(DateTime dt) => DateFormat.MMMd(_loc).format(toIstanbul(dt));

  /// `12 Ekim 2026` / `12 October 2026`.
  String date(DateTime dt) => DateFormat.yMMMMd(_loc).format(toIstanbul(dt));

  /// `12 Ekim Pazartesi` / `Monday 12 October`.
  String dateLong(DateTime dt) =>
      DateFormat.MMMMEEEEd(_loc).format(toIstanbul(dt));

  /// `12 Eki Pzt, 19:30` / `Mon 12 Oct, 19:30` (ARB `dateTimeAt`).
  String dateTime(AppLocalizations l10n, DateTime dt) => l10n.dateTimeAt(
    DateFormat.MMMEd(_loc).format(toIstanbul(dt)),
    time(dt),
  );

  /// `Ekim 2026` / `October 2026`.
  String monthYear(DateTime dt) =>
      DateFormat.yMMMM(_loc).format(toIstanbul(dt));

  /// `Eki` / `Oct` (kısaltma noktası temizlenir).
  String monthShort(DateTime dt) =>
      DateFormat.MMM(_loc).format(toIstanbul(dt)).replaceAll('.', '');

  /// `Pzt` / `Mon`.
  String weekdayShort(DateTime dt) => DateFormat.E(_loc).format(toIstanbul(dt));

  /// Zaman aralığı: [end] yoksa [time]; aynı Istanbul günüyse `19:30–21:00`
  /// (U+2013); farklı günse `12 Eki Pzt, 19:30 → 13 Eki Sal, 10:00`. Ayraçlar
  /// dilden bağımsız simgelerdir (PLAN §14.7).
  String range(AppLocalizations l10n, DateTime start, DateTime? end) {
    if (end == null) return time(start);
    final sameDay =
        _clock.istanbulStartOfDay(start) == _clock.istanbulStartOfDay(end);
    return sameDay
        ? '${time(start)}–${time(end)}'
        : '${dateTime(l10n, start)} → ${dateTime(l10n, end)}';
  }

  /// Binlik ayraçlı sayı: `1.250` / `1,250`.
  String number(num n) => NumberFormat.decimalPattern(_loc).format(n);

  /// Yüzde, yerel ayara göre: `%62` / `62%` ([value] 0–100 — CD-101).
  String percent(num value) =>
      NumberFormat.percentPattern(_loc).format(value / 100);

  /// Bilinen bir Pazartesi (5 Ocak 2026); yalnızca gün adı üretmek için.
  static final DateTime _referenceMonday = DateTime.utc(2026, 1, 5);

  static String _firstTwo(String text) =>
      text.length <= 2 ? text : text.substring(0, 2);
}
