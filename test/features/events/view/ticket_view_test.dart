// EVT-03 · Bilet — içerik (kulüp, başlık, rozet, tarih / mekân, QR, kod,
// sahip), durumlar (geçerli / okutuldu / iptal, yükleniyor, hata), aksiyon
// envanteri (`EVT-03.demoScan` muaf — K-02), aksiyon sonuçları (geri /
// "Etkinliğe git" → EVT-02, takvim → SHT-14, "Vazgeç" → DLG-14 → TST-42 +
// geri), canlı okutma → TST-15, bilet yok → EVT-02, etkinlik yok → SYS-04,
// cihaz matrisi, açık + koyu golden.
// Referans: design/reference-shots/screens/EVT-03__*.webp,
// design/prototype/app/screens-events.js:74–87.
//
// İki kip (FED-02 testleriyle aynı düzen): durum kipi (`pumpApp`, ViewModel
// durumu ezilir) ve akış kipi (gerçek ViewModel + sahte depolar + yer
// tutucu rotalar).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/events/provider/ticket_state.dart';
import 'package:gu_kulupler/features/events/provider/ticket_view_model.dart';
import 'package:gu_kulupler/features/events/view/ticket_view.dart';
import 'package:gu_kulupler/features/events/view/widget/add_to_calendar_sheet.dart';
import 'package:gu_kulupler/features/events/view/widget/ticket_card.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/service/share_service.dart';
import 'package:gu_kulupler/product/widget/event/qr_code_view.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fakes/fake_event_repository.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_rsvp_repository.dart';
import '../../../fakes/fake_share_service.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/fake_app_clock.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';
import '../ticket_test_support.dart';

final Key _back = GuKey.action('EVT-03.back');
final Key _calendar = GuKey.action('EVT-03.addToCalendar');
final Key _openEvent = GuKey.action('EVT-03.openEvent');
final Key _leave = GuKey.action('EVT-03.leave');
final Key _retry = GuKey.action('EVT-03.retry');

const String _eventPath = '/events/$kTicketEventId';
const String _ticketPath = '$_eventPath/ticket';

final TicketViewModelProvider _provider = ticketViewModelProvider(
  kTicketEventId,
);

FakeFeedbackService _feedback() =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;

FakeRsvpRepository _rsvps() => GetIt.I<RsvpRepository>() as FakeRsvpRepository;

/// Durum kipi: oturum + saat + ViewModel durumu ezilir.
List<Override> _overrides({TicketViewState? state}) => [
  sessionViewModelProvider.overrideWithBuild(
    (ref, notifier) => ticketSession(),
  ),
  appClockProvider.overrideWithValue(FakeAppClock(kTicketNowUtc)),
  _provider.overrideWithBuild((ref, notifier) => state ?? loadedTicketState()),
];

Future<void> _pump(
  WidgetTester tester, {
  TicketViewState? state,
  Locale locale = const Locale('tr'),
  Size size = const Size(390, 844),
}) async {
  await tester.pumpApp(
    const TicketView(eventId: kTicketEventId),
    locale: locale,
    size: size,
    overrides: _overrides(state: state),
  );
  await tester.pump();
}

/// Akış kipi: gerçek ViewModel + yer tutucu EVT-02 / SYS-04.
Future<GoRouter> _pumpRoute(
  WidgetTester tester, {
  bool withRsvp = true,
  void Function()? before,
}) async {
  GoRouter? created;
  await tester.pumpAppRouter(
    size: const Size(390, 1000),
    routerOf: (_) => created ??= GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(path: '/start', builder: (_, _) => const _Stub('/start')),
        GoRoute(
          path: '/not-found',
          builder: (_, _) => const _Stub('/not-found'),
        ),
        GoRoute(
          path: '/events/:eventId',
          builder: (_, state) => _Stub(state.uri.toString()),
          routes: [
            GoRoute(
              path: 'ticket',
              builder: (_, state) =>
                  TicketView(eventId: state.pathParameters['eventId']!),
            ),
          ],
        ),
      ],
    ),
    overrides: [
      sessionViewModelProvider.overrideWithBuild(
        (ref, notifier) => ticketSession(),
      ),
    ],
  );
  final router = created!;
  addTearDown(router.dispose);
  seedTicket(withRsvp: withRsvp);
  before?.call();
  router.go(_ticketPath);
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
  group('EVT-03 · Bilet · içerik', () {
    for (final locale in const [Locale('tr'), Locale('en')]) {
      testWidgets('geçerli bilet (${locale.languageCode}): kulüp (büyük harf), '
          'başlık, rozet, tarih, mekân, QR, kod, sahip; "Etkinliğe git" + '
          '"Vazgeç"', (tester) async {
        await _pump(tester, locale: locale);
        final l10n = tester.l10nFor(locale);

        expect(find.text(l10n.ticketTitle), findsOneWidget);
        expect(find.text(kTicketEvent.title), findsOneWidget);
        expect(
          find.text(
            locale.languageCode == 'tr'
                ? 'YAZILIM VE YAPAY ZEKÂ TOPLULUĞU'
                : kTicketClub.name.toUpperCase(),
          ),
          findsOneWidget,
        );
        expect(find.text(l10n.ticketStatusValid), findsOneWidget);
        expect(
          find.text(
            locale.languageCode == 'tr'
                ? '9 Eki Cum, 18:00'
                : l10n.dateTimeAt('Fri 9 Oct', '18:00'),
          ),
          findsOneWidget,
        );
        expect(find.text(l10n.placePl04), findsOneWidget);
        expect(find.text('GU-CWV4-JMW9'), findsOneWidget);
        expect(find.text('Mehmet Kaya'), findsOneWidget);
        expect(find.byType(QrCodeView), findsOneWidget);
        expect(
          tester.widget<QrCodeView>(find.byType(QrCodeView)).data,
          'gu:ticket:v1:e01:GU-CWV4-JMW9',
        );
        expect(
          tester.widget<QrCodeView>(find.byType(QrCodeView)).semanticLabel,
          l10n.a11yTicketQr(l10n.ticketStatusValid),
        );
        expect(find.text(l10n.ticketOpenEvent), findsOneWidget);
        expect(find.text(l10n.eventCtaLeave), findsOneWidget);
        // Demo öğeleri uygulanmaz (K-02); parlaklık rozeti yok.
        expect(find.text(l10n.ticketDemoScan), findsNothing);
        expect(find.text(l10n.ticketBrightness), findsNothing);
      });
    }

    testWidgets('okutuldu: bulanık QR, "Okutuldu" rozeti + okutulma anı; '
        '"Vazgeç" yok', (tester) async {
      await _pump(tester, state: loadedTicketState(rsvp: kScannedRsvp));
      final l10n = tester.l10nFor(const Locale('tr'));
      expect(
        tester.widget<QrCodeView>(find.byType(QrCodeView)).state,
        TicketState.used,
      );
      expect(find.text(l10n.ticketStatusUsed), findsOneWidget);
      expect(
        find.text(l10n.ticketScannedAt('9 Eki Cum, 18:05')),
        findsOneWidget,
      );
      expect(find.byKey(_leave), findsNothing);
      expect(find.byKey(_openEvent), findsOneWidget);
    });

    testWidgets('iptal: etkinlik iptal → "İptal" rozeti + çizgili QR; '
        '"Vazgeç" yok', (tester) async {
      await _pump(
        tester,
        state: loadedTicketState(
          event: kTicketEvent.copyWith(status: EventStatus.cancelled),
        ),
      );
      final l10n = tester.l10nFor(const Locale('tr'));
      expect(
        tester.widget<TicketCard>(find.byType(TicketCard)).state,
        TicketState.voided,
      );
      expect(find.text(l10n.ticketStatusVoid), findsOneWidget);
      expect(find.byKey(_leave), findsNothing);
    });

    testWidgets('bitmiş etkinlik: "Vazgeç" gösterilmez (W-81 b)', (
      tester,
    ) async {
      await _pump(
        tester,
        state: loadedTicketState(
          event: kTicketEvent.copyWith(
            startsAt: kTicketNowUtc.subtract(const Duration(hours: 3)),
            endsAt: kTicketNowUtc.subtract(const Duration(hours: 1)),
          ),
        ),
      );
      expect(find.byKey(_leave), findsNothing);
    });
  });

  group('EVT-03 · Bilet · durumlar', () {
    testWidgets('yükleniyor: kart iskeleti; takvim simgesi kapalı', (
      tester,
    ) async {
      await _pump(tester, state: const TicketViewState(isFetching: true));
      expect(find.byType(GuSkeletonList), findsOneWidget);
      expect(find.byType(TicketCard), findsNothing);
      expect(
        tester.widget<GuIconButton>(find.byKey(_calendar)).disabled,
        isTrue,
      );
    });

    testWidgets('hata: "Bir şeyler ters gitti" + "Yeniden dene"', (
      tester,
    ) async {
      await _pump(tester, state: const TicketViewState(isError: true));
      final l10n = tester.l10nFor(const Locale('tr'));
      expect(find.text(l10n.sysErrorTitle), findsOneWidget);
      expect(find.byKey(_retry), findsOneWidget);
      expect(find.byType(TicketCard), findsNothing);
    });
  });

  group('EVT-03 · Bilet · aksiyon envanteri', () {
    testWidgets('üye bakışı: envanterdeki anahtarlar birebir (demoScan '
        'muaf)', (tester) async {
      await _pump(tester, size: const Size(390, 1000));
      expectActionInventory(tester, 'EVT-03', role: 'member');
    });
  });

  group('EVT-03 · Bilet · aksiyonlar', () {
    testWidgets('geri ve "Etkinliğe git" → EVT-02', (tester) async {
      var router = await _pumpRoute(tester);
      expect(find.byType(TicketView), findsOneWidget);
      await tester.tap(find.byKey(_back));
      await tester.pumpAndSettle();
      expect(_location(router), _eventPath);

      router = await _pumpRoute(tester);
      await tester.tap(find.byKey(_openEvent));
      await tester.pumpAndSettle();
      expect(_location(router), _eventPath);
    });

    testWidgets('takvim simgesi → SHT-14; "Bağlantıyı kopyala" → TST-35', (
      tester,
    ) async {
      await _pumpRoute(tester);
      _feedback().nextSheetResult = CalendarChoice.copyLink;
      await tester.tap(find.byKey(_calendar));
      await tester.pumpAndSettle();
      expect(_feedback().sheets, [SheetId.sht14]);
      expect(
        (GetIt.I<ShareService>() as FakeShareService).copied,
        ['https://kulupler.gumushane.edu.tr/events/e01'],
      );
      expect(_feedback().toasts, [ToastId.tst35]);
    });

    testWidgets('"Vazgeç" → DLG-14 onayı → TST-42 ve EVT-02', (tester) async {
      final router = await _pumpRoute(tester);
      _feedback().nextDialogResult = true;
      await tester.tap(find.byKey(_leave));
      await tester.pumpAndSettle();
      expect(_feedback().dialogs, [DialogId.dlg14]);
      expect(_rsvps().rsvps[kTicketRsvp.id]!.status, RsvpStatus.cancelled);
      expect(_feedback().toasts, [ToastId.tst42]);
      expect(_location(router), _eventPath);
    });

    testWidgets('canlı: yönetici okutunca ekran değişir + TST-15', (
      tester,
    ) async {
      await _pumpRoute(tester);
      expect(find.text('Geçerli'), findsOneWidget);
      _rsvps()
          .watchMineController(kTicketEventId, kTicketUid)
          .add(FirebaseSuccess(kScannedRsvp));
      await tester.pumpAndSettle();
      expect(find.text('Okutuldu'), findsOneWidget);
      expect(find.byKey(_leave), findsNothing);
      expect(_feedback().toasts, [ToastId.tst15]);
    });

    testWidgets('bilet yok → EVT-02; etkinlik yok → SYS-04', (tester) async {
      var router = await _pumpRoute(tester, withRsvp: false);
      expect(_location(router), _eventPath);

      router = await _pumpRoute(
        tester,
        before: () => (GetIt.I<EventRepository>() as FakeEventRepository).events
            .remove(kTicketEventId),
      );
      expect(_location(router), '/not-found');
    });
  });

  group('EVT-03 · Bilet · cihaz matrisi', () {
    Widget view(BuildContext context) =>
        const TicketView(eventId: kTicketEventId);

    testWidgets('geçerli (güvenli alan); okutuldu, iptal, yükleniyor, hata', (
      tester,
    ) async {
      await DeviceMatrix.run(
        tester,
        view,
        overrides: _overrides(),
        safeAreas: true,
      );
      for (final state in [
        loadedTicketState(rsvp: kScannedRsvp),
        loadedTicketState(
          event: kTicketEvent.copyWith(status: EventStatus.cancelled),
        ),
        const TicketViewState(isFetching: true),
        const TicketViewState(isError: true),
      ]) {
        await DeviceMatrix.run(
          tester,
          view,
          overrides: _overrides(state: state),
        );
      }
    });
  });

  group('EVT-03 · Bilet · golden', () {
    testWidgets('varsayılan (geçerli bilet) açık + koyu', (tester) async {
      await goldenForThemes(
        tester,
        'EVT-03',
        const TicketView(eventId: kTicketEventId),
        overrides: _overrides(),
      );
    });
  });
}
