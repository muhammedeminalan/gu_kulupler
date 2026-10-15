// MGT-07 · QR tarayıcı — içerik (tasarım yakalaması: u_elif → e17 "Veri
// Bilimi Söyleşisi", Katıldı 5/52; kamera yerine sahte önizleme), durum
// çubuğu açık ikon (D-20), izin reddi ekranı ("Kamera izni gerekli" · "Kod
// gir" · "Ayarlara git"), elle kod alanı, aksiyon envanteri (demo tarama
// düğmeleri yok — K-02, K-04), temel aksiyon sonuçları (QR okuması →
// tarama durur → SHT-24 → sürer; fener; kamera çevir; izin yeniden dene →
// kamera; kapat → MGT-06), cihaz matrisi, açık + koyu golden. Referans:
// design/reference-shots/screens/MGT-07__*.webp,
// design/prototype/app/screens-manage.js:142–157.
//
// İki kip (MGT-04 testleriyle aynı düzen): durum kipi (`pumpApp`, ViewModel
// durumu ezilir) · akış kipi (gerçek ViewModel, sahte depolar, yer tutucu
// rotalar). Tarama çizgisi sonsuz animasyondur: `pumpAndSettle` yerine
// sayılı kare ilerletilir.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/management/provider/scan_state.dart';
import 'package:gu_kulupler/features/management/provider/scan_view_model.dart';
import 'package:gu_kulupler/features/management/view/scan_view.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/service/permission_service.dart';
import 'package:gu_kulupler/product/service/qr_scanner_service.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_qr_scanner_service.dart';
import '../../../helpers/a11y_guidelines.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/fake_app_clock.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';
import '../scan_test_support.dart';

final Key _close = GuKey.action('MGT-07.close');
final Key _torch = GuKey.action('MGT-07.torch');
final Key _flip = GuKey.action('MGT-07.flip');
final Key _manualCode = GuKey.action('MGT-07.manualCode');
final Key _codeInput = GuKey.action('MGT-07.codeInput');
final Key _verify = GuKey.action('MGT-07.verify');
final Key _retry = GuKey.action('MGT-07.permission.retry');

const String _attendancePath =
    '/clubs/$kScanClubId/manage/events/$kScanEventId/attendance';
const String _path = '$_attendancePath/scan';

final ScanViewModelProvider _provider = scanViewModelProvider(
  kScanClubId,
  kScanEventId,
);

const Widget _view = ScanView(clubId: kScanClubId, eventId: kScanEventId);

FakeFeedbackService _feedback() =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;

FakeQrScannerController _scanner() =>
    (GetIt.I<QrScannerService>() as FakeQrScannerService).last!;

/// Durum kipi: oturum + ViewModel durumu ezilir.
List<Override> _overrides({ScanState? state}) => [
  appClockProvider.overrideWithValue(FakeAppClock(kScanNow)),
  sessionViewModelProvider.overrideWithBuild((ref, notifier) => scanSession()),
  _provider.overrideWithBuild((ref, notifier) => state ?? loadedScanState()),
];

Future<void> _pump(WidgetTester tester, {ScanState? state}) async {
  await tester.pumpApp(_view, overrides: _overrides(state: state));
  await tester.pump();
}

/// Sonsuz tarama çizgisi varken `pumpAndSettle` yerine.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(GuMotion.base);
  }
}

/// Akış kipi: gerçek ViewModel + yer tutucu rotalar.
Future<GoRouter> _pumpRoute(
  WidgetTester tester, {
  PermissionStatus? camera = PermissionStatus.granted,
}) async {
  GoRouter? created;
  Widget stub(GoRouterState state) => _Stub(state.uri.toString());
  await tester.pumpAppRouter(
    routerOf: (_) => created ??= GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(path: '/start', builder: (_, s) => stub(s)),
        GoRoute(
          path: _attendancePath,
          builder: (_, s) => stub(s),
          routes: [
            GoRoute(
              path: 'scan',
              builder: (_, s) => ScanView(
                clubId: s.pathParameters['clubId'] ?? kScanClubId,
                eventId: kScanEventId,
              ),
            ),
          ],
        ),
      ],
    ),
    overrides: [
      appClockProvider.overrideWithValue(FakeAppClock(kScanNow)),
      sessionViewModelProvider.overrideWithBuild(
        (ref, notifier) => scanSession(),
      ),
    ],
  );
  final router = created!;
  addTearDown(router.dispose);
  seedScan(camera: camera);
  router.go(_path);
  await _settle(tester);
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

Future<void> _tapKey(WidgetTester tester, Key key) async {
  await tester.tap(find.byKey(key));
  await _settle(tester);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_GB');
  });

  group('MGT-07 · QR tarayıcı · içerik', () {
    testWidgets('dolu: sahte önizleme + kamera açık, başlık, "Katıldı '
        '5/52", ipucu, "Kod gir"; durum çubuğu açık ikon (D-20)', (
      tester,
    ) async {
      await _pump(tester);
      final l10n = tester.l10n;
      expect(find.byKey(FakeQrScannerController.previewKey), findsOneWidget);
      expect(_scanner().isRunning, isTrue);
      expect(find.text(kScanEvent.title), findsOneWidget);
      expect(find.text(l10n.scanCounter('5', '52')), findsOneWidget);
      expect(find.text(l10n.scanHint), findsOneWidget);
      expect(find.text(l10n.scanManualCode), findsOneWidget);
      expect(find.text(l10n.scanDemoValid), findsNothing);
      final systemUi = tester.widget<GuSystemUi>(
        find.descendant(
          of: find.byType(ScanView),
          matching: find.byType(GuSystemUi),
        ),
      );
      expect(systemUi.style, GuSystemUiStyle.lightIcons);
      await expectA11yGuidelines(tester);
    });

    testWidgets('kamera izni reddi: "Kamera izni gerekli" + açıklama, "Kod '
        'gir" · "Ayarlara git"; önizleme yok, kamera kapalı', (tester) async {
      await _pump(
        tester,
        state: loadedScanState(cameraAccess: ScanCameraAccess.denied),
      );
      final l10n = tester.l10n;
      expect(find.text(l10n.scanPermissionTitle), findsOneWidget);
      expect(find.text(l10n.scanPermissionDesc), findsOneWidget);
      expect(find.byKey(_close), findsOneWidget);
      expect(find.byKey(_manualCode), findsOneWidget);
      expect(find.byKey(_retry), findsOneWidget);
      expect(find.text(l10n.scanGoSettings), findsOneWidget);
      expect(find.byKey(FakeQrScannerController.previewKey), findsNothing);
      expect(_scanner().isRunning, isFalse);
      expect(
        tester
            .widget<GuSystemUi>(
              find.descendant(
                of: find.byType(ScanView),
                matching: find.byType(GuSystemUi),
              ),
            )
            .style,
        GuSystemUiStyle.lightIcons,
      );
    });

    testWidgets('elle kod açık: "Bilet kodu" alanı + "Doğrula" (12 '
        'karakterden kısa → devre dışı)', (tester) async {
      await _pump(
        tester,
        state: loadedScanState(manualOpen: true, manualCode: 'GU-AB'),
      );
      expect(find.byKey(_codeInput), findsOneWidget);
      expect(find.byKey(_manualCode), findsNothing);
      expect(tester.widget<GuButton>(find.byKey(_verify)).disabled, isTrue);
      await _pump(
        tester,
        state: loadedScanState(manualOpen: true, manualCode: 'GU-ABCD-EFGH'),
      );
      expect(tester.widget<GuButton>(find.byKey(_verify)).disabled, isFalse);
    });
  });

  group('MGT-07 · QR tarayıcı · envanter', () {
    testWidgets('4 anahtar (yönetici bakışı; demo tarama yok)', (
      tester,
    ) async {
      await _pump(tester);
      expectActionInventory(tester, 'MGT-07', role: 'manager');
    });
  });

  group('MGT-07 · QR tarayıcı · aksiyonlar', () {
    testWidgets('QR okuması → tarama durur → SHT-24 → tarama sürer', (
      tester,
    ) async {
      await _pumpRoute(tester);
      final scanner = _scanner();
      expect(scanner.isRunning, isTrue);
      expect(scanner.emit(goingRsvp.qrPayload), isTrue);
      await _settle(tester);
      expect(_feedback().sheets, [SheetId.sht24]);
      expect(scanner.callsTo('stop'), hasLength(1));
      expect(scanner.isRunning, isTrue);
      expect(find.text(tester.l10n.scanCounter('6', '52')), findsOneWidget);
    });

    testWidgets('fener ve kamera çevir kamerayı yönetir', (tester) async {
      await _pumpRoute(tester);
      await _tapKey(tester, _torch);
      expect(_scanner().torchOn, isTrue);
      await _tapKey(tester, _flip);
      expect(_scanner().frontCamera, isTrue);
    });

    testWidgets('"Kod gir" → alan; kod + Doğrula → SHT-24', (tester) async {
      await _pumpRoute(tester);
      await _tapKey(tester, _manualCode);
      await tester.enterText(
        find.byKey(_codeInput),
        goingRsvp.ticketCode.toLowerCase(),
      );
      await _settle(tester);
      await _tapKey(tester, _verify);
      expect(_feedback().sheets, [SheetId.sht24]);
      expect(find.byKey(_codeInput), findsNothing);
    });

    testWidgets('izin yok → izin ekranı; "Ayarlara git" → izin → kamera', (
      tester,
    ) async {
      await _pumpRoute(tester, camera: null);
      expect(find.byKey(_retry), findsOneWidget);
      await _tapKey(tester, _retry);
      expect(find.byKey(_retry), findsNothing);
      expect(find.byKey(FakeQrScannerController.previewKey), findsOneWidget);
      expect(_scanner().isRunning, isTrue);
    });

    testWidgets('kapat → MGT-06', (tester) async {
      final router = await _pumpRoute(tester);
      await _tapKey(tester, _close);
      expect(_location(router), _attendancePath);
      expect(_scanner().isDisposed, isTrue);
    });
  });

  group('MGT-07 · QR tarayıcı · matris', () {
    testWidgets('kamera · izin reddi · elle kod (klavye)', (tester) async {
      await DeviceMatrix.run(tester, (_) => _view, overrides: _overrides());
      await DeviceMatrix.run(
        tester,
        (_) => _view,
        overrides: _overrides(
          state: loadedScanState(cameraAccess: ScanCameraAccess.denied),
        ),
      );
      await DeviceMatrix.run(
        tester,
        (_) => _view,
        overrides: _overrides(state: loadedScanState(manualOpen: true)),
        keyboard: true,
      );
    });
  });

  group('MGT-07 · QR tarayıcı · golden', () {
    testWidgets('varsayılan açık + koyu', (tester) async {
      await goldenForThemes(tester, 'MGT-07', _view, overrides: _overrides());
    });
  });
}
