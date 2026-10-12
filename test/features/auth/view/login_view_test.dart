// AUT-01 · Giriş — içerik (TR / EN), 10 aksiyon ve sonuçları (7 demo aksiyonu
// muaf, K-02), doğrulama ve giriş hataları, kilit geri sayımı + DLG-02, klavye
// sırası, yükleniyor durumu, yönlendirme (`from` dönüşü), cihaz matrisi
// (+ klavye, güvenli alan), aksiyon envanteri, dokunma hedefleri, açık + koyu
// golden (boş, hatalı, kilitli).
// Referans: design/reference-shots/screens/AUT-01__*.webp.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/auth/provider/login_state.dart';
import 'package:gu_kulupler/features/auth/provider/login_view_model.dart';
import 'package:gu_kulupler/features/auth/view/login_view.dart';
import 'package:gu_kulupler/features/auth/view/widget/login_form_shake.dart';
import 'package:gu_kulupler/features/auth/view/widget/login_lock_dialog.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/menu_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/navigation/app_router.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fakes/fake_app_preferences_store.dart';
import '../../../fakes/fake_auth_repository.dart';
import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_user_repository.dart';
import '../../../fakes/register_fakes.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/fake_app_clock.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';

final Key _lang = GuKey.action('AUT-01.lang');
final Key _form = GuKey.action('AUT-01.form');
final Key _email = GuKey.action('AUT-01.email');
final Key _password = GuKey.action('AUT-01.password');
final Key _togglePassword = GuKey.action('AUT-01.togglePassword');
final Key _forgot = GuKey.action('AUT-01.forgot');
final Key _login = GuKey.action('AUT-01.login');
final Key _register = GuKey.action('AUT-01.register');
final Key _terms = GuKey.action('AUT-01.terms');
final Key _privacy = GuKey.action('AUT-01.privacy');

const String _validEmail = 'ayse.demir@ogr.gumushane.edu.tr';
const String _validPassword = 'Sifre123';

/// Hatalı durum: iki alan hatası + alana bağlanamayan hata.
const LoginState _errorState = LoginState(
  errors: {
    LoginField.email: FormFieldError.domainNotAllowed,
    LoginField.password: FormFieldError.passwordWeak,
  },
  submitError: LoginError.unknown,
);

/// Kilitli durum: 5. hatalı denemenin hemen sonrası.
final LoginState _lockedState = LoginState(
  failedAttempts: Limits.loginMaxFailedAttempts,
  submitError: LoginError.invalidCredential,
  lockedUntil: kDefaultFakeNowUtc.add(Limits.loginLockout),
);

FakeAuthRepository _auth() => GetIt.I<AuthRepository>() as FakeAuthRepository;

FakeUserRepository _users() => GetIt.I<UserRepository>() as FakeUserRepository;

FakeFeedbackService _feedback() =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;

FakeConnectivityService _connectivity() =>
    GetIt.I<ConnectivityService>() as FakeConnectivityService;

FakeAppClock _clock() => GetIt.I<AppClock>() as FakeAppClock;

TextField _field(WidgetTester tester, Key key) =>
    tester.widget<TextField>(find.byKey(key));

bool _hasFocus(WidgetTester tester, Key key) =>
    _field(tester, key).focusNode!.hasFocus;

GuInput _input(WidgetTester tester, Key key) => tester.widget<GuInput>(
  find.ancestor(of: find.byKey(key), matching: find.byType(GuInput)),
);

GuButton _loginButton(WidgetTester tester) =>
    tester.widget<GuButton>(find.byKey(_login));

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.tap(find.byKey(key));
  await tester.pump();
}

Future<void> _fillValid(WidgetTester tester) async {
  await tester.enterText(find.byKey(_email), _validEmail);
  await tester.enterText(find.byKey(_password), _validPassword);
}

/// "Giriş yap"a dokunur ve gönderimin sonucunu bekler (sallanma dahil).
Future<void> _submitForm(WidgetTester tester) async {
  await _tap(tester, _login);
  await tester.pump();
  await tester.pump(GuMotion.shake);
}

/// SDK'nın "hatalı kimlik" cevabıyla (sayılan deneme) [times] kez gönderir.
Future<void> _failLogin(WidgetTester tester, {int times = 1}) async {
  for (var i = 0; i < times; i++) {
    _auth().service.failNext(AuthError.invalidCredentials);
    await _submitForm(tester);
  }
}

Override _state(LoginState state) =>
    loginViewModelProvider.overrideWithBuild((ref, notifier) => state);

/// Ekranı geçici rotalarla çizer: `/login` (+ `register`, `reset` alt
/// rotaları) ve `/legal/:tip`. Diğer ekranlar yer tutucudur (yollarını gösterir).
Future<GoRouter> _pumpRouter(WidgetTester tester) async {
  GoRouter? created;
  await tester.pumpAppRouter(
    routerOf: (ref) => created ??= GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginView(),
          routes: [
            GoRoute(
              path: 'register',
              builder: (context, state) => const _Stub('/login/register'),
            ),
            GoRoute(
              path: 'reset',
              builder: (context, state) => const _Stub('/login/reset'),
            ),
          ],
        ),
        GoRoute(
          path: '/legal/:tip',
          builder: (context, state) =>
              _Stub('/legal/${state.pathParameters['tip']}'),
        ),
      ],
    ),
  );
  final router = created!;
  addTearDown(router.dispose);
  await tester.pumpAndSettle();
  return router;
}

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

/// Uygulamanın gerçek router'ı + gerçek `SessionViewModel` (fake servislerle):
/// tanıtım görülmüş, oturum yok → `/login`.
Future<GoRouter> _pumpApp(WidgetTester tester, {String? location}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  late GoRouter router;
  await tester.pumpAppRouter(
    routerOf: (ref) {
      // Oturum katmanı kurulmadan önce: tanıtım görüldü (R2 → R3).
      (GetIt.I<AppPreferencesStore>() as FakeAppPreferencesStore)
              .values[AppPreferenceKeys.onboardingSeen] =
          true;
      return router = ref.watch(appRouterProvider);
    },
  );
  await tester.pumpAndSettle();
  if (location != null) {
    router.go(location);
    await tester.pumpAndSettle();
  }
  return router;
}

/// Logo PNG'si çözülmüş hâlde açık + koyu golden (kod çözme motor
/// tarafındadır → `runAsync`).
Future<void> _golden(
  WidgetTester tester,
  String name, {
  List<Override> overrides = const [],
  Locale locale = const Locale('tr'),
}) async {
  for (final theme in kGoldenThemes) {
    await tester.pumpApp(
      const LoginView(),
      theme: theme,
      locale: locale,
      overrides: overrides,
    );
    final image = tester.widget<Image>(find.byType(Image));
    await tester.runAsync(
      () => precacheImage(image.image, tester.element(find.byType(Image))),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(kPumpAppBoundaryKey),
      matchesGoldenFile(goldenUri(goldenPath(name, theme, locale))),
    );
  }
}

class _Stub extends StatelessWidget {
  const _Stub(this.path);

  final String path;

  @override
  Widget build(BuildContext context) => Scaffold(body: Text(path));
}

void main() {
  group('AUT-01 · Giriş', () {
    for (final locale in DeviceMatrix.locales) {
      testWidgets('içerik (${locale.languageCode}): dil düğmesi, logo, başlık, '
          'alanlar, düğmeler, bağlantılar', (tester) async {
        await tester.pumpApp(const LoginView(), locale: locale);
        final l10n = tester.l10n;

        // Dil düğmesi: etkin dil kodu + açılır menü oku.
        expect(
          find.descendant(
            of: find.byKey(_lang),
            matching: find.text(locale.languageCode.toUpperCase()),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(_lang),
            matching: find.byWidgetPredicate(
              (w) => w is GuIcon && w.icon == GuIcons.chevronDown,
            ),
          ),
          findsOneWidget,
        );

        expect(tester.widget<GuLogo>(find.byType(GuLogo)).size, 72);
        expect(find.text(l10n.authLoginWelcome), findsOneWidget);
        expect(find.text(l10n.appTagline), findsOneWidget);

        final email = _input(tester, _email);
        expect(email.label, l10n.authEmail);
        expect(email.icon, GuIcons.mail);
        expect(email.placeholder, 'ad.soyad@ogr.gumushane.edu.tr');
        expect(email.keyboardType, TextInputType.emailAddress);
        expect(email.textInputAction, TextInputAction.next);
        expect(email.errorText, isNull);
        // Referans görüntüde alan odaksızdır: açılışta klavye açılmaz.
        expect(email.autofocus, isFalse);

        final password = _input(tester, _password);
        expect(password.label, l10n.authPassword);
        expect(password.icon, GuIcons.keyRound);
        expect(password.obscure, isTrue);
        expect(password.textInputAction, TextInputAction.done);
        expect(password.errorText, isNull);

        final forgot = tester.widget<GuButton>(find.byKey(_forgot));
        expect(forgot.label, l10n.authForgot);
        expect(forgot.variant, GuButtonVariant.text);
        expect(forgot.size, GuButtonSize.sm);

        final login = _loginButton(tester);
        expect(login.label, l10n.authLoginCta);
        expect(login.size, GuButtonSize.lg);
        expect(login.full, isTrue);
        expect(login.loading, isFalse);
        expect(login.disabled, isFalse);

        expect(
          find.text(
            '${l10n.authNoAccount} ${l10n.authRegisterCta}',
            findRichText: true,
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(_terms),
            matching: find.text(l10n.legalKosullarTitle),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(_privacy),
            matching: find.text(l10n.legalGizlilikTitle),
          ),
          findsOneWidget,
        );
        // Cümle: önek + bağlantı + "ve" + bağlantı + bitişik ek.
        final legal = tester.widget<RichText>(
          find
              .descendant(
                of: find.byType(GuLinkText),
                matching: find.byType(RichText),
              )
              .first,
        );
        expect(
          legal.text.toPlainText(includePlaceholders: false),
          '${l10n.authLegalPrefix}  ${l10n.commonAnd} ${l10n.authLegalSuffix}',
        );
        expect(legal.textAlign, TextAlign.center);
      });
    }

    testWidgets('yerleşim: prototip ölçüleri (390 dp)', (tester) async {
      await tester.pumpApp(const LoginView());
      final l10n = tester.l10n;
      final lang = tester.getRect(find.byKey(_lang));
      final logo = tester.getRect(find.byType(GuLogo));
      final title = tester.getRect(find.text(l10n.authLoginWelcome));
      final tagline = tester.getRect(find.text(l10n.appTagline));
      final email = tester.getRect(find.byType(GuInput).first);
      final password = tester.getRect(find.byType(GuInput).last);
      final forgot = tester.getRect(find.byKey(_forgot));
      final login = tester.getRect(find.byKey(_login));
      final register = tester.getRect(find.byKey(_register));
      final legal = tester.getRect(
        find
            .descendant(
              of: find.byType(GuLinkText),
              matching: find.byType(RichText),
            )
            .first,
      );

      // `.row.end` dolgu 4 / 8; düğme 40.
      expect(lang.top, 4);
      expect(lang.right, 390 - 8);
      expect(lang.height, 40);
      // Başlık bloğu: dolgu 8 / 24 / 24; logo 72, +8 başlık, +8 slogan.
      expect(logo.top, lang.bottom + 8);
      expect(logo.size, const Size(72, 72));
      expect(logo.center.dx, 195);
      expect(title.top, logo.bottom + 8);
      expect(tagline.top, title.bottom + 8);
      // Form: yatay 16, aralık 16; "Şifremi unuttum" −8.
      expect(email.top, tagline.bottom + 24);
      expect(email.left, 16);
      expect(email.right, 390 - 16);
      expect(password.top, email.bottom + 16);
      expect(forgot.top, password.bottom + 8);
      expect(forgot.right, 390 - 16);
      expect(forgot.height, 44);
      expect(login.top, forgot.bottom + 16);
      expect(login.height, 56);
      expect(login.width, 390 - 32);
      expect(register.top, login.bottom + 16);
      expect(register.center.dx, 195);
      // Yasal metin: dolgu 24 / 24 / 8.
      expect(legal.top, register.bottom + 24);
      expect(legal.left, 24);
      expect(legal.right, 390 - 24);
    });

    testWidgets('üst boşluk gerçek güvenli alandır; alt boşluk güvenli alan + '
        '8 (K-07)', (tester) async {
      await tester.pumpApp(
        const LoginView(),
        viewPadding: const EdgeInsets.only(top: 59, bottom: 34),
      );
      expect(tester.getRect(find.byKey(_lang)).top, 59 + 4);
      final legalBlock = tester.getRect(find.byType(GuLinkText));
      final legalText = tester.getRect(
        find
            .descendant(
              of: find.byType(GuLinkText),
              matching: find.byType(RichText),
            )
            .first,
      );
      expect(legalBlock.bottom - legalText.bottom, 8 + 34 + 8);
    });

    testWidgets('demo hesap bölümü uygulanmaz (K-02)', (tester) async {
      await tester.pumpApp(const LoginView());
      final l10n = tester.l10n;
      expect(find.text(l10n.authDemoAccounts), findsNothing);
      expect(find.text(l10n.authDemoAccounts.toUpperCase()), findsNothing);
      expect(find.textContaining(l10n.authDemoPassword), findsNothing);
      expect(
        ActionInventory.found(tester).where((k) => k.contains('demo')),
        isEmpty,
      );
    });

    testWidgets('aksiyon envanteri: 10 aksiyon (7 demo aksiyonu muaf)', (
      tester,
    ) async {
      await tester.pumpApp(const LoginView());
      expectActionInventory(tester, 'AUT-01');
      expect(ActionInventory.found(tester), hasLength(10));
      expect(find.byKey(_form), findsOneWidget);
    });

    testWidgets('aksiyon envanteri kilitli ve hatalı durumda da aynı', (
      tester,
    ) async {
      for (final state in [_errorState, _lockedState]) {
        await tester.pumpApp(const LoginView(), overrides: [_state(state)]);
        expectActionInventory(tester, 'AUT-01');
      }
    });

    testWidgets('cihaz matrisi: taşma yok (+ klavye, güvenli alan)', (
      tester,
    ) async {
      await DeviceMatrix.run(
        tester,
        (_) => const LoginView(),
        keyboard: true,
        safeAreas: true,
      );
    });

    testWidgets('cihaz matrisi: hatalı ve kilitli durum', (tester) async {
      for (final state in [_errorState, _lockedState]) {
        await DeviceMatrix.run(
          tester,
          (_) => const LoginView(),
          overrides: [_state(state)],
          keyboard: true,
        );
      }
    });

    testWidgets('klavye açıkken içerik kayar: giriş düğmesine ulaşılır', (
      tester,
    ) async {
      await tester.pumpApp(
        const LoginView(),
        keyboardInset: DeviceMatrix.keyboardInset,
      );
      const visibleBottom = 844 - DeviceMatrix.keyboardInset;
      await tester.ensureVisible(find.byKey(_login));
      await tester.pump();
      expect(
        tester.getRect(find.byKey(_login)).bottom,
        lessThanOrEqualTo(visibleBottom),
      );
      await tester.ensureVisible(find.byKey(_privacy));
      await tester.pump();
      expect(
        tester.getRect(find.byKey(_privacy)).bottom,
        lessThanOrEqualTo(visibleBottom),
      );
    });

    testWidgets('dokunma hedefleri: Android 48 dp / iOS 44 pt (K-03)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpApp(const LoginView());
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await tester.pumpApp(const LoginView(), platform: TargetPlatform.iOS);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('semantik: alan etiketleri, göster / gizle, bağlantılar', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpApp(const LoginView());
      final l10n = tester.l10n;
      // Yer tutucu, alan boşken etiketin ardından okunur.
      expect(
        tester.getSemantics(find.byKey(_email)).label,
        '${l10n.authEmail}\nad.soyad@ogr.gumushane.edu.tr',
      );
      expect(
        tester.getSemantics(find.byKey(_password)),
        matchesSemantics(
          label: l10n.authPassword,
          isTextField: true,
          isObscured: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      expect(find.bySemanticsLabel(l10n.authShowPassword), findsOneWidget);
      expect(
        find.bySemanticsLabel(l10n.a11yLanguage('Türkçe')),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(find.byKey(_register)),
        matchesSemantics(
          label: '${l10n.authNoAccount} ${l10n.authRegisterCta}',
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      for (final (key, label) in [
        (_terms, l10n.legalKosullarTitle),
        (_privacy, l10n.legalGizlilikTitle),
      ]) {
        expect(
          tester.getSemantics(find.byKey(key)),
          matchesSemantics(label: label, isLink: true, hasTapAction: true),
        );
      }
      handle.dispose();
    });

    testWidgets('golden: açık + koyu', (tester) async {
      await _golden(tester, 'AUT-01');
    });

    testWidgets('golden: EN', (tester) async {
      await _golden(tester, 'AUT-01', locale: const Locale('en'));
    });

    testWidgets('golden: hatalı form (alan hataları + alana bağlanamayan '
        'hata)', (tester) async {
      await _golden(tester, 'AUT-01__errors', overrides: [_state(_errorState)]);
    });

    testWidgets('golden: kilitli (geri sayım düğmesi + hatalı kimlik)', (
      tester,
    ) async {
      await _golden(
        tester,
        'AUT-01__locked',
        overrides: [_state(_lockedState)],
      );
    });
  });

  group('AUT-01 · Giriş · form', () {
    testWidgets('AUT-01.email / .password: yazılan değer ViewModel’e işlenir', (
      tester,
    ) async {
      await tester.pumpApp(const LoginView());
      await _fillValid(tester);
      final state = ProviderScope.containerOf(
        tester.element(find.byType(LoginView)),
      ).read(loginViewModelProvider);
      expect(state.email, _validEmail);
      expect(state.password, _validPassword);
      expect(state.isDirty, isTrue);
    });

    testWidgets('AUT-01.togglePassword: şifreyi gösterir / gizler; ikon ve '
        'etiket değişir', (tester) async {
      await tester.pumpApp(const LoginView());
      final l10n = tester.l10n;
      GuIconButton toggle() =>
          tester.widget<GuIconButton>(find.byKey(_togglePassword));

      expect(_field(tester, _password).obscureText, isTrue);
      expect(toggle().icon, GuIcons.eye);
      expect(toggle().semanticLabel, l10n.authShowPassword);
      expect(toggle().size, GuIconButtonSize.sm);

      await _tap(tester, _togglePassword);
      expect(_field(tester, _password).obscureText, isFalse);
      expect(toggle().icon, GuIcons.eyeOff);
      expect(toggle().semanticLabel, l10n.authHidePassword);

      await _tap(tester, _togglePassword);
      expect(_field(tester, _password).obscureText, isTrue);
    });

    testWidgets('AUT-01.login: boş form gönderilmez; alan hataları görünür, '
        'odak ilk hatalı alana gider', (tester) async {
      await tester.pumpApp(const LoginView());
      final l10n = tester.l10n;
      await _submitForm(tester);

      expect(_auth().signInAttempts, isEmpty);
      expect(_input(tester, _email).errorText, l10n.authErrRequired);
      expect(_input(tester, _password).errorText, l10n.authErrRequired);
      expect(_hasFocus(tester, _email), isTrue);
      expect(_feedback().toasts, isEmpty);
    });

    testWidgets('alan hatası metinleri: biçim, alan adı, kısa şifre; odak '
        'hatalı alana gider, düzenleyince hata kalkar', (tester) async {
      await tester.pumpApp(const LoginView());
      final l10n = tester.l10n;

      await tester.enterText(find.byKey(_email), 'ayse');
      await tester.enterText(find.byKey(_password), 'kisa');
      await _submitForm(tester);
      expect(_input(tester, _email).errorText, l10n.authErrEmail);
      expect(_input(tester, _password).errorText, l10n.authErrPassword);

      await tester.enterText(find.byKey(_email), 'ayse@gmail.com');
      await tester.pump();
      expect(_input(tester, _email).errorText, isNull);
      expect(_input(tester, _password).errorText, l10n.authErrPassword);
      await _submitForm(tester);
      expect(_input(tester, _email).errorText, l10n.authErrDomain);

      // Yalnızca şifre hatalıysa odak şifreye gider.
      await tester.enterText(find.byKey(_email), _validEmail);
      await _submitForm(tester);
      expect(_input(tester, _email).errorText, isNull);
      expect(_hasFocus(tester, _password), isTrue);
      expect(_auth().signInAttempts, isEmpty);
    });

    testWidgets('bu formda üretilmeyen hata türleri metne çevrilmez', (
      tester,
    ) async {
      for (final error in [
        FormFieldError.tooShort,
        FormFieldError.tooLong,
        FormFieldError.passwordMismatch,
        FormFieldError.consentMissing,
        FormFieldError.limitExceeded,
        FormFieldError.invalidFormat,
        FormFieldError.endBeforeStart,
        FormFieldError.capacityBelowGoing,
      ]) {
        await tester.pumpApp(
          const LoginView(),
          overrides: [
            _state(
              LoginState(
                errors: {LoginField.email: error, LoginField.password: error},
              ),
            ),
          ],
        );
        expect(_input(tester, _email).errorText, isNull, reason: error.name);
        expect(_input(tester, _password).errorText, isNull, reason: error.name);
      }
    });

    testWidgets('klavye: e-postada "sonraki" şifreye geçer; şifrede "bitti" '
        'formu gönderir (AUT-01.form)', (tester) async {
      await tester.pumpApp(const LoginView());
      await _fillValid(tester);

      await tester.showKeyboard(find.byKey(_email));
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      expect(_hasFocus(tester, _password), isTrue);
      expect(_auth().signInAttempts, isEmpty);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump();
      expect(_auth().signInAttempts, [
        (email: _validEmail, password: _validPassword),
      ]);
    });

    testWidgets('AUT-01.login: geçerli formla oturum açar; şifre alanı '
        'temizlenir, geri bildirim yok', (tester) async {
      await tester.pumpApp(const LoginView());
      await tester.enterText(find.byKey(_email), '  $_validEmail ');
      await tester.enterText(find.byKey(_password), _validPassword);
      await _submitForm(tester);

      expect(_auth().signInAttempts, [
        (email: _validEmail, password: _validPassword),
      ]);
      expect(_auth().currentUser?.email, _validEmail);
      expect(_field(tester, _password).controller!.text, isEmpty);
      expect(_input(tester, _password).errorText, isNull);
      expect(_feedback().toasts, isEmpty);
      expect(_feedback().dialogs, isEmpty);
    });

    testWidgets('hatalı giriş: TST-01, şifre alanında "E-posta veya şifre '
        'hatalı", form sallanır; düzenleyince hata kalkar', (tester) async {
      await tester.pumpApp(const LoginView());
      final l10n = tester.l10n;
      double shakeOffset() => tester
          .widget<Transform>(
            find
                .descendant(
                  of: find.byType(LoginFormShake),
                  matching: find.byType(Transform),
                )
                .first,
          )
          .transform
          .getTranslation()
          .x;

      await _fillValid(tester);
      expect(shakeOffset(), 0);
      _auth().service.failNext(AuthError.invalidCredentials);
      await _tap(tester, _login);
      await tester.pump();
      // `@keyframes shake`: ilk kare −8'e doğru.
      await tester.pump(GuMotion.shake * 0.2);
      expect(shakeOffset(), closeTo(GuMotion.shakeOffsets[1], 1e-3));
      await tester.pump(GuMotion.shake);
      expect(shakeOffset(), 0);

      expect(_feedback().toasts, [ToastId.tst01]);
      expect(_input(tester, _password).errorText, l10n.authErrWrong);
      expect(_input(tester, _email).errorText, isNull);
      // Şifre silinmez: kullanıcı düzeltebilir.
      expect(_field(tester, _password).controller!.text, _validPassword);
      expect(_loginButton(tester).loading, isFalse);

      await tester.enterText(find.byKey(_password), '${_validPassword}4');
      await tester.pump();
      expect(_input(tester, _password).errorText, isNull);
    });

    testWidgets('azaltılmış harekette form sallanmaz', (tester) async {
      await tester.pumpApp(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: LoginView(),
        ),
      );
      await _fillValid(tester);
      _auth().service.failNext(AuthError.invalidCredentials);
      await _tap(tester, _login);
      await tester.pump();
      await tester.pump(GuMotion.shake * 0.2);
      expect(
        tester
            .widget<Transform>(
              find
                  .descendant(
                    of: find.byType(LoginFormShake),
                    matching: find.byType(Transform),
                  )
                  .first,
            )
            .transform
            .getTranslation()
            .x,
        0,
      );
      expect(_feedback().toasts, [ToastId.tst01]);
    });

    testWidgets('yükleniyor: istek sürerken düğme meşgul; ikinci dokunuş yok '
        'sayılır', (tester) async {
      await tester.pumpApp(
        const LoginView(),
        overrides: [_state(const LoginState(isSubmitting: true))],
      );
      expect(_loginButton(tester).loading, isTrue);
      expect(
        find.descendant(
          of: find.byKey(_login),
          matching: find.byType(GuSpinner),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(_login));
      await tester.pump();
      expect(_auth().signInAttempts, isEmpty);
    });

    testWidgets('yükleniyor: oturum çözülürken düğme meşgul kalır ve gönderim '
        'yapılmaz', (tester) async {
      await tester.pumpApp(
        const LoginView(),
        overrides: [
          sessionViewModelProvider.overrideWithBuild(
            (ref, notifier) => const SessionState(
              status: AuthStatus.signedOut,
              onboardingSeen: true,
              isResolving: true,
            ),
          ),
        ],
      );
      expect(_loginButton(tester).loading, isTrue);
      await _fillValid(tester);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(_auth().signInAttempts, isEmpty);
    });

    testWidgets('çevrimdışı: TST-24, signIn çağrılmaz', (tester) async {
      await tester.pumpApp(const LoginView());
      await _fillValid(tester);
      _connectivity().isOffline = true;
      await _submitForm(tester);

      expect(_feedback().toasts, [ToastId.tst24]);
      expect(_auth().signInAttempts, isEmpty);
      expect(_loginButton(tester).loading, isFalse);
    });

    testWidgets('bilinmeyen hata: düğmenin altında hata satırı; düzenleyince '
        'kalkar', (tester) async {
      await tester.pumpApp(const LoginView());
      final l10n = tester.l10n;
      await _fillValid(tester);
      _auth().failNext(AuthError.unknown);
      await _submitForm(tester);

      expect(find.text(l10n.sysErrorTitle), findsOneWidget);
      expect(_feedback().toasts, isEmpty);
      expect(_loginButton(tester).loading, isFalse);

      await tester.enterText(find.byKey(_password), '${_validPassword}4');
      await tester.pump();
      expect(find.text(l10n.sysErrorTitle), findsNothing);
    });

    testWidgets('askıdaki hesap: oturum kapatılır, DLG-01 gösterilir, şifre '
        'alanı temizlenir', (tester) async {
      await tester.pumpApp(const LoginView());
      await _fillValid(tester);
      _auth().service.failNext(AuthError.userDisabled);
      await _submitForm(tester);

      expect(_auth().callsTo('signOut'), hasLength(1));
      expect(_feedback().dialogs, [DialogId.dlg01]);
      expect(_field(tester, _password).controller!.text, isEmpty);
      expect(_loginButton(tester).loading, isFalse);
    });
  });

  group('AUT-01 · Giriş · kilit (DLG-02)', () {
    testWidgets('5. hatalı denemede DLG-02 açılır; düğme "{s} sn kilitli" '
        'geri sayımına döner ve devre dışı görünür', (tester) async {
      await tester.pumpApp(const LoginView());
      final l10n = tester.l10n;
      await _fillValid(tester);
      await _failLogin(tester, times: Limits.loginMaxFailedAttempts - 1);
      expect(_feedback().dialogs, isEmpty);
      expect(_loginButton(tester).disabled, isFalse);

      await _failLogin(tester);
      expect(
        _feedback().toasts,
        List.filled(Limits.loginMaxFailedAttempts, ToastId.tst01),
      );
      expect(_feedback().dialogs, [DialogId.dlg02]);
      final dialog =
          _feedback().lastDialogBuilder!(tester.element(find.byType(LoginView)))
              as LoginLockDialog;
      expect(dialog.lockedUntil, kDefaultFakeNowUtc.add(Limits.loginLockout));

      final login = _loginButton(tester);
      expect(login.label, l10n.authLockedFor('30'));
      expect(login.disabled, isTrue);
      expect(login.loading, isFalse);
    });

    testWidgets('kilitli düğmeye dokunma: DLG-02 yeniden açılır, signIn '
        'çağrılmaz', (tester) async {
      await tester.pumpApp(const LoginView());
      await _fillValid(tester);
      await _failLogin(tester, times: Limits.loginMaxFailedAttempts);
      final attempts = _auth().signInAttempts.length;
      _feedback().resetFake();

      await _tap(tester, _login);
      expect(_feedback().dialogs, [DialogId.dlg02]);
      expect(_auth().signInAttempts, hasLength(attempts));
      expect(_feedback().toasts, isEmpty);
    });

    testWidgets('geri sayım saniyede bir güncellenir; süre dolunca düğme '
        '"Giriş yap"a döner ve giriş yapılabilir', (tester) async {
      await tester.pumpApp(const LoginView());
      final l10n = tester.l10n;
      await _fillValid(tester);
      await _failLogin(tester, times: Limits.loginMaxFailedAttempts);
      expect(_loginButton(tester).label, l10n.authLockedFor('30'));

      _clock().advance(const Duration(seconds: 1));
      await tester.pump(GuMotion.countdownTick);
      expect(_loginButton(tester).label, l10n.authLockedFor('29'));

      _clock().advance(const Duration(seconds: 28, milliseconds: 500));
      await tester.pump(GuMotion.countdownTick);
      expect(_loginButton(tester).label, l10n.authLockedFor('1'));
      expect(_loginButton(tester).disabled, isTrue);

      _clock().advance(const Duration(milliseconds: 500));
      await tester.pump(GuMotion.countdownTick);
      await tester.pump();
      expect(_loginButton(tester).label, l10n.authLoginCta);
      expect(_loginButton(tester).disabled, isFalse);

      await _submitForm(tester);
      expect(_auth().currentUser?.email, _validEmail);
    });

    testWidgets('DLG-02 süre dolduğunu bildirince (onUnlocked) kilit kalkar', (
      tester,
    ) async {
      await tester.pumpApp(const LoginView());
      final l10n = tester.l10n;
      await _fillValid(tester);
      await _failLogin(tester, times: Limits.loginMaxFailedAttempts);
      final dialog =
          _feedback().lastDialogBuilder!(tester.element(find.byType(LoginView)))
              as LoginLockDialog;

      // Süre dolmadan gelen bildirim kilidi kaldırmaz.
      dialog.onUnlocked!();
      await tester.pump();
      expect(_loginButton(tester).disabled, isTrue);

      _clock().advance(Limits.loginLockout);
      dialog.onUnlocked!();
      await tester.pump();
      expect(_loginButton(tester).label, l10n.authLoginCta);
      expect(_loginButton(tester).disabled, isFalse);
    });

    testWidgets('DLG-02 "Şifremi unuttum" (sonuç true) → AUT-04 '
        '(`/login/reset`, W-05); geri AUT-01’e döner', (tester) async {
      final router = await _pumpRouter(tester);
      await _fillValid(tester);
      await _failLogin(tester, times: Limits.loginMaxFailedAttempts - 1);
      _feedback().nextDialogResult = true;
      await _failLogin(tester);
      await tester.pumpAndSettle();

      expect(_feedback().dialogs, [DialogId.dlg02]);
      expect(_location(router), '/login/reset');
      expect(find.text('/login/reset'), findsOneWidget);
      expect(router.canPop(), isTrue);

      router.pop();
      await tester.pumpAndSettle();
      expect(_location(router), '/login');
      expect(find.byType(LoginView), findsOneWidget);
    });

    testWidgets('DLG-02 "Tamam" / scrim (sonuç false / null): ekranda '
        'kalınır', (tester) async {
      for (final result in <bool?>[false, null]) {
        final router = await _pumpRouter(tester);
        await _fillValid(tester);
        await _failLogin(tester, times: Limits.loginMaxFailedAttempts - 1);
        _feedback().nextDialogResult = result;
        await _failLogin(tester);
        await tester.pumpAndSettle();

        expect(_feedback().dialogs, [DialogId.dlg02], reason: '$result');
        expect(_location(router), '/login', reason: '$result');
        expect(router.canPop(), isFalse, reason: '$result');
      }
    });

    testWidgets('kilit sürerken klavyeden gönderim de DLG-02 açar', (
      tester,
    ) async {
      await tester.pumpApp(const LoginView());
      await _fillValid(tester);
      await _failLogin(tester, times: Limits.loginMaxFailedAttempts);
      final attempts = _auth().signInAttempts.length;
      _feedback().resetFake();

      await tester.showKeyboard(find.byKey(_password));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(_feedback().dialogs, [DialogId.dlg02]);
      expect(_auth().signInAttempts, hasLength(attempts));
    });
  });

  group('AUT-01 · Giriş · aksiyonlar', () {
    testWidgets('AUT-01.lang: SHT-01 açılır menüsü', (tester) async {
      await tester.pumpApp(const LoginView());
      await _tap(tester, _lang);
      expect(_feedback().menus, [MenuId.sht01]);
      expect(_feedback().lastMenuItems, hasLength(1));
    });

    testWidgets('AUT-01.register: AUT-02 (go); geri AUT-01’e döner', (
      tester,
    ) async {
      final router = await _pumpRouter(tester);
      await _tap(tester, _register);
      await tester.pumpAndSettle();
      expect(_location(router), '/login/register');
      expect(find.text('/login/register'), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();
      expect(_location(router), '/login');
      expect(find.byType(LoginView), findsOneWidget);
    });

    testWidgets('AUT-01.register dokunma alanı: satırın üstünde ve altında '
        'görsel kutunun dışı da (48 dp hedef) çalışır (K-03)', (tester) async {
      for (final dy in <double>[-22, 22]) {
        final router = await _pumpRouter(tester);
        final line = tester.getRect(find.byKey(_register));
        expect(line.height, lessThan(GuSizes.tapTargetAndroid));
        await tester.tapAt(line.center + Offset(0, dy));
        await tester.pumpAndSettle();
        expect(_location(router), '/login/register', reason: 'dy $dy');
      }
    });

    testWidgets('AUT-01.terms / .privacy: AUT-06 ilgili sekmeyle push edilir; '
        'geri AUT-01’e döner ve form korunur', (tester) async {
      final router = await _pumpRouter(tester);
      await tester.enterText(find.byKey(_email), _validEmail);
      for (final (key, path) in [
        (_terms, '/legal/kosullar'),
        (_privacy, '/legal/gizlilik'),
      ]) {
        await _tap(tester, key);
        await tester.pumpAndSettle();
        expect(find.text(path), findsOneWidget, reason: path);
        expect(router.canPop(), isTrue);

        router.pop();
        await tester.pumpAndSettle();
        expect(find.byType(LoginView), findsOneWidget);
        expect(_field(tester, _email).controller!.text, _validEmail);
      }
    });

    testWidgets('yasal bağlantıların dokunma alanı: en yakın bağlantı; alt '
        'alta düşen bağlantılar birbirinin dokunuşunu çalmaz', (tester) async {
      // 320 dp'de cümle iki satıra bölünür.
      final router = await _pumpRouter(tester);
      for (final size in [const Size(320, 640), const Size(390, 844)]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(_privacy));
        await tester.pumpAndSettle();
        final terms = tester.getRect(find.byKey(_terms));
        final privacy = tester.getRect(find.byKey(_privacy));

        Future<String?> opened(Offset position) async {
          await tester.tapAt(position);
          await tester.pumpAndSettle();
          if (!router.canPop()) return null;
          final path = tester.widget<Text>(find.byType(Text).last).data;
          router.pop();
          await tester.pumpAndSettle();
          return path;
        }

        // Kutunun her köşesi kendi bağlantısını açar.
        for (final (rect, path) in [
          (terms, '/legal/kosullar'),
          (privacy, '/legal/gizlilik'),
        ]) {
          for (final point in [
            rect.topLeft + const Offset(1, 1),
            rect.topRight + const Offset(-1, 1),
            rect.bottomLeft + const Offset(1, -1),
            rect.bottomRight + const Offset(-1, -1),
            rect.center,
          ]) {
            expect(await opened(point), path, reason: '$size $point');
          }
        }
        // Görsel kutunun hemen dışı (≤ 48 dp hedefin içi) da bağlantıyı açar.
        expect(
          await opened(privacy.bottomCenter + const Offset(0, 6)),
          '/legal/gizlilik',
          reason: '$size alt dolgu',
        );
        // Hiçbir bağlantıya yakın olmayan nokta etkisizdir.
        final block = tester.getRect(find.byType(GuLinkText));
        expect(await opened(block.bottomLeft + const Offset(2, -2)), isNull);
      }
    });

    testWidgets('AUT-01.forgot → AUT-04 (`/login/reset`, W-05): `go` ile alt '
        'rota açılır, geri AUT-01’e döner', (tester) async {
      final router = await _pumpRouter(tester);
      await _tap(tester, _forgot);
      await tester.pumpAndSettle();
      expect(_location(router), '/login/reset');
      expect(find.text('/login/reset'), findsOneWidget);
      expect(router.canPop(), isTrue);
      expect(_feedback().calls, isEmpty);

      router.pop();
      await tester.pumpAndSettle();
      expect(_location(router), '/login');
      expect(find.byType(LoginView), findsOneWidget);
    });
  });

  group('AUT-01 · Giriş · yönlendirme', () {
    testWidgets('başarılı giriş: yönlendirmeyi router yapar — oturum '
        'çözülürken düğme meşgul, sonra ana sayfa', (tester) async {
      final router = await _pumpApp(tester);
      expect(_location(router), '/login');
      expect(find.byType(LoginView), findsOneWidget);

      _users().putActive(_auth().service.uid);
      _auth().service.emailVerified = true;
      final gate = Completer<void>();
      _auth().superAdminGate = gate;
      await _fillValid(tester);
      await _tap(tester, _login);
      await tester.pump();

      // Giriş tamam, kullanıcı belgesi bekleniyor: ekran yerinde, düğme meşgul.
      expect(_location(router), '/login');
      expect(_loginButton(tester).loading, isTrue);

      gate.complete();
      await tester.pumpAndSettle();
      expect(_location(router), '/clubs');
      expect(find.byType(LoginView), findsNothing);
    });

    testWidgets('`/login?from=` ile gelen kullanıcı girişten sonra geldiği '
        'sayfaya döner (R7)', (tester) async {
      final router = await _pumpApp(tester, location: '/login?from=%2Fprofile');
      expect(_location(router), '/login?from=%2Fprofile');

      _users().putActive(_auth().service.uid);
      _auth().service.emailVerified = true;
      await _fillValid(tester);
      await _tap(tester, _login);
      await tester.pumpAndSettle();
      expect(_location(router), '/profile');
    });

    testWidgets('e-postası doğrulanmamış kullanıcı girişten sonra AUT-03’e '
        'yönlendirilir', (tester) async {
      final router = await _pumpApp(tester);
      await _fillValid(tester);
      await _tap(tester, _login);
      await tester.pumpAndSettle();
      expect(_location(router), '/verify');
    });
  });
}
