import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/clubs/provider/club_members_state.dart';
import 'package:gu_kulupler/features/clubs/provider/club_members_view_model.dart';
import 'package:gu_kulupler/features/clubs/view/mixin/club_members_view_mixin.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/media/user_avatar_image.dart';
import 'package:gu_kulupler/product/widget/member/member_row.dart';
import 'package:gu_kulupler/product/widget/system/offline_list_fallback.dart';
import 'package:gu_ui/gu_ui.dart';

/// Üyeler ekranı — `ClubMembersRoute` (`/clubs/:clubId/members`); prototip
/// `Members` (`screens-clubs.js:141–148`). CLB-03 "Tüm üyeler" ve SHT-06
/// "Üyeler" açar; yalnızca kulübün içini görenler girer (guard `üye`,
/// router'da).
///
/// Yukarıdan aşağıya: başlık çubuğu (geri · "Üyeler" · kulüp adı) · arama
/// alanı · rol çipleri ("Tümü" / "Yönetim" / "Üye"; şerit dolgusu 3 px —
/// K-59) · kaydırma alanı (çek-yenile): "{n} kişi" + rol grupları (Başkan ·
/// Yönetim Kurulu · Danışman · Üye), her grup yapışkan başlık (rol adı +
/// sayı) ve `MemberRow` satırlarıyla.
///
/// * Arama ve çipler kaydırma alanının dışındadır; durumlar yalnızca listeyi
///   değiştirir (sıra: hata → yükleniyor → boş → dolu). Hata: "Bir şeyler
///   ters gitti" + "Yeniden dene"; yükleniyor: 6 satır iskeleti; boş:
///   "Eşleşen üye yok". Çevrimdışı bandı kökte çizilir; liste önbellekteki
///   veriyle kalır, yazan eylemler TST-24 verir.
/// * Sıradan üyeler 20'lik sayfalarla gelir; sonraki sayfa okunurken liste
///   sonunda iskelet satırları çizilir.
/// * Satıra dokunma CLB-07'yi açar. "⋮" yalnızca yönetici / süper admin
///   bakışında ve başkan ile danışman dışındaki satırlarda çizilir.
/// * Kaydırma sonu dolgusu alt güvenli alandır (`GuRefresh`).
///
/// Davranış `ClubMembersViewMixin`'dedir.
///
/// Design: CLB-06
class ClubMembersView extends ConsumerStatefulWidget {
  /// [clubId] kulübünün üye listesi.
  const ClubMembersView({required this.clubId, super.key});

  /// Kulüp kimliği (`ClubMembersRoute.clubId`).
  final String clubId;

  @override
  ConsumerState<ClubMembersView> createState() => _ClubMembersViewState();
}

class _ClubMembersViewState extends ConsumerState<ClubMembersView>
    with ClubMembersViewMixin {
  /// Yükleniyor iskeletindeki satır sayısı (prototip `ListState n=6`,
  /// `screens-clubs.js:147`).
  static const int _skeletonRows = 6;

  /// Sonraki sayfa okunurken liste sonunda çizilen iskelet satırı sayısı.
  static const int _nextPageRows = 3;

  static String _filterLabel(AppLocalizations l10n, MemberRoleFilter filter) =>
      switch (filter) {
        MemberRoleFilter.all => l10n.commonAll,
        MemberRoleFilter.board => l10n.membersFilterBoard,
        MemberRoleFilter.member => l10n.roleMember,
      };

  static Key _filterKey(MemberRoleFilter filter) => switch (filter) {
    MemberRoleFilter.all => GuKey.action('CLB-06.filter.all'),
    MemberRoleFilter.board => GuKey.action('CLB-06.filter.board'),
    MemberRoleFilter.member => GuKey.action('CLB-06.filter.member'),
  };

  static String _roleLabel(AppLocalizations l10n, ClubRole role) =>
      switch (role) {
        ClubRole.president => l10n.rolePresident,
        ClubRole.board => l10n.roleBoard,
        ClubRole.advisor => l10n.roleAdvisor,
        ClubRole.member => l10n.roleMember,
      };

  /// Bir rol grubu: yapışkan başlık + satırlar. "⋮" yalnızca [canManage]
  /// iken ve başkan / danışman dışındaki satırlarda çizilir
  /// (`screens-clubs.js:147`).
  Widget _group(
    ClubMembersState state,
    MemberGroup group, {
    required bool canManage,
  }) {
    final hasMenu =
        canManage &&
        group.role != ClubRole.president &&
        group.role != ClubRole.advisor;
    return SliverMainAxisGroup(
      slivers: [
        GuGroupHeader(
          title: _roleLabel(
            context.l10n,
            group.role,
          ).upperFor(Localizations.localeOf(context)),
          trailingText: group.count.toString(),
          sticky: true,
        ),
        SliverList.builder(
          itemCount: group.rows.length,
          itemBuilder: (_, index) {
            final membership = group.rows[index];
            final userId = membership.userId;
            return MemberRow(
              key: ValueKey<String>(userId),
              membership: membership,
              user: state.users[userId],
              avatarImage: ref.userAvatarImage(
                state.users[userId],
                displaySize: GuSizes.avatar,
              ),
              actionKey: GuKey.action('CLB-06.member.$userId'),
              onTap: () => openProfile(userId),
              menuActionKey: hasMenu
                  ? GuKey.action('CLB-06.menu.$userId')
                  : null,
              onMenu: hasMenu ? () => openMenu(membership) : null,
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final state = ref.watch(clubMembersViewModelProvider(widget.clubId));
    final access = ref.watch(
      sessionViewModelProvider.select(
        (session) => session.accessTo(widget.clubId),
      ),
    );
    final canManage =
        access == ClubAccess.manager || access == ClubAccess.superAdmin;
    final groups = state.groups;
    final status = GuListStatus.resolve(
      isError: state.isError,
      isLoading: state.isFetching,
      isEmpty: groups.isEmpty,
    );

    return Scaffold(
      backgroundColor: gu.colors.bgCanvas,
      appBar: GuAppBar(
        title: l10n.membersTitle,
        subtitle: state.club?.name,
        onBack: goBack,
        backSemanticLabel: l10n.a11yBack,
        backActionKey: GuKey.action('CLB-06.back'),
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
            child: GuInput(
              controller: searchController,
              icon: GuIcons.search,
              placeholder: l10n.membersSearch,
              semanticLabel: l10n.membersSearch,
              textInputAction: TextInputAction.search,
              onChanged: onQueryChanged,
              actionKey: GuKey.action('CLB-06.search'),
            ),
          ),
          // `.hscroll.pb16` yazılmıştır, ancak dikey dolgu 3 px kalır (K-59;
          // referans görüntüde ölçüldü).
          GuHorizontalList(
            children: [
              for (final filter in MemberRoleFilter.values)
                GuChip(
                  key: _filterKey(filter),
                  label: _filterLabel(l10n, filter),
                  selected: state.roleFilter == filter,
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
                          retryActionKey: GuKey.action('CLB-06.retry'),
                          inline: true,
                          onRetry: retry,
                        ),
                      ),
                    ],
                    GuListStatus.loading => [
                      SliverToBoxAdapter(
                        child: GuSkeletonList(
                          semanticLabel: l10n.commonLoading,
                          count: _skeletonRows,
                        ),
                      ),
                    ],
                    GuListStatus.empty => [
                      SliverToBoxAdapter(
                        child: GuEmptyState(
                          illustration: GuIllustrations.emptyClubs,
                          title: l10n.membersNoResults,
                          compact: true,
                        ),
                      ),
                    ],
                    GuListStatus.data => [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: GuInsets.only(
                            left: GuSpacing.s16,
                            right: GuSpacing.s16,
                            bottom: GuSpacing.s16,
                          ),
                          child: Text(
                            l10n.membersTotal(
                              ClubMembersState.countOf(groups),
                            ),
                            style: gu.text.caption.copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ),
                      for (final group in groups)
                        _group(state, group, canManage: canManage),
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
