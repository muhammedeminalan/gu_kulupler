import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/format/app_date_formats.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/profile/provider/my_clubs_state.dart';
import 'package:gu_kulupler/features/profile/provider/my_clubs_view_model.dart';
import 'package:gu_kulupler/features/profile/view/mixin/my_clubs_view_mixin.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/navigation/my_clubs_tab.dart';
import 'package:gu_kulupler/product/widget/club/my_club_row.dart';
import 'package:gu_ui/gu_ui.dart';

/// "Kulüplerim" ekranı — `MyClubsRoute` (`/profile/clubs?tab=`); prototip
/// `MyClubs` (`screens-profile.js:40–49`). Sekmeler: aktif · bekleyen ·
/// geçmiş ([MyClubsTab]).
///
/// Yukarıdan aşağıya: başlık çubuğu (geri · "Kulüplerim ve başvurularım") ·
/// sekmeler ("Üyeliklerim" / "Bekleyen" / "Geçmiş"; K-05: sığmazsa
/// kaydırılır) · kaydırma alanı (çek-yenile): `MyClubRow` satırları.
///
/// * Satır: amblem · kulüp adı · aktifte rol, diğerlerinde durum rozeti +
///   karar / başvuru tarihi · "Diğer" (⋮) menüsü (Aç · Kulüpten ayrıl /
///   İsteği iptal et / Tekrar başvur).
/// * Durumlar yalnızca listeyi değiştirir (hata → yükleniyor → boş → dolu).
///   Hata: "Bir şeyler ters gitti" + "Yeniden dene"; yükleniyor: 4 satır
///   iskeleti; boş: sekmeye göre başlık + "Etkinlikleri keşfet". Çevrimdışı
///   bandı kökte çizilir; liste oturumdaki veriyle kalır, yazımlar TST-24
///   verir.
///
/// Davranış `MyClubsViewModel` ve `MyClubsViewMixin`'dedir.
///
/// Design: PRF-03
class MyClubsView extends ConsumerStatefulWidget {
  /// Kulüplerim; [tab] ilk açılan sekmedir (`null` → [MyClubsTab.active]).
  const MyClubsView({this.tab, super.key});

  /// İlk açılan sekme (`?tab=`).
  final MyClubsTab? tab;

  @override
  ConsumerState<MyClubsView> createState() => _MyClubsViewState();
}

class _MyClubsViewState extends ConsumerState<MyClubsView>
    with MyClubsViewMixin {
  static String _tabLabel(AppLocalizations l10n, MyClubsTab tab) =>
      switch (tab) {
        MyClubsTab.active => l10n.myclubsTabActive,
        MyClubsTab.pending => l10n.myclubsTabPending,
        MyClubsTab.past => l10n.myclubsTabHistory,
      };

  static Key _tabKey(MyClubsTab tab) => switch (tab) {
    MyClubsTab.active => GuKey.action('PRF-03.tab.active'),
    MyClubsTab.pending => GuKey.action('PRF-03.tab.pending'),
    MyClubsTab.past => GuKey.action('PRF-03.tab.history'),
  };

  static String _emptyTitle(AppLocalizations l10n, MyClubsTab tab) =>
      switch (tab) {
        MyClubsTab.active => l10n.myclubsEmptyActive,
        MyClubsTab.pending => l10n.myclubsEmptyPending,
        MyClubsTab.past => l10n.myclubsEmptyHistory,
      };

  Widget _row(MyClubEntry entry, AppDateFormats formats) {
    final (membership, club) = entry;
    final id = club.id;
    final date = MyClubsState.dateOf(membership);
    return MyClubRow(
      key: ValueKey<String>(id),
      club: club,
      role: membership.role,
      status: membership.status,
      caption: date == null ? null : formats.date(date),
      actionKey: GuKey.action('PRF-03.row.$id'),
      onTap: () => openClub(membership),
      menuKey: GuKey.action('PRF-03.menu.$id'),
      onMenu: () => openMenu(entry),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final state = ref.watch(myClubsViewModelProvider);
    final formats = AppDateFormats(
      Localizations.localeOf(context),
      ref.watch(appClockProvider),
    );
    final visible = state.visible;
    final status = GuListStatus.resolve(
      isError: state.isError,
      isLoading: state.isFetching,
      isEmpty: visible.isEmpty,
    );

    return Scaffold(
      backgroundColor: gu.colors.bgCanvas,
      appBar: GuAppBar(
        title: l10n.myclubsTitle,
        onBack: goBack,
        backSemanticLabel: l10n.a11yBack,
        backActionKey: GuKey.action('PRF-03.back'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GuTabs(
            tabs: [
              for (final tab in MyClubsTab.values)
                GuTabItem(id: tab.name, label: _tabLabel(l10n, tab)),
            ],
            value: state.tab.name,
            onChanged: (id) => selectTab(MyClubsTab.values.byName(id)),
            tabKeyBuilder: (index) => _tabKey(MyClubsTab.values[index]),
          ),
          Expanded(
            child: GuRefresh(
              onRefresh: refresh,
              child: CustomScrollView(
                controller: scrollController,
                slivers: [
                  ...switch (status) {
                    GuListStatus.error => [
                      SliverToBoxAdapter(
                        child: GuErrorState(
                          title: l10n.sysErrorTitle,
                          description: l10n.sysErrorDesc,
                          retryLabel: l10n.commonRetry,
                          retryActionKey: GuKey.action('PRF-03.retry'),
                          inline: true,
                          onRetry: retry,
                        ),
                      ),
                    ],
                    GuListStatus.loading => [
                      SliverToBoxAdapter(
                        // Prototip `ListState n=4`.
                        child: GuSkeletonList(
                          semanticLabel: l10n.commonLoading,
                        ),
                      ),
                    ],
                    GuListStatus.empty => [
                      SliverToBoxAdapter(
                        child: GuEmptyState(
                          illustration: GuIllustrations.emptyApplications,
                          title: _emptyTitle(l10n, state.tab),
                          ctaLabel: l10n.eventsDiscover,
                          ctaActionKey: GuKey.action('PRF-03.discover'),
                          onCta: discover,
                        ),
                      ),
                    ],
                    GuListStatus.data => [
                      SliverList.builder(
                        itemCount: visible.length,
                        itemBuilder: (_, index) =>
                            _row(visible[index], formats),
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
