import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/profile/provider/saved_state.dart';
import 'package:gu_kulupler/features/profile/provider/saved_view_model.dart';
import 'package:gu_kulupler/features/profile/view/mixin/saved_view_mixin.dart';
import 'package:gu_kulupler/features/profile/view/widget/saved_post_card.dart';
import 'package:gu_kulupler/product/format/relative_time_formatter.dart';
import 'package:gu_kulupler/product/widget/system/offline_list_fallback.dart';
import 'package:gu_ui/gu_ui.dart';

/// "Kaydedilenler" ekranı — `SavedRoute` (`/profile/saved`); prototip
/// `Saved` (`screens-profile.js:52–56`).
///
/// Yukarıdan aşağıya: başlık çubuğu (geri · "Kaydedilenler") · kaydırma
/// alanı (çek-yenile): `SavedPostCard` kartları (yatay 16, aralık 12).
///
/// * Kart: "kulüp · göreli zaman" · başlık · 2 satır metin · yer imi
///   ("Kaydı kaldır" → TST-11 + "Geri al"). Silinmiş / gizlenmiş gönderi
///   "İçerik kaldırıldı" satırıdır (dokunulamaz, çöp kutusuyla kaldırılır).
/// * Durumlar (hata → yükleniyor → boş → dolu): hata "Bir şeyler ters
///   gitti" + "Yeniden dene"; yükleniyor 3 kart iskeleti; boş "Kaydettiğin
///   gönderiler burada görünür". Çevrimdışı bandı kökte; kaldırma TST-24.
/// * Kayıtlar 20'lik sayfalarla okunur; sonraki sayfa okunurken liste
///   sonunda kart iskeleti çizilir.
///
/// Davranış `SavedViewModel` ve `SavedViewMixin`'dedir.
///
/// Design: PRF-04
class SavedView extends ConsumerStatefulWidget {
  /// Kaydedilen gönderiler.
  const SavedView({super.key});

  @override
  ConsumerState<SavedView> createState() => _SavedViewState();
}

class _SavedViewState extends ConsumerState<SavedView> with SavedViewMixin {
  /// Prototip `ListState n=3 variant="card"`.
  static const int _skeletonCards = 3;

  /// Sonraki sayfa okunurken liste sonunda çizilen iskelet kartı sayısı.
  static const int _nextPageCards = 1;

  /// Kart başlığındaki ayraç (`club.name · rel`).
  static const String _separator = ' · ';

  Widget _card(
    SavedState state,
    SavedEntry entry,
    RelativeTimeFormatter relative,
  ) {
    final (saved, post) = entry;
    final id = saved.postId;
    final removed = SavedState.isRemoved(post);
    final created = post?.createdAt;
    final meta = removed || post == null
        ? null
        : [
            ?state.clubNames[post.clubId],
            if (created != null) relative.format(created),
          ].join(_separator);
    return SavedPostCard(
      key: ValueKey<String>(id),
      post: removed ? null : post,
      meta: meta == null || meta.isEmpty ? null : meta,
      cardKey: GuKey.action('PRF-04.post.$id'),
      unsaveKey: GuKey.action('PRF-04.unsave.$id'),
      onOpen: () => openPost(clubId: saved.clubId, postId: id),
      onUnsave: () => unsave(id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final state = ref.watch(savedViewModelProvider);
    final relative = RelativeTimeFormatter(l10n, ref.watch(appClockProvider));
    final visible = state.visible;
    final status = GuListStatus.resolve(
      isError: state.isError,
      isLoading: state.isFetching || (visible.isEmpty && state.isLoadingMore),
      isEmpty: visible.isEmpty,
    );

    return Scaffold(
      backgroundColor: gu.colors.bgCanvas,
      appBar: GuAppBar(
        title: l10n.savedTitle,
        onBack: goBack,
        backSemanticLabel: l10n.a11yBack,
        backActionKey: GuKey.action('PRF-04.back'),
      ),
      body: GuRefresh(
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
                    retryActionKey: GuKey.action('PRF-04.retry'),
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
                    illustration: GuIllustrations.emptyPosts,
                    title: l10n.savedEmpty,
                  ),
                ),
              ],
              GuListStatus.data => [
                SliverPadding(
                  padding: GuInsets.sym(h: GuSpacing.s16),
                  sliver: SliverList.separated(
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => GuGap.v12,
                    itemBuilder: (_, index) =>
                        _card(state, visible[index], relative),
                  ),
                ),
                if (state.isLoadingMore)
                  SliverPadding(
                    padding: GuInsets.only(top: GuSpacing.s12),
                    sliver: SliverToBoxAdapter(
                      child: GuSkeletonList(
                        semanticLabel: l10n.commonLoading,
                        count: _nextPageCards,
                        variant: GuSkeletonVariant.card,
                      ),
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
    );
  }
}
