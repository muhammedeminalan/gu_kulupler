import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/management/provider/manage_events_state.dart';
import 'package:gu_kulupler/features/management/provider/manage_events_view_model.dart';
import 'package:gu_kulupler/features/management/view/mixin/manage_events_view_mixin.dart';
import 'package:gu_kulupler/features/management/view/widget/manage_event_row.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/managed_club_picker_sheet.dart';
import 'package:gu_kulupler/product/navigation/manage_events_tab.dart';
import 'package:gu_kulupler/product/widget/manage/manage_header.dart';
import 'package:gu_ui/gu_ui.dart';

/// Etkinlik yönetimi — `ManageEventsRoute`
/// (`/clubs/:clubId/manage/events?tab=`); prototip `MgtEvents`
/// (`screens-manage.js:77–83`). MGT-01 hızlı eylemi "Etkinlikler" (W-38)
/// açar (guard `V`, router'da); danışman salt okunur görür (bant, FAB yok,
/// yazma eylemleri TST-26).
///
/// Yukarıdan aşağıya: `ManageHeader` (geri · "Etkinlik yönetimi" / kulüp
/// adı · rol rozeti) · danışmanda salt okunur bandı · sekmeler (`.px16.pb16`
/// `Segmented`: Taslak · Yayında · Geçmiş · İptal; varsayılan "Yayında") ·
/// kaydırma alanı (çek-yenile): `ManageEventRow` satırları (dokunuş EVT-02,
/// "⋮" → SHT-23) · "Etkinlik" FAB (`+`, MGT-05).
///
/// Durumlar (sıra: hata → yükleniyor → boş → dolu) yalnızca listeyi
/// değiştirir; boş görünüm sekmenin başlığını taşır (referans
/// `states/MGT-04__empty` — CTA yok, FAB yeterli). Çevrimdışı bandı kökte
/// (kabuk) çizilir; yazan eylemler TST-24 verir.
///
/// Davranış `ManageEventsViewModel` ve `ManageEventsViewMixin`'dedir.
///
/// Design: MGT-04
class ManageEventsView extends ConsumerStatefulWidget {
  /// [clubId] kulübünün etkinlikleri; [tab] ilk açılan sekme.
  const ManageEventsView({required this.clubId, this.tab, super.key});

  /// Kulüp kimliği (`ManageEventsRoute.clubId`).
  final String clubId;

  /// İlk açılan sekme (`ManageEventsRoute.tab`); `null` → yayındakiler.
  final ManageEventsTab? tab;

  @override
  ConsumerState<ManageEventsView> createState() => _ManageEventsViewState();
}

class _ManageEventsViewState extends ConsumerState<ManageEventsView>
    with ManageEventsViewMixin {
  /// Sekmeler, tasarım sırasıyla (`screens-manage.js:81`).
  static const List<ManageEventsTab> _tabs = [
    ManageEventsTab.draft,
    ManageEventsTab.published,
    ManageEventsTab.past,
    ManageEventsTab.cancelled,
  ];

  static final List<Key> _tabKeys = [
    for (final tab in _tabs)
      switch (tab) {
        ManageEventsTab.draft => GuKey.action('MGT-04.tab.draft'),
        ManageEventsTab.published => GuKey.action('MGT-04.tab.published'),
        ManageEventsTab.past => GuKey.action('MGT-04.tab.past'),
        ManageEventsTab.cancelled => GuKey.action('MGT-04.tab.cancelled'),
      },
  ];

  static String _tabLabel(AppLocalizations l10n, ManageEventsTab tab) =>
      switch (tab) {
        ManageEventsTab.draft => l10n.statusDraft,
        ManageEventsTab.published => l10n.statusPublished,
        ManageEventsTab.past => l10n.eventPast,
        ManageEventsTab.cancelled => l10n.statusCancelled,
      };

  static String _emptyTitle(AppLocalizations l10n, ManageEventsTab tab) =>
      switch (tab) {
        ManageEventsTab.draft => l10n.mgtEventsEmptyDraft,
        ManageEventsTab.published => l10n.mgtEventsEmptyPublished,
        ManageEventsTab.past => l10n.mgtEventsEmptyPast,
        ManageEventsTab.cancelled => l10n.mgtEventsEmptyCancelled,
      };

  List<Widget> _slivers(ManageEventsState state, AppLocalizations l10n) {
    final rows = state.visibleAt(ref.watch(appClockProvider).nowUtc());
    final status = GuListStatus.resolve(
      isError: state.isError,
      isLoading: state.isFetching,
      isEmpty: rows.isEmpty,
    );
    switch (status) {
      case GuListStatus.error:
        return [
          SliverToBoxAdapter(
            child: GuErrorState(
              title: l10n.sysErrorTitle,
              description: l10n.sysErrorDesc,
              retryLabel: l10n.commonRetry,
              retryActionKey: GuKey.action('MGT-04.retry'),
              inline: true,
              onRetry: retry,
            ),
          ),
        ];
      case GuListStatus.loading:
        return [
          SliverToBoxAdapter(
            // Varsayılan 4 satır (prototip `ListState n=4`).
            child: GuSkeletonList(semanticLabel: l10n.commonLoading),
          ),
        ];
      case GuListStatus.empty:
        return [
          SliverToBoxAdapter(
            child: GuEmptyState(
              illustration: GuIllustrations.emptyEvents,
              title: _emptyTitle(l10n, state.tab),
            ),
          ),
        ];
      case GuListStatus.data:
        return [
          SliverList.builder(
            itemCount: rows.length,
            itemBuilder: (_, index) {
              final event = rows[index];
              return ManageEventRow(
                key: ValueKey<String>(event.id),
                event: event,
                actionKey: GuKey.action('MGT-04.event.${event.id}'),
                menuKey: GuKey.action('MGT-04.menu.${event.id}'),
                onTap: () => openEvent(event.id),
                onMenu: () => openMenu(event),
              );
            },
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final state = ref.watch(manageEventsViewModelProvider(widget.clubId));
    final canSwitch = ref.watch(
      sessionViewModelProvider.select(
        (session) => ManagedClubPickerSheet.managedOf(session).length > 1,
      ),
    );
    final showFab = !state.isReadOnly;

    return Scaffold(
      backgroundColor: gu.colors.bgCanvas,
      appBar: ManageHeader(
        club: state.club,
        title: l10n.mgtEventsTitle,
        onBack: goBack,
        backKey: GuKey.action('MGT-04.back'),
        role: state.role,
        isSuperAdmin: state.isSuperAdmin,
        onSwitchClub: canSwitch ? switchClub : null,
        switchClubKey: canSwitch ? GuKey.action('MGT-04.switchClub') : null,
      ),
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.isReadOnly)
                GuBanner(
                  kind: GuBannerKind.readonly,
                  text: l10n.mgtReadOnlyBanner,
                ),
              Padding(
                padding: GuInsets.only(
                  left: GuSpacing.s16,
                  right: GuSpacing.s16,
                  bottom: GuSpacing.s16,
                ),
                child: GuSegmented(
                  options: [
                    for (final tab in _tabs)
                      GuSegmentOption(
                        id: tab.name,
                        label: _tabLabel(l10n, tab),
                      ),
                  ],
                  value: state.tab.name,
                  optionKeyBuilder: (index) => _tabKeys[index],
                  onChanged: selectTab,
                ),
              ),
              Expanded(
                child: GuRefresh(
                  onRefresh: refresh,
                  child: CustomScrollView(
                    slivers: [
                      ..._slivers(state, l10n),
                      // FAB son satırın "⋮" düğmesini örtmesin.
                      if (showFab)
                        const SliverToBoxAdapter(
                          child: SizedBox(
                            height: GuSizes.fabHeight + GuSizes.fabMargin,
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
          if (showFab)
            GuFab(
              key: GuKey.action('MGT-04.create'),
              label: l10n.mgtEventsCreate,
              icon: GuIcons.plus,
              semanticLabel: l10n.mgtEventsCreate,
              onPressed: createEvent,
            ),
        ],
      ),
    );
  }
}
