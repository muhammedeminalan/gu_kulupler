// T-13 · Uçtan uca kimlik akışı: gerçek `GuApp` (rota ağacı, yönlendirme,
// oturum katmanı, `AppFeedbackService`) + sahte servisler.
//
//   ilk açılış → SYS-01 → ONB-01 → "Başla" → AUT-01
//   AUT-01 → "Kayıt ol" → AUT-02 → AUT-06 "Okudum, anladım" → kayıt → AUT-03
//   AUT-01 başarılı giriş (aktif hesap) → uygulama kabuğu (`/clubs`)
//   askıdaki hesap → oturum kapanır + DLG-01 (giriş sırasında / soğuk açılış)
//   yasal metin `push` / geri (form korunur)
//
// T-14 · devamı (W-02, W-05, W-06, W-56, W-57):
//   kayıt → AUT-03 "Doğruladım" (doğrulanmamış → TST-02; doğrulanınca başarı
//   görünümü) → AUT-05 üç adım (SHT-16 + DLG-05, SHT-02, SHT-03) → "Tamamla"
//   → createProfile → updateProfile → updateAvatar → TST-05 → `/clubs` →
//   DLG-03 (ilk aktif giriş, bir kez)
//   AUT-03 "Çıkış yap" / "E-postayı değiştir" → DLG-06 → oturum kapanır
//   AUT-01 "Şifremi unuttum" → AUT-04 → gönder → "Tekrar gönder" (TST-X3 →
//   TST-03) → "Girişe dön"
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
import 'package:gu_kulupler/features/auth/provider/verify_email_view_model.dart';
import 'package:gu_kulupler/features/auth/view/legal_view.dart';
import 'package:gu_kulupler/features/auth/view/login_view.dart';
import 'package:gu_kulupler/features/auth/view/register_view.dart';
import 'package:gu_kulupler/features/auth/view/reset_password_view.dart';
import 'package:gu_kulupler/features/auth/view/setup_profile_view.dart';
import 'package:gu_kulupler/features/auth/view/verify_email_view.dart';
import 'package:gu_kulupler/features/auth/view/widget/setup_profile_interests_step.dart';
import 'package:gu_kulupler/features/onboarding/view/onboarding_view.dart';
import 'package:gu_kulupler/features/system/view/splash_view.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/department_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/photo_source_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/year_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/navigation/app_router.dart';
import 'package:gu_kulupler/product/navigation/legal_tab.dart';
import 'package:gu_kulupler/product/navigation/navigator_keys.dart';
import 'package:gu_kulupler/product/navigation/shell/app_shell_view.dart';
import 'package:gu_kulupler/product/service/image_picker_service.dart';
import 'package:gu_kulupler/product/service/permission_service.dart';
import 'package:gu_kulupler/product/service/url_launcher_service.dart';
import 'package:gu_ui/gu_ui.dart';

import '../fakes/fake_app_preferences_store.dart';
import '../fakes/fake_auth_repository.dart';
import '../fakes/fake_image_picker_service.dart';
import '../fakes/fake_permission_service.dart';
import '../fakes/fake_url_launcher_service.dart';
import '../fakes/fake_user_repository.dart';
import '../fakes/register_fakes.dart';
import '../helpers/fake_app_clock.dart';

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

FakeImagePickerService _picker() =>
    GetIt.I<ImagePickerService>() as FakeImagePickerService;

FakePermissionService _permissions() =>
    GetIt.I<PermissionService>() as FakePermissionService;

FakeAppClock _clock() => GetIt.I<AppClock>() as FakeAppClock;

Finder _toast(ToastId id) => find.byKey(ValueKey<ToastId>(id));

/// Görünen toast'ın süresini doldurur (test sonunda bekleyen zamanlayıcı
/// kalmasın).
Future<void> _flushToast(WidgetTester tester) async {
  await tester.pump(GuMotion.toastUndo);
  await tester.pumpAndSettle();
}

/// Saati ve ekrandaki geri sayımı [by] kadar ilerletir (saniyelik adımlarla).
Future<void> _elapse(WidgetTester tester, Duration by) async {
  for (var i = 0; i < by.inSeconds; i++) {
    _clock().advance(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }
}

/// AUT-01 → AUT-02: formu doldurur, yasal onayı verir ve hesabı açar. Sonuç:
/// doğrulanmamış oturum, AUT-03 (`/verify`).
Future<void> _register(WidgetTester tester) async {
  await _tap(tester, _k('AUT-01.register'));
  await tester.enterText(find.byKey(_k('AUT-02.name')), _name);
  await tester.enterText(find.byKey(_k('AUT-02.email')), _email);
  await tester.enterText(find.byKey(_k('AUT-02.password')), _password);
  await tester.enterText(find.byKey(_k('AUT-02.password2')), _password);
  await _tap(tester, _k('AUT-02.legal'));
  await _tap(tester, _k('AUT-06.accept'));
  await _tap(tester, _k('AUT-02.submit'));
}

/// Yalnızca profil yazımları, çağrı sırasıyla (W-56, W-57).
List<String> _profileWrites() => [
  for (final call in _users().calls)
    if (const {
      'createProfile',
      'updateProfile',
      'updateAvatar',
    }.contains(call.method))
      call.method,
];

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
      expect(find.byType(VerifyEmailView), findsOneWidget);
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

  group('T-14 · akış · kayıt → doğrulama → profil → kabuk', () {
    testWidgets('kayıt → AUT-03: doğrulanmamışken "Doğruladım" TST-02 '
        'gösterir; doğrulanınca başarı görünümü → AUT-05 üç adım → "Tamamla" '
        '→ createProfile → updateProfile → updateAvatar → TST-05 → kabuk; '
        'ilk aktif girişte DLG-03', (tester) async {
      await _launch(tester);
      await tester.pumpAndSettle();
      await _register(tester);
      final l10n = _l10n(tester);
      final uid = _auth().service.uid;

      // W-06 · kayıt sonrası AUT-03; sistem geri tuşu ekrandan çıkarmaz.
      expect(_location(tester), '/verify');
      expect(find.byType(VerifyEmailView), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_location(tester), '/verify');
      expect(_session(tester).status, AuthStatus.unverified);

      // Bağlantıya tıklanmadan "Doğruladım": TST-02, profil belgesi yok.
      await _tap(tester, _k('AUT-03.confirm'));
      expect(_auth().callsTo('reloadUser'), hasLength(1));
      expect(_toast(ToastId.tst02), findsOneWidget);
      expect(find.text(l10n.tst02), findsOneWidget);
      expect(_location(tester), '/verify');
      expect(_session(tester).status, AuthStatus.unverified);
      expect(_profileWrites(), isEmpty);
      // Toast alt kenarda durur; süresi dolmadan alttaki sayfa satırlarını
      // örter.
      await _flushToast(tester);

      // Bağlantıya tıklandı: başarı görünümü, ardından oturum yeniden çözülür
      // (W-56c) ve router AUT-05'e taşır (W-02).
      _auth().service.emailVerified = true;
      await tester.tap(find.byKey(_k('AUT-03.confirm')));
      await tester.pump();
      await tester.pump();
      expect(find.text(l10n.authVerifySuccess), findsOneWidget);
      expect(find.byKey(_k('AUT-03.confirm')), findsNothing);
      expect(_location(tester), '/verify');
      await tester.pump(VerifyEmailViewModel.successHold);
      await tester.pumpAndSettle();

      expect(_session(tester).status, AuthStatus.profileIncomplete);
      expect(_session(tester).user, isNull);
      expect(_location(tester), '/setup-profile');
      expect(find.byType(SetupProfileView), findsOneWidget);
      expect(find.byType(VerifyEmailView), findsNothing);
      // W-56a · profil belgesi doğrulamadan sonra da hemen oluşturulmaz.
      expect(_profileWrites(), isEmpty);

      // 1 · fotoğraf: SHT-16 → galeri → DLG-05 "İzin ver" → sistem seçicisi.
      await _tap(tester, _k('AUT-05.photo'));
      expect(find.byType(PhotoSourceSheet), findsOneWidget);
      await _tap(tester, PhotoSourceSheet.keyOf(PhotoSourceChoice.gallery));
      expect(find.byType(PhotoSourceSheet), findsNothing);
      expect(
        tester.widget<GuDialogFrame>(find.byType(GuDialogFrame)).title,
        l10n.dlg05Title,
      );
      await _tap(tester, FeedbackKeys.of('DLG-05', 'allow'));
      expect(find.byType(GuDialogFrame), findsNothing);
      expect(_picker().picks, [MediaSource.gallery]);
      // Galeri için sistem izni istenmez (CD-16).
      expect(_permissions().requested, isEmpty);
      expect(find.text(l10n.authSetupPhotoAdded), findsOneWidget);
      await _tap(tester, _k('AUT-05.next'));

      // 2 · bölüm (SHT-02) ve sınıf (SHT-03).
      await _tap(tester, _k('AUT-05.department'));
      await _tap(tester, DepartmentPickerSheet.keyOf('d02'));
      await _tap(tester, _k('AUT-05.year'));
      await _tap(tester, YearPickerSheet.keyOf(YearLevel.second));
      await _tap(tester, _k('AUT-05.next'));

      // 3 · ilgi alanları ve gönderim.
      await _tap(tester, SetupProfileInterestsStep.keyOf('i05'));
      await _tap(tester, SetupProfileInterestsStep.keyOf('i01'));
      expect(_profileWrites(), isEmpty);
      await _tap(tester, _k('AUT-05.finish'));

      // W-56 / W-57 · yazım sırası ve yükler. Yama, Rules sözleşmesindeki
      // "AUT-05 tamamlama" adımıyla aynı alan kümesidir
      // (firebase/test/contracts/repository_payloads.json `aut05`).
      expect(_profileWrites(), [
        'createProfile',
        'updateProfile',
        'updateAvatar',
      ]);
      expect(_users().createdProfiles, [
        (
          uid: uid,
          email: _email,
          name: _name,
          nameLower: 'ayşe demir',
          avatarSeed: uid,
        ),
      ]);
      expect(_users().profilePatches, [
        (
          uid: uid,
          patch: const UserProfilePatch(
            department: 'd02',
            year: YearLevel.second,
            interests: ['i01', 'i05'],
            profileComplete: true,
          ),
        ),
      ]);
      final upload = _users().avatarUploads.single;
      expect(upload.uid, uid);
      expect(upload.bytes, kFakeJpeg.bytes);
      expect(upload.contentType, 'image/jpeg');
      // Fotoğraf yamasız yazılır: profil bir önceki adımda tamamlandı.
      expect(upload.profile, isNull);
      expect(StoragePaths.isUserAvatar(upload.path, uid), isTrue);

      final user = _users().users[uid]!;
      expect(user.name, _name);
      expect(user.profileComplete, isTrue);
      expect(user.avatarPath, upload.path);
      expect(_users().accounts[uid]!.email, _email);

      // Oturum `active`: router kabuğa taşır; karşılama toast'ı görünür.
      expect(_session(tester).status, AuthStatus.active);
      expect(_session(tester).user?.avatarPath, upload.path);
      expect(_location(tester), '/clubs');
      expect(find.byType(AppShellView), findsOneWidget);
      expect(find.byType(SetupProfileView), findsNothing);
      expect(_toast(ToastId.tst05), findsOneWidget);
      expect(find.text(l10n.tst05('Ayşe')), findsOneWidget);

      // İlk aktif giriş: bildirim ön izni bir kez sorulur.
      expect(
        tester.widget<GuDialogFrame>(find.byType(GuDialogFrame)).title,
        l10n.dlg03Title,
      );
      await _tap(tester, FeedbackKeys.of('DLG-03', 'notNow'));
      expect(find.byType(GuDialogFrame), findsNothing);
      expect(_permissions().requested, isEmpty);
      expect(_store().notificationPermissionAsked, isTrue);
      await _flushToast(tester);
    });

    testWidgets('AUT-03 "Çıkış yap" → DLG-06: "Vazgeç" ekranda bırakır; '
        '"Çıkış yap" oturumu kapatır ve girişe döner', (tester) async {
      await _launch(tester);
      await tester.pumpAndSettle();
      await _register(tester);
      final l10n = _l10n(tester);
      expect(_location(tester), '/verify');

      await _tap(tester, _k('AUT-03.logout'));
      expect(
        tester.widget<GuDialogFrame>(find.byType(GuDialogFrame)).title,
        l10n.dlg06Title,
      );
      await _tap(tester, FeedbackKeys.of('DLG-06', 'cancel'));
      expect(find.byType(GuDialogFrame), findsNothing);
      expect(_auth().callsTo('signOut'), isEmpty);
      expect(_location(tester), '/verify');

      await _tap(tester, _k('AUT-03.logout'));
      await _tap(tester, FeedbackKeys.of('DLG-06', 'logout'));

      expect(_auth().callsTo('signOut'), hasLength(1));
      expect(_auth().currentUser, isNull);
      expect(_session(tester).status, AuthStatus.signedOut);
      expect(_location(tester), '/login');
      expect(find.byType(LoginView), findsOneWidget);
      expect(find.byType(VerifyEmailView), findsNothing);
      expect(_profileWrites(), isEmpty);
    });

    testWidgets('AUT-03 "E-postayı değiştir" de DLG-06 ile çıkış yaptırır '
        '(yeni adresle yeniden kayıt)', (tester) async {
      await _launch(tester);
      await tester.pumpAndSettle();
      await _register(tester);

      await _tap(tester, _k('AUT-03.changeEmail'));
      expect(
        tester.widget<GuDialogFrame>(find.byType(GuDialogFrame)).title,
        _l10n(tester).dlg06Title,
      );
      await _tap(tester, FeedbackKeys.of('DLG-06', 'logout'));

      expect(_session(tester).status, AuthStatus.signedOut);
      expect(_location(tester), '/login');
    });
  });

  group('T-14 · akış · şifre sıfırlama (W-05)', () {
    testWidgets('AUT-01 "Şifremi unuttum" → AUT-04 → gönder → gönderildi '
        'görünümü; bekleme sürerken "Tekrar gönder" TST-X3, dolunca TST-03; '
        '"Girişe dön" → AUT-01', (tester) async {
      await _launch(tester);
      await tester.pumpAndSettle();
      final l10n = _l10n(tester);

      await _tap(tester, _k('AUT-01.forgot'));
      expect(_location(tester), '/login/reset');
      expect(find.byType(ResetPasswordView), findsOneWidget);

      // Geri: AUT-01; oturum durumu değişmez.
      await _tap(tester, _k('AUT-04.back'));
      expect(_location(tester), '/login');
      expect(find.byType(ResetPasswordView), findsNothing);

      await _tap(tester, _k('AUT-01.forgot'));
      await tester.enterText(find.byKey(_k('AUT-04.email')), _email);
      await _tap(tester, _k('AUT-04.send'));

      expect(_auth().resetSent, [_email]);
      expect(find.text(l10n.authResetSentTitle), findsOneWidget);
      expect(find.text(l10n.authResetSentDesc(_email)), findsOneWidget);
      expect(find.byKey(_k('AUT-04.send')), findsNothing);
      // İlk gönderimde toast yok (prototip): bildirim görünümün kendisidir.
      expect(_toast(ToastId.tst03), findsNothing);

      // Bekleme sürerken yeniden gönderim: istek gitmez, TST-X3.
      await tester.tap(find.byKey(_k('AUT-04.resend')));
      await tester.pump();
      await tester.pump(GuMotion.base);
      expect(_toast(ToastId.tstX3), findsOneWidget);
      expect(_auth().resetSent, hasLength(1));

      // Bekleme dolunca yeniden gönderilir: TST-03.
      await _elapse(tester, Limits.verificationResendCooldown);
      await tester.tap(find.byKey(_k('AUT-04.resend')));
      await tester.pump();
      await tester.pump(GuMotion.base);
      expect(_auth().resetSent, [_email, _email]);
      expect(_toast(ToastId.tst03), findsOneWidget);
      expect(find.text(l10n.tst03), findsOneWidget);

      await _flushToast(tester);
      await _tap(tester, _k('AUT-04.toLogin'));
      expect(_location(tester), '/login');
      expect(find.byType(LoginView), findsOneWidget);
      expect(find.byType(ResetPasswordView), findsNothing);
      expect(_session(tester).status, AuthStatus.signedOut);
    });
  });
}
