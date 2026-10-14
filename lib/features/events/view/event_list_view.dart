import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/events/provider/event_list_state.dart';
import 'package:gu_kulupler/features/events/provider/event_list_view_model.dart';
import 'package:gu_kulupler/features/events/view/mixin/event_list_view_mixin.dart';
import 'package:gu_kulupler/features/events/view/widget/event_calendar_section.dart';
import 'package:gu_kulupler/features/events/view/widget/event_list_section.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/media/post_image_resolver.dart';
import 'package:gu_kulupler/product/widget/event/event_card.dart';
import 'package:gu_kulupler/product/widget/event/event_card_status.dart';
import 'package:gu_kulupler/product/widget/event/event_cta.dart';
import 'package:gu_ui/gu_ui.dart';

/// "Etkinlikler" ekranı — Etkinlikler sekmesinin kökü, `EventsRoute`
/// (`/events`); prototip `Events` (`screens-events.js:17–33`).
///
/// Büyük başlık çubuğu ("Biletlerim" + ara) altında sabit bölümler: liste ↔
/// takvim dilimi (`px16 pb16`) ve — liste kipinde — hızlı çipler (Tümü /
/// Bugün / Bu hafta / Kulüplerim / Herkese açık) + "Filtre" (etkin süzgeç
/// rozeti). Altında çek-yenilemeli tek kaydırma alanı:
///
/// * **Liste:** gün grupları (`EventListSection`: Bugün / Yarın / Bu hafta /
///   Daha sonra / Geçmiş; yapışkan başlık + sayı) · liste sonu satırı.
/// * **Takvim:** `EventCalendarSection` (ay takvimi + seçili günün sıkışık
///   kartları; süzgeç / çipten bağımsız — prototip `visibleEvents`).
///
/// Durumlar yalnızca kaydırma alanını değiştirir (sıra: hata → yükleniyor →
/// boş → dolu). Hata: "Bir şeyler ters gitti" + "Yeniden dene";
/// yükleniyor: 4 kart iskeleti; boş: "Bu aralıkta etkinlik yok" (+ süzgeç ya
/// da çip seçiliyse "Filtreleri temizle"). Çevrimdışı bandı kökte çizilir;
/// liste önbellekteki veriyle kalır, katılım TST-24 verir.
///
/// Kart durumu ve hızlı eylemi `EventCardStatus.of` / `EventCtaKind.of`
/// ile katılım kayıtlarından türetilir (W-81: bekleme kararı
/// `joinsWaitlist`); kapak görseli `storageImageResolverProvider`'dan.
/// Davranış `EventListViewMixin`'dedir.
///
/// Design: EVT-01
class EventListView extends ConsumerStatefulWidget {
  /// Etkinlikler sekme kökü.
  const EventListView({super.key});

  @override
  ConsumerState<EventListView> createState() => _EventListViewState();
}

class _EventListViewState extends ConsumerState<EventListView>
    with EventListViewMixin {
  static String _chipLabel(AppLocalizations l10n, EventListChip chip) =>
      switch (chip) {
        EventListChip.all => l10n.commonAll,
        EventListChip.today => l10n.timeToday,
        EventListChip.week => l10n.eventsChipWeek,
        EventListChip.mine => l10n.eventsChipMine,
        EventListChip.public => l10n.eventsChipPublic,
      };

  /// Tek etkinliğin kartı (liste: kapaklı; takvim: [compact]).
  Widget _card(
    EventListState state,
    EventModel event, {
    required DateTime nowUtc,
    required bool superAdmin,
    required StorageImageResolver coverOf,
    bool compact = false,
  }) {
    final status = EventCardStatus.of(
      event: event,
      rsvp: state.rsvps[event.id],
      canSeeInside: superAdmin || state.memberClubIds.contains(event.clubId),
      nowUtc: nowUtc,
    );
    final kind = EventCtaKind.of(status: status, event: event);
    return EventCard(
      event: event,
      club: state.clubById(event.clubId),
      status: status,
      registeredCount: event.goingCount,
      compact: compact,
      coverImage: compact ? null : coverOf(event.coverPath),
      quickAction: kind == null
          ? null
          : EventQuickAction(
              kind: kind,
              onPressed: () => onQuickAction(event, kind),
              actionKey: GuKey.action('EVT-01.join.${event.id}'),
            ),
      actionKey: GuKey.action('EVT-01.card.${event.id}'),
      clubKey: GuKey.action('EVT-01.club.${event.id}'),
      onOpen: () => openEvent(event),
      onClub: () => openClub(event.clubId),
    );
  }

  /// Liste kipinin üst bölümü: hızlı çipler + "Filtre" (`.hscroll pb16`;
  /// dikey dolgu 3 px — K-59, referansta ölçüldü).
  Widget _chips(AppLocalizations l10n, EventListState state) =>
      GuHorizontalList(
        children: [
          for (final chip in EventListChip.values)
            GuChip(
              key: GuKey.action('EVT-01.chip.${chip.name}'),
              label: _chipLabel(l10n, chip),
              selected: state.chip == chip,
              onTap: () => selectChip(chip),
            ),
          GuChip(
            key: GuKey.action('EVT-01.filter'),
            label: l10n.commonFilter,
            icon: GuIcons.slidersHorizontal,
            count: state.activeFilterCount > 0 ? state.activeFilterCount : null,
            onTap: openFilters,
          ),
        ],
      );

  List<Widget> _listSlivers(
    AppLocalizations l10n,
    EventListState state,
    AppClock clock,
    Widget Function(BuildContext, EventModel) cardBuilder,
  ) {
    final visible = state.visibleAt(clock);
    final status = GuListStatus.resolve(
      isError: state.isError,
      isLoading: state.isFetching,
      isEmpty: visible.isEmpty,
    );
    return switch (status) {
      GuListStatus.error => [_errorSliver(l10n)],
      GuListStatus.loading => [
        SliverToBoxAdapter(
          // Varsayılan 4 kart = prototip `ListState n=4`
          // (`screens-events.js:29`).
          child: GuSkeletonList(
            semanticLabel: l10n.commonLoading,
            variant: GuSkeletonVariant.card,
          ),
        ),
      ],
      GuListStatus.empty => [
        SliverToBoxAdapter(
          child: GuEmptyState(
            illustration: GuIllustrations.emptyEvents,
            title: l10n.eventsEmptyTitle,
            description: l10n.eventsEmptyDesc,
            ctaLabel: state.hasActiveFilter ? l10n.clubsEmptyClear : null,
            ctaActionKey: GuKey.action('EVT-01.clearFilters'),
            onCta: state.hasActiveFilter ? clearFilters : null,
          ),
        ),
      ],
      GuListStatus.data => [
        for (final (group, events) in EventListSection.groupsOf(
          visible,
          clock: clock,
        ))
          EventListSection(
            key: ValueKey<EventListGroup>(group),
            group: group,
            events: events,
            cardBuilder: cardBuilder,
          ),
        SliverToBoxAdapter(child: GuListEnd(label: l10n.commonAllDone)),
      ],
    };
  }

  Widget _errorSliver(AppLocalizations l10n) => SliverToBoxAdapter(
    child: GuErrorState(
      title: l10n.sysErrorTitle,
      description: l10n.sysErrorDesc,
      retryLabel: l10n.commonRetry,
      retryActionKey: GuKey.action('EVT-01.retry'),
      inline: true,
      onRetry: retry,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(eventListViewModelProvider);
    final superAdmin = ref.watch(
      sessionViewModelProvider.select((session) => session.isSuperAdmin),
    );
    final clock = ref.watch(appClockProvider);
    final coverOf = ref.watch(storageImageResolverProvider);
    final nowUtc = clock.nowUtc();
    final today = EventListState.istanbulCalendarDay(nowUtc);
    final listMode = state.mode == EventListMode.list;

    Widget card(BuildContext _, EventModel event) => _card(
      state,
      event,
      nowUtc: nowUtc,
      superAdmin: superAdmin,
      coverOf: coverOf,
    );

    Widget compactCard(BuildContext _, EventModel event) => _card(
      state,
      event,
      nowUtc: nowUtc,
      superAdmin: superAdmin,
      coverOf: coverOf,
      compact: true,
    );

    return Scaffold(
      backgroundColor: context.gu.colors.bgCanvas,
      appBar: GuAppBar(
        large: true,
        title: l10n.navEvents,
        actions: [
          GuIconButton(
            key: GuKey.action('EVT-01.tickets'),
            icon: GuIcons.ticket,
            semanticLabel: l10n.eventsTickets,
            onPressed: openMyEvents,
          ),
          GuIconButton(
            key: GuKey.action('EVT-01.search'),
            icon: GuIcons.search,
            semanticLabel: l10n.commonSearch,
            onPressed: openSearch,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: GuInsets.only(
              left: GuSpacing.s16,
              right: GuSpacing.s16,
              bottom: GuSpacing.s16,
            ),
            child: GuSegmented(
              options: [
                GuSegmentOption(
                  id: EventListMode.list.name,
                  label: l10n.eventsViewList,
                  icon: GuIcons.list,
                ),
                GuSegmentOption(
                  id: EventListMode.calendar.name,
                  label: l10n.eventsViewCalendar,
                  icon: GuIcons.calendarDays,
                ),
              ],
              value: state.mode.name,
              optionKeyBuilder: (index) => GuKey.action(
                'EVT-01.view.${EventListMode.values[index].name}',
              ),
              onChanged: selectMode,
            ),
          ),
          if (listMode) _chips(l10n, state),
          Expanded(
            child: GuRefresh(
              onRefresh: refresh,
              refreshActionKey: GuKey.action('EVT-01.refresh'),
              child: CustomScrollView(
                controller: scrollController,
                slivers: [
                  if (listMode)
                    ..._listSlivers(l10n, state, clock, card)
                  else if (state.isError)
                    _errorSliver(l10n)
                  else
                    SliverToBoxAdapter(
                      child: EventCalendarSection(
                        events: state.events,
                        month:
                            state.calendarMonth ??
                            DateTime(today.year, today.month),
                        selectedDay: state.selectedDay ?? today,
                        today: today,
                        onSelectDay: viewModel.selectDay,
                        onMonthChanged: viewModel.setMonth,
                        cardBuilder: compactCard,
                      ),
                    ),
                  const SliverSafeArea(
                    top: false,
                    sliver: SliverToBoxAdapter(child: SizedBox.shrink()),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
