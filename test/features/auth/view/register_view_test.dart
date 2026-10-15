// AUT-02 · Kayıt ol — içerik (TR / EN), 13 aksiyon ve sonuçları, doğrulama ve
// sunucu hataları, klavye sırası, cihaz matrisi (+ klavye), aksiyon
// envanteri, dokunma hedefleri, açık + koyu golden (boş, dolu, hatalı).
// Referans: design/reference-shots/screens/AUT-02__*.webp.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/auth/provider/register_state.dart';
import 'package:gu_kulupler/features/auth/provider/register_view_model.dart';
import 'package:gu_kulupler/features/auth/view/register_view.dart';
import 'package:gu_kulupler/features/auth/view/widget/register_legal_consent.dart';
import 'package:gu_kulupler/features/auth/view/widget/register_password_strength.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/menu_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fakes/fake_auth_repository.dart';
import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_session_states.dart';
import '../../../fakes/fake_user_repository.dart';
import '../../../fakes/test_router.dart';
import '../../../helpers/a11y_guidelines.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';

final Key _back = GuKey.action('AUT-02.back');
final Key _lang = GuKey.action('AUT-02.lang');
final Key _form = GuKey.action('AUT-02.form');
final Key _name = GuKey.action('AUT-02.name');
final Key _email = GuKey.action('AUT-02.email');
final Key _password = GuKey.action('AUT-02.password');
final Key _password2 = GuKey.action('AUT-02.password2');
final Key _togglePassword = GuKey.action('AUT-02.togglePassword');
final Key _legalCheck = GuKey.action('AUT-02.legalCheck');
final Key _legal = GuKey.action('AUT-02.legal');
final Key _legalPrivacy = GuKey.action('AUT-02.legalPrivacy');
final Key _submit = GuKey.action('AUT-02.submit');
final Key _toLogin = GuKey.action('AUT-02.toLogin');

const String _validName = 'Ayşe Yılmaz';
const String _validEmail = 'ayse.yilmaz@ogr.gumushane.edu.tr';
const String _validPassword = 'Parola123';

/// Hatalı durum: beş alan hatası + alana bağlanamayan sunucu hatası.
const RegisterState _errorState = RegisterState(
  errors: {
    RegisterField.name: FormFieldError.required,
    RegisterField.email: FormFieldError.domainNotAllowed,
    RegisterField.password: FormFieldError.passwordWeak,
    RegisterField.passwordConfirm: FormFieldError.passwordMismatch,
    RegisterField.legal: FormFieldError.consentMissing,
  },
  submitError: RegisterError.unknown,
);

FakeAuthRepository _auth() => GetIt.I<AuthRepository>() as FakeAuthRepository;

FakeUserRepository _users() => GetIt.I<UserRepository>() as FakeUserRepository;

FakeFeedbackService _feedback() =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;

FakeConnectivityService _connectivity() =>
    GetIt.I<ConnectivityService>() as FakeConnectivityService;

TextField _field(WidgetTester tester, Key key) =>
    tester.widget<TextField>(find.byKey(key));

bool _hasFocus(WidgetTester tester, Key key) =>
    _field(tester, key).focusNode!.hasFocus;

GuInput _input(WidgetTester tester, Key key) => tester.widget<GuInput>(
  find.ancestor(of: find.byKey(key), matching: find.byType(GuInput)),
);

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.tap(find.byKey(key));
  await tester.pump();
}

/// Geçerli formu doldurur (onay kutusu dahil).
Future<void> _fillValid(WidgetTester tester) async {
  await tester.enterText(find.byKey(_name), _validName);
  await tester.enterText(find.byKey(_email), _validEmail);
  await tester.enterText(find.byKey(_password), _validPassword);
  await tester.enterText(find.byKey(_password2), _validPassword);
  await _tap(tester, _legalCheck);
}

/// "Hesap oluştur"a dokunur ve gönderimin sonucunu bekler.
Future<void> _submitForm(WidgetTester tester) async {
  await _tap(tester, _submit);
  await tester.pump();
}

/// Ekranı geçici rotalarla çizer: `/login` (+ `register` alt rotası),
/// `/legal/:tip` ve yığınsız açılış için `/solo`. Diğer ekranlar yer
/// tutucudur (yollarını gösterir).
Future<GoRouter> _pumpRouter(
  WidgetTester tester, {
  String location = '/login/register',
}) async {
  GoRouter? created;
  await tester.pumpAppRouter(
    routerOf: (ref) => created ??= GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const _Stub('/login'),
          routes: [
            GoRoute(
              path: 'register',
              builder: (context, state) => const RegisterView(),
            ),
          ],
        ),
        GoRoute(
          path: '/legal/:tip',
          builder: (context, state) =>
              _Stub('/legal/${state.pathParameters['tip']}'),
        ),
        GoRoute(
          path: '/solo',
          builder: (context, state) => const RegisterView(),
        ),
      ],
    ),
  );
  final router = created!;
  addTearDown(router.dispose);
  await tester.pumpAndSettle();
  return router;
}

class _Stub extends StatelessWidget {
  const _Stub(this.path);

  final String path;

  @override
  Widget build(BuildContext context) => Scaffold(body: Text(path));
}

void main() {
  group('AUT-02 · Kayıt ol', () {
    for (final locale in DeviceMatrix.locales) {
      testWidgets('içerik (${locale.languageCode}): çubuk, alanlar, kurallar, '
          'onay cümlesi, düğmeler', (tester) async {
        await tester.pumpApp(const RegisterView(), locale: locale);
        final l10n = tester.l10n;

        // Çubuk: geri + başlık + dil düğmesi.
        expect(
          find.descendant(
            of: find.byType(GuAppBar),
            matching: find.text(l10n.authRegisterTitle),
          ),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel(l10n.a11yBack), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(_lang),
            matching: find.text(locale.languageCode.toUpperCase()),
          ),
          findsOneWidget,
        );

        // Alanlar: etiket, ikon, yer tutucu, yardım.
        expect(_input(tester, _name).label, l10n.authFullName);
        expect(_input(tester, _name).icon, GuIcons.user);
        expect(_input(tester, _email).label, l10n.authUniEmail);
        expect(_input(tester, _email).icon, GuIcons.mail);
        expect(
          _input(tester, _email).placeholder,
          'ad.soyad@ogr.gumushane.edu.tr',
        );
        expect(find.text(l10n.authRegisterEmailHelp), findsOneWidget);
        expect(_input(tester, _password).label, l10n.authPassword);
        expect(_input(tester, _password).icon, GuIcons.keyRound);
        expect(_input(tester, _password2).label, l10n.authPasswordRepeat);
        expect(_input(tester, _password2).icon, GuIcons.keyRound);
        for (final label in [
          l10n.authFullName,
          l10n.authUniEmail,
          l10n.authPassword,
          l10n.authPasswordRepeat,
        ]) {
          expect(find.text(label), findsOneWidget);
        }
        expect(_field(tester, _email).keyboardType, TextInputType.emailAddress);
        // Ekran açılışta klavyeyi açmaz.
        for (final key in [_name, _email, _password, _password2]) {
          expect(_hasFocus(tester, key), isFalse);
        }

        // Şifre gizli; göz düğmesi "göster".
        expect(_field(tester, _password).obscureText, isTrue);
        expect(_field(tester, _password2).obscureText, isTrue);
        expect(find.bySemanticsLabel(l10n.authShowPassword), findsOneWidget);

        // Güç çubuğu boş, üç kural karşılanmamış.
        final strength = tester.widget<RegisterPasswordStrength>(
          find.byType(RegisterPasswordStrength),
        );
        expect(strength.strength, 0);
        expect(strength.max, 4);
        expect(strength.rules, [
          (met: false, label: l10n.authRuleLen),
          (met: false, label: l10n.authRuleUpper),
          (met: false, label: l10n.authRuleDigit),
        ]);
        expect(find.text(l10n.authRuleLen), findsOneWidget);
        expect(find.text(l10n.authRuleUpper), findsOneWidget);
        expect(find.text(l10n.authRuleDigit), findsOneWidget);

        // Yasal onay: kutu boş; iki bağlantı + cümle.
        expect(
          tester.widget<GuCheckbox>(find.byKey(_legalCheck)).value,
          isFalse,
        );
        expect(
          find.descendant(
            of: find.byKey(_legal),
            matching: find.text(l10n.legalKvkkTitle),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(_legalPrivacy),
            matching: find.text(l10n.legalGizlilikTitle),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(RegisterLegalConsent),
            matching: find.textContaining(
              ' ${l10n.commonAnd} ',
              findRichText: true,
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(RegisterLegalConsent),
            matching: find.textContaining(
              l10n.authLegalCheck,
              findRichText: true,
            ),
          ),
          findsOneWidget,
        );

        // Gönder + girişe dön.
        final submit = tester.widget<GuButton>(find.byKey(_submit));
        expect(submit.label, l10n.authRegisterSubmit);
        expect(submit.size, GuButtonSize.lg);
        expect(submit.full, isTrue);
        expect(submit.loading, isFalse);
        expect(
          find.descendant(
            of: find.byKey(_toLogin),
            matching: find.textContaining(
              '${l10n.authHaveAccount} ${l10n.authLoginCta}',
              findRichText: true,
            ),
          ),
          findsOneWidget,
        );
        // Hata satırı yok.
        expect(find.text(l10n.authErrRequired), findsNothing);
        expect(find.text(l10n.sysErrorTitle), findsNothing);
        await expectA11yGuidelines(tester);
      });
    }

    testWidgets('aksiyon envanteri: 13 aksiyon', (tester) async {
      await tester.pumpApp(const RegisterView());
      expectActionInventory(tester, 'AUT-02');
      expect(find.byKey(_form), findsOneWidget);
    });

    testWidgets('cihaz matrisi: taşma yok (klavye + güvenli alanlar)', (
      tester,
    ) async {
      await DeviceMatrix.run(
        tester,
        (_) => const RegisterView(),
        keyboard: true,
        safeAreas: true,
      );
    });

    testWidgets('cihaz matrisi: tüm hata satırları açıkken taşma yok', (
      tester,
    ) async {
      await DeviceMatrix.run(
        tester,
        (_) => const RegisterView(),
        keyboard: true,
        overrides: [
          registerViewModelProvider.overrideWithBuild(
            (ref, notifier) => _errorState,
          ),
        ],
      );
    });

    testWidgets('yerleşim: yatay 16, üst 8, alan aralığı 16; alt boşluk gerçek '
        'güvenli alan + 8', (tester) async {
      await tester.pumpApp(
        const RegisterView(),
        viewPadding: const EdgeInsets.only(top: 47, bottom: 34),
      );
      final bar = tester.getRect(find.byType(GuAppBar));
      expect(bar, const Rect.fromLTWH(0, 0, 390, 47 + 56));
      final form = tester.getRect(find.byKey(_form));
      expect(form.left, 16);
      expect(form.right, 390 - 16);
      expect(form.top, bar.bottom + 8);
      final name = tester.getRect(
        find.ancestor(of: find.byKey(_name), matching: find.byType(GuInput)),
      );
      final email = tester.getRect(
        find.ancestor(of: find.byKey(_email), matching: find.byType(GuInput)),
      );
      expect(email.top - name.bottom, 16);
      expect(tester.getSize(find.byKey(_submit)), const Size(358, 56));
      final scroll = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(
        scroll.padding,
        const EdgeInsets.fromLTRB(16, 8, 16, 34 + 8),
      );
    });

    testWidgets('dokunma hedefleri: Android 48 dp / iOS 44 pt (K-03)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpApp(const RegisterView());
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await tester.pumpApp(const RegisterView(), platform: TargetPlatform.iOS);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('metin ölçeği 1.6: satır içi bağlantılar çevresindeki metinle '
        'aynı boyda (çift ölçek yok)', (tester) async {
      await tester.pumpApp(
        const RegisterView(),
        textScale: 1.6,
        size: MatrixSize.large.size,
      );
      // Kural satırı da `bodyS` tek satırdır: bağlantının ekrandaki yüksekliği
      // onunla aynı olmalı.
      final lineHeight = tester
          .getRect(find.text(tester.l10n.authRuleLen))
          .height;
      for (final key in [_legal, _legalPrivacy]) {
        expect(
          tester.getRect(find.byKey(key)).height,
          moreOrLessEquals(lineHeight, epsilon: 0.5),
        );
      }
    });

    testWidgets('golden: açık + koyu', (tester) async {
      await goldenForThemes(tester, 'AUT-02', const RegisterView());
    });

    testWidgets('golden: dolu form (şifre görünür, kurallar karşılanmış, onay '
        'verilmiş)', (tester) async {
      const locale = Locale('tr');
      for (final theme in kGoldenThemes) {
        await tester.pumpApp(const RegisterView(), theme: theme);
        await _fillValid(tester);
        await _tap(tester, _togglePassword);
        // Odak kenarlığı ve imleç golden'a girmesin.
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        await tester.pump(GuMotion.base);
        await expectLater(
          find.byKey(kPumpAppBoundaryKey),
          matchesGoldenFile(
            goldenUri(goldenPath('AUT-02__filled', theme, locale)),
          ),
        );
      }
    });

    testWidgets('golden: hatalı form (alan hataları + sunucu hatası)', (
      tester,
    ) async {
      await goldenForThemes(
        tester,
        'AUT-02__errors',
        const RegisterView(),
        overrides: [
          registerViewModelProvider.overrideWithBuild(
            (ref, notifier) => _errorState,
          ),
        ],
      );
    });
  });

  group('AUT-02 · Kayıt ol · form aksiyonları', () {
    testWidgets('AUT-02.name / .email / .password / .password2: yazılan değer '
        'ViewModel katmanına geçer', (tester) async {
      await tester.pumpApp(const RegisterView());
      await tester.enterText(find.byKey(_name), _validName);
      await tester.enterText(find.byKey(_email), _validEmail);
      await tester.enterText(find.byKey(_password), _validPassword);
      await tester.enterText(find.byKey(_password2), 'Parola12');
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(RegisterView)),
      );
      expect(
        container.read(registerViewModelProvider),
        const RegisterState(
          name: _validName,
          email: _validEmail,
          password: _validPassword,
          passwordConfirm: 'Parola12',
          isDirty: true,
        ),
      );
    });

    testWidgets(
      'AUT-02.password: güç çubuğu ve kurallar yazdıkça güncellenir',
      (
        tester,
      ) async {
        await tester.pumpApp(const RegisterView());
        final l10n = tester.l10n;
        RegisterPasswordStrength strength() =>
            tester.widget<RegisterPasswordStrength>(
              find.byType(RegisterPasswordStrength),
            );
        List<Color?> segments() => [
          for (final box in tester.widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(RegisterPasswordStrength),
              matching: find.byType(DecoratedBox),
            ),
          ))
            (box.decoration as BoxDecoration).color,
        ];
        const colors = GuColors.light;

        expect(segments(), List.filled(4, colors.borderDefault));

        await tester.enterText(find.byKey(_password), 'abcdefgh');
        await tester.pump();
        expect(strength().strength, 1);
        expect(strength().rules.map((rule) => rule.met), [true, false, false]);
        expect(segments(), [
          colors.stateDanger,
          colors.borderDefault,
          colors.borderDefault,
          colors.borderDefault,
        ]);

        await tester.enterText(find.byKey(_password), 'Abcdefgh');
        await tester.pump();
        expect(strength().strength, 2);
        expect(segments(), [
          colors.stateWarning,
          colors.stateWarning,
          colors.borderDefault,
          colors.borderDefault,
        ]);

        await tester.enterText(find.byKey(_password), 'Abcdefg1');
        await tester.pump();
        expect(strength().strength, 3);
        expect(strength().rules, [
          (met: true, label: l10n.authRuleLen),
          (met: true, label: l10n.authRuleUpper),
          (met: true, label: l10n.authRuleDigit),
        ]);
        expect(segments(), [
          colors.stateSuccess,
          colors.stateSuccess,
          colors.stateSuccess,
          colors.borderDefault,
        ]);
        // Karşılanan kural: yeşil onay ikonu; karşılanmayan: gri çarpı.
        final icons = tester.widgetList<GuIcon>(
          find.descendant(
            of: find.byType(RegisterPasswordStrength),
            matching: find.byType(GuIcon),
          ),
        );
        expect(
          icons.map((icon) => icon.icon),
          List.filled(3, GuIcons.circleCheck),
        );
        expect(
          icons.map((icon) => icon.color),
          List.filled(3, colors.stateSuccess),
        );
        expect(icons.map((icon) => icon.size), List.filled(3, 14));

        await tester.enterText(find.byKey(_password), 'Abcdef1!');
        await tester.pump();
        expect(strength().strength, 4);
        expect(segments(), List.filled(4, colors.stateSuccess));

        await tester.enterText(find.byKey(_password), '');
        await tester.pump();
        final empty = tester.widgetList<GuIcon>(
          find.descendant(
            of: find.byType(RegisterPasswordStrength),
            matching: find.byType(GuIcon),
          ),
        );
        expect(empty.map((icon) => icon.icon), List.filled(3, GuIcons.circleX));
        expect(
          empty.map((icon) => icon.color),
          List.filled(3, colors.textMuted),
        );
      },
    );

    testWidgets('AUT-02.togglePassword: iki şifre alanını birlikte gösterir / '
        'gizler', (tester) async {
      await tester.pumpApp(const RegisterView());
      final l10n = tester.l10n;
      GuIconButton toggle() =>
          tester.widget<GuIconButton>(find.byKey(_togglePassword));
      expect(toggle().icon, GuIcons.eye);
      expect(toggle().size, GuIconButtonSize.sm);

      await _tap(tester, _togglePassword);
      expect(_field(tester, _password).obscureText, isFalse);
      expect(_field(tester, _password2).obscureText, isFalse);
      expect(toggle().icon, GuIcons.eyeOff);
      expect(toggle().semanticLabel, l10n.authHidePassword);

      await _tap(tester, _togglePassword);
      expect(_field(tester, _password).obscureText, isTrue);
      expect(_field(tester, _password2).obscureText, isTrue);
      expect(toggle().semanticLabel, l10n.authShowPassword);
    });

    testWidgets('AUT-02.legalCheck: onayı işaretler / kaldırır', (
      tester,
    ) async {
      await tester.pumpApp(const RegisterView());
      GuCheckbox box() => tester.widget<GuCheckbox>(find.byKey(_legalCheck));
      expect(box().semanticLabel, tester.l10n.authLegalCheck);
      await _tap(tester, _legalCheck);
      expect(box().value, isTrue);
      await _tap(tester, _legalCheck);
      expect(box().value, isFalse);
    });

    testWidgets('AUT-02.lang: dil menüsü (SHT-01) açılır', (tester) async {
      await tester.pumpApp(const RegisterView());
      await _tap(tester, _lang);
      expect(_feedback().menus, [MenuId.sht01]);
      expect(_feedback().sheets, isEmpty);
    });

    testWidgets('AUT-02.form: klavye eylem tuşu sıradaki alana geçer; son '
        'alanda formu gönderir', (tester) async {
      await tester.pumpApp(const RegisterView());
      expect(_field(tester, _name).textInputAction, TextInputAction.next);
      expect(_field(tester, _email).textInputAction, TextInputAction.next);
      expect(_field(tester, _password).textInputAction, TextInputAction.next);
      expect(_field(tester, _password2).textInputAction, TextInputAction.done);

      await tester.showKeyboard(find.byKey(_name));
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      expect(_hasFocus(tester, _email), isTrue);
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      expect(_hasFocus(tester, _password), isTrue);
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      expect(_hasFocus(tester, _password2), isTrue);

      // Son alan: form gönderilir (boş form → doğrulama hataları).
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump();
      expect(find.text(tester.l10n.authErrRequired), findsNWidgets(2));
      expect(_auth().callsTo('register'), isEmpty);
    });
  });

  group('AUT-02 · Kayıt ol · gönderim', () {
    testWidgets('AUT-02.submit: boş form → alan hataları, odak ilk hatalı '
        'alanda, istek gitmez', (tester) async {
      await tester.pumpApp(const RegisterView());
      final l10n = tester.l10n;
      await _submitForm(tester);

      expect(_input(tester, _name).errorText, l10n.authErrRequired);
      expect(_input(tester, _email).errorText, l10n.authErrRequired);
      expect(_input(tester, _password).errorText, l10n.authErrPassword);
      expect(_input(tester, _password2).errorText, isNull);
      expect(find.text(l10n.authErrLegal), findsOneWidget);
      // Hata varken yardım metni gizlenir.
      expect(find.text(l10n.authRegisterEmailHelp), findsNothing);
      expect(_hasFocus(tester, _name), isTrue);
      expect(_auth().callsTo('register'), isEmpty);
      expect(tester.widget<GuButton>(find.byKey(_submit)).loading, isFalse);
    });

    testWidgets('AUT-02.submit: her doğrulama hatasının metni', (tester) async {
      await tester.pumpApp(const RegisterView());
      final l10n = tester.l10n;
      await tester.enterText(find.byKey(_name), 'A');
      await tester.enterText(find.byKey(_email), 'ayse');
      await tester.enterText(find.byKey(_password), 'parola');
      await tester.enterText(find.byKey(_password2), 'parola1');
      await _submitForm(tester);
      expect(_input(tester, _name).errorText, l10n.authErrNameLength(2, 60));
      expect(_input(tester, _email).errorText, l10n.authErrEmail);
      expect(_input(tester, _password).errorText, l10n.authErrPassword);
      expect(_input(tester, _password2).errorText, l10n.authErrMismatch);
      expect(find.text(l10n.authErrLegal), findsOneWidget);

      await tester.enterText(find.byKey(_email), 'ayse@hotmail.com');
      await _submitForm(tester);
      expect(_input(tester, _email).errorText, l10n.authErrDomain);
      expect(_auth().callsTo('register'), isEmpty);
    });

    testWidgets('alan düzenlenince o alanın hatası kaybolur', (tester) async {
      await tester.pumpApp(const RegisterView());
      final l10n = tester.l10n;
      await _submitForm(tester);
      await tester.enterText(find.byKey(_name), _validName);
      await tester.pump();
      expect(_input(tester, _name).errorText, isNull);
      expect(_input(tester, _email).errorText, l10n.authErrRequired);
      await _tap(tester, _legalCheck);
      expect(find.text(l10n.authErrLegal), findsNothing);
    });

    testWidgets('yalnızca onay eksikse: klavye kapanır, hata satırı görünür', (
      tester,
    ) async {
      await tester.pumpApp(const RegisterView());
      await _fillValid(tester);
      await _tap(tester, _legalCheck); // onayı geri al
      await tester.showKeyboard(find.byKey(_password2));
      await _submitForm(tester);
      await tester.pumpAndSettle();
      expect(find.text(tester.l10n.authErrLegal), findsOneWidget);
      expect(
        FocusManager.instance.primaryFocus?.context?.widget,
        isNot(isA<EditableText>()),
      );
      for (final key in [_name, _email, _password, _password2]) {
        expect(_hasFocus(tester, key), isFalse);
      }
      expect(_auth().callsTo('register'), isEmpty);
    });

    testWidgets('AUT-02.submit: geçerli form → hesap açılır; ad kimlik '
        'hesabında, profil belgesi yok; düğme meşgul kalır', (tester) async {
      await tester.pumpApp(const RegisterView());
      await _fillValid(tester);
      await _submitForm(tester);

      expect(_auth().registered, [
        (email: _validEmail, password: _validPassword, name: _validName),
      ]);
      expect(_auth().currentUser?.displayName, _validName);
      expect(_auth().currentUser?.emailVerified, isFalse);
      expect(_auth().service.callsTo('sendEmailVerification'), hasLength(1));
      expect(_users().calls, isEmpty);
      expect(_feedback().toasts, isEmpty);
      expect(tester.widget<GuButton>(find.byKey(_submit)).loading, isTrue);
      expect(find.byType(GuSpinner), findsOneWidget);

      // Yönlendirme beklenirken yeniden dokunma ikinci hesabı açmaz.
      await _tap(tester, _submit);
      await tester.pump();
      expect(_auth().callsTo('register'), hasLength(1));
    });

    testWidgets('AUT-02.submit: art arda iki dokunma tek istek gönderir', (
      tester,
    ) async {
      await tester.pumpApp(const RegisterView());
      await _fillValid(tester);
      await tester.ensureVisible(find.byKey(_submit));
      await tester.tap(find.byKey(_submit));
      await tester.tap(find.byKey(_submit));
      await tester.pump();
      await tester.pump();
      expect(_auth().callsTo('register'), hasLength(1));
    });

    testWidgets('kayıtlı e-posta: hata e-posta alanının altında, odak orada', (
      tester,
    ) async {
      await tester.pumpApp(const RegisterView());
      final l10n = tester.l10n;
      await _fillValid(tester);
      _auth().service.failNext(AuthError.emailAlreadyInUse);
      await _submitForm(tester);

      expect(_input(tester, _email).errorText, l10n.authErrExists);
      expect(_hasFocus(tester, _email), isTrue);
      expect(tester.widget<GuButton>(find.byKey(_submit)).loading, isFalse);
      expect(_feedback().toasts, isEmpty);

      // Adres değişince hata kaybolur.
      await tester.enterText(find.byKey(_email), 'ayse@gumushane.edu.tr');
      await tester.pump();
      expect(_input(tester, _email).errorText, isNull);
    });

    testWidgets('sunucu alan adını / şifreyi reddederse ilgili alan hatası', (
      tester,
    ) async {
      await tester.pumpApp(const RegisterView());
      final l10n = tester.l10n;
      await _fillValid(tester);
      _auth().failNext(AuthError.domainNotAllowed);
      await _submitForm(tester);
      expect(_input(tester, _email).errorText, l10n.authErrDomain);
      expect(_hasFocus(tester, _email), isTrue);

      _auth().service.failNext(AuthError.weakPassword);
      await tester.enterText(find.byKey(_email), _validEmail);
      await _submitForm(tester);
      expect(_input(tester, _email).errorText, isNull);
      expect(_input(tester, _password).errorText, l10n.authErrPassword);
      expect(_hasFocus(tester, _password), isTrue);
    });

    testWidgets('ağ hatası: TST-24; form açık kalır, satır içi hata yok', (
      tester,
    ) async {
      await tester.pumpApp(const RegisterView());
      await _fillValid(tester);
      _auth().service.failNext(AuthError.network);
      await _submitForm(tester);
      expect(_feedback().toasts, [ToastId.tst24]);
      expect(tester.widget<GuButton>(find.byKey(_submit)).loading, isFalse);
      expect(find.text(tester.l10n.sysErrorTitle), findsNothing);
    });

    testWidgets('çevrimdışı: TST-24, istek gitmez', (tester) async {
      await tester.pumpApp(const RegisterView());
      await _fillValid(tester);
      _connectivity().isOffline = true;
      await _submitForm(tester);
      expect(_feedback().toasts, [ToastId.tst24]);
      expect(_auth().callsTo('register'), isEmpty);
      expect(tester.widget<GuButton>(find.byKey(_submit)).loading, isFalse);
    });

    testWidgets('bilinmeyen hata: düğmenin altında genel hata satırı; form '
        'düzenlenince kaybolur', (tester) async {
      await tester.pumpApp(const RegisterView());
      final l10n = tester.l10n;
      await _fillValid(tester);
      _auth().failNext(AuthError.unknown);
      await _submitForm(tester);

      final error = find.text(l10n.sysErrorTitle);
      expect(error, findsOneWidget);
      expect(
        tester.getTopLeft(error).dy,
        greaterThan(tester.getBottomLeft(find.byKey(_submit)).dy),
      );
      expect(_feedback().toasts, isEmpty);
      expect(tester.widget<GuButton>(find.byKey(_submit)).loading, isFalse);

      await tester.enterText(find.byKey(_name), 'Ayşe Demir');
      await tester.pump();
      expect(error, findsNothing);
    });
  });

  group('AUT-02 · Kayıt ol · gezinme', () {
    testWidgets(
      'gerçek rota: `/login/register` misafire açılır; kayıttan sonra '
      'ekran gezinmez, oturum doğrulanmamış olunca router AUT-03 açar',
      (
        tester,
      ) async {
        final app = await TestRouter.pump(
          tester,
          session: FakeSessionStates.signedOut,
          location: '/login/register',
        );
        expect(app.location, '/login/register');
        expect(find.byType(RegisterView), findsOneWidget);

        await _fillValid(tester);
        await _submitForm(tester);
        expect(_auth().registered, hasLength(1));
        expect(app.location, '/login/register');

        app.session = FakeSessionStates.unverified;
        await tester.pumpAndSettle();
        expect(app.location, '/verify');
        expect(find.byType(RegisterView), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('AUT-02.back: AUT-01 ekranına döner', (tester) async {
      final router = await _pumpRouter(tester);
      expect(find.byType(RegisterView), findsOneWidget);
      await tester.tap(find.byKey(_back));
      await tester.pumpAndSettle();
      expect(find.byType(RegisterView), findsNothing);
      expect(find.text('/login'), findsOneWidget);
      expect(router.routerDelegate.currentConfiguration.uri.path, '/login');
    });

    testWidgets('AUT-02.back: yığında sayfa yoksa AUT-01 ekranına gider', (
      tester,
    ) async {
      final router = await _pumpRouter(tester, location: '/solo');
      await tester.tap(find.byKey(_back));
      await tester.pumpAndSettle();
      expect(find.text('/login'), findsOneWidget);
      expect(router.routerDelegate.currentConfiguration.uri.path, '/login');
    });

    testWidgets('AUT-02.toLogin: AUT-01 (`go`)', (tester) async {
      final router = await _pumpRouter(tester);
      await tester.tap(find.byKey(_toLogin));
      await tester.pumpAndSettle();
      expect(find.text('/login'), findsOneWidget);
      expect(find.byType(RegisterView), findsNothing);
      expect(router.routerDelegate.currentConfiguration.uri.path, '/login');
      expect(router.canPop(), isFalse);
    });

    testWidgets('AUT-02.legal: AUT-06 KVKK sekmesi `push` ile açılır; geri '
        'dönünce form korunur', (tester) async {
      final router = await _pumpRouter(tester);
      await tester.enterText(find.byKey(_name), _validName);
      await tester.tap(find.byKey(_legal));
      await tester.pumpAndSettle();
      expect(find.text('/legal/kvkk'), findsOneWidget);
      expect(router.canPop(), isTrue);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('/legal/kvkk'), findsNothing);
      expect(find.byType(RegisterView), findsOneWidget);
      expect(_field(tester, _name).controller!.text, _validName);
      expect(
        ProviderScope.containerOf(
          tester.element(find.byType(RegisterView)),
        ).read(registerViewModelProvider).name,
        _validName,
      );
    });

    testWidgets('AUT-02.legalPrivacy: AUT-06 gizlilik sekmesi `push` ile '
        'açılır', (tester) async {
      final router = await _pumpRouter(tester);
      await tester.tap(find.byKey(_legalPrivacy));
      await tester.pumpAndSettle();
      expect(find.text('/legal/gizlilik'), findsOneWidget);
      expect(router.canPop(), isTrue);
      // Bağlantı onay kutusunu işaretlemez.
      router.pop();
      await tester.pumpAndSettle();
      expect(tester.widget<GuCheckbox>(find.byKey(_legalCheck)).value, isFalse);
    });
  });
}
