import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/format/relative_time_formatter.dart';
import 'package:gu_kulupler/product/widget/calendar/app_calendar.dart';
import 'package:gu_ui/gu_ui.dart';

/// EVT-01 takvim kipi — kart içinde `GuCalendar` (noktalar: günün etkinlik
/// sayısı) + seçili günün başlığı (`fmt.dayLabel`, `t-title-s`) + o günün
/// sıkışık etkinlik kartları ya da "Bu gün için etkinlik yok" boş durumu
/// (prototip `screens-events.js:31–32`).
///
/// * Gün ve ay **takvim günüdür** (yalnızca yıl / ay / gün; Istanbul duvar
///   saati — D-26). Hafta TR'de Pazartesi, EN'de Pazar başlar
///   (`AppCalendar.firstDayOfWeekOf`, `ui.js:141`).
/// * Etkinliğin günü başlangıç anının **Istanbul** günüdür
///   (`AppCalendar.dayOf`): `21:30Z` başlayan etkinlik ertesi günün
///   noktasına ve listesine düşer. Gün listesi başlangıca göre sıralıdır.
/// * Ay ve seçili gün çağıranın durumundadır: oklar [onMonthChanged] ile yeni
///   ayı (ayın 1'i), gün dokunuşu [onSelectDay] ile günü verir; "Bugün"
///   ikisini de [today] ile çağırır. Diğer aydan gün seçmek ayı değiştirmez
///   (prototip).
/// * Kartı çağıran kurar ([cardBuilder]; `EventCard(compact: true)`,
///   anahtarlar `EVT-01.card.<id>` …). Takvim anahtarları `EVT-01.prevMonth`
///   / `.nextMonth` / `.today` / `.day.<yyyy-mm-dd>` (CD-111).
/// * Kaydırmaz: `px16 col gap16` sütunudur, ekranın kaydırıcısı içinde
///   çizilir.
class EventCalendarSection extends ConsumerWidget {
  /// [month] ayını, [selectedDay] gününü gösteren takvim bölümü.
  const EventCalendarSection({
    required this.events,
    required this.month,
    required this.selectedDay,
    required this.today,
    required this.onSelectDay,
    required this.onMonthChanged,
    required this.cardBuilder,
    super.key,
  });

  /// Noktaların ve gün listesinin kaynağı (görünür etkinlikler; liste
  /// kipinin çip / süzgecinden bağımsız — prototip `visibleEvents`).
  final List<EventModel> events;

  /// Gösterilen ay (takvim günü; yalnızca yıl + ay okunur).
  final DateTime month;

  /// Seçili gün (takvim günü).
  final DateTime selectedDay;

  /// Bugün (Istanbul takvim günü, `AppClock`'tan).
  final DateTime today;

  /// Gün seçimi (takvim günü).
  final ValueChanged<DateTime> onSelectDay;

  /// Ay değişimi (yeni ayın 1'i, takvim günü).
  final ValueChanged<DateTime> onMonthChanged;

  /// Seçili günün tek etkinlik kartı.
  final Widget Function(BuildContext context, EventModel event) cardBuilder;

  /// Istanbul takvim günü başına etkinlik sayısı (`yyyy-mm-dd` →
  /// sayı; prototip `dots(k)`).
  static Map<String, int> countsByDay(Iterable<EventModel> events) {
    final counts = <String, int>{};
    for (final event in events) {
      final key = GuCalendar.dayKey(AppCalendar.dayOf(event.startsAt));
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  /// [day] Istanbul gününde başlayan etkinlikler, başlangıca göre (eşitlikte
  /// girdi sırası korunur; prototip `dayList`).
  static List<EventModel> eventsOn(Iterable<EventModel> events, DateTime day) {
    final key = GuCalendar.dayKey(day);
    final indexed =
        [
          for (final (index, event) in events.indexed)
            if (GuCalendar.dayKey(AppCalendar.dayOf(event.startsAt)) == key)
              (index, event),
        ]..sort((a, b) {
          final byStart = a.$2.startsAt.compareTo(b.$2.startsAt);
          return byStart != 0 ? byStart : a.$1 - b.$1;
        });
    return [for (final (_, event) in indexed) event];
  }

  void _shiftMonth(int by) =>
      onMonthChanged(DateTime(month.year, month.month + by));

  void _goToday() {
    onMonthChanged(DateTime(today.year, today.month));
    onSelectDay(AppCalendar.dateOnly(today));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gu = context.gu;
    final l10n = context.l10n;
    final clock = ref.watch(appClockProvider);
    final counts = countsByDay(events);
    final dayEvents = eventsOn(events, selectedDay);
    return Padding(
      padding: GuInsets.h16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: GuSpacing.s16,
        children: [
          GuCard(
            padding: GuCard.bodyPadding,
            child: AppCalendar(
              month: month,
              today: today,
              selected: selectedDay,
              onSelect: onSelectDay,
              onPrev: () => _shiftMonth(-1),
              onNext: () => _shiftMonth(1),
              onToday: _goToday,
              dotsFor: (day) => counts[GuCalendar.dayKey(day)] ?? 0,
              prevKey: GuKey.action('EVT-01.prevMonth'),
              nextKey: GuKey.action('EVT-01.nextMonth'),
              todayKey: GuKey.action('EVT-01.today'),
              dayKeyBuilder: (day) =>
                  GuKey.action('EVT-01.day.${GuCalendar.dayKey(day)}'),
            ),
          ),
          // `h2.t-title-s` (`screens-events.js:32`).
          Semantics(
            header: true,
            child: Text(
              RelativeTimeFormatter(
                l10n,
                clock,
              ).dayLabel(AppCalendar.instantOf(selectedDay)),
              style: gu.text.titleS,
            ),
          ),
          if (dayEvents.isEmpty)
            GuEmptyState(
              illustration: GuIllustrations.emptyEvents,
              title: l10n.eventsEmptyDay,
              compact: true,
            )
          else
            for (final event in dayEvents) cardBuilder(context, event),
        ],
      ),
    );
  }
}
