// FED-02 · Gönderi — içerik (üye / danışman bakışı, engellenen yazar),
// durumlar (yükleniyor, hata, yorum bloğu: iskelet / hata / boş, çevrimdışı),
// aksiyon envanteri (16 anahtar), her aksiyonun sonucu (CLB-03 / CLB-07
// gezinmesi, beğeni, kayıt, SHT-15, SHT-08 → DLG-10, yorum yaz → TST-12, yorum
// menüsü → SHT-27 / DLG-11, canlı akış, gizlenen gönderi → SYS-04), cihaz
// matrisi, açık + koyu golden.
// Referans: design/reference-shots/screens/FED-02__*.webp,
// design/prototype/app/screens-clubs.js:165–178.
//
// İki kip (CLB-06 testleriyle aynı düzen):
// * **Durum kipi** (içerik, durumlar, matris, envanter, golden): ekran
//   `pumpApp` ile çizilir, ViewModel durumu ezilir (dinleme yapılmaz).
// * **Akış kipi** (aksiyon sonuçları): ekran gerçek ViewModel, sahte depolar
//   ve yer tutucu hedef rotalarla açılır.
//
// Yorum sırası: uygulama eskiden yeniye çizer (cm03 → cm01); referans görüntü
// prototipin `commentIds` sırasını gösterir (cm01 → cm03) — demo veride
// `createdAt` azalan yazılmıştır.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/feed/provider/post_detail_state.dart';
import 'package:gu_kulupler/features/feed/provider/post_detail_view_model.dart';
import 'package:gu_kulupler/features/feed/view/post_detail_view.dart';
import 'package:gu_kulupler/features/feed/view/widget/comment_composer.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/post_menu.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/user_menu_sheet.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';
import 'package:gu_kulupler/product/widget/post/comment_row.dart';
import 'package:gu_kulupler/product/widget/post/post_card.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fakes/fake_comment_repository.dart';
import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_post_repository.dart';
import '../../../helpers/a11y_guidelines.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';
import '../post_detail_test_support.dart';

final Key _back = GuKey.action('FED-02.back');
final Key _retry = GuKey.action('FED-02.retry');
final Key _input = GuKey.action('FED-02.commentInput');
final Key _send = GuKey.action('FED-02.sendComment');
final Key _postAuthor = GuKey.action('FED-02.author.$kPostId');
final Key _menu = GuKey.action('FED-02.menu.$kPostId');
final Key _like = GuKey.action('FED-02.like.$kPostId');
final Key _share = GuKey.action('FED-02.share.$kPostId');
final Key _save = GuKey.action('FED-02.save.$kPostId');

Key _commentAuthor(String commentId) =>
    GuKey.action('FED-02.author.$commentId');
Key _commentMenu(String commentId) =>
    GuKey.action('FED-02.commentMenu.$commentId');

/// İçeriğin tamamı kurulsun diye uzun yüzey.
const Size _tall = Size(390, 1600);

const String _clubPath = '/clubs/$kPostClubId';
const String _postPath = '$_clubPath/posts/$kPostId';

final PostDetailViewModelProvider _provider = postDetailViewModelProvider(
  clubId: kPostClubId,
  postId: kPostId,
);

FakeFeedbackService _feedback() =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;

FakePostRepository _posts() => GetIt.I<PostRepository>() as FakePostRepository;

FakeCommentRepository _comments() =>
    GetIt.I<CommentRepository>() as FakeCommentRepository;

FakeConnectivityService _connectivity() =>
    GetIt.I<ConnectivityService>() as FakeConnectivityService;

/// Durum kipi: oturum + ViewModel durumu ezilir.
List<Override> _overrides({SessionState? session, PostDetailState? state}) => [
  sessionViewModelProvider.overrideWithBuild(
    (ref, notifier) => session ?? postSession(),
  ),
  _provider.overrideWithBuild(
    (ref, notifier) => state ?? loadedPostState(session: session),
  ),
];

/// Ekranı dolu durumla (ya da [state] ile) çizer.
Future<void> _pump(
  WidgetTester tester, {
  SessionState? session,
  PostDetailState? state,
  Locale locale = const Locale('tr'),
  Size size = const Size(390, 844),
}) async {
  await tester.pumpApp(
    const PostDetailView(clubId: kPostClubId, postId: kPostId),
    locale: locale,
    size: size,
    overrides: _overrides(session: session, state: state),
  );
  await tester.pump();
}

/// Akış kipi: ekranı gerçek ViewModel ve yer tutucu rotalarla açar. Depolar
/// ekran açılmadan önce tohumlanır.
Future<GoRouter> _pumpRoute(
  WidgetTester tester, {
  SessionState? session,
}) async {
  GoRouter? created;
  await tester.pumpAppRouter(
    size: _tall,
    routerOf: (_) => created ??= GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(path: '/start', builder: (_, _) => const _Stub('/start')),
        GoRoute(
          path: '/not-found',
          builder: (_, _) => const _Stub('/not-found'),
        ),
        GoRoute(
          path: '/clubs/:clubId',
          builder: (_, state) => _Stub(state.uri.toString()),
          routes: [
            // T-43 · K-69: kulüp bağlamlı CLB-07 (geri → CLB-03).
            GoRoute(
              path: 'user/:userId',
              builder: (_, state) => _Stub(state.uri.toString()),
            ),
            GoRoute(
              path: 'posts/:postId',
              builder: (_, state) => PostDetailView(
                clubId: state.pathParameters['clubId']!,
                postId: state.pathParameters['postId']!,
              ),
            ),
            GoRoute(
              path: 'compose',
              builder: (_, state) => _Stub(state.uri.toString()),
            ),
          ],
        ),
      ],
    ),
    overrides: [
      sessionViewModelProvider.overrideWithBuild(
        (ref, notifier) => session ?? postSession(),
      ),
    ],
  );
  final router = created!;
  addTearDown(router.dispose);
  await seedPost();
  router.go(_postPath);
  await tester.pumpAndSettle();
  return router;
}

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

/// Yer tutucu hedef sayfa: yolunu gösterir.
class _Stub extends StatelessWidget {
  const _Stub(this.path);

  final String path;

  @override
  Widget build(BuildContext context) => Scaffold(body: Text(path));
}

PostDetailState _stateOf(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(PostDetailView, skipOffstage: false)),
).read(_provider);

List<String> _rowIds(WidgetTester tester) => [
  for (final row in tester.widgetList<CommentRow>(find.byType(CommentRow)))
    row.comment.id,
];

PostCard _card(WidgetTester tester) =>
    tester.widget<PostCard>(find.byType(PostCard));

Future<void> _tapKey(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(_input), text);
  await tester.pumpAndSettle();
}

void main() {
  group('FED-02 · Gönderi · içerik', () {
    for (final locale in const [Locale('tr'), Locale('en')]) {
      testWidgets('üye bakışı (${locale.languageCode}): başlık + kulüp adı, '
          'tam gönderi kartı, "3 yorum", yorum satırları, yorum çubuğu', (
        tester,
      ) async {
        await _pump(tester, locale: locale, size: _tall);
        final l10n = tester.l10n;
        final bar = tester.widget<GuAppBar>(find.byType(GuAppBar));
        expect(bar.title, l10n.postTitle);
        expect(bar.subtitle, kPostClub.name);
        expect(find.byKey(_back), findsOneWidget);

        final card = _card(tester);
        expect(card.post, kPost);
        expect(card.author, kPostUsers[kPost.authorId]);
        expect(card.role, ClubRole.president);
        expect(card.club, kPostClub);
        expect(card.expanded, isTrue);
        expect(card.showClub, isTrue);
        expect(card.liked, isFalse);
        expect(card.saved, isTrue);
        expect(card.hideActions, isFalse);
        expect(card.keys.more, isNull);

        expect(
          find.text(l10n.postComments(kPostComments.length)),
          findsOneWidget,
        );
        final rows = tester
            .widgetList<CommentRow>(find.byType(CommentRow))
            .toList();
        expect(rows.map((row) => row.comment), kPostComments);
        expect(rows.map((row) => row.author), [
          for (final comment in kPostComments) kPostUsers[comment.authorId],
        ]);
        expect(rows.map((row) => row.role), [ClubRole.board, null, null]);
        expect(rows.every((row) => row.onAuthor != null), isTrue);
        expect(rows.every((row) => row.onMenu != null), isTrue);

        final composer = find.byType(CommentComposer);
        expect(
          find.ancestor(of: composer, matching: find.byType(GuStickyCta)),
          findsOneWidget,
        );
        final avatar = tester.widget<GuAvatar>(
          find.descendant(of: composer, matching: find.byType(GuAvatar)),
        );
        expect(avatar.initials, 'MK');
        expect(avatar.size, 36);
        final input = tester.widget<GuInput>(
          find.descendant(of: composer, matching: find.byType(GuInput)),
        );
        expect(input.placeholder, l10n.postWriteComment);
        expect(input.multiline, isTrue);
        expect(input.maxLength, Limits.commentMax);
        expect(input.showCounter, isTrue);
        final send = tester.widget<GuIconButton>(find.byKey(_send));
        expect(send.icon, GuIcons.send);
        expect(send.tone, GuIconButtonTone.brand);
        expect(send.disabled, isTrue);
        expect(send.semanticLabel, l10n.commonSend);
        expect(find.byType(GuBanner), findsNothing);
        await expectA11yGuidelines(tester);
      });
    }

    testWidgets('danışman: yorum çubuğu yerine salt okunur bant', (
      tester,
    ) async {
      await _pump(tester, session: postSession(role: ClubRole.advisor));
      final banner = tester.widget<GuBanner>(find.byType(GuBanner));
      expect(banner.kind, GuBannerKind.readonly);
      expect(banner.text, tester.l10n.postAdvisorNoComment);
      expect(find.byType(CommentComposer), findsNothing);
      expect(find.byKey(_input), findsNothing);
    });

    testWidgets('oturumda engellenen yazarın yorumu çizilmez; sayı düşer', (
      tester,
    ) async {
      await _pump(
        tester,
        session: postSession(blocked: {kOtherComment.authorId}),
        size: _tall,
      );
      expect(_rowIds(tester), isNot(contains(kOtherComment.id)));
      expect(_rowIds(tester), hasLength(kPostComments.length - 1));
      expect(
        find.text(tester.l10n.postComments(kPostComments.length - 1)),
        findsOneWidget,
      );
    });

    testWidgets('silinmiş yazar: kart ve satır yazarsız çizilir, profil '
        'açılmaz', (tester) async {
      final author = kPostComments.first.authorId;
      await _pump(
        tester,
        state: loadedPostState().copyWith(
          users: {
            for (final entry in kPostUsers.entries)
              if (entry.key != author) entry.key: entry.value,
          },
        ),
        size: _tall,
      );
      final row = tester.widget<CommentRow>(find.byType(CommentRow).first);
      expect(row.author, isNull);
      expect(row.onAuthor, isNull);
    });
  });

  group('FED-02 · Gönderi · durumlar', () {
    testWidgets('yükleniyor: kart + satır iskeleti; alt çubuk yok', (
      tester,
    ) async {
      await _pump(
        tester,
        state: const PostDetailState(
          isFetching: true,
          isFetchingComments: true,
        ),
      );
      final skeletons = tester
          .widgetList<GuSkeletonList>(find.byType(GuSkeletonList))
          .toList();
      expect(skeletons.map((skeleton) => skeleton.variant), [
        GuSkeletonVariant.card,
        GuSkeletonVariant.tile,
      ]);
      expect(skeletons.first.semanticLabel, tester.l10n.commonLoading);
      expect(find.byType(PostCard), findsNothing);
      expect(find.byType(CommentComposer), findsNothing);
      expect(tester.widget<GuAppBar>(find.byType(GuAppBar)).subtitle, isNull);
    });

    testWidgets('hata: "Bir şeyler ters gitti" + "Yeniden dene"', (
      tester,
    ) async {
      await _pump(tester, state: const PostDetailState(isError: true));
      final l10n = tester.l10n;
      final error = tester.widget<GuErrorState>(find.byType(GuErrorState));
      expect(error.title, l10n.sysErrorTitle);
      expect(error.description, l10n.sysErrorDesc);
      expect(error.retryLabel, l10n.commonRetry);
      expect(error.inline, isFalse);
      expect(find.byKey(_retry), findsOneWidget);
      expect(find.byType(PostCard), findsNothing);
    });

    testWidgets('yorum bloğu: iskelet → hata (satır içi) → boş ("İlk yorumu '
        'sen yaz."); gönderi kartı yerinde', (tester) async {
      await _pump(
        tester,
        state: loadedPostState(
          comments: const [],
        ).copyWith(isFetchingComments: true),
        size: _tall,
      );
      expect(find.byType(PostCard), findsOneWidget);
      expect(find.byType(GuSkeletonList), findsOneWidget);
      expect(find.text(tester.l10n.postNoComments), findsNothing);

      await _pump(
        tester,
        state: loadedPostState(
          comments: const [],
        ).copyWith(isCommentsError: true),
        size: _tall,
      );
      expect(
        tester.widget<GuErrorState>(find.byType(GuErrorState)).inline,
        isTrue,
      );
      expect(find.byKey(_retry), findsOneWidget);
      expect(find.byType(PostCard), findsOneWidget);

      await _pump(
        tester,
        state: loadedPostState(comments: const []),
        size: _tall,
      );
      expect(find.text(tester.l10n.postNoComments), findsOneWidget);
      expect(find.text(tester.l10n.postComments(0)), findsOneWidget);
      expect(find.byType(CommentRow), findsNothing);
      expect(find.byType(CommentComposer), findsOneWidget);
    });

    testWidgets('çevrimdışı: içerik ekranda kalır; beğeni TST-24 verir, '
        'yazılmaz', (tester) async {
      await _pumpRoute(tester);
      _connectivity().isOffline = true;
      await _tapKey(tester, _like);
      expect(_feedback().toasts, [ToastId.tst24]);
      expect(_posts().callsTo('like'), isEmpty);
      expect(find.byType(PostCard), findsOneWidget);
      expect(_rowIds(tester), hasLength(kPostComments.length));
    });
  });

  group('FED-02 · Gönderi · aksiyon envanteri', () {
    testWidgets('üye bakışı: envanterdeki 16 anahtar birebir', (tester) async {
      await _pump(tester, size: _tall);
      expectActionInventory(tester, 'FED-02', role: 'member');
    });
  });

  group('FED-02 · Gönderi · aksiyonlar', () {
    testWidgets('geri → CLB-03 (/clubs/c01); gönderi yazarı ve yorum avatarı '
        '→ CLB-07 (kulüp bağlamıyla)', (tester) async {
      final router = await _pumpRoute(tester);
      expect(
        tester.widget<GuAppBar>(find.byType(GuAppBar)).subtitle,
        isNotNull,
      );
      await _tapKey(tester, _postAuthor);
      expect(
        _location(router),
        '/clubs/$kPostClubId/user/${kPost.authorId}',
      );

      router.go(_postPath);
      await tester.pumpAndSettle();
      await _tapKey(tester, _commentAuthor(kOtherComment.id));
      expect(
        _location(router),
        '/clubs/$kPostClubId/user/${kOtherComment.authorId}',
      );

      router.go(_postPath);
      await tester.pumpAndSettle();
      await _tapKey(tester, _back);
      expect(_location(router), _clubPath);
    });

    testWidgets('beğen → kalp dolar (iyimser) + yazılır; kaydet → TST-11; '
        'paylaş → SHT-15', (tester) async {
      await _pumpRoute(tester);
      expect(_card(tester).liked, isFalse);
      expect(_card(tester).saved, isTrue);

      await _tapKey(tester, _like);
      expect(_card(tester).liked, isTrue);
      expect(_card(tester).post.likeCount, kPost.likeCount + 1);
      expect(_posts().callsTo('like'), hasLength(1));

      await _tapKey(tester, _save);
      expect(_card(tester).saved, isFalse);
      expect(_feedback().toasts, [ToastId.tst11]);

      await _tapKey(tester, _share);
      expect(_feedback().sheets, [SheetId.sht15]);
    });

    testWidgets('"…" → SHT-08; yönetici "Sil" → DLG-10 → TST-45 ve ekran '
        'kulübe döner', (tester) async {
      final router = await _pumpRoute(
        tester,
        session: postSession(role: ClubRole.board),
      );
      await _tapKey(tester, _menu);
      expect(_feedback().sheets, [SheetId.sht08]);
      expect(_location(router), _postPath);

      _feedback()
        ..nextSheetResult = PostMenuAction.remove
        ..dialogResults[DialogId.dlg10] = true;
      await _tapKey(tester, _menu);
      expect(_feedback().dialogs, [DialogId.dlg10]);
      expect(_feedback().toasts, [ToastId.tst45]);
      expect(_feedback().toastParams.single.what, tester.l10n.feedTypePost);
      expect(_posts().callsTo('softDeletePost'), hasLength(1));
      expect(_location(router), _clubPath);
    });

    testWidgets('"…" → SHT-08 "Düzenle" → FED-03 düzenleme kipi '
        '(`ComposeRoute(edit:)`)', (tester) async {
      final router = await _pumpRoute(
        tester,
        session: postSession(role: ClubRole.board),
      );
      _feedback().nextSheetResult = PostMenuAction.edit;
      await _tapKey(tester, _menu);
      await tester.pumpAndSettle();
      expect(_feedback().sheets, [SheetId.sht08]);
      expect(_location(router), '$_clubPath/compose?edit=$kPostId');
    });

    testWidgets('yorum yaz: metin girilince "Gönder" açılır; gönder → TST-12, '
        'alan boşalır, yeni satır listenin sonunda', (tester) async {
      await _pumpRoute(tester);
      expect(tester.widget<GuIconButton>(find.byKey(_send)).disabled, isTrue);
      await tester.tap(find.byKey(_send));
      await tester.pumpAndSettle();
      expect(_comments().callsTo('add'), isEmpty);

      await _type(tester, 'Ben de geliyorum.');
      expect(tester.widget<GuIconButton>(find.byKey(_send)).disabled, isFalse);
      await _tapKey(tester, _send);

      expect(_feedback().toasts, [ToastId.tst12]);
      final added = _comments().added.single;
      expect(added.text, 'Ben de geliyorum.');
      expect(_rowIds(tester).last, added.id);
      expect(
        find.text(tester.l10n.postComments(kPostComments.length + 1)),
        findsOneWidget,
      );
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        isEmpty,
      );
      expect(tester.widget<GuIconButton>(find.byKey(_send)).disabled, isTrue);
    });

    testWidgets('yorum alanı Limits.commentMax karakterde kesilir', (
      tester,
    ) async {
      await _pumpRoute(tester);
      await _type(tester, 'x' * (Limits.commentMax + 5));
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        hasLength(Limits.commentMax),
      );
      expect(_stateOf(tester).commentDraft, hasLength(Limits.commentMax));
    });

    testWidgets('yorum "…": başkasının yorumu → SHT-27 ("Profili gör" → '
        'CLB-07); kendi yorumu → DLG-11 → satır kaybolur + TST-45', (
      tester,
    ) async {
      final router = await _pumpRoute(tester);
      await _type(tester, 'Benim yorumum');
      await _tapKey(tester, _send);
      final mine = _comments().added.single;
      _feedback().resetFake();

      _feedback().dialogResults[DialogId.dlg11] = true;
      await _tapKey(tester, _commentMenu(mine.id));
      expect(_feedback().sheets, isEmpty);
      expect(_feedback().dialogs, [DialogId.dlg11]);
      expect(_feedback().toasts, [ToastId.tst45]);
      expect(_feedback().toastParams.single.what, tester.l10n.feedComment);
      expect(_rowIds(tester), isNot(contains(mine.id)));

      _feedback().nextSheetResult = UserMenuAction.viewProfile;
      await _tapKey(tester, _commentMenu(kOtherComment.id));
      expect(_feedback().sheets, [SheetId.sht27]);
      expect(
        _location(router),
        '/clubs/$kPostClubId/user/${kOtherComment.authorId}',
      );
    });

    testWidgets('canlı akış: başkasının yorumu gelince liste güncellenir; '
        'gönderi gizlenince SYS-04', (tester) async {
      final router = await _pumpRoute(tester);
      _comments().put(
        kOtherComment.copyWith(
          id: 'cm_live',
          createdAt: kOtherComment.createdAt!.add(const Duration(hours: 2)),
        ),
      );
      await tester.pumpAndSettle();
      expect(_rowIds(tester).last, 'cm_live');

      _posts().put(kPost.copyWith(isHidden: true));
      await tester.pumpAndSettle();
      expect(_location(router), '/not-found');
    });
  });

  group('FED-02 · Gönderi · toast konumu', () {
    testWidgets('toast yorum çubuğunun üstünde durur: çubukla ve "Gönder" '
        'düğmesiyle kesişmez — klavye kapalı ve açık', (tester) async {
      for (final keyboard in [0.0, 300.0]) {
        final controller = GuToastController();
        addTearDown(controller.dispose);
        await tester.pumpApp(
          GuToastHost(
            controller: controller,
            child: const PostDetailView(clubId: kPostClubId, postId: kPostId),
          ),
          keyboardInset: keyboard,
          overrides: _overrides(),
        );
        await tester.pump();
        controller.show(
          GuToastEntry(
            kind: GuToastKind.success,
            text: 'Yorum gönderildi.',
            closeSemanticLabel: tester.l10n.a11yClose,
            persistent: true,
          ),
        );
        await tester.pump();
        await tester.pump(GuMotion.slow);

        final toast = tester.getRect(find.byType(GuToast));
        final bar = tester.getRect(find.byType(GuStickyCta));
        final send = tester.getRect(find.byKey(_send));
        expect(toast.overlaps(bar), isFalse, reason: 'klavye $keyboard');
        expect(toast.overlaps(send), isFalse, reason: 'klavye $keyboard');
        expect(
          toast.bottom,
          bar.top - GuSizes.toastBottomExtra,
          reason: 'klavye $keyboard',
        );
        // Çubuk klavyenin üstündedir; toast da.
        expect(send.bottom, lessThanOrEqualTo(844 - keyboard));
      }
    });

    testWidgets('danışman: toast salt okunur bandın üstünde durur', (
      tester,
    ) async {
      final controller = GuToastController();
      addTearDown(controller.dispose);
      final session = postSession(role: ClubRole.advisor);
      await tester.pumpApp(
        GuToastHost(
          controller: controller,
          child: const PostDetailView(clubId: kPostClubId, postId: kPostId),
        ),
        overrides: _overrides(session: session),
      );
      await tester.pump();
      controller.show(
        GuToastEntry(
          kind: GuToastKind.info,
          text: 'Salt okunur.',
          closeSemanticLabel: tester.l10n.a11yClose,
          persistent: true,
        ),
      );
      await tester.pump();
      await tester.pump(GuMotion.slow);

      final toast = tester.getRect(find.byType(GuToast));
      final banner = tester.getRect(find.byType(GuBanner));
      expect(toast.overlaps(banner), isFalse);
      expect(toast.bottom, lessThanOrEqualTo(banner.top));
    });
  });

  group('FED-02 · Gönderi · cihaz matrisi', () {
    Widget view(BuildContext context) =>
        const PostDetailView(clubId: kPostClubId, postId: kPostId);

    testWidgets('üye bakışı (dolu; klavye + güvenli alan)', (tester) async {
      await DeviceMatrix.run(
        tester,
        view,
        overrides: _overrides(),
        keyboard: true,
        safeAreas: true,
      );
    });

    testWidgets('danışman; yükleniyor, hata, yorum yok', (tester) async {
      await DeviceMatrix.run(
        tester,
        view,
        overrides: _overrides(session: postSession(role: ClubRole.advisor)),
        safeAreas: true,
      );
      for (final state in [
        const PostDetailState(isFetching: true, isFetchingComments: true),
        const PostDetailState(isError: true),
        loadedPostState(comments: const []),
      ]) {
        await DeviceMatrix.run(
          tester,
          view,
          overrides: _overrides(state: state),
        );
      }
    });
  });

  group('FED-02 · Gönderi · golden', () {
    testWidgets('varsayılan (üye bakışı) açık + koyu', (tester) async {
      await goldenForThemes(
        tester,
        'FED-02',
        const PostDetailView(clubId: kPostClubId, postId: kPostId),
        overrides: _overrides(),
      );
    });
  });
}
