// EVT-04 · Etkinliklerim — satır içeriği (tarih rozeti, başlık, "kulüp ·
// saat", durum rozeti, bilet / vazgeç), sekmeler, aksiyon envanteri, durumlar
// (yükleniyor, hata, boş — sekme başına), aksiyon sonuçları (EVT-02 / EVT-03
// / EVT-01 gezinmesi, DLG-14 → TST-42), cihaz matrisi, açık + koyu golden.
// Referans: design/reference-shots/screens/EVT-04__*.webp, states/EVT-04__*,
// design/prototype/app/screens-events.js:90–95.
//
// * Durum kipi: ViewModel durumu ezilir (okuma yok), saat `kMyNowUtc`.
// * Akış kipi: gerçek ViewModel + sahte depolar + yer tutucu rotalar.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/events/provider/my_events_state.dart';
import 'package:gu_kulupler/features/events/provider/my_events_view_model.dart';
import 'package:gu_kulupler/features/events/view/my_events_view.dart';
import 'package:gu_kulupler/features/events/view/widget/my_event_tile.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_session_states.dart';
import '../../../fixtures/club_model_fixtures.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/fake_app_clock.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';
import '../my_events_test_support.dart';

Key _k(String action) => GuKey.action('EVT-04.$action');

/// Durum kipi: oturum + ViewModel durumu + saat ezilir.
List<Override> _overrides([MyEventsState? state]) => [
  sessionViewModelProvider.overrideWithBuild(
    (ref, notifier) => FakeSessionStates.active,
  ),
  myEventsViewModelProvider.overrideWithBuild(
    (ref, notifier) => state ?? loadedMyEvents(),
  ),
  appClockProvider.overrideWithValue(FakeAppClock(kMyNowUtc)),
];

Future<void> _pump(
  WidgetTester tester, {
  MyEventsState? state,
  Locale locale = const Locale('tr'),
}) async {
  await tester.pumpApp(
    const MyEventsView(),
    locale: locale,
    overrides: _overrides(state),
  );
  await tester.pump();
}

/// Akış kipi: gerçek ViewModel ve yer tutucu rotalar.
Future<GoRouter> _pumpRoute(WidgetTester tester) async {
  GoRouter? created;
  await tester.pumpAppRouter(
    routerOf: (_) => created ??= GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(path: '/start', builder: (_, _) => const _Stub('/start')),
        GoRoute(
          path: '/events',
          builder: (_, _) => const _Stub('/events'),
          routes: [
            GoRoute(path: 'mine', builder: (_, _) => const MyEventsView()),
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
      ],
    ),
    overrides: [
      sessionViewModelProvider.overrideWithBuild(
        (ref, notifier) => FakeSessionStates.active,
      ),
    ],
  );
  final router = created!;
  addTearDown(router.dispose);
  seedMyEvents();
  router.go('/events/mine');
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

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_GB');
  });

  group('EVT-04 · Etkinliklerim · içerik', () {
    testWidgets('başlık, sekmeler, yaklaşan satırı: tarih rozeti, kulüp · '
        'saat, "Katılıyorsun", bilet + vazgeç', (tester) async {
      await _pump(tester);
      final l10n = tester.l10n;
      expect(find.text(l10n.myeventsTitle), findsOneWidget);
      for (final label in [
        l10n.eventUpcoming,
        l10n.eventPast,
        l10n.statusWaitlist,
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.byType(MyEventTile), findsOneWidget);
      expect(find.text(kMyE01.title), findsOneWidget);
      final club = ClubModelFixtures.byId(kMyE01.clubId).name;
      expect(find.text('$club · 18:00'), findsOneWidget);
      final badge = tester.widget<GuDateBadge>(find.byType(GuDateBadge));
      expect((badge.day, badge.monthShort), (9, 'EKİ'));
      final status = tester.widget<GuStatusBadge>(find.byType(GuStatusBadge));
      expect(status.kind, GuStatusBadgeKind.going);
      expect(status.label, l10n.statusGoing);
      final ticket = tester.widget<GuIconButton>(find.byKey(_k('ticket.e01')));
      expect(ticket.icon, GuIcons.ticket);
      expect(ticket.tone, GuIconButtonTone.brand);
      final leave = tester.widget<GuIconButton>(find.byKey(_k('leave.e01')));
      expect(leave.icon, GuIcons.x);
      expect(leave.semanticLabel, l10n.eventCtaLeave);
    });

    testWidgets('bekleme sekmesi: yalnızca "Ayrıl"; geçmiş: "Katıldın", '
        'düğme yok', (tester) async {
      await _pump(tester, state: loadedMyEvents(tab: MyEventsTab.waitlist));
      final l10n = tester.l10n;
      expect(find.text(kMyE08.title), findsOneWidget);
      expect(find.byKey(_k('ticket.e08')), findsNothing);
      expect(
        tester.widget<GuIconButton>(find.byKey(_k('leave.e08'))).semanticLabel,
        l10n.eventCtaLeaveWaitlist,
      );
      await _pump(tester, state: loadedMyEvents(tab: MyEventsTab.past));
      expect(find.text(kMyE18.title), findsOneWidget);
      expect(
        tester.widget<GuStatusBadge>(find.byType(GuStatusBadge)).kind,
        GuStatusBadgeKind.attended,
      );
      expect(find.byType(GuIconButton), findsOneWidget); // yalnızca geri
    });
  });

  group('EVT-04 · Etkinliklerim · durumlar', () {
    testWidgets('yükleniyor: 4 satır iskeleti', (tester) async {
      await _pump(tester, state: const MyEventsState(isFetching: true));
      expect(find.byType(GuSkeletonList), findsOneWidget);
      expect(find.byType(MyEventTile), findsNothing);
    });

    testWidgets('hata: "Bir şeyler ters gitti" + "Yeniden dene"', (
      tester,
    ) async {
      await _pump(tester, state: const MyEventsState(isError: true));
      expect(find.text(tester.l10n.sysErrorTitle), findsOneWidget);
      expect(find.byKey(_k('retry')), findsOneWidget);
    });

    testWidgets('boş: sekme başına başlık + "Etkinlikleri keşfet"', (
      tester,
    ) async {
      final l10n = tester.l10nFor(const Locale('tr'));
      for (final (tab, title) in [
        (MyEventsTab.upcoming, l10n.myeventsEmptyUpcoming),
        (MyEventsTab.past, l10n.myeventsEmptyPast),
        (MyEventsTab.waitlist, l10n.myeventsEmptyWaitlist),
      ]) {
        await _pump(tester, state: MyEventsState(tab: tab));
        expect(find.text(title), findsOneWidget);
        expect(find.byKey(_k('discover')), findsOneWidget);
      }
    });
  });

  group('EVT-04 · Etkinliklerim · aksiyon envanteri', () {
    testWidgets('envanterdeki anahtarlar birebir', (tester) async {
      await _pump(tester);
      expectActionInventory(tester, 'EVT-04');
    });
  });

  group('EVT-04 · Etkinliklerim · aksiyonlar', () {
    testWidgets('satır → EVT-02; bilet → EVT-03', (tester) async {
      var router = await _pumpRoute(tester);
      expect(find.byType(MyEventTile), findsOneWidget);
      await tester.tap(find.byKey(_k('event.e01')));
      await tester.pumpAndSettle();
      expect(_location(router), '/events/e01');

      router = await _pumpRoute(tester);
      await tester.tap(find.byKey(_k('ticket.e01')));
      await tester.pumpAndSettle();
      expect(_location(router), '/events/e01/ticket');
    });

    testWidgets('sekme → bekleme listesi; geri → EVT-01', (tester) async {
      final router = await _pumpRoute(tester);
      await tester.tap(find.byKey(_k('tab.waitlist')));
      await tester.pumpAndSettle();
      expect(find.text(kMyE08.title), findsOneWidget);
      await tester.tap(find.byKey(_k('back')));
      await tester.pumpAndSettle();
      expect(_location(router), '/events');
    });

    testWidgets('vazgeç → DLG-14 → satır düşer + TST-42; boşta "Etkinlikleri '
        'keşfet" → EVT-01', (tester) async {
      final router = await _pumpRoute(tester);
      final feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
      feedback.dialogResults[DialogId.dlg14] = true;
      await tester.tap(find.byKey(_k('leave.e01')));
      await tester.pumpAndSettle();
      expect(feedback.dialogs, [DialogId.dlg14]);
      expect(feedback.toasts, [ToastId.tst42]);
      expect(find.byType(MyEventTile), findsNothing);
      await tester.tap(find.byKey(_k('discover')));
      await tester.pumpAndSettle();
      expect(_location(router), '/events');
    });
  });

  group('EVT-04 · Etkinliklerim · cihaz matrisi', () {
    Widget view(BuildContext context) => const MyEventsView();

    testWidgets('dolu (güvenli alan); bekleme, geçmiş, boş, hata', (
      tester,
    ) async {
      await DeviceMatrix.run(
        tester,
        view,
        overrides: _overrides(),
        safeAreas: true,
      );
      for (final state in [
        loadedMyEvents(tab: MyEventsTab.waitlist),
        loadedMyEvents(tab: MyEventsTab.past),
        const MyEventsState(),
        const MyEventsState(isError: true),
      ]) {
        await DeviceMatrix.run(tester, view, overrides: _overrides(state));
      }
    });
  });

  group('EVT-04 · Etkinliklerim · golden', () {
    testWidgets('varsayılan (açık + koyu)', (tester) async {
      await goldenForThemes(
        tester,
        'EVT-04',
        const MyEventsView(),
        overrides: _overrides(),
      );
    });
  });
}
