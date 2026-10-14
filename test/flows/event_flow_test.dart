// T-23 · Uçtan uca etkinlik akışı: gerçek `GuApp` (rota ağacı, yönlendirme,
// oturum katmanı, `AppFeedbackService`) + sahte servisler. Oturum hazırdır
// (`u_mehmet`, `c01` üyesi); saat demo verinin üretim anıdır (8 Eki 19:24
// Istanbul — `e01`'den bir gün önce).
//
//   CLB-03 (c01) "Etkinlikler" → EventCard (e01) → EVT-02 → "Katıl" → SHT-12
//   (1 sa) → going + plan + TST-41 → hatırlatıcı → SHT-13 (15 dk) → plan
//   yenilendi + TST-37 → "Biletini göster" → EVT-03 → okutuldu (canlı) →
//   TST-15 → geri → EVT-02
//   CLB-03 kart hızlı eylemi "Katıl" (e02) → SHT-12 → going (EVT-02 açılmaz)
//   EVT-02 (e03, kontenjan dolu) → "Bekleme listesine katıl" → DLG-15 →
//   waitlist + TST-43
//   üyelere özel etkinliğe yetkisiz derin bağlantı → TST-X18 → /events
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/bootstrap/gu_app.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/clubs/view/club_detail_view.dart';
import 'package:gu_kulupler/features/events/provider/ticket_view_model.dart';
import 'package:gu_kulupler/features/events/view/event_detail_view.dart';
import 'package:gu_kulupler/features/events/view/ticket_view.dart';
import 'package:gu_kulupler/features/events/view/widget/reminder_sheet.dart';
import 'package:gu_kulupler/features/events/view/widget/rsvp_confirm_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/app_router.dart';
import 'package:gu_kulupler/product/navigation/navigator_keys.dart';
import 'package:gu_kulupler/product/service/local_reminder_service.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../fakes/fake_app_preferences_store.dart';
import '../fakes/fake_auth_repository.dart';
import '../fakes/fake_club_repository.dart';
import '../fakes/fake_event_repository.dart';
import '../fakes/fake_local_reminder_service.dart';
import '../fakes/fake_rsvp_repository.dart';
import '../fakes/register_fakes.dart';
import '../features/clubs/club_members_test_support.dart';
import '../fixtures/club_model_fixtures.dart';
import '../fixtures/event_model_fixtures.dart';
import '../helpers/fake_app_clock.dart';
import '../helpers/test_asset_bundle.dart';

/// Demo verinin üretim anı (8 Eki 19:24 Istanbul).
final DateTime _nowUtc = DateTime.utc(2026, 10, 8, 16, 24, 30);

Key _k(String id) => GuKey.action(id);

FakeEventRepository _events() =>
    GetIt.I<EventRepository>() as FakeEventRepository;

FakeRsvpRepository _rsvps() => GetIt.I<RsvpRepository>() as FakeRsvpRepository;

FakeLocalReminderService _reminders() =>
    GetIt.I<LocalReminderService>() as FakeLocalReminderService;

RsvpModel? _rsvpOf(String eventId) => _rsvps().rsvps.values
    .where((rsvp) => rsvp.eventId == eventId && rsvp.userId == kMembersUid)
    .firstOrNull;

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
  seedMembers();
  (GetIt.I<AppClock>() as FakeAppClock).set(_nowUtc);
  (GetIt.I<ClubRepository>() as FakeClubRepository).clubs['c03'] =
      ClubModelFixtures.byId('c03');
  _events()
    ..put(EventModelFixtures.e01)
    ..put(EventModelFixtures.e02)
    ..put(EventModelFixtures.e03);
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
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(GuApp)));

GoRouter _router(WidgetTester tester) =>
    _container(tester).read(appRouterProvider);

String _location(WidgetTester tester) =>
    _router(tester).routerDelegate.currentConfiguration.uri.toString();

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

Future<void> _flushToast(WidgetTester tester) async {
  await tester.pump(GuMotion.toastUndo);
  await tester.pumpAndSettle();
}

/// CLB-03 (c01) "Etkinlikler" sekmesi.
Future<void> _openClubEvents(WidgetTester tester) async {
  await _go(tester, '${AppPaths.clubs}/$kMembersClubId');
  expect(find.byType(ClubDetailView), findsOneWidget);
  await _tap(tester, _k('CLB-03.tab.events'));
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_GB');
    await initializeDateFormatting('en_US');
  });

  testWidgets('CLB-03 → EventCard → EVT-02 → katıl (SHT-12) → hatırlatıcı '
      '(SHT-13) → EVT-03 → canlı "okutuldu" → geri', (tester) async {
    await _launch(tester);
    const eventId = 'e01';
    final event = EventModelFixtures.e01;
    await _openClubEvents(tester);

    // Kart → EVT-02.
    await _tap(tester, _k('CLB-03.card.$eventId'));
    expect(_location(tester), '${AppPaths.events}/$eventId');
    expect(find.byType(EventDetailView), findsOneWidget);

    // "Katıl" → SHT-12 (varsayılan 1 sa) → going + plan + TST-41.
    await _tap(tester, _k('EVT-02.join'));
    expect(find.byType(RsvpConfirmSheet), findsOneWidget);
    await _tap(tester, _k('SHT-12.confirm'));
    final joined = _rsvpOf(eventId)!;
    expect(joined.status, RsvpStatus.going);
    expect(joined.reminder, ReminderOption.oneHour);
    expect(
      _reminders().scheduledFor(joined.id)?.triggerAtUtc,
      event.startsAt.subtract(const Duration(hours: 1)),
    );
    expect(_toast(ToastId.tst41), findsOneWidget);
    await _flushToast(tester);

    // Hatırlatıcı → SHT-13 (15 dk) → plan yenilendi + TST-37.
    await _tap(tester, _k('EVT-02.reminder'));
    expect(find.byType(ReminderSheet), findsOneWidget);
    await _tap(tester, _k('SHT-13.select.15m'));
    expect(
      _reminders().scheduledFor(joined.id)?.triggerAtUtc,
      event.startsAt.subtract(const Duration(minutes: 15)),
    );
    expect(
      _reminders().scheduledFor(joined.id)?.payload,
      LocalReminderService.payloadFor(eventId),
    );
    expect(_toast(ToastId.tst37), findsOneWidget);
    await _flushToast(tester);

    // "Biletini göster" → EVT-03.
    await _tap(tester, _k('EVT-02.ticket'));
    expect(_location(tester), '${AppPaths.events}/$eventId/ticket');
    expect(find.byType(TicketView), findsOneWidget);
    final ticket = ticketViewModelProvider(eventId);
    expect(_container(tester).read(ticket).status, TicketState.valid);

    // Yönetici okuttu (canlı akış) → rozet "Okutuldu" + TST-15.
    _rsvps().put(
      _rsvpOf(eventId)!.copyWith(
        status: RsvpStatus.attended,
        scannedAt: _nowUtc,
        scannedBy: 'u_p_c01',
      ),
    );
    await tester.pumpAndSettle();
    expect(_container(tester).read(ticket).status, TicketState.used);
    expect(_toast(ToastId.tst15), findsOneWidget);
    await _flushToast(tester);

    // Geri → EVT-02.
    await _tap(tester, _k('EVT-03.back'));
    expect(_location(tester), '${AppPaths.events}/$eventId');
    expect(find.byType(EventDetailView), findsOneWidget);
  });

  testWidgets('CLB-03 kart hızlı eylemi "Katıl" → SHT-12 → going (ekran '
      'değişmez)', (tester) async {
    await _launch(tester);
    const eventId = 'e02';
    await _openClubEvents(tester);
    await _tap(tester, _k('CLB-03.join.$eventId'));
    expect(find.byType(RsvpConfirmSheet), findsOneWidget);
    await _tap(tester, _k('SHT-12.confirm'));
    expect(_rsvpOf(eventId)?.status, RsvpStatus.going);
    expect(_reminders().scheduledFor(_rsvpOf(eventId)!.id), isNotNull);
    expect(_location(tester), startsWith('${AppPaths.clubs}/$kMembersClubId'));
    expect(_toast(ToastId.tst41), findsOneWidget);
    await _flushToast(tester);
  });

  testWidgets('kontenjan dolu (e03) → "Bekleme listesine katıl" → DLG-15 → '
      'waitlist + TST-43; üyelere özel etkinliğe yetkisiz bağlantı → TST-X18 '
      '→ /events', (tester) async {
    await _launch(tester);
    const eventId = 'e03';
    expect(EventModelFixtures.e03.joinsWaitlist, isTrue);
    await _go(tester, '${AppPaths.events}/$eventId');
    expect(find.byType(EventDetailView), findsOneWidget);
    expect(find.byKey(_k('EVT-02.join')), findsNothing);

    await _tap(tester, _k('EVT-02.waitlist'));
    await _tap(tester, _k('DLG-15.confirm'));
    final waiting = _rsvpOf(eventId)!;
    expect(waiting.status, RsvpStatus.waitlist);
    // Bekleme listesinde hatırlatıcı planlanmaz.
    expect(_reminders().scheduledFor(waiting.id), isNull);
    expect(_toast(ToastId.tst43), findsOneWidget);
    await _flushToast(tester);

    // Üyelere özel etkinlik: Rules okumayı reddeder (CD-57).
    // Etkinlikten etkinliğe `go` (aynı sayfa kalıbı): ekran yeniden kurulur.
    _events().failNext(FirestoreError.permissionDenied);
    await _go(tester, '${AppPaths.events}/e02');
    expect(_toast(ToastId.tstX18), findsOneWidget);
    expect(_location(tester), AppPaths.events);
    await _flushToast(tester);
  });
}
