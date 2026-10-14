// T-32 · Uçtan uca başvuru yönetimi akışı: gerçek `GuApp` (rota ağacı, guard
// `V`, oturum katmanı, kabuk, `AppFeedbackService` — SHT-19 / SHT-20 /
// DLG-17 / DLG-18 ve toast'lar gerçekten çizilir) + sahte servisler. Veri
// `c03` demo kaydıdır (`seedManage` + `seedApplications`; başvurular kapalı).
//
//   yönetici (`u_burak`): CLB-03 → MGT-01 → "Bekleyen başvuru" (W-36) →
//   MGT-02 → satır → SHT-19 → Onayla → TST-27 → Geri al (30 sn içinde) →
//   TST-X17 → ret → SHT-20 neden → TST-28 (`retryAfter` +7 gün) → uzun basış
//   → Hepsini seç → toplu onay → DLG-17 → TST-27 ("n başvuru") → "Başvuruları
//   aç" → TST-54
//   ikinci yönetici kararı (fake çakışma) → DLG-18 → satır kalkar;
//   `application_received` bildirimine dokunma (W-28) → MGT-02 + SHT-19
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/bootstrap/gu_app.dart';
import 'package:gu_kulupler/core/constants/app_durations.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/management/view/manage_applications_view.dart';
import 'package:gu_kulupler/features/management/view/widget/application_detail_sheet.dart';
import 'package:gu_kulupler/features/management/view/widget/reject_reason_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/navigation/app_router.dart';
import 'package:gu_kulupler/product/navigation/navigator_keys.dart';
import 'package:gu_kulupler/product/widget/member/application_row.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../fakes/fake_app_preferences_store.dart';
import '../fakes/fake_auth_repository.dart';
import '../fakes/fake_club_repository.dart';
import '../fakes/fake_membership_repository.dart';
import '../fakes/fake_notification_repository.dart';
import '../fakes/fake_user_repository.dart';
import '../fakes/register_fakes.dart';
import '../features/management/applications_test_support.dart';
import '../features/management/manage_test_support.dart';
import '../fixtures/user_model_fixtures.dart';
import '../helpers/test_asset_bundle.dart';

const String _email = 'burak.sahin@ogr.gumushane.edu.tr';
const String _path = '/clubs/$kManageClubId/manage/applications';

Key _k(String id) => GuKey.action(id);

FakeMembershipRepository _memberships() =>
    GetIt.I<MembershipRepository>() as FakeMembershipRepository;

MembershipModel _membership(String uid) =>
    _memberships().memberships.values.firstWhere(
      (m) => m.clubId == kManageClubId && m.userId == uid,
    );

/// `c03` verisini (başvurular kapalı) ve `u_burak` oturumunu kurar, gerçek
/// `GuApp`'i açar ve `c03` kulüp sayfasına gider.
Future<void> _launch(
  WidgetTester tester, {
  void Function()? beforeLaunch,
}) async {
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
  seedApplications();
  (GetIt.I<ClubRepository>() as FakeClubRepository).clubs[kManageClubId] =
      kManageClub.copyWith(applicationsOpen: false);
  beforeLaunch?.call();
  (GetIt.I<AuthRepository>() as FakeAuthRepository)
    ..service.uid = kManageUid
    ..service.emailVerified = true
    ..currentUser = const AuthUserInfo(
      uid: kManageUid,
      email: _email,
      emailVerified: true,
    );
  (GetIt.I<UserRepository>() as FakeUserRepository).putActive(
    kManageUid,
    name: UserModelFixtures.byId(kManageUid).name,
    email: _email,
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

/// Fake'te hâlâ bekleyen `c03` başvuranları.
List<String> _pendingIds() => [
  for (final m in _memberships().memberships.values)
    if (m.clubId == kManageClubId && m.status == MembershipStatus.pending)
      m.userId,
];

List<String> _rowIds(WidgetTester tester) => [
  for (final row in tester.widgetList<ApplicationRow>(
    find.byType(ApplicationRow),
  ))
    row.application.userId,
];

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_GB');
    await initializeDateFormatting('en_US');
  });

  testWidgets('yönetici: MGT-01 → MGT-02 → SHT-19 onay → TST-27 → Geri al → '
      'SHT-20 ret → TST-28 → toplu onay (DLG-17) → TST-54', (tester) async {
    await _launch(tester);

    // CLB-03 → MGT-01 → "Bekleyen başvuru" (W-36) → MGT-02.
    await _tap(tester, _k('CLB-03.openManage'));
    await _tap(tester, _k('MGT-01.kpi.pending'));
    expect(_location(tester), _path);
    expect(find.byType(ManageApplicationsView), findsOneWidget);
    expect(kPendingIds, containsAll(_rowIds(tester)));
    expect(_pendingIds(), unorderedEquals(kPendingIds));

    // Satır → SHT-19 → Onayla → TST-27; satır kalkar, üyelik aktif.
    await _tap(tester, _k('MGT-02.row.u_cem'));
    expect(find.byType(ApplicationDetailSheet), findsOneWidget);
    await _tap(tester, ApplicationDetailSheet.keyOf('approve'));
    expect(find.byType(ApplicationDetailSheet), findsNothing);
    expect(_toast(ToastId.tst27), findsOneWidget);
    expect(_rowIds(tester), isNot(contains('u_cem')));
    expect(_membership('u_cem').status, MembershipStatus.active);

    // Geri al (30 sn içinde) → TST-X17; başvuru yeniden bekliyor.
    await _tap(tester, FeedbackKeys.of('TST-27', 'undo'));
    expect(_toast(ToastId.tstX17), findsOneWidget);
    expect(_membership('u_cem').status, MembershipStatus.pending);
    expect(_rowIds(tester), contains('u_cem'));
    await _dismissToast(tester);

    // Ret → SHT-20 (neden: koşullar) → TST-28; `retryAfter` = karar + 7 gün.
    await _tap(tester, _k('MGT-02.reject.u043'));
    expect(find.byType(RejectReasonSheet), findsOneWidget);
    await _tap(tester, RejectReasonSheet.reasonKey(RejectReason.criteria));
    await _tap(tester, RejectReasonSheet.submitKey);
    expect(_toast(ToastId.tst28), findsOneWidget);
    final rejected = _membership('u043');
    expect(rejected.status, MembershipStatus.rejected);
    expect(rejected.rejectReason, RejectReason.criteria);
    expect(
      rejected.retryAfter!.difference(rejected.decidedAt!),
      const Duration(days: 7),
    );
    expect(_rowIds(tester), isNot(contains('u043')));
    await _dismissToast(tester);

    // Uzun basış → seçim → Hepsini seç → toplu onay → DLG-17 → TST-27.
    final remaining = _pendingIds();
    expect(remaining, hasLength(kPendingIds.length - 1));
    await tester.longPress(find.byKey(_k('MGT-02.row.${remaining.first}')));
    await tester.pumpAndSettle();
    await _tap(tester, _k('MGT-02.selectAll'));
    await _tap(tester, _k('MGT-02.bulkApprove'));
    await _tap(tester, FeedbackKeys.of('DLG-17', 'confirm'));
    expect(_toast(ToastId.tst27), findsOneWidget);
    expect(find.byType(ApplicationRow), findsNothing);
    for (final uid in remaining) {
      expect(_membership(uid).status, MembershipStatus.active, reason: uid);
    }
    await _dismissToast(tester);

    // Başvurular kapalı bandı → "Başvuruları aç" → TST-54.
    await _tap(tester, _k('MGT-02.toggleOpen'));
    expect(_toast(ToastId.tst54), findsOneWidget);
    expect(
      (GetIt.I<ClubRepository>() as FakeClubRepository)
          .clubs[kManageClubId]!
          .applicationsOpen,
      isTrue,
    );
    await _dismissToast(tester);
  });

  testWidgets('ikinci yönetici kararı → DLG-18; application_received '
      'bildirimi → MGT-02 + SHT-19 (W-28)', (tester) async {
    final notification = NotificationModel(
      id: 'n_app',
      userId: kManageUid,
      type: NotificationType.applicationReceived,
      refs: const NotificationRefsModel(
        clubId: kManageClubId,
        applicantId: 'u_long',
      ),
      createdAt: kDefaultFakeNowUtc.subtract(const Duration(minutes: 5)),
    );
    await _launch(
      tester,
      beforeLaunch: () =>
          (GetIt.I<NotificationRepository>() as FakeNotificationRepository).put(
            notification,
          ),
    );
    _router(tester).go(_path);
    await tester.pumpAndSettle();
    expect(_rowIds(tester), contains('u039'));

    // Başka yönetici `u039`'u liste okunduktan sonra onayladı.
    _memberships().put(
      _membership('u039').copyWith(status: MembershipStatus.active),
    );
    await _tap(tester, _k('MGT-02.approve.u039'));
    expect(find.byKey(FeedbackKeys.of('DLG-18', 'ok')), findsOneWidget);
    expect(_toast(ToastId.tst27), findsNothing);
    await _tap(tester, FeedbackKeys.of('DLG-18', 'ok'));
    expect(_rowIds(tester), isNot(contains('u039')));

    // Bildirim → MGT-02 `?applicant=` → 250 ms sonra o başvurunun SHT-19'u.
    // Alt çubuk yalnızca sekme kökünde: Kulüpler köküne dön → Bildirimler.
    _router(tester).go('/clubs');
    await tester.pumpAndSettle();
    await _tap(tester, _k('NAV.tab.notifications'));
    await _tap(tester, _k('NTF-01.item.n_app'));
    expect(_location(tester), '$_path?applicant=u_long');
    expect(find.byType(ManageApplicationsView), findsOneWidget);
    await tester.pump(AppDurations.postNavigationSheetDelay);
    await tester.pumpAndSettle();
    final sheet = tester.widget<ApplicationDetailSheet>(
      find.byType(ApplicationDetailSheet),
    );
    expect(sheet.application?.userId, 'u_long');
  });
}
