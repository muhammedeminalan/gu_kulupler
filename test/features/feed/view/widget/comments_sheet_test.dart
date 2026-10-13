// SHT-09 · Yorumlar — içerik ("{n} yorum" başlığı, "Tümünü gör", yorum
// satırları, yorum yazma satırı / danışman notu), durumlar (yükleniyor, hata,
// boş), sonuç değeri ("Tümünü gör" → true, kapat → null), canlı akış (yaz →
// TST-12 → yeni satır; gönderi gizlenince sayfa kapanır), cihaz matrisi, açık
// + koyu golden. Referans: design/reference-shots/sheets/SHT-09__*.webp,
// design/prototype/app/sheets.js:45–48.
//
// Sayfa gerçek `AppFeedbackService` + go_router gezgininde açılır
// (`ClubSheetHarness`); durum testlerinde ViewModel durumu ezilir, akış
// testlerinde gerçek ViewModel sahte depolarla çalışır.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/feed/provider/post_detail_state.dart';
import 'package:gu_kulupler/features/feed/provider/post_detail_view_model.dart';
import 'package:gu_kulupler/features/feed/view/widget/comment_composer.dart';
import 'package:gu_kulupler/features/feed/view/widget/comments_sheet.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/widget/post/comment_row.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../../fakes/fake_comment_repository.dart';
import '../../../../fakes/fake_post_repository.dart';
import '../../../../helpers/device_matrix.dart';
import '../../../../helpers/golden_helper.dart';
import '../../../../helpers/test_l10n.dart';
import '../../../clubs/view/widget/club_sheet_harness.dart';
import '../../post_detail_test_support.dart';

final Key _close = GuKey.action('SHT-09.close');
final Key _retry = GuKey.action('SHT-09.retry');

final PostDetailViewModelProvider _provider = postDetailViewModelProvider(
  clubId: kPostClubId,
  postId: kPostId,
);

const CommentsSheet _sheet = CommentsSheet(
  clubId: kPostClubId,
  postId: kPostId,
);

/// Durum kipi ezmesi ([state] `null` → gerçek ViewModel).
List<Override> _stateOverride(PostDetailState? state) => [
  if (state != null) _provider.overrideWithBuild((ref, notifier) => state),
];

/// Sayfayı açar: [state] verilirse ViewModel durumu ezilir; verilmezse gerçek
/// ViewModel tohumlanmış sahte depolarla çalışır.
Future<ClubSheetHarness<bool>> _open(
  WidgetTester tester, {
  PostDetailState? state,
  SessionState? session,
  ThemeMode theme = ThemeMode.light,
  Locale locale = const Locale('tr'),
}) async {
  final h = ClubSheetHarness<bool>(
    SheetId.sht09,
    (_) => _sheet,
    session: session ?? postSession(),
    overrides: _stateOverride(state),
  );
  await h.pump(tester, theme: theme, locale: locale);
  await seedPost();
  await h.open(tester);
  return h;
}

FakeCommentRepository _comments() =>
    GetIt.I<CommentRepository>() as FakeCommentRepository;

List<String> _rowIds(WidgetTester tester) => [
  for (final row in tester.widgetList<CommentRow>(find.byType(CommentRow)))
    row.comment.id,
];

void main() {
  group('SHT-09 · Yorumlar · içerik', () {
    for (final locale in const [Locale('tr'), Locale('en')]) {
      testWidgets('(${locale.languageCode}) "3 yorum" + "Tümünü gör", yorum '
          'satırları (rozet / menü yok), yorum yazma satırı', (tester) async {
        await _open(tester, state: loadedPostState(), locale: locale);
        final l10n = tester.l10n;
        final frame = tester.widget<GuSheetFrame>(find.byType(GuSheetFrame));
        expect(frame.title, l10n.postComments(kPostComments.length));
        expect(frame.closeSemanticLabel, l10n.a11yClose);
        expect(find.byKey(_close), findsOneWidget);
        final seeAll = tester.widget<GuButton>(
          find.byKey(CommentsSheet.seeAllKey),
        );
        expect(seeAll.label, l10n.sht09SeeAll);
        expect(seeAll.variant, GuButtonVariant.text);
        expect(seeAll.size, GuButtonSize.sm);

        final rows = tester
            .widgetList<CommentRow>(find.byType(CommentRow))
            .toList();
        expect(rows.map((row) => row.comment), kPostComments);
        expect(rows.map((row) => row.author), [
          for (final comment in kPostComments) kPostUsers[comment.authorId],
        ]);
        expect(rows.every((row) => row.role == null), isTrue);
        expect(rows.every((row) => row.onAuthor == null), isTrue);
        expect(rows.every((row) => row.onMenu == null), isTrue);

        final composer = find.byType(CommentComposer);
        expect(composer, findsOneWidget);
        expect(
          find.descendant(of: composer, matching: find.byType(GuAvatar)),
          findsNothing,
        );
        final input = tester.widget<GuInput>(find.byType(GuInput));
        expect(input.placeholder, l10n.postWriteComment);
        expect(input.maxLength, Limits.commentMax);
        expect(find.byKey(CommentsSheet.inputKey), findsOneWidget);
        expect(
          tester
              .widget<GuIconButton>(find.byKey(CommentsSheet.sendKey))
              .disabled,
          isTrue,
        );
      });
    }

    testWidgets('danışman: yorum alanı yerine "yorum yazamazsın" notu', (
      tester,
    ) async {
      await _open(
        tester,
        state: loadedPostState(),
        session: postSession(role: ClubRole.advisor),
      );
      expect(find.text(tester.l10n.postAdvisorNoComment), findsOneWidget);
      expect(find.byType(CommentComposer), findsNothing);
    });

    testWidgets('engellenen yazarın yorumu çizilmez; başlık sayısı düşer', (
      tester,
    ) async {
      final session = postSession(blocked: {kOtherComment.authorId});
      await _open(
        tester,
        state: loadedPostState(session: session),
        session: session,
      );
      expect(_rowIds(tester), isNot(contains(kOtherComment.id)));
      expect(
        tester.widget<GuSheetFrame>(find.byType(GuSheetFrame)).title,
        tester.l10n.postComments(kPostComments.length - 1),
      );
    });
  });

  group('SHT-09 · Yorumlar · durumlar', () {
    testWidgets('boş: başlık "Yorumlar", "İlk yorumu sen yaz."', (
      tester,
    ) async {
      await _open(tester, state: loadedPostState(comments: const []));
      final l10n = tester.l10n;
      expect(
        tester.widget<GuSheetFrame>(find.byType(GuSheetFrame)).title,
        l10n.postComments(0),
      );
      expect(find.text(l10n.postNoComments), findsOneWidget);
      expect(find.byType(CommentRow), findsNothing);
      expect(find.byType(CommentComposer), findsOneWidget);
    });

    testWidgets('yükleniyor: satır iskeleti; hata: "Yeniden dene"', (
      tester,
    ) async {
      await _open(
        tester,
        state: const PostDetailState(
          isFetching: true,
          isFetchingComments: true,
        ),
      );
      expect(find.byType(GuSkeletonList), findsOneWidget);
      expect(find.text(tester.l10n.postNoComments), findsNothing);

      await _open(
        tester,
        state: loadedPostState(
          comments: const [],
        ).copyWith(isCommentsError: true),
      );
      final error = tester.widget<GuErrorState>(find.byType(GuErrorState));
      expect(error.inline, isTrue);
      expect(error.retryLabel, tester.l10n.commonRetry);
      expect(find.byKey(_retry), findsOneWidget);
    });
  });

  group('SHT-09 · Yorumlar · aksiyonlar', () {
    testWidgets('"Tümünü gör" → true; X → null', (tester) async {
      final h = await _open(tester, state: loadedPostState());
      await tester.tap(find.byKey(CommentsSheet.seeAllKey));
      await tester.pumpAndSettle();
      expect(h.result, isTrue);
      expect(find.byType(GuSheetFrame), findsNothing);

      await h.open(tester);
      await tester.tap(find.byKey(_close));
      await tester.pumpAndSettle();
      expect(h.result, isNull);
    });

    testWidgets('canlı yorumlar: yaz + gönder → TST-12, alan boşalır, yeni '
        'satır sonda; başlık sayısı artar', (tester) async {
      final h = await _open(tester);
      expect(_rowIds(tester), ['cm03', 'cm02', 'cm01']);

      await tester.enterText(find.byKey(CommentsSheet.inputKey), ' Selam ');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(CommentsSheet.sendKey));
      await tester.pumpAndSettle();

      expect(h.feedback.toasts, [ToastId.tst12]);
      final added = _comments().added.single;
      expect(added.text, 'Selam');
      expect(_rowIds(tester).last, added.id);
      expect(
        tester.widget<GuSheetFrame>(find.byType(GuSheetFrame)).title,
        tester.l10n.postComments(kPostComments.length + 1),
      );
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        isEmpty,
      );
    });

    testWidgets('gönderi gizlenince (içerik yok) sayfa kapanır', (
      tester,
    ) async {
      final h = await _open(tester);
      expect(find.byType(GuSheetFrame), findsOneWidget);
      (GetIt.I<PostRepository>() as FakePostRepository).put(
        kPost.copyWith(isHidden: true),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GuSheetFrame), findsNothing);
      expect(h.result, isNull);
    });
  });

  group('SHT-09 · Yorumlar · cihaz matrisi + golden', () {
    testWidgets('cihaz matrisi: taşma yok (dolu, boş, danışman; klavye + '
        'güvenli alan)', (tester) async {
      for (final (state, session) in [
        (loadedPostState(), postSession()),
        (loadedPostState(comments: const []), postSession()),
        (loadedPostState(), postSession(role: ClubRole.advisor)),
      ]) {
        await DeviceMatrix.run(
          tester,
          (context) =>
              const Align(alignment: Alignment.bottomCenter, child: _sheet),
          overrides: [
            sessionViewModelProvider.overrideWithBuild((_, _) => session),
            ..._stateOverride(state),
          ],
          keyboard: true,
          safeAreas: true,
        );
      }
    });

    testWidgets('golden: açık sayfa (scrim dahil) — açık + koyu (TR)', (
      tester,
    ) async {
      for (final theme in kGoldenThemes) {
        final h = await _open(tester, state: loadedPostState(), theme: theme);
        await h.expectGolden(tester, 'SHT-09', theme);
      }
    });
  });
}
