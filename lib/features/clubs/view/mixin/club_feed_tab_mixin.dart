import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/clubs/provider/club_feed_state.dart';
import 'package:gu_kulupler/features/clubs/provider/club_feed_view_model.dart';
import 'package:gu_kulupler/features/clubs/view/widget/club_feed_tab.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/image_viewer_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/mixin/post_actions_mixin.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';

/// FED-01 davranışı: tür çipleri, sayfalama tetikleyicisi, gönderi kartının
/// eylemleri, SHT-09 / SHT-34 ve gezinme.
///
/// * Sayfalama: sekme CLB-03'ün kaydırma alanının içindedir; o alanın sonuna
///   bir ekran boyundan az kaldığında sonraki sayfa istenir. Sayfa geldiğinde
///   ya da süzgeç değiştiğinde liste hâlâ ekranı doldurmuyorsa istek
///   yinelenir — süzgeç, okunmamış sayfalardaki gönderileri de böyle bulur.
///   Okunamayan sayfa kendiliğinden yeniden denenmez (kullanıcı yeniden
///   kaydırınca ya da süzgeci değiştirince denenir).
/// * Beğeni, kaydet, oy, paylaş ve menü (SHT-08 → DLG-10 / SHT-10 / SHT-15;
///   toast'lar) ViewModel'dedir (`PostActionsMixin`). Yorumlar (SHT-09) ve
///   görsel görüntüleyici (SHT-34) buradan açılır.
/// * Gönderi gövdesi ve SHT-09 "Tümünü gör" FED-02'ye, yazar satırı CLB-07'ye
///   gider (`go`). FED-02'den geri dönülünce ve SHT-09 kapanınca o gönderi
///   yeniden okunur (beğeni, kayıt, yorum sayacı; kaldırıldıysa akıştan
///   çıkar).
/// * "Kulübüne bir şey yaz…" / "İlk gönderini yaz" ve SHT-08 "Düzenle"
///   FED-03'ü açar (`ComposeRoute`, `go`; düzenlemede `edit`). FED-03'ten
///   geri dönülünce akış iskelet göstermeden yeniden okunur (yeni gönderi
///   başa gelir); düzenlemeden dönüşte o gönderi yeniden okunur.
mixin ClubFeedTabMixin on ConsumerState<ClubFeedTab> {
  ScrollPosition? _position;
  ProviderSubscription<ClubFeedState>? _stateSubscription;

  /// FED-02'si ya da FED-03 düzenlemesi açılan gönderi: sayfa geri gelince
  /// yeniden okunur.
  String? _openedPostId;

  /// FED-03 (yeni gönderi) açıldı: sayfa geri gelince akış yenilenir.
  bool _composeOpened = false;
  bool _wasCurrent = true;

  /// Sekmenin ViewModel'i.
  ClubFeedViewModel get viewModel =>
      ref.read(clubFeedViewModelProvider(widget.clubId).notifier);

  ClubFeedState get _state =>
      ref.read(clubFeedViewModelProvider(widget.clubId));

  FeedbackService get _feedback => ref.read(feedbackServiceProvider);

  @override
  void initState() {
    super.initState();
    _stateSubscription = ref.listenManual(
      clubFeedViewModelProvider(widget.clubId),
      (previous, next) {
        // Görünen liste değişti (sayfa geldi, süzgeç): ekran hâlâ dolmuyorsa
        // sıradaki sayfa istenir.
        final changed =
            previous == null ||
            previous.posts.length != next.posts.length ||
            previous.cursor != next.cursor ||
            previous.filter != next.filter;
        if (!changed || !next.hasMore) return;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _loadMoreIfNearEnd(),
        );
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sekme CLB-03'ün kaydırma alanında çizilir; sayfalama o alanı izler.
    final position = Scrollable.maybeOf(context)?.position;
    if (!identical(position, _position)) {
      _position?.removeListener(_loadMoreIfNearEnd);
      _position = position?..addListener(_loadMoreIfNearEnd);
    }
    // Gönderi detayından (FED-02) ya da düzenlemeden (FED-03) geri dönüldü:
    // orada yapılan beğeni, kayıt, yorum, düzenleme ya da kaldırma akıştaki
    // karta yansısın diye gönderi yeniden okunur. Yeni gönderi ekranından
    // dönüşte akışın tamamı yenilenir (yayınlanan gönderi başa gelir).
    final isCurrent = ModalRoute.isCurrentOf(context) ?? true;
    if (isCurrent && !_wasCurrent) {
      final opened = _openedPostId;
      _openedPostId = null;
      if (_composeOpened) {
        _composeOpened = false;
        // Yenileme durumu hemen değiştirir; yapım sırasında değil, kare
        // bitince başlatılır.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(viewModel.refresh());
        });
      } else if (opened != null) {
        unawaited(viewModel.reloadPost(opened));
      }
    }
    _wasCurrent = isCurrent;
  }

  @override
  void dispose() {
    _stateSubscription?.close();
    _position?.removeListener(_loadMoreIfNearEnd);
    super.dispose();
  }

  /// Tür çipi (`FED-01.filter.<id>`).
  void selectFilter(FeedFilter filter) => viewModel.setFilter(filter);

  /// "Yeniden dene" (`FED-01.retry`).
  Future<void> retry() => viewModel.fetch();

  /// "Kulübüne bir şey yaz…" / "İlk gönderini yaz" (`FED-01.compose`) →
  /// FED-03.
  void compose() {
    if (!mounted) return;
    _composeOpened = true;
    ComposeRoute(clubId: widget.clubId).go(context);
  }

  /// Gönderi gövdesi (`FED-01.post.<postId>`) → FED-02.
  void openPost(PostModel post) {
    if (!mounted) return;
    _openedPostId = post.id;
    PostDetailRoute(clubId: post.clubId, postId: post.id).go(context);
  }

  /// Yazar satırı (`FED-01.author.<postId>`) → CLB-07, kulüp bağlamıyla.
  /// Hesabı silinmiş yazarın profili açılmaz (`cards.js:106`).
  void openAuthor(PostModel post) {
    if (_state.authorName(post.authorId) == null) return;
    ClubUserProfileRoute(
      userId: post.authorId,
      clubId: widget.clubId,
    ).go(context);
  }

  /// "…" (`FED-01.menu.<postId>`): SHT-08 ve seçilen satırın eylemi
  /// ViewModel'dedir; buraya yalnızca gezinme kalır.
  Future<void> openMenu(PostModel post) async {
    final outcome = await viewModel.openPostMenu(
      post.id,
      removedLabel: context.l10n.feedTypePost,
    );
    if (!mounted) return;
    switch (outcome) {
      case PostMenuOutcome.edit:
        // FED-03 düzenleme kipi; geri dönülünce gönderi yeniden okunur.
        _openedPostId = post.id;
        ComposeRoute(clubId: post.clubId, edit: post.id).go(context);
      case PostMenuOutcome.none:
      case PostMenuOutcome.removed:
        // Kaldırılan gönderi akıştan çıkar; sayfa yerinde kalır.
        break;
    }
  }

  /// Beğen (`FED-01.like.<postId>`).
  void like(PostModel post) => unawaited(viewModel.togglePostLike(post.id));

  /// Kaydet (`FED-01.save.<postId>`) → TST-11.
  void save(PostModel post) => unawaited(viewModel.togglePostSave(post.id));

  /// Paylaş (`FED-01.share.<postId>`) → SHT-15.
  void share(PostModel post) => unawaited(viewModel.sharePost(post.id));

  /// Anket seçeneği (`FED-01.vote.<postId>.<optionId>`) → TST-10.
  void vote(PostModel post, String optionId) =>
      unawaited(viewModel.votePost(post.id, optionId));

  /// Yorum (`FED-01.comment.<postId>`): SHT-09; "Tümünü gör" → FED-02. Sayfa
  /// kapanınca gönderi yeniden okunur (yorum sayacı). Gövde verilmediyse
  /// doğrudan FED-02 açılır.
  Future<void> openComments(PostModel post) async {
    final builder = widget.commentsSheetBuilder;
    if (builder == null) return openPost(post);
    final seeAll = await _feedback.showSheet<bool>(
      SheetId.sht09,
      builder: (_) => builder(post.clubId, post.id),
    );
    if (!mounted) return;
    if (seeAll ?? false) return openPost(post);
    await viewModel.reloadPost(post.id);
  }

  /// Görsel hücresi (`FED-01.image.<postId>.<index>`) → SHT-34.
  Future<void> openImage(PostModel post, int index) =>
      _feedback.showSheet<void>(
        SheetId.sht34,
        builder: (_) => ImageViewerSheet(
          images: post.images,
          initialIndex: index,
          club: _state.club,
          onShare: () => share(post),
        ),
      );

  /// Kaydırma alanının sonuna bir ekran boyundan az kaldıysa sonraki sayfayı
  /// ister.
  void _loadMoreIfNearEnd() {
    final position = _position;
    if (!mounted || position == null || !position.hasContentDimensions) return;
    if (!_state.hasMore) return;
    if (position.extentAfter < position.viewportDimension) {
      unawaited(viewModel.loadMore());
    }
  }
}
