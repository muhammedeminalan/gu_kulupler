// T-38 · Uçtan uca admin genel bakış akışı: gerçek `GuApp` (rota ağacı, guard
// `S`, oturum katmanı, kabuk, `AppFeedbackService`) + sahte servisler. Veri
// demo kayıtlarıdır: tüm kulüpler (askıdaki dahil) ve şikayet belgeleri;
// KPI sayaçları (`AdminRepository.stats`) aynı fixture'lardan sayılır.
//
//   süper admin (`u_admin`, claim `superadmin`): Kulüpler → "Admin" sekmesi →
//   ADM-01 (KPI = fixture sayıları; askıdaki kulüp kulüp listesinden) →
//   "Bekleyen işler" şikayet / askı satırları → en aktif kulüp → CLB-03
//   (Kulüpler yığını) → geri → "Admin" sekmesi → ADM-01 (yığın korunur)
//   süper admin olmayan (`u_ayse`): "Admin" sekmesi yok; `/admin` → `/clubs`
//   + TST-X18
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/bootstrap/gu_app.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/admin/view/admin_view.dart';
import 'package:gu_kulupler/features/clubs/view/club_detail_view.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/app_router.dart';
import 'package:gu_kulupler/product/navigation/navigator_keys.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../fakes/fake_admin_repository.dart';
import '../fakes/fake_app_preferences_store.dart';
import '../fakes/fake_auth_repository.dart';
import '../fakes/fake_club_repository.dart';
import '../fakes/fake_user_repository.dart';
import '../fakes/register_fakes.dart';
import '../fixtures/club_model_fixtures.dart';
import '../fixtures/demo_data.dart';
import '../fixtures/user_model_fixtures.dart';
import '../helpers/test_asset_bundle.dart';

/// Süper admin olmayan öğrenci.
const String _studentUid = 'u_ayse';

Key _k(String id) => GuKey.action(id);

/// Demo verideki tüm kulüpler.
List<ClubModel> _demoClubs() => [
  for (final id in DemoDataFixture.ids(FirestoreCollections.clubs))
    ClubModelFixtures.byId(id),
];

/// Demo verideki tüm şikayet belgeleri.
List<ReportModel> _demoReports() => [
  for (final id in DemoDataFixture.ids(FirestoreCollections.reports))
    ReportModel.fromJson(
      DemoDataFixture.toFirestoreJson(FirestoreCollections.reports, id),
      id: id,
    ),
];

/// KPI sayaçları fixture'lardan: etkin kulüp, kullanıcı belgesi, açık
/// şikayet (CD-37).
AdminStats _fixtureStats(List<ClubModel> clubs, List<ReportModel> reports) =>
    AdminStats(
      clubCount: clubs
          .where((c) => c.status == ClubStatus.active && !c.isDeleted)
          .length,
      userCount: DemoDataFixture.ids(FirestoreCollections.users).length,
      openReportCount: reports
          .where((r) => r.status == ReportStatus.open && !r.isDeleted)
          .length,
    );

/// Demo kulüpleri ve şikayetleri yazar, [uid] oturumunu kurar ve gerçek
/// `GuApp`'i açar (açılış yeri `/clubs`).
Future<void> _launch(WidgetTester tester, {required String uid}) async {
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
  final clubs = _demoClubs();
  final reports = _demoReports();
  final clubStore = (GetIt.I<ClubRepository>() as FakeClubRepository).clubs;
  for (final club in clubs) {
    clubStore[club.id] = club;
  }
  final admin = GetIt.I<AdminRepository>() as FakeAdminRepository
    ..statsValue = _fixtureStats(clubs, reports);
  for (final report in reports) {
    admin.reports[report.id] = report;
  }
  final email = '$uid@ogr.gumushane.edu.tr';
  final auth = GetIt.I<AuthRepository>() as FakeAuthRepository
    ..isSuperAdminResult = uid == DemoDataFixture.superAdminId
    ..currentUser = AuthUserInfo(uid: uid, email: email, emailVerified: true);
  auth.service
    ..uid = uid
    ..emailVerified = true;
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
  expect(_location(tester), '/clubs');
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

String _kpi(WidgetTester tester, String id) =>
    tester.widget<GuKpi>(find.byKey(_k('ADM-01.kpi.$id'))).value;

int _navItems(WidgetTester tester) =>
    tester.widget<GuBottomNav>(find.byType(GuBottomNav)).items.length;

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_GB');
    await initializeDateFormatting('en_US');
  });

  testWidgets('süper admin: Admin sekmesi → ADM-01 (KPI = fixture) → bekleyen '
      'şikayetler → en aktif kulüp CLB-03 → sekmeye dönüş', (tester) async {
    await _launch(tester, uid: DemoDataFixture.superAdminId);
    final clubs = _demoClubs();
    final stats = _fixtureStats(clubs, _demoReports());
    final suspended = clubs.where((c) => c.isSuspended).length;
    expect(stats.openReportCount, greaterThan(0));
    expect(suspended, greaterThan(0));

    // Claim okundu: beşinci sekme "Admin".
    expect(_navItems(tester), GuTab.values.length);
    await _tap(tester, _k('NAV.tab.admin'));
    expect(_location(tester), '/admin');
    expect(find.byType(AdminView), findsOneWidget);

    // KPI: sayaçlar fixture'larla aynı; askıdaki kulüp kulüp listesinden.
    expect(_kpi(tester, 'clubs'), '${stats.clubCount}');
    expect(_kpi(tester, 'users'), '${stats.userCount}');
    expect(_kpi(tester, 'reports'), '${stats.openReportCount}');
    expect(_kpi(tester, 'suspended'), '$suspended');

    // "Bekleyen işler": açık şikayet ve askıdaki kulüp önizlemesi (uygulamanın
    // etkin dilinde).
    final l10n = AppLocalizations.of(tester.element(find.byType(AdminView)));
    expect(
      find.descendant(
        of: find.byKey(_k('ADM-01.task.reports')),
        matching: find.text(l10n.adminTaskReports(stats.openReportCount)),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(_k('ADM-01.task.suspended')),
        matching: find.text(l10n.adminTaskSuspended(suspended)),
      ),
      findsOneWidget,
    );

    // En aktif kulüp (etkinler `memberCount ↓`) → CLB-03, Kulüpler yığınında.
    final top =
        (clubs.where((c) => c.status == ClubStatus.active).toList()
              ..sort((a, b) => b.memberCount.compareTo(a.memberCount)))
            .first;
    await _tap(tester, _k('ADM-01.topClub.${top.id}'));
    expect(_location(tester), '/clubs/${top.id}');
    expect(find.byType(ClubDetailView), findsOneWidget);

    // Geri → Kulüpler kökü (alt çubuk yalnızca kökte) → Admin sekmesi: kök
    // ve içerik korunur.
    await _tap(tester, _k('CLB-03.back'));
    expect(_location(tester), '/clubs');
    await _tap(tester, _k('NAV.tab.admin'));
    expect(_location(tester), '/admin');
    expect(_kpi(tester, 'reports'), '${stats.openReportCount}');
  });

  testWidgets('süper admin olmayan: Admin sekmesi yok; /admin → /clubs + '
      'TST-X18', (tester) async {
    await _launch(tester, uid: _studentUid);

    expect(_navItems(tester), GuTab.values.length - 1);
    expect(find.byKey(_k('NAV.tab.admin')), findsNothing);

    _router(tester).go('/admin');
    await tester.pumpAndSettle();
    expect(_location(tester), '/clubs');
    expect(find.byType(AdminView), findsNothing);
    expect(find.byKey(const ValueKey<ToastId>(ToastId.tstX18)), findsOneWidget);
    await tester.pump(GuMotion.toastDefault);
    await tester.pumpAndSettle();
  });
}
