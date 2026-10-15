import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/events/provider/my_events_state.dart';
import 'package:gu_kulupler/features/events/provider/my_events_view_model.dart';
import 'package:gu_kulupler/features/events/view/mixin/my_events_view_mixin.dart';
import 'package:gu_kulupler/features/events/view/widget/my_event_tile.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/widget/event/event_card_status.dart';
import 'package:gu_kulupler/product/widget/system/offline_list_fallback.dart';
import 'package:gu_ui/gu_ui.dart';

/// "Etkinliklerim" ekranı — `MyEventsRoute` (`/events/mine`); prototip
/// `MyEvents` (`screens-events.js:90–95`). EVT-01 "Biletlerim" açar.
///
/// Yukarıdan aşağıya: başlık çubuğu (geri · "Etkinliklerim") · sekmeler
/// ("Yaklaşan" / "Geçmiş" / "Bekleme listesi"; dolgu 0/16/16) · kaydırma
/// alanı (çek-yenile): `MyEventTile` satırları.
///
/// * Satır: tarih rozeti · başlık / "kulüp · saat" / durum rozeti
///   (`EventCardStatus.of` — katılıyorsun, katıldın, gelmedin, iptal …).
///   "Yaklaşan"da bilet + "Vazgeç", "Bekleme listesi"nde "Ayrıl" düğmesi;
///   vazgeçme yalnızca etkinlik bitmeden (W-81 (b)). Bekleme sırası
///   katılımcıya kapalıdır (W-76) — prototipteki "{n}. sıra" yazılmaz.
/// * Durumlar yalnızca listeyi değiştirir (hata → yükleniyor → boş → dolu).
///   Hata: "Bir şeyler ters gitti" + "Yeniden dene"; yükleniyor: 4 satır
///   iskeleti; boş: sekmeye göre başlık + "Etkinlikleri keşfet". Çevrimdışı
///   bandı kökte çizilir; liste önbellekteki veriyle kalır, "Vazgeç" TST-24
///   verir.
/// * Etkinlikler 20'lik sayfalarla okunur; sonraki sayfa okunurken liste
///   sonunda iskelet satırları çizilir.
///
/// Davranış `MyEventsViewModel` ve `MyEventsViewMixin`'dedir.
///
/// Design: EVT-04
class MyEventsView extends ConsumerStatefulWidget {
  /// Kullanıcının etkinlikleri; [tab] ilk açılan sekmedir (`null` →
  /// [MyEventsTab.upcoming]).
  const MyEventsView({this.tab, super.key});

  /// İlk açılan sekme (`?tab=`).
  final MyEventsTab? tab;

  @override
  ConsumerState<MyEventsView> createState() => _MyEventsViewState();
}

class _MyEventsViewState extends ConsumerState<MyEventsView>
    with MyEventsViewMixin {
  /// Sonraki sayfa okunurken liste sonunda çizilen iskelet satırı sayısı.
  static const int _nextPageRows = 2;

  static String _tabLabel(AppLocalizations l10n, MyEventsTab tab) =>
      switch (tab) {
        MyEventsTab.upcoming => l10n.eventUpcoming,
        MyEventsTab.past => l10n.eventPast,
        MyEventsTab.waitlist => l10n.statusWaitlist,
      };

  static Key _tabKey(MyEventsTab tab) => switch (tab) {
    MyEventsTab.upcoming => GuKey.action('EVT-04.tab.upcoming'),
    MyEventsTab.past => GuKey.action('EVT-04.tab.past'),
    MyEventsTab.waitlist => GuKey.action('EVT-04.tab.waitlist'),
  };

  static String _emptyTitle(AppLocalizations l10n, MyEventsTab tab) =>
      switch (tab) {
        MyEventsTab.upcoming => l10n.myeventsEmptyUpcoming,
        MyEventsTab.past => l10n.myeventsEmptyPast,
        MyEventsTab.waitlist => l10n.myeventsEmptyWaitlist,
      };

  Widget _tile(MyEventsState state, MyEventEntry entry, DateTime nowUtc) {
    final l10n = context.l10n;
    final (rsvp, event) = entry;
    final id = event.id;
    final canLeave = MyEventsState.canLeave(rsvp, event, nowUtc);
    final isWaitlist = state.tab == MyEventsTab.waitlist;
    return MyEventTile(
      key: ValueKey<String>(id),
      event: event,
      // Satırda daima etkin kayıt vardır: "üyelere özel" rozeti çıkmaz.
      status: EventCardStatus.of(
        event: event,
        rsvp: rsvp,
        canSeeInside: true,
        nowUtc: nowUtc,
      ),
      clubName: state.clubNames[event.clubId],
      actionKey: GuKey.action('EVT-04.event.$id'),
      onOpen: () => openEvent(id),
      ticketKey: GuKey.action('EVT-04.ticket.$id'),
      onTicket: state.tab == MyEventsTab.upcoming ? () => openTicket(id) : null,
      leaveKey: GuKey.action('EVT-04.leave.$id'),
      leaveLabel: isWaitlist ? l10n.eventCtaLeaveWaitlist : l10n.eventCtaLeave,
      onLeave: canLeave ? () => leave(id) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final state = ref.watch(myEventsViewModelProvider);
    final nowUtc = ref.watch(appClockProvider).nowUtc();
    final visible = state.visibleAt(nowUtc);
    final status = GuListStatus.resolve(
      isError: state.isError,
      isLoading: state.isFetching || (visible.isEmpty && state.isLoadingMore),
      isEmpty: visible.isEmpty,
    );

    return Scaffold(
      backgroundColor: gu.colors.bgCanvas,
      appBar: GuAppBar(
        title: l10n.myeventsTitle,
        onBack: goBack,
        backSemanticLabel: l10n.a11yBack,
        backActionKey: GuKey.action('EVT-04.back'),
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
                for (final tab in MyEventsTab.values)
                  GuSegmentOption(id: tab.name, label: _tabLabel(l10n, tab)),
              ],
              value: state.tab.name,
              onChanged: (id) => selectTab(MyEventsTab.values.byName(id)),
              optionKeyBuilder: (index) => _tabKey(MyEventsTab.values[index]),
            ),
          ),
          Expanded(
            child: GuRefresh(
              onRefresh: refresh,
              child: CustomScrollView(
                controller: scrollController,
                slivers: [
                  ...switch (status) {
                    _ when OfflineListFallback.applies(ref, status) => [
                      OfflineListFallback.sliver(onReload: retry),
                    ],
                    GuListStatus.error => [
                      SliverToBoxAdapter(
                        child: GuErrorState(
                          title: l10n.sysErrorTitle,
                          description: l10n.sysErrorDesc,
                          retryLabel: l10n.commonRetry,
                          retryActionKey: GuKey.action('EVT-04.retry'),
                          inline: true,
                          onRetry: retry,
                        ),
                      ),
                    ],
                    GuListStatus.loading => [
                      SliverToBoxAdapter(
                        // Prototip `ListState n=4` (varsayılan sayı).
                        child: GuSkeletonList(
                          semanticLabel: l10n.commonLoading,
                        ),
                      ),
                    ],
                    GuListStatus.empty => [
                      SliverToBoxAdapter(
                        child: GuEmptyState(
                          illustration: GuIllustrations.emptyEvents,
                          title: _emptyTitle(l10n, state.tab),
                          ctaLabel: l10n.eventsDiscover,
                          ctaActionKey: GuKey.action('EVT-04.discover'),
                          onCta: discover,
                        ),
                      ),
                    ],
                    GuListStatus.data => [
                      SliverList.builder(
                        itemCount: visible.length,
                        itemBuilder: (_, index) =>
                            _tile(state, visible[index], nowUtc),
                      ),
                      if (state.isLoadingMore)
                        SliverToBoxAdapter(
                          child: GuSkeletonList(
                            semanticLabel: l10n.commonLoading,
                            count: _nextPageRows,
                          ),
                        ),
                    ],
                  },
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
