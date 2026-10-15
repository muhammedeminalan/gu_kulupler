// T-35 · Uçtan uca yoklama akışı: gerçek `GuApp` (rota ağacı, guard `V` /
// `M`, oturum, kabuk, `AppFeedbackService` — SHT-23 / SHT-24 ve toast'lar
// gerçekten çizilir) + sahte servisler (kamera `FakeQrScannerService`).
// Veri: `u_elif` (c01 yönetim kurulu) → e17 "Veri Bilimi Söyleşisi" (52
// kayıt: 5 katıldı; + bekleme listesinde `u_mehmet`); saat yoklama
// penceresinin içinde (başlangıç + 30 dk).
//
//   MGT-04 → e17 "⋮" (SHT-23) → Katılımcılar (W-42) → MGT-06 → "Gelmedi"
//   çipi → bir kayıtlıyı Katıldı yap (TST-31) → Geri al → "Bekleme" çipi →
//   Kayıtlıya al (TST-X13) → QR → MGT-07 → geçerli bilet (SHT-24, 2 sn sonra
//   kapanır) → aynı bilet "Zaten okutulmuş" → başka etkinliğin bileti
//   "Geçersiz" → kapat → MGT-06'da katıldı sayısı 6; bilet sahibinin EVT-03
//   bileti (aynı fake'ler, canlı) "kullanıldı"ya döner.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/bootstrap/gu_app.dart';
import 'package:gu_kulupler/core/constants/app_durations.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/events/provider/ticket_view_model.dart';
import 'package:gu_kulupler/features/management/provider/attendance_view_model.dart';
import 'package:gu_kulupler/features/management/view/attendance_view.dart';
import 'package:gu_kulupler/features/management/view/scan_view.dart';
import 'package:gu_kulupler/features/management/view/widget/scan_overlay.dart';
import 'package:gu_kulupler/features/management/view/widget/scan_result_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/event_menu_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/navigation/app_router.dart';
import 'package:gu_kulupler/product/navigation/navigator_keys.dart';
import 'package:gu_kulupler/product/service/permission_service.dart';
import 'package:gu_kulupler/product/service/qr_scanner_service.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../fakes/fake_app_preferences_store.dart';
import '../fakes/fake_auth_repository.dart';
import '../fakes/fake_event_repository.dart';
import '../fakes/fake_membership_repository.dart';
import '../fakes/fake_permission_service.dart';
import '../fakes/fake_qr_scanner_service.dart';
import '../fakes/fake_rsvp_repository.dart';
import '../fakes/fake_user_repository.dart';
import '../fakes/register_fakes.dart';
import '../features/management/attendance_test_support.dart';
import '../fixtures/demo_data.dart';
import '../fixtures/membership_model_fixtures.dart';
import '../fixtures/user_model_fixtures.dart';
import '../helpers/fake_app_clock.dart';
import '../helpers/test_asset_bundle.dart';
import '../helpers/test_container.dart';

const String _club = kAttendanceClubId;
const String _event = kAttendanceEventId;
const String _events = '/clubs/$_club/manage/events';
const String _attendance = '$_events/$_event/attendance';
const String _waiting = 'u_mehmet';

Key _k(String id) => GuKey.action(id);

FakeRsvpRepository _rsvps() => GetIt.I<RsvpRepository>() as FakeRsvpRepository;

RsvpStatus? _status(String userId) =>
    _rsvps().rsvps[FirestoreIds.rsvp(_event, userId)]?.status;

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
  seedAttendance(extra: [waitlisted(_waiting)]);
  final events = GetIt.I<EventRepository>() as FakeEventRepository;
  events.put(events.events[_event]!.copyWith(waitlistCount: 1));
  final memberships =
      GetIt.I<MembershipRepository>() as FakeMembershipRepository;
  for (final id in DemoDataFixture.ids(FirestoreCollections.memberships)) {
    if (id.startsWith('${_club}_')) {
      memberships.put(MembershipModelFixtures.byId(id));
    }
  }
  (GetIt.I<PermissionService>() as FakePermissionService).results[Permission
          .camera] =
      PermissionStatus.granted;
  const uid = kAttendanceUid;
  const email = '$uid@ogr.gumushane.edu.tr';
  (GetIt.I<AuthRepository>() as FakeAuthRepository)
    ..service.uid = uid
    ..service.emailVerified = true
    ..currentUser = const AuthUserInfo(
      uid: uid,
      email: email,
      emailVerified: true,
    );
  (GetIt.I<UserRepository>() as FakeUserRepository).putActive(
    uid,
    name: UserModelFixtures.byId(uid).name,
    email: email,
  );
  (GetIt.I<AppPreferencesStore>() as FakeAppPreferencesStore)
    ..values[AppPreferenceKeys.onboardingSeen] = true
    ..values[AppPreferenceKeys.notificationPermissionAsked] = true;
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(390, 1800);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
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
  _router(tester).go(_events);
  await tester.pumpAndSettle();
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(GuApp)));

GoRouter _router(WidgetTester tester) =>
    _container(tester).read(appRouterProvider);

String _location(WidgetTester tester) =>
    _router(tester).routerDelegate.currentConfiguration.uri.toString();

Future<void> _tap(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// MGT-07'de sonsuz tarama çizgisi varken `pumpAndSettle` yerine.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(GuMotion.base);
  }
}

Finder _toast(ToastId id) => find.byKey(ValueKey<ToastId>(id));

Future<void> _dismissToast(WidgetTester tester) async {
  await tester.pump(GuMotion.toastUndo);
  await tester.pumpAndSettle();
}

ScanResultSheet _sheet(WidgetTester tester) =>
    tester.widget<ScanResultSheet>(find.byType(ScanResultSheet));

/// Okunan [raw] içeriği → SHT-24.
Future<void> _scan(WidgetTester tester, String raw) async {
  final scanner = (GetIt.I<QrScannerService>() as FakeQrScannerService).last!;
  expect(scanner.emit(raw), isTrue);
  await _settle(tester);
  expect(find.byType(ScanResultSheet), findsOneWidget);
}

/// SHT-24 X → tarama sürer; aynı içerik bekleme süresinden sonra yeniden
/// okunabilir.
Future<void> _closeSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(ScanResultSheet.closeKey));
  await _settle(tester);
  expect(find.byType(ScanResultSheet), findsNothing);
  (GetIt.I<AppClock>() as FakeAppClock).advance(
    AppDurations.scanRepeatCooldown,
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_GB');
    await initializeDateFormatting('en_US');
  });

  testWidgets('yönetici: MGT-04 → SHT-23 → MGT-06 (çip, Katıldı + Geri al, '
      'Kayıtlıya al) → MGT-07 (geçerli / zaten okutulmuş / geçersiz) → '
      'MGT-06 sayaç; sahibinin EVT-03 bileti canlı "kullanıldı"', (
    tester,
  ) async {
    await _launch(tester);
    final rsvps = attendanceRsvps();
    final going = rsvps.where(
      (r) => r.status == RsvpStatus.going && r.userId != kAttendanceUid,
    );
    final marked = going.first.userId;
    final ticket = going.elementAt(1);
    final attendedBefore = rsvps
        .where((r) => r.status == RsvpStatus.attended)
        .length;

    // Bilet sahibinin EVT-03'ü (aynı fake'ler, ayrı oturum) — canlı dinler.
    final holder = createContainer(
      overrides: [
        sessionViewModelProvider.overrideWithBuild(
          (ref, notifier) => SessionState(
            status: AuthStatus.active,
            uid: ticket.userId,
            onboardingSeen: true,
            user: UserModelFixtures.byId(ticket.userId),
          ),
        ),
      ],
    );
    final ticketProvider = ticketViewModelProvider(_event);
    addTearDown(holder.listen(ticketProvider, (_, _) {}).close);
    await tester.pump();
    expect(holder.read(ticketProvider).status, TicketState.valid);

    // MGT-04 → e17 "⋮" → SHT-23 "Katılımcılar" (W-42) → MGT-06.
    await _tap(tester, _k('MGT-04.menu.$_event'));
    await _tap(tester, EventMenuSheet.keyOf(EventMenuAction.attendees));
    expect(_location(tester), _attendance);
    expect(find.byType(AttendanceView), findsOneWidget);

    // "Gelmedi" çipi → Katıldı → TST-31 → Geri al.
    await _tap(tester, _k('MGT-06.summary.absent'));
    await tester.enterText(
      find.descendant(
        of: find.byKey(_k('MGT-06.search')),
        matching: find.byType(EditableText),
      ),
      UserModelFixtures.byId(marked).name,
    );
    await tester.pumpAndSettle();
    await _tap(tester, _k('MGT-06.attended.$marked'));
    expect(_toast(ToastId.tst31), findsOneWidget);
    expect(_status(marked), RsvpStatus.attended);
    await _tap(tester, FeedbackKeys.of('TST-31', 'undo'));
    expect(_status(marked), RsvpStatus.going);
    await _dismissToast(tester);

    // "Bekleme" çipi → Kayıtlıya al → TST-X13.
    await _tap(tester, _k('MGT-06.summary.waitlist'));
    await _tap(tester, _k('MGT-06.promote.$_waiting'));
    expect(_toast(ToastId.tstX13), findsOneWidget);
    expect(_status(_waiting), RsvpStatus.going);
    await _dismissToast(tester);

    // QR → MGT-07 (kamera izni var: DLG-04 açılmaz).
    await _tap(tester, _k('MGT-06.summary.all'));
    await tester.tap(find.byKey(_k('MGT-06.scan')));
    await _settle(tester);
    expect(_location(tester), '$_attendance/scan');
    expect(find.byType(ScanView), findsOneWidget);

    // Geçerli bilet → SHT-24 → 2 sn sonra kendiliğinden kapanır.
    await _scan(tester, ticket.qrPayload);
    expect(_sheet(tester).outcome, ScanOutcome.valid);
    expect(_status(ticket.userId), RsvpStatus.attended);
    await tester.pump(AppDurations.qrSuccessAutoClose);
    await _settle(tester);
    expect(find.byType(ScanResultSheet), findsNothing);
    (GetIt.I<AppClock>() as FakeAppClock).advance(
      AppDurations.scanRepeatCooldown,
    );

    // Aynı bilet → "Zaten okutulmuş" (okutan: oturumdaki yönetici).
    await _scan(tester, ticket.qrPayload);
    expect(_sheet(tester).outcome, ScanOutcome.alreadyScanned);
    await _closeSheet(tester);

    // Başka etkinliğin bileti → "Geçersiz" (ağa çıkmadan).
    await _scan(
      tester,
      FirestoreIds.ticketQrPayload('e03', ticket.ticketCode),
    );
    expect(_sheet(tester).outcome, ScanOutcome.invalid);
    expect(_sheet(tester).invalidReason, ScanInvalidReason.notForEvent);
    await _closeSheet(tester);

    // Kapat → MGT-06: katıldı sayısı bir arttı.
    await tester.tap(find.byKey(ScanOverlay.closeKey));
    await tester.pumpAndSettle();
    expect(_location(tester), _attendance);
    final state = _container(
      tester,
    ).read(attendanceViewModelProvider(_club, _event));
    expect(state.attendedCount, attendedBefore + 1);

    // Bilet sahibinin EVT-03'ü canlı akıştan "kullanıldı"ya döndü.
    final after = holder.read(ticketProvider);
    expect(after.status, TicketState.used);
    expect(after.rsvp?.scannedBy, kAttendanceUid);
  });
}
