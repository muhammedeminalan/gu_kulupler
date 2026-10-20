import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/feed/provider/post_detail_state.dart';
import 'package:gu_kulupler/features/feed/view/mixin/post_detail_view_mixin.dart';
import 'package:gu_kulupler/features/feed/view/widget/comment_composer.dart';
import 'package:gu_kulupler/product/media/post_image_resolver.dart';
import 'package:gu_kulupler/product/media/user_avatar_image.dart';
import 'package:gu_kulupler/product/widget/post/comment_row.dart';
import 'package:gu_kulupler/product/widget/post/post_card.dart';
import 'package:gu_ui/gu_ui.dart';

/// FED-02 "Gönderi" — gönderi detayı ve yorumlar (prototip `S['FED-02']`,
/// `screens-clubs.js:165–178`). `PostDetailRoute` açar
/// (`/clubs/:clubId/posts/:postId`, guard `üye` — router'da).
///
/// Yukarıdan aşağıya: başlık çubuğu (geri · "Gönderi" · kulüp adı) · kaydırma
/// alanı (`px16 col gap16`): gönderi kartı (`PostCard`, tam metin + kulüp
/// adı), "{n} yorum" başlığı, yorum satırları (`CommentRow`, `col gap4`) ·
/// altta yorum yazma çubuğu (avatar 36 + metin alanı + "Gönder"; danışmanda
/// salt okunur bant).
///
/// * Gönderi ve yorumlar canlıdır (`PostDetailViewModel`). Durum sırası:
///   hata ("Bir şeyler ters gitti" + "Yeniden dene") → yükleniyor (kart +
///   satır iskeleti) → dolu; yorum bloğunun kendi sırası: hata → iskelet →
///   boş ("İlk yorumu sen yaz.") → satırlar. Çevrimdışı bandı kökte çizilir;
///   içerik ekranda kalır, yazan eylemler TST-24 verir.
/// * Gönderi yoksa, silinmişse ya da gizlenmişse SYS-04'e gidilir.
/// * Yorum sayısı ve liste engellenen yazarların yorumlarını içermez.
/// * Klavye açıkken yorum çubuğu klavyenin üstünde kalır (`GuStickyCta`).
/// * Toast alt çubuğun (yorum çubuğu / salt okunur bant) üstünde çıkar
///   (`GuToastBottomObstacle`).
///
/// Davranış `PostDetailViewMixin`'dedir.
///
/// Design: FED-02
class PostDetailView extends ConsumerStatefulWidget {
  /// [clubId] kulübünün [postId] gönderisi.
  const PostDetailView({
    required this.clubId,
    required this.postId,
    super.key,
  });

  /// Kulüp kimliği (`PostDetailRoute.clubId`).
  final String clubId;

  /// Gönderi kimliği (`PostDetailRoute.postId`).
  final String postId;

  @override
  ConsumerState<PostDetailView> createState() => _PostDetailViewState();
}

class _PostDetailViewState extends ConsumerState<PostDetailView>
    with PostDetailViewMixin {
  /// Yorum bloğu iskeletindeki satır sayısı.
  static const int _skeletonComments = 3;

  /// `screens-clubs.js:177` `Avatar size=36` — `GuSizes.avatarSizes`
  /// kümesindeki değer.
  static final double _composerAvatarSize = GuSizes.avatarSizes[2];

  /// Gönderi okunurken: kart + yorum satırı iskeleti.
  Widget _skeleton() {
    final l10n = context.l10n;
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GuSkeletonList(
            semanticLabel: l10n.commonLoading,
            count: 1,
            variant: GuSkeletonVariant.card,
          ),
          GuSkeletonList(
            semanticLabel: l10n.commonLoading,
            count: _skeletonComments,
          ),
        ],
      ),
    );
  }

  /// Yorum bloğu (sıra: hata → iskelet → boş → satırlar).
  Widget _comments(PostDetailState state, List<CommentModel> comments) {
    final gu = context.gu;
    final l10n = context.l10n;
    if (state.isCommentsError) {
      return GuErrorState(
        title: l10n.sysErrorTitle,
        description: l10n.sysErrorDesc,
        retryLabel: l10n.commonRetry,
        retryActionKey: GuKey.action('FED-02.retry'),
        inline: true,
        onRetry: retry,
      );
    }
    if (state.isFetchingComments) {
      return GuSkeletonList(
        semanticLabel: l10n.commonLoading,
        count: _skeletonComments,
      );
    }
    if (comments.isEmpty) {
      return Padding(
        padding: GuInsets.all16,
        child: Text(
          l10n.postNoComments,
          style: gu.text.bodyS.copyWith(color: gu.colors.textMuted),
          textAlign: TextAlign.center,
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: GuSpacing.s4,
      children: [
        for (final comment in comments)
          CommentRow(
            key: ValueKey<String>(comment.id),
            comment: comment,
            author: state.authorOf(comment.authorId),
            authorAvatar: ref.userAvatarImage(
              state.authorOf(comment.authorId),
              displaySize: GuSizes.commentAvatar,
            ),
            role: state.roles[comment.authorId],
            authorKey: GuKey.action('FED-02.author.${comment.id}'),
            // Silinmiş kullanıcının profili yoktur: avatar düz kalır.
            onAuthor: state.authorOf(comment.authorId) == null
                ? null
                : () => openProfile(comment.authorId),
            menuKey: GuKey.action('FED-02.commentMenu.${comment.id}'),
            onMenu: () => openCommentMenu(comment),
          ),
      ],
    );
  }

  /// Gönderi kartı + yorumlar.
  Widget _content(PostDetailState state, PostModel post, String? uid) {
    final gu = context.gu;
    final comments = state.visibleComments;
    final author = state.authorOf(post.authorId);
    return GuRefresh(
      onRefresh: refresh,
      noSafe: true,
      child: SingleChildScrollView(
        controller: scrollController,
        padding: GuInsets.only(
          left: GuSpacing.s16,
          right: GuSpacing.s16,
          bottom: GuSizes.screenScrollBottomExtra,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: GuSpacing.s16,
          children: [
            PostCard(
              post: post,
              author: author,
              authorAvatar: ref.userAvatarImage(
                author,
                displaySize: GuSizes.postAvatar,
              ),
              role: state.roles[post.authorId],
              club: state.club,
              liked: uid != null && post.likedBy(uid),
              saved: state.isSaved,
              myOptionId: state.myOptionId,
              pollResults: state.pollResults,
              expanded: true,
              showClub: true,
              keys: PostCardKeys(
                author: GuKey.action('FED-02.author.${post.id}'),
                menu: GuKey.action('FED-02.menu.${post.id}'),
                post: GuKey.action('FED-02.post.${post.id}'),
                like: GuKey.action('FED-02.like.${post.id}'),
                comment: GuKey.action('FED-02.comment.${post.id}'),
                share: GuKey.action('FED-02.share.${post.id}'),
                save: GuKey.action('FED-02.save.${post.id}'),
                image: (index) =>
                    GuKey.action('FED-02.image.${post.id}.$index'),
                vote: (optionId) =>
                    GuKey.action('FED-02.vote.${post.id}.$optionId'),
              ),
              onAuthor: author == null
                  ? null
                  : () => openProfile(post.authorId),
              onMenu: openMenu,
              onLike: like,
              onShare: share,
              onSave: save,
              onVote: vote,
              onImage: openImage,
              // Görseller Storage'dan çözülür; adres gelene dek yer tutucu
              // (K-18). Yalnızca bu gönderinin yolları izlenir (T-44).
              imageOf: ref.postImagesOf(post.images),
            ),
            Semantics(
              header: true,
              child: Text(
                context.l10n.postComments(comments.length),
                style: gu.text.titleS.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            _comments(state, comments),
          ],
        ),
      ),
    );
  }

  /// Alt çubuk: yorum yazma satırı; danışmanda salt okunur bant
  /// (`screens-clubs.js:177`).
  Widget _bottomBar({required bool isAdvisor, required UserModel? me}) {
    final gu = context.gu;
    final l10n = context.l10n;
    if (isAdvisor) {
      return ColoredBox(
        color: gu.colors.bgSurfaceMuted,
        child: SafeArea(
          top: false,
          child: GuBanner(
            kind: GuBannerKind.readonly,
            text: l10n.postAdvisorNoComment,
          ),
        ),
      );
    }
    final name = me?.name ?? '';
    return GuStickyCta(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: CommentComposer(
            clubId: widget.clubId,
            postId: widget.postId,
            inputKey: GuKey.action('FED-02.commentInput'),
            sendKey: GuKey.action('FED-02.sendComment'),
            leading: GuAvatar(
              initials: name.initials,
              seed: me?.avatarSeed ?? name,
              size: _composerAvatarSize,
              image: ref.userAvatarImage(
                me,
                displaySize: _composerAvatarSize,
              ),
            ),
            onSent: onCommentSent,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final state = ref.watch(provider);
    final uid = ref.watch(
      sessionViewModelProvider.select((session) => session.uid),
    );
    final me = ref.watch(
      sessionViewModelProvider.select((session) => session.user),
    );
    final isAdvisor = ref.watch(
      sessionViewModelProvider.select(
        (session) => session.accessTo(widget.clubId) == ClubAccess.advisor,
      ),
    );
    watchNotFound();
    final post = state.post;

    // Sıra: hata → yükleniyor → dolu (yorum bloğunun boş durumu içeride).
    // Hata yalnızca gönderi hiç okunamadığında tam ekrandır; içerik varken
    // gelen hata içeriği silmez.
    final Widget body;
    if (post != null) {
      body = _content(state, post, uid);
    } else if (state.isError) {
      body = Center(
        child: SingleChildScrollView(
          child: GuErrorState(
            title: l10n.sysErrorTitle,
            description: l10n.sysErrorDesc,
            retryLabel: l10n.commonRetry,
            retryActionKey: GuKey.action('FED-02.retry'),
            onRetry: retry,
          ),
        ),
      );
    } else if (state.isNotFound) {
      // SYS-04'e gidilir; geçiş karesinde boş zemin kalır.
      body = const SizedBox.expand();
    } else {
      body = _skeleton();
    }

    return Scaffold(
      backgroundColor: gu.colors.bgCanvas,
      appBar: GuAppBar(
        title: l10n.postTitle,
        subtitle: post == null ? null : state.club?.name,
        onBack: goBack,
        backSemanticLabel: l10n.a11yBack,
        backActionKey: GuKey.action('FED-02.back'),
      ),
      body: body,
      // Toast alt çubuğun üstünde durur ("Gönder" düğmesine binmez).
      bottomNavigationBar: post == null
          ? null
          : GuToastBottomObstacle(
              child: _bottomBar(isAdvisor: isAdvisor, me: me),
            ),
    );
  }
}
