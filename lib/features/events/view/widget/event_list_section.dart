import 'package:flutter/widgets.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/constants/app_constants.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_ui/gu_ui.dart';

/// EVT-01 liste kipindeki zaman grubu (prototip `groups`,
/// `screens-events.js:22`; ARB `events.group.*`). Sıra tasarımdaki bölüm
/// sırasıdır; boş grup çizilmez.
enum EventListGroup {
  /// "Bugün" — bugünün Istanbul günü.
  today,

  /// "Yarın".
  tomorrow,

  /// "Bu hafta" — yarından sonra, bugünden itibaren 7 gün içinde.
  week,

  /// "Daha sonra".
  later,

  /// "Geçmiş" — başlangıcı bugünden önce (iptal edilmiş / süren).
  past,
}

/// EVT-01 liste bölümü — grup başlığı (`.group-head`: `t-overline` başlık +
/// `t-caption tnum` sayı; yapışkan, css:215) ve altında aralık 12 ile
/// etkinlik kartları (`col gap12 px16 pb16`; `screens-events.js:30`). Widget
/// kataloğu F7: `GuGroupHeader(title, trailingText: sayı)` + `EventCard` × n.
/// Liste sonu (`GuListEnd`) bölümün değil listenin işidir.
///
/// **Sliver döner** (`SliverMainAxisGroup`): `CustomScrollView.slivers`
/// içinde kullanılır; başlık grup sonunda bir sonrakiyle itilir.
///
/// Kartı çağıran kurar ([cardBuilder]): anahtarlar (`EVT-01.card.<id>`,
/// `EVT-01.club.<id>`, `EVT-01.join.<id>`) ve düğme durumu ekrandadır.
class EventListSection extends StatelessWidget {
  /// [group] başlığı altında [events] kartları.
  const EventListSection({
    required this.group,
    required this.events,
    required this.cardBuilder,
    super.key,
  });

  /// Bölümün zaman grubu (başlık metni `events.group.*`).
  final EventListGroup group;

  /// Bölümdeki etkinlikler, gösterim sırasıyla (boş olmamalı).
  final List<EventModel> events;

  /// Tek etkinliğin kartı (`EventCard`; anahtarları çağıran verir).
  final Widget Function(BuildContext context, EventModel event) cardBuilder;

  /// [events] listesini zaman gruplarına ayırır; boş gruplar düşer, grup
  /// içi sıra korunur. "Bugün" [clock]'un Istanbul günüdür; aralıklar yarı
  /// açıktır ve `startsAt`'e uygulanır.
  ///
  /// Prototipte "Bu hafta" `startsAt > bugün + 1 gün` yazar (`screens-events.js:22`)
  /// — yarın 00:00'dan sonra başlayan etkinlik hem "Yarın" hem "Bu hafta"
  /// grubuna düşer. Burada gruplar çakışmaz: "Bu hafta" yarından sonraki
  /// günden (`bugün + 2 gün`) başlar.
  static List<(EventListGroup, List<EventModel>)> groupsOf(
    Iterable<EventModel> events, {
    required AppClock clock,
  }) {
    final today = clock.istanbulStartOfDay(clock.nowUtc());
    final tomorrow = today.add(AppConstants.calendarDay);
    final dayAfter = tomorrow.add(AppConstants.calendarDay);
    final weekEnd = today.add(AppConstants.eventWeekSpan);
    EventListGroup groupOf(DateTime startsAt) {
      if (startsAt.isBefore(today)) return EventListGroup.past;
      if (startsAt.isBefore(tomorrow)) return EventListGroup.today;
      if (startsAt.isBefore(dayAfter)) return EventListGroup.tomorrow;
      if (startsAt.isBefore(weekEnd)) return EventListGroup.week;
      return EventListGroup.later;
    }

    final byGroup = <EventListGroup, List<EventModel>>{};
    for (final event in events) {
      (byGroup[groupOf(event.startsAt)] ??= []).add(event);
    }
    return [
      for (final group in EventListGroup.values)
        if (byGroup[group] case final list?) (group, list),
    ];
  }

  /// [group] başlığının metni (büyük harf çevrimi çizimdedir).
  static String titleOf(AppLocalizations l10n, EventListGroup group) =>
      switch (group) {
        EventListGroup.today => l10n.eventsGroupToday,
        EventListGroup.tomorrow => l10n.eventsGroupTomorrow,
        EventListGroup.week => l10n.eventsGroupWeek,
        EventListGroup.later => l10n.eventsGroupLater,
        EventListGroup.past => l10n.eventsGroupPastGroup,
      };

  @override
  Widget build(BuildContext context) => SliverMainAxisGroup(
    slivers: [
      GuGroupHeader(
        title: titleOf(
          context.l10n,
          group,
        ).upperFor(Localizations.localeOf(context)),
        trailingText: events.length.toString(),
        sticky: true,
      ),
      SliverPadding(
        padding: GuInsets.only(
          left: GuSpacing.s16,
          right: GuSpacing.s16,
          bottom: GuSpacing.s16,
        ),
        sliver: SliverList.separated(
          itemCount: events.length,
          itemBuilder: (context, index) => KeyedSubtree(
            key: ValueKey<String>(events[index].id),
            child: cardBuilder(context, events[index]),
          ),
          separatorBuilder: (_, _) => GuGap.v12,
        ),
      ),
    ],
  );
}
