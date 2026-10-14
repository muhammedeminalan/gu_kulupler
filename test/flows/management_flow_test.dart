// T-31 · Uçtan uca yönetim paneli akışı: gerçek `GuApp` (rota ağacı, guard
// `V`, oturum katmanı, kabuk, `AppFeedbackService` — SHT-18 ve toast'lar
// gerçekten çizilir) + sahte servisler. Veri `c03` (Doğa Sporları ve
// Dağcılık) demo kaydıdır (`seedManage`).
//
//   yönetici (`u_burak`, başkan): CLB-03 → "Yönetim" (W-12) → MGT-01 (KPI =
//   sayaçlar) → "Son hareketler → Tümü" → MGT-10 → "Üyelik" süzgeci → geri →
//   MGT-01 → geri → CLB-03 → Profil sekmesi → yönetilen kulüp (W-31) → MGT-01
//   danışman (`u_a_c03`): CLB-03 → "Yönetimi görüntüle" → MGT-01 salt okunur
//   bandı → "Gönderi yaz" → TST-26 (gezinme yok)
//   iki kulüp yöneten: PRF-01 "Yönetim paneli" → SHT-18 (varsayılan, W-26)
//   → c01 MGT-01 → "kulüp değiştir" → SHT-18 → c03 MGT-01
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/bootstrap/gu_app.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/management/view/activity_log_view.dart';
import 'package:gu_kulupler/features/management/view/manage_view.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/managed_club_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/navigation/app_router.dart';
import 'package:gu_kulupler/product/navigation/navigator_keys.dart';
import 'package:gu_kulupler/product/widget/manage/activity_row.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../fakes/fake_app_preferences_store.dart';
import '../fakes/fake_auth_repository.dart';
import '../fakes/fake_club_repository.dart';
import '../fakes/fake_membership_repository.dart';
import '../fakes/fake_user_repository.dart';
import '../fakes/register_fakes.dart';
import '../features/management/manage_test_support.dart';
import '../fixtures/club_model_fixtures.dart';
import '../fixtures/demo_data.dart';
import '../fixtures/membership_model_fixtures.dart';
import '../fixtures/user_model_fixtures.dart';
import '../helpers/test_asset_bundle.dart';

/// Kulüp belgesindeki üye sayacı (aktif üyelik sayısından farklı: KPI
/// sayaçtan okunur, yeniden sayılmaz).
const int _memberCounter = 231;

/// `c03` danışmanı.
const String _advisorUid = 'u_a_c03';

/// Oturum e-postaları (demo veri; e-posta `users` belgesinde değil).
const Map<String, String> _emails = {
  kManageUid: 'burak.sahin@ogr.gumushane.edu.tr',
  _advisorUid: 'doc.dr.hakan.yalcin@gumushane.edu.tr',
};

Key _k(String id) => GuKey.action(id);

FakeClubRepository _clubs() => GetIt.I<ClubRepository>() as FakeClubRepository;

FakeMembershipRepository _memberships() =>
    GetIt.I<MembershipRepository>() as FakeMembershipRepository;

/// `c03` demo verisini ve [uid] oturumunu kurar, gerçek `GuApp`'i açar ve
/// `c03` kulüp sayfasına gider. [beforeLaunch] ek veri yazar.
Future<void> _launch(
  WidgetTester tester, {
  String uid = kManageUid,
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
  _clubs().clubs[kManageClubId] = kManageClub.copyWith(
    memberCount: _memberCounter,
  );
  beforeLaunch?.call();
  final user = UserModelFixtures.byId(uid);
  final email = _emails[uid]!;
  (GetIt.I<AuthRepository>() as FakeAuthRepository)
    ..service.uid = uid
    ..service.emailVerified = true
    ..currentUser = AuthUserInfo(
      uid: uid,
      email: email,
      emailVerified: true,
    );
  (GetIt.I<UserRepository>() as FakeUserRepository).putActive(
    uid,
    name: user.name,
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
  _router(tester).go('/clubs/$kManageClubId');
  await tester.pumpAndSettle();
  expect(_location(tester), '/clubs/$kManageClubId');
}

/// `c01`'de yönetim kurulu üyeliği: kullanıcı iki kulüp yönetir.
void _secondManagedClub() {
  _clubs().clubs['c01'] = ClubModelFixtures.byId('c01');
  _memberships().put(
    MembershipModelFixtures.byId(
      FirestoreIds.membership('c01', kManageUid),
    ).copyWith(status: MembershipStatus.active, role: ClubRole.board),
  );
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
    tester.widget<GuKpi>(find.byKey(_k('MGT-01.kpi.$id'))).value;

Finder _toast(ToastId id) => find.byKey(ValueKey<ToastId>(id));

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_GB');
    await initializeDateFormatting('en_US');
  });

  testWidgets('yönetici: CLB-03 → MGT-01 (KPI = sayaçlar) → MGT-10 süzgeç → '
      'geri; PRF-01 yönetilen kulüp → MGT-01', (tester) async {
    await _launch(tester);
    const panel = '/clubs/$kManageClubId/manage';

    // CLB-03 "Yönetim" → MGT-01 (W-12).
    await _tap(tester, _k('CLB-03.openManage'));
    expect(_location(tester), panel);
    expect(find.byType(ManageView), findsOneWidget);
    expect(find.byType(GuBanner), findsNothing);

    // KPI: üye sayacı kulüp belgesinden, bekleyen = bekleyen başvurular,
    // yaklaşan = yayımlanmış gelecek etkinlikler.
    final pending = [
      for (final id in DemoDataFixture.ids(FirestoreCollections.memberships))
        if (id.startsWith('${kManageClubId}_'))
          MembershipModelFixtures.byId(id),
    ].where((m) => m.status == MembershipStatus.pending).length;
    expect(_kpi(tester, 'members'), '$_memberCounter');
    expect(_kpi(tester, 'pending'), '$pending');
    expect(_kpi(tester, 'events'), '${kUpcomingEvents.length}');

    // "Son hareketler → Tümü" → MGT-10.
    await _tap(tester, _k('MGT-01.activityAll'));
    expect(_location(tester), '$panel/activity');
    expect(find.byType(ActivityLogView), findsOneWidget);
    List<ActivityModel> rows() => [
      for (final row in tester.widgetList<ActivityRow>(
        find.byType(ActivityRow),
      ))
        row.activity,
    ];
    expect(
      rows().map((a) => a.category).toSet(),
      containsAll(<ActivityCategory>[
        ActivityCategory.membership,
        ActivityCategory.event,
      ]),
    );

    // "Üyelik" süzgeci: yalnızca üyelik kayıtları.
    await _tap(tester, _k('MGT-10.filter.membership'));
    final filtered = rows();
    expect(filtered, isNotEmpty);
    expect(
      filtered.every((a) => a.category == ActivityCategory.membership),
      isTrue,
    );

    // Geri → MGT-01 → geri → CLB-03.
    await _tap(tester, _k('MGT-10.back'));
    expect(_location(tester), panel);
    await _tap(tester, _k('MGT-01.back'));
    expect(_location(tester), '/clubs/$kManageClubId');

    // Profil sekmesi → yönetilen kulüp satırı → MGT-01 (W-31).
    await _tap(tester, _k('CLB-03.back'));
    expect(_location(tester), '/clubs');
    await _tap(tester, _k('NAV.tab.profile'));
    expect(_location(tester), '/profile');
    await _tap(tester, _k('PRF-01.managed.$kManageClubId'));
    expect(_location(tester), panel);
    expect(find.byType(ManageView), findsOneWidget);
  });

  testWidgets('danışman: MGT-01 salt okunur bandı; "Gönderi yaz" → TST-26, '
      'gezinme yok', (tester) async {
    await _launch(tester, uid: _advisorUid);
    const panel = '/clubs/$kManageClubId/manage';

    await _tap(tester, _k('CLB-03.openManage'));
    expect(_location(tester), panel);
    final banner = tester.widget<GuBanner>(find.byType(GuBanner));
    expect(banner.kind, GuBannerKind.readonly);
    expect(
      tester
          .widget<GuQuickAction>(find.byKey(_k('MGT-01.quick.post')))
          .disabled,
      isTrue,
    );

    await _tap(tester, _k('MGT-01.quick.post'));
    expect(_toast(ToastId.tst26), findsOneWidget);
    expect(_location(tester), panel);
    await tester.pump(GuMotion.toastUndo);
    await tester.pumpAndSettle();
  });

  testWidgets('iki kulüp: PRF-01 "Yönetim paneli" → SHT-18 varsayılanı → c01 '
      'MGT-01 → kulüp değiştir → c03 MGT-01', (tester) async {
    await _launch(tester, beforeLaunch: _secondManagedClub);

    await _tap(tester, _k('CLB-03.back'));
    await _tap(tester, _k('NAV.tab.profile'));
    expect(_location(tester), '/profile');

    // SHT-18 `onSelect` verilmeden açılır: seçim → seçilen kulübün paneli.
    await _tap(tester, _k('PRF-01.managedAll'));
    expect(find.byType(ManagedClubPickerSheet), findsOneWidget);
    await _tap(tester, ManagedClubPickerSheet.keyOf('c01'));
    expect(find.byType(ManagedClubPickerSheet), findsNothing);
    expect(_location(tester), '/clubs/c01/manage');
    expect(find.byType(ManageView), findsOneWidget);

    await _tap(tester, _k('MGT-01.switchClub'));
    expect(find.byType(ManagedClubPickerSheet), findsOneWidget);
    await _tap(tester, ManagedClubPickerSheet.keyOf(kManageClubId));
    expect(_location(tester), '/clubs/$kManageClubId/manage');
    expect(_kpi(tester, 'members'), '$_memberCounter');
  });
}
