// EVT-01 · Etkinlikler — içerik (gün grupları, çipler, kart durumu), durumlar
// (yükleniyor, hata, boş, süzgeç sonucu boş, takvim kipi), aksiyon envanteri
// (kabukla 56 anahtar), aksiyon sonuçları (CLB-02 / EVT-04 / EVT-02 / EVT-03
// / CLB-03 gezinmesi, SHT-11, SHT-12 akışı, TST-X2, çip, kip, temizle, yeniden
// dene, başa kaydırma), cihaz matrisi, açık + koyu golden.
// Referans: design/reference-shots/screens/EVT-01__*.webp,
// design/reference-shots/states/EVT-01__*.webp,
// design/prototype/app/screens-events.js:17–33.
//
// İki kip (CLB-01 testleriyle aynı düzen): **durum kipi** ViewModel durumunu
// ezer; **akış kipi** gerçek ViewModel + sahte depolar + yer tutucu rotalar.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/events/provider/event_filter_state.dart';
import 'package:gu_kulupler/features/events/provider/event_list_state.dart';
import 'package:gu_kulupler/features/events/provider/event_list_view_model.dart';
import 'package:gu_kulupler/features/events/view/event_list_view.dart';
import 'package:gu_kulupler/features/events/view/widget/event_calendar_section.dart';
import 'package:gu_kulupler/features/events/view/widget/event_filter_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/widget/event/event_card.dart';
import 'package:gu_kulupler/product/widget/event/event_card_status.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fakes/fake_event_repository.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fixtures/event_model_fixtures.dart';
import '../../../helpers/a11y_guidelines.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/fake_app_clock.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';
import '../event_list_test_support.dart';

Key _key(String action) => GuKey.action('EVT-01.$action');

/// Tembel listenin 14 kartı da kurulsun diye uzun yüzey.
const Size _tall = Size(390, 6400);

FakeFeedbackService _feedback() =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;

/// Durum kipi: oturum + ViewModel durumu + saat ezilir.
List<Override> _overrides({
  SessionState session = kVisitorSession,
  EventListState? state,
}) => [
  sessionViewModelProvider.overrideWithBuild((ref, notifier) => session),
  eventListViewModelProvider.overrideWithBuild(
    (ref, notifier) => state ?? loadedListState(session),
  ),
  appClockProvider.overrideWithValue(FakeAppClock(kNowUtc)),
];

Future<void> _pump(
  WidgetTester tester, {
  SessionState session = kVisitorSession,
  EventListState? state,
  Locale locale = const Locale('tr'),
  ThemeMode theme = ThemeMode.light,
  Size size = const Size(390, 844),
  bool wrapInShell = false,
}) async {
  await tester.pumpApp(
    const EventListView(),
    locale: locale,
    theme: theme,
    size: size,
    wrapInShell: wrapInShell,
    shellTab: GuTab.events,
    overrides: _overrides(session: session, state: state),
  );
  await tester.pump();
}

/// Akış kipi: gerçek ViewModel, sahte depolar ve yer tutucu hedefler.
Future<GoRouter> _pumpRoute(
  WidgetTester tester, {
  SessionState session = kVisitorSession,
  List<RsvpModel> rsvps = const [],
  List<EventModel>? events,
}) async {
  GoRouter? created;
  await tester.pumpAppRouter(
    size: _tall,
    routerOf: (_) => created ??= GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(path: '/start', builder: (_, _) => const _Stub('/start')),
        GoRoute(
          path: '/events',
          builder: (_, _) => const EventListView(),
          routes: [
            for (final segment in ['mine', 'search'])
              GoRoute(
                path: segment,
                builder: (_, state) => _Stub(state.uri.path),
              ),
            GoRoute(
              path: ':eventId',
              builder: (_, state) => _Stub(state.uri.path),
              routes: [
                GoRoute(
                  path: 'ticket',
                  builder: (_, state) => _Stub(state.uri.path),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/clubs/:clubId',
          builder: (_, state) => _Stub(state.uri.path),
        ),
      ],
    ),
    overrides: [
      sessionViewModelProvider.overrideWithBuild((ref, notifier) => session),
    ],
  );
  final router = created!;
  addTearDown(router.dispose);
  seedEventList(rsvps: rsvps, events: events);
  router.go('/events');
  await tester.pumpAndSettle();
  return router;
}

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

class _Stub extends StatelessWidget {
  const _Stub(this.path);

  final String path;

  @override
  Widget build(BuildContext context) => Scaffold(body: Text(path));
}

Element _viewElement(WidgetTester tester) =>
    tester.element(find.byType(EventListView, skipOffstage: false));

EventListState _stateOf(WidgetTester tester) => ProviderScope.containerOf(
  _viewElement(tester),
).read(eventListViewModelProvider);

Future<void> _tapKey(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

List<String> _cardIds(WidgetTester tester) => [
  for (final card in tester.widgetList<EventCard>(find.byType(EventCard)))
    card.event.id,
];

void main() {
  group('EVT-01 · Etkinlikler · içerik', () {
    for (final locale in DeviceMatrix.locales) {
      testWidgets('ziyaretçi (${locale.languageCode}): başlık, üst düğmeler, '
          'dilim, çipler, gün grupları (çakışmasız), 14 kart', (tester) async {
        await _pump(tester, locale: locale, size: _tall);
        final l10n = tester.l10nFor(locale);
        final upper = Localizations.localeOf(_viewElement(tester));

        expect(find.text(l10n.navEvents), findsOneWidget);
        expect(
          tester.widget<GuIconButton>(find.byKey(_key('tickets'))).icon,
          GuIcons.ticket,
        );
        final segmented = tester.widget<GuSegmented>(find.byType(GuSegmented));
        expect(segmented.options.map((o) => o.label), [
          l10n.eventsViewList,
          l10n.eventsViewCalendar,
        ]);
        expect(segmented.value, EventListMode.list.name);
        expect(
          tester
              .widgetList<GuChip>(find.byType(GuChip))
              .map((chip) => chip.label),
          [
            l10n.commonAll,
            l10n.timeToday,
            l10n.eventsChipWeek,
            l10n.eventsChipMine,
            l10n.eventsChipPublic,
            l10n.commonFilter,
          ],
        );

        final headers = tester
            .widgetList<GuGroupHeader>(find.byType(GuGroupHeader))
            .map((h) => (h.title, h.trailingText))
            .toList();
        expect(headers, [
          (l10n.eventsGroupToday.upperFor(upper), '1'),
          (l10n.eventsGroupTomorrow.upperFor(upper), '1'),
          (l10n.eventsGroupWeek.upperFor(upper), '5'),
          (l10n.eventsGroupLater.upperFor(upper), '7'),
        ]);
        expect(_cardIds(tester), kVisitorCardIds);
        expect(
          tester.widget<GuListEnd>(find.byType(GuListEnd)).label,
          l10n.commonAllDone,
        );
        await expectA11yGuidelines(tester);
      });
    }

    testWidgets('kart durumu kayıttan: bilet (going), bekleme, dolu → '
        'bekleme listesine katıl, iptal düğmesiz', (tester) async {
      await _pump(
        tester,
        session: kMemberSession,
        size: _tall,
        state: loadedListState(kMemberSession, rsvps: kMyRsvps),
      );
      EventCard card(String id) => tester
          .widgetList<EventCard>(find.byType(EventCard))
          .firstWhere((card) => card.event.id == id);
      expect(card('e01').status, EventCardStatus.going);
      expect(card('e08').status, EventCardStatus.waitlist);
      expect(card('e03').status, EventCardStatus.full);
      expect(card('e21').quickAction, isNull);
      // Üye olunan kulübün üyelere özel etkinliği listede.
      expect(_cardIds(tester), contains('e02'));
    });
  });

  group('EVT-01 · Etkinlikler · durumlar', () {
    testWidgets('yükleniyor: kart iskeleti; üst bölümler yerinde', (
      tester,
    ) async {
      await _pump(tester, state: const EventListState(isFetching: true));
      expect(find.byType(GuSkeletonList), findsOneWidget);
      expect(find.byType(EventCard), findsNothing);
      expect(find.byKey(_key('chip.all')), findsOneWidget);
    });

    testWidgets('hata: "Bir şeyler ters gitti" + "Yeniden dene"', (
      tester,
    ) async {
      await _pump(tester, state: const EventListState(isError: true));
      final l10n = tester.l10nFor(const Locale('tr'));
      expect(find.text(l10n.sysErrorTitle), findsOneWidget);
      expect(find.byKey(_key('retry')), findsOneWidget);
    });

    testWidgets('boş: "Bu aralıkta etkinlik yok", süzgeçsiz CTA yok; süzgeç '
        'sonucu boşsa "Filtreleri temizle"', (tester) async {
      final l10n = tester.l10nFor(const Locale('tr'));
      await _pump(tester, state: const EventListState());
      expect(find.text(l10n.eventsEmptyTitle), findsOneWidget);
      expect(find.byKey(_key('clearFilters')), findsNothing);

      await _pump(
        tester,
        state: loadedListState(
          kVisitorSession,
          base: const EventListState(chip: EventListChip.mine),
        ),
      );
      expect(find.text(l10n.eventsEmptyTitle), findsOneWidget);
      expect(find.byKey(_key('clearFilters')), findsOneWidget);
    });

    testWidgets('takvim kipi: çipler gizli, takvim bölümü', (tester) async {
      await _pump(
        tester,
        state: loadedListState(
          kVisitorSession,
          base: const EventListState(mode: EventListMode.calendar),
        ),
      );
      expect(find.byType(EventCalendarSection), findsOneWidget);
      expect(find.byKey(_key('chip.all')), findsNothing);
      final section = tester.widget<EventCalendarSection>(
        find.byType(EventCalendarSection),
      );
      expect(section.today, DateTime(2026, 10, 8));
      expect(
        section.events,
        hasLength(loadedListState(kVisitorSession).events.length),
      );
    });

    testWidgets('etkin süzgeç rozeti', (tester) async {
      await _pump(
        tester,
        state: loadedListState(
          kVisitorSession,
          base: const EventListState(
            filter: EventFilterState(freeOnly: true, sort: EventSort.popular),
          ),
        ),
      );
      expect(tester.widget<GuChip>(find.byKey(_key('filter'))).count, 2);
    });
  });

  group('EVT-01 · Etkinlikler · aksiyon envanteri', () {
    testWidgets('ziyaretçi, kabukla: envanterdeki 56 anahtar birebir', (
      tester,
    ) async {
      await _pump(tester, size: _tall, wrapInShell: true);
      expectActionInventory(tester, 'EVT-01', includeShell: true);
    });
  });

  group('EVT-01 · Etkinlikler · aksiyonlar', () {
    testWidgets('ara → /events/search; Biletlerim → /events/mine', (
      tester,
    ) async {
      final router = await _pumpRoute(tester);
      await _tapKey(tester, _key('search'));
      expect(_location(router), '/events/search');
      router.go('/events');
      await tester.pumpAndSettle();
      await _tapKey(tester, _key('tickets'));
      expect(_location(router), '/events/mine');
    });

    testWidgets('kart → EVT-02; kulüp adı → CLB-03', (tester) async {
      final router = await _pumpRoute(tester);
      await _tapKey(tester, _key('card.e17'));
      expect(_location(router), '/events/e17');
      router.go('/events');
      await tester.pumpAndSettle();
      await _tapKey(tester, _key('club.e17'));
      expect(_location(router), '/clubs/c01');
    });

    testWidgets('hızlı eylem: bilet → EVT-03; "Katıl" → SHT-12 akışı; '
        '"Kayıtlar kapalı" → TST-X2', (tester) async {
      final closed = EventModelFixtures.byId(
        'e10',
      ).copyWith(registrationOpen: false);
      final router = await _pumpRoute(
        tester,
        session: kMemberSession,
        rsvps: kMyRsvps,
        events: [
          for (final event in kAllEvents)
            if (event.id == closed.id) closed else event,
        ],
      );
      await _tapKey(tester, _key('join.e17'));
      expect(_feedback().sheets, [SheetId.sht12]);

      await _tapKey(tester, _key('join.e10'));
      expect(_feedback().toasts, [ToastId.tstX2]);

      await _tapKey(tester, _key('join.e01'));
      expect(_location(router), '/events/e01/ticket');
    });

    testWidgets('çip "Bugün" yalnız bugünü gösterir; "Tümü" geri getirir', (
      tester,
    ) async {
      await _pumpRoute(tester);
      await _tapKey(tester, _key('chip.today'));
      expect(_cardIds(tester), ['e17']);
      await _tapKey(tester, _key('chip.all'));
      expect(_cardIds(tester), kVisitorCardIds);
    });

    testWidgets('dilim liste ↔ takvim', (tester) async {
      await _pumpRoute(tester);
      await _tapKey(tester, _key('view.calendar'));
      expect(_stateOf(tester).mode, EventListMode.calendar);
      expect(find.byType(EventCalendarSection), findsOneWidget);
      await _tapKey(tester, _key('view.list'));
      expect(_stateOf(tester).mode, EventListMode.list);
    });

    testWidgets('"Filtre" → SHT-11 (geçerli süzgeç, kulüpler, sayı); "Uygula" '
        'uygular; boş sonuçta "Filtreleri temizle" sıfırlar', (tester) async {
      await _pumpRoute(tester);
      const result = EventFilterState(types: {EventType.competition});
      _feedback().nextSheetResult = result;
      await _tapKey(tester, _key('filter'));
      expect(_feedback().sheets, [SheetId.sht11]);
      final sheet =
          _feedback().lastSheetBuilder!(_viewElement(tester))
              as EventFilterSheet;
      expect(sheet.initial, EventFilterState.none);
      expect(sheet.clubs.any((club) => club.isSuspended), isFalse);
      expect(sheet.countFor(EventFilterState.none), kVisitorCardIds.length);
      expect(_stateOf(tester).filter, result);
      expect(_cardIds(tester), ['e08', 'e09']);

      await _tapKey(tester, _key('chip.today'));
      expect(_cardIds(tester), isEmpty);
      await _tapKey(tester, _key('clearFilters'));
      expect(_stateOf(tester).filter, EventFilterState.none);
      expect(_cardIds(tester), kVisitorCardIds);
    });

    testWidgets('hata → "Yeniden dene" yükler', (tester) async {
      GoRouter? router;
      await tester.pumpAppRouter(
        size: _tall,
        routerOf: (_) => router ??= GoRouter(
          initialLocation: '/start',
          routes: [
            GoRoute(path: '/start', builder: (_, _) => const _Stub('/start')),
            GoRoute(path: '/events', builder: (_, _) => const EventListView()),
          ],
        ),
        overrides: [
          sessionViewModelProvider.overrideWithBuild(
            (ref, notifier) => kVisitorSession,
          ),
        ],
      );
      addTearDown(router!.dispose);
      seedEventList();
      (GetIt.I<EventRepository>() as FakeEventRepository).failNext(
        FirestoreError.unavailable,
      );
      router!.go('/events');
      await tester.pumpAndSettle();
      expect(find.byKey(_key('retry')), findsOneWidget);
      await _tapKey(tester, _key('retry'));
      expect(_cardIds(tester), kVisitorCardIds);
    });

    testWidgets('etkin sekmeye yeniden dokunma başa kaydırır', (tester) async {
      await _pumpRoute(tester);
      final scrollable = find.descendant(
        of: find.byType(EventListView),
        matching: find.byType(Scrollable),
      );
      final position =
          tester.stateList<ScrollableState>(scrollable).last.position
            ..jumpTo(600);
      await tester.pump();
      ProviderScope.containerOf(
        _viewElement(tester),
      ).read(scrollTopRequestProvider(GuTab.events).notifier).request();
      await tester.pumpAndSettle();
      expect(position.pixels, 0);
    });
  });

  group('EVT-01 · Etkinlikler · cihaz matrisi', () {
    Widget view(BuildContext context) => const EventListView();

    testWidgets('ziyaretçi, liste (kabukla)', (tester) async {
      await DeviceMatrix.run(
        tester,
        view,
        overrides: _overrides(),
        wrapInShell: true,
        shellTab: GuTab.events,
        safeAreas: true,
      );
    });

    testWidgets('üye, kayıtlar + etkin süzgeç; yükleniyor, hata, boş', (
      tester,
    ) async {
      for (final state in [
        loadedListState(
          kMemberSession,
          rsvps: kMyRsvps,
          base: const EventListState(
            filter: EventFilterState(sort: EventSort.popular),
          ),
        ),
        const EventListState(isFetching: true),
        const EventListState(isError: true),
        const EventListState(chip: EventListChip.mine),
      ]) {
        await DeviceMatrix.run(
          tester,
          view,
          overrides: _overrides(session: kMemberSession, state: state),
        );
      }
    });
  });

  group('EVT-01 · Etkinlikler · golden', () {
    testWidgets('varsayılan (ziyaretçi, kabukla) açık + koyu', (tester) async {
      for (final theme in kGoldenThemes) {
        await _pump(tester, theme: theme, wrapInShell: true);
        await tester.pump(GuMotion.base);
        await expectLater(
          find.byKey(kPumpAppBoundaryKey),
          matchesGoldenFile(
            goldenUri(goldenPath('EVT-01', theme, const Locale('tr'))),
          ),
        );
      }
    });
  });
}
