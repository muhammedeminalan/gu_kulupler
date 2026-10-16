import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/admin/provider/admin_users_state.dart';
import 'package:gu_kulupler/features/admin/provider/admin_users_view_model.dart';
import 'package:gu_kulupler/features/admin/view/mixin/admin_users_view_mixin.dart';
import 'package:gu_kulupler/features/admin/view/widget/admin_user_row.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/navigation/admin_users_filter.dart';
import 'package:gu_kulupler/product/widget/system/offline_list_fallback.dart';
import 'package:gu_ui/gu_ui.dart';

/// Admin kullanıcılar bölmesi (ADM-05) — admin kökünün (`AdminView`,
/// `/admin?tab=users&filter=`; guard `S`) Kullanıcılar bölmesi. Prototip
/// `AdminUsers` (`screens-admin.js:72–78`).
///
/// Başlık ve `AdminSegmentBar` kökte (`AdminView`; kullanıcı kararı
/// 2026-10-16 — önceden ayrı sayfa). Bölme: `.px16.pb8` arama ("Ad veya
/// e-posta ara"; `pb8` tanımsız — K-42, dolgu yok) · `.hscroll.py8`
/// süzgeç çipleri (Tümü · Askıda · Yöneticiler; K-59) · kaydırma alanı
/// (çek-yenile, sayfalı; süzgeç değişimi kısa solma, `GuSliverContentFade`):
/// `AdminUserRow` satırları (dokunuş CLB-07 — admin kökünün alt sayfası,
/// geri → bu bölme; "⋮" → Profili gör · Askıya al / Askıyı kaldır).
///
/// Durumlar (sıra: hata → yükleniyor → boş → dolu; referans
/// `states/ADM-05__*`) yalnızca listeyi değiştirir; boş görünüm "Eşleşen üye
/// yok". Çevrimdışı bandı kökte (kabuk) çizilir; yazan eylemler TST-24
/// verir.
///
/// Davranış `AdminUsersViewModel` ve `AdminUsersViewMixin`'dedir.
///
/// Design: ADM-05
class AdminUsersView extends ConsumerStatefulWidget {
  /// Kullanıcı listesi; [filter] seçilen süzgeç.
  const AdminUsersView({this.filter, this.active = true, super.key});

  /// Seçilen süzgeç (`AdminRoute.filter`; değişip dolu geldiğinde uygulanır;
  /// ilk açılışta tümü).
  final AdminUsersFilter? filter;

  /// Bölme sahnede mi (sekmeye yeniden dokunma yalnızca etkin bölmeyi başa
  /// kaydırır).
  final bool active;

  @override
  ConsumerState<AdminUsersView> createState() => _AdminUsersViewState();
}

class _AdminUsersViewState extends ConsumerState<AdminUsersView>
    with AdminUsersViewMixin {
  /// İskelet satır sayısı (prototip `ListState n=${6}`).
  static const int _skeletonRows = 6;

  /// Sonraki sayfa yüklenirken liste sonundaki iskelet satırları.
  static const int _nextPageRows = 2;

  /// Çip sırası (`screens-admin.js:75`: Tümü · Askıda · Yöneticiler).
  static const List<AdminUsersFilter> _filters = [
    AdminUsersFilter.all,
    AdminUsersFilter.suspended,
    AdminUsersFilter.managers,
  ];

  static Key _filterKey(AdminUsersFilter filter) => switch (filter) {
    AdminUsersFilter.all => GuKey.action('ADM-05.filter.all'),
    AdminUsersFilter.managers => GuKey.action('ADM-05.filter.managers'),
    AdminUsersFilter.suspended => GuKey.action('ADM-05.filter.suspended'),
  };

  static String _filterLabel(AppLocalizations l10n, AdminUsersFilter filter) =>
      switch (filter) {
        AdminUsersFilter.all => l10n.commonAll,
        AdminUsersFilter.managers => l10n.adminUsersManagers,
        AdminUsersFilter.suspended => l10n.statusSuspended,
      };

  List<Widget> _slivers(AdminUsersState state, AppLocalizations l10n) {
    final rows = state.visible;
    final status = GuListStatus.resolve(
      isError: state.isError,
      isLoading: state.isFetching || state.isSearching || !state.isLoaded,
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
              retryActionKey: GuKey.action('ADM-05.retry'),
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
              title: l10n.membersNoResults,
            ),
          ),
        ];
      case GuListStatus.data:
        return [
          SliverList.builder(
            itemCount: rows.length,
            itemBuilder: (_, index) {
              final user = rows[index];
              return AdminUserRow(
                key: ValueKey<String>(user.uid),
                user: user,
                clubCount: state.clubCounts[user.uid],
                actionKey: GuKey.action('ADM-05.row.${user.uid}'),
                menuKey: GuKey.action('ADM-05.menu.${user.uid}'),
                onTap: () => openUser(user.uid),
                onMenu: () => openMenu(user),
              );
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
    final l10n = context.l10n;
    final state = ref.watch(adminUsersViewModelProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // `.px16.pb8`: `pb8` tanımsız (K-42) → alt dolgu yok.
        Padding(
          padding: GuInsets.h16,
          child: GuSearchField(
            value: state.query,
            onChanged: search,
            placeholder: l10n.adminUsersSearch,
            semanticLabel: l10n.adminUsersSearch,
            actionKey: GuKey.action('ADM-05.search'),
          ),
        ),
        // `.hscroll.py8` yazılmıştır, ancak `.hscroll` dolgusu ezer:
        // dikey 3 px (K-59).
        GuHorizontalList(
          children: [
            for (final filter in _filters)
              GuChip(
                key: _filterKey(filter),
                label: _filterLabel(l10n, filter),
                selected: state.filter == filter,
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
                GuSliverContentFade(
                  value: state.filter,
                  sliver: SliverMainAxisGroup(slivers: _slivers(state, l10n)),
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
    );
  }
}
