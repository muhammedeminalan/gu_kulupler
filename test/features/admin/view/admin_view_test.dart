// ADM-01 · Admin genel bakış — içerik (tasarım yakalaması: u_admin; KPI
// 13 / 226 (+18 yeni) / 1 / 5, en aktif beş kulüp c03 · c10 · c01 · c11 ·
// c02), durumlar (yükleniyor, hata), aksiyon envanteri (31 anahtar, kabuk
// dahil), temel aksiyon sonuçları (kulüp satırı → CLB-03, dönem çipi,
// "Yeniden dene"), cihaz matrisi, açık + koyu golden (kabukta, alt çubuk
// görünür).
// Admin kökü (kullanıcı kararı 2026-10-16): ADM-01 / 02 / 04 / 05 tek sayfa —
// bölme değişimi sayfa değiştirmez (alt çubuk görünür, geri oku yok, kısa
// solma), bölmeler hâlini korur, göstergeler bölme açar, rota sorgusu
// komuttur.
// Referans: design/reference-shots/screens/ADM-01__*.webp,
// design/prototype/app/screens-admin.js:11–27.
//
// İki kip (MGT-01 testleriyle aynı düzen):
// * **Durum kipi**: ekran `pumpApp` ile çizilir, ViewModel durumu ezilir.
// * **Akış kipi**: gerçek ViewModel, sahte depolar ve yer tutucu rotalar.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/admin/provider/admin_clubs_view_model.dart';
import 'package:gu_kulupler/features/admin/provider/admin_reports_view_model.dart';
import 'package:gu_kulupler/features/admin/provider/admin_state.dart';
import 'package:gu_kulupler/features/admin/provider/admin_users_view_model.dart';
import 'package:gu_kulupler/features/admin/provider/admin_view_model.dart';
import 'package:gu_kulupler/features/admin/view/admin_clubs_view.dart';
import 'package:gu_kulupler/features/admin/view/admin_overview_view.dart';
import 'package:gu_kulupler/features/admin/view/admin_reports_view.dart';
import 'package:gu_kulupler/features/admin/view/admin_users_view.dart';
import 'package:gu_kulupler/features/admin/view/admin_view.dart';
import 'package:gu_kulupler/features/admin/view/widget/admin_segment_bar.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fakes/fake_admin_repository.dart';
import '../../../fakes/fake_club_repository.dart';
import '../../../helpers/a11y_guidelines.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';
import '../admin_clubs_test_support.dart';
import '../admin_reports_test_support.dart';
import '../admin_test_support.dart';
import '../admin_users_test_support.dart';

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
        GoRoute(
          path: '/admin',
          builder: (_, s) => adminViewOf(s),
          routes: [GoRoute(path: 'clubs/new', builder: (_, s) => stub(s))],
        ),
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

/// Seçili bölme (`AdminSegmentBar.current`).
String _segment(WidgetTester tester) =>
    tester.widget<AdminSegmentBar>(find.byType(AdminSegmentBar)).current;

/// Bölme kabının (`GuFadeIndexedStack`) solma opaklığı.
double _stackOpacity(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find
          .descendant(
            of: find.byType(GuFadeIndexedStack).last,
            matching: find.byType(FadeTransition),
          )
          .first,
    )
    .opacity
    .value;

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
        await expectA11yGuidelines(tester);
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

    testWidgets('T-43 · en aktif kulüp satırları en az 44 dp (D-22, '
        'kullanıcı kararı)', (tester) async {
      await _pump(tester);
      final rows = find.byWidgetPredicate(
        (widget) =>
            widget is GuTapTarget &&
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'ADM-01.topClub.',
            ),
      );
      expect(rows, findsWidgets);
      for (var i = 0; i < rows.evaluate().length; i++) {
        expect(
          tester.getSize(rows.at(i)).height,
          greaterThanOrEqualTo(GuSizes.tapTargetIos),
        );
      }
    });

    testWidgets('"Aktif kulüp" → Kulüpler bölmesi; "Askıdaki kulüp" → '
        'Kulüpler › Askıda (W-45; aynı sayfa, adres eşitlenir)', (
      tester,
    ) async {
      final router = await _pumpRoute(tester);
      await _tapKey(tester, GuKey.action('ADM-01.kpi.clubs'));
      expect(_location(router), '/admin?tab=clubs');
      expect(find.byType(AdminClubsView), findsOneWidget);
      expect(find.byType(AdminOverviewView), findsNothing);
      expect(_segment(tester), AdminSegmentBar.clubs);

      await _tapKey(tester, GuKey.action('ADM-02.seg.ADM-01'));
      expect(_location(router), '/admin');
      expect(find.byType(AdminOverviewView), findsOneWidget);
      await _tapKey(tester, GuKey.action('ADM-01.task.suspended'));
      expect(_location(router), '/admin?tab=clubs&clubsTab=suspended');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AdminView)),
      );
      expect(
        container.read(adminClubsViewModelProvider).tab,
        AdminClubsTab.suspended,
      );
    });

    testWidgets(
      '"Toplam kullanıcı" ve "Kullanıcılar" bölmesi → ADM-05 (W-47); '
      '"Açık şikayet" → ADM-04 (W-46)',
      (tester) async {
        final router = await _pumpRoute(tester);
        await _tapKey(tester, GuKey.action('ADM-01.kpi.users'));
        expect(_location(router), '/admin?tab=users');
        expect(find.byType(AdminUsersView), findsOneWidget);

        await _tapKey(tester, GuKey.action('ADM-05.seg.ADM-01'));
        await _tapKey(tester, GuKey.action('ADM-01.seg.ADM-05'));
        expect(_location(router), '/admin?tab=users');
        expect(find.byType(AdminUsersView), findsOneWidget);

        await _tapKey(tester, GuKey.action('ADM-05.seg.ADM-01'));
        await _tapKey(tester, GuKey.action('ADM-01.kpi.reports'));
        expect(_location(router), '/admin?tab=reports');
        expect(find.byType(AdminReportsView), findsOneWidget);
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

  group('Admin kökü · tek sayfa (kullanıcı kararı 2026-10-16)', () {
    /// Dört bölmenin ViewModel'leri dolu durumla ezilir; kabukta çizilir.
    Future<void> pumpShell(WidgetTester tester) async {
      await tester.pumpApp(
        _view,
        wrapInShell: true,
        shellTab: GuTab.admin,
        overrides: [
          ..._overrides(),
          adminClubsViewModelProvider.overrideWithBuild(
            (ref, notifier) => loadedAdminClubsState(),
          ),
          adminReportsViewModelProvider.overrideWithBuild(
            (ref, notifier) => loadedAdminReportsState(),
          ),
          adminUsersViewModelProvider.overrideWithBuild(
            (ref, notifier) => loadedAdminUsersState(),
          ),
        ],
      );
      await tester.pumpAndSettle();
    }

    testWidgets('bölme değişimi: alt çubuk görünür, geri oku yok, sayfa '
        'aynı (tek AdminView), içerik kısa solmayla girer', (tester) async {
      await pumpShell(tester);
      final view = tester.element(find.byType(AdminView));
      for (final (key, type, current) in [
        ('ADM-01.seg.ADM-02', AdminClubsView, AdminSegmentBar.clubs),
        ('ADM-02.seg.ADM-04', AdminReportsView, AdminSegmentBar.reports),
        ('ADM-04.seg.ADM-05', AdminUsersView, AdminSegmentBar.users),
        ('ADM-05.seg.ADM-01', AdminOverviewView, AdminSegmentBar.overview),
      ]) {
        await tester.tap(find.byKey(GuKey.action(key)));
        await tester.pump();
        // Yeni bölme sahnede, saydamdan solmaya başlar.
        expect(find.byType(type), findsOneWidget, reason: key);
        expect(_stackOpacity(tester), lessThan(1), reason: key);
        await tester.pumpAndSettle();
        expect(_stackOpacity(tester), 1, reason: key);
        expect(_segment(tester), current, reason: key);
        expect(find.byType(GuBottomNav), findsOneWidget, reason: key);
        final bar = tester.widget<GuAppBar>(find.byType(GuAppBar));
        expect(bar.onBack, isNull, reason: key);
        // Aynı sayfa öğesi (yığın değişmedi).
        expect(tester.element(find.byType(AdminView)), same(view));
      }
    });

    testWidgets('bölmeler hâlini korur (arama metni, süzgeç, kaydırma)', (
      tester,
    ) async {
      await pumpShell(tester);
      await _tapKey(tester, GuKey.action('ADM-01.seg.ADM-02'));
      await tester.enterText(find.byKey(GuKey.action('ADM-02.search')), 'spor');
      await tester.pumpAndSettle();

      await _tapKey(tester, GuKey.action('ADM-02.seg.ADM-05'));
      await _tapKey(tester, GuKey.action('ADM-05.filter.suspended'));
      await _tapKey(tester, GuKey.action('ADM-05.seg.ADM-01'));
      final overview = find.descendant(
        of: find.byType(AdminOverviewView),
        matching: find.byType(Scrollable),
      );
      await tester.drag(overview.first, const Offset(0, -300));
      await tester.pumpAndSettle();
      final offset = tester
          .state<ScrollableState>(overview.first)
          .position
          .pixels;
      expect(offset, greaterThan(0));

      await _tapKey(tester, GuKey.action('ADM-01.seg.ADM-02'));
      expect(
        find.descendant(
          of: find.byKey(GuKey.action('ADM-02.search')),
          matching: find.text('spor'),
        ),
        findsOneWidget,
      );
      await _tapKey(tester, GuKey.action('ADM-02.seg.ADM-05'));
      final chip = tester.widget<GuChip>(
        find.byKey(GuKey.action('ADM-05.filter.suspended')),
      );
      expect(chip.selected, isTrue);
      await _tapKey(tester, GuKey.action('ADM-05.seg.ADM-01'));
      expect(
        tester.state<ScrollableState>(overview.first).position.pixels,
        offset,
      );
    });

    testWidgets('Admin sekmesine yeniden dokunma etkin bölmeyi başa kaydırır '
        '(diğer bölmeler yerinde kalır)', (tester) async {
      await pumpShell(tester);
      // Bölmenin liste kaydırması (arama alanının iç kaydırması değil).
      Finder scrollOf(Type section) => find
          .descendant(
            of: find.descendant(
              of: find.byType(section, skipOffstage: false),
              matching: find.byType(CustomScrollView, skipOffstage: false),
            ),
            matching: find.byType(Scrollable, skipOffstage: false),
          )
          .first;
      double pixels(Type section) =>
          tester.state<ScrollableState>(scrollOf(section)).position.pixels;

      await tester.drag(scrollOf(AdminOverviewView), const Offset(0, -300));
      await tester.pumpAndSettle();
      await _tapKey(tester, GuKey.action('ADM-01.seg.ADM-02'));
      await tester.drag(scrollOf(AdminClubsView), const Offset(0, -300));
      await tester.pumpAndSettle();
      final overview = pixels(AdminOverviewView);
      expect(overview, greaterThan(0));
      expect(pixels(AdminClubsView), greaterThan(0));

      await tester.tap(find.byKey(GuKey.action('NAV.tab.admin')));
      await tester.pumpAndSettle();
      expect(pixels(AdminClubsView), 0);
      expect(pixels(AdminOverviewView), overview);
    });

    testWidgets('bölmeler ilk seçildiğinde kurulur (okuma o an başlar)', (
      tester,
    ) async {
      await pumpShell(tester);
      expect(find.byType(AdminClubsView, skipOffstage: false), findsNothing);
      expect(find.byType(AdminReportsView, skipOffstage: false), findsNothing);
      await _tapKey(tester, GuKey.action('ADM-01.seg.ADM-04'));
      expect(find.byType(AdminReportsView), findsOneWidget);
      await _tapKey(tester, GuKey.action('ADM-04.seg.ADM-01'));
      expect(
        find.byType(AdminReportsView, skipOffstage: false),
        findsOneWidget,
      );
      expect(find.byType(AdminClubsView, skipOffstage: false), findsNothing);
    });

    testWidgets('yeniden seçilen bölme içerik kalarak yeniden okunur '
        '(öteki bölmenin yazımı bayat kalmaz)', (
      tester,
    ) async {
      await _pumpRoute(tester);
      final clubs = GetIt.I<ClubRepository>() as FakeClubRepository;
      final admin = GetIt.I<AdminRepository>() as FakeAdminRepository;
      int reads(String method) => switch (method) {
        'stats' => admin.callsTo('stats').length,
        _ => clubs.callsTo(method).length,
      };

      await _tapKey(tester, GuKey.action('ADM-01.seg.ADM-02'));
      final activeRow = GuKey.action('ADM-02.row.c01');
      expect(find.byKey(activeRow), findsOneWidget);
      final clubReads = reads('fetchActiveClubs');
      final statReads = reads('stats');

      // Başka bölmede (SHT-26) kulüp askıya alındı.
      await _tapKey(tester, GuKey.action('ADM-02.seg.ADM-04'));
      clubs.clubs['c01'] = clubs.clubs['c01']!.copyWith(
        status: ClubStatus.suspended,
      );
      await _tapKey(tester, GuKey.action('ADM-04.seg.ADM-02'));
      expect(reads('fetchActiveClubs'), clubReads + 1);
      // Liste iskelete dönmeden güncellendi: c01 "Aktif" sekmesinden çıktı.
      expect(find.byType(GuSkeletonList), findsNothing);
      expect(find.byKey(activeRow), findsNothing);

      // Genel bakış da yeniden seçilince tazelenir.
      await _tapKey(tester, GuKey.action('ADM-02.seg.ADM-01'));
      expect(reads('stats'), greaterThan(statReads));
    });

    testWidgets('hareket azaltılmışsa bölme geçişi anında', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pumpShell(tester);
      await tester.tap(find.byKey(GuKey.action('ADM-01.seg.ADM-02')));
      await tester.pump();
      expect(find.byType(AdminClubsView), findsOneWidget);
      expect(_stackOpacity(tester), 1);
    });

    testWidgets('rota sorgusu komuttur: dolu ve değişen `tab` uygulanır; '
        'boş `tab` (alt sayfadan dönüş) bölmeyi korur', (tester) async {
      final router = await _pumpRoute(tester);
      router.go('/admin?tab=reports');
      await tester.pumpAndSettle();
      expect(find.byType(AdminReportsView), findsOneWidget);

      // Alt sayfa (ebeveyn sorgusuz kurulur) → geri: Şikayetler açık kalır.
      router.go('/admin/clubs/new');
      await tester.pumpAndSettle();
      expect(find.text('/admin/clubs/new'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(_location(router), '/admin');
      expect(find.byType(AdminReportsView), findsOneWidget);
      expect(_segment(tester), AdminSegmentBar.reports);

      router.go(const AdminRoute(tab: AdminTab.users).location);
      await tester.pumpAndSettle();
      expect(find.byType(AdminUsersView), findsOneWidget);
    });
  });

  group('ADM-01 · Admin genel bakış · golden', () {
    testWidgets('varsayılan açık + koyu (kabukta: alt çubuk görünür)', (
      tester,
    ) async {
      await goldenForThemes(
        tester,
        'ADM-01',
        _view,
        overrides: _overrides(),
        wrapInShell: true,
        shellTab: GuTab.admin,
      );
    });
  });
}
