// T-20 · Uçtan uca kulüp akışı ve gönderi detayı: gerçek `GuApp` (rota
// ağacı, yönlendirme, oturum katmanı, `AppFeedbackService`) + sahte servisler.
//
//   üye girişi (`u_mehmet`, `c01` üyesi) → CLB-03 → "Gönderiler" sekmesi
//   (FED-01) → "Anketler" çipi (liste süzülür) → beğen → anket oyu (TST-10) →
//   karta dokun → FED-02 (/clubs/c01/posts/p04) → yorum yaz (TST-12) → "…" →
//   SHT-08 → "Kaydet" (TST-11) → geri → akıştaki kart güncel
//   gizlenmiş gönderinin adresi → SYS-04 (/not-found)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/bootstrap/gu_app.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/clubs/provider/club_feed_state.dart';
import 'package:gu_kulupler/features/clubs/provider/club_feed_view_model.dart';
import 'package:gu_kulupler/features/clubs/view/club_detail_view.dart';
import 'package:gu_kulupler/features/feed/provider/post_detail_state.dart';
import 'package:gu_kulupler/features/feed/provider/post_detail_view_model.dart';
import 'package:gu_kulupler/features/feed/view/post_detail_view.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/post_menu.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/app_router.dart';
import 'package:gu_kulupler/product/navigation/navigator_keys.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../fakes/fake_app_preferences_store.dart';
import '../fakes/fake_auth_repository.dart';
import '../fakes/fake_comment_repository.dart';
import '../fakes/register_fakes.dart';
import '../features/clubs/club_feed_test_support.dart';
import '../helpers/test_asset_bundle.dart';

/// Akışta izlenen gönderi: dört seçenekli açık anket (`p04`).
final String _postId = kPollPost.id;

/// Verilen oy: anketin ilk seçeneği.
final String _optionId = kPollPost.poll!.options.first.id;

/// Gizlenmiş gönderi (moderasyon): adresi bilinse de açılmaz.
const String _hiddenPostId = 'p_hidden';

const String _commentText = 'Ben de varım.';

Key _k(String id) => GuKey.action(id);

FakeCommentRepository _comments() =>
    GetIt.I<CommentRepository>() as FakeCommentRepository;

/// Sahte servisleri kaydeder, `c01` kulübünü yedi gönderisiyle (+ gizlenmiş
/// bir gönderi) kurar ve gerçek `GuApp`'i `u_mehmet` (`c01` üyesi) oturumuyla
/// açar.
Future<void> _launch(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await GetIt.I.reset();
  registerDefaultFakes();
  addTearDown(GetIt.I.reset);
  final toasts = GuToastController();
  addTearDown(toasts.dispose);
  GetIt.I
    ..unregister<FeedbackService>()
    ..registerSingleton<FeedbackService>(
      AppFeedbackService(
        navigatorKey: rootNavigatorKey,
        toastController: toasts,
      ),
    );
  seedFeed();
  feedPosts().put(kImagePost.copyWith(id: _hiddenPostId, isHidden: true));
  (GetIt.I<AuthRepository>() as FakeAuthRepository).service.emailVerified =
      true;
  (GetIt.I<AppPreferencesStore>() as FakeAppPreferencesStore)
    ..values[AppPreferenceKeys.onboardingSeen] = true
    ..values[AppPreferenceKeys.notificationPermissionAsked] = true;
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    // Kapak şablonları depo kökünden eşzamanlı okunur (> 50 KB).
    DefaultAssetBundle(
      bundle: TestAssetBundle.instance,
      child: ProviderScope(child: GuApp(toastController: toasts)),
    ),
  );
  await tester.pumpAndSettle();
  expect(
    _container(tester).read(sessionViewModelProvider).status,
    AuthStatus.active,
  );
  expect(_location(tester), AppPaths.clubs);
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(GuApp)));

GoRouter _router(WidgetTester tester) =>
    _container(tester).read(appRouterProvider);

String _location(WidgetTester tester) =>
    _router(tester).routerDelegate.currentConfiguration.uri.toString();

ClubFeedState _feed(WidgetTester tester) =>
    _container(tester).read(clubFeedViewModelProvider(kFeedClubId));

PostDetailState _detail(WidgetTester tester) => _container(tester).read(
  postDetailViewModelProvider(clubId: kFeedClubId, postId: _postId),
);

Future<void> _go(WidgetTester tester, String location) async {
  _router(tester).go(location);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _toast(ToastId id) => find.byKey(ValueKey<ToastId>(id));

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_GB');
    await initializeDateFormatting('en_US');
  });

  group('T-20 · akış · kulüp akışı ve gönderi detayı (FED-01, FED-02, '
      'SHT-08, TST-10, TST-11, TST-12)', () {
    testWidgets('üye: CLB-03 → "Gönderiler" → "Anketler" çipi → beğen → oy '
        '(TST-10) → kart → FED-02 → yorum (TST-12) → menü → "Kaydet" '
        '(TST-11) → geri', (tester) async {
      await _launch(tester);
      await _go(tester, '${AppPaths.clubs}/$kFeedClubId');
      expect(find.byType(ClubDetailView), findsOneWidget);

      // CLB-03 "Gönderiler" sekmesi: sabit duyuru üstte.
      await _tap(tester, _k('CLB-03.tab.posts'));
      expect(_feed(tester).visible.first.id, kPinnedPost.id);
      expect(find.byKey(_k('FED-01.post.${kPinnedPost.id}')), findsOneWidget);

      // "Anketler" çipi: yalnızca anket kalır.
      await _tap(tester, _k('FED-01.filter.polls'));
      expect(_feed(tester).filter, FeedFilter.polls);
      expect([for (final post in _feed(tester).visible) post.id], [_postId]);
      expect(find.byKey(_k('FED-01.post.${kPinnedPost.id}')), findsNothing);

      // Beğen: iyimser, depoya yazılır.
      final wasLiked = kPollPost.likedBy(kMembersUid);
      await _tap(tester, _k('FED-01.like.$_postId'));
      expect(_feed(tester).postById(_postId)!.likedBy(kMembersUid), !wasLiked);
      expect(feedPosts().posts[_postId]!.likedBy(kMembersUid), !wasLiked);

      // Anket oyu → TST-10; oy depoda, seçenek işaretli.
      expect(_feed(tester).myVotes[_postId], isNull);
      await _tap(tester, _k('FED-01.vote.$_postId.$_optionId'));
      expect(_feed(tester).myVotes[_postId], _optionId);
      expect(feedPosts().votes[_postId]![kMembersUid], _optionId);
      expect(
        _feed(tester).pollResults[_postId]![_optionId],
        kPollResults[_optionId]! + 1,
      );
      expect(_toast(ToastId.tst10), findsOneWidget);

      // Kart gövdesi → FED-02; oy ve beğeni orada da görünür.
      await _tap(tester, _k('FED-01.post.$_postId'));
      expect(
        _location(tester),
        '${AppPaths.clubs}/$kFeedClubId/posts/$_postId',
      );
      expect(find.byType(PostDetailView), findsOneWidget);
      expect(_detail(tester).post!.likedBy(kMembersUid), !wasLiked);
      expect(_detail(tester).myOptionId, _optionId);

      // TST-10 yorum çubuğunun üstünde durur (tasarımdaki konum: güvenli
      // alan + 12); kapanması beklenir.
      await tester.pump(GuMotion.toastUndo);
      await tester.pumpAndSettle();
      expect(_toast(ToastId.tst10), findsNothing);

      // Yorum yaz → TST-12; yorum canlı akıştan listeye gelir, alan boşalır.
      await tester.enterText(
        find.byKey(_k('FED-02.commentInput')),
        _commentText,
      );
      await tester.pump();
      await _tap(tester, _k('FED-02.sendComment'));
      expect(_comments().added.single.text, _commentText);
      expect(_comments().added.single.authorId, kMembersUid);
      expect(_detail(tester).comments.single.text, _commentText);
      expect(_detail(tester).commentDraft, isEmpty);
      expect(_toast(ToastId.tst12), findsOneWidget);

      // "…" → SHT-08 → "Kaydet" → kayıt yazılır, TST-11.
      expect(_detail(tester).isSaved, isFalse);
      await _tap(tester, _k('FED-02.menu.$_postId'));
      expect(find.byType(PostMenu), findsOneWidget);
      await _tap(tester, PostMenu.keyOf(PostMenuAction.save));
      expect(find.byType(PostMenu), findsNothing);
      expect(_detail(tester).isSaved, isTrue);
      expect(
        feedSaved().saved.values.any(
          (record) =>
              record.userId == kMembersUid &&
              record.postId == _postId &&
              !record.isDeleted,
        ),
        isTrue,
      );
      expect(_toast(ToastId.tst11), findsOneWidget);

      // Geri → CLB-03 "Gönderiler"; akıştaki kart yeniden okunur (kayıt).
      await _tap(tester, _k('FED-02.back'));
      expect(find.byType(PostDetailView), findsNothing);
      expect(find.byType(ClubDetailView), findsOneWidget);
      expect(_location(tester), startsWith('${AppPaths.clubs}/$kFeedClubId'));
      expect(_location(tester), isNot(contains('/posts/')));
      expect(_feed(tester).filter, FeedFilter.polls);
      expect(_feed(tester).savedPostIds, contains(_postId));

      await tester.pump(GuMotion.toastUndo);
      await tester.pumpAndSettle();
    });

    testWidgets('gizlenmiş gönderinin adresi → SYS-04', (tester) async {
      await _launch(tester);

      await _go(
        tester,
        '${AppPaths.clubs}/$kFeedClubId/posts/$_hiddenPostId',
      );
      expect(_location(tester), AppPaths.notFound);
      expect(find.byType(PostDetailView), findsNothing);

      // Gizlenmiş gönderi akışta da yoktur.
      await _go(tester, '${AppPaths.clubs}/$kFeedClubId');
      await _tap(tester, _k('CLB-03.tab.posts'));
      expect(
        _feed(tester).posts.any((post) => post.id == _hiddenPostId),
        isFalse,
      );
    });
  });
}
