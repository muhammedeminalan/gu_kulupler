import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/admin/provider/admin_reports_state.dart';
import 'package:gu_kulupler/features/admin/provider/admin_reports_view_model.dart';
import 'package:gu_kulupler/features/admin/provider/report_group.dart';
import 'package:gu_kulupler/features/admin/provider/report_target_preview.dart';
import 'package:gu_kulupler/features/admin/view/mixin/admin_reports_view_mixin.dart';
import 'package:gu_kulupler/features/admin/view/widget/admin_segment_bar.dart';
import 'package:gu_kulupler/features/admin/view/widget/report_group_row.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/navigation/admin_reports_tab.dart';
import 'package:gu_kulupler/product/widget/system/offline_list_fallback.dart';
import 'package:gu_ui/gu_ui.dart';

/// Admin şikayetler — `AdminReportsRoute` (`/admin/reports?tab=&reportId=`;
/// guard `S`: yalnızca süper admin, router'da). Prototip `Reports`
/// (`screens-admin.js:61–66`).
///
/// Yukarıdan aşağıya: büyük başlık "Admin" + "Süper Admin" rozeti ·
/// `AdminSegmentBar` (Şikayetler seçili) · sekmeler (Açık — açık grup
/// sayacı · Çözüldü) · hedef türü çipleri (`.hscroll.py8`: Tümü · Gönderi ·
/// Yorum · Kullanıcı · Kulüp · Etkinlik) · kaydırma alanı (çek-yenile,
/// sayfalı): `ReportGroupRow` satırları (dokunuş SHT-26).
///
/// Durumlar (sıra: hata → yükleniyor → boş → dolu; referans
/// `states/ADM-04__*`) yalnızca listeyi değiştirir; boş görünüm "Açık
/// şikayet yok" / "Çözülmüş şikayet yok". Çevrimdışı bandı kökte (kabuk)
/// çizilir; yazan eylemler TST-24 verir.
///
/// Davranış `AdminReportsViewModel` ve `AdminReportsViewMixin`'dedir.
///
/// Design: ADM-04
class AdminReportsView extends ConsumerStatefulWidget {
  /// Şikayet listesi; [tab] ilk açılan sekme, [reportId] açılışta SHT-26'sı
  /// açılan grup anahtarı.
  const AdminReportsView({this.tab, this.reportId, super.key});

  /// İlk açılan sekme (`AdminReportsRoute.tab`; `null` → açık).
  final AdminReportsTab? tab;

  /// Açılışta SHT-26'sı açılan grup (`{targetType}_{targetId}`).
  final String? reportId;

  @override
  ConsumerState<AdminReportsView> createState() => _AdminReportsViewState();
}

class _AdminReportsViewState extends ConsumerState<AdminReportsView>
    with AdminReportsViewMixin {
  /// Sonraki sayfa okunurken iskelet satır sayısı.
  static const int _nextPageRows = 2;

  static final List<Key> _tabKeys = [
    for (final tab in AdminReportsTab.values)
      switch (tab) {
        AdminReportsTab.open => GuKey.action('ADM-04.tab.open'),
        AdminReportsTab.resolved => GuKey.action('ADM-04.tab.resolved'),
      },
  ];

  static Key _filterKey(ReportTargetFilter filter) => switch (filter) {
    ReportTargetFilter.all => GuKey.action('ADM-04.filter.all'),
    ReportTargetFilter.post => GuKey.action('ADM-04.filter.post'),
    ReportTargetFilter.comment => GuKey.action('ADM-04.filter.comment'),
    ReportTargetFilter.user => GuKey.action('ADM-04.filter.user'),
    ReportTargetFilter.club => GuKey.action('ADM-04.filter.club'),
    ReportTargetFilter.event => GuKey.action('ADM-04.filter.event'),
  };

  static String _filterLabel(
    AppLocalizations l10n,
    ReportTargetFilter filter,
  ) => switch (filter.type) {
    null => l10n.commonAll,
    final type => ReportGroupRow.typeLabel(l10n, type),
  };

  static String _tabLabel(AppLocalizations l10n, AdminReportsTab tab) =>
      switch (tab) {
        AdminReportsTab.open => l10n.reportsTabOpen,
        AdminReportsTab.resolved => l10n.reportsTabResolved,
      };

  Widget _row(
    ReportGroup group,
    ReportTargetPreview? preview,
    AppLocalizations l10n,
  ) => ReportGroupRow(
    key: ValueKey<String>(group.key),
    group: group,
    title: ReportGroupRow.titleOf(l10n, group, preview),
    actionKey: GuKey.action('ADM-04.row.${group.key}'),
    onTap: () => openGroup(group.key),
  );

  List<Widget> _slivers(AdminReportsState state, AppLocalizations l10n) {
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
              retryActionKey: GuKey.action('ADM-04.retry'),
              inline: true,
              onRetry: retry,
            ),
          ),
        ];
      case GuListStatus.loading:
        return [
          SliverToBoxAdapter(
            // Prototip `ListState n=${4}` = varsayılan satır sayısı.
            child: GuSkeletonList(semanticLabel: l10n.commonLoading),
          ),
        ];
      case GuListStatus.empty:
        return [
          SliverToBoxAdapter(
            child: GuEmptyState(
              illustration: GuIllustrations.emptyNotifications,
              title: switch (state.tab) {
                AdminReportsTab.open => l10n.reportsEmptyOpen,
                AdminReportsTab.resolved => l10n.reportsEmptyResolved,
              },
            ),
          ),
        ];
      case GuListStatus.data:
        return [
          SliverList.builder(
            itemCount: rows.length,
            itemBuilder: (_, index) {
              final group = rows[index];
              return _row(group, state.previews[group.key], l10n);
            },
          ),
          if (state.isLoadingMore)
            SliverToBoxAdapter(
              child: GuSkeletonList(
                semanticLabel: l10n.commonLoading,
                count: _nextPageRows,
              ),
            ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final state = ref.watch(adminReportsViewModelProvider);
    final openCount = state.loadedTabs.contains(AdminReportsTab.open)
        ? state.openCount
        : 0;

    return Scaffold(
      backgroundColor: gu.colors.bgCanvas,
      appBar: GuAppBar(
        title: l10n.navAdmin,
        large: true,
        actions: [
          GuRoleBadge(
            kind: GuRoleBadgeKind.superadmin,
            label: l10n.roleSuperadmin,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminSegmentBar(
            current: AdminSegmentBar.reports,
            onSelect: openSegment,
            keyOf: (id) => GuKey.action('ADM-04.seg.$id'),
          ),
          GuTabs(
            tabs: [
              for (final tab in AdminReportsTab.values)
                GuTabItem(
                  id: tab.name,
                  label: _tabLabel(l10n, tab),
                  count: tab == AdminReportsTab.open && openCount > 0
                      ? openCount
                      : null,
                ),
            ],
            value: state.tab.name,
            onChanged: selectTab,
            tabKeyBuilder: (index) => _tabKeys[index],
          ),
          // `.hscroll.py8` yazılmıştır, ancak `.hscroll` dolgusu ezer:
          // dikey 3 px (K-59).
          GuHorizontalList(
            children: [
              for (final filter in ReportTargetFilter.values)
                GuChip(
                  key: _filterKey(filter),
                  label: _filterLabel(l10n, filter),
                  selected: state.typeFilter == filter,
                  onTap: () => selectFilter(filter),
                ),
            ],
          ),
          Expanded(
            child: GuRefresh(
              onRefresh: refresh,
              child: CustomScrollView(
                controller: scrollController,
                slivers: [
                  ..._slivers(state, l10n),
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
