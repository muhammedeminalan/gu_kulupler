import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/format/app_date_formats.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/management/provider/manage_members_state.dart';
import 'package:gu_kulupler/features/management/provider/manage_members_view_model.dart';
import 'package:gu_kulupler/features/management/view/mixin/manage_members_view_mixin.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/managed_club_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/member_actions_sheet.dart';
import 'package:gu_kulupler/product/media/user_avatar_image.dart';
import 'package:gu_kulupler/product/widget/manage/manage_header.dart';
import 'package:gu_kulupler/product/widget/member/member_row.dart';
import 'package:gu_kulupler/product/widget/system/offline_list_fallback.dart';
import 'package:gu_ui/gu_ui.dart';

/// Üye yönetimi — `ManageMembersRoute`
/// (`/clubs/:clubId/manage/members?transfer=`); prototip `MgtMembers`
/// (`screens-manage.js:61–74`). MGT-01 "Üyeler" (W-37) açar; DLG-09 (W-14)
/// ve SET-03 (W-34) [openTransfer] ile açar (guard `V`, router'da).
///
/// Yukarıdan aşağıya: `ManageHeader` (geri · "Üye yönetimi" / kulüp adı ·
/// rol rozeti · "⋮" → "Üye listesini dışa aktar (CSV)") · danışmanda salt
/// okunur bandı · arama (`.px16.py8`) · rol çipleri (Tümü / Başkan /
/// Yönetim Kurulu / Danışman / Üye; şerit dolgusu 3 px — K-59) · "{n} kişi"
/// + sıralama düğmesi (açılır menü: ada / katılım tarihine / role göre) ·
/// kaydırma alanı (çek-yenile): `MemberRow` satırları ("{ay yıl}'den beri";
/// başkan ve danışman dışındaki satırlarda "⋮" → SHT-21) + başkan / süper
/// adminde "Başkanlığı devret" kartı (SHT-25 → DLG-21) + liste sonu.
///
/// Durumlar (sıra: hata → yükleniyor → boş → dolu) yalnızca listeyi
/// değiştirir; "{n} kişi" yükleniyor / hata durumunda çizilmez. Çevrimdışı
/// bandı kökte (kabuk) çizilir; yazan eylemler TST-24 verir. Katılım oranı
/// çubuğu (`showRate`) için üye başına veri kaynağı yoktur — çizilmez.
///
/// Davranış `ManageMembersViewModel` ve `ManageMembersViewMixin`'dedir.
///
/// Design: MGT-03
class ManageMembersView extends ConsumerStatefulWidget {
  /// [clubId] kulübünün üyeleri; [openTransfer] `true` ise açılışta SHT-25.
  const ManageMembersView({
    required this.clubId,
    this.openTransfer = false,
    super.key,
  });

  /// Kulüp kimliği (`ManageMembersRoute.clubId`).
  final String clubId;

  /// Açılışta başkanlık devri sayfası (SHT-25) açılsın mı
  /// (`ManageMembersRoute.transfer`; W-14, W-34).
  final bool openTransfer;

  @override
  ConsumerState<ManageMembersView> createState() => _ManageMembersViewState();
}

class _ManageMembersViewState extends ConsumerState<ManageMembersView>
    with ManageMembersViewMixin {
  /// Yükleniyor iskeletindeki satır sayısı (prototip `ListState n=6`).
  static const int _skeletonRows = 6;

  /// Sonraki sayfa okunurken liste sonunda çizilen iskelet satırı sayısı.
  static const int _nextPageRows = 3;

  static Key _filterKey(ManageRoleFilter filter) => switch (filter) {
    ManageRoleFilter.all => GuKey.action('MGT-03.filter.all'),
    ManageRoleFilter.president => GuKey.action('MGT-03.filter.president'),
    ManageRoleFilter.board => GuKey.action('MGT-03.filter.board'),
    ManageRoleFilter.advisor => GuKey.action('MGT-03.filter.advisor'),
    ManageRoleFilter.member => GuKey.action('MGT-03.filter.member'),
  };

  static String _filterLabel(AppLocalizations l10n, ManageRoleFilter filter) =>
      switch (filter) {
        ManageRoleFilter.all => l10n.commonAll,
        ManageRoleFilter.president => l10n.rolePresident,
        ManageRoleFilter.board => l10n.roleBoard,
        ManageRoleFilter.advisor => l10n.roleAdvisor,
        ManageRoleFilter.member => l10n.roleMember,
      };

  /// Üye satırı (`cards.js:165–169`, `screens-manage.js:71`).
  Widget _row(
    ManageMembersState state,
    MembershipModel m,
    AppDateFormats formats,
    DateTime now,
  ) {
    final userId = m.userId;
    final user = state.users[userId];
    final hasMenu =
        !state.isReadOnly &&
        MemberActionsSheet.canOpen(
          actorRole: state.role,
          targetRole: m.role,
          isSuperAdmin: state.isSuperAdmin,
        );
    return MemberRow(
      key: ValueKey<String>(userId),
      membership: m,
      user: user,
      avatarImage: ref.userAvatarImage(user, displaySize: GuSizes.avatar),
      sub: context.l10n.mgtMembersSince(
        formats.monthYear(ManageMembersState.joinedAt(m) ?? now),
      ),
      actionKey: GuKey.action('MGT-03.member.$userId'),
      onTap: () => openProfile(userId),
      menuActionKey: hasMenu ? GuKey.action('MGT-03.menu.$userId') : null,
      onMenu: hasMenu ? () => openMemberMenu(m) : null,
    );
  }

  /// "Başkanlığı devret" kartı (`screens-manage.js:72`; `.px16.pt16`,
  /// `card-body col gap8`).
  Widget _transferCard(AppLocalizations l10n) {
    final gu = context.gu;
    final colors = gu.colors;
    return Padding(
      padding: GuInsets.only(
        left: GuSpacing.s16,
        right: GuSpacing.s16,
        top: GuSpacing.s16,
      ),
      child: GuCard(
        padding: GuCard.bodyPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: GuSpacing.s8,
          children: [
            Row(
              spacing: GuSpacing.s6,
              children: [
                GuIcon(
                  GuIcons.crown,
                  size: GuSizes.icon18,
                  color: colors.brandPrimaryText,
                ),
                Expanded(
                  child: Text(
                    l10n.mgtMembersTransferTitle,
                    style: gu.text.labelL.copyWith(color: colors.textHeading),
                  ),
                ),
              ],
            ),
            Text(
              l10n.mgtMembersTransferDesc,
              style: gu.text.bodyS.copyWith(color: colors.textSecondary),
            ),
            GuButton(
              key: GuKey.action('MGT-03.transfer'),
              label: l10n.mgtMembersTransfer,
              variant: GuButtonVariant.outline,
              onPressed: openTransfer,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _slivers(
    ManageMembersState state,
    List<MembershipModel> rows,
    AppLocalizations l10n,
  ) {
    final status = GuListStatus.resolve(
      isError: state.isError,
      isLoading: state.isFetching,
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
              retryActionKey: GuKey.action('MGT-03.retry'),
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
        final clock = ref.watch(appClockProvider);
        final now = clock.nowUtc();
        final formats = AppDateFormats(Localizations.localeOf(context), clock);
        return [
          SliverList.builder(
            itemCount: rows.length,
            itemBuilder: (_, index) => _row(state, rows[index], formats, now),
          ),
          if (state.isLoadingMore)
            SliverToBoxAdapter(
              child: GuSkeletonList(
                semanticLabel: l10n.commonLoading,
                count: _nextPageRows,
              ),
            ),
          if (state.canTransfer) SliverToBoxAdapter(child: _transferCard(l10n)),
          if (!state.wantsMore)
            SliverToBoxAdapter(child: GuListEnd(label: l10n.commonAllDone)),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final state = ref.watch(manageMembersViewModelProvider(widget.clubId));
    final canSwitch = ref.watch(
      sessionViewModelProvider.select(
        (session) => ManagedClubPickerSheet.managedOf(session).length > 1,
      ),
    );
    final showCount = !state.isFetching && !state.isError;
    // Süzme + sıralama build başına bir kez (satırlar ve sayaç paylaşır).
    final rows = state.visible;

    return Scaffold(
      backgroundColor: gu.colors.bgCanvas,
      appBar: ManageHeader(
        club: state.club,
        title: l10n.mgtMembersTitle,
        onBack: goBack,
        backKey: GuKey.action('MGT-03.back'),
        role: state.role,
        isSuperAdmin: state.isSuperAdmin,
        onSwitchClub: canSwitch ? switchClub : null,
        switchClubKey: canSwitch ? GuKey.action('MGT-03.switchClub') : null,
        actions: [
          GuIconButton(
            key: GuKey.action('MGT-03.menu'),
            icon: GuIcons.moreVertical,
            semanticLabel: l10n.a11yMore,
            onPressed: openMenu,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.isReadOnly)
            GuBanner(kind: GuBannerKind.readonly, text: l10n.mgtReadOnlyBanner),
          Padding(
            padding: GuInsets.h16v8,
            child: GuInput(
              controller: searchController,
              icon: GuIcons.search,
              placeholder: l10n.membersSearch,
              semanticLabel: l10n.membersSearch,
              textInputAction: TextInputAction.search,
              onChanged: onQueryChanged,
              actionKey: GuKey.action('MGT-03.search'),
            ),
          ),
          // `.hscroll.pb16` yazılmıştır, ancak dikey dolgu 3 px kalır (K-59).
          GuHorizontalList(
            children: [
              for (final filter in ManageRoleFilter.values)
                GuChip(
                  key: _filterKey(filter),
                  label: _filterLabel(l10n, filter),
                  selected: state.roleFilter == filter,
                  onTap: () => selectFilter(filter),
                ),
            ],
          ),
          Padding(
            padding: GuInsets.only(
              left: GuSpacing.s16,
              right: GuSpacing.s16,
              bottom: GuSpacing.s16,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              spacing: GuSpacing.s8,
              children: [
                if (showCount)
                  Text(
                    l10n.membersTotal(state.totalCountFor(rows.length)),
                    maxLines: 1,
                    style: gu.text.labelL.copyWith(
                      color: gu.colors.textSecondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  )
                else
                  const SizedBox.shrink(),
                Flexible(
                  child: GuButton(
                    key: GuKey.action('MGT-03.sort'),
                    label: ManageMembersViewMixin.sortLabel(l10n, state.sort),
                    icon: GuIcons.arrowUpDown,
                    variant: GuButtonVariant.outline,
                    size: GuButtonSize.sm,
                    onPressed: openSort,
                  ),
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
                  ..._slivers(state, rows, l10n),
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
