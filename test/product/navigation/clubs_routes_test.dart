// T-16 · Kulüpler dalının alt rotaları — gerçek rota ağacı + yönlendirme:
// CLB-03 `/clubs/:clubId?tab=`, CLB-04 `…/applied`, CLB-05 `…/application`
// (navigation.md §2.2, PLAN §13.3.2). Yol / sorgu parametreleri view'a
// aktarılır, yığın rota ağacından kurulur (geri ebeveyne döner), alt çubuk
// derin ekranda gizlenir, guard `A` (oturumsuz → giriş), geçiş platform
// varsayılanıdır (D-06).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/features/clubs/view/club_application_view.dart';
import 'package:gu_kulupler/features/clubs/view/club_applied_view.dart';
import 'package:gu_kulupler/features/clubs/view/club_detail_view.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../fakes/fake_club_repository.dart';
import '../../fakes/fake_session_states.dart';
import '../../fakes/test_router.dart';
import '../../fixtures/club_model_fixtures.dart';

/// Gerçek rota ağacını çizer, demo veriden kulüpleri sahte repository'ye
/// yazar ve [location] yoluna gider. Kulüp ekranları kulübü açılışta okur;
/// bulunamayan kulüp SYS-04'e yönlenir — bu yüzden kulüpler yola gitmeden
/// önce yazılır (fake'ler `pump` sırasında sıfırlanır).
Future<TestRouter> _pump(
  WidgetTester tester, {
  SessionState session = FakeSessionStates.active,
  String? location,
}) async {
  final app = await TestRouter.pump(tester, session: session);
  final clubs = GetIt.I<ClubRepository>() as FakeClubRepository;
  for (final id in const ['c01', 'c03', 'c06', 'c07', 'c09']) {
    clubs.clubs[id] = ClubModelFixtures.byId(id);
  }
  if (location != null) await app.go(location);
  return app;
}

ClubDetailView _detail(WidgetTester tester) =>
    tester.widget<ClubDetailView>(find.byType(ClubDetailView));

void main() {
  group('T-16 · kulüp rotaları · eşleşme', () {
    testWidgets('/clubs/:clubId → ClubDetailView(clubId); sekme verilmezse '
        '`tab` null', (tester) async {
      final app = await _pump(tester, location: '/clubs/c01');
      expect(app.location, '/clubs/c01');
      expect(_detail(tester).clubId, 'c01');
      expect(_detail(tester).tab, isNull);

      await app.go('/clubs/c07');
      expect(_detail(tester).clubId, 'c07');
    });

    testWidgets('`?tab=` her sekme adını ekrana taşır; tanınmayan değer '
        'null (ekran hakkında ile açılır)', (tester) async {
      final app = await _pump(tester);
      for (final tab in ClubDetailTab.values) {
        await app.go('/clubs/c01?tab=${tab.name}');
        expect(app.location, '/clubs/c01?tab=${tab.name}');
        expect(_detail(tester).tab, tab, reason: tab.name);
      }
      await app.go('/clubs/c01?tab=bilinmeyen');
      expect(_detail(tester).clubId, 'c01');
      expect(_detail(tester).tab, isNull);
    });

    testWidgets('/clubs/:clubId/applied → ClubAppliedView(clubId)', (
      tester,
    ) async {
      final app = await _pump(
        tester,
        location: '/clubs/c06/applied',
      );
      expect(app.location, '/clubs/c06/applied');
      expect(
        tester.widget<ClubAppliedView>(find.byType(ClubAppliedView)).clubId,
        'c06',
      );
    });

    testWidgets('/clubs/:clubId/application → ClubApplicationView(clubId)', (
      tester,
    ) async {
      final app = await _pump(
        tester,
        location: '/clubs/c06/application',
      );
      expect(app.location, '/clubs/c06/application');
      expect(
        tester
            .widget<ClubApplicationView>(find.byType(ClubApplicationView))
            .clubId,
        'c06',
      );
    });

    testWidgets('tipli rota `go` ile açılır (ClubDetailRoute, '
        'ClubAppliedRoute, ClubApplicationRoute)', (tester) async {
      final app = await _pump(tester);
      BuildContext context() => tester.element(find.byType(Scaffold).last);

      const ClubDetailRoute(
        clubId: 'c03',
        tab: ClubDetailTab.posts,
      ).go(context());
      await tester.pumpAndSettle();
      expect(app.location, '/clubs/c03?tab=posts');
      expect(_detail(tester).clubId, 'c03');
      expect(_detail(tester).tab, ClubDetailTab.posts);

      const ClubAppliedRoute(clubId: 'c03').go(context());
      await tester.pumpAndSettle();
      expect(app.location, '/clubs/c03/applied');
      expect(find.byType(ClubAppliedView), findsOneWidget);

      const ClubApplicationRoute(clubId: 'c03').go(context());
      await tester.pumpAndSettle();
      expect(app.location, '/clubs/c03/application');
      expect(find.byType(ClubApplicationView), findsOneWidget);
    });
  });

  group('T-16 · kulüp rotaları · yığın ve kabuk', () {
    testWidgets('yığın rota ağacından kurulur: başvuru ekranından geri → '
        'kulüp → Kulüpler kökü', (tester) async {
      for (final leaf in ['applied', 'application']) {
        final app = await _pump(
          tester,
          location: '/clubs/c01/$leaf',
        );
        expect(app.currentTab, GuTab.clubs);
        expect(app.stackDepth(GuTab.clubs), 3, reason: leaf);

        expect(await app.systemBack(), isTrue);
        expect(app.location, '/clubs/c01', reason: leaf);
        expect(find.byType(ClubDetailView), findsOneWidget);
        expect(app.stackDepth(GuTab.clubs), 2);

        expect(await app.systemBack(), isTrue);
        expect(app.location, '/clubs', reason: leaf);
        expect(find.byType(ClubDetailView), findsNothing);
      }
    });

    testWidgets('alt sekme çubuğu yalnızca kökte: kulüp ve başvuru '
        'ekranlarında gizlenir', (tester) async {
      final app = await _pump(tester, location: '/clubs');
      expect(find.byType(GuBottomNav), findsOneWidget);
      for (final location in [
        '/clubs/c01',
        '/clubs/c01?tab=events',
        '/clubs/c01/applied',
        '/clubs/c01/application',
      ]) {
        await app.go(location);
        expect(find.byType(GuBottomNav), findsNothing, reason: location);
      }
      await app.go('/clubs');
      expect(find.byType(GuBottomNav), findsOneWidget);
    });

    testWidgets('başka sekmeden kulübe `go`: Kulüpler sekmesine geçilir, '
        'çağıran sekmenin yığını korunur (Q-20)', (tester) async {
      final app = await _pump(tester, location: '/profile');
      expect(app.currentTab, GuTab.profile);

      await app.go('/clubs/c01');
      expect(app.currentTab, GuTab.clubs);
      expect(app.stackDepth(GuTab.clubs), 2);
      expect(app.stackDepth(GuTab.profile), 1);

      expect(await app.systemBack(), isTrue);
      expect(app.location, '/clubs');
    });

    testWidgets('geçiş platform varsayılanıdır: üç rotanın sayfası '
        'MaterialPage', (tester) async {
      final app = await _pump(tester);
      for (final location in [
        '/clubs/c01',
        '/clubs/c01/applied',
        '/clubs/c01/application',
      ]) {
        await app.go(location);
        final pages = GuTab.clubs.navigatorKey.currentState!.widget.pages;
        expect(pages.last, isA<MaterialPage<void>>(), reason: location);
      }
    });
  });

  group('T-16 · kulüp rotaları · guard (A)', () {
    testWidgets('oturum yokken giriş ekranına yönlenir; dönüş adresi '
        'sorguda taşınır', (tester) async {
      for (final location in [
        '/clubs/c01',
        '/clubs/c01/applied',
        '/clubs/c01/application',
      ]) {
        final app = await _pump(
          tester,
          session: FakeSessionStates.signedOut,
          location: location,
        );
        expect(
          app.location,
          '/login?from=${Uri.encodeQueryComponent(location)}',
          reason: location,
        );
        expect(find.byType(ClubDetailView), findsNothing);
      }
    });

    testWidgets('doğrulanmamış ve profili eksik oturum kulüp rotasına '
        'giremez', (tester) async {
      final unverified = await _pump(
        tester,
        session: FakeSessionStates.unverified,
        location: '/clubs/c01',
      );
      expect(unverified.location, '/verify');

      final incomplete = await _pump(
        tester,
        session: FakeSessionStates.profileIncomplete,
        location: '/clubs/c01/application',
      );
      expect(incomplete.location, '/setup-profile');
    });

    testWidgets('ziyaretçi (kulüpte üyeliği yok) üç rotaya da girer: rota '
        'düzeyinde rol koruması yoktur', (tester) async {
      final app = await _pump(tester);
      expect(app.session.memberships.containsKey('c09'), isFalse);
      for (final location in [
        '/clubs/c09',
        '/clubs/c09?tab=posts',
        '/clubs/c09/applied',
        '/clubs/c09/application',
      ]) {
        await app.go(location);
        expect(app.location, location);
        expect(app.feedback.toasts, isEmpty);
      }
    });
  });
}
