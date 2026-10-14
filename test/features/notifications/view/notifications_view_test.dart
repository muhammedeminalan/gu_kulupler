// NTF-01 · Bildirimler — içerik (başlık, izin bandı, çipler, gün grupları,
// satır metinleri / ikon / okunmamış noktası), aksiyon envanteri, durumlar
// (yükleniyor, hata, boş), aksiyon sonuçları (tümünü okundu → TST-18,
// ayarlar → NTF-02, izin "Aç" → DLG-03, bant kapat, filtre, satır → okundu,
// kaydır-sil → TST-16, uzun basma menüsü), sekme rozeti "9+", cihaz matrisi,
// açık + koyu golden. Referans: design/reference-shots/screens/NTF-01__*,
// states/NTF-01__*, design/prototype/app/screens-events.js:98–106,
// cards.js:139–160.
//
// Durum kipi: ViewModel durumu gerçek ViewModel'in demo veriyle ürettiği
// durumdur (`loadedNotificationsState`); yazımlar sahte depolara gider.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/notifications/provider/notifications_state.dart';
import 'package:gu_kulupler/features/notifications/provider/notifications_view_model.dart';
import 'package:gu_kulupler/features/notifications/view/notifications_view.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/notification_navigator.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';
import 'package:gu_kulupler/product/widget/notification/notification_row.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_session_states.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/fake_app_clock.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';
import '../notifications_test_support.dart';

Key _k(String action) => GuKey.action('NTF-01.$action');

/// Envanterdeki tüm satırların çizildiği yükseklik.
const Size _tall = Size(390, 2400);

late NotificationsState _loaded;

List<Override> _overrides([NotificationsState? state]) => [
  sessionViewModelProvider.overrideWithBuild(
    (ref, notifier) => FakeSessionStates.active,
  ),
  notificationsViewModelProvider.overrideWithBuild(
    (ref, notifier) => state ?? _loaded,
  ),
  appClockProvider.overrideWithValue(FakeAppClock(kNtfNowUtc)),
  notificationNavigatorProvider.overrideWithValue(
    NotificationNavigator(
      router: GoRouter(
        routes: [GoRoute(path: '/', builder: (_, _) => _stub)],
      ),
      userId: kNtfUid,
      isSuperAdmin: false,
    ),
  ),
];

const Widget _stub = SizedBox.shrink();

Future<void> _pump(
  WidgetTester tester, {
  NotificationsState? state,
  Size size = const Size(390, 844),
  Locale locale = const Locale('tr'),
}) async {
  await tester.pumpApp(
    const NotificationsView(),
    locale: locale,
    size: size,
    overrides: _overrides(state),
  );
  // Yazımlar için sahte depolar (pumpApp GetIt'i yeniden kurdu).
  seedNotifications();
  await tester.pump();
}

NotificationsState _stateOf(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(NotificationsView)),
).read(notificationsViewModelProvider);

FakeFeedbackService get _feedback =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_GB');
  });

  setUp(() async {
    _loaded = await loadedNotificationsState();
  });

  group('NTF-01 · Bildirimler · içerik', () {
    testWidgets('başlık, izin bandı, çipler, gün grupları, satır metinleri ve '
        'okunmamış noktası', (tester) async {
      await _pump(tester, size: _tall);
      final l10n = tester.l10n;
      expect(find.text(l10n.navNotifications), findsOneWidget);
      expect(find.text(l10n.notifOffBanner), findsOneWidget);
      for (final label in [
        l10n.commonAll,
        l10n.notifUnread,
        l10n.navClubs,
        l10n.navEvents,
        l10n.notifSystem,
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      for (final head in ['BUGÜN', 'DÜN', 'BU HAFTA', 'DAHA ESKİ']) {
        expect(find.text(head), findsOneWidget);
      }
      expect(
        find.text(
          l10n.notifTypeEventReminderTitle('Yapay Zekâya Giriş Atölyesi'),
        ),
        findsOneWidget,
      );
      expect(
        find.text(l10n.notifTypeEventReminderBody('18:00')),
        findsOneWidget,
      );
      expect(find.text(l10n.timeHoursAgo(2)), findsOneWidget);
      expect(find.text('GÜ Kulüpler’e hoş geldin'), findsOneWidget);
      expect(find.byType(NotificationRow), findsNWidgets(kNtfIds.length));
      // Okunmamış noktası satırın birleşik etiketine katılır.
      expect(
        find.descendant(
          of: find.byType(NotificationRow),
          matching: find.bySemanticsLabel(RegExp(l10n.notifUnread)),
        ),
        findsNWidgets(kNtfUnread.length),
      );
    });
  });

  group('NTF-01 · Bildirimler · aksiyon envanteri', () {
    testWidgets('envanterdeki anahtarlar birebir', (tester) async {
      await _pump(tester, size: _tall);
      expectActionInventory(tester, 'NTF-01');
    });
  });

  group('NTF-01 · Bildirimler · durumlar', () {
    testWidgets('yükleniyor → iskelet; hata → "Yeniden dene"; boş → '
        'illüstrasyon', (tester) async {
      await _pump(
        tester,
        state: NotificationsState(
          sessionStartedAt: kNtfNowUtc,
          isFetching: true,
        ),
      );
      expect(find.byType(GuSkeletonList), findsOneWidget);

      await _pump(
        tester,
        state: NotificationsState(sessionStartedAt: kNtfNowUtc, isError: true),
      );
      expect(find.byKey(_k('retry')), findsOneWidget);

      await _pump(
        tester,
        state: NotificationsState(sessionStartedAt: kNtfNowUtc),
      );
      final l10n = tester.l10n;
      expect(find.text(l10n.notifEmptyTitle), findsOneWidget);
      expect(find.text(l10n.notifEmptyDesc), findsOneWidget);
    });
  });

  group('NTF-01 · Bildirimler · aksiyonlar', () {
    testWidgets('tümünü okundu → TST-18, noktalar kalkar', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(_k('markAllRead')));
      await tester.pumpAndSettle();
      expect(_feedback.toasts, [ToastId.tst18]);
      expect(_stateOf(tester).unreadCount, 0);
    });

    testWidgets('izin "Aç" → DLG-03; kapat → bant kalkar', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(_k('enable')));
      await tester.pumpAndSettle();
      expect(_feedback.dialogs, [DialogId.dlg03]);
      await tester.tap(find.byKey(_k('dismissBanner')));
      await tester.pumpAndSettle();
      expect(find.byKey(_k('enable')), findsNothing);
    });

    testWidgets('filtre "Okunmamış" → yalnız okunmamış satırlar', (
      tester,
    ) async {
      await _pump(tester, size: _tall);
      await tester.tap(find.byKey(_k('filter.unread')));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationRow), findsNWidgets(kNtfUnread.length));
    });

    testWidgets('satıra dokunma → okundu', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(_k('item.n009')));
      await tester.pumpAndSettle();
      expect(
        _stateOf(tester).raw.firstWhere((n) => n.id == 'n009').read,
        isTrue,
      );
    });

    testWidgets('sola kaydır → soft delete + TST-16; sağa → okundu', (
      tester,
    ) async {
      await _pump(tester);
      await tester.drag(find.byKey(_k('swipe.n009')), const Offset(-160, 0));
      await tester.pumpAndSettle();
      expect(_feedback.toasts, [ToastId.tst16]);
      expect(find.byKey(_k('item.n009')), findsNothing);

      await tester.drag(find.byKey(_k('swipe.n005')), const Offset(160, 0));
      await tester.pumpAndSettle();
      expect(ntfInbox.notifications['n005']!.read, isTrue);
    });

    testWidgets('uzun basma → satır menüsü (okundu, sil, türü kapat)', (
      tester,
    ) async {
      await _pump(tester);
      await tester.longPress(find.byKey(_k('item.n009')));
      await tester.pumpAndSettle();
      expect(_feedback.menus, [null]);
      expect(
        [for (final item in _feedback.lastMenuItems) item.key],
        [_k('menu.n009.read'), _k('menu.n009.delete'), _k('menu.n009.mute')],
      );
    });

    testWidgets('ayarlar → NTF-02', (tester) async {
      GoRouter? created;
      await tester.pumpAppRouter(
        routerOf: (_) => created ??= GoRouter(
          initialLocation: '/notifications',
          routes: [
            GoRoute(
              path: '/notifications',
              builder: (_, _) => const NotificationsView(),
              routes: [
                GoRoute(
                  path: NotificationPrefsRoute.segment,
                  builder: (_, _) => const Text('prefs'),
                ),
              ],
            ),
          ],
        ),
        overrides: _overrides(),
      );
      addTearDown(created!.dispose);
      await tester.pump();
      await tester.tap(find.byKey(_k('settings')));
      await tester.pumpAndSettle();
      expect(
        created!.routerDelegate.currentConfiguration.uri.path,
        const NotificationPrefsRoute().location,
      );
    });

    testWidgets('sekme rozeti: 10 okunmamış → "9+"', (tester) async {
      await tester.pumpApp(
        const NotificationsView(),
        wrapInShell: true,
        shellTab: GuTab.notifications,
        overrides: _overrides(
          NotificationsState(sessionStartedAt: kNtfNowUtc, unreadCount: 10),
        ),
      );
      await tester.pump();
      expect(find.text(tester.l10n.badgeOverflow), findsOneWidget);
    });
  });

  group('NTF-01 · Bildirimler · cihaz matrisi', () {
    Widget view(BuildContext context) => const NotificationsView();

    testWidgets('dolu (güvenli alan); yükleniyor, boş, hata', (tester) async {
      await DeviceMatrix.run(
        tester,
        view,
        overrides: _overrides(),
        safeAreas: true,
      );
      for (final state in [
        NotificationsState(sessionStartedAt: kNtfNowUtc, isFetching: true),
        NotificationsState(sessionStartedAt: kNtfNowUtc),
        NotificationsState(sessionStartedAt: kNtfNowUtc, isError: true),
      ]) {
        await DeviceMatrix.run(tester, view, overrides: _overrides(state));
      }
    });
  });

  group('NTF-01 · Bildirimler · golden', () {
    testWidgets('varsayılan (açık + koyu)', (tester) async {
      await goldenForThemes(
        tester,
        'NTF-01',
        const NotificationsView(),
        overrides: _overrides(),
      );
    });
  });
}
