// T-24 · Uçtan uca etkinlik listesi akışı: gerçek `GuApp` (rota ağacı,
// yönlendirme, oturum katmanı, `AppFeedbackService`) + sahte servisler.
// Oturum hazırdır (`u_mehmet`, `c01` üyesi); saat 8 Eki 15:00 Istanbul
// (referans görüntünün günü); demo verinin tüm kulüpleri ve etkinlikleri,
// Mehmet'in `e01` (going) ve `e18` (yoklaması alınmış, geçmiş) kayıtları.
//
//   giriş → "Etkinlikler" sekmesi (EVT-01) → çip "Bu hafta" → SHT-11 tür
//   "Eğitim" → Uygula (yalnız `e01`) → takvim kipi → 9 Eki → kart → EVT-02 →
//   geri → "Biletlerim" (EVT-04) → Yaklaşan `e01` → Vazgeç → DLG-14 →
//   TST-42 → Geçmiş sekmesinde bitmiş `e18`
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/bootstrap/gu_app.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/events/provider/event_list_state.dart';
import 'package:gu_kulupler/features/events/provider/event_list_view_model.dart';
import 'package:gu_kulupler/features/events/view/event_detail_view.dart';
import 'package:gu_kulupler/features/events/view/event_list_view.dart';
import 'package:gu_kulupler/features/events/view/my_events_view.dart';
import 'package:gu_kulupler/features/events/view/widget/event_filter_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/app_router.dart';
import 'package:gu_kulupler/product/navigation/navigator_keys.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../fakes/fake_app_preferences_store.dart';
import '../fakes/fake_auth_repository.dart';
import '../fakes/fake_rsvp_repository.dart';
import '../fakes/register_fakes.dart';
import '../features/clubs/club_members_test_support.dart';
import '../features/events/event_list_test_support.dart';
import '../fixtures/rsvp_model_fixtures.dart';
import '../helpers/test_asset_bundle.dart';

Key _k(String id) => GuKey.action(id);

FakeRsvpRepository _rsvps() => GetIt.I<RsvpRepository>() as FakeRsvpRepository;

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
  seedEventList(
    rsvps: [RsvpModelFixtures.e01Mehmet, RsvpModelFixtures.e18Mehmet],
  );
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

String _location(WidgetTester tester) => _container(
  tester,
).read(appRouterProvider).routerDelegate.currentConfiguration.uri.toString();

EventListState _list(WidgetTester tester) =>
    _container(tester).read(eventListViewModelProvider);

Future<void> _tap(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _toast(ToastId id) => find.byKey(ValueKey<ToastId>(id));

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_GB');
    await initializeDateFormatting('en_US');
  });

  testWidgets('EVT-01 çip + SHT-11 → takvim → gün → EVT-02 → geri → EVT-04 '
      'vazgeç → geçmiş', (tester) async {
    await _launch(tester);

    // "Etkinlikler" sekmesi → EVT-01.
    await _tap(tester, _k('NAV.tab.events'));
    expect(_location(tester), AppPaths.events);
    expect(find.byType(EventListView), findsOneWidget);
    expect(find.byKey(_k('EVT-01.card.e17')), findsOneWidget);

    // Çip "Bu hafta".
    await _tap(tester, _k('EVT-01.chip.week'));
    expect(_list(tester).chip, EventListChip.week);
    expect(find.byKey(_k('EVT-01.card.e15')), findsNothing);

    // SHT-11: tür "Eğitim" → Uygula → yalnız e01 (9 Eki).
    await _tap(tester, _k('EVT-01.filter'));
    expect(find.byType(EventFilterSheet), findsOneWidget);
    await _tap(tester, _k('SHT-11.type.${EventType.training.json}'));
    await _tap(tester, _k('SHT-11.apply'));
    expect(find.byType(EventFilterSheet), findsNothing);
    expect(_list(tester).filter.types, {EventType.training});
    expect(find.byKey(_k('EVT-01.card.e01')), findsOneWidget);
    expect(find.byKey(_k('EVT-01.card.e17')), findsNothing);

    // Takvim kipi → 9 Eki → sıkışık kart (e01) → EVT-02 → geri.
    await _tap(tester, _k('EVT-01.view.calendar'));
    expect(find.byKey(_k('EVT-01.chip.week')), findsNothing);
    await _tap(tester, _k('EVT-01.day.2026-10-09'));
    expect(_list(tester).selectedDay, DateTime(2026, 10, 9));
    await _tap(tester, _k('EVT-01.card.e01'));
    expect(_location(tester), '${AppPaths.events}/e01');
    expect(find.byType(EventDetailView), findsOneWidget);
    await _tap(tester, _k('EVT-02.back'));
    expect(_location(tester), AppPaths.events);
    expect(_list(tester).mode, EventListMode.calendar);

    // "Biletlerim" → EVT-04 Yaklaşan: e01 → Vazgeç → DLG-14 → TST-42.
    await _tap(tester, _k('EVT-01.tickets'));
    expect(_location(tester), '${AppPaths.events}/mine');
    expect(find.byType(MyEventsView), findsOneWidget);
    expect(find.byKey(_k('EVT-04.event.e01')), findsOneWidget);
    await _tap(tester, _k('EVT-04.leave.e01'));
    await _tap(tester, _k('DLG-14.confirm'));
    expect(
      _rsvps().rsvps[RsvpModelFixtures.e01Mehmet.id]?.status,
      RsvpStatus.cancelled,
    );
    expect(find.byKey(_k('EVT-04.event.e01')), findsNothing);
    expect(_toast(ToastId.tst42), findsOneWidget);
    await tester.pump(GuMotion.toastUndo);
    await tester.pumpAndSettle();

    // Geçmiş: bitmiş e18 (yoklaması alınmış; "Vazgeç" yok).
    await _tap(tester, _k('EVT-04.tab.past'));
    expect(find.byKey(_k('EVT-04.event.e18')), findsOneWidget);
    expect(find.byKey(_k('EVT-04.leave.e18')), findsNothing);
  });
}
