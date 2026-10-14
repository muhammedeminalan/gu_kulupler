import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/clubs/provider/club_feed_state.dart';
import 'package:gu_kulupler/features/clubs/provider/club_feed_view_model.dart';
import 'package:gu_kulupler/features/clubs/view/mixin/club_feed_tab_mixin.dart';
import 'package:gu_kulupler/features/clubs/view/widget/feed_compose_entry.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/media/post_image_resolver.dart';
import 'package:gu_kulupler/product/media/user_avatar_image.dart';
import 'package:gu_kulupler/product/widget/post/image_grid.dart';
import 'package:gu_kulupler/product/widget/post/post_card.dart';
import 'package:gu_ui/gu_ui.dart';

/// Akış — CLB-03 "Gönderiler" sekmesinin gövdesi (kulübün içini görenler;
/// görmeyene CLB-03 kilitli bloğu çizer). Prototip `Feed`
/// (`screens-clubs.js:59–72`); bağımsız rota değildir (CD-10).
///
/// Üst dolgu 16, aralık 12'lik sütun: (yöneticiye) "Kulübüne bir şey yaz…"
/// girişi · tür çipleri ("Tümü" / "Duyurular" / "Anketler" / "Görseller") ·
/// liste: sabit gönderi en üstte, ardından en yeniden eskiye `PostCard`'lar
/// (yatay 16, aralık 12) ve liste sonu "— Hepsi bu kadar —".
///
/// * Kaydırma CLB-03'ündür (sekme onun kaydırma alanında çizilir); sonuna
///   yaklaşınca sonraki 20 gönderi okunur, okunurken liste sonunda bir kart
///   iskeleti çizilir.
/// * Durumlar yalnızca listeyi değiştirir (sıra: hata → yükleniyor → boş →
///   dolu); giriş ve çipler yerinde kalır. Hata: "Bir şeyler ters gitti" +
///   "Yeniden dene"; yükleniyor: 3 kart iskeleti; boş (hiç gönderi yok ya da
///   süzgece uyan yok): "Henüz gönderi yok" — yöneticiye "İlk gönderini yaz"
///   düğmesiyle. Çevrimdışı bandı kökte çizilir; akış önbellekteki veriyle
///   kalır, yazan eylemler TST-24 verir.
/// * Danışman akışı okur; beğeni, oy ve yönetim eylemleri TST-26 verir.
/// * Engellenen kullanıcıların gönderileri çizilmez.
/// * Gönderi görselleri `postImageResolverProvider` ile Storage'dan çözülür;
///   adres gelene (ya da alınamazsa) dek hücre yer tutucu desendir (K-18).
///
/// Davranış `ClubFeedTabMixin`'dedir.
///
/// Design: FED-01
class ClubFeedTab extends ConsumerStatefulWidget {
  /// [clubId] kulübünün gönderi akışı.
  const ClubFeedTab({
    required this.clubId,
    this.commentsSheetBuilder,
    super.key,
  });

  /// Kulüp kimliği (`ClubFeedViewModel` ailesi).
  final String clubId;

  /// Yorum sayfasının (SHT-09) gövdesi — `features/feed`'dedir, rota verir
  /// (`commentsSheetBuilder`, `clubs_routes.dart`). Verilmezse yorum düğmesi
  /// gönderi detayına (FED-02) gider.
  final Widget Function(String clubId, String postId)? commentsSheetBuilder;

  @override
  ConsumerState<ClubFeedTab> createState() => _ClubFeedTabState();
}

class _ClubFeedTabState extends ConsumerState<ClubFeedTab>
    with ClubFeedTabMixin {
  /// Yükleniyor iskeletindeki kart sayısı (prototip `ListState n=3`,
  /// `screens-clubs.js:69`).
  static const int _skeletonCards = 3;

  /// Sonraki sayfa okunurken liste sonunda çizilen iskelet kartı sayısı.
  static const int _nextPageCards = 1;

  static String _filterLabel(AppLocalizations l10n, FeedFilter filter) =>
      switch (filter) {
        FeedFilter.all => l10n.commonAll,
        FeedFilter.announcements => l10n.feedFilterAnnouncements,
        FeedFilter.polls => l10n.feedFilterPolls,
        FeedFilter.images => l10n.feedFilterImages,
      };

  static Key _filterKey(FeedFilter filter) => switch (filter) {
    FeedFilter.all => GuKey.action('FED-01.filter.all'),
    FeedFilter.announcements => GuKey.action('FED-01.filter.announcements'),
    FeedFilter.polls => GuKey.action('FED-01.filter.polls'),
    FeedFilter.images => GuKey.action('FED-01.filter.images'),
  };

  Widget _card(
    ClubFeedState state,
    PostModel post,
    String? uid,
    PostImageResolver imageOf,
  ) {
    final author = state.users[post.authorId];
    return PostCard(
      key: ValueKey<String>(post.id),
      post: post,
      author: author == null || author.isAnonymized ? null : author,
      authorAvatar: ref.userAvatarImage(author),
      role: state.roles[post.authorId],
      club: state.club,
      liked: uid != null && post.likedBy(uid),
      saved: state.savedPostIds.contains(post.id),
      myOptionId: state.myVotes[post.id],
      pollResults: state.pollResults[post.id] ?? const <String, int>{},
      keys: PostCardKeys(
        author: GuKey.action('FED-01.author.${post.id}'),
        menu: GuKey.action('FED-01.menu.${post.id}'),
        post: GuKey.action('FED-01.post.${post.id}'),
        more: GuKey.action('FED-01.more.${post.id}'),
        like: GuKey.action('FED-01.like.${post.id}'),
        comment: GuKey.action('FED-01.comment.${post.id}'),
        share: GuKey.action('FED-01.share.${post.id}'),
        save: GuKey.action('FED-01.save.${post.id}'),
        image: (index) => GuKey.action('FED-01.image.${post.id}.$index'),
        vote: (optionId) => GuKey.action('FED-01.vote.${post.id}.$optionId'),
      ),
      onOpen: () => openPost(post),
      onAuthor: () => openAuthor(post),
      onMenu: () => openMenu(post),
      onLike: () => like(post),
      onComment: () => openComments(post),
      onShare: () => share(post),
      onSave: () => save(post),
      onVote: (optionId) => vote(post, optionId),
      onImage: (index) => openImage(post, index),
      imageOf: imageOf,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(clubFeedViewModelProvider(widget.clubId));
    final (uid, me, canCompose) = ref.watch(
      sessionViewModelProvider.select(
        (session) => (
          session.uid,
          session.user,
          RolePolicy.can(
            ClubPermission.createPost,
            session.roleIn(widget.clubId),
            isSuper: session.isSuperAdmin,
          ),
        ),
      ),
    );
    final posts = state.visible;
    // Gönderi görselleri Storage'dan çözülür; adres gelene dek yer tutucu
    // (K-18).
    final imageOf = ref.watch(postImageResolverProvider);
    final status = GuListStatus.resolve(
      isError: state.isError,
      // Süzgece uyan gönderi yok ama okunmamış sayfa var: sıradaki sayfalar
      // okunana dek iskelet (boş durum akış bitince çizilir).
      isLoading: state.isFetching || (posts.isEmpty && state.hasMore),
      isEmpty: posts.isEmpty,
    );

    return Padding(
      padding: GuInsets.only(top: GuSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: GuSpacing.s12,
        children: [
          if (canCompose)
            Padding(
              padding: GuInsets.h16,
              child: FeedComposeEntry(
                key: GuKey.action('FED-01.compose'),
                user: me,
                avatarImage: ref.userAvatarImage(me),
                onTap: compose,
              ),
            ),
          GuHorizontalList(
            children: [
              for (final filter in FeedFilter.values)
                GuChip(
                  key: _filterKey(filter),
                  label: _filterLabel(l10n, filter),
                  selected: state.filter == filter,
                  onTap: () => selectFilter(filter),
                ),
            ],
          ),
          switch (status) {
            GuListStatus.error => GuErrorState(
              title: l10n.sysErrorTitle,
              description: l10n.sysErrorDesc,
              retryLabel: l10n.commonRetry,
              retryActionKey: GuKey.action('FED-01.retry'),
              inline: true,
              onRetry: retry,
            ),
            GuListStatus.loading => GuSkeletonList(
              semanticLabel: l10n.commonLoading,
              count: _skeletonCards,
              variant: GuSkeletonVariant.card,
            ),
            GuListStatus.empty => GuEmptyState(
              illustration: GuIllustrations.emptyPosts,
              title: l10n.feedEmptyTitle,
              description: canCompose
                  ? l10n.feedEmptyDescManager
                  : l10n.feedEmptyDesc,
              ctaLabel: canCompose ? l10n.feedEmptyCta : null,
              onCta: canCompose ? compose : null,
              ctaActionKey: canCompose ? GuKey.action('FED-01.compose') : null,
            ),
            GuListStatus.data => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: GuInsets.h16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: GuSpacing.s12,
                    children: [
                      for (final post in posts)
                        _card(state, post, uid, imageOf),
                    ],
                  ),
                ),
                if (state.isLoadingMore)
                  Padding(
                    padding: GuInsets.only(top: GuSpacing.s12),
                    child: GuSkeletonList(
                      semanticLabel: l10n.commonLoading,
                      count: _nextPageCards,
                      variant: GuSkeletonVariant.card,
                    ),
                  ),
                if (!state.hasMore) GuListEnd(label: l10n.commonAllDone),
              ],
            ),
          },
        ],
      ),
    );
  }
}
