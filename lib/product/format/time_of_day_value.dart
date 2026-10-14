import 'package:equatable/equatable.dart';

/// Gün içi saat (`HH:mm`, Istanbul duvar saati) — SHT-29 sonucu,
/// `settings.quietFrom` / `quietTo` (`Limits.timeOfDayPattern`) ve MGT-05
/// etkinlik saati.
final class TimeOfDayValue extends Equatable {
  /// [hour] 0–23, [minute] 0–59.
  const TimeOfDayValue(this.hour, this.minute)
    : assert(hour >= 0 && hour < hoursPerDay, 'hour 0–23'),
      assert(minute >= 0 && minute < minutesPerHour, 'minute 0–59');

  /// `HH:mm` dizgesinden; geçersizse `null`.
  static TimeOfDayValue? tryParse(String? value) {
    final match = _pattern.firstMatch(value ?? '');
    if (match == null) return null;
    return TimeOfDayValue(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
    );
  }

  /// Bir gündeki saat sayısı.
  static const int hoursPerDay = 24;

  /// Bir saatteki dakika sayısı.
  static const int minutesPerHour = 60;

  static final RegExp _pattern = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$');

  /// Saat (0–23).
  final int hour;

  /// Dakika (0–59).
  final int minute;

  /// `HH:mm` (sıfır dolgulu; `settings` alan biçimi ve görünen metin).
  String get hhmm => '${pad2(hour)}:${pad2(minute)}';

  /// İki haneli sıfır dolgu (`GU.pad2`).
  static String pad2(int value) => value.toString().padLeft(2, '0');

  @override
  List<Object?> get props => [hour, minute];

  @override
  String toString() => hhmm;
}
