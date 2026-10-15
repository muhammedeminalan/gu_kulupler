// T-41 · Roadmap testi "askıya alınan kullanıcı giriş yapamaz": gerçek
// `GuApp` (rota ağacı, yönlendirme, oturum katmanı, `AppFeedbackService`) +
// sahte servisler. Askı süper adminin yazma yoluyla gelir
// (`AdminRepository.suspendUser` → `users.status` + `private/account`
// gerekçesi, CD-133); başka cihazdaki süper adminin oturum ortasındaki yazımı
// belgeye doğrudan yazılır (sahte, kendi hesabında askıyı reddeder — T-37).
//
//   suspendUser → AUT-01 giriş → oturum kapanır, `/login` + DLG-01
//   activateUser → AUT-01 giriş → kabuk (`/clubs`)
//   oturum açıkken askı → refreshUser (öne gelme) → `/login` + DLG-01
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/bootstrap/gu_app.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/auth/view/login_view.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/navigation/app_router.dart';
import 'package:gu_kulupler/product/navigation/navigator_keys.dart';
import 'package:gu_kulupler/product/navigation/shell/app_shell_view.dart';
import 'package:gu_ui/gu_ui.dart';

import '../fakes/fake_app_preferences_store.dart';
import '../fakes/fake_auth_repository.dart';
import '../fakes/fake_user_repository.dart';
import '../fakes/register_fakes.dart';

const String _email = 'ayse.demir@ogr.gumushane.edu.tr';
const String _password = 'Sifre123';
const String _name = 'Ayşe Demir';
const String _reason = 'Topluluk kurallarının ihlali';

Key _k(String id) => GuKey.action(id);

FakeAuthRepository _auth() => GetIt.I<AuthRepository>() as FakeAuthRepository;

FakeUserRepository _users() => GetIt.I<UserRepository>() as FakeUserRepository;

AdminRepository _admin() => GetIt.I<AdminRepository>();

String get _uid => _auth().service.uid;

/// Sahteleri kaydeder, aktif hesabı hazırlar ve uygulamayı açar (giriş
/// ekranı). Overlay'ler gerçek `AppFeedbackService` ile kök gezgine itilir.
Future<void> _launch(WidgetTester tester, {bool signedIn = false}) async {
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
  (GetIt.I<AppPreferencesStore>() as FakeAppPreferencesStore)
          .values[AppPreferenceKeys.onboardingSeen] =
      true;
  _users().putActive(_uid, name: _name, email: _email);
  _auth().service.emailVerified = true;
  if (signedIn) {
    _auth().currentUser = AuthUserInfo(
      uid: _uid,
      email: _email,
      emailVerified: true,
    );
  }
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(child: GuApp(toastController: toasts)),
  );
  await tester.pumpAndSettle();
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(GuApp)));

String _location(WidgetTester tester) => _container(
  tester,
).read(appRouterProvider).routerDelegate.currentConfiguration.uri.toString();

SessionState _session(WidgetTester tester) =>
    _container(tester).read(sessionViewModelProvider);

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byKey(rootNavigatorKey)));

Future<void> _login(WidgetTester tester) async {
  await tester.enterText(find.byKey(_k('AUT-01.email')), _email);
  await tester.enterText(find.byKey(_k('AUT-01.password')), _password);
  await tester.ensureVisible(find.byKey(_k('AUT-01.login')));
  await tester.pump();
  await tester.tap(find.byKey(_k('AUT-01.login')));
  await tester.pumpAndSettle();
}

/// Askı bildirimi (DLG-01) açık, oturum kapalı, kullanıcı girişte.
void _expectSuspendedAtLogin(WidgetTester tester) {
  expect(_session(tester).status, AuthStatus.signedOut);
  expect(_auth().currentUser, isNull);
  // Oturum ortasında askı `?from=` taşıyabilir (R6): yol giriştir.
  expect(Uri.parse(_location(tester)).path, '/login');
  expect(find.byType(AppShellView), findsNothing);
  expect(
    tester.widget<GuDialogFrame>(find.byType(GuDialogFrame)).title,
    _l10n(tester).dlg01Title,
  );
}

Future<void> _dismissNotice(WidgetTester tester) async {
  await tester.tap(find.byKey(FeedbackKeys.of('DLG-01', 'ok')));
  await tester.pumpAndSettle();
  expect(find.byType(GuDialogFrame), findsNothing);
}

void main() {
  group('T-41 · akış · askıya alınan kullanıcı giriş yapamaz', () {
    testWidgets('süper admin askıya alır (`suspendUser`) → giriş reddedilir '
        '(oturum kapanır, DLG-01); askı kaldırılınca (`activateUser`) giriş '
        'kabuğa gider', (tester) async {
      await _launch(tester);
      expect(_location(tester), '/login');

      expect(
        (await _admin().suspendUser(_uid, reason: _reason)).isSuccess,
        isTrue,
      );
      expect(_users().users[_uid]!.status, UserStatus.suspended);
      expect(_users().accounts[_uid]!.suspendReason, _reason);

      await _login(tester);
      expect(_auth().callsTo('signOut'), hasLength(1));
      _expectSuspendedAtLogin(tester);
      await _dismissNotice(tester);
      expect(find.byType(LoginView), findsOneWidget);

      expect((await _admin().activateUser(_uid)).isSuccess, isTrue);
      expect(_users().users[_uid]!.status, UserStatus.active);
      expect(_users().accounts[_uid]!.suspendReason, isNull);

      await _login(tester);
      expect(_session(tester).status, AuthStatus.active);
      expect(_location(tester), '/clubs');
      expect(find.byType(AppShellView), findsOneWidget);
      // Askı bildirimi yeniden gösterilmez (ilk giriş karşılaması olabilir).
      expect(find.text(_l10n(tester).dlg01Title), findsNothing);
    });

    testWidgets('oturum açıkken askıya alınır: öne gelişte belge yenilenir → '
        'oturum kapanır, girişte DLG-01', (tester) async {
      await _launch(tester, signedIn: true);
      expect(_location(tester), '/clubs');
      expect(_session(tester).status, AuthStatus.active);

      // Başka cihazdaki süper adminin yazımı (CD-133: durum + gerekçe).
      _users().users[_uid] = _users().users[_uid]!.copyWith(
        status: UserStatus.suspended,
      );
      _users().accounts[_uid] = _users().accounts[_uid]!.copyWith(
        suspendReason: _reason,
      );
      await _container(
        tester,
      ).read(sessionViewModelProvider.notifier).refreshUser();
      await tester.pumpAndSettle();

      expect(_auth().callsTo('signOut'), hasLength(1));
      _expectSuspendedAtLogin(tester);
      expect(find.byType(LoginView, skipOffstage: false), findsOneWidget);
      await _dismissNotice(tester);
    });
  });
}
