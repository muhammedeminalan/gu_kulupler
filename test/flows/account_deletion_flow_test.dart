// T-29 · Uçtan uca hesap silme akışı: gerçek `GuApp` (rota ağacı,
// yönlendirme, oturum katmanı, kabuk, `AppFeedbackService` — toast gerçekten
// çizilir) + sahte servisler. Oturum hazırdır (`u_mehmet`, demo üyelikleri).
//
//   Profil (PRF-01) → ⚙ → Ayarlar (SET-01) → "Hesabı sil" (W-33) → SET-03
//   1/3 → Devam → 2/3 (neden) → Devam → 3/3 şifre + "sil" → "Hesabımı kalıcı
//   olarak sil" → yeniden doğrulama + anonimleştirme + üyelikler `left` →
//   oturum kapanır → giriş ekranı (AUT-01) + TST-22. Aynı hesapla yeniden
//   giriş → silinmiş hesap engeli (oturum yine kapanır, TST-22).
//   Başkan kullanıcıda 1/3 → Devam kapalı → TST-X10, ekran değişmez.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/bootstrap/gu_app.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/auth/view/login_view.dart';
import 'package:gu_kulupler/features/settings/view/delete_account_view.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/navigation/app_router.dart';
import 'package:gu_kulupler/product/navigation/navigator_keys.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../fakes/fake_app_preferences_store.dart';
import '../fakes/fake_auth_repository.dart';
import '../fakes/fake_membership_repository.dart';
import '../fakes/fake_user_repository.dart';
import '../fakes/register_fakes.dart';
import '../features/profile/profile_test_support.dart';
import '../helpers/test_asset_bundle.dart';

const String _email = 'mehmet.kaya@ogr.gumushane.edu.tr';
const String _password = 'Demo1234!';

Key _k(String id) => GuKey.action(id);

FakeAuthRepository _auth() => GetIt.I<AuthRepository>() as FakeAuthRepository;

FakeUserRepository _users() => GetIt.I<UserRepository>() as FakeUserRepository;

FakeMembershipRepository _memberships() =>
    GetIt.I<MembershipRepository>() as FakeMembershipRepository;

Future<void> _launch(
  WidgetTester tester, {
  Map<String, ClubRole> roles = const {},
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
  _auth()
    ..service.uid = kProfileUid
    ..service.emailVerified = true
    ..currentUser = const AuthUserInfo(
      uid: kProfileUid,
      email: _email,
      emailVerified: true,
    );
  _users().putActive(kProfileUid, email: _email);
  seedProfile();
  for (final membership in profileMembershipsWithRoles(roles)) {
    _memberships().put(membership, email: _email, note: 'Başvuru notu.');
  }
  (GetIt.I<AppPreferencesStore>() as FakeAppPreferencesStore).values
    ..[AppPreferenceKeys.onboardingSeen] = true
    ..[AppPreferenceKeys.notificationPermissionAsked] = true;
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

/// PRF-01 → SET-01 → SET-03 (W-32, W-33).
Future<void> _openDeleteAccount(WidgetTester tester) async {
  await _tap(tester, _k('NAV.tab.profile'));
  await _tap(tester, _k('PRF-01.settings'));
  await _tap(tester, _k('SET-01.delete'));
  expect(_location(tester), '/profile/settings/delete');
  expect(find.byType(DeleteAccountView), findsOneWidget);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_GB');
    await initializeDateFormatting('en_US');
  });

  testWidgets('T-29 · Profil → Ayarlar → Hesabı sil → 1/3 → 2/3 → şifre + '
      'SİL → anonimleştirme → AUT-01 + TST-22; yeniden giriş engellenir', (
    tester,
  ) async {
    await _launch(tester);
    await _openDeleteAccount(tester);

    await _tap(tester, _k('SET-03.next'));
    await _tap(tester, _k('SET-03.reason.graduated'));
    await _tap(tester, _k('SET-03.next'));
    expect(find.text('3/3'), findsOneWidget);
    await tester.enterText(find.byKey(_k('SET-03.password')), _password);
    await tester.enterText(find.byKey(_k('SET-03.confirmWord')), 'sil');
    await tester.pump();
    await _tap(tester, _k('SET-03.confirm'));

    // Silindi: profil anonim, üyelikler kapandı, oturum kapandı → AUT-01.
    final user = _users().users[kProfileUid]!;
    expect(user.name, Anonymization.deletedUserName);
    expect(user.status, UserStatus.deleted);
    expect(_users().accounts[kProfileUid]!.email, isEmpty);
    for (final membership in _memberships().memberships.values) {
      expect(
        membership.status,
        isNot(MembershipStatus.active),
        reason: membership.id,
      );
      expect(
        membership.applicant,
        FirebaseMembershipRepository.anonymizedApplicant,
      );
    }
    expect(_auth().callsTo('reauthenticate').single.args, [_password]);
    expect(
      _container(tester).read(sessionViewModelProvider).status,
      AuthStatus.signedOut,
    );
    expect(_location(tester), startsWith('/login'));
    expect(find.byType(LoginView), findsOneWidget);
    expect(_toast(ToastId.tst22), findsOneWidget);

    // Silinmiş hesapla giriş: kimlik doğrulanır ama oturum hemen kapanır
    // (Q-11; giriş engeli), giriş ekranında kalınır.
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    final signIn = await _auth().signIn(email: _email, password: _password);
    expect(signIn.isSuccess, isTrue);
    await tester.pumpAndSettle();
    expect(
      _container(tester).read(sessionViewModelProvider).status,
      AuthStatus.signedOut,
    );
    expect(find.byType(LoginView), findsOneWidget);
    expect(_toast(ToastId.tst22), findsOneWidget);
  });

  testWidgets('T-29 · TST-X10 · başkan kullanıcı: 1/3 → Devam kapalı → '
      'TST-X10; adım ilerlemez, hiçbir şey yazılmaz', (tester) async {
    await _launch(tester, roles: const {'c01': ClubRole.president});
    await _openDeleteAccount(tester);

    expect(find.byKey(_k('SET-03.transfer.c01')), findsOneWidget);
    await _tap(tester, _k('SET-03.next'));
    expect(_toast(ToastId.tstX10), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);
    expect(_users().users[kProfileUid]!.status, UserStatus.active);
    expect(_auth().callsTo('reauthenticate'), isEmpty);
  });
}
