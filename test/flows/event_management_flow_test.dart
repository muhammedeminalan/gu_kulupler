// T-34 · Uçtan uca etkinlik yönetimi akışı: gerçek `GuApp` (rota ağacı,
// guard `V` / `M`, oturum, kabuk, `AppFeedbackService` — SHT-23 / SHT-28 /
// SHT-29 / SHT-30, DLG-22 / DLG-31 ve toast'lar gerçekten çizilir) + sahte
// servisler. Veri `c03` demo kaydıdır (`seedManage`; e03 yayında, 30 kayıtlı).
//
//   başkan (`u_burak`): CLB-03 → MGT-01 "Etkinlik oluştur" (W-38) → MGT-05 →
//   başlık → SHT-28 başlangıç günü → SHT-29 bitiş saati < başlangıç → hata →
//   düzelt → SHT-30 mekân → DLG-22 ("{n}" = `estimateEventNew`) → TST-30 →
//   MGT-04 yayında → "⋮" → kopyala (+7 gün, taslak, kapaksız) → MGT-05
//   (kopya) → kapat → "Taslaklar" → "⋮" → sil (DLG-31) → TST-45 → Geri al;
//   e03 (kayıtlı) "⋮" → "Taslağa al" devre dışı (K-F); EVT-02 "Düzenle"
//   (W-27) → MGT-05 düzenleme.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/bootstrap/gu_app.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/management/view/event_form_view.dart';
import 'package:gu_kulupler/features/management/view/manage_events_view.dart';
import 'package:gu_kulupler/features/management/view/widget/place_picker_sheet.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/date_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/event_menu_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/time_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/dialogs/publish_event_dialog.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/navigation/app_router.dart';
import 'package:gu_kulupler/product/navigation/navigator_keys.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../fakes/fake_app_preferences_store.dart';
import '../fakes/fake_auth_repository.dart';
import '../fakes/fake_event_repository.dart';
import '../fakes/fake_management_repository.dart';
import '../fakes/fake_recipient_resolver.dart';
import '../fakes/fake_user_repository.dart';
import '../fakes/register_fakes.dart';
import '../features/management/manage_test_support.dart';
import '../fixtures/event_model_fixtures.dart';
import '../fixtures/user_model_fixtures.dart';
import '../helpers/test_asset_bundle.dart';

const String _events = '/clubs/$kManageClubId/manage/events';

Key _k(String id) => GuKey.action(id);

FakeEventRepository _repo() =>
    GetIt.I<EventRepository>() as FakeEventRepository;

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
  seedManage();
  (GetIt.I<RecipientResolver>() as FakeRecipientResolver).eventNewIds = [
    for (var i = 0; i < 37; i++) 'u9$i',
  ];
  const uid = kManageUid;
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
  _router(tester).go('/clubs/$kManageClubId');
  await tester.pumpAndSettle();
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(GuApp)));

GoRouter _router(WidgetTester tester) =>
    _container(tester).read(appRouterProvider);

String _location(WidgetTester tester) =>
    _router(tester).routerDelegate.currentConfiguration.uri.toString();

/// Uygulamanın etkin dili (cihaz yerel ayarı; test bağlamında `en`).
AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(EventFormView)));

Future<void> _tap(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// SHT-29 saat tekerleğinde [hour] satırına dokunur (görünür olmalı).
Future<void> _tapHour(WidgetTester tester, String hour) async {
  await tester.tap(
    find.descendant(
      of: find.byKey(TimePickerSheet.keyOf('hour')),
      matching: find.text(hour),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _toast(ToastId id) => find.byKey(ValueKey<ToastId>(id));

Future<void> _dismissToast(WidgetTester tester) async {
  await tester.pump(GuMotion.toastUndo);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_GB');
    await initializeDateFormatting('en_US');
  });

  testWidgets('başkan: MGT-01 → MGT-05 (SHT-28 / SHT-29, bitiş hatası) → '
      'DLG-22 → TST-30 → MGT-04 → kopya (+7 gün) → taslak sil → Geri al; '
      'K-F; EVT-02 "Düzenle" → MGT-05', (tester) async {
    await _launch(tester);

    // CLB-03 → MGT-01 → "Etkinlik oluştur" (W-38) → MGT-05.
    await _tap(tester, _k('CLB-03.openManage'));
    await _tap(tester, _k('MGT-01.quick.event'));
    expect(_location(tester), '$_events/new');
    expect(find.byType(EventFormView), findsOneWidget);
    final l10n = _l10n(tester);

    // 1. adım: başlık → Devam.
    await tester.enterText(find.byKey(_k('MGT-05.title')), 'Ilgaz Kayak Günü');
    await tester.pumpAndSettle();
    await _tap(tester, _k('MGT-05.next'));

    // 2. adım: SHT-28 başlangıç günü 21 Ekim (saat 18:00 korunur, bitiş
    // 20:00'ye kayar).
    await _tap(tester, _k('MGT-05.startDate'));
    expect(find.byType(DatePickerSheet), findsOneWidget);
    await _tap(tester, DatePickerSheet.dayKeyOf(DateTime.utc(2026, 10, 21)));
    await _tap(tester, DatePickerSheet.keyOf('ok'));
    expect(find.byType(DatePickerSheet), findsNothing);

    // SHT-29 bitiş saati 17:00 (< başlangıç 18:00) → hata, Devam ilerlemez.
    await _tap(tester, _k('MGT-05.endTime'));
    await _tapHour(tester, '18');
    await _tapHour(tester, '17');
    await _tap(tester, TimePickerSheet.keyOf('ok'));
    await _tap(tester, _k('MGT-05.next'));
    expect(find.text(l10n.eventFormErrEndAfter), findsOneWidget);
    expect(find.byKey(_k('MGT-05.startDate')), findsOneWidget);

    // Düzelt: 19:00 → hata kalkar; mekân SHT-30 → Devam → 3. adım.
    await _tap(tester, _k('MGT-05.endTime'));
    await _tapHour(tester, '18');
    await _tapHour(tester, '19');
    await _tap(tester, TimePickerSheet.keyOf('ok'));
    expect(find.text(l10n.eventFormErrEndAfter), findsNothing);
    await _tap(tester, _k('MGT-05.place'));
    await _tap(tester, PlacePickerSheet.selectKeyOf('pl09'));
    await _tap(tester, _k('MGT-05.next'));

    // "Yayınla" → DLG-22 ("37 üyeye", CD-38) → onay → TST-30 → MGT-04.
    await _tap(tester, _k('MGT-05.publish'));
    expect(find.byType(PublishEventDialog), findsOneWidget);
    expect(find.text(l10n.dlg22Notify(37)), findsOneWidget);
    await _tap(tester, PublishEventDialog.confirmKey);
    expect(_toast(ToastId.tst30), findsOneWidget);
    final created = _repo().created.single;
    final published = _repo().events[created.id]!;
    expect(published.status, EventStatus.published);
    expect(published.title, 'Ilgaz Kayak Günü');
    expect(published.startsAt, DateTime.utc(2026, 10, 21, 15));
    expect(published.endsAt, DateTime.utc(2026, 10, 21, 16));
    final management =
        GetIt.I<ManagementRepository>() as FakeManagementRepository;
    expect(management.fanOuts.single.kind, NotificationType.eventNew);
    expect(_location(tester), _events);
    expect(find.byType(ManageEventsView), findsOneWidget);
    expect(find.byKey(_k('MGT-04.event.${created.id}')), findsOneWidget);
    await _dismissToast(tester);

    // "⋮" → Çoğalt → TST-13 → kopyanın düzenleme ekranı (+7 gün, taslak,
    // kapak kopyalanmaz).
    await _tap(tester, _k('MGT-04.menu.${created.id}'));
    expect(find.byType(EventMenuSheet), findsOneWidget);
    await _tap(tester, EventMenuSheet.keyOf(EventMenuAction.duplicate));
    expect(_toast(ToastId.tst13), findsOneWidget);
    final copy = _repo().events.values.singleWhere(
      (e) => e.title == 'Ilgaz Kayak Günü${l10n.eventCopySuffix}',
    );
    expect(copy.status, EventStatus.draft);
    expect(copy.startsAt, published.startsAt.add(Limits.eventCopyShift));
    expect(copy.endsAt, published.endsAt.add(Limits.eventCopyShift));
    expect(copy.coverPath, isNull);
    expect(_location(tester), '$_events/${copy.id}/edit');
    expect(find.byType(EventFormView), findsOneWidget);
    await _dismissToast(tester);

    // Kapat (değişiklik yok) → MGT-04 → "Taslaklar" → "⋮" → Sil → DLG-31 →
    // TST-45 → Geri al.
    await _tap(tester, _k('MGT-05.close'));
    expect(_location(tester), startsWith(_events));
    expect(find.byType(ManageEventsView), findsOneWidget);
    await _tap(tester, _k('MGT-04.tab.draft'));
    expect(find.byKey(_k('MGT-04.event.${copy.id}')), findsOneWidget);
    await _tap(tester, _k('MGT-04.menu.${copy.id}'));
    await _tap(tester, EventMenuSheet.keyOf(EventMenuAction.delete));
    await _tap(tester, FeedbackKeys.of('DLG-31', 'confirm'));
    expect(_toast(ToastId.tst45), findsOneWidget);
    expect(_repo().events[copy.id]!.isDeleted, isTrue);
    expect(find.byKey(_k('MGT-04.event.${copy.id}')), findsNothing);
    await _tap(tester, FeedbackKeys.of('TST-45', 'undo'));
    expect(_repo().events[copy.id]!.isDeleted, isFalse);
    expect(find.byKey(_k('MGT-04.event.${copy.id}')), findsOneWidget);
    await _dismissToast(tester);

    // K-F: e03 (30 kayıtlı) → "Taslağa al" devre dışı + nedeni.
    final e03 = EventModelFixtures.e03;
    expect(e03.goingCount, greaterThan(0));
    await _tap(tester, _k('MGT-04.tab.published'));
    await _tap(tester, _k('MGT-04.menu.${e03.id}'));
    final unpublish = tester.widget<GuTile>(
      find.byKey(EventMenuSheet.keyOf(EventMenuAction.unpublish)),
    );
    expect(unpublish.disabled, isTrue);
    expect(find.text(l10n.sht23UnpublishBlocked), findsOneWidget);
    await _tap(tester, _k('SHT-23.close'));
    expect(_repo().events[e03.id]!.status, EventStatus.published);

    // Satır → EVT-02 → "Düzenle" (W-27) → MGT-05 düzenleme.
    await _tap(tester, _k('MGT-04.event.${e03.id}'));
    expect(_location(tester), '/events/${e03.id}');
    await _tap(tester, _k('EVT-02.edit'));
    expect(_location(tester), '$_events/${e03.id}/edit');
    final form = tester.widget<EventFormView>(find.byType(EventFormView));
    expect(form.isEdit, isTrue);
    expect(find.text(e03.title), findsWidgets);
  });
}
