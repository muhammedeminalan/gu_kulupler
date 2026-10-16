import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/admin/provider/admin_clubs_state.dart';
import 'package:gu_kulupler/features/admin/provider/admin_clubs_view_model.dart';
import 'package:gu_kulupler/features/admin/view/mixin/admin_clubs_view_mixin.dart';
import 'package:gu_kulupler/features/admin/view/widget/admin_club_row.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/navigation/admin_clubs_tab.dart';
import 'package:gu_kulupler/product/widget/system/offline_list_fallback.dart';
import 'package:gu_ui/gu_ui.dart';

/// Admin kulüpler bölmesi (ADM-02) — admin kökünün (`AdminView`,
/// `/admin?tab=clubs&clubsTab=`; guard `S`) Kulüpler bölmesi. Prototip
/// `AdminClubs` (`screens-admin.js:29–35`).
///
/// Başlık ve `AdminSegmentBar` kökte (`AdminView`; kullanıcı kararı
/// 2026-10-16 — önceden ayrı sayfa). Bölme: `.px16.pb16.col.gap8`: sekmeler
/// (Aktif · Askıda) + arama · kaydırma alanı (çek-yenile; sekme değişimi
/// kısa solma, `GuSliverContentFade`): `AdminClubRow` satırları (dokunuş
/// CLB-03, "⋮" → Görüntüle · Düzenle · Başkanı değiştir · Askıya al /
/// Etkinleştir) · "Kulüp oluştur" FAB (`+`, ADM-03). Bölme alt sekme
/// çubuğunun üstünde biter: FAB bölmenin altından `fabMargin` yukarıdadır
/// (tasarımdaki `nav-h + 16` — K-34).
///
/// Durumlar (sıra: hata → yükleniyor → boş → dolu; referans
/// `states/ADM-02__*`) yalnızca listeyi değiştirir; boş görünüm "Kulüp yok".
/// Çevrimdışı bandı kökte (kabuk) çizilir; yazan eylemler TST-24 verir.
///
/// Davranış `AdminClubsViewModel` ve `AdminClubsViewMixin`'dedir.
///
/// Design: ADM-02
class AdminClubsView extends ConsumerStatefulWidget {
  /// Kulüp listesi; [tab] açılan sekme (`null` → son seçili, ilk açılışta
  /// etkin).
  const AdminClubsView({this.tab, this.active = true, super.key});

  /// Açılan sekme (`AdminRoute.clubsTab`; değişip dolu geldiğinde uygulanır).
  final AdminClubsTab? tab;

  /// Bölme sahnede mi (sekmeye yeniden dokunma yalnızca etkin bölmeyi başa
  /// kaydırır).
  final bool active;

  @override
  ConsumerState<AdminClubsView> createState() => _AdminClubsViewState();
}

class _AdminClubsViewState extends ConsumerState<AdminClubsView>
    with AdminClubsViewMixin {
  /// İskelet satır sayısı (prototip `ListState n=${5}`).
  static const int _skeletonRows = 5;

  static final List<Key> _tabKeys = [
    for (final tab in AdminClubsTab.values)
      switch (tab) {
        AdminClubsTab.active => GuKey.action('ADM-02.tab.active'),
        AdminClubsTab.suspended => GuKey.action('ADM-02.tab.suspended'),
      },
  ];

  static String _tabLabel(AppLocalizations l10n, AdminClubsTab tab) =>
      switch (tab) {
        AdminClubsTab.active => l10n.statusActive,
        AdminClubsTab.suspended => l10n.statusSuspended,
      };

  List<Widget> _slivers(AdminClubsState state, AppLocalizations l10n) {
    final rows = state.visible;
    final status = GuListStatus.resolve(
      isError: state.isError,
      isLoading: state.isFetching || !state.isLoaded,
      isEmpty: rows.isEmpty,
    );
    switch (status) {
      case _ when OfflineListFallback.applies(ref, status):
        return [OfflineListFallback.sliver(onReload: retry)];
      case GuListStatus.error:
        return [
          SliverToBoxAdapter(
            child: GuErrorState(
              title: l10n.sysErrorTitle,
              description: l10n.sysErrorDesc,
              retryLabel: l10n.commonRetry,
              retryActionKey: GuKey.action('ADM-02.retry'),
              inline: true,
              onRetry: retry,
            ),
          ),
        ];
      case GuListStatus.loading:
        return [
          SliverToBoxAdapter(
            child: GuSkeletonList(
              semanticLabel: l10n.commonLoading,
              count: _skeletonRows,
            ),
          ),
        ];
      case GuListStatus.empty:
        return [
          SliverToBoxAdapter(
            child: GuEmptyState(
              illustration: GuIllustrations.emptyClubs,
              title: l10n.adminClubsEmpty,
            ),
          ),
        ];
      case GuListStatus.data:
        return [
          SliverList.builder(
            itemCount: rows.length,
            itemBuilder: (_, index) {
              final club = rows[index];
              return AdminClubRow(
                key: ValueKey<String>(club.id),
                club: club,
                president: state.presidents[club.presidentId],
                actionKey: GuKey.action('ADM-02.row.${club.id}'),
                menuKey: GuKey.action('ADM-02.menu.${club.id}'),
                onTap: () => openClub(club.id),
                onMenu: () => openMenu(club),
              );
            },
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(adminClubsViewModelProvider);

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: GuInsets.only(
                left: GuSpacing.s16,
                right: GuSpacing.s16,
                bottom: GuSpacing.s16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: GuSpacing.s8,
                children: [
                  GuSegmented(
                    options: [
                      for (final tab in AdminClubsTab.values)
                        GuSegmentOption(
                          id: tab.name,
                          label: _tabLabel(l10n, tab),
                        ),
                    ],
                    value: state.tab.name,
                    optionKeyBuilder: (index) => _tabKeys[index],
                    onChanged: selectTab,
                  ),
                  GuSearchField(
                    value: state.query,
                    onChanged: search,
                    placeholder: l10n.commonSearch,
                    semanticLabel: l10n.commonSearch,
                    actionKey: GuKey.action('ADM-02.search'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GuRefresh(
                onRefresh: refresh,
                child: CustomScrollView(
                  controller: scrollController,
                  slivers: [
                    GuSliverContentFade(
                      value: state.tab,
                      sliver: SliverMainAxisGroup(
                        slivers: _slivers(state, l10n),
                      ),
                    ),
                    // FAB son satırın "⋮" düğmesini örtmesin.
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
        GuFab(
          key: GuKey.action('ADM-02.create'),
          label: l10n.adminClubsCreate,
          icon: GuIcons.plus,
          semanticLabel: l10n.adminClubsCreate,
          onPressed: createClub,
        ),
      ],
    );
  }
}
