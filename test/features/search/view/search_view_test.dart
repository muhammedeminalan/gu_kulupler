// CLB-02 · Arama — içerik (TR / EN), aksiyon envanteri, her aksiyonun sonucu
// (son aramalar: dokun / kaldır / temizle TST-06 + geri al; popüler aramalar;
// sekmeler; sorgu → 250 ms sonra sonuçlar; kulüp sonucu → CLB-03; önerilen
// kulüp kartı → CLB-03, "Katıl" → TST-34 / TST-X1 / SHT-05; "İptal"),
// durumlar (yükleniyor, hata + yeniden dene, sonuç yok, etkinlik sekmesi),
// cihaz matrisi, açık + koyu golden.
// Referans: design/reference-shots/screens/CLB-02__*.webp,
// design/prototype/app/screens-clubs.js:35–56.
//
// İki kip (CLB-03 testleriyle aynı düzen):
// * **Durum kipi** (içerik, matris, envanter, golden): ekran `pumpApp` ile
//   çizilir, ViewModel'in ilk durumu ezilir (havuz okunmaz).
// * **Akış kipi** (gezinme ve yazan aksiyonlar): ekran gerçek ViewModel,
//   sahte depolar ve yer tutucu hedef rotalarla açılır.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/search/provider/search_state.dart';
import 'package:gu_kulupler/features/search/provider/search_view_model.dart';
import 'package:gu_kulupler/features/search/view/search_view.dart';
import 'package:gu_kulupler/features/search/view/widget/recent_searches_section.dart';
import 'package:gu_kulupler/features/search/view/widget/search_result_section.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/l10n/static_labels.dart';
import 'package:gu_kulupler/product/widget/club/club_card.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../fakes/fake_app_preferences_store.dart';
import '../../../fakes/fake_club_repository.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_membership_repository.dart';
import '../../../fakes/fake_session_states.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';
import '../search_test_support.dart';

final Key _input = GuKey.action('CLB-02.input');
final Key _clear = GuKey.action('CLB-02.clear');
final Key _cancel = GuKey.action('CLB-02.cancel');
final Key _clearRecent = GuKey.action('CLB-02.clearRecent');
final Key _retry = GuKey.action('CLB-02.retry');

Key _tab(SearchScope scope) => GuKey.action('CLB-02.tab.${scope.name}');

Key _recent(int index) => GuKey.action('CLB-02.recent.$index');

Key _removeRecent(int index) => GuKey.action('CLB-02.removeRecent.$index');

Key _popular(int index) => GuKey.action('CLB-02.popular.$index');

Key _suggest(int index) => GuKey.action('CLB-02.suggest.$index');

Key _card(String clubId) => GuKey.action('CLB-02.card.$clubId');

Key _join(String clubId) => GuKey.action('CLB-02.join.$clubId');

Key _clubResult(String clubId) => GuKey.action('CLB-02.result.club.$clubId');

/// Akış kipinde yollar.
const String _clubsPath = '/clubs';
const String _searchPath = '/clubs/search';

const SearchView _view = SearchView(scope: SearchScope.clubs);

final SearchViewModelProvider _provider = searchViewModelProvider(
  SearchScope.clubs,
);

FakeFeedbackService _feedback() =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;

FakeMembershipRepository _memberships() =>
    GetIt.I<MembershipRepository>() as FakeMembershipRepository;

FakeClubRepository _clubs() => GetIt.I<ClubRepository>() as FakeClubRepository;

FakeAppPreferencesStore _store() =>
    GetIt.I<AppPreferencesStore>() as FakeAppPreferencesStore;

/// Durum kipi: oturum + ViewModel'in ilk durumu ezilir.
List<Override> _overrides({SessionState? session, SearchState? state}) => [
  sessionViewModelProvider.overrideWithBuild(
    (ref, notifier) => session ?? kVisitorSession,
  ),
  _provider.overrideWithBuild((ref, notifier) => state ?? kDefaultState),
];

/// Ekranı tasarımdaki varsayılan durumla (ya da [state] ile) çizer.
Future<void> _pump(
  WidgetTester tester, {
  SessionState? session,
  SearchState? state,
  Locale locale = const Locale('tr'),
}) async {
  await tester.pumpApp(
    _view,
    locale: locale,
    overrides: _overrides(session: session, state: state),
  );
  await tester.pump();
}

/// Akış kipi: ekranı gerçek ViewModel ve yer tutucu rotalarla açar. Depolar
/// ekran açılmadan önce tohumlanır ([seed] ek değişiklik içindir).
Future<GoRouter> _pumpRoute(
  WidgetTester tester, {
  SessionState? session,
  void Function()? seed,
}) async {
  GoRouter? created;
  await tester.pumpAppRouter(
    routerOf: (_) => created ??= GoRouter(
      initialLocation: _clubsPath,
      routes: [
        GoRoute(
          path: _clubsPath,
          builder: (_, _) => const _Stub(_clubsPath),
          routes: [
            GoRoute(path: 'search', builder: (_, _) => _view),
            GoRoute(
              path: ':clubId',
              builder: (_, state) => _Stub(state.uri.path),
              routes: [
                GoRoute(
                  path: 'application',
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
  seedSearch();
  _store().values[AppPreferenceKeys.recentSearches] = kRecent;
  seed?.call();
  router.go(_searchPath);
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

SearchState _stateOf(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(SearchView)),
).read(_provider);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _tapKey(WidgetTester tester, Key key) =>
    _tap(tester, find.byKey(key));

/// Arama alanına [text] yazar ve bekleme süresini geçirir.
Future<void> _search(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(_input), text);
  await tester.pump();
  await tester.pump(Limits.searchDebounce);
}

String _fieldValue(WidgetTester tester) =>
    tester.widget<GuSearchField>(find.byType(GuSearchField)).value;

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_GB');
  });

  group('CLB-02 · Arama · içerik', () {
    for (final locale in DeviceMatrix.locales) {
      testWidgets('varsayılan (${locale.languageCode}): arama çubuğu, '
          'sekmeler, son aramalar, popüler aramalar, önerilen kulüpler', (
        tester,
      ) async {
        await _pump(tester, locale: locale);
        final l10n = tester.l10n;
        final context = tester.element(find.byType(SearchView));
        final gu = context.gu;

        // Başlık çubuğu yok; alan otomatik odaklı, min 44, "İptal" metin
        // düğmesi.
        expect(find.byType(GuAppBar), findsNothing);
        final field = tester.widget<GuSearchField>(find.byType(GuSearchField));
        expect(field.value, isEmpty);
        expect(field.placeholder, l10n.searchPlaceholder);
        expect(field.semanticLabel, l10n.commonSearch);
        expect(field.compact, isTrue);
        expect(field.autofocus, isTrue);
        expect(find.byKey(_clear), findsNothing);
        final cancel = tester.widget<GuButton>(find.byKey(_cancel));
        expect(cancel.label, l10n.commonCancel);
        expect(cancel.variant, GuButtonVariant.text);
        // `padding:4px 8px 4px 16px`: alan soldan 16, düğme sağdan 8.
        expect(tester.getTopLeft(find.byType(GuSearchField)).dx, 16);
        expect(tester.getTopRight(find.byKey(_cancel)).dx, 390 - 8);

        // Sekmeler: Kulüpler seçili.
        final tabs = tester.widget<GuTabs>(find.byType(GuTabs));
        expect(tabs.sticky, isFalse);
        expect(tabs.value, SearchScope.clubs.name);
        expect(tabs.tabs.map((t) => t.label), [l10n.navClubs, l10n.navEvents]);

        // Son aramalar: başlık + "Temizle" + üç satır (history, "Kaldır").
        expect(find.text(l10n.searchRecent), findsOneWidget);
        final clear = tester.widget<GuButton>(find.byKey(_clearRecent));
        expect(clear.label, l10n.commonClear);
        for (final (index, term) in kRecent.indexed) {
          final tile = tester.widget<GuTile>(find.byKey(_recent(index)));
          expect(tile.title, term);
          final icon = tile.leading! as GuIcon;
          expect(icon.icon, GuIcons.history);
          expect(icon.size, GuSizes.icon20);
          expect(icon.color, gu.colors.textMuted);
          final remove = tester.widget<GuIconButton>(
            find.byKey(_removeRecent(index)),
          );
          expect(remove.icon, GuIcons.x);
          expect(remove.size, GuIconButtonSize.sm);
          expect(remove.semanticLabel, l10n.commonRemove);
        }

        // Popüler aramalar: altı çip, `trending-up` ikonlu; terimler
        // çevrilmez.
        expect(find.text(l10n.searchPopular), findsOneWidget);
        for (final (index, term) in StaticTables.popularSearches.indexed) {
          final chip = tester.widget<GuChip>(find.byKey(_popular(index)));
          expect(chip.label, term);
          expect(chip.icon, GuIcons.trendingUp);
        }

        // Önerilen kulüpler: üç liste kartı.
        expect(find.text(l10n.searchSuggested), findsOneWidget);
        final cards = tester.widgetList<ClubCard>(find.byType(ClubCard));
        expect(cards.map((c) => c.club), kDefaultState.suggested);
        expect(cards.every((c) => !c.grid), isTrue);
        expect(cards.every((c) => c.access == ClubAccess.visitor), isTrue);
      });
    }

    testWidgets('son arama yokken bölüm çizilmez; "Popüler aramalar" ilk '
        'başlıktır', (tester) async {
      await _pump(tester, state: kDefaultState.copyWith(recent: const []));
      expect(find.byType(RecentSearchesSection), findsNothing);
      expect(find.byKey(_clearRecent), findsNothing);
      final titles = tester.widgetList<GuSectionTitle>(
        find.byType(GuSectionTitle),
      );
      expect(titles.first.title, tester.l10n.searchPopular);
      expect(titles.first.topMargin, GuSectionTitleMargin.first);
    });

    testWidgets('Etkinlikler sekmesi: önerilen kulüpler yok', (tester) async {
      await _pump(
        tester,
        state: kDefaultState.copyWith(scope: SearchScope.events),
      );
      expect(find.text(tester.l10n.searchSuggested), findsNothing);
      expect(find.byType(ClubCard), findsNothing);
      expect(find.byKey(_popular(0)), findsOneWidget);
      expect(find.byKey(_recent(0)), findsOneWidget);
    });

    testWidgets('sonuçlar: kulüp satırı (amblem, kalın eşleşme, "kategori · '
        'N üye", chevron)', (tester) async {
      await _pump(
        tester,
        state: kDefaultState.copyWith(
          query: 'satranç',
          clubResults: [kChess],
        ),
      );
      final l10n = tester.l10n;
      final context = tester.element(find.byType(SearchView));
      expect(find.byType(RecentSearchesSection), findsNothing);
      expect(find.byType(ClubCard), findsNothing);
      expect(find.byKey(_clear), findsOneWidget);

      final tile = tester.widget<GuTile>(find.byKey(_clubResult(kChess.id)));
      expect(tile.title, kChess.name);
      expect(tile.chevron, isTrue);
      expect(
        tile.subtitle,
        '${StaticLabels.category(context, kChess.categoryId)} · '
        '${l10n.clubsCardMembers(kChess.memberCount)}',
      );
      expect((tile.leading! as GuEmblem).size, GuEmblemSize.sm);
      // "Satranç" kalın, kalanı düz.
      final spans = (tile.titleSpan! as TextSpan).children!.cast<TextSpan>();
      expect(spans.map((s) => s.text).join(), kChess.name);
      expect(spans.first.text, 'Satranç');
      expect(
        spans.first.style!.fontWeight,
        context.gu.text.titleL.fontWeight,
      );
      expect(spans.last.style, isNull);
    });

    test(
      'highlight: Türkçe harf duyarsız eşleşme; eşleşme yoksa düz metin',
      () {
        const bold = TextStyle(inherit: false);
        final hit = SearchResultSection.highlight('IŞIK Kulübü', 'ışık', bold);
        expect(hit.children!.cast<TextSpan>().map((s) => (s.text, s.style)), [
          ('IŞIK', bold),
          (' Kulübü', null),
        ]);
        final middle = SearchResultSection.highlight(
          'E-Spor Kulübü',
          'SPOR',
          bold,
        );
        expect(middle.children!.cast<TextSpan>().map((s) => s.text), [
          'E-',
          'Spor',
          ' Kulübü',
        ]);
        expect(
          SearchResultSection.highlight('Tiyatro', 'x', bold).text,
          'Tiyatro',
        );
        expect(
          SearchResultSection.highlight('Tiyatro', '', bold).children,
          isNull,
        );
      },
    );
  });

  group('CLB-02 · Arama · aksiyon envanteri', () {
    testWidgets('varsayılan durum envanterle birebir (23 aksiyon)', (
      tester,
    ) async {
      await _pump(tester);
      expectActionInventory(tester, 'CLB-02', role: 'guest');
    });

    testWidgets('diğer görünümler envanter dışı anahtar üretmez', (
      tester,
    ) async {
      const cards = {'CLB-02.card.*', 'CLB-02.join.*'};
      const recents = {
        'CLB-02.clearRecent',
        'CLB-02.recent.*',
        'CLB-02.removeRecent.*',
      };
      const defaults = {...cards, ...recents, 'CLB-02.popular.*'};
      for (final (state, exempt) in [
        // Etkinlikler sekmesi: önerilen kulüp yok.
        (kDefaultState.copyWith(scope: SearchScope.events), cards),
        // Son arama yok.
        (kDefaultState.copyWith(recent: const []), recents),
        // Sonuçlar, sonuç yok, yükleniyor, hata: varsayılan bölümler yok.
        (
          kDefaultState.copyWith(query: 'satranç', clubResults: [kChess]),
          defaults,
        ),
        (kDefaultState.copyWith(query: 'yok'), defaults),
        (kDefaultState.copyWith(query: 'sat', isSearching: true), defaults),
        (kDefaultState.copyWith(query: 'sat', isError: true), defaults),
        // Havuz okunamadı: önerilen kulüpler yerine satır içi hata.
        (
          kDefaultState.copyWith(isError: true, suggested: const []),
          cards,
        ),
      ]) {
        await _pump(tester, state: state);
        expectActionInventory(tester, 'CLB-02', extraExempt: exempt);
      }
    });
  });

  group('CLB-02 · Arama · aksiyonlar', () {
    testWidgets('"İptal" → önceki sayfa (Kulüpler)', (tester) async {
      final router = await _pumpRoute(tester);
      expect(_location(router), _searchPath);
      await _tapKey(tester, _cancel);
      await tester.pumpAndSettle();
      expect(_location(router), _clubsPath);
    });

    testWidgets('yazınca 250 ms sonra sonuçlar; kulüp sonucu → terim son '
        'aramalara yazılır + CLB-03', (tester) async {
      final router = await _pumpRoute(tester);
      await tester.enterText(find.byKey(_input), 'satranç');
      await tester.pump();
      // Bekleme süresinde iskelet.
      expect(find.byType(GuSkeletonList), findsOneWidget);
      expect(find.byKey(_clubResult(kChess.id)), findsNothing);
      await tester.pump(Limits.searchDebounce);
      expect(find.byType(GuSkeletonList), findsNothing);
      expect(find.byKey(_clubResult(kChess.id)), findsOneWidget);
      expect(find.byType(ClubCard), findsNothing);

      await _tapKey(tester, _clubResult(kChess.id));
      await tester.pumpAndSettle();
      expect(_location(router), '$_clubsPath/${kChess.id}');
      // Zaten listede: öne taşındı.
      expect(_store().recentSearches, [
        'satranç',
        'hackathon',
        'doğa yürüyüşü',
      ]);
    });

    testWidgets('klavyede "Ara" → terim son aramalara yazılır; (x) alanı '
        'boşaltır ve varsayılan görünüme döner', (tester) async {
      await _pumpRoute(tester);
      await _search(tester, 'tiyatro');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(_store().recentSearches.first, 'tiyatro');

      await _tapKey(tester, _clear);
      await tester.pump();
      expect(_fieldValue(tester), isEmpty);
      expect(find.byType(SearchResultSection), findsNothing);
      expect(find.byKey(_recent(0)), findsOneWidget);
      expect(
        tester.widget<GuTile>(find.byKey(_recent(0))).title,
        'tiyatro',
      );
    });

    testWidgets('son aramaya ve popüler aramaya dokunma → terim alana '
        'yazılır, sonuçlar gelir', (tester) async {
      await _pumpRoute(tester);
      await _tapKey(tester, _recent(2));
      expect(_fieldValue(tester), 'satranç');
      await tester.pump(Limits.searchDebounce);
      expect(find.byKey(_clubResult(kChess.id)), findsOneWidget);

      await _tapKey(tester, _clear);
      await tester.pump();
      await _tapKey(tester, _popular(4));
      expect(_fieldValue(tester), StaticTables.popularSearches[4]);
      await tester.pump(Limits.searchDebounce);
      expect(find.byKey(_clubResult(kPhoto.id)), findsOneWidget);
    });

    testWidgets('"Kaldır" satırı siler; "Temizle" → TST-06, "Geri al" '
        'listeyi geri getirir', (tester) async {
      await _pumpRoute(tester);
      await _tapKey(tester, _removeRecent(1));
      await tester.pump();
      expect(_stateOf(tester).recent, ['hackathon', 'satranç']);
      expect(find.byKey(_recent(2)), findsNothing);
      expect(_store().recentSearches, ['hackathon', 'satranç']);

      await _tapKey(tester, _clearRecent);
      await tester.pump();
      expect(find.byType(RecentSearchesSection), findsNothing);
      expect(_feedback().toasts, [ToastId.tst06]);
      expect(_feedback().hasToastAction, isTrue);
      expect(_store().recentSearches, isEmpty);

      _feedback().tapToastAction();
      await tester.pump();
      await tester.pump();
      expect(find.byKey(_recent(1)), findsOneWidget);
      expect(_store().recentSearches, ['hackathon', 'satranç']);
    });

    testWidgets('sekmeler: Etkinlikler → önerilen kulüpler gizlenir; '
        'etkinlik araması "sonuç yok" (T-23\'e kadar)', (tester) async {
      await _pumpRoute(tester);
      expect(find.byType(ClubCard), findsWidgets);
      await _tapKey(tester, _tab(SearchScope.events));
      expect(_stateOf(tester).scope, SearchScope.events);
      expect(find.byType(ClubCard), findsNothing);

      await _search(tester, 'satranç');
      expect(find.byKey(_clubResult(kChess.id)), findsNothing);
      expect(
        find.text(tester.l10n.searchNoResults('satranç')),
        findsOneWidget,
      );

      await _tapKey(tester, _tab(SearchScope.clubs));
      expect(find.byKey(_clubResult(kChess.id)), findsOneWidget);
    });

    testWidgets('sonuç yok: illüstrasyon 100, "\'{q}\' için sonuç yok", '
        'ilk dört popüler arama; çip → terim alana yazılır', (tester) async {
      await _pumpRoute(tester);
      await _search(tester, 'bulunmayan');
      expect(
        find.text(tester.l10n.searchNoResults('bulunmayan')),
        findsOneWidget,
      );
      final illustration = tester.widget<GuIllustration>(
        find.byType(GuIllustration),
      );
      expect(illustration.illustration, GuIllustrations.emptyClubs);
      expect(illustration.size, 100);
      for (var index = 0; index < 4; index++) {
        final chip = tester.widget<GuChip>(find.byKey(_suggest(index)));
        expect(chip.label, StaticTables.popularSearches[index]);
        expect(chip.icon, isNull);
      }
      expect(find.byKey(_suggest(4)), findsNothing);

      await _tapKey(tester, _suggest(2));
      expect(_fieldValue(tester), StaticTables.popularSearches[2]);
      await tester.pump(Limits.searchDebounce);
      expect(find.byKey(_clubResult(kTheatre.id)), findsOneWidget);
    });

    testWidgets('önerilen kulüp kartı → CLB-03', (tester) async {
      final router = await _pumpRoute(tester);
      await _tapKey(tester, _card(kChess.id));
      await tester.pumpAndSettle();
      expect(_location(router), '$_clubsPath/${kChess.id}');
    });

    testWidgets('"Katıl": onaysız kulüp → joinInstant + TST-34; "Kulübe '
        'git" → CLB-03', (tester) async {
      final router = await _pumpRoute(tester);
      await _tapKey(tester, _join(kPhoto.id));
      await tester.pump();
      expect(_memberships().applied.single.clubId, kPhoto.id);
      expect(_feedback().toasts, [ToastId.tst34]);
      expect(_location(router), _searchPath);

      _feedback().tapToastAction();
      await tester.pumpAndSettle();
      expect(_location(router), '$_clubsPath/${kPhoto.id}');
    });

    // SHT-05'in gövdesini rota verir (`applicationSheetBuilder`); gerçek
    // rota ile açılış `test/flows/club_list_flow_test.dart`'tadır.
    testWidgets('"Katıl": onay gerekli → (gövde verilmediyse) kulüp sayfası; '
        'başvurular kapalı → TST-X1', (tester) async {
      // Satranç kulübü olmadan önerilenler: Fotoğraf, Yazılım, Tiyatro.
      final router = await _pumpRoute(
        tester,
        seed: () => _clubs().clubs.remove(kChess.id),
      );
      await _tapKey(tester, _join(kTheatre.id));
      expect(_feedback().toasts, [ToastId.tstX1]);
      expect(_location(router), _searchPath);

      await _tapKey(tester, _join(kSoftware.id));
      await tester.pumpAndSettle();
      expect(_memberships().callsTo('joinInstant'), isEmpty);
      expect(_location(router), '$_clubsPath/${kSoftware.id}');
    });

    testWidgets('reddedilen kullanıcı: kartta durum düğmesi → CLB-05', (
      tester,
    ) async {
      final rejected = FakeSessionStates.withMembership(
        kPhoto.id,
        status: MembershipStatus.rejected,
      ).copyWith(user: kUser);
      final router = await _pumpRoute(tester, session: rejected);
      await _tapKey(tester, GuKey.action('CLB-02.status.${kPhoto.id}'));
      await tester.pumpAndSettle();
      expect(_location(router), '$_clubsPath/${kPhoto.id}/application');
    });
  });

  group('CLB-02 · Arama · durumlar', () {
    testWidgets('yükleniyor: varsayılan görünümde önerilenlerin yerinde kart '
        'iskeleti; sorgu varken satır iskeleti', (tester) async {
      await _pump(
        tester,
        state: kDefaultState.copyWith(
          isFetching: true,
          clubPool: const [],
          suggested: const [],
        ),
      );
      expect(find.text(tester.l10n.searchSuggested), findsOneWidget);
      var skeleton = tester.widget<GuSkeletonList>(find.byType(GuSkeletonList));
      expect(skeleton.variant, GuSkeletonVariant.card);
      expect(skeleton.count, 3);
      expect(find.byKey(_recent(0)), findsOneWidget);

      await _pump(
        tester,
        state: kDefaultState.copyWith(query: 'sat', isSearching: true),
      );
      skeleton = tester.widget<GuSkeletonList>(find.byType(GuSkeletonList));
      expect(skeleton.variant, GuSkeletonVariant.tile);
      expect(skeleton.count, 3);
      expect(find.byKey(_recent(0)), findsNothing);
    });

    testWidgets('hata: önerilenlerin yerinde satır içi hata, sorgu varken '
        'tam hata; "Yeniden dene" havuzu yeniden okur', (tester) async {
      await _pump(
        tester,
        state: kDefaultState.copyWith(
          isError: true,
          clubPool: const [],
          suggested: const [],
        ),
      );
      var error = tester.widget<GuErrorState>(find.byType(GuErrorState));
      expect(error.inline, isTrue);
      expect(error.title, tester.l10n.sysErrorTitle);
      expect(find.byKey(_popular(0)), findsOneWidget);

      await _pump(
        tester,
        state: kDefaultState.copyWith(
          query: 'sat',
          isError: true,
          clubPool: const [],
          suggested: const [],
        ),
      );
      error = tester.widget<GuErrorState>(find.byType(GuErrorState));
      expect(error.inline, isFalse);
      expect(error.retryLabel, tester.l10n.commonRetry);

      seedSearch();
      await _tapKey(tester, _retry);
      await tester.pump();
      await tester.pump(Limits.searchDebounce);
      expect(_clubs().callsTo('fetchActiveClubs'), hasLength(1));
      expect(_stateOf(tester).isError, isFalse);
      expect(_stateOf(tester).clubPool, kPool);
      expect(find.byType(GuErrorState), findsNothing);
      expect(find.byKey(_clubResult(kChess.id)), findsOneWidget);
    });

    testWidgets('öneri yoksa (her kulübün üyesi) bölüm çizilmez', (
      tester,
    ) async {
      await _pump(tester, state: kDefaultState.copyWith(suggested: const []));
      expect(find.text(tester.l10n.searchSuggested), findsNothing);
      expect(find.byType(GuSkeletonList), findsNothing);
    });
  });

  group('CLB-02 · Arama · cihaz matrisi', () {
    Widget view(BuildContext _) => _view;

    testWidgets('varsayılan', (tester) async {
      await DeviceMatrix.run(
        tester,
        view,
        overrides: _overrides(),
        safeAreas: true,
        keyboard: true,
      );
    });

    testWidgets('sonuçlar, sonuç yok, yükleniyor, hata', (tester) async {
      for (final state in [
        kDefaultState.copyWith(
          query: 'kulübü',
          clubResults: kDefaultState.clubPool,
        ),
        kDefaultState.copyWith(query: 'çok uzun ve eşleşmeyen bir arama'),
        kDefaultState.copyWith(query: 'sat', isSearching: true),
        kDefaultState.copyWith(query: 'sat', isError: true),
        kDefaultState.copyWith(isFetching: true, suggested: const []),
        kDefaultState.copyWith(isError: true, suggested: const []),
      ]) {
        await DeviceMatrix.run(
          tester,
          view,
          overrides: _overrides(state: state),
        );
      }
    });
  });

  group('CLB-02 · Arama · golden', () {
    testWidgets('varsayılan açık + koyu', (tester) async {
      // Otomatik odak ilk kareden sonra gelir: alanın odak stili (marka
      // kenarlığı, referans görüntüdeki gibi) için odak karesi ayrıca
      // pompalanır (`goldenForThemes` tek kare pompalar).
      for (final theme in kGoldenThemes) {
        await tester.pumpApp(_view, theme: theme, overrides: _overrides());
        await tester.pump();
        await tester.pump(GuMotion.base);
        await expectLater(
          find.byKey(kPumpAppBoundaryKey),
          matchesGoldenFile(
            goldenUri(goldenPath('CLB-02', theme, const Locale('tr'))),
          ),
        );
      }
    });
  });
}
