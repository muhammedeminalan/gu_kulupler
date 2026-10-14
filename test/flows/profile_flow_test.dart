// T-27 · Uçtan uca profil akışı: gerçek `GuApp` (rota ağacı, yönlendirme,
// oturum katmanı, kabuk) + sahte servisler (`FakeFeedbackService` dialog /
// menü / toast sonuçlarını verir). Oturum hazırdır (`u_mehmet`; `c01` ve
// `c07` üyesi, `c06` bekleyen başvuru, `c05` reddedildi; iki kayıtlı gönderi).
//
//   giriş → Profil sekmesi (PRF-01) → "Profili düzenle" (PRF-02) → biyografi
//   değişir → geri → DLG-25 → "Kaydet" → TST-21, PRF-01 → "Tümü" (PRF-03) →
//   Bekleyen sekmesi → ⋮ "İsteği iptal et" → DLG-07 → TST-40 → geri →
//   "Kaydedilenler" (PRF-04) → kaydı kaldır → TST-11 → Geri al → Kulüpler
//   sekmesi (CLB-01) → "Kulüplerim → Tümü" → PRF-03 (W-18)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/bootstrap/gu_app.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/profile/provider/my_clubs_view_model.dart';
import 'package:gu_kulupler/features/profile/view/edit_profile_view.dart';
import 'package:gu_kulupler/features/profile/view/my_clubs_view.dart';
import 'package:gu_kulupler/features/profile/view/profile_view.dart';
import 'package:gu_kulupler/features/profile/view/saved_view.dart';
import 'package:gu_kulupler/features/profile/view/widget/my_club_menu.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/unsaved_changes_dialog.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/navigation/app_router.dart';
import 'package:gu_kulupler/product/navigation/my_clubs_tab.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../fakes/fake_app_preferences_store.dart';
import '../fakes/fake_auth_repository.dart';
import '../fakes/fake_feedback_service.dart';
import '../fakes/fake_membership_repository.dart';
import '../fakes/fake_saved_post_repository.dart';
import '../fakes/fake_user_repository.dart';
import '../fakes/register_fakes.dart';
import '../features/profile/my_clubs_test_support.dart';
import '../features/profile/profile_test_support.dart';
import '../features/profile/saved_test_support.dart';
import '../helpers/test_asset_bundle.dart';

const String _email = 'mehmet.kaya@ogr.gumushane.edu.tr';
const String _bio = 'Elektronik ve robotik meraklısı.';

Key _k(String id) => GuKey.action(id);

FakeFeedbackService _feedback() =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;

FakeUserRepository _users() => GetIt.I<UserRepository>() as FakeUserRepository;

Future<void> _launch(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await GetIt.I.reset();
  registerDefaultFakes();
  addTearDown(GetIt.I.reset);
  final toasts = GuToastController();
  addTearDown(toasts.dispose);
  (GetIt.I<AuthRepository>() as FakeAuthRepository)
    ..service.uid = kProfileUid
    ..service.emailVerified = true
    ..currentUser = const AuthUserInfo(
      uid: kProfileUid,
      email: _email,
      emailVerified: true,
    );
  _users().putActive(kProfileUid, email: _email);
  seedProfile();
  seedMyClubs();
  seedSaved();
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

String _location(WidgetTester tester) => _container(
  tester,
).read(appRouterProvider).routerDelegate.currentConfiguration.uri.toString();

Future<void> _tap(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_GB');
    await initializeDateFormatting('en_US');
  });

  testWidgets('Profil → düzenle + DLG-25 kaydet → Kulüplerim bekleyen iptal '
      '→ Kaydedilenler kaldır + geri al → CLB-01 "Kulüplerim" → PRF-03', (
    tester,
  ) async {
    await _launch(tester);
    final feedback = _feedback();

    // Profil sekmesi (PRF-01).
    await _tap(tester, _k('NAV.tab.profile'));
    expect(_location(tester), '/profile');
    expect(find.byType(ProfileView), findsOneWidget);
    expect(find.text(kProfileUser.name), findsOneWidget);

    // PRF-02: biyografi değişir; geri → DLG-25 "Kaydet" → TST-21.
    await _tap(tester, _k('PRF-01.edit'));
    expect(_location(tester), '/profile/edit');
    expect(find.byType(EditProfileView), findsOneWidget);
    await tester.enterText(find.byKey(_k('PRF-02.bio')), _bio);
    await tester.pump();
    feedback.dialogResults[DialogId.dlg25] = UnsavedChangesResult.save;
    await _tap(tester, _k('PRF-02.back'));
    expect(feedback.dialogs, [DialogId.dlg25]);
    expect(feedback.toasts, [ToastId.tst21]);
    expect(_users().profilePatches.single.patch.bio, _bio);
    expect(_users().users[kProfileUid]!.bio, _bio);
    expect(_location(tester), '/profile');

    // PRF-03: Bekleyen sekmesi → ⋮ "İsteği iptal et" → DLG-07 → TST-40.
    await _tap(tester, _k('PRF-01.allClubs'));
    expect(_location(tester), '/profile/clubs');
    expect(find.byType(MyClubsView), findsOneWidget);
    await _tap(tester, _k('PRF-03.tab.pending'));
    final myClubs = ProviderScope.containerOf(
      tester.element(find.byType(MyClubsView)),
    );
    expect(myClubs.read(myClubsViewModelProvider).tab, MyClubsTab.pending);
    feedback
      ..nextMenuResult = MyClubMenuAction.cancel
      ..dialogResults[DialogId.dlg07] = true;
    await _tap(tester, _k('PRF-03.menu.c06'));
    expect(feedback.dialogs, [DialogId.dlg25, DialogId.dlg07]);
    expect(feedback.toasts.last, ToastId.tst40);
    final memberships =
        GetIt.I<MembershipRepository>() as FakeMembershipRepository;
    expect(
      memberships.memberships['c06_$kProfileUid']!.status,
      MembershipStatus.cancelled,
    );
    expect(find.byKey(_k('PRF-03.row.c06')), findsNothing);
    feedback.nextMenuResult = null;

    // PRF-04: kaydı kaldır → TST-11 → Geri al.
    await _tap(tester, _k('PRF-03.back'));
    expect(_location(tester), '/profile');
    await _tap(tester, _k('PRF-01.saved'));
    expect(_location(tester), '/profile/saved');
    expect(find.byType(SavedView), findsOneWidget);
    await _tap(tester, _k('PRF-04.unsave.p01'));
    expect(feedback.toasts.last, ToastId.tst11);
    expect(find.byKey(_k('PRF-04.post.p01')), findsNothing);
    final saved = GetIt.I<SavedPostRepository>() as FakeSavedPostRepository;
    expect(saved.saved['${kProfileUid}_p01']!.isDeleted, isTrue);
    feedback.tapToastAction();
    await tester.pumpAndSettle();
    expect(saved.saved['${kProfileUid}_p01']!.isDeleted, isFalse);
    expect(find.byKey(_k('PRF-04.post.p01')), findsOneWidget);

    // CLB-01 "Kulüplerim → Tümü" → PRF-03 (Profil sekmesi, W-18). Alt
    // çubuk yalnızca sekme kökünde görünür.
    await _tap(tester, _k('PRF-04.back'));
    expect(_location(tester), '/profile');
    await _tap(tester, _k('NAV.tab.clubs'));
    expect(_location(tester), '/clubs');
    await _tap(tester, _k('CLB-01.myClubsAll'));
    expect(_location(tester), '/profile/clubs');
    expect(find.byType(MyClubsView), findsOneWidget);
  });
}
