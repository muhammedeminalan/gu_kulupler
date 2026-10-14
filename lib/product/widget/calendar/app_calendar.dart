import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/format/app_date_formats.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_ui/gu_ui.dart';

/// Uygulamanın ay takvimi — `GuCalendar`'ı (gu_ui, yerel ayar bilmez) etkin
/// dilin metinleri ve hafta başlangıcıyla kurar (prototip `Calendar`,
/// `ui.js:140–150`). EVT-01 takvim kipi (`EventCalendarSection`) ve SHT-28
/// (`DatePickerSheet`) kullanır.
///
/// * Hafta başlangıcı dile göredir ([firstDayOfWeekOf]): TR Pazartesi (D-26),
///   EN Pazar (`ui.js:141` `mondayFirst = loc === 'tr'`). Başlık kısaltmaları
///   aynı sırada ([weekdayLabelsOf], `AppDateFormats.weekdayInitials`).
/// * Ay başlığı `AppDateFormats.monthYear` ("Ekim 2026"), gün etiketi
///   `AppDateFormats.date` ("8 Ekim 2026"); "Bugün" `common.today`, oklar
///   `a11y.prevMonth` / `a11y.nextMonth`.
/// * Bütün günler **takvim günüdür** (yalnızca yıl / ay / gün; Istanbul
///   duvar saati — D-26): biçimlendirmeden önce [instantOf] ile o Istanbul
///   gününün başlangıç anına çevrilir, böylece cihaz saat dilimi sonucu
///   değiştirmez. Etkinlik anı → takvim günü: [dayOf].
/// * Anahtarlar çağırandan (CD-111): `<ID>.prevMonth`, `.nextMonth`,
///   `.today`, `.day.<yyyy-mm-dd>` (`GuCalendar.dayKey`).
class AppCalendar extends ConsumerWidget {
  /// [month] ayını gösteren takvim.
  const AppCalendar({
    required this.month,
    required this.today,
    required this.onSelect,
    required this.onPrev,
    required this.onNext,
    this.selected,
    this.onToday,
    this.dotsFor,
    this.min,
    this.max,
    this.compact = false,
    this.prevKey,
    this.nextKey,
    this.todayKey,
    this.dayKeyBuilder,
    super.key,
  });

  /// Gösterilen ay (takvim günü; yalnızca yıl + ay okunur).
  final DateTime month;

  /// Bugün (Istanbul takvim günü — [todayOf]).
  final DateTime today;

  /// Seçili gün; `null` → seçim yok.
  final DateTime? selected;

  /// Gün seçimi (takvim günü); devre dışı günde çağrılmaz.
  final ValueChanged<DateTime> onSelect;

  /// Önceki ay.
  final VoidCallback onPrev;

  /// Sonraki ay.
  final VoidCallback onNext;

  /// "Bugün" düğmesi; `null` → düğme yok.
  final VoidCallback? onToday;

  /// Günün nokta sayısı (≤ `GuSizes.calendarDotsMax` çizilir).
  final int Function(DateTime day)? dotsFor;

  /// Seçilebilir ilk gün (takvim günü).
  final DateTime? min;

  /// Seçilebilir son gün (takvim günü; dahil).
  final DateTime? max;

  /// Sıkışık hücre (SHT-28, en az 36).
  final bool compact;

  /// `<ID>.prevMonth`.
  final Key? prevKey;

  /// `<ID>.nextMonth`.
  final Key? nextKey;

  /// `<ID>.today`.
  final Key? todayKey;

  /// `<ID>.day.<yyyy-mm-dd>`.
  final Key Function(DateTime day)? dayKeyBuilder;

  /// [locale] dilinde haftanın ilk günü: EN Pazar, diğerleri (TR) Pazartesi.
  static int firstDayOfWeekOf(Locale locale) =>
      locale.languageCode == _english ? DateTime.sunday : DateTime.monday;

  /// [locale] dilinin hafta başlığı kısaltmaları, [firstDayOfWeekOf]
  /// sırasında 7 öğe (`Pz Sa … Pa` / `Su Mo … Sa`).
  static List<String> weekdayLabelsOf(Locale locale) {
    final mondayFirst = AppDateFormats.weekdayInitials(locale);
    final offset = firstDayOfWeekOf(locale) - DateTime.monday;
    return [
      for (var index = 0; index < DateTime.daysPerWeek; index++)
        mondayFirst[(offset + index) % DateTime.daysPerWeek],
    ];
  }

  /// [day] takvim gününün Istanbul'daki başlangıç anı (UTC).
  static DateTime instantOf(DateTime day) => DateTime.utc(
    day.year,
    day.month,
    day.day,
  ).subtract(Limits.istanbulUtcOffset);

  /// [instant] anının Istanbul takvim günü (yerel gece yarısı; yalnızca yıl /
  /// ay / gün anlamlıdır).
  static DateTime dayOf(DateTime instant) {
    final wall = AppDateFormats.toIstanbul(instant);
    return DateTime(wall.year, wall.month, wall.day);
  }

  /// [day]'in saatsiz kopyası (yerel gece yarısı) — çağıranın verdiği UTC /
  /// saatli tarih takvimin gün karşılaştırmasıyla aynı düzleme iner.
  static DateTime dateOnly(DateTime day) =>
      DateTime(day.year, day.month, day.day);

  /// [clock]'a göre bugünün Istanbul takvim günü.
  static DateTime todayOf(AppClock clock) => dayOf(clock.nowUtc());

  static const String _english = 'en';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final formats = AppDateFormats(locale, ref.watch(appClockProvider));
    final lower = min;
    final upper = max;
    final picked = selected;
    return GuCalendar(
      month: DateTime(month.year, month.month),
      today: dateOnly(today),
      selected: picked == null ? null : dateOnly(picked),
      onSelect: onSelect,
      monthTitle: formats.monthYear(
        instantOf(DateTime(month.year, month.month)),
      ),
      weekdayLabels: weekdayLabelsOf(locale),
      firstDayOfWeek: firstDayOfWeekOf(locale),
      onPrev: onPrev,
      onNext: onNext,
      onToday: onToday,
      todayLabel: l10n.commonToday,
      prevSemanticLabel: l10n.a11yPrevMonth,
      nextSemanticLabel: l10n.a11yNextMonth,
      daySemanticLabel: (day) => formats.date(instantOf(day)),
      dotsFor: dotsFor,
      min: lower == null ? null : dateOnly(lower),
      max: upper == null ? null : dateOnly(upper),
      compact: compact,
      prevKey: prevKey,
      nextKey: nextKey,
      todayKey: todayKey,
      dayKeyBuilder: dayKeyBuilder,
    );
  }
}
