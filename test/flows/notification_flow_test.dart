// T-26 · Uçtan uca bildirim akışı: gerçek `GuApp` (rota ağacı, yönlendirme,
// oturum katmanı, kabuk, `AppFeedbackService`) + sahte servisler. Oturum
// hazırdır (`u_mehmet`); gelen kutusu demo verinin dokuz bildirimi (4
// okunmamış; `c01` ve `c07` üyesi) + hedef gönderisi silinmiş, okunmuş bir duyuru (`n_gone`).
//
//   giriş → sekme rozeti "4" → Bildirimler (NTF-01) → duyuru `n005`'e dokun →
//   FED-02 (/clubs/c07/posts/p22) + okundu, rozet "3" → geri → "Tümünü okundu
//   say" (TST-18) → `n009`'u kaydırıp sil (TST-16) → Geri al → Ayarlar
//   (NTF-02) → sessiz saat aç → Başlangıç → SHT-29 23:00 → Tamam (tek yama)
//   → hatırlatma "1 gün önce" → hatırlatıcılar yeniden kuruldu → geri →
//   silinmiş hedefli bildirim → SYS-04
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/bootstrap/gu_app.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/feed/view/post_detail_view.dart';
import 'package:gu_kulupler/features/notifications/provider/notifications_view_model.dart';
import 'package:gu_kulupler/features/notifications/view/notification_prefs_view.dart';
import 'package:gu_kulupler/features/notifications/view/notifications_view.dart';
import 'package:gu_kulupler/features/system/view/not_found_view.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/time_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/app_router.dart';
import 'package:gu_kulupler/product/navigation/navigator_keys.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';
import 'package:gu_kulupler/product/service/local_reminder_service.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../fakes/fake_app_preferences_store.dart';
import '../fakes/fake_auth_repository.dart';
import '../fakes/fake_local_reminder_service.dart';
import '../fakes/fake_membership_repository.dart';
import '../fakes/fake_settings_repository.dart';
import '../fakes/register_fakes.dart';
import '../features/clubs/club_members_test_support.dart';
import '../features/notifications/notifications_test_support.dart';
import '../fixtures/membership_model_fixtures.dart';
import '../helpers/test_asset_bundle.dart';

Key _k(String id) => GuKey.action(id);

/// Hedef gönderisi (`p_gone`) hiç olmayan, okunmuş, bugünkü duyuru.
final NotificationModel _gone = ntf('n004').copyWith(
  id: 'n_gone',
  refs: const NotificationRefsModel(clubId: 'c01', postId: 'p_gone'),
  createdAt: kNtfNowUtc.subtract(const Duration(minutes: 30)),
);

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
  // Duyuru hedefi `c07` gönderisi üyelere açıktır (guard `üye`).
  (GetIt.I<MembershipRepository>() as FakeMembershipRepository).put(
    MembershipModelFixtures.byId('c07_u_mehmet'),
  );
  seedNotifications(notifications: [...kNtfIds.map(ntf), _gone]);
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

int _unread(WidgetTester tester) =>
    _container(tester).read(notificationsViewModelProvider).unreadCount;

Finder _badge(String label) => find.descendant(
  of: find.byKey(_k('NAV.tab.notifications')),
  matching: find.text(label),
);

Future<void> _tap(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
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

  testWidgets('rozet → NTF-01 → FED-02 → tümü okundu → sil + geri al → '
      'NTF-02 sessiz saat + SHT-29 → hatırlatıcılar → SYS-04', (tester) async {
    await _launch(tester);
    final reminders =
        GetIt.I<LocalReminderService>() as FakeLocalReminderService;
    final settings = GetIt.I<SettingsRepository>() as FakeSettingsRepository;

    // Sekme çubuğunda okunmamış rozeti (tercih süzgecinden geçmiş 4).
    expect(_unread(tester), kNtfUnread.length);
    expect(_badge('4'), findsOneWidget);

    // Bildirimler → NTF-01.
    await _tap(tester, _k('NAV.tab.notifications'));
    expect(_location(tester), AppPaths.notifications);
    expect(find.byType(NotificationsView), findsOneWidget);

    // Duyuruya dokun → FED-02 (Kulüpler sekmesi; gönderiler sekmesi yığında),
    // sunucuda okundu, rozet azalır.
    await _tap(tester, _k('NTF-01.item.n005'));
    expect(_location(tester), '${AppPaths.clubs}/c07/posts/p22?tab=posts');
    expect(find.byType(PostDetailView), findsOneWidget);
    expect(ntfInbox.notifications['n005']!.read, isTrue);
    expect(_unread(tester), kNtfUnread.length - 1);

    // Geri → CLB-03 → CLB-01 → Bildirimler (rozet "3").
    await _tap(tester, _k('FED-02.back'));
    expect(_location(tester), startsWith('${AppPaths.clubs}/c07'));
    await _tap(tester, _k('CLB-03.back'));
    expect(_badge('3'), findsOneWidget);
    await _tap(tester, _k('NAV.tab.notifications'));
    expect(find.byType(NotificationsView), findsOneWidget);

    // Tümünü okundu say → TST-18, rozet yok.
    await _tap(tester, _k('NTF-01.markAllRead'));
    expect(_toast(ToastId.tst18), findsOneWidget);
    expect(_unread(tester), 0);
    expect(
      [for (final id in kNtfUnread) ntfInbox.notifications[id]!.read],
      everyElement(isTrue),
    );
    await _dismissToast(tester);

    // Kaydırıp sil → TST-16 → Geri al → satır geri gelir.
    // Etkin sekmeye yeniden dokunma → liste başa kayar (bugünkü satırlar).
    await _tap(tester, _k('NAV.tab.notifications'));
    final swipe = find.byKey(_k('NTF-01.swipe.n009'));
    await tester.ensureVisible(swipe);
    await tester.pumpAndSettle();
    await tester.drag(swipe, const Offset(-160, 0));
    await tester.pumpAndSettle();
    expect(ntfInbox.notifications['n009']!.isDeleted, isTrue);
    expect(find.byKey(_k('NTF-01.item.n009')), findsNothing);
    expect(_toast(ToastId.tst16), findsOneWidget);
    await _tap(tester, _k('TST-16.undo'));
    expect(ntfInbox.notifications['n009']!.isDeleted, isFalse);
    expect(find.byKey(_k('NTF-01.item.n009')), findsOneWidget);

    // Ayarlar → NTF-02 → sessiz saat aç → Başlangıç → SHT-29 23:00 → Tamam.
    await _tap(tester, _k('NTF-01.settings'));
    expect(
      _location(tester),
      '${AppPaths.notifications}/${NotificationPrefsRoute.segment}',
    );
    expect(find.byType(NotificationPrefsView), findsOneWidget);
    await _tap(tester, _k('NTF-02.quiet'));
    expect(settings.settings[kNtfUid]!.quiet, isTrue);
    expect(_toast(ToastId.tst19), findsOneWidget);
    await _dismissToast(tester);
    await _tap(tester, _k('NTF-02.quietFrom'));
    expect(find.byType(TimePickerSheet), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byKey(TimePickerSheet.keyOf('hour')),
        matching: find.text('23'),
      ),
    );
    await tester.pumpAndSettle();
    await _tap(tester, TimePickerSheet.keyOf('ok'));
    expect(find.byType(TimePickerSheet), findsNothing);
    expect(settings.settings[kNtfUid]!.quietFrom, '23:00');
    expect(settings.patches.last.patch.quietFrom, '23:00');
    expect(settings.patches.last.patch.quietTo, isNotNull);

    // Hatırlatma "1 gün önce" → kayıt → hatırlatıcılar yeniden kurulur.
    final before = reminders.rescheduleCalls;
    await _tap(tester, _k('NTF-02.reminderTime.1d'));
    expect(settings.settings[kNtfUid]!.reminderTime, ReminderOption.oneDay);
    expect(reminders.rescheduleCalls, greaterThan(before));
    await _dismissToast(tester);

    // Geri → NTF-01 → silinmiş hedefli bildirim → SYS-04.
    await _tap(tester, _k('NTF-02.back'));
    expect(_location(tester), AppPaths.notifications);
    await _tap(tester, _k('NTF-01.item.n_gone'));
    expect(_location(tester), AppPaths.notFound);
    expect(find.byType(NotFoundView), findsOneWidget);
  });
}
