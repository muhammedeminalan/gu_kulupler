import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/feed/provider/post_detail_state.dart';
import 'package:gu_kulupler/features/feed/provider/post_detail_view_model.dart';
import 'package:gu_kulupler/features/feed/view/widget/comment_composer.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/widget/post/comment_row.dart';
import 'package:gu_ui/gu_ui.dart';

/// SHT-09 "Yorumlar" — akıştaki gönderi kartının yorum düğmesinden açılan
/// yorum sayfası (prototip `SHEETS['SHT-09']`, `sheets.js:45–48`).
///
/// * Başlık "{n} yorum" (yorum yokken "Yorumlar"); yanında "Tümünü gör".
///   Gövde yorum satırlarıdır (`CommentRow`; rol rozeti, profil ve menü
///   yok), en az 200 px; yorum yokken "İlk yorumu sen yaz.". Alt bölüm yorum
///   yazma satırıdır (`CommentComposer`); danışmanda "Danışman olarak yorum
///   yazamazsın." notu.
/// * Sayfa `features/feed` altındadır ve `PostDetailViewModel(clubId,
///   postId)` ailesine bağlanır: yorumlar canlıdır, sayfa açıkken dinlenir.
///   Durum sırası: hata → iskelet → boş → satırlar. Gönderi artık yoksa
///   (silinmiş / gizlenmiş) sayfa kapanır.
/// * FED-01 (`features/clubs`) onu içe aktaramaz: gövdeyi rota (kompozisyon
///   kökü) verir — `commentsSheetBuilder` (`clubs_routes.dart`).
/// * Sonuç (`pop`): "Tümünü gör" → `true` (çağıran `PostDetailRoute`'a
///   gider); X / scrim / sürükleme / geri → `null`.
/// * Anahtarlar `SHT-09.seeAll`, `SHT-09.input`, `SHT-09.send`,
///   `SHT-09.close` (+ `SHT-09.scrim`, `FeedbackService`).
///
/// ```dart
/// final seeAll = await feedback.showSheet<bool>(
///   SheetId.sht09,
///   builder: (_) => commentsSheetBuilder(post.clubId, post.id),
/// );
/// if (seeAll ?? false) PostDetailRoute(clubId: …, postId: …).go(context);
/// ```
///
/// Design: SHT-09
class CommentsSheet extends ConsumerWidget {
  /// [clubId] kulübünün [postId] gönderisinin yorumları.
  const CommentsSheet({
    required this.clubId,
    required this.postId,
    super.key,
  });

  /// Kulüp kimliği.
  final String clubId;

  /// Gönderi kimliği.
  final String postId;

  /// "Tümünü gör" düğmesinin anahtarı (`SHT-09.seeAll`).
  static final Key seeAllKey = FeedbackKeys.of(
    SheetId.sht09.designId,
    'seeAll',
  );

  /// Yorum alanının anahtarı (`SHT-09.input`).
  static final Key inputKey = FeedbackKeys.of(SheetId.sht09.designId, 'input');

  /// "Gönder" düğmesinin anahtarı (`SHT-09.send`).
  static final Key sendKey = FeedbackKeys.of(SheetId.sht09.designId, 'send');

  /// Yükleniyor iskeletindeki satır sayısı.
  static const int _skeletonRows = 3;

  /// Gövde (sıra: hata → iskelet → boş → satırlar).
  Widget _body(
    BuildContext context,
    PostDetailState state,
    List<CommentModel> comments, {
    required Future<void> Function() onRetry,
  }) {
    final gu = context.gu;
    final l10n = context.l10n;
    if (state.isError || state.isCommentsError) {
      return GuErrorState(
        title: l10n.sysErrorTitle,
        description: l10n.sysErrorDesc,
        retryLabel: l10n.commonRetry,
        retryActionKey: FeedbackKeys.of(SheetId.sht09.designId, 'retry'),
        inline: true,
        onRetry: onRetry,
      );
    }
    if (state.isFetchingComments) {
      return GuSkeletonList(
        semanticLabel: l10n.commonLoading,
        count: _skeletonRows,
      );
    }
    if (comments.isEmpty) {
      return Padding(
        padding: GuInsets.sym(v: GuSpacing.s32),
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
      children: [
        for (final comment in comments)
          CommentRow(
            key: ValueKey<String>(comment.id),
            comment: comment,
            author: state.authorOf(comment.authorId),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gu = context.gu;
    final l10n = context.l10n;
    final provider = postDetailViewModelProvider(
      clubId: clubId,
      postId: postId,
    );
    final state = ref.watch(provider);
    final isAdvisor = ref.watch(
      sessionViewModelProvider.select(
        (session) => session.accessTo(clubId) == ClubAccess.advisor,
      ),
    );
    // Gönderi artık yok (silinmiş / gizlenmiş): sayfa kapanır.
    ref.listen(provider.select((state) => state.isNotFound), (_, isNotFound) {
      if (isNotFound && context.mounted && context.canPop()) context.pop();
    });
    final comments = state.visibleComments;

    return GuSheetFrame(
      title: l10n.postComments(comments.length),
      closeSemanticLabel: l10n.a11yClose,
      closeKey: FeedbackKeys.of(SheetId.sht09.designId, 'close'),
      headerExtra: GuButton(
        key: seeAllKey,
        label: l10n.sht09SeeAll,
        size: GuButtonSize.sm,
        variant: GuButtonVariant.text,
        onPressed: () => context.pop(true),
      ),
      footer: [
        if (isAdvisor)
          Expanded(
            child: Text(
              l10n.postAdvisorNoComment,
              style: gu.text.bodyS.copyWith(color: gu.colors.textMuted),
            ),
          )
        else
          Expanded(
            child: CommentComposer(
              clubId: clubId,
              postId: postId,
              inputKey: inputKey,
              sendKey: sendKey,
            ),
          ),
      ],
      body: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: GuSizes.commentsSheetMinHeight,
        ),
        child: _body(
          context,
          state,
          comments,
          onRetry: () => ref.read(provider.notifier).fetch(),
        ),
      ),
    );
  }
}
