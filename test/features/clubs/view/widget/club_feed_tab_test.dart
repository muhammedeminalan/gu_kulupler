// FED-01 · Akış (CLB-03 "Gönderiler" sekmesi) — içerik (üye / yönetici
// bakışı), durumlar (yükleniyor, hata, boş, sonraki sayfa, çevrimdışı),
// aksiyon envanteri (61 anahtar), her aksiyonun sonucu (FED-02 / CLB-07
// gezinmesi, süzgeç, beğeni, kaydet → TST-11, oy → TST-10, SHT-08, SHT-09,
// SHT-15, SHT-34, sayfalama), danışman → TST-26, cihaz matrisi, açık + koyu
// golden.
// Referans: design/reference-shots/screens/FED-01__*.webp,
// design/prototype/app/screens-clubs.js:59–72, cards.js:83–127.
//
// Sekme bağımsız rota değildir (CD-10): testlerde bir kaydırma alanının
// içinde, tasarım yakalamasındaki "Akış" başlık çubuğuyla çizilir.
//
// İki kip (CLB-06 testleriyle aynı düzen):
// * **Durum kipi** (içerik, durumlar, matris, envanter, golden): sekme
//   `pumpApp` ile çizilir, ViewModel durumu ezilir (okuma yapılmaz).
// * **Akış kipi** (aksiyon sonuçları): sekme gerçek ViewModel, sahte depolar
//   ve yer tutucu hedef rotalarla açılır.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/clubs/provider/club_feed_state.dart';
import 'package:gu_kulupler/features/clubs/provider/club_feed_view_model.dart';
import 'package:gu_kulupler/features/clubs/view/club_detail_view.dart';
import 'package:gu_kulupler/features/clubs/view/widget/club_feed_tab.dart';
import 'package:gu_kulupler/features/clubs/view/widget/feed_compose_entry.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/image_viewer_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/post_menu.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/media/post_image_resolver.dart';
import 'package:gu_kulupler/product/navigation/club_detail_tab.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';
import 'package:gu_kulupler/product/widget/post/post_card.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../../fakes/fake_club_repository.dart';
import '../../../../fakes/fake_connectivity_service.dart';
import '../../../../fakes/fake_feedback_service.dart';
import '../../../../fakes/fake_membership_repository.dart';
import '../../../../fakes/fake_storage_service.dart';
import '../../../../helpers/a11y_guidelines.dart';
import '../../../../helpers/action_inventory.dart';
import '../../../../helpers/device_matrix.dart';
import '../../../../helpers/fake_app_clock.dart';
import '../../../../helpers/golden_helper.dart';
import '../../../../helpers/pump_app.dart';
import '../../../../helpers/test_l10n.dart';
import '../../club_feed_test_support.dart';

final Key _compose = GuKey.action('FED-01.compose');
final Key _retry = GuKey.action('FED-01.retry');

Key _filter(FeedFilter filter) => GuKey.action('FED-01.filter.${filter.name}');
Key _post(String id) => GuKey.action('FED-01.post.$id');
Key _author(String id) => GuKey.action('FED-01.author.$id');
Key _menu(String id) => GuKey.action('FED-01.menu.$id');
Key _like(String id) => GuKey.action('FED-01.like.$id');
Key _comment(String id) => GuKey.action('FED-01.comment.$id');
Key _share(String id) => GuKey.action('FED-01.share.$id');
Key _save(String id) => GuKey.action('FED-01.save.$id');
Key _image(String id, int index) => GuKey.action('FED-01.image.$id.$index');
Key _vote(String id, String optionId) =>
    GuKey.action('FED-01.vote.$id.$optionId');

/// Tembel listede sona kaydırma adımı (dp).
const double _scrollStep = 400;

/// Yedi kartın tamamı ekranda olsun diye uzun yüzey.
const Size _tall = Size(390, 4200);

const String _feedPath = '/clubs/$kFeedClubId';

final ClubFeedViewModelProvider _provider = clubFeedViewModelProvider(
  kFeedClubId,
);

FakeFeedbackService _feedback() =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;

FakeConnectivityService _connectivity() =>
    GetIt.I<ConnectivityService>() as FakeConnectivityService;

/// SHT-09 gövdesinin yer tutucusu (asıl gövde `features/feed`'dedir; rota
/// verir).
Widget _commentsStub(String clubId, String postId) =>
    Text('comments:$clubId/$postId');

/// Sekmenin test kabuğu: tasarım yakalamasındaki "Akış" başlık çubuğu +
/// CLB-03'teki gibi tek kaydırma alanı (`CustomScrollView`; sekme bir sliver
/// grubudur, kartlar tembel kurulur — T-44). [cacheExtent] verilirse ekran
/// dışındaki kartlar da yerleşir (cihaz matrisi tüm kartların taşmasını
/// denetler).
class _Host extends StatelessWidget {
  const _Host({this.cacheExtent});

  final ScrollCacheExtent? cacheExtent;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.gu.colors.bgCanvas,
    appBar: GuAppBar(
      title: context.l10n.feedTitle,
      onBack: () {},
      backSemanticLabel: context.l10n.a11yBack,
    ),
    body: SafeArea(
      top: false,
      child: CustomScrollView(
        scrollCacheExtent: cacheExtent,
        slivers: const [
          ClubFeedTab(
            clubId: kFeedClubId,
            commentsSheetBuilder: _commentsStub,
          ),
        ],
      ),
    ),
  );
}

/// Cihaz matrisinde yedi kartın hepsinin yerleşmesi için önbellek alanı.
const ScrollCacheExtent _matrixCacheExtent = ScrollCacheExtent.pixels(10000);

/// Durum kipi: oturum + ViewModel durumu ezilir; saat tasarım yakalamasının
/// anıdır.
List<Override> _overrides({SessionState? session, ClubFeedState? state}) => [
  appClockProvider.overrideWithValue(FakeAppClock(kFeedNowUtc)),
  sessionViewModelProvider.overrideWithBuild(
    (ref, notifier) => session ?? feedSession(),
  ),
  _provider.overrideWithBuild(
    (ref, notifier) => state ?? loadedFeedState(session: session),
  ),
];

/// Sekmeyi dolu durumla (ya da [state] ile) çizer.
Future<void> _pump(
  WidgetTester tester, {
  SessionState? session,
  ClubFeedState? state,
  Locale locale = const Locale('tr'),
  Size size = _tall,
}) async {
  await tester.pumpApp(
    const _Host(),
    locale: locale,
    size: size,
    overrides: _overrides(session: session, state: state),
  );
  await tester.pump();
}

/// Akış kipi: sekmeyi gerçek ViewModel ve yer tutucu rotalarla açar. Depolar
/// sekme açılmadan önce tohumlanır ([seed] ek değişiklik içindir).
Future<GoRouter> _pumpRoute(
  WidgetTester tester, {
  SessionState? session,
  void Function()? seed,
  Size size = _tall,
  List<Override> overrides = const [],
}) async {
  GoRouter? created;
  await tester.pumpAppRouter(
    size: size,
    routerOf: (_) => created ??= GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(path: '/start', builder: (_, _) => const _Stub('/start')),
        GoRoute(
          path: '/clubs/:clubId',
          builder: (_, _) => const _Host(),
          routes: [
            // T-43 · K-69: kulüp bağlamlı CLB-07 (geri → CLB-03).
            GoRoute(
              path: 'user/:userId',
              builder: (_, state) => _Stub(state.uri.toString()),
            ),
            GoRoute(
              path: 'posts/:postId',
              builder: (_, state) => _Stub(state.uri.toString()),
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
        (ref, notifier) => session ?? feedSession(),
      ),
      ...overrides,
    ],
  );
  final router = created!;
  addTearDown(router.dispose);
  seedFeed();
  seed?.call();
  router.go(_feedPath);
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

ClubFeedState _stateOf(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(ClubFeedTab, skipOffstage: false)),
).read(_provider);

List<PostCard> _cards(WidgetTester tester) =>
    tester.widgetList<PostCard>(find.byType(PostCard)).toList();

List<String> _cardIds(WidgetTester tester) => [
  for (final card in _cards(tester)) card.post.id,
];

Future<void> _tapKey(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

/// Ağ ve disk önbelleği olmadan Storage görseli: 1 × 1 saydam PNG (T-44
/// testleri; `storageImageFactoryProvider` ezilir).
final Uint8List _onePixelPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

ImageProvider _memoryImage(String url, String path, {int? coverEdgePx}) =>
    MemoryImage(_onePixelPng);

FakeClubRepository _clubs() => GetIt.I<ClubRepository>() as FakeClubRepository;

FakeMembershipRepository _memberships() =>
    GetIt.I<MembershipRepository>() as FakeMembershipRepository;

FakeStorageService _storage() =>
    GetIt.I<StorageService>() as FakeStorageService;

/// [count] görselli gönderi (her biri tek, ayrı yollu görsel; en yeni başta).
List<PostModel> _imagePosts(int count) => [
  for (var index = 0; index < count; index++)
    kImagePost.copyWith(
      id: 'pi${index.toString().padLeft(2, '0')}',
      images: [
        PostImageModel(
          path: 'posts/pi$index/20261013T090000Z_000000000000000$index.jpg',
          w: 1600,
          h: 900,
        ),
      ],
      createdAt: kFeedNowUtc.subtract(Duration(minutes: index + 1)),
    ),
];

/// CLB-03'ü gerçek ViewModel'lerle açar ([tab] ilk sekme); yönlendirici
/// döner (`/start` ↔ kulüp).
Future<GoRouter> _pumpClubDetail(
  WidgetTester tester, {
  ClubDetailTab? tab = ClubDetailTab.posts,
}) async {
  GoRouter? created;
  await tester.pumpAppRouter(
    routerOf: (_) => created ??= GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(path: '/start', builder: (_, _) => const _Stub('/start')),
        GoRoute(
          path: '/clubs/:clubId',
          builder: (_, state) => ClubDetailView(
            clubId: state.pathParameters['clubId']!,
            tab: tab,
            commentsSheetBuilder: _commentsStub,
          ),
        ),
        GoRoute(
          path: '/not-found',
          builder: (_, _) => const _Stub('/not-found'),
        ),
      ],
    ),
    overrides: [
      sessionViewModelProvider.overrideWithBuild(
        (ref, notifier) => feedSession(),
      ),
    ],
  );
  final router = created!;
  addTearDown(router.dispose);
  seedFeed();
  router.go(_feedPath);
  await tester.pumpAndSettle();
  return router;
}

void main() {
  group('FED-01 · Akış · içerik', () {
    for (final locale in const [Locale('tr'), Locale('en')]) {
      testWidgets('üye bakışı (${locale.languageCode}): çipler, sabit gönderi '
          'üstte, yedi kart, liste sonu; yazı girişi yok', (tester) async {
        await _pump(tester, locale: locale);
        final l10n = tester.l10n;

        final chips = tester.widgetList<GuChip>(find.byType(GuChip)).toList();
        expect(chips.map((chip) => chip.label), [
          l10n.commonAll,
          l10n.feedFilterAnnouncements,
          l10n.feedFilterPolls,
          l10n.feedFilterImages,
        ]);
        expect(chips.map((chip) => chip.selected), [true, false, false, false]);

        final cards = _cards(tester);
        expect(_cardIds(tester), kFeedOrder);
        expect(cards.first.post.pinned, isTrue);
        for (final card in cards) {
          expect(card.author, kFeedAuthors[card.post.authorId]);
          expect(card.role, kFeedRoles[card.post.authorId]);
          expect(card.club, kMembersClub);
          expect(card.liked, card.post.likedBy(kMembersUid));
          expect(card.saved, kFeedSavedIds.contains(card.post.id));
          expect(card.expanded, isFalse);
          expect(card.hideActions, isFalse);
        }
        final poll = cards.firstWhere((card) => card.post.isPoll);
        expect(poll.pollResults, kPollResults);
        expect(poll.myOptionId, isNull);

        expect(
          tester.widget<GuListEnd>(find.byType(GuListEnd)).label,
          l10n.commonAllDone,
        );
        expect(find.byType(FeedComposeEntry), findsNothing);
        expect(find.byKey(_compose), findsNothing);
        await expectA11yGuidelines(tester);
      });
    }

    testWidgets('yönetici bakışı: "Kulübüne bir şey yaz…" girişi çiplerin '
        'üstünde', (tester) async {
      await _pump(tester, session: feedSession(role: ClubRole.board));
      final entry = tester.widget<FeedComposeEntry>(find.byKey(_compose));
      expect(entry.user!.uid, kMembersUid);
      expect(find.text(tester.l10n.feedComposePlaceholder), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(_compose)).dy,
        lessThan(tester.getTopLeft(find.byKey(_filter(FeedFilter.all))).dy),
      );
      final avatar = tester.widget<GuAvatar>(
        find.descendant(
          of: find.byKey(_compose),
          matching: find.byType(GuAvatar),
        ),
      );
      expect(avatar.size, FeedComposeEntry.avatarSize);
    });

    testWidgets('oturumda engellenen yazarın gönderileri çizilmez', (
      tester,
    ) async {
      final blocked = kImagePost.authorId;
      await _pump(tester, session: feedSession(blocked: {blocked}));
      expect(_cards(tester).any((c) => c.post.authorId == blocked), isFalse);
      expect(_cards(tester), isNotEmpty);
    });

    testWidgets('anket: oy verilmişse seçenek ve sonuçlar karta iner', (
      tester,
    ) async {
      final optionId = kPollPost.poll!.options[1].id;
      await _pump(
        tester,
        state: loadedFeedState().copyWith(myVotes: {kPollPost.id: optionId}),
      );
      final poll = _cards(tester).firstWhere((card) => card.post.isPoll);
      expect(poll.myOptionId, optionId);
      expect(poll.pollResults, kPollResults);
    });
  });

  group('FED-01 · Akış · durumlar', () {
    testWidgets('yükleniyor: 3 kart iskeleti; çipler yerinde', (tester) async {
      await _pump(tester, state: const ClubFeedState(isFetching: true));
      final skeleton = tester.widget<GuSkeletonList>(
        find.byType(GuSkeletonList),
      );
      expect(skeleton.count, 3);
      expect(skeleton.variant, GuSkeletonVariant.card);
      expect(skeleton.semanticLabel, tester.l10n.commonLoading);
      expect(find.byKey(_filter(FeedFilter.all)), findsOneWidget);
      expect(find.byType(PostCard), findsNothing);
    });

    testWidgets('hata: "Bir şeyler ters gitti" + "Yeniden dene" (satır içi)', (
      tester,
    ) async {
      await _pump(tester, state: const ClubFeedState(isError: true));
      final l10n = tester.l10n;
      final error = tester.widget<GuErrorState>(find.byType(GuErrorState));
      expect(error.title, l10n.sysErrorTitle);
      expect(error.description, l10n.sysErrorDesc);
      expect(error.retryLabel, l10n.commonRetry);
      expect(error.inline, isTrue);
      expect(find.byKey(_retry), findsOneWidget);
      expect(find.byKey(_filter(FeedFilter.all)), findsOneWidget);
    });

    testWidgets('boş: üyeye "Henüz gönderi yok"; yöneticiye "İlk gönderini '
        'yaz" düğmesiyle', (tester) async {
      await _pump(tester, state: const ClubFeedState());
      final l10n = tester.l10n;
      var empty = tester.widget<GuEmptyState>(find.byType(GuEmptyState));
      expect(empty.illustration, GuIllustrations.emptyPosts);
      expect(empty.title, l10n.feedEmptyTitle);
      expect(empty.description, l10n.feedEmptyDesc);
      expect(find.text(l10n.feedEmptyCta), findsNothing);
      expect(find.byType(GuListEnd), findsNothing);

      await _pump(
        tester,
        session: feedSession(role: ClubRole.president),
        state: const ClubFeedState(),
      );
      empty = tester.widget<GuEmptyState>(find.byType(GuEmptyState));
      expect(empty.description, l10n.feedEmptyDescManager);
      expect(find.text(l10n.feedEmptyCta), findsOneWidget);
      // Giriş kartı + boş durum düğmesi aynı aksiyondur.
      expect(find.byKey(_compose), findsNWidgets(2));
    });

    testWidgets('süzgece uyan yok → boş durum; okunmamış sayfa varken '
        'iskelet', (tester) async {
      final onlyPosts = loadedFeedState().copyWith(
        posts: [kImagePost],
        clearPinned: true,
        filter: FeedFilter.polls,
      );
      await _pump(tester, state: onlyPosts);
      expect(find.byType(GuEmptyState), findsOneWidget);
      expect(find.byType(PostCard), findsNothing);

      await _pump(tester, state: onlyPosts.copyWith(cursor: PageCursor.fake()));
      expect(find.byType(GuEmptyState), findsNothing);
      expect(find.byType(GuSkeletonList), findsOneWidget);
    });

    testWidgets('sonraki sayfa okunurken liste sonunda 1 kart iskeleti; '
        'liste sonu yazısı yok', (tester) async {
      await _pump(
        tester,
        state: loadedFeedState().copyWith(
          cursor: PageCursor.fake(),
          isLoadingMore: true,
        ),
      );
      expect(_cards(tester), hasLength(kFeedPosts.length));
      final skeleton = tester.widget<GuSkeletonList>(
        find.byType(GuSkeletonList),
      );
      expect(skeleton.count, 1);
      expect(skeleton.variant, GuSkeletonVariant.card);
      expect(find.byType(GuListEnd), findsNothing);
    });

    testWidgets('çevrimdışı: akış ekranda kalır; beğeni yazılmaz → TST-24', (
      tester,
    ) async {
      await _pumpRoute(tester);
      _connectivity().isOffline = true;
      await _tapKey(tester, _like(kImagePost.id));
      await tester.pumpAndSettle();
      expect(_cardIds(tester), kFeedOrder);
      expect(_feedback().toasts, [ToastId.tst24]);
      expect(feedPosts().callsTo('like'), isEmpty);
    });
  });

  group('FED-01 · Akış · aksiyon envanteri', () {
    testWidgets('üye bakışı: envanterdeki anahtarlar birebir', (tester) async {
      await _pump(tester);
      // `FED-01.back` prototipin bağımsız "Akış" sayfasının başlık
      // çubuğudur (`screens-clubs.js:73`); uygulamada FED-01 CLB-03'ün
      // sekmesidir, geri düğmesi `CLB-03.back`'tir (CD-10).
      expectActionInventory(
        tester,
        'FED-01',
        role: 'member',
        extraExempt: const {'FED-01.back'},
      );
    });

    testWidgets('yönetici bakışı: yazı girişi envanter dışı fazlalık '
        'üretmez', (tester) async {
      await _pump(tester, session: feedSession(role: ClubRole.board));
      expectActionInventory(
        tester,
        'FED-01',
        extraExempt: const {'FED-01.back'},
      );
      expect(find.byKey(_compose), findsOneWidget);
    });
  });

  group('FED-01 · Akış · aksiyonlar', () {
    testWidgets('gönderi gövdesi → FED-02; yazar satırı → CLB-07 (kulüp '
        'bağlamıyla)', (tester) async {
      final router = await _pumpRoute(tester);
      await _tapKey(tester, _post(kImagePost.id));
      await tester.pumpAndSettle();
      expect(_location(router), '$_feedPath/posts/${kImagePost.id}');

      router.go(_feedPath);
      await tester.pumpAndSettle();
      await _tapKey(tester, _author(kImagePost.id));
      await tester.pumpAndSettle();
      expect(_location(router), '$_feedPath/user/${kImagePost.authorId}');
    });

    testWidgets('FED-02 sayfasından geri dönülünce gönderi yeniden okunur', (
      tester,
    ) async {
      final router = await _pumpRoute(tester);
      await _tapKey(tester, _post(kImagePost.id));
      await tester.pumpAndSettle();
      feedPosts().put(
        kImagePost.copyWith(commentCount: kImagePost.commentCount + 1),
      );
      router.pop();
      await tester.pumpAndSettle();
      expect(_location(router), _feedPath);
      expect(
        _stateOf(tester).postById(kImagePost.id)!.commentCount,
        kImagePost.commentCount + 1,
      );
    });

    testWidgets('tür çipleri listeyi süzer', (tester) async {
      await _pumpRoute(tester);
      await _tapKey(tester, _filter(FeedFilter.announcements));
      expect(_cardIds(tester), [kPinnedPost.id]);
      await _tapKey(tester, _filter(FeedFilter.polls));
      expect(_cardIds(tester), [kPollPost.id]);
      await _tapKey(tester, _filter(FeedFilter.images));
      expect(_cardIds(tester), hasLength(2));
      await _tapKey(tester, _filter(FeedFilter.all));
      expect(_cardIds(tester), kFeedOrder);
    });

    testWidgets('beğen: kart anında beğenilmiş olur ve yazılır; yazılamazsa '
        'geri alınır + TST-24', (tester) async {
      await _pumpRoute(tester);
      PostCard card() =>
          _cards(tester).firstWhere((c) => c.post.id == kImagePost.id);
      await _tapKey(tester, _like(kImagePost.id));
      expect(card().liked, isTrue);
      expect(card().post.likeCount, kImagePost.likeCount + 1);
      await tester.pumpAndSettle();
      expect(feedPosts().posts[kImagePost.id]!.likedBy(kMembersUid), isTrue);
      expect(_feedback().toasts, isEmpty);

      feedPosts().failNext(FirestoreError.unavailable);
      await _tapKey(tester, _like(kImagePost.id));
      await tester.pumpAndSettle();
      expect(card().liked, isTrue);
      expect(_feedback().toasts, [ToastId.tst24]);
    });

    testWidgets('kaydet → TST-11 (Geri al kaydı kaldırır)', (tester) async {
      await _pumpRoute(tester);
      await _tapKey(tester, _save(kImagePost.id));
      await tester.pumpAndSettle();
      expect(_stateOf(tester).savedPostIds, contains(kImagePost.id));
      expect(_feedback().toasts, [ToastId.tst11]);

      _feedback().tapToastAction();
      await tester.pumpAndSettle();
      expect(_stateOf(tester).savedPostIds, isNot(contains(kImagePost.id)));
    });

    testWidgets('anket seçeneği → oy yazılır, TST-10; kart seçeneği ve '
        'sonuçları gösterir', (tester) async {
      await _pumpRoute(tester);
      final optionId = kPollPost.poll!.options.first.id;
      await _tapKey(tester, _vote(kPollPost.id, optionId));
      await tester.pumpAndSettle();
      final card = _cards(tester).firstWhere((c) => c.post.isPoll);
      expect(card.myOptionId, optionId);
      expect(card.pollResults[optionId], kPollResults[optionId]! + 1);
      expect(_feedback().toasts, [ToastId.tst10]);
      expect(feedPosts().votes[kPollPost.id]![kMembersUid], optionId);
    });

    testWidgets('danışman: beğeni ve oy → TST-26, yazılmaz', (tester) async {
      await _pumpRoute(tester, session: feedSession(role: ClubRole.advisor));
      await _tapKey(tester, _like(kImagePost.id));
      await _tapKey(
        tester,
        _vote(kPollPost.id, kPollPost.poll!.options.first.id),
      );
      await tester.pumpAndSettle();
      expect(_feedback().toasts, [ToastId.tst26, ToastId.tst26]);
      expect(feedPosts().callsTo('like'), isEmpty);
      expect(feedPosts().callsTo('vote'), isEmpty);
      expect(find.byKey(_compose), findsNothing);
    });

    testWidgets('"…" → SHT-08 (yazar olmayan üye: kaydet / paylaş / kopyala '
        '/ şikayet / engelle)', (tester) async {
      await _pumpRoute(tester);
      await _tapKey(tester, _menu(kImagePost.id));
      await tester.pumpAndSettle();
      expect(_feedback().sheets, [SheetId.sht08]);
      final menu =
          _feedback().lastSheetBuilder!(tester.element(find.byType(_Host)))
              as PostMenu;
      expect(menu.isOwn, isFalse);
      expect(menu.canManage, isFalse);
      expect(menu.isSaved, isFalse);
      expect(menu.isPinned, isFalse);
    });

    testWidgets('paylaş → SHT-15', (tester) async {
      await _pumpRoute(tester);
      await _tapKey(tester, _share(kImagePost.id));
      await tester.pumpAndSettle();
      expect(_feedback().sheets, [SheetId.sht15]);
    });

    testWidgets('yorum → SHT-09 (rotanın verdiği gövde); "Tümünü gör" → '
        'FED-02; kapanınca gönderi yeniden okunur', (tester) async {
      final router = await _pumpRoute(tester);
      feedPosts().calls.clear();
      await _tapKey(tester, _comment(kImagePost.id));
      await tester.pumpAndSettle();
      expect(_feedback().sheets, [SheetId.sht09]);
      final body =
          _feedback().lastSheetBuilder!(tester.element(find.byType(_Host)))
              as Text;
      expect(body.data, 'comments:$kFeedClubId/${kImagePost.id}');
      expect(_location(router), _feedPath);
      expect(feedPosts().callsTo('getPost').single.args, [kImagePost.id]);

      _feedback().nextSheetResult = true;
      await _tapKey(tester, _comment(kImagePost.id));
      await tester.pumpAndSettle();
      expect(_location(router), '$_feedPath/posts/${kImagePost.id}');
    });

    testWidgets('görsel hücresi → SHT-34 (dokunulan sıradan açılır)', (
      tester,
    ) async {
      await _pumpRoute(tester);
      await _tapKey(tester, _image(kImagePost.id, 1));
      await tester.pumpAndSettle();
      expect(_feedback().sheets, [SheetId.sht34]);
      final viewer =
          _feedback().lastSheetBuilder!(tester.element(find.byType(_Host)))
              as ImageViewerSheet;
      expect(viewer.images, kImagePost.images);
      expect(viewer.initialIndex, 1);
      expect(viewer.club, kMembersClub);

      viewer.onShare!();
      await tester.pumpAndSettle();
      expect(_feedback().sheets, [SheetId.sht34, SheetId.sht15]);
    });

    testWidgets('"Yeniden dene" akışı yeniden okur', (tester) async {
      await _pumpRoute(
        tester,
        seed: () => feedPosts().failNext(FirestoreError.unavailable),
      );
      expect(find.byType(GuErrorState), findsOneWidget);
      await _tapKey(tester, _retry);
      await tester.pumpAndSettle();
      expect(find.byType(GuErrorState), findsNothing);
      expect(_cardIds(tester), kFeedOrder);
    });

    testWidgets('sayfalama: sona yaklaşınca sonraki sayfa okunur', (
      tester,
    ) async {
      await _pumpRoute(
        tester,
        seed: () => extraFeedPosts(18).forEach(feedPosts().put),
        size: const Size(390, 844),
      );
      expect(_stateOf(tester).posts, hasLength(Limits.pageSize));
      expect(_stateOf(tester).hasMore, isTrue);
      expect(find.byType(GuListEnd), findsNothing);

      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      expect(position.axis, Axis.vertical);
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(_stateOf(tester).hasMore, isFalse);
      expect(_stateOf(tester).posts, hasLength(kFeedPosts.length + 18));
      // Liste tembel kurulur (T-44): liste sonu yeni sonda çizilir.
      await tester.scrollUntilVisible(
        find.byType(GuListEnd),
        _scrollStep,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byType(GuListEnd), findsOneWidget);
    });

    testWidgets('yönetici: "Kulübüne bir şey yaz…" → FED-03 (`ComposeRoute`); '
        'geri dönülünce akış yenilenir (yeni gönderi başta)', (tester) async {
      final router = await _pumpRoute(
        tester,
        session: feedSession(role: ClubRole.board),
      );
      await _tapKey(tester, _compose);
      await tester.pumpAndSettle();
      expect(_location(router), '$_feedPath/compose');
      expect(_feedback().toasts, isEmpty);

      final published = extraFeedPosts(1).single;
      feedPosts().put(published);
      router.pop();
      await tester.pumpAndSettle();
      expect(_location(router), _feedPath);
      expect(_stateOf(tester).postById(published.id), isNotNull);
      expect(_stateOf(tester).isFetching, isFalse);
    });

    testWidgets('"…" → SHT-08 "Düzenle" → FED-03 düzenleme kipi (`?edit=`); '
        'geri dönülünce gönderi yeniden okunur', (tester) async {
      final router = await _pumpRoute(
        tester,
        session: feedSession(role: ClubRole.board),
      );
      _feedback().nextSheetResult = PostMenuAction.edit;
      await _tapKey(tester, _menu(kImagePost.id));
      await tester.pumpAndSettle();
      expect(_feedback().sheets, [SheetId.sht08]);
      expect(_location(router), '$_feedPath/compose?edit=${kImagePost.id}');

      feedPosts().put(kImagePost.copyWith(text: 'Düzenlenmiş metin'));
      router.pop();
      await tester.pumpAndSettle();
      expect(
        _stateOf(tester).postById(kImagePost.id)!.text,
        'Düzenlenmiş metin',
      );
    });
  });

  group('FED-01 · Akış · CLB-03 içinde', () {
    testWidgets('T-44 · D3-05: Gönderiler → Hakkında → Gönderiler akışı '
        'yeniden okumaz, iskelet çizilmez', (tester) async {
      await _pumpClubDetail(tester);
      expect(find.byType(ClubFeedTab), findsOneWidget);
      final feedReads = feedPosts().callsTo('listFeed').length;
      final clubReads = _clubs().callsTo('getClub').length;
      final managerReads = _memberships().callsTo('listManagers').length;
      expect(feedReads, 1);

      await _tapKey(tester, GuKey.action('CLB-03.tab.about'));
      await tester.pumpAndSettle();
      expect(find.byType(ClubFeedTab), findsNothing);
      await _tapKey(tester, GuKey.action('CLB-03.tab.posts'));
      // İlk karede iskelet yok: akış canlı kaldı.
      expect(find.byType(GuSkeletonList), findsNothing);
      expect(find.byType(PostCard), findsWidgets);
      await tester.pumpAndSettle();

      expect(feedPosts().callsTo('listFeed'), hasLength(feedReads));
      expect(_clubs().callsTo('getClub'), hasLength(clubReads));
      expect(
        _memberships().callsTo('listManagers'),
        hasLength(managerReads),
      );
    });

    testWidgets('T-44 · D3-05: sekmeden çıkınca süzgeç "Tümü"ne döner', (
      tester,
    ) async {
      await _pumpClubDetail(tester);
      await _tapKey(tester, _filter(FeedFilter.polls));
      expect(_stateOf(tester).filter, FeedFilter.polls);

      await _tapKey(tester, GuKey.action('CLB-03.tab.events'));
      await tester.pumpAndSettle();
      await _tapKey(tester, GuKey.action('CLB-03.tab.posts'));
      await tester.pumpAndSettle();
      expect(_stateOf(tester).filter, FeedFilter.all);
      expect(
        tester.widget<GuChip>(find.byKey(_filter(FeedFilter.all))).selected,
        isTrue,
      );
      expect(feedPosts().callsTo('listFeed'), hasLength(1));
    });

    testWidgets('T-44 · D3-05: erişim kaybında ve CLB-03 kapanınca akış '
        'ViewModel’i atılır; yeniden açınca akış okunur', (tester) async {
      final router = await _pumpClubDetail(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ClubDetailView)),
      );
      await _tapKey(tester, GuKey.action('CLB-03.tab.about'));
      await tester.pumpAndSettle();
      expect(container.exists(_provider), isTrue);

      // Kulüpten çıkarıldı: içini görmez → akış bırakılır.
      container.read(sessionViewModelProvider.notifier).state = feedSession()
          .copyWith(memberships: const {});
      await tester.pumpAndSettle();
      expect(container.exists(_provider), isFalse);

      // Üyelik geri gelir, akış yeniden okunur; sayfa kapanınca atılır.
      container.read(sessionViewModelProvider.notifier).state = feedSession();
      await tester.pumpAndSettle();
      await _tapKey(tester, GuKey.action('CLB-03.tab.posts'));
      await tester.pumpAndSettle();
      expect(feedPosts().callsTo('listFeed'), hasLength(2));
      router.go('/start');
      await tester.pumpAndSettle();
      expect(container.exists(_provider), isFalse);

      router.go(_feedPath);
      await tester.pumpAndSettle();
      expect(find.byType(ClubFeedTab), findsOneWidget);
      expect(feedPosts().callsTo('listFeed'), hasLength(3));
    });

    testWidgets('"Gönderiler" sekmesi akışı çizer; CLB-03 kaydırma alanının '
        'sonuna gelince sonraki sayfa okunur', (tester) async {
      GoRouter? created;
      await tester.pumpAppRouter(
        routerOf: (_) => created ??= GoRouter(
          initialLocation: '/start',
          routes: [
            GoRoute(path: '/start', builder: (_, _) => const _Stub('/start')),
            GoRoute(
              path: '/clubs/:clubId',
              builder: (_, state) => ClubDetailView(
                clubId: state.pathParameters['clubId']!,
                tab: ClubDetailTab.posts,
                commentsSheetBuilder: _commentsStub,
              ),
            ),
            GoRoute(
              path: '/not-found',
              builder: (_, _) => const _Stub('/not-found'),
            ),
          ],
        ),
        overrides: [
          sessionViewModelProvider.overrideWithBuild(
            (ref, notifier) => feedSession(),
          ),
        ],
      );
      final router = created!;
      addTearDown(router.dispose);
      seedFeed();
      extraFeedPosts(18).forEach(feedPosts().put);
      router.go(_feedPath);
      await tester.pumpAndSettle();

      expect(find.byType(ClubFeedTab), findsOneWidget);
      expect(_stateOf(tester).posts, hasLength(Limits.pageSize));
      expect(_cards(tester).first.post.id, kPinnedPost.id);
      expect(find.byKey(_filter(FeedFilter.all)), findsOneWidget);

      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      expect(position.axis, Axis.vertical);
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(_stateOf(tester).hasMore, isFalse);
      expect(_stateOf(tester).posts, hasLength(kFeedPosts.length + 18));
    });
  });

  group('FED-01 · Akış · performans (T-44)', () {
    testWidgets('tembel liste: 60 görselli gönderiden yalnızca görünen ve '
        'önbellek alanındaki kartlar kurulur; adres istekleri onlarla '
        'sınırlı', (tester) async {
      final posts = _imagePosts(60);
      await _pump(
        tester,
        size: const Size(390, 844),
        state: loadedFeedState().copyWith(posts: posts, clearPinned: true),
      );
      final built = tester
          .widgetList<PostCard>(find.byType(PostCard, skipOffstage: false))
          .toList();
      expect(built, isNotEmpty);
      expect(built.length, lessThan(10));
      final requested = {
        for (final call in _storage().callsTo('downloadUrl')) call.args.first,
      };
      expect(requested, {
        for (final card in built)
          for (final image in card.post.images) image.path,
      });
      expect(requested.length, lessThan(posts.length));
    });

    testWidgets('tek beğeni yalnızca kurulu (görünen + önbellek) kartları '
        'yeniden kurar', (tester) async {
      await _pumpRoute(
        tester,
        seed: () => extraFeedPosts(18).forEach(feedPosts().put),
        size: const Size(390, 844),
      );
      expect(_stateOf(tester).posts, hasLength(Limits.pageSize));
      final like = find.byKey(_like(kPinnedPost.id));
      await tester.ensureVisible(like);
      await tester.pump();
      final mounted = tester
          .widgetList<PostCard>(find.byType(PostCard, skipOffstage: false))
          .map((card) => card.post.id)
          .toSet();
      expect(mounted.length, lessThan(Limits.pageSize));

      final rebuilt = <String>[];
      debugOnRebuildDirtyWidget = (element, _) {
        final widget = element.widget;
        if (widget is PostCard) rebuilt.add(widget.post.id);
      };
      addTearDown(() => debugOnRebuildDirtyWidget = null);
      await tester.tap(like);
      await tester.pump();
      // Yalnızca kurulu kartlar, her biri bir kez.
      expect(rebuilt, isNotEmpty);
      expect(rebuilt.toSet(), mounted);
      expect(rebuilt, hasLength(mounted.length));
    });

    testWidgets('adres gelişi yalnızca o görselin kartını yeniden kurar '
        '(ClubFeedTab ve öteki kartlar kurulmaz)', (tester) async {
      await _pumpRoute(
        tester,
        overrides: [
          storageImageFactoryProvider.overrideWithValue(_memoryImage),
        ],
      );
      final path = kImagePost.images.first.path;
      // İlk istek dosya yokken düştü; dosya yüklenir, yeniden deneme süresi
      // dolar ve adres istenir (çizimdeki yenilemeyle aynı yol).
      await _storage().upload(
        path: path,
        bytes: Uint8List(3),
        contentType: 'image/png',
      );
      feedClock().advance(const Duration(minutes: 1));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ClubFeedTab)),
      );
      final counts = <Type, int>{};
      final rebuiltCards = <String>[];
      debugOnRebuildDirtyWidget = (element, _) {
        final widget = element.widget;
        counts[widget.runtimeType] = (counts[widget.runtimeType] ?? 0) + 1;
        if (widget is PostCard) rebuiltCards.add(widget.post.id);
      };
      addTearDown(() => debugOnRebuildDirtyWidget = null);
      // Sahte depo eşzamanlı tamamlanır: adres mikro görevde gelir.
      await container.read(imageUrlCacheProvider).request(path);
      await tester.pump();
      await tester.pump();

      expect(counts[ClubFeedTab] ?? 0, 0);
      expect(rebuiltCards, [kImagePost.id]);
      final card = tester.widget<PostCard>(
        find.byWidgetPredicate(
          (w) => w is PostCard && w.post.id == kImagePost.id,
        ),
      );
      expect(card.imageOf!(kImagePost.images.first), isA<MemoryImage>());
    });

    testWidgets('"Devamı" ile açılan kart ekran dışına kaydırılıp geri '
        'gelince açık kalır', (tester) async {
      final long = kImagePost.copyWith(
        id: 'plong',
        text: List.filled(80, 'Kulüp').join(' '),
        images: const [],
        createdAt: kFeedNowUtc.subtract(const Duration(seconds: 30)),
      );
      await _pumpRoute(
        tester,
        seed: () {
          extraFeedPosts(18).forEach(feedPosts().put);
          feedPosts().put(long);
        },
        size: const Size(390, 844),
      );
      final more = GuKey.action('FED-01.more.${long.id}');
      await _tapKey(tester, more);
      await tester.pumpAndSettle();
      expect(find.byKey(more), findsNothing);

      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.byKey(_post(long.id)), findsNothing);
      position.jumpTo(0);
      await tester.pumpAndSettle();

      expect(find.byKey(_post(long.id)), findsOneWidget);
      expect(find.byKey(more), findsNothing);
    });
  });

  group('FED-01 · Akış · cihaz matrisi', () {
    Widget view(BuildContext context) =>
        const _Host(cacheExtent: _matrixCacheExtent);

    testWidgets('üye bakışı (dolu akış)', (tester) async {
      await DeviceMatrix.run(tester, view, overrides: _overrides());
    });

    testWidgets('yönetici bakışı (yazı girişi); yükleniyor, hata, boş', (
      tester,
    ) async {
      final manager = feedSession(role: ClubRole.board);
      for (final state in [
        loadedFeedState(session: manager),
        const ClubFeedState(isFetching: true),
        const ClubFeedState(isError: true),
        const ClubFeedState(),
      ]) {
        await DeviceMatrix.run(
          tester,
          view,
          overrides: _overrides(session: manager, state: state),
        );
      }
    });
  });

  group('FED-01 · Akış · golden', () {
    testWidgets('varsayılan (üye bakışı) açık + koyu', (tester) async {
      await goldenForThemes(
        tester,
        'FED-01',
        const _Host(),
        overrides: _overrides(),
      );
    });
  });
}
