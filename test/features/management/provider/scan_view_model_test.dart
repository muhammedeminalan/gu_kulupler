// MGT-07 · ScanViewModel: açılış (etkinlik + canlı kayıtlar, sayaç 5/52),
// kamera izni (var → kamera; DLG-04 vazgeç / sistem reddi → TST-32 + izin
// ekranı; "Ayarlara git" yeniden ister ya da ayarları açar; dönüşte yeniden
// denetim), okutma (biçimsiz / başka etkinlik → ağa çıkmadan geçersiz;
// scanTicket geçerli / zaten okutulmuş / geçersiz / pencere dışı → SHT-24),
// aynı içeriğin art arda okunması, elle kod, danışman TST-26 — PLAN §4.2,
// roadmap T-35.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/management/provider/scan_state.dart';
import 'package:gu_kulupler/features/management/provider/scan_view_model.dart';
import 'package:gu_kulupler/product/event/ticket_scan_parser.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';
import 'package:gu_kulupler/product/service/permission_service.dart';

import '../../../fakes/fake_attendance_repository.dart';
import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_permission_service.dart';
import '../../../fakes/register_fakes.dart';
import '../../../helpers/fake_app_clock.dart';
import '../../../helpers/test_container.dart';
import '../scan_test_support.dart';

void main() {
  late FakeAttendanceRepository attendance;
  late FakePermissionService permissions;
  late FakeFeedbackService feedback;
  late FakeAppClock clock;

  final provider = scanViewModelProvider(kScanClubId, kScanEventId);

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    attendance = GetIt.I<AttendanceRepository>() as FakeAttendanceRepository;
    permissions = GetIt.I<PermissionService>() as FakePermissionService;
    feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
    clock = GetIt.I<AppClock>() as FakeAppClock;
  });

  Future<ProviderContainer> loaded({
    SessionState? session,
    PermissionStatus? camera = PermissionStatus.granted,
  }) async {
    seedScan(camera: camera);
    final container = createContainer(
      overrides: [
        sessionViewModelProvider.overrideWithBuild(
          (ref, notifier) => session ?? scanSession(),
        ),
      ],
    );
    addTearDown(container.listen(provider, (_, _) {}).close);
    await pumpEventQueue();
    return container;
  }

  ScanViewModel vm(ProviderContainer c) => c.read(provider.notifier);

  String qr(RsvpModel r) => r.qrPayload;

  group('MGT-07 · açılış ve kamera izni', () {
    test('izin var: etkinlik + canlı kayıtlar (Katıldı 5/52), kamera açık; '
        'DLG-04 yok', () async {
      final c = await loaded();
      final state = c.read(provider);
      expect(state.event?.title, kScanEvent.title);
      expect(state.attendedCount, 5);
      expect(state.registeredCount, 52);
      expect(state.cameraAccess, ScanCameraAccess.granted);
      expect(state.isCameraActive, isTrue);
      expect(state.showPermissionScreen, isFalse);
      expect(feedback.dialogs, isEmpty);
    });

    test('izin yok: DLG-04 "Şimdi değil" → izin ekranı, toast yok; "İzin '
        'ver" + sistem reddi → TST-32', () async {
      final c = await loaded(camera: null);
      expect(feedback.dialogs, [DialogId.dlg04]);
      expect(c.read(provider).cameraAccess, ScanCameraAccess.denied);
      expect(c.read(provider).showPermissionScreen, isTrue);
      expect(c.read(provider).isCameraActive, isFalse);
      expect(feedback.toasts, isEmpty);

      feedback.dialogResults[DialogId.dlg04] = true;
      permissions.results[Permission.camera] = PermissionStatus.denied;
      final c2 = await loaded(camera: null);
      expect(permissions.requested, contains(Permission.camera));
      expect(feedback.toasts, [ToastId.tst32]);
      expect(c2.read(provider).cameraAccess, ScanCameraAccess.denied);
    });

    test(
      '"Ayarlara git": sistem sorabiliyorsa yeniden ister (verilirse '
      'kamera); kalıcı retse ayarları açar; dönüşte yeniden denetim',
      () async {
        final c = await loaded(camera: null);
        expect(c.read(provider).cameraAccess, ScanCameraAccess.denied);

        // Sistem yeniden sorar ve izin verilir.
        await vm(c).retryPermission();
        expect(c.read(provider).cameraAccess, ScanCameraAccess.granted);
        expect(permissions.openedSettings, 0);

        // Kalıcı ret → ayarlar; ayarlarda açılınca dönüşte kamera açılır.
        final c2 = await loaded(camera: PermissionStatus.permanentlyDenied);
        expect(c2.read(provider).cameraAccess, ScanCameraAccess.denied);
        await vm(c2).retryPermission();
        expect(permissions.openedSettings, 1);
        expect(c2.read(provider).cameraAccess, ScanCameraAccess.denied);
        permissions.results[Permission.camera] = PermissionStatus.granted;
        await vm(c2).recheckPermission();
        expect(c2.read(provider).cameraAccess, ScanCameraAccess.granted);
      },
    );
  });

  group('MGT-07 · okutma → SHT-24', () {
    test(
      'biçimsiz ve başka etkinliğin QR\'ı → ağa çıkmadan "Geçersiz bilet"',
      () async {
        final c = await loaded();
        await vm(c).onCode('https://example.org/not-a-ticket');
        expect(c.read(provider).lastResult?.outcome, ScanOutcome.invalid);
        expect(
          c.read(provider).lastResult?.rejection,
          TicketScanRejection.malformed,
        );
        await vm(c).onCode(
          FirestoreIds.ticketQrPayload('e01', goingRsvp.ticketCode),
        );
        expect(
          c.read(provider).lastResult?.rejection,
          TicketScanRejection.otherEvent,
        );
        expect(attendance.callsTo('scanTicket'), isEmpty);
        expect(feedback.sheets, [SheetId.sht24, SheetId.sht24]);
        expect(c.read(provider).isShowingResult, isFalse);
      },
    );

    test('geçerli: scanTicket (actor u_elif) → "Geçerli bilet", sahibi + '
        'sayaç 6/52; kayıt hemen attended', () async {
      final c = await loaded();
      final going = goingRsvp;
      await vm(c).onCode(qr(going));
      final call = attendance.callsTo('scanTicket').single;
      expect(call.args, [kScanEventId, kScanClubId, qr(going), kScanUid]);
      final result = c.read(provider).lastResult!;
      expect(result.outcome, ScanOutcome.valid);
      expect(result.user?.uid, going.userId);
      expect(result.counter, (attended: 6, registered: 52));
      expect(
        c.read(provider).findByCode(going.ticketCode)?.status,
        RsvpStatus.attended,
      );
      expect(feedback.sheets, [SheetId.sht24]);
      expect(c.read(provider).isPaused, isFalse);
    });

    test('zaten okutulmuş: "Zaten okutulmuş" + önceki okutma anı; yazım '
        'yok', () async {
      final c = await loaded();
      final attended = attendedRsvp;
      await vm(c).onCode(qr(attended));
      final result = c.read(provider).lastResult!;
      expect(result.outcome, ScanOutcome.alreadyScanned);
      expect(result.user?.uid, attended.userId);
      expect(result.scannedAt, attended.scannedAt);
      expect(attended.scannedBy, isNotNull);
      expect(result.scannedByName, isNotEmpty);
      expect(result.counter, isNull);
      expect(c.read(provider).attendedCount, 5);
    });

    test('kayıtsız kod → "Geçersiz bilet"; pencere dışı (K-G) → "Geçersiz '
        'bilet"', () async {
      final c = await loaded();
      await vm(
        c,
      ).onCode(FirestoreIds.ticketQrPayload(kScanEventId, 'GU-ZZZZ-ZZZZ'));
      expect(c.read(provider).lastResult?.outcome, ScanOutcome.invalid);
      expect(c.read(provider).lastResult?.rejection, isNull);

      clock.set(kScanNow.add(const Duration(days: 2)));
      await vm(c).onCode(qr(goingRsvp));
      expect(attendance.callsTo('scanTicket'), hasLength(2));
      expect(c.read(provider).lastResult?.outcome, ScanOutcome.invalid);
      expect(c.read(provider).lastResult?.windowClosed, isTrue);
      expect(c.read(provider).attendedCount, 5);
    });

    test('aynı içerik art arda: bekleme süresi içinde yok sayılır, sonra '
        'yeniden okunur', () async {
      final c = await loaded();
      const raw = 'gu:ticket:v1:e01:GU-AAAA-AAAB';
      await vm(c).onCode(raw);
      await vm(c).onCode(raw);
      expect(feedback.sheets, hasLength(1));
      clock.advance(ScanViewModel.repeatScanCooldown);
      await vm(c).onCode(raw);
      expect(feedback.sheets, hasLength(2));
    });

    test(
      'sonuç açıkken / okutma sürerken kamera kapalı, okuma yok sayılır',
      () async {
        final c = await loaded();
        final state = c.read(provider);
        expect(state.copyWith(isShowingResult: true).isCameraActive, isFalse);
        expect(state.copyWith(isProcessing: true).isCameraActive, isFalse);

        final first = vm(c).onCode(qr(goingRsvp));
        expect(c.read(provider).isProcessing, isTrue);
        expect(c.read(provider).isCameraActive, isFalse);
        await vm(c).onCode(qr(attendedRsvp));
        await first;
        expect(attendance.callsTo('scanTicket'), hasLength(1));
        expect(feedback.sheets, [SheetId.sht24]);
        expect(c.read(provider).isCameraActive, isTrue);
      },
    );

    test('danışman: okutma yok → TST-26', () async {
      final c = await loaded(session: scanSession(role: ClubRole.advisor));
      expect(c.read(provider).isReadOnly, isTrue);
      await vm(c).onCode(qr(goingRsvp));
      expect(feedback.toasts, [ToastId.tst26]);
      expect(attendance.callsTo('scanTicket'), isEmpty);
    });
  });

  group('MGT-07 · elle kod', () {
    test('kod büyük harfe çevrilir; 12 karakterden kısa → Doğrula kapalı; '
        'bulunan bilet → okutulur, alan kapanır', () async {
      final c = await loaded();
      vm(c).openManual();
      expect(c.read(provider).manualOpen, isTrue);
      final code = goingRsvp.ticketCode;
      vm(c).setManualCode(code.substring(0, 6).toLowerCase());
      expect(c.read(provider).manualCode, code.substring(0, 6));
      expect(c.read(provider).canVerify, isFalse);
      await vm(c).verifyManual();
      expect(attendance.callsTo('scanTicket'), isEmpty);

      vm(c).setManualCode(code.toLowerCase());
      expect(c.read(provider).canVerify, isTrue);
      await vm(c).verifyManual();
      expect(
        attendance.callsTo('scanTicket').single.args[2],
        qr(goingRsvp),
      );
      expect(c.read(provider).lastResult?.outcome, ScanOutcome.valid);
      expect(c.read(provider).manualCode, isEmpty);
      expect(c.read(provider).manualOpen, isFalse);
    });

    test(
      'bulunmayan / biçimsiz kod → "Geçersiz bilet", kod alanda kalır',
      () async {
        final c = await loaded();
        vm(c)
          ..openManual()
          ..setManualCode('GU-ZZZZ-ZZZZ');
        await vm(c).verifyManual();
        expect(c.read(provider).lastResult?.outcome, ScanOutcome.invalid);
        expect(c.read(provider).manualCode, 'GU-ZZZZ-ZZZZ');
        expect(c.read(provider).manualOpen, isTrue);

        vm(c).setManualCode('ABCDEFGHIJKLM');
        await vm(c).verifyManual();
        expect(
          c.read(provider).lastResult?.rejection,
          TicketScanRejection.malformed,
        );
        expect(attendance.callsTo('scanTicket'), hasLength(1));
      },
    );

    test('fener / kamera çevir durumu', () async {
      final c = await loaded();
      vm(c)
        ..toggleTorch()
        ..flipCamera();
      expect(c.read(provider).torchOn, isTrue);
      expect(c.read(provider).frontCamera, isTrue);
    });
  });

  group('MGT-07 · çevrimdışı (T-44)', () {
    test('kamera okutması ve elle kod: TST-24; scanTicket yok, işleniyor '
        'durumuna geçilmez, kod alanı kalır', () async {
      final c = await loaded();
      (GetIt.I<ConnectivityService>() as FakeConnectivityService).isOffline =
          true;

      await vm(c).onCode(qr(goingRsvp));
      expect(c.read(provider).isProcessing, isFalse);

      vm(c)
        ..openManual()
        ..setManualCode(goingRsvp.ticketCode);
      await vm(c).verifyManual();

      expect(attendance.callsTo('scanTicket'), isEmpty);
      expect(c.read(provider).isProcessing, isFalse);
      expect(c.read(provider).manualCode, goingRsvp.ticketCode);
      expect(feedback.sheets, isEmpty);
      expect(feedback.toasts, [ToastId.tst24, ToastId.tst24]);
    });
  });
}
