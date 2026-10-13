import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/feed/provider/post_detail_view_model.dart';
import 'package:gu_kulupler/features/feed/view/post_detail_view.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/image_viewer_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/mixin/post_actions_mixin.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';
import 'package:gu_kulupler/product/navigation/routes/system_routes.dart';
import 'package:gu_ui/gu_ui.dart';

/// FED-02 davranışı: gezinme, gönderi ve yorum eylemleri, "içerik yok"
/// yönlendirmesi (prototip `PostDetail`, `screens-clubs.js:165–178`).
///
/// * Geri (`FED-02.back`) önceki sayfaya döner; yığın yoksa kulübün
///   "Gönderiler" sekmesine iner.
/// * Gönderi kartının eylemleri ViewModel'e gider (`PostActionsMixin`):
///   beğen / kaydet / oy / paylaş (SHT-15) / "…" (SHT-08). SHT-08'de gönderi
///   kaldırılınca ekran geri döner; "Düzenle" FED-03'ü açar (W-25, T-21).
/// * Yazar satırı ve yorum avatarı CLB-07'yi kulüp bağlamıyla açar. Yorumun
///   "…" düğmesi: kendi yorumu → DLG-11; başkası → SHT-27.
/// * Görsel hücresi SHT-34'ü açar.
/// * Yorum gönderilince liste sona kayar (`screens-clubs.js:170`).
/// * Gönderi yoksa / silinmişse / gizlenmişse SYS-04'e gidilir.
mixin PostDetailViewMixin on ConsumerState<PostDetailView> {
  /// İçeriğin kaydırma denetleyicisi.
  final ScrollController scrollController = ScrollController();

  ProviderSubscription<int>? _commentCountSubscription;
  bool _scrollToEndOnNextComment = false;

  /// Ekranın ViewModel sağlayıcısı (kulüp + gönderi ailesi).
  PostDetailViewModelProvider get provider => postDetailViewModelProvider(
    clubId: widget.clubId,
    postId: widget.postId,
  );

  /// Ekranın ViewModel'i.
  PostDetailViewModel get viewModel => ref.read(provider.notifier);

  FeedbackService get _feedback => ref.read(feedbackServiceProvider);

  @override
  void initState() {
    super.initState();
    // Ekran, gönderinin yokluğu zaten bilinirken açıldıysa (ViewModel
    // canlıydı).
    if (ref.read(provider).isNotFound) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _goNotFound());
    }
    // Gönderilen yorum listeye canlı akıştan gelir: geldiğinde sona kayılır.
    _commentCountSubscription = ref.listenManual(
      provider.select((state) => state.comments.length),
      (previous, next) {
        if (!_scrollToEndOnNextComment || next <= (previous ?? next)) return;
        _scrollToEndOnNextComment = false;
        _scrollToEnd();
      },
    );
  }

  @override
  void dispose() {
    _commentCountSubscription?.close();
    scrollController.dispose();
    super.dispose();
  }

  /// `build` içinde çağrılır: gönderi yok çıkarsa SYS-04'e gider.
  void watchNotFound() => ref.listen(
    provider.select((state) => state.isNotFound),
    (_, isNotFound) {
      if (isNotFound) _goNotFound();
    },
  );

  /// Geri (`FED-02.back`): önceki sayfa; yığın yoksa kulübün "Gönderiler"
  /// sekmesi.
  void goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      ClubDetailRoute(
        clubId: widget.clubId,
        tab: ClubDetailTab.posts,
      ).go(context);
    }
  }

  /// "Yeniden dene" (`FED-02.retry`).
  Future<void> retry() => viewModel.fetch();

  /// Yazar satırı / yorum avatarı (`FED-02.author.<id>`) → CLB-07, kulüp
  /// bağlamıyla.
  void openProfile(String userId) {
    if (!mounted) return;
    ClubUserProfileRoute(userId: userId, clubId: widget.clubId).go(context);
  }

  /// Beğen / geri al (`FED-02.like.<postId>`).
  void like() => unawaited(viewModel.togglePostLike(widget.postId));

  /// Kaydet / kaydı kaldır (`FED-02.save.<postId>`) → TST-11.
  void save() => unawaited(viewModel.togglePostSave(widget.postId));

  /// Paylaş (`FED-02.share.<postId>`) → SHT-15.
  void share() => unawaited(viewModel.sharePost(widget.postId));

  /// Anket seçeneği (`FED-02.vote.<postId>.<optionId>`) → TST-10.
  void vote(String optionId) =>
      unawaited(viewModel.votePost(widget.postId, optionId));

  /// "…" (`FED-02.menu.<postId>`) → SHT-08; seçilen satırdan sonra gezinme.
  Future<void> openMenu() async {
    final outcome = await viewModel.openPostMenu(
      widget.postId,
      removedLabel: context.l10n.feedTypePost,
    );
    if (!mounted) return;
    switch (outcome) {
      case PostMenuOutcome.none:
        break;
      case PostMenuOutcome.edit:
        // TODO(T-21): FED-03 düzenleme kipi açılır (`ComposeRoute(clubId,
        // edit: postId)`) — bağlama borcu W-25.
        break;
      case PostMenuOutcome.removed:
        goBack();
    }
  }

  /// Görsel hücresi (`FED-02.image.<postId>.<index>`) → SHT-34.
  Future<void> openImage(int index) async {
    final state = ref.read(provider);
    final post = state.post;
    if (post == null) return;
    await _feedback.showSheet<void>(
      SheetId.sht34,
      builder: (_) => ImageViewerSheet(
        images: post.images,
        initialIndex: index,
        club: state.club,
        onShare: share,
      ),
    );
  }

  /// Yorumun "…" düğmesi (`FED-02.commentMenu.<commentId>`): kendi yorumu →
  /// DLG-11; başkası → SHT-27 ("Profili gör" → CLB-07).
  Future<void> openCommentMenu(CommentModel comment) async {
    final outcome = await viewModel.openCommentMenu(
      comment.id,
      removedLabel: context.l10n.feedComment,
    );
    if (!mounted) return;
    switch (outcome) {
      case CommentMenuOutcome.none:
        break;
      case CommentMenuOutcome.viewProfile:
        openProfile(comment.authorId);
    }
  }

  /// Yorum gönderildi: liste sona kayar (yeni yorum geldiğinde bir kez daha).
  void onCommentSent() {
    _scrollToEndOnNextComment = true;
    _scrollToEnd();
  }

  void _scrollToEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted || !scrollController.hasClients) return;
    final end = scrollController.position.maxScrollExtent;
    final duration = context.gu.duration(GuMotion.base);
    if (duration == Duration.zero) {
      // Hareket azaltılmış: geçişsiz.
      scrollController.jumpTo(end);
      return;
    }
    unawaited(
      scrollController.animateTo(
        end,
        duration: duration,
        curve: GuMotion.easeStandard,
      ),
    );
  });

  void _goNotFound() {
    if (mounted) const NotFoundRoute().go(context);
  }
}
