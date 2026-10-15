// ADM-01 · Admin genel bakış — içerik (tasarım yakalaması: u_admin; KPI
// 13 / 226 (+18 yeni) / 1 / 5, en aktif beş kulüp c03 · c10 · c01 · c11 ·
// c02), durumlar (yükleniyor, hata), aksiyon envanteri (31 anahtar, kabuk
// dahil), temel aksiyon sonuçları (kulüp satırı → CLB-03, dönem çipi,
// "Yeniden dene"), cihaz matrisi, açık + koyu golden.
// Referans: design/reference-shots/screens/ADM-01__*.webp,
// design/prototype/app/screens-admin.js:11–27.
//
// İki kip (MGT-01 testleriyle aynı düzen):
// * **Durum kipi**: ekran `pumpApp` ile çizilir, ViewModel durumu ezilir.
// * **Akış kipi**: gerçek ViewModel, sahte depolar ve yer tutucu rotalar.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/admin/provider/admin_state.dart';
import 'package:gu_kulupler/features/admin/provider/admin_view_model.dart';
import 'package:gu_kulupler/features/admin/view/admin_view.dart';
import 'package:gu_kulupler/features/admin/view/widget/admin_segment_bar.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';
import '../admin_test_support.dart';

final Key _retry = GuKey.action('ADM-01.retry');

/// Tüm bölümler kurulsun diye uzun yüzey.
const Size _tall = Size(390, 2000);

const Widget _view = AdminView();

/// Durum kipi: oturum + ViewModel durumu ezilir.
List<Override> _overrides({AdminState? state}) => [
  sessionViewModelProvider.overrideWithBuild((ref, notifier) => kAdminSession),
  adminViewModelProvider.overrideWithBuild(
    (ref, notifier) => state ?? loadedAdminState(),
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  AdminState? state,
  Locale locale = const Locale('tr'),
  Size size = _tall,
  bool wrapInShell = false,
}) async {
  await tester.pumpApp(
    _view,
    locale: locale,
    size: size,
    wrapInShell: wrapInShell,
    shellTab: GuTab.admin,
    overrides: _overrides(state: state),
  );
  await tester.pump();
}

/// Akış kipi: gerçek ViewModel + yer tutucu rotalar.
Future<GoRouter> _pumpRoute(WidgetTester tester) async {
  GoRouter? created;
  Widget stub(GoRouterState state) => _Stub(state.uri.toString());
  await tester.pumpAppRouter(
    size: _tall,
    routerOf: (_) => created ??= GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(path: '/start', builder: (_, s) => stub(s)),
        GoRoute(path: '/admin', builder: (_, _) => _view),
        GoRoute(path: '/admin/clubs', builder: (_, s) => stub(s)),
        GoRoute(path: '/clubs/:clubId', builder: (_, s) => stub(s)),
      ],
    ),
    overrides: [
      sessionViewModelProvider.overrideWithBuild(
        (ref, notifier) => kAdminSession,
      ),
    ],
  );
  final router = created!;
  addTearDown(router.dispose);
  seedAdmin();
  router.go('/admin');
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

Future<void> _tapKey(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('ADM-01 · Admin genel bakış · içerik', () {
    for (final locale in const [Locale('tr'), Locale('en')]) {
      testWidgets('dolu (${locale.languageCode}): başlık + rozet, bölmeli '
          'geçiş, dönem çipleri, KPI, grafik, en aktif kulüpler, katılım, '
          'bekleyen işler', (tester) async {
        await _pump(tester, locale: locale);
        final l10n = tester.l10n;

        final bar = tester.widget<GuAppBar>(find.byType(GuAppBar));
        expect(bar.title, l10n.navAdmin);
        expect(bar.large, isTrue);
        expect(find.byType(GuRoleBadge), findsOneWidget);
        expect(
          tester.widget<AdminSegmentBar>(find.byType(AdminSegmentBar)).current,
          AdminSegmentBar.overview,
        );

        final chips = tester.widgetList<GuChip>(find.byType(GuChip)).toList();
        expect(chips.map((c) => c.label), [
          l10n.adminRange7,
          l10n.adminRange30,
          l10n.adminRangeTerm,
        ]);
        expect(chips.map((c) => c.selected), [false, true, false]);

        final kpis = tester.widgetList<GuKpi>(find.byType(GuKpi)).toList();
        expect(
          [for (final k in kpis) (k.label, k.value, k.accent)],
          [
            (l10n.adminKpiActiveClubs, '13', false),
            (l10n.adminKpiUsers, '226', false),
            (l10n.adminKpiSuspended, '1', false),
            (l10n.adminKpiOpenReports, '5', true),
          ],
        );
        expect(kpis[1].subtitle, l10n.adminKpiNewUsers(18));

        expect(find.text(l10n.adminWau), findsOneWidget);
        expect(
          tester.widget<GuMiniLineChart>(find.byType(GuMiniLineChart)).data,
          [for (final v in kDesignChart) v.toDouble()],
        );

        expect(find.text(l10n.adminTopClubs), findsOneWidget);
        for (final id in kTopClubIds) {
          final club = designClub(id);
          expect(find.text(club.name), findsOneWidget);
          expect(find.text('${club.memberCount}'), findsOneWidget);
        }

        expect(find.text(l10n.adminAttendanceRate), findsOneWidget);
        expect(
          tester.widget<GuDonut>(find.byType(GuDonut)).value,
          closeTo(61.67, 0.01),
        );
        expect(
          find.text(l10n.adminAttendanceDesc('6', '120', '74')),
          findsOneWidget,
        );

        expect(find.text(l10n.adminPendingTasks), findsOneWidget);
        expect(find.text(l10n.adminTaskReports(5)), findsOneWidget);
        expect(find.text(l10n.adminTaskSuspended(1)), findsOneWidget);
      });
    }

    testWidgets('yükleniyor → iskelet; hata → "Yeniden dene"', (tester) async {
      await _pump(tester, state: const AdminState(isFetching: true));
      expect(find.byType(GuSkeletonList), findsOneWidget);
      expect(find.byType(GuKpi), findsNothing);
      expect(find.byType(AdminSegmentBar), findsOneWidget);
      await _pump(tester, state: const AdminState(isError: true));
      expect(find.byKey(_retry), findsOneWidget);
      expect(find.byType(GuKpi), findsNothing);
    });

    testWidgets('etkin kulüp yok → kartta "Kulüp yok"', (tester) async {
      await _pump(tester, state: loadedAdminState(topClubIds: const []));
      expect(find.text(tester.l10n.adminClubsEmpty), findsOneWidget);
    });
  });

  group('ADM-01 · Admin genel bakış · envanter', () {
    testWidgets('31 anahtar (süper admin; kabuk NAV.tab.* dahil)', (
      tester,
    ) async {
      await _pump(tester, wrapInShell: true);
      expectActionInventory(
        tester,
        'ADM-01',
        role: 'admin',
        includeShell: true,
      );
    });
  });

  group('ADM-01 · Admin genel bakış · aksiyonlar', () {
    testWidgets('en aktif kulüp satırı → CLB-03; dönem çipi seçilir', (
      tester,
    ) async {
      final router = await _pumpRoute(tester);
      await _tapKey(tester, GuKey.action('ADM-01.range.7'));
      final chips = tester.widgetList<GuChip>(find.byType(GuChip)).toList();
      expect(chips.map((c) => c.selected), [true, false, false]);

      await _tapKey(tester, GuKey.action('ADM-01.topClub.c03'));
      expect(_location(router), '/clubs/c03');
    });

    testWidgets('"Aktif kulüp" → ADM-02; "Askıdaki kulüp" → ADM-02 askıda '
        'sekmesi (W-45)', (tester) async {
      final router = await _pumpRoute(tester);
      await _tapKey(tester, GuKey.action('ADM-01.kpi.clubs'));
      expect(_location(router), '/admin/clubs');

      router.go('/admin');
      await tester.pumpAndSettle();
      await _tapKey(tester, GuKey.action('ADM-01.task.suspended'));
      expect(_location(router), '/admin/clubs?tab=suspended');
    });

    testWidgets(
      '"Toplam kullanıcı" ve "Kullanıcılar" bölmesi → ADM-05 (W-47)',
      (
        tester,
      ) async {
        final router = await _pumpRoute(tester);
        await _tapKey(tester, GuKey.action('ADM-01.kpi.users'));
        expect(_location(router), '/admin/users');

        router.go('/admin');
        await tester.pumpAndSettle();
        await _tapKey(tester, GuKey.action('ADM-01.seg.ADM-05'));
        expect(_location(router), '/admin/users');
      },
    );

    testWidgets('hata → "Yeniden dene" yeniden okur', (tester) async {
      await _pump(tester, state: const AdminState(isError: true));
      await _tapKey(tester, _retry);
      expect(find.byKey(_retry), findsNothing);
    });
  });

  group('ADM-01 · Admin genel bakış · matris', () {
    testWidgets('dolu görünüm', (tester) async {
      await DeviceMatrix.run(tester, (_) => _view, overrides: _overrides());
    });
  });

  group('ADM-01 · Admin genel bakış · golden', () {
    testWidgets('varsayılan açık + koyu', (tester) async {
      await goldenForThemes(tester, 'ADM-01', _view, overrides: _overrides());
    });
  });
}
