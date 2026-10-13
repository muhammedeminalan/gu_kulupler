// CLB-01 · Kulüpler — içerik (TR / EN), üye görünümü ("Kulüplerim"), durumlar
// (yükleniyor, hata, boş, çevrimdışı), aksiyon envanteri (kabukla 44 anahtar),
// her aksiyonun sonucu (CLB-02 / CLB-03 / CLB-04 / CLB-05 gezinmesi, SHT-04,
// SHT-05, TST-24 / TST-34 / TST-X1), başa kaydırma, cihaz matrisi, açık +
// koyu golden.
// Referans: design/reference-shots/screens/CLB-01__*.webp,
// design/reference-shots/states/CLB-01__*.webp,
// design/prototype/app/screens-clubs.js:19–33.
//
// İki kip (CLB-03 testleriyle aynı düzen):
// * **Durum kipi** (içerik, durumlar, matris, envanter, golden): ekran
//   `pumpApp` ile çizilir, ViewModel durumu ezilir (okuma yapılmaz).
// * **Akış kipi** (aksiyon sonuçları): ekran gerçek ViewModel, sahte depolar
//   ve yer tutucu hedef rotalarla açılır.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/clubs/provider/club_filters.dart';
import 'package:gu_kulupler/features/clubs/provider/club_list_state.dart';
import 'package:gu_kulupler/features/clubs/provider/club_list_view_model.dart';
import 'package:gu_kulupler/features/clubs/provider/join_application_state.dart';
import 'package:gu_kulupler/features/clubs/view/club_list_view.dart';
import 'package:gu_kulupler/features/clubs/view/widget/club_filter_sheet.dart';
import 'package:gu_kulupler/features/clubs/view/widget/club_list_toolbar.dart';
import 'package:gu_kulupler/features/clubs/view/widget/first_club_card.dart';
import 'package:gu_kulupler/features/clubs/view/widget/join_application_sheet.dart';
import 'package:gu_kulupler/features/clubs/view/widget/my_clubs_strip.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/l10n/static_labels.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';
import 'package:gu_kulupler/product/widget/club/club_card.dart';
import 'package:gu_kulupler/product/widget/club/my_club_chip.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fakes/fake_club_repository.dart';
import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_membership_repository.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';
import '../club_list_test_support.dart';

final Key _search = GuKey.action('CLB-01.search');
final Key _refresh = GuKey.action('CLB-01.refresh');
final Key _discover = GuKey.action('CLB-01.discover');
final Key _filter = GuKey.action('CLB-01.filter');
final Key _toggleView = GuKey.action('CLB-01.toggleView');
final Key _categoryAll = GuKey.action('CLB-01.category.all');
final Key _myClubsAll = GuKey.action('CLB-01.myClubsAll');
final Key _clearFilters = GuKey.action('CLB-01.clearFilters');
final Key _retry = GuKey.action('CLB-01.retry');

Key _category(String id) => GuKey.action('CLB-01.category.$id');
Key _card(String id) => GuKey.action('CLB-01.card.$id');
Key _join(String id) => GuKey.action('CLB-01.join.$id');
Key _status(String id) => GuKey.action('CLB-01.status.$id');
Key _open(String id) => GuKey.action('CLB-01.open.$id');
Key _myClub(String id) => GuKey.action('CLB-01.myClub.$id');

/// Tembel listenin 13 kartı da kurulsun diye uzun yüzey.
const Size _tall = Size(390, 6400);

const String _clubsPath = '/clubs';

FakeFeedbackService _feedback() =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;

FakeClubRepository _clubs() => GetIt.I<ClubRepository>() as FakeClubRepository;

FakeMembershipRepository _memberships() =>
    GetIt.I<MembershipRepository>() as FakeMembershipRepository;

FakeConnectivityService _connectivity() =>
    GetIt.I<ConnectivityService>() as FakeConnectivityService;

/// Durum kipi: oturum + ViewModel durumu ezilir.
List<Override> _overrides(SessionState session, {ClubListState? state}) => [
  sessionViewModelProvider.overrideWithBuild((ref, notifier) => session),
  clubListViewModelProvider.overrideWithBuild(
    (ref, notifier) => state ?? loadedListState(session),
  ),
];

/// Ekranı [session] oturumunun dolu durumuyla (ya da [state] ile) çizer.
Future<void> _pump(
  WidgetTester tester, {
  SessionState? session,
  ClubListState? state,
  Locale locale = const Locale('tr'),
  ThemeMode theme = ThemeMode.light,
  Size size = const Size(390, 844),
  bool wrapInShell = false,
}) async {
  await tester.pumpApp(
    const ClubListView(),
    locale: locale,
    theme: theme,
    size: size,
    wrapInShell: wrapInShell,
    overrides: _overrides(session ?? kVisitorSession, state: state),
  );
  await tester.pump();
}

/// Akış kipi: ekranı gerçek ViewModel ve yer tutucu rotalarla açar. Depolar
/// ekran açılmadan önce tohumlanır ([seed] ek değişiklik içindir).
Future<GoRouter> _pumpRoute(
  WidgetTester tester, {
  SessionState? session,
  void Function()? seed,
  Size size = _tall,
}) async {
  GoRouter? created;
  await tester.pumpAppRouter(
    size: size,
    routerOf: (_) => created ??= GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(path: '/start', builder: (_, _) => const _Stub('/start')),
        GoRoute(
          path: _clubsPath,
          builder: (_, _) => const ClubListView(),
          routes: [
            GoRoute(
              path: 'search',
              builder: (_, state) => _Stub(state.uri.path),
            ),
            GoRoute(
              path: ':clubId',
              builder: (_, state) => _Stub(state.uri.path),
              routes: [
                for (final segment in ['applied', 'application'])
                  GoRoute(
                    path: segment,
                    builder: (_, state) => _Stub(state.uri.path),
                  ),
              ],
            ),
          ],
        ),
      ],
    ),
    overrides: [
      sessionViewModelProvider.overrideWithBuild(
        (ref, notifier) => session ?? kVisitorSession,
      ),
    ],
  );
  final router = created!;
  addTearDown(router.dispose);
  seedClubs();
  seed?.call();
  router.go(_clubsPath);
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

/// Ekranın öğesi (üstüne sayfa açılmışken de bulunur).
Element _viewElement(WidgetTester tester) =>
    tester.element(find.byType(ClubListView, skipOffstage: false));

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(_viewElement(tester));

ClubListState _stateOf(WidgetTester tester) =>
    _container(tester).read(clubListViewModelProvider);

Future<void> _tapKey(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

List<ClubCard> _cards(WidgetTester tester) =>
    tester.widgetList<ClubCard>(find.byType(ClubCard)).toList();

ClubCard _cardOf(WidgetTester tester, String clubId) =>
    _cards(tester).firstWhere((card) => card.club.id == clubId);

ScrollPosition _scroll(WidgetTester tester) => tester
    .widget<CustomScrollView>(find.byType(CustomScrollView))
    .controller!
    .position;

void main() {
  group('CLB-01 · Kulüpler · içerik', () {
    for (final locale in DeviceMatrix.locales) {
      testWidgets('ziyaretçi (${locale.languageCode}): başlık, "İlk kulübünü '
          'bul", kategori çipleri, sayaç satırı, kartlar', (tester) async {
        await _pump(tester, locale: locale, size: _tall);
        final l10n = tester.l10n;
        final context = tester.element(find.byType(ClubListView));
        final gu = context.gu;

        // Büyük başlık + ara.
        final bar = tester.widget<GuAppBar>(find.byType(GuAppBar));
        expect(bar.large, isTrue);
        expect(bar.title, l10n.navClubs);
        expect(bar.onBack, isNull);
        final search = tester.widget<GuIconButton>(find.byKey(_search));
        expect(search.icon, GuIcons.search);
        expect(search.semanticLabel, l10n.commonSearch);

        // Üyelik yok: "Kulüplerim" yerine soluk kart.
        expect(find.byType(MyClubsStrip), findsNothing);
        final first = find.byType(FirstClubCard);
        expect(
          tester
              .widget<GuCard>(
                find.descendant(of: first, matching: find.byType(GuCard)),
              )
              .muted,
          isTrue,
        );
        final illustration = tester.widget<GuIllustration>(
          find.descendant(of: first, matching: find.byType(GuIllustration)),
        );
        expect(illustration.illustration, GuIllustrations.emptyClubs);
        expect(illustration.size, FirstClubCard.illustrationSize);
        expect(
          tester.widget<Text>(find.text(l10n.clubsFirstTitle)).style,
          gu.text.titleS,
        );
        expect(find.text(l10n.clubsFirstDesc), findsOneWidget);
        final discover = tester.widget<GuButton>(find.byKey(_discover));
        expect(discover.label, l10n.clubsFirstCta);
        expect(discover.size, GuButtonSize.sm);
        expect(discover.variant, GuButtonVariant.tonal);

        // Kategori çipleri: "Tümü" seçili + 8 kategori, tasarım sırasıyla.
        final chips = tester.widgetList<GuChip>(find.byType(GuChip)).toList();
        expect(chips.map((chip) => chip.label), [
          l10n.commonAll,
          for (final category in StaticTables.categories)
            StaticLabels.category(context, category.id),
        ]);
        expect(chips.map((chip) => chip.selected), [
          true,
          ...List.filled(StaticTables.categories.length, false),
        ]);
        expect(chips.first.icon, isNull);
        expect(chips[1].icon, GuIcons.cpu);
        expect(chips[3].icon, GuIcons.mountain);

        // Sayaç + "Filtre / Sırala" + görünüm düğmesi; etkin süzgeç yok.
        final count = tester.widget<Text>(
          find.text(l10n.clubsCount(kActiveClubCount)),
        );
        expect(count.style?.color, gu.colors.textSecondary);
        final filter = tester.widget<GuButton>(find.byKey(_filter));
        expect(filter.label, l10n.commonFilterSort);
        expect(filter.icon, GuIcons.slidersHorizontal);
        expect(filter.size, GuButtonSize.sm);
        expect(filter.variant, GuButtonVariant.outline);
        expect(
          find.descendant(
            of: find.byType(ClubListToolbar),
            matching: find.byType(GuCountBadge),
          ),
          findsNothing,
        );
        final toggle = tester.widget<GuIconButton>(find.byKey(_toggleView));
        expect(toggle.icon, GuIcons.layoutGrid);
        expect(toggle.semanticLabel, l10n.commonGridView);

        // Kartlar: askıdaki kulüp yok, üye sayısına göre; liste kartı,
        // ziyaretçi; yönetici önizlemesi yalnızca okunan kulüpte.
        final cards = _cards(tester);
        expect(cards, hasLength(kActiveClubCount));
        expect(cards.first.club.id, kApprovalClubId);
        expect(
          cards.map((card) => card.club.memberCount),
          [...cards.map((card) => card.club.memberCount)]
            ..sort((a, b) => b.compareTo(a)),
        );
        expect(cards.map((card) => card.grid).toSet(), {false});
        expect(cards.map((card) => card.access).toSet(), {ClubAccess.visitor});
        expect(cards.first.memberPreview, hasLength(kManagers.length));
        expect(
          cards.first.memberPreview.first.seed,
          kPresident.applicant.avatarSeed,
        );
        expect(
          tester.widget<GuListEnd>(find.byType(GuListEnd)).label,
          l10n.commonAllDone,
        );
      });
    }

    testWidgets('üye: "Kulüplerim" şeridi (etkin üyelikler; yönetici rozeti), '
        '"Tümü" kartı; kartlar kullanıcının kipiyle', (tester) async {
      await _pump(tester, session: kMemberSession, size: _tall);
      final l10n = tester.l10n;

      expect(find.byType(FirstClubCard), findsNothing);
      expect(
        find.descendant(
          of: find.byType(MyClubsStrip),
          matching: find.text(l10n.clubsMyTitle),
        ),
        findsOneWidget,
      );
      final chips = tester
          .widgetList<MyClubChip>(find.byType(MyClubChip))
          .toList();
      // Bekleyen (c06) ve reddedilen (c05) üyelik şeride girmez.
      expect(chips.map((chip) => chip.club.id), ['c01', 'c07']);
      expect(chips.map((chip) => chip.manager), [false, true]);
      expect(chips.map((chip) => chip.unread).toSet(), {false});
      expect(find.byKey(_myClub('c01')), findsOneWidget);
      final all = find.byKey(_myClubsAll);
      expect(
        find.descendant(of: all, matching: find.text(l10n.commonAll)),
        findsOneWidget,
      );
      expect(
        tester
            .widget<GuIcon>(
              find.descendant(of: all, matching: find.byType(GuIcon)),
            )
            .icon,
        GuIcons.arrowRight,
      );

      expect(_cardOf(tester, 'c01').access, ClubAccess.member);
      expect(_cardOf(tester, 'c07').access, ClubAccess.manager);
      expect(_cardOf(tester, 'c06').access, ClubAccess.pending);
      expect(_cardOf(tester, 'c06').membershipStatus, MembershipStatus.pending);
      expect(_cardOf(tester, 'c05').access, ClubAccess.rejected);
      expect(_cardOf(tester, kApprovalClubId).access, ClubAccess.visitor);
      expect(find.byKey(_open('c01')), findsOneWidget);
      expect(find.byKey(_status('c06')), findsOneWidget);
    });

    testWidgets('ızgara + etkin süzgeç: iki sütun, rozet, "Liste görünümü"; '
        'seçili kategori çipi', (tester) async {
      const filters = ClubFilters(categoryIds: {'k04'}, sort: ClubSort.az);
      await _pump(
        tester,
        size: _tall,
        state: loadedListState(
          kVisitorSession,
          base: const ClubListState(
            layout: ClubListLayout.grid,
            filters: filters,
          ),
        ),
      );
      final l10n = tester.l10n;

      final cards = _cards(tester);
      expect(cards.map((card) => card.club.categoryId).toSet(), {'k04'});
      expect(cards.map((card) => card.grid).toSet(), {true});
      // İlk iki kart aynı satırda, eşit yükseklikte.
      final a = tester.getRect(find.byKey(_card(cards[0].club.id)));
      final b = tester.getRect(find.byKey(_card(cards[1].club.id)));
      expect(a.top, b.top);
      expect(a.height, b.height);
      expect(b.left - a.right, GuSizes.gridGap);

      final badge = tester.widget<GuCountBadge>(
        find.descendant(
          of: find.byType(ClubListToolbar),
          matching: find.byType(GuCountBadge),
        ),
      );
      expect(badge.label, '${filters.activeCount}');
      expect(
        find.bySemanticsLabel(l10n.clubsActiveFilters(filters.activeCount)),
        findsOneWidget,
      );
      final toggle = tester.widget<GuIconButton>(find.byKey(_toggleView));
      expect(toggle.icon, GuIcons.list);
      expect(toggle.semanticLabel, l10n.commonListView);
      expect(tester.widget<GuChip>(find.byKey(_categoryAll)).selected, isFalse);
      expect(
        tester.widget<GuChip>(find.byKey(_category('k04'))).selected,
        isTrue,
      );
      expect(find.text(l10n.clubsCount(cards.length)), findsOneWidget);
    });

    testWidgets('anında katılım sürerken kart iyimser "üye" çizilir', (
      tester,
    ) async {
      await _pump(
        tester,
        size: _tall,
        state: loadedListState(
          kVisitorSession,
          base: const ClubListState(pendingJoinIds: {kInstantClubId}),
        ),
      );
      final card = _cardOf(tester, kInstantClubId);
      expect(card.access, ClubAccess.member);
      expect(card.membershipStatus, MembershipStatus.active);
      expect(find.byKey(_open(kInstantClubId)), findsOneWidget);
      expect(find.byKey(_join(kInstantClubId)), findsNothing);
    });
  });

  group('CLB-01 · Kulüpler · durumlar', () {
    testWidgets('yükleniyor: 6 kart iskeleti; üst bölümler yerinde', (
      tester,
    ) async {
      await _pump(tester, state: const ClubListState(isFetching: true));
      final skeleton = tester.widget<GuSkeletonList>(
        find.byType(GuSkeletonList),
      );
      expect(skeleton.count, 6);
      expect(skeleton.variant, GuSkeletonVariant.card);
      expect(skeleton.semanticLabel, tester.l10n.commonLoading);
      expect(find.byType(FirstClubCard), findsOneWidget);
      expect(find.byKey(_categoryAll), findsOneWidget);
      expect(find.byKey(_filter), findsOneWidget);
      expect(find.byType(ClubCard), findsNothing);
    });

    testWidgets('hata: "Bir şeyler ters gitti" + "Yeniden dene"; üst '
        'bölümler yerinde', (tester) async {
      await _pump(tester, state: const ClubListState(isError: true));
      final l10n = tester.l10n;
      final error = tester.widget<GuErrorState>(find.byType(GuErrorState));
      expect(error.title, l10n.sysErrorTitle);
      expect(error.description, l10n.sysErrorDesc);
      expect(error.retryLabel, l10n.commonRetry);
      expect(error.inline, isTrue);
      expect(find.byKey(_retry), findsOneWidget);
      expect(find.byKey(_categoryAll), findsOneWidget);
      expect(find.byType(GuSkeletonList), findsNothing);
    });

    testWidgets('boş: "Aramana uygun kulüp bulamadık" + "Filtreleri temizle"', (
      tester,
    ) async {
      await _pump(
        tester,
        state: loadedListState(
          kVisitorSession,
          base: const ClubListState(
            filters: ClubFilters(membership: ClubMembershipFilter.mine),
          ),
        ),
      );
      final l10n = tester.l10n;
      final empty = tester.widget<GuEmptyState>(find.byType(GuEmptyState));
      expect(empty.illustration, GuIllustrations.emptyClubs);
      expect(empty.title, l10n.clubsEmptyTitle);
      expect(empty.description, l10n.clubsEmptyDesc);
      expect(empty.ctaLabel, l10n.clubsEmptyClear);
      expect(find.byKey(_clearFilters), findsOneWidget);
      expect(find.text(l10n.clubsCount(0)), findsOneWidget);
      expect(find.byType(GuListEnd), findsNothing);
    });

    testWidgets('hata → "Yeniden dene" kulüpleri yükler; boş → "Filtreleri '
        'temizle" listeyi geri getirir', (tester) async {
      await _pumpRoute(
        tester,
        seed: () => _clubs().failNext(FirestoreError.unavailable),
      );
      expect(find.byType(GuErrorState), findsOneWidget);
      await _tapKey(tester, _retry);
      await tester.pumpAndSettle();
      expect(find.byType(GuErrorState), findsNothing);
      expect(_cards(tester), hasLength(kActiveClubCount));

      _container(tester)
          .read(clubListViewModelProvider.notifier)
          .setFilters(const ClubFilters(membership: ClubMembershipFilter.mine));
      await tester.pump();
      expect(find.byType(GuEmptyState), findsOneWidget);
      await _tapKey(tester, _clearFilters);
      expect(_stateOf(tester).filters, ClubFilters.none);
      expect(_cards(tester), hasLength(kActiveClubCount));
    });

    testWidgets('çevrimdışı: liste ekranda kalır; "Katıl" TST-24 verir, '
        'yazılmaz', (tester) async {
      await _pumpRoute(tester);
      _connectivity().isOffline = true;
      _memberships().calls.clear();
      await _tapKey(tester, _join(kInstantClubId));
      await tester.pumpAndSettle();
      expect(_feedback().toasts, [ToastId.tst24]);
      expect(_memberships().callsTo('joinInstant'), isEmpty);
      expect(_cards(tester), hasLength(kActiveClubCount));
    });
  });

  group('CLB-01 · Kulüpler · aksiyon envanteri', () {
    testWidgets('ziyaretçi, kabukla: envanterdeki 44 anahtar birebir', (
      tester,
    ) async {
      await _pump(tester, size: _tall, wrapInShell: true);
      expectActionInventory(tester, 'CLB-01', includeShell: true);
    });

    testWidgets('üye, ızgara: "Kulüplerim", durum ve "Aç" anahtarları '
        'envanter dışı fazlalık üretmez', (tester) async {
      await _pump(
        tester,
        session: kMemberSession,
        size: _tall,
        state: loadedListState(
          kMemberSession,
          base: const ClubListState(layout: ClubListLayout.grid),
        ),
      );
      expectActionInventory(
        tester,
        'CLB-01',
        // Üyede "İlk kulübünü bul" yoktur; kipi olan kartlarda "Katıl"
        // yerine "Aç" / durum düğmesi çizilir.
        extraExempt: {
          'CLB-01.discover',
          for (final id in ['c01', 'c05', 'c06', 'c07']) 'CLB-01.join.$id',
        },
      );
      for (final key in [
        _myClub('c01'),
        _myClub('c07'),
        _myClubsAll,
        _open('c01'),
        _open('c07'),
        _status('c06'),
        _status('c05'),
      ]) {
        expect(find.byKey(key), findsOneWidget);
      }
    });
  });

  group('CLB-01 · Kulüpler · aksiyonlar', () {
    testWidgets('ara → CLB-02 (/clubs/search)', (tester) async {
      final router = await _pumpRoute(tester);
      await _tapKey(tester, _search);
      await tester.pumpAndSettle();
      expect(_location(router), '$_clubsPath/search');
    });

    testWidgets('kart, "Kulüplerim" kartı ve "Aç" → CLB-03; durum → CLB-05', (
      tester,
    ) async {
      for (final (key, path) in [
        (_card(kApprovalClubId), '$_clubsPath/$kApprovalClubId'),
        (_myClub('c07'), '$_clubsPath/c07'),
        (_open('c01'), '$_clubsPath/c01'),
        (_status('c06'), '$_clubsPath/c06/application'),
      ]) {
        final router = await _pumpRoute(tester, session: kMemberSession);
        await _tapKey(tester, key);
        await tester.pumpAndSettle();
        expect(_location(router), path);
      }
    });

    testWidgets('kategori çipi tek kategori seçer; yeniden dokunma ve "Tümü" '
        'seçimi kaldırır', (tester) async {
      await _pumpRoute(tester);
      await _tapKey(tester, _category('k04'));
      expect(_stateOf(tester).filters.categoryIds, {'k04'});
      expect(
        _cards(tester).map((card) => card.club.categoryId).toSet(),
        {'k04'},
      );
      expect(
        tester.widget<GuChip>(find.byKey(_category('k04'))).selected,
        isTrue,
      );

      await _tapKey(tester, _category('k04'));
      expect(_stateOf(tester).filters, ClubFilters.none);

      await _tapKey(tester, _category('k01'));
      await _tapKey(tester, _categoryAll);
      expect(_stateOf(tester).filters, ClubFilters.none);
      expect(_cards(tester), hasLength(kActiveClubCount));
    });

    testWidgets('görünüm düğmesi liste ↔ ızgara', (tester) async {
      await _pumpRoute(tester);
      await _tapKey(tester, _toggleView);
      expect(_stateOf(tester).layout, ClubListLayout.grid);
      expect(_cards(tester).map((card) => card.grid).toSet(), {true});
      await _tapKey(tester, _toggleView);
      expect(_cards(tester).map((card) => card.grid).toSet(), {false});
    });

    testWidgets('"Filtre / Sırala" → SHT-04 (geçerli süzgeç + sonuç sayısı); '
        '"Sonuçları göster" uygular, kapatma değiştirmez', (tester) async {
      await _pumpRoute(tester);
      const result = ClubFilters(instantOnly: true, sort: ClubSort.az);
      _feedback().nextSheetResult = result;
      await _tapKey(tester, _filter);
      await tester.pumpAndSettle();

      expect(_feedback().sheets, [SheetId.sht04]);
      final sheet =
          _feedback().lastSheetBuilder!(_viewElement(tester))
              as ClubFilterSheet;
      expect(sheet.initial, ClubFilters.none);
      expect(sheet.countFor(ClubFilters.none), kActiveClubCount);
      expect(_stateOf(tester).filters, result);
      expect(
        _cards(tester).map((card) => card.club.approvalRequired).toSet(),
        {false},
      );
      expect(
        tester
            .widget<GuCountBadge>(
              find.descendant(
                of: find.byType(ClubListToolbar),
                matching: find.byType(GuCountBadge),
              ),
            )
            .label,
        '${result.activeCount}',
      );

      // Sayfa kapatılırsa (sonuç yok) süzgeç değişmez.
      await _tapKey(tester, _filter);
      await tester.pumpAndSettle();
      expect(_feedback().sheets, [SheetId.sht04, SheetId.sht04]);
      expect(_stateOf(tester).filters, result);
    });

    testWidgets('"Katıl" (onay gerekli) → SHT-05; başvuru yazıldı → CLB-04', (
      tester,
    ) async {
      final router = await _pumpRoute(tester);
      _feedback().nextSheetResult = JoinApplicationOutcome.applied;
      await _tapKey(tester, _join(kApprovalClubId));
      await tester.pumpAndSettle();
      expect(_feedback().sheets, [SheetId.sht05]);
      final sheet =
          _feedback().lastSheetBuilder!(_viewElement(tester))
              as JoinApplicationSheet;
      expect(sheet.clubId, kApprovalClubId);
      expect(_location(router), '$_clubsPath/$kApprovalClubId/applied');
    });

    testWidgets('"Katıl" (onaysız) → kart "Aç" olur, üye sayısı + 1, TST-34; '
        '"Kulübe git" → CLB-03', (tester) async {
      final router = await _pumpRoute(tester);
      final before = clubOf(kInstantClubId).memberCount;
      await _tapKey(tester, _join(kInstantClubId));
      await tester.pumpAndSettle();

      expect(_feedback().toasts, [ToastId.tst34]);
      expect(_feedback().sheets, isEmpty);
      expect(_memberships().callsTo('joinInstant'), hasLength(1));
      final card = _cardOf(tester, kInstantClubId);
      expect(card.access, ClubAccess.member);
      expect(card.club.memberCount, before + 1);
      expect(find.byKey(_open(kInstantClubId)), findsOneWidget);
      expect(find.byKey(_join(kInstantClubId)), findsNothing);

      _feedback().tapToastAction();
      await tester.pumpAndSettle();
      expect(_location(router), '$_clubsPath/$kInstantClubId');
    });

    testWidgets('"Başvurular kapalı" düğmesi → TST-X1', (tester) async {
      await _pumpRoute(tester);
      await _tapKey(tester, _join(kClosedClubId));
      await tester.pumpAndSettle();
      expect(_feedback().toasts, [ToastId.tstX1]);
      expect(_feedback().sheets, isEmpty);
    });

    testWidgets('"Keşfet" kulüp listesine kaydırır; etkin sekmeye yeniden '
        'dokunma başa döndürür', (tester) async {
      await _pumpRoute(tester, size: const Size(390, 844));
      expect(_scroll(tester).pixels, 0);
      await tester.tap(find.byKey(_discover));
      await tester.pumpAndSettle();
      final scrolled = _scroll(tester).pixels;
      expect(scrolled, greaterThan(0));
      // Kategori şeridi görünümün başındadır.
      expect(
        tester.getTopLeft(find.byKey(_categoryAll)).dy,
        lessThan(tester.getTopLeft(find.byType(CustomScrollView)).dy + 48),
      );

      _container(
        tester,
      ).read(scrollTopRequestProvider(GuTab.clubs).notifier).request();
      await tester.pumpAndSettle();
      expect(_scroll(tester).pixels, 0);
    });

    testWidgets('çek-yenile kulüpleri yeniden okur', (tester) async {
      await _pumpRoute(tester, size: const Size(390, 844));
      _clubs().calls.clear();
      await tester.drag(find.byKey(_refresh), const Offset(0, 220));
      await tester.pumpAndSettle();
      expect(_clubs().callsTo('fetchActiveClubs'), hasLength(1));
      expect(_stateOf(tester).isRefreshing, isFalse);
    });

    testWidgets('liste kartı ekrana gelince yönetici önizlemesi okunur; '
        'ızgarada okunmaz', (tester) async {
      await _pumpRoute(tester, size: const Size(390, 844));
      expect(
        _memberships().callsTo('listManagers').map((call) => call.args.single),
        contains(kApprovalClubId),
      );
      expect(
        _cardOf(tester, kApprovalClubId).memberPreview,
        hasLength(kManagers.length),
      );
      // Tembel liste: ekran dışındaki kartlar okuma yapmaz.
      expect(
        _memberships().callsTo('listManagers').length,
        lessThan(kActiveClubCount),
      );

      // Izgara kartında avatar grubu yoktur: yeni okuma istenmez.
      // (Düğme görünürdür; `ensureVisible` listeyi kaydırıp yeni liste kartı
      // kurdurmasın diye doğrudan dokunulur.)
      _memberships().calls.clear();
      await tester.tap(find.byKey(_toggleView));
      await tester.pumpAndSettle();
      expect(_cards(tester).map((card) => card.grid).toSet(), {true});
      expect(_memberships().callsTo('listManagers'), isEmpty);
    });
  });

  group('CLB-01 · Kulüpler · cihaz matrisi', () {
    Widget view(BuildContext context) => const ClubListView();

    testWidgets('ziyaretçi, liste (kabukla)', (tester) async {
      await DeviceMatrix.run(
        tester,
        view,
        overrides: _overrides(kVisitorSession),
        wrapInShell: true,
        safeAreas: true,
      );
    });

    testWidgets('üye, ızgara + etkin süzgeç ("Kulüplerim", rozet)', (
      tester,
    ) async {
      await DeviceMatrix.run(
        tester,
        view,
        overrides: _overrides(
          kMemberSession,
          state: loadedListState(
            kMemberSession,
            base: const ClubListState(
              layout: ClubListLayout.grid,
              filters: ClubFilters(sort: ClubSort.az, instantOnly: true),
            ),
          ),
        ),
      );
    });

    testWidgets('yükleniyor, hata, boş', (tester) async {
      for (final state in [
        const ClubListState(isFetching: true),
        const ClubListState(isError: true),
        const ClubListState(
          filters: ClubFilters(membership: ClubMembershipFilter.mine),
        ),
      ]) {
        await DeviceMatrix.run(
          tester,
          view,
          overrides: _overrides(kVisitorSession, state: state),
        );
      }
    });
  });

  group('CLB-01 · Kulüpler · golden', () {
    testWidgets('varsayılan (ziyaretçi, kabukla) açık + koyu', (tester) async {
      for (final theme in kGoldenThemes) {
        await _pump(tester, theme: theme, wrapInShell: true);
        await tester.pump(GuMotion.base);
        await expectLater(
          find.byKey(kPumpAppBoundaryKey),
          matchesGoldenFile(
            goldenUri(goldenPath('CLB-01', theme, const Locale('tr'))),
          ),
        );
      }
    });
  });
}
