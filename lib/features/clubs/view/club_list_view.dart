import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/clubs/provider/club_list_state.dart';
import 'package:gu_kulupler/features/clubs/provider/club_list_view_model.dart';
import 'package:gu_kulupler/features/clubs/view/mixin/club_list_view_mixin.dart';
import 'package:gu_kulupler/features/clubs/view/widget/club_list_item.dart';
import 'package:gu_kulupler/features/clubs/view/widget/club_list_toolbar.dart';
import 'package:gu_kulupler/features/clubs/view/widget/first_club_card.dart';
import 'package:gu_kulupler/features/clubs/view/widget/my_clubs_strip.dart';
import 'package:gu_kulupler/product/l10n/static_labels.dart';
import 'package:gu_kulupler/product/media/club_media_image.dart';
import 'package:gu_kulupler/product/notification/unread_notification_clubs.dart';
import 'package:gu_kulupler/product/widget/club/club_card.dart';
import 'package:gu_kulupler/product/widget/club/cover_mapper.dart';
import 'package:gu_kulupler/product/widget/club/my_club_chip.dart';
import 'package:gu_kulupler/product/widget/system/offline_list_fallback.dart';
import 'package:gu_ui/gu_ui.dart';

/// "Kulüpler" ekranı — Kulüpler sekmesinin kökü, `ClubsRoute` (`/clubs`);
/// prototip `Clubs` (`screens-clubs.js:19–33`).
///
/// Büyük başlık çubuğu (ara) altında tek kaydırma alanı, çek-yenile ile:
/// "Kulüplerim" şeridi (üyeliği olmayana "İlk kulübünü bul" kartı) ·
/// kategori çipleri ("Tümü" + 8 kategori, tek seçim; şerit dolgusu 3 px —
/// K-59) · kulüp sayısı +
/// "Filtre / Sırala" (etkin süzgeç rozeti) + liste ↔ ızgara · kulüp kartları
/// · liste sonu satırı.
///
/// * Durumlar yalnızca liste alanını değiştirir (sıra: hata → yükleniyor →
///   boş → dolu); üstteki bölümler yerinde kalır. Hata: "Bir şeyler ters
///   gitti" + "Yeniden dene"; yükleniyor: 6 kart iskeleti; boş: "Aramana
///   uygun kulüp bulamadık" + "Filtreleri temizle". Çevrimdışı bandı kökte
///   çizilir; liste önbellekteki veriyle kalır, yazan eylemler TST-24 verir.
/// * Kart görünümü kullanıcının kulüpteki kipine göredir (`ClubCard` /
///   `ClubCta`); anında katılımda kart iyimser olarak "üye" çizilir.
/// * Izgara satırları eşit yükseklikte iki sütundur (`.grid2`, aralık 12).
/// * Kaydırma sonu dolgusu alt güvenli alandır (`GuRefresh`).
///
/// Davranış `ClubListViewMixin`'dedir.
///
/// Design: CLB-01
class ClubListView extends ConsumerStatefulWidget {
  /// Kulüpler sekme kökü.
  const ClubListView({super.key});

  @override
  ConsumerState<ClubListView> createState() => _ClubListViewState();
}

class _ClubListViewState extends ConsumerState<ClubListView>
    with ClubListViewMixin {
  /// Yükleniyor iskeletindeki kart sayısı (prototip `ListState n=6`,
  /// `screens-clubs.js:29`).
  static const int _skeletonCards = 6;

  /// Izgara sütun sayısı (`.grid2`).
  static const int _gridColumns = 2;

  /// "Kulüplerim": etkin üyeliği olan kulüpler, oturumdaki üyelik sırasıyla
  /// (`actions.js:31`; listede olmayan kulüp atlanır). Okunmamış bildirimi
  /// olan kulübün kartında nokta (W-68; `screens-clubs.js:25`).
  List<Widget> _myClubChips(
    ClubListState state,
    SessionState session,
    Set<String> unreadClubIds,
  ) => [
    for (final membership in session.memberships.values)
      if (membership.status == MembershipStatus.active)
        if (state.clubById(membership.clubId) case final club?)
          MyClubChip(
            club: club,
            manager:
                membership.role == ClubRole.board ||
                membership.role == ClubRole.president,
            unread: unreadClubIds.contains(club.id),
            coverImage: ref.clubCoverImage(club),
            actionKey: GuKey.action('CLB-01.myClub.${club.id}'),
            onTap: () => openClub(club.id),
          ),
  ];

  Widget _card(ClubListState state, SessionState session, ClubModel club) {
    final grid = state.layout == ClubListLayout.grid;
    // Anında katılım yazılırken / oturuma yansıyana dek kart "üye" çizilir.
    final joining = state.pendingJoinIds.contains(club.id);
    return ClubListItem(
      key: ValueKey<String>(club.id),
      clubId: club.id,
      loadPreview: !grid,
      child: ClubCard(
        club: club,
        access: joining ? ClubAccess.member : session.accessTo(club.id),
        membershipStatus: joining
            ? MembershipStatus.active
            : session.memberships[club.id]?.status,
        memberPreview: [
          for (final manager
              in state.managerPreviews[club.id] ?? const <MembershipModel>[])
            GuAvatarData(
              initials: manager.applicant.name.initials,
              seed: manager.applicant.avatarSeed,
            ),
        ],
        grid: grid,
        coverImage: ref.clubCoverImage(club),
        logoImage: ref.clubLogoImage(
          club,
          displaySize: (grid ? GuEmblemSize.xs : GuEmblemSize.sm).dimension,
        ),
        actionKey: GuKey.action('CLB-01.card.${club.id}'),
        joinKey: GuKey.action('CLB-01.join.${club.id}'),
        statusKey: GuKey.action('CLB-01.status.${club.id}'),
        openKey: GuKey.action('CLB-01.open.${club.id}'),
        onOpen: () => openClub(club.id),
        onJoin: () => join(club.id),
        onClosedTap: showClosed,
        onStatus: () => openStatus(club.id),
      ),
    );
  }

  /// Dolu liste: tek sütun (aralık 12) ya da eşit yükseklikli iki sütunlu
  /// satırlar.
  Widget _clubs(
    ClubListState state,
    SessionState session,
    List<ClubModel> visible,
  ) {
    if (state.layout == ClubListLayout.list) {
      return SliverList.separated(
        itemCount: visible.length,
        itemBuilder: (_, index) => _card(state, session, visible[index]),
        separatorBuilder: (_, _) => GuGap.v12,
      );
    }
    return SliverList.separated(
      itemCount: (visible.length / _gridColumns).ceil(),
      itemBuilder: (_, row) {
        final start = row * _gridColumns;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: GuSizes.gridGap,
            children: [
              for (var i = start; i < start + _gridColumns; i++)
                Expanded(
                  child: i < visible.length
                      ? _card(state, session, visible[i])
                      : const SizedBox.shrink(),
                ),
            ],
          ),
        );
      },
      separatorBuilder: (_, _) => const SizedBox(height: GuSizes.gridGap),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(clubListViewModelProvider);
    final session = ref.watch(sessionViewModelProvider);
    final visible = state.visible;
    final selectedCategory = state.filters.singleCategoryId;
    final myClubs = _myClubChips(
      state,
      session,
      ref.watch(unreadNotificationClubsProvider),
    );
    final hasMembership = session.memberships.values.any(
      (membership) => membership.status == MembershipStatus.active,
    );
    final status = GuListStatus.resolve(
      isError: state.isError,
      isLoading: state.isFetching,
      isEmpty: visible.isEmpty,
    );

    return Scaffold(
      backgroundColor: context.gu.colors.bgCanvas,
      appBar: GuAppBar(
        large: true,
        title: l10n.navClubs,
        actions: [
          GuIconButton(
            key: GuKey.action('CLB-01.search'),
            icon: GuIcons.search,
            semanticLabel: l10n.commonSearch,
            onPressed: openSearch,
          ),
        ],
      ),
      body: GuRefresh(
        onRefresh: refresh,
        refreshActionKey: GuKey.action('CLB-01.refresh'),
        child: CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (myClubs.isNotEmpty)
                    MyClubsStrip(
                      chips: myClubs,
                      allKey: GuKey.action('CLB-01.myClubsAll'),
                      onAll: openMyClubsAll,
                    )
                  else if (!hasMembership)
                    FirstClubCard(
                      discoverKey: GuKey.action('CLB-01.discover'),
                      onDiscover: discover,
                    ),
                  KeyedSubtree(
                    key: listAnchorKey,
                    // `.hscroll.pb16` yazılmıştır, ancak dikey dolgu 3 px
                    // kalır (K-59; referans görüntüde ölçüldü).
                    child: GuHorizontalList(
                      children: [
                        GuChip(
                          key: GuKey.action('CLB-01.category.all'),
                          label: l10n.commonAll,
                          selected: state.filters.categoryIds.isEmpty,
                          onTap: () => selectCategory(null),
                        ),
                        for (final category in StaticTables.categories)
                          GuChip(
                            key: GuKey.action(
                              'CLB-01.category.${category.id}',
                            ),
                            label: StaticLabels.category(context, category.id),
                            icon: CoverMapper.icon(category.icon),
                            selected: selectedCategory == category.id,
                            onTap: () => selectCategory(category.id),
                          ),
                      ],
                    ),
                  ),
                  ClubListToolbar(
                    count: visible.length,
                    activeFilterCount: state.activeFilterCount,
                    grid: state.layout == ClubListLayout.grid,
                    filterKey: GuKey.action('CLB-01.filter'),
                    toggleViewKey: GuKey.action('CLB-01.toggleView'),
                    onFilter: openFilters,
                    onToggleView: toggleView,
                  ),
                ],
              ),
            ),
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
                    retryActionKey: GuKey.action('CLB-01.retry'),
                    inline: true,
                    onRetry: retry,
                  ),
                ),
              ],
              GuListStatus.loading => [
                SliverToBoxAdapter(
                  child: GuSkeletonList(
                    semanticLabel: l10n.commonLoading,
                    count: _skeletonCards,
                    variant: GuSkeletonVariant.card,
                  ),
                ),
              ],
              GuListStatus.empty => [
                SliverToBoxAdapter(
                  child: GuEmptyState(
                    illustration: GuIllustrations.emptyClubs,
                    title: l10n.clubsEmptyTitle,
                    description: l10n.clubsEmptyDesc,
                    ctaLabel: l10n.clubsEmptyClear,
                    ctaActionKey: GuKey.action('CLB-01.clearFilters'),
                    onCta: clearFilters,
                  ),
                ),
              ],
              GuListStatus.data => [
                SliverPadding(
                  padding: GuInsets.h16,
                  sliver: _clubs(state, session, visible),
                ),
                SliverToBoxAdapter(
                  child: GuListEnd(label: l10n.commonAllDone),
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
    );
  }
}
