// T-13 · Uçtan uca kimlik akışı: gerçek `GuApp` (rota ağacı, yönlendirme,
// oturum katmanı, `AppFeedbackService`) + sahte servisler.
//
//   ilk açılış → SYS-01 → ONB-01 → "Başla" → AUT-01
//   AUT-01 → "Kayıt ol" → AUT-02 → AUT-06 "Okudum, anladım" → kayıt → AUT-03
//   AUT-01 başarılı giriş (aktif hesap) → uygulama kabuğu (`/clubs`)
//   askıdaki hesap → oturum kapanır + DLG-01 (giriş sırasında / soğuk açılış)
//   yasal metin `push` / geri (form korunur)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/bootstrap/gu_app.dart';
import 'package:gu_kulupler/core/constants/app_constants.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/auth/view/legal_view.dart';
import 'package:gu_kulupler/features/auth/view/login_view.dart';
import 'package:gu_kulupler/features/auth/view/register_view.dart';
import 'package:gu_kulupler/features/onboarding/view/onboarding_view.dart';
import 'package:gu_kulupler/features/system/view/splash_view.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/navigation/app_router.dart';
import 'package:gu_kulupler/product/navigation/legal_tab.dart';
import 'package:gu_kulupler/product/navigation/navigator_keys.dart';
import 'package:gu_kulupler/product/navigation/routes/route_placeholder_view.dart';
import 'package:gu_kulupler/product/navigation/shell/app_shell_view.dart';
import 'package:gu_kulupler/product/service/url_launcher_service.dart';
import 'package:gu_ui/gu_ui.dart';

import '../fakes/fake_app_preferences_store.dart';
import '../fakes/fake_auth_repository.dart';
import '../fakes/fake_url_launcher_service.dart';
import '../fakes/fake_user_repository.dart';
import '../fakes/register_fakes.dart';

const String _email = 'ayse.demir@ogr.gumushane.edu.tr';
const String _password = 'Sifre123';
const String _name = 'Ayşe Demir';

Key _k(String id) => GuKey.action(id);

FakeAuthRepository _auth() => GetIt.I<AuthRepository>() as FakeAuthRepository;

FakeUserRepository _users() => GetIt.I<UserRepository>() as FakeUserRepository;

FakeAppPreferencesStore _store() =>
    GetIt.I<AppPreferencesStore>() as FakeAppPreferencesStore;

FakeUrlLauncherService _launcher() =>
    GetIt.I<UrlLauncherService>() as FakeUrlLauncherService;

/// Sahte servisleri kaydeder; overlay'ler gerçek `AppFeedbackService` ile kök
/// gezgine itilir (uygulamadaki kayıtla aynı). [arrange] ağaç kurulmadan önce
/// çalışır (hazır oturum, tercihler).
Future<void> _launch(
  WidgetTester tester, {
  bool onboardingSeen = true,
  void Function()? arrange,
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
  _store().values[AppPreferenceKeys.onboardingSeen] = onboardingSeen;
  arrange?.call();
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(child: GuApp(toastController: toasts)),
  );
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(GuApp)));

GoRouter _router(WidgetTester tester) =>
    _container(tester).read(appRouterProvider);

String _location(WidgetTester tester) =>
    _router(tester).routerDelegate.currentConfiguration.uri.toString();

/// `push` ile açılan yasal metnin konumu (taban konum açan ekranda kalır).
String _legalLocation(WidgetTester tester) => GoRouterState.of(
  tester.element(find.byType(LegalView)),
).uri.toString();

SessionState _session(WidgetTester tester) =>
    _container(tester).read(sessionViewModelProvider);

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byKey(rootNavigatorKey)));

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.pump();
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

Future<void> _fillLogin(WidgetTester tester) async {
  await tester.enterText(find.byKey(_k('AUT-01.email')), _email);
  await tester.enterText(find.byKey(_k('AUT-01.password')), _password);
}

/// Profili tamam, aktif `fake-uid` hesabı (doğrulanmış e-posta).
void _arrangeActiveAccount() {
  _users().putActive(_auth().service.uid, name: _name, email: _email);
  _auth().service.emailVerified = true;
}

/// [_arrangeActiveAccount] + `users.status == suspended`.
void _arrangeSuspendedAccount() {
  _arrangeActiveAccount();
  final uid = _auth().service.uid;
  _users().users[uid] = _users().users[uid]!.copyWith(
    status: UserStatus.suspended,
  );
}

void main() {
  group('T-13 · akış · ilk açılış', () {
    testWidgets(
      'SYS-01 → ONB-01 → üç slayt → "Başla" → AUT-01; tanıtım bayrağı '
      'yazılır ve ikinci açılışta tanıtım atlanır',
      (tester) async {
        await _launch(tester, onboardingSeen: false);
        expect(find.byType(SplashView), findsOneWidget);
        expect(_location(tester), '/splash');

        await tester.pumpAndSettle();
        expect(_location(tester), '/onboarding');
        expect(find.byType(OnboardingView), findsOneWidget);
        expect(_session(tester).status, AuthStatus.signedOut);

        await _tap(tester, _k('ONB-01.next'));
        await _tap(tester, _k('ONB-01.next'));
        expect(find.byKey(_k('ONB-01.next')), findsNothing);
        await _tap(tester, _k('ONB-01.start'));

        expect(_location(tester), '/login');
        expect(find.byType(LoginView), findsOneWidget);
        expect(find.byType(OnboardingView), findsNothing);
        expect(_store().values[AppPreferenceKeys.onboardingSeen], isTrue);
        expect(_session(tester).onboardingSeen, isTrue);

        // İkinci açılış: tanıtım görülmüş → doğrudan giriş.
        await _launch(tester);
        await tester.pumpAndSettle();
        expect(_location(tester), '/login');
        expect(find.byType(OnboardingView), findsNothing);
      },
    );

    testWidgets('"Atla" da tanıtımı bitirir ve girişe götürür', (tester) async {
      await _launch(tester, onboardingSeen: false);
      await tester.pumpAndSettle();
      await _tap(tester, _k('ONB-01.skip'));
      expect(_location(tester), '/login');
      expect(_store().values[AppPreferenceKeys.onboardingSeen], isTrue);
    });
  });

  group('T-13 · akış · kayıt', () {
    testWidgets('AUT-01 → "Kayıt ol" → AUT-02 → AUT-06 "Okudum, anladım" onayı '
        'işaretler → kayıt → doğrulanmamış oturum AUT-03’e yönlenir', (
      tester,
    ) async {
      await _launch(tester);
      await tester.pumpAndSettle();
      await _tap(tester, _k('AUT-01.register'));
      expect(_location(tester), '/login/register');
      expect(find.byType(RegisterView), findsOneWidget);

      await tester.enterText(find.byKey(_k('AUT-02.name')), _name);
      await tester.enterText(find.byKey(_k('AUT-02.email')), _email);
      await tester.enterText(find.byKey(_k('AUT-02.password')), _password);
      await tester.enterText(find.byKey(_k('AUT-02.password2')), _password);

      // Onay verilmeden gönderim: hesap açılmaz.
      await _tap(tester, _k('AUT-02.submit'));
      expect(_auth().registered, isEmpty);
      expect(find.text(_l10n(tester).authErrLegal), findsOneWidget);

      // Yasal metin kayıt formundan açılır: altta onay çubuğu vardır.
      await _tap(tester, _k('AUT-02.legal'));
      expect(_legalLocation(tester), '/legal/kvkk?from=register');
      // `push` taban konumu değiştirmez.
      expect(_location(tester), '/login/register');
      final legal = tester.widget<LegalView>(find.byType(LegalView));
      expect(legal.tip, LegalTab.kvkk);
      expect(legal.showAccept, isTrue);
      // Kayıt formu yığında kalır (push).
      expect(find.byType(RegisterView, skipOffstage: false), findsOneWidget);

      await _tap(tester, _k('AUT-06.accept'));
      expect(_location(tester), '/login/register');
      expect(find.byType(LegalView), findsNothing);
      expect(
        tester.widget<GuCheckbox>(find.byKey(_k('AUT-02.legalCheck'))).value,
        isTrue,
      );
      expect(find.text(_l10n(tester).authErrLegal), findsNothing);

      await _tap(tester, _k('AUT-02.submit'));
      expect(_auth().registered, [
        (email: _email, password: _password, name: _name),
      ]);
      // Ad kimlik hesabında taşınır; profil belgesi oluşturulmaz (CD-134).
      expect(_auth().currentUser?.displayName, _name);
      expect(_users().callsTo('createProfile'), isEmpty);
      expect(_session(tester).status, AuthStatus.unverified);
      expect(_location(tester), '/verify');
      expect(find.byType(RegisterView), findsNothing);
      // AUT-03 T-14'te gelir (W-02, W-06): şimdilik yer tutucu.
      expect(find.byType(RoutePlaceholderView), findsOneWidget);
    });

    testWidgets('AUT-02 geri → AUT-01; "Giriş yap" → AUT-01', (tester) async {
      await _launch(tester);
      await tester.pumpAndSettle();
      await _tap(tester, _k('AUT-01.register'));
      await _tap(tester, _k('AUT-02.back'));
      expect(_location(tester), '/login');

      await _tap(tester, _k('AUT-01.register'));
      await _tap(tester, _k('AUT-02.toLogin'));
      expect(_location(tester), '/login');
      expect(find.byType(RegisterView), findsNothing);
    });
  });

  group('T-13 · akış · giriş', () {
    testWidgets('aktif hesap: AUT-01 → uygulama kabuğu (`/clubs`); son giriş '
        'anı yazılır', (tester) async {
      await _launch(tester, arrange: _arrangeActiveAccount);
      await tester.pumpAndSettle();
      expect(_location(tester), '/login');

      await _fillLogin(tester);
      await _tap(tester, _k('AUT-01.login'));

      expect(_auth().signInAttempts, [(email: _email, password: _password)]);
      expect(_session(tester).status, AuthStatus.active);
      expect(_session(tester).user?.name, _name);
      expect(_location(tester), '/clubs');
      expect(find.byType(AppShellView), findsOneWidget);
      expect(find.byKey(_k('NAV.tab.clubs')), findsOneWidget);
      expect(find.byType(LoginView), findsNothing);
      expect(_users().lastLoginTouches, [_auth().service.uid]);
    });

    testWidgets('hazır oturumla açılış: SYS-01 → doğrudan kabuk', (
      tester,
    ) async {
      await _launch(
        tester,
        arrange: () {
          _arrangeActiveAccount();
          _auth().currentUser = AuthUserInfo(
            uid: _auth().service.uid,
            email: _email,
            emailVerified: true,
          );
        },
      );
      expect(find.byType(SplashView), findsOneWidget);
      await tester.pumpAndSettle();
      expect(_location(tester), '/clubs');
      expect(find.byType(AppShellView), findsOneWidget);
    });

    testWidgets('hatalı şifre: TST-01 gösterilir, ekran yerinde kalır', (
      tester,
    ) async {
      await _launch(tester, arrange: _arrangeActiveAccount);
      await tester.pumpAndSettle();
      _auth().service.failNext(AuthError.invalidCredentials);
      await _fillLogin(tester);
      await tester.tap(find.byKey(_k('AUT-01.login')));
      await tester.pump();
      await tester.pump(GuMotion.base);

      final l10n = _l10n(tester);
      expect(find.text(l10n.tst01), findsOneWidget);
      expect(find.text(l10n.authErrWrong), findsOneWidget);
      expect(_location(tester), '/login');
      expect(_session(tester).status, AuthStatus.signedOut);
      // Toast süresi dolsun (bekleyen zamanlayıcı kalmasın).
      await tester.pump(GuMotion.toastDefault);
      await tester.pumpAndSettle();
    });
  });

  group('T-13 · akış · askıdaki hesap (W-03)', () {
    testWidgets('giriş: oturum kapatılır, kullanıcı girişte kalır ve DLG-01 '
        'gösterilir; "Tamam" kapatır', (tester) async {
      await _launch(tester, arrange: _arrangeSuspendedAccount);
      await tester.pumpAndSettle();
      await _fillLogin(tester);
      await _tap(tester, _k('AUT-01.login'));

      final l10n = _l10n(tester);
      expect(_auth().callsTo('signOut'), hasLength(1));
      expect(_auth().currentUser, isNull);
      expect(_session(tester).status, AuthStatus.signedOut);
      expect(_location(tester), '/login');
      expect(find.byType(AppShellView), findsNothing);
      final dialog = tester.widget<GuDialogFrame>(find.byType(GuDialogFrame));
      expect(dialog.title, l10n.dlg01Title);
      expect(dialog.body, l10n.dlg01Body);

      await tester.tap(find.byKey(FeedbackKeys.of('DLG-01', 'ok')));
      await tester.pumpAndSettle();
      expect(find.byType(GuDialogFrame), findsNothing);
      expect(find.byType(LoginView), findsOneWidget);
      expect(_launcher().opened, isEmpty);
      // Form yeniden kullanılabilir: düğme meşgul değil.
      expect(
        tester.widget<GuButton>(find.byKey(_k('AUT-01.login'))).loading,
        isFalse,
      );
    });

    testWidgets('"Destekle iletişime geç" destek adresine e-posta açar', (
      tester,
    ) async {
      await _launch(tester, arrange: _arrangeSuspendedAccount);
      await tester.pumpAndSettle();
      await _fillLogin(tester);
      await _tap(tester, _k('AUT-01.login'));

      await tester.tap(find.byKey(FeedbackKeys.of('DLG-01', 'support')));
      await tester.pumpAndSettle();
      expect(find.byType(GuDialogFrame), findsNothing);
      expect(_launcher().opened, [AppConstants.supportMailUri]);
    });

    testWidgets('soğuk açılış (hazır oturum askıda): SYS-01 → giriş; DLG-01 '
        'yönlendirmeden sonra giriş ekranının üstünde gösterilir', (
      tester,
    ) async {
      await _launch(
        tester,
        arrange: () {
          _arrangeSuspendedAccount();
          _auth().currentUser = AuthUserInfo(
            uid: _auth().service.uid,
            email: _email,
            emailVerified: true,
          );
        },
      );
      expect(find.byType(SplashView), findsOneWidget);
      await tester.pumpAndSettle();

      expect(_auth().callsTo('signOut'), hasLength(1));
      expect(_session(tester).status, AuthStatus.signedOut);
      expect(_location(tester), '/login');
      expect(find.byType(LoginView, skipOffstage: false), findsOneWidget);
      expect(
        tester.widget<GuDialogFrame>(find.byType(GuDialogFrame)).title,
        _l10n(tester).dlg01Title,
      );

      // Scrim de kapatır; bildirim yeniden gösterilmez.
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      expect(find.byType(GuDialogFrame), findsNothing);
    });

    testWidgets('kimlik hesabı devre dışı (userDisabled): giriş reddedilir ve '
        'DLG-01 gösterilir', (tester) async {
      await _launch(tester, arrange: _arrangeActiveAccount);
      await tester.pumpAndSettle();
      _auth().service.failNext(AuthError.userDisabled);
      await _fillLogin(tester);
      await _tap(tester, _k('AUT-01.login'));

      expect(_location(tester), '/login');
      expect(_session(tester).status, AuthStatus.signedOut);
      expect(find.byType(GuDialogFrame), findsOneWidget);
      await tester.tap(find.byKey(FeedbackKeys.of('DLG-01', 'ok')));
      await tester.pumpAndSettle();
      expect(find.byType(GuDialogFrame), findsNothing);
    });
  });

  group('T-13 · akış · yasal metin', () {
    testWidgets('AUT-01 bağlantıları AUT-06’yı `push` ile açar; geri AUT-01’e '
        'döner ve form korunur', (tester) async {
      await _launch(tester);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(_k('AUT-01.email')), _email);

      for (final (action, tab) in [
        ('AUT-01.terms', LegalTab.kosullar),
        ('AUT-01.privacy', LegalTab.gizlilik),
      ]) {
        await _tap(tester, _k(action));
        expect(_legalLocation(tester), '/legal/${tab.name}');
        expect(_location(tester), '/login');
        final legal = tester.widget<LegalView>(find.byType(LegalView));
        expect(legal.tip, tab);
        // Girişten açılan yasal metinde onay çubuğu yoktur.
        expect(legal.showAccept, isFalse);
        expect(find.byKey(_k('AUT-06.accept')), findsNothing);
        expect(find.byType(LoginView, skipOffstage: false), findsOneWidget);

        await _tap(tester, _k('AUT-06.back'));
        expect(_location(tester), '/login');
        expect(find.byType(LegalView), findsNothing);
        expect(find.text(_email), findsOneWidget);
      }
    });

    testWidgets('AUT-06 sekme değişimi ve sistem geri tuşu', (tester) async {
      await _launch(tester);
      await tester.pumpAndSettle();
      await _tap(tester, _k('AUT-01.terms'));
      await _tap(tester, _k('AUT-06.tab.kvkk'));
      expect(find.text(_l10n(tester).legalKvkkTitle), findsWidgets);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_location(tester), '/login');
      expect(find.byType(LoginView), findsOneWidget);
    });
  });
}
