import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/management/provider/manage_content_state.dart';
import 'package:gu_kulupler/features/management/provider/manage_content_view_model.dart';
import 'package:gu_kulupler/features/management/view/mixin/manage_content_view_mixin.dart';
import 'package:gu_kulupler/features/management/view/widget/manage_content_row.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/managed_club_picker_sheet.dart';
import 'package:gu_kulupler/product/widget/manage/manage_header.dart';
import 'package:gu_ui/gu_ui.dart';

/// İçerik yönetimi — `ManageContentRoute` (`/clubs/:clubId/manage/content`);
/// prototip `Content` (`screens-manage.js:159–167`). MGT-01 hızlı eylemi
/// "İçerik" açar (guard `V`, router'da); danışman salt okunur görür (bant,
/// FAB yok, menü satırları devre dışı).
///
/// Yukarıdan aşağıya: `ManageHeader` (geri · "İçerik yönetimi" / kulüp adı ·
/// rol rozeti) · danışmanda salt okunur bandı · `.px16.pb16.col.gap8`:
/// sekmeler (Gönderiler · Duyurular · Anketler) + arama · kaydırma alanı
/// (çek-yenile): `ManageContentRow` satırları (dokunuş FED-02, "⋮" → açılır
/// menü: sabitle / düzenle / sil) · "Gönderi" FAB (`+`, FED-03 — seçili
/// sekmenin türüyle).
///
/// Durumlar (sıra: hata → yükleniyor → boş → dolu) yalnızca listeyi
/// değiştirir; boş görünüm `empty-posts` + "İçerik yok" (arama sonucu da).
/// Çevrimdışı bandı kökte (kabuk) çizilir; yazan eylemler TST-24 verir.
///
/// Davranış `ManageContentViewModel` ve `ManageContentViewMixin`'dedir.
///
/// Design: MGT-08
class ManageContentView extends ConsumerStatefulWidget {
  /// [clubId] kulübünün içerik yönetimi; [tab] ilk açılan sekme.
  const ManageContentView({required this.clubId, this.tab, super.key});

  /// Kulüp kimliği (`ManageContentRoute.clubId`).
  final String clubId;

  /// İlk açılan sekme (gönderi / duyuru / anket); `null` → gönderiler.
  /// MGT-01 "Bu ay duyuru" duyurular sekmesini açar (prototip
  /// `go('MGT-08', { tab: 'announcements' })`).
  final PostType? tab;

  @override
  ConsumerState<ManageContentView> createState() => _ManageContentViewState();
}

class _ManageContentViewState extends ConsumerState<ManageContentView>
    with ManageContentViewMixin {
  /// Sekmeler, tasarım sırasıyla (`screens-manage.js:164`).
  static const List<PostType> _tabs = [
    PostType.post,
    PostType.announcement,
    PostType.poll,
  ];

  static final List<Key> _tabKeys = [
    for (final tab in _tabs)
      switch (tab) {
        PostType.post => GuKey.action('MGT-08.tab.posts'),
        PostType.announcement => GuKey.action('MGT-08.tab.announcements'),
        PostType.poll => GuKey.action('MGT-08.tab.polls'),
      },
  ];

  /// Sonraki sayfa okunurken liste sonunda çizilen iskelet satırı sayısı.
  static const int _nextPageRows = 3;

  static String _tabLabel(AppLocalizations l10n, PostType tab) => switch (tab) {
    PostType.post => l10n.contentTabPosts,
    PostType.announcement => l10n.contentTabAnnouncements,
    PostType.poll => l10n.contentTabPolls,
  };

  List<Widget> _slivers(ManageContentState state, AppLocalizations l10n) {
    final rows = state.visible;
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
              retryActionKey: GuKey.action('MGT-08.retry'),
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
              illustration: GuIllustrations.emptyPosts,
              title: l10n.contentEmpty,
            ),
          ),
          if (state.isLoadingMore)
            SliverToBoxAdapter(
              child: GuSkeletonList(
                semanticLabel: l10n.commonLoading,
                count: _nextPageRows,
              ),
            ),
        ];
      case GuListStatus.data:
        return [
          SliverList.builder(
            itemCount: rows.length,
            itemBuilder: (_, index) {
              final post = rows[index];
              return ManageContentRow(
                key: ValueKey<String>(post.id),
                post: post,
                actionKey: GuKey.action('MGT-08.row.${post.id}'),
                menuKey: GuKey.action('MGT-08.menu.${post.id}'),
                onTap: () => openPost(post.id),
                onMenu: () => openMenu(post),
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
    final gu = context.gu;
    final l10n = context.l10n;
    final state = ref.watch(manageContentViewModelProvider(widget.clubId));
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
        title: l10n.contentTitle,
        onBack: goBack,
        backKey: GuKey.action('MGT-08.back'),
        role: state.role,
        isSuperAdmin: state.isSuperAdmin,
        onSwitchClub: canSwitch ? switchClub : null,
        switchClubKey: canSwitch ? GuKey.action('MGT-08.switchClub') : null,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: GuSpacing.s8,
                  children: [
                    GuSegmented(
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
                    GuInput(
                      controller: searchController,
                      icon: GuIcons.search,
                      placeholder: l10n.commonSearch,
                      semanticLabel: l10n.commonSearch,
                      textInputAction: TextInputAction.search,
                      onChanged: onQueryChanged,
                      actionKey: GuKey.action('MGT-08.search'),
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
              key: GuKey.action('MGT-08.create'),
              label: l10n.feedTypePost,
              icon: GuIcons.plus,
              semanticLabel: l10n.composeTitle,
              onPressed: create,
            ),
        ],
      ),
    );
  }
}
