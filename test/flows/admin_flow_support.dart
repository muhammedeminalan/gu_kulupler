// Admin akış testlerinin ortak kurulumu (T-38, T-39): gerçek `GuApp` (rota
// ağacı, guard `S`, oturum katmanı, kabuk, `AppFeedbackService`) + sahte
// servisler; demo kulüpleri ve şikayetleri, KPI sayaçları fixture'lardan.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/bootstrap/gu_app.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/navigation/app_router.dart';
import 'package:gu_kulupler/product/navigation/navigator_keys.dart';
import 'package:gu_ui/gu_ui.dart';

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

/// Demo verideki tüm kulüpler.
List<ClubModel> adminDemoClubs() => [
  for (final id in DemoDataFixture.ids(FirestoreCollections.clubs))
    ClubModelFixtures.byId(id),
];

/// Demo verideki tüm şikayet belgeleri.
List<ReportModel> adminDemoReports() => [
  for (final id in DemoDataFixture.ids(FirestoreCollections.reports))
    ReportModel.fromJson(
      DemoDataFixture.toFirestoreJson(FirestoreCollections.reports, id),
      id: id,
    ),
];

/// KPI sayaçları fixture'lardan: etkin kulüp, kullanıcı belgesi, açık
/// şikayet (CD-37).
AdminStats adminFixtureStats(
  List<ClubModel> clubs,
  List<ReportModel> reports,
) => AdminStats(
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
Future<void> launchAdminApp(WidgetTester tester, {required String uid}) async {
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
  final clubs = adminDemoClubs();
  final reports = adminDemoReports();
  final clubStore = (GetIt.I<ClubRepository>() as FakeClubRepository).clubs;
  for (final club in clubs) {
    clubStore[club.id] = club;
  }
  final admin = GetIt.I<AdminRepository>() as FakeAdminRepository
    ..statsValue = adminFixtureStats(clubs, reports);
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
    flowContainer(tester).read(sessionViewModelProvider).status,
    AuthStatus.active,
  );
  expect(flowLocation(tester), '/clubs');
}

ProviderContainer flowContainer(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(GuApp)));

GoRouter flowRouter(WidgetTester tester) =>
    flowContainer(tester).read(appRouterProvider);

String flowLocation(WidgetTester tester) =>
    flowRouter(tester).routerDelegate.currentConfiguration.uri.toString();

Future<void> flowTap(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
