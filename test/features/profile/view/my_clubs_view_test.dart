// PRF-03 · Kulüplerim — satır içeriği (amblem, ad, rol / durum rozeti +
// tarih, ⋮), sekmeler (`?tab=` açılış sekmesi, W-65), aksiyon envanteri,
// durumlar (yükleniyor, hata, boş — sekme başına), aksiyon sonuçları
// (CLB-03 / CLB-05 / CLB-01 gezinmesi, menü → DLG-07 → TST-40), K-05 (EN
// 320 × 1.3 / 1.6 taşma yok), cihaz matrisi, açık + koyu golden.
// Referans: design/reference-shots/screens/PRF-03__*.webp, states/PRF-03__*,
// design/prototype/app/screens-profile.js:40–49.
//
// * Durum kipi: ViewModel durumu ezilir (okuma yok).
// * Akış kipi: gerçek ViewModel + sahte depolar + yer tutucu rotalar.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/profile/provider/my_clubs_state.dart';
import 'package:gu_kulupler/features/profile/provider/my_clubs_view_model.dart';
import 'package:gu_kulupler/features/profile/view/my_clubs_view.dart';
import 'package:gu_kulupler/features/profile/view/widget/my_club_menu.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/navigation/my_clubs_tab.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';
import 'package:gu_kulupler/product/widget/club/my_club_row.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_membership_repository.dart';
import '../../../fixtures/club_model_fixtures.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/overflow_detector.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';
import '../my_clubs_test_support.dart';

Key _k(String action) => GuKey.action('PRF-03.$action');

/// Durum kipi: oturum + ViewModel durumu ezilir.
List<Override> _overrides([MyClubsState? state]) => [
  sessionViewModelProvider.overrideWithBuild(
    (ref, notifier) => myClubsSession(),
  ),
  myClubsViewModelProvider.overrideWithBuild(
    (ref, notifier) => state ?? loadedMyClubs(),
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  MyClubsState? state,
  Locale locale = const Locale('tr'),
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  await tester.pumpApp(
    const MyClubsView(),
    locale: locale,
    size: size,
    textScale: textScale,
    overrides: _overrides(state),
  );
  await tester.pump();
}

/// Akış kipi: gerçek ViewModel ve yer tutucu rotalar.
Future<GoRouter> _pumpRoute(
  WidgetTester tester, {
  String location = '/profile/clubs',
}) async {
  GoRouter? created;
  await tester.pumpAppRouter(
    routerOf: (_) => created ??= GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(path: '/start', builder: (_, _) => const _Stub('/start')),
        GoRoute(
          path: '/clubs',
          builder: (_, _) => const _Stub('/clubs'),
          routes: [
            GoRoute(
              path: ':clubId',
              builder: (_, state) => _Stub(state.uri.path),
              routes: [
                GoRoute(
                  path: 'application',
                  builder: (_, state) => _Stub(state.uri.path),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/profile',
          builder: (_, _) => const _Stub('/profile'),
          routes: [
            GoRoute(
              path: 'clubs',
              builder: (_, state) => MyClubsView(
                tab: switch (state.uri.queryParameters['tab']) {
                  final String name => MyClubsTab.values.asNameMap()[name],
                  null => null,
                },
              ),
            ),
          ],
        ),
      ],
    ),
    overrides: [
      sessionViewModelProvider.overrideWithBuild(
        (ref, notifier) => myClubsSession(),
      ),
    ],
  );
  final router = created!;
  addTearDown(router.dispose);
  seedMyClubs();
  router.go(location);
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

  group('PRF-03 · Kulüplerim · içerik', () {
    testWidgets('başlık, sekmeler, aktif satırlar: ad, "Üye" rozeti, tarih, '
        '⋮', (tester) async {
      await _pump(tester);
      final l10n = tester.l10n;
      expect(find.text(l10n.myclubsTitle), findsOneWidget);
      for (final label in [
        l10n.myclubsTabActive,
        l10n.myclubsTabPending,
        l10n.myclubsTabHistory,
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.byType(MyClubRow), findsNWidgets(2));
      // En yeni üstte: c07 (9 Ağustos 2026), c01 (21 Mayıs 2026).
      final rows = tester.widgetList<MyClubRow>(find.byType(MyClubRow));
      expect([for (final row in rows) row.club.id], ['c07', 'c01']);
      expect(find.text(ClubModelFixtures.byId('c07').name), findsOneWidget);
      expect(find.text('9 Ağustos 2026'), findsOneWidget);
      expect(find.text('21 Mayıs 2026'), findsOneWidget);
      expect(find.text(l10n.roleMember), findsNWidgets(2));
      expect(find.byKey(_k('menu.c07')), findsOneWidget);
    });

    testWidgets('bekleyen ve geçmiş sekmeleri durum rozeti çizer', (
      tester,
    ) async {
      await _pump(tester, state: loadedMyClubs(tab: MyClubsTab.pending));
      final l10n = tester.l10n;
      expect(find.text(l10n.statusPending), findsOneWidget);
      await _pump(tester, state: loadedMyClubs(tab: MyClubsTab.past));
      expect(find.text(l10n.statusRejected), findsOneWidget);
    });

    testWidgets('aksiyon envanteri', (tester) async {
      await _pump(tester);
      expectActionInventory(tester, 'PRF-03');
    });
  });

  group('PRF-03 · Kulüplerim · durumlar', () {
    testWidgets('yükleniyor → iskelet; hata → "Yeniden dene"; boş → sekme '
        'başlığı + "Etkinlikleri keşfet"', (tester) async {
      await _pump(tester, state: const MyClubsState(isFetching: true));
      final l10n = tester.l10n;
      expect(find.byType(GuSkeletonList), findsOneWidget);
      expect(find.byType(MyClubRow), findsNothing);

      await _pump(tester, state: const MyClubsState(isError: true));
      expect(find.byKey(_k('retry')), findsOneWidget);
      expect(find.text(l10n.sysErrorTitle), findsOneWidget);

      for (final (tab, title) in [
        (MyClubsTab.active, l10n.myclubsEmptyActive),
        (MyClubsTab.pending, l10n.myclubsEmptyPending),
        (MyClubsTab.past, l10n.myclubsEmptyHistory),
      ]) {
        await _pump(tester, state: MyClubsState(tab: tab));
        expect(find.text(title), findsOneWidget);
        expect(find.byKey(_k('discover')), findsOneWidget);
      }
    });
  });

  group('PRF-03 · Kulüplerim · aksiyonlar', () {
    testWidgets('satır → CLB-03; ?tab=pending açılış sekmesi; bekleyen satır '
        '→ CLB-05', (tester) async {
      var router = await _pumpRoute(tester);
      await tester.tap(find.byKey(_k('row.c07')));
      await tester.pumpAndSettle();
      expect(_location(router), '/clubs/c07');

      router = await _pumpRoute(tester, location: '/profile/clubs?tab=pending');
      expect(find.byKey(_k('row.c06')), findsOneWidget);
      expect(find.byKey(_k('row.c07')), findsNothing);
      await tester.tap(find.byKey(_k('row.c06')));
      await tester.pumpAndSettle();
      expect(_location(router), '/clubs/c06/application');
    });

    testWidgets('sekme → geçmiş; geri → PRF-01', (tester) async {
      final router = await _pumpRoute(tester);
      await tester.tap(find.byKey(_k('tab.history')));
      await tester.pumpAndSettle();
      expect(find.byKey(_k('row.c05')), findsOneWidget);
      await tester.tap(find.byKey(_k('back')));
      await tester.pumpAndSettle();
      expect(_location(router), '/profile');
    });

    testWidgets('⋮ → menü (Aç · Kulüpten ayrıl); İsteği iptal et → DLG-07 → '
        'satır "Geçmiş"e + TST-40', (tester) async {
      await _pumpRoute(tester);
      final feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
      await tester.tap(find.byKey(_k('menu.c07')));
      await tester.pumpAndSettle();
      expect(feedback.menus, [null]);
      expect(
        [for (final item in feedback.lastMenuItems) item.key],
        [
          _k('menu.c07.open'),
          _k('menu.c07.leave'),
        ],
      );

      await tester.tap(find.byKey(_k('tab.pending')));
      await tester.pumpAndSettle();
      feedback
        ..nextMenuResult = MyClubMenuAction.cancel
        ..dialogResults[DialogId.dlg07] = true;
      await tester.tap(find.byKey(_k('menu.c06')));
      await tester.pumpAndSettle();
      expect(feedback.dialogs, [DialogId.dlg07]);
      expect(feedback.toasts, [ToastId.tst40]);
      expect(find.byKey(_k('row.c06')), findsNothing);
      expect(find.byKey(_k('discover')), findsOneWidget);
    });

    testWidgets('çevrimdışı: liste kalır; iptal TST-24 verir, yazılmaz', (
      tester,
    ) async {
      await _pumpRoute(tester, location: '/profile/clubs?tab=pending');
      (GetIt.I<ConnectivityService>() as FakeConnectivityService).isOffline =
          true;
      final feedback = (GetIt.I<FeedbackService>() as FakeFeedbackService)
        ..nextMenuResult = MyClubMenuAction.cancel
        ..dialogResults[DialogId.dlg07] = true;
      await tester.tap(find.byKey(_k('menu.c06')));
      await tester.pumpAndSettle();
      expect(feedback.toasts, [ToastId.tst24]);
      expect(
        (GetIt.I<MembershipRepository>() as FakeMembershipRepository).callsTo(
          'cancelApplication',
        ),
        isEmpty,
      );
      expect(find.byKey(_k('row.c06')), findsOneWidget);
    });

    testWidgets('boşta "Etkinlikleri keşfet" → CLB-01', (tester) async {
      final router = await _pumpRoute(tester);
      await tester.tap(find.byKey(_k('tab.pending')));
      await tester.pumpAndSettle();
      (GetIt.I<FeedbackService>() as FakeFeedbackService)
        ..nextMenuResult = MyClubMenuAction.cancel
        ..dialogResults[DialogId.dlg07] = true;
      await tester.tap(find.byKey(_k('menu.c06')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_k('discover')));
      await tester.pumpAndSettle();
      expect(_location(router), '/clubs');
    });
  });

  group('PRF-03 · Kulüplerim · K-05 + cihaz matrisi', () {
    testWidgets('EN 320 × 1.3 / 1.6: sekmeler ve satırlar taşmaz', (
      tester,
    ) async {
      OverflowDetector.install();
      addTearDown(OverflowDetector.reset);
      for (final scale in const [1.3, 1.6]) {
        for (final tab in MyClubsTab.values) {
          OverflowDetector.reset();
          await _pump(
            tester,
            state: loadedMyClubs(tab: tab),
            locale: const Locale('en'),
            size: const Size(320, 640),
            textScale: scale,
          );
          OverflowDetector.assertNone('EN 320 × $scale · ${tab.name}');
          expect(tester.takeException(), isNull);
        }
      }
    });

    testWidgets('dolu (güvenli alan); bekleyen, geçmiş, boş, hata', (
      tester,
    ) async {
      Widget view(BuildContext context) => const MyClubsView();
      await DeviceMatrix.run(
        tester,
        view,
        overrides: _overrides(),
        safeAreas: true,
      );
      for (final state in [
        loadedMyClubs(tab: MyClubsTab.pending),
        loadedMyClubs(tab: MyClubsTab.past),
        const MyClubsState(),
        const MyClubsState(isError: true),
      ]) {
        await DeviceMatrix.run(tester, view, overrides: _overrides(state));
      }
    });
  });

  group('PRF-03 · Kulüplerim · golden', () {
    testWidgets('varsayılan (açık + koyu)', (tester) async {
      await goldenForThemes(
        tester,
        'PRF-03',
        const MyClubsView(),
        overrides: _overrides(),
      );
    });
  });
}
