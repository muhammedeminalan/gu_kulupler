// AUT-04 · Şifre sıfırlama — içerik (TR / EN), 3 aksiyon (+ "gönderildi"
// görünümünün 2 koşullu aksiyonu) ve sonuçları, doğrulama ve sunucu hataları,
// hesabın sızdırılmaması, 60 sn geri sayım, cihaz matrisi (+ klavye), aksiyon
// envanteri, dokunma hedefleri, açık + koyu golden (form, hatalı,
// gönderildi). Referans: design/reference-shots/screens/AUT-04__*.webp.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/auth/provider/reset_password_state.dart';
import 'package:gu_kulupler/features/auth/provider/reset_password_view_model.dart';
import 'package:gu_kulupler/features/auth/view/reset_password_view.dart';
import 'package:gu_kulupler/features/auth/view/widget/reset_password_sent.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fakes/fake_auth_repository.dart';
import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_session_states.dart';
import '../../../fakes/register_fakes.dart';
import '../../../fakes/test_router.dart';
import '../../../helpers/a11y_guidelines.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/fake_app_clock.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';

final Key _back = GuKey.action('AUT-04.back');
final Key _email = GuKey.action('AUT-04.email');
final Key _send = GuKey.action('AUT-04.send');
final Key _toLogin = GuKey.action('AUT-04.toLogin');
final Key _resend = GuKey.action('AUT-04.resend');

const String _validEmail = 'ayse.yilmaz@ogr.gumushane.edu.tr';
const Duration _cooldown = Duration(seconds: 60);

/// Hatalı form: alan hatası + alana bağlanamayan sunucu hatası.
///
/// Enjekte edilen sabit görünüm durumudur (doğrulayıcı çalışmaz). Adres
/// `AUT-04__errors` golden'ında görünür ve D-27'nin kalıcı hâlini yansıtır;
/// geçici `gmail.com` izni (W-61, CD-136) bu fixture'ı değiştirmez.
const ResetPasswordState _errorState = ResetPasswordState(
  email: 'ayse@gmail.com',
  errors: {ResetField.email: FormFieldError.domainNotAllowed},
  submitError: SubmitError.unknown,
);

/// "Gönderildi" görünümü; geri sayım 60 sn'den başlar.
final ResetPasswordState _sentState = ResetPasswordState(
  email: _validEmail,
  isSent: true,
  resendAvailableAt: kDefaultFakeNowUtc.add(_cooldown),
);

FakeAuthRepository _auth() => GetIt.I<AuthRepository>() as FakeAuthRepository;

FakeFeedbackService _feedback() =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;

FakeConnectivityService _connectivity() =>
    GetIt.I<ConnectivityService>() as FakeConnectivityService;

FakeAppClock _clock() => GetIt.I<AppClock>() as FakeAppClock;

TextField _field(WidgetTester tester) =>
    tester.widget<TextField>(find.byKey(_email));

bool _hasFocus(WidgetTester tester) => _field(tester).focusNode!.hasFocus;

GuInput _input(WidgetTester tester) => tester.widget<GuInput>(
  find.ancestor(of: find.byKey(_email), matching: find.byType(GuInput)),
);

GuButton _button(WidgetTester tester, Key key) =>
    tester.widget<GuButton>(find.byKey(key));

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.tap(find.byKey(key));
  await tester.pump();
}

/// Adresi yazıp "Bağlantı gönder"e dokunur ve sonucu bekler.
Future<void> _submit(WidgetTester tester, [String email = _validEmail]) async {
  await tester.enterText(find.byKey(_email), email);
  await _tap(tester, _send);
  await tester.pump();
}

/// Saati ve geri sayımı [by] kadar ilerletir (saniyelik adımlarla).
Future<void> _elapse(WidgetTester tester, Duration by) async {
  for (var i = 0; i < by.inSeconds; i++) {
    _clock().advance(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }
}

/// Ekrandaki `AUT-04.*` anahtarları.
Set<String> _keys(WidgetTester tester) => {
  for (final key in ActionInventory.found(tester))
    if (key.startsWith('AUT-04.')) key,
};

/// Ekranı geçici rotalarla çizer: `/login` (+ `reset` alt rotası) ve yığınsız
/// açılış için `/solo`.
Future<GoRouter> _pumpRouter(
  WidgetTester tester, {
  String location = '/login/reset',
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
              path: 'reset',
              builder: (context, state) => const ResetPasswordView(),
            ),
          ],
        ),
        GoRoute(
          path: '/solo',
          builder: (context, state) => const ResetPasswordView(),
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
  group('AUT-04 · Şifre sıfırlama', () {
    for (final locale in DeviceMatrix.locales) {
      testWidgets('içerik (${locale.languageCode}): çubuk, açıklama, alan, '
          'düğme', (tester) async {
        await tester.pumpApp(const ResetPasswordView(), locale: locale);
        final l10n = tester.l10n;

        // Çubuk: geri + başlık.
        expect(
          find.descendant(
            of: find.byType(GuAppBar),
            matching: find.text(l10n.authResetTitle),
          ),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel(l10n.a11yBack), findsOneWidget);

        // Açıklama + alan (etiket, ikon; yer tutucu ve yardım yok).
        expect(find.text(l10n.authResetDesc), findsOneWidget);
        expect(find.text(l10n.authUniEmail), findsOneWidget);
        expect(_input(tester).label, l10n.authUniEmail);
        expect(_input(tester).icon, GuIcons.mail);
        expect(_input(tester).placeholder, isNull);
        expect(_input(tester).help, isNull);
        expect(_input(tester).errorText, isNull);
        expect(_field(tester).keyboardType, TextInputType.emailAddress);
        expect(_field(tester).textInputAction, TextInputAction.done);
        // Tek alanlı form: açılışta odak alandadır.
        expect(_hasFocus(tester), isTrue);

        // Gönder.
        final send = _button(tester, _send);
        expect(send.label, l10n.authResetSend);
        expect(send.variant, GuButtonVariant.primary);
        expect(send.size, GuButtonSize.lg);
        expect(send.full, isTrue);
        expect(send.loading, isFalse);

        // Hata satırı ve "gönderildi" görünümü yok.
        expect(find.text(l10n.sysErrorTitle), findsNothing);
        expect(find.byType(ResetPasswordSent), findsNothing);
        await expectA11yGuidelines(tester);
      });

      testWidgets('gönderildi (${locale.languageCode}): işaret, başlık, '
          'adres, "Girişe dön", geri sayımlı "Tekrar gönder"', (tester) async {
        await tester.pumpApp(
          const ResetPasswordView(),
          locale: locale,
          overrides: [
            resetPasswordViewModelProvider.overrideWithBuild(
              (ref, notifier) => _sentState,
            ),
          ],
        );
        final l10n = tester.l10n;

        expect(find.text(l10n.authResetTitle), findsOneWidget);
        final check = tester.widget<GuSuccessCheck>(
          find.byType(GuSuccessCheck),
        );
        expect(check.size, 96);
        expect(check.semanticLabel, l10n.commonSuccess);
        expect(find.text(l10n.authResetSentTitle), findsOneWidget);
        expect(find.text(l10n.authResetSentDesc(_validEmail)), findsOneWidget);

        final toLogin = _button(tester, _toLogin);
        expect(toLogin.label, l10n.authResetToLogin);
        expect(toLogin.variant, GuButtonVariant.primary);
        expect(toLogin.size, GuButtonSize.lg);
        expect(toLogin.full, isTrue);

        final resend = _button(tester, _resend);
        expect(resend.label, l10n.authResendIn('60'));
        expect(resend.variant, GuButtonVariant.text);
        expect(resend.size, GuButtonSize.md);
        expect(resend.disabled, isTrue);
        expect(resend.loading, isFalse);

        // Form kalkmıştır.
        expect(find.byKey(_email), findsNothing);
        expect(find.byKey(_send), findsNothing);
        expect(find.text(l10n.authResetDesc), findsNothing);
      });
    }

    testWidgets('aksiyon envanteri: 3 aksiyon', (tester) async {
      await tester.pumpApp(const ResetPasswordView());
      expectActionInventory(tester, 'AUT-04');
      expect(_keys(tester), {'AUT-04.back', 'AUT-04.email', 'AUT-04.send'});
    });

    testWidgets('aksiyon envanteri (gönderildi): geri + 2 koşullu aksiyon '
        '(`screens-auth.js:130`)', (tester) async {
      await tester.pumpApp(const ResetPasswordView());
      await _submit(tester);
      expect(_keys(tester), {
        'AUT-04.back',
        'AUT-04.toLogin',
        'AUT-04.resend',
      });
    });

    testWidgets('cihaz matrisi: taşma yok (klavye + güvenli alanlar)', (
      tester,
    ) async {
      await DeviceMatrix.run(
        tester,
        (_) => const ResetPasswordView(),
        keyboard: true,
        safeAreas: true,
      );
    });

    testWidgets('cihaz matrisi: hata satırları açıkken taşma yok', (
      tester,
    ) async {
      await DeviceMatrix.run(
        tester,
        (_) => const ResetPasswordView(),
        keyboard: true,
        overrides: [
          resetPasswordViewModelProvider.overrideWithBuild(
            (ref, notifier) => _errorState,
          ),
        ],
      );
    });

    testWidgets('cihaz matrisi: gönderildi görünümünde taşma yok (geri sayım, '
        'hata satırı)', (tester) async {
      await DeviceMatrix.run(
        tester,
        (_) => const ResetPasswordView(),
        safeAreas: true,
        overrides: [
          resetPasswordViewModelProvider.overrideWithBuild(
            (ref, notifier) =>
                _sentState.copyWith(submitError: SubmitError.unknown),
          ),
        ],
      );
    });

    testWidgets('yerleşim: yatay 16, üst 16, aralık 16; alan 48, düğme 56; '
        'alt boşluk gerçek güvenli alan + 8', (tester) async {
      await tester.pumpApp(
        const ResetPasswordView(),
        viewPadding: const EdgeInsets.only(top: 47, bottom: 34),
      );
      final l10n = tester.l10n;
      final bar = tester.getRect(find.byType(GuAppBar));
      expect(bar, const Rect.fromLTWH(0, 0, 390, 47 + 56));

      final desc = tester.getRect(find.text(l10n.authResetDesc));
      expect(desc.left, 16);
      expect(desc.right, 390 - 16);
      expect(desc.top, bar.bottom + 16);
      // `t-body-m` 15 / 22: iki satır.
      expect(desc.height, 44);

      final input = tester.getRect(find.byType(GuInput));
      expect(input.left, 16);
      expect(input.right, 390 - 16);
      expect(input.top - desc.bottom, 16);

      final send = tester.getRect(find.byKey(_send));
      expect(send.size, const Size(358, 56));
      expect(send.top - input.bottom, 16);

      final scroll = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(scroll.padding, const EdgeInsets.fromLTRB(16, 16, 16, 34 + 8));
    });

    testWidgets('yerleşim (gönderildi): ortalı sütun, üst 16 + 24, aralık 12; '
        '"Girişe dön" tam genişlik', (tester) async {
      await tester.pumpApp(
        const ResetPasswordView(),
        overrides: [
          resetPasswordViewModelProvider.overrideWithBuild(
            (ref, notifier) => _sentState,
          ),
        ],
      );
      final l10n = tester.l10n;
      final bar = tester.getRect(find.byType(GuAppBar));
      final check = tester.getRect(find.byType(GuSuccessCheck));
      expect(check.size, const Size(96, 96));
      expect(check.center.dx, 195);
      expect(check.top, bar.bottom + 16 + 24);

      final title = tester.getRect(find.text(l10n.authResetSentTitle));
      expect(title.top - check.bottom, 12);
      expect(title.center.dx, 195);
      final desc = tester.getRect(
        find.text(l10n.authResetSentDesc(_validEmail)),
      );
      expect(desc.top - title.bottom, 12);
      expect(desc.left, greaterThanOrEqualTo(16));
      expect(desc.right, lessThanOrEqualTo(390 - 16));

      final toLogin = tester.getRect(find.byKey(_toLogin));
      expect(toLogin.size, const Size(358, 56));
      expect(toLogin.top - desc.bottom, 12);

      final resend = tester.getRect(find.byKey(_resend));
      expect(resend.top - toLogin.bottom, 12);
      expect(resend.center.dx, 195);
      // Metin düğmesi 44 yüksekliğindedir ve içeriği kadar yer kaplar.
      expect(resend.height, 44);
      expect(resend.width, lessThan(358));
    });

    testWidgets('dokunma hedefleri: Android 48 dp / iOS 44 pt (K-03)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      for (final state in [
        const ResetPasswordState(),
        // Geri sayım bitmiş: "Tekrar gönder" etkin.
        _sentState.copyWith(resendAvailableAt: kDefaultFakeNowUtc),
      ]) {
        final overrides = [
          resetPasswordViewModelProvider.overrideWithBuild(
            (ref, notifier) => state,
          ),
        ];
        await tester.pumpApp(const ResetPasswordView(), overrides: overrides);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await tester.pumpApp(
          const ResetPasswordView(),
          platform: TargetPlatform.iOS,
          overrides: overrides,
        );
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      }
      handle.dispose();
    });

    testWidgets('golden: açık + koyu', (tester) async {
      const locale = Locale('tr');
      for (final theme in kGoldenThemes) {
        await tester.pumpApp(const ResetPasswordView(), theme: theme);
        // Referans görüntü odaksızdır: odak kenarlığı ve imleç golden'a
        // girmesin.
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        await tester.pump(GuMotion.base);
        await expectLater(
          find.byKey(kPumpAppBoundaryKey),
          matchesGoldenFile(goldenUri(goldenPath('AUT-04', theme, locale))),
        );
      }
    });

    testWidgets('golden: hatalı form (alan hatası + sunucu hatası)', (
      tester,
    ) async {
      const locale = Locale('tr');
      for (final theme in kGoldenThemes) {
        await tester.pumpApp(
          const ResetPasswordView(),
          theme: theme,
          overrides: [
            resetPasswordViewModelProvider.overrideWithBuild(
              (ref, notifier) => _errorState,
            ),
          ],
        );
        await tester.enterText(find.byKey(_email), _errorState.email);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        await tester.pump(GuMotion.base);
        await expectLater(
          find.byKey(kPumpAppBoundaryKey),
          matchesGoldenFile(
            goldenUri(goldenPath('AUT-04__errors', theme, locale)),
          ),
        );
      }
    });

    testWidgets('golden: gönderildi (geri sayım 60 sn)', (tester) async {
      const locale = Locale('tr');
      for (final theme in kGoldenThemes) {
        await tester.pumpApp(
          const ResetPasswordView(),
          theme: theme,
          overrides: [
            resetPasswordViewModelProvider.overrideWithBuild(
              (ref, notifier) => _sentState,
            ),
          ],
        );
        // Başarı işaretinin çizimi biter (daire 500 + tik 200 + 320 ms).
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(GuMotion.base);
        await expectLater(
          find.byKey(kPumpAppBoundaryKey),
          matchesGoldenFile(
            goldenUri(goldenPath('AUT-04__sent', theme, locale)),
          ),
        );
      }
    });
  });

  group('AUT-04 · Şifre sıfırlama · gönderim', () {
    testWidgets('AUT-04.email: yazılan değer state alanına işlenir', (
      tester,
    ) async {
      await tester.pumpApp(const ResetPasswordView());
      await tester.enterText(find.byKey(_email), _validEmail);
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ResetPasswordView)),
      );
      expect(container.read(resetPasswordViewModelProvider).email, _validEmail);
    });

    testWidgets('AUT-04.send: her doğrulama hatasının metni; odak alanda '
        'kalır, istek gitmez', (tester) async {
      await tester.pumpApp(const ResetPasswordView());
      final l10n = tester.l10n;
      for (final (value, message) in [
        ('', l10n.authErrRequired),
        ('ayse', l10n.authErrEmail),
        ('ayse@hotmail.com', l10n.authErrDomain),
      ]) {
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        await _submit(tester, value);
        expect(_input(tester).errorText, message, reason: value);
        expect(find.text(message), findsOneWidget);
        expect(_hasFocus(tester), isTrue, reason: value);
      }
      expect(_auth().callsTo('sendPasswordReset'), isEmpty);
      expect(_feedback().toasts, isEmpty);
      expect(find.byType(ResetPasswordSent), findsNothing);
    });

    testWidgets('alan düzenlenince hata kaybolur', (tester) async {
      await tester.pumpApp(const ResetPasswordView());
      await _tap(tester, _send);
      expect(_input(tester).errorText, tester.l10n.authErrRequired);
      await tester.enterText(find.byKey(_email), 'a');
      await tester.pump();
      expect(_input(tester).errorText, isNull);
    });

    testWidgets('AUT-04.send: geçerli adres → bağlantı istenir (adres '
        'kırpılır), form "gönderildi" görünümüne geçer; toast yok', (
      tester,
    ) async {
      await tester.pumpApp(const ResetPasswordView());
      final l10n = tester.l10n;
      await _submit(tester, '  $_validEmail ');

      expect(_auth().resetSent, [_validEmail]);
      expect(find.byType(ResetPasswordSent), findsOneWidget);
      expect(find.byKey(_email), findsNothing);
      expect(find.text(l10n.authResetSentTitle), findsOneWidget);
      expect(find.text(l10n.authResetSentDesc(_validEmail)), findsOneWidget);
      expect(_button(tester, _resend).label, l10n.authResendIn('60'));
      expect(_button(tester, _resend).disabled, isTrue);
      expect(_feedback().toasts, isEmpty);
      // Alan kalkınca klavye bağlantısı kapanır.
      expect(tester.testTextInput.hasAnyClients, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('klavye eylem tuşu formu gönderir', (tester) async {
      await tester.pumpApp(const ResetPasswordView());
      await tester.enterText(find.byKey(_email), _validEmail);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump();
      expect(_auth().resetSent, [_validEmail]);
      expect(find.byType(ResetPasswordSent), findsOneWidget);
    });

    testWidgets('AUT-04.send: art arda iki dokunma tek istek gönderir', (
      tester,
    ) async {
      await tester.pumpApp(const ResetPasswordView());
      await tester.enterText(find.byKey(_email), _validEmail);
      await tester.tap(find.byKey(_send));
      await tester.tap(find.byKey(_send));
      await tester.pump();
      await tester.pump();
      expect(_auth().callsTo('sendPasswordReset'), hasLength(1));
    });

    testWidgets('gönderim sürerken düğme meşgul görünür', (tester) async {
      await tester.pumpApp(
        const ResetPasswordView(),
        overrides: [
          resetPasswordViewModelProvider.overrideWithBuild(
            (ref, notifier) => const ResetPasswordState(
              email: _validEmail,
              isSubmitting: true,
            ),
          ),
        ],
      );
      expect(_button(tester, _send).loading, isTrue);
      expect(find.byType(GuSpinner), findsOneWidget);
      await _tap(tester, _send);
      expect(_auth().callsTo('sendPasswordReset'), isEmpty);
    });

    testWidgets('kayıtlı olmayan ya da askıdaki hesap: aynı "gönderildi" '
        'görünümü (hesap sızdırılmaz)', (tester) async {
      for (final arrange in <void Function()>[
        () => _auth().service.failNext(AuthError.invalidCredentials),
        () => _auth().failNext(AuthError.userDisabled),
      ]) {
        await tester.pumpApp(const ResetPasswordView());
        final l10n = tester.l10n;
        arrange();
        await _submit(tester);
        expect(find.text(l10n.authResetSentTitle), findsOneWidget);
        expect(find.text(l10n.authResetSentDesc(_validEmail)), findsOneWidget);
        expect(find.text(l10n.sysErrorTitle), findsNothing);
        expect(_feedback().toasts, isEmpty);
      }
    });

    testWidgets('çevrimdışı: TST-24, istek gitmez; form açık kalır', (
      tester,
    ) async {
      await tester.pumpApp(const ResetPasswordView());
      _connectivity().isOffline = true;
      await _submit(tester);
      expect(_feedback().toasts, [ToastId.tst24]);
      expect(_auth().callsTo('sendPasswordReset'), isEmpty);
      expect(find.byKey(_email), findsOneWidget);
      expect(_button(tester, _send).loading, isFalse);
      expect(find.text(tester.l10n.sysErrorTitle), findsNothing);
    });

    testWidgets('ağ hatası: TST-24; form açık kalır, satır içi hata yok', (
      tester,
    ) async {
      await tester.pumpApp(const ResetPasswordView());
      _auth().service.failNext(AuthError.network);
      await _submit(tester);
      expect(_feedback().toasts, [ToastId.tst24]);
      expect(find.byKey(_email), findsOneWidget);
      expect(_button(tester, _send).loading, isFalse);
      expect(find.text(tester.l10n.sysErrorTitle), findsNothing);
    });

    testWidgets('sunucu adresi reddederse hata alanın altında, odak alanda', (
      tester,
    ) async {
      await tester.pumpApp(const ResetPasswordView());
      final l10n = tester.l10n;
      _auth().service.failNext(AuthError.invalidEmail);
      await _submit(tester);
      expect(_input(tester).errorText, l10n.authErrEmail);
      expect(_hasFocus(tester), isTrue);
      expect(find.byType(ResetPasswordSent), findsNothing);
    });

    testWidgets('sunucu kısıtı: TST-X3 "60"; bekleme sürerken yeni dokunma '
        'istek göndermez', (tester) async {
      await tester.pumpApp(const ResetPasswordView());
      _auth().service.failNext(AuthError.tooManyRequests);
      await _submit(tester);
      expect(_feedback().toasts, [ToastId.tstX3]);
      expect(_feedback().toastParams.single.s, '60');
      expect(find.byKey(_email), findsOneWidget);

      _clock().advance(const Duration(seconds: 20));
      await _tap(tester, _send);
      await tester.pump();
      expect(_feedback().toastParams.last.s, '40');
      expect(_auth().callsTo('sendPasswordReset'), hasLength(1));
    });

    testWidgets('bilinmeyen hata: düğmenin altında genel hata satırı; adres '
        'düzenlenince kaybolur', (tester) async {
      await tester.pumpApp(const ResetPasswordView());
      final l10n = tester.l10n;
      _auth().failNext(AuthError.unknown);
      await _submit(tester);

      final error = find.text(l10n.sysErrorTitle);
      expect(error, findsOneWidget);
      expect(
        tester.getTopLeft(error).dy,
        greaterThan(tester.getBottomLeft(find.byKey(_send)).dy),
      );
      expect(_feedback().toasts, isEmpty);
      expect(_button(tester, _send).loading, isFalse);
      expect(find.byType(ResetPasswordSent), findsNothing);

      await tester.enterText(find.byKey(_email), 'ayse@gumushane.edu.tr');
      await tester.pump();
      expect(error, findsNothing);
    });
  });

  group('AUT-04 · Şifre sıfırlama · yeniden gönderim', () {
    testWidgets('AUT-04.resend: bekleme sürerken devre dışı görünür; dokunma '
        'TST-X3 {s} gösterir, istek gitmez', (tester) async {
      await tester.pumpApp(const ResetPasswordView());
      await _submit(tester);
      expect(_button(tester, _resend).disabled, isTrue);

      await _tap(tester, _resend);
      expect(_feedback().toasts, [ToastId.tstX3]);
      expect(_feedback().toastParams.single.s, '60');

      await _elapse(tester, const Duration(seconds: 15));
      await _tap(tester, _resend);
      expect(_feedback().toastParams.last.s, '45');
      expect(_auth().callsTo('sendPasswordReset'), hasLength(1));
    });

    testWidgets('geri sayım saniye saniye iner; dolunca "Tekrar gönder" '
        'açılır', (tester) async {
      await tester.pumpApp(const ResetPasswordView());
      final l10n = tester.l10n;
      await _submit(tester);
      expect(find.text(l10n.authResendIn('60')), findsOneWidget);

      await _elapse(tester, const Duration(seconds: 1));
      expect(find.text(l10n.authResendIn('59')), findsOneWidget);
      await _elapse(tester, const Duration(seconds: 58));
      expect(find.text(l10n.authResendIn('1')), findsOneWidget);
      expect(_button(tester, _resend).disabled, isTrue);

      await _elapse(tester, const Duration(seconds: 1));
      expect(_button(tester, _resend).label, l10n.authResend);
      expect(_button(tester, _resend).disabled, isFalse);
    });

    testWidgets('AUT-04.resend: bekleme dolunca bağlantı yeniden istenir, '
        'TST-03; geri sayım baştan başlar', (tester) async {
      await tester.pumpApp(const ResetPasswordView());
      final l10n = tester.l10n;
      await _submit(tester);
      await _elapse(tester, _cooldown);

      await _tap(tester, _resend);
      await tester.pump();
      expect(_auth().resetSent, [_validEmail, _validEmail]);
      expect(_feedback().toasts, [ToastId.tst03]);
      expect(_button(tester, _resend).label, l10n.authResendIn('60'));
      expect(_button(tester, _resend).disabled, isTrue);

      await _elapse(tester, const Duration(seconds: 2));
      expect(find.text(l10n.authResendIn('58')), findsOneWidget);
      // Görünüm değişmez.
      expect(find.text(l10n.authResetSentTitle), findsOneWidget);
    });

    testWidgets('yeniden gönderim sürerken "Tekrar gönder" meşgul görünür', (
      tester,
    ) async {
      await tester.pumpApp(
        const ResetPasswordView(),
        overrides: [
          resetPasswordViewModelProvider.overrideWithBuild(
            (ref, notifier) => _sentState.copyWith(
              resendAvailableAt: kDefaultFakeNowUtc,
              isSubmitting: true,
            ),
          ),
        ],
      );
      expect(_button(tester, _resend).loading, isTrue);
      expect(_button(tester, _toLogin).loading, isFalse);
    });

    testWidgets('çevrimdışı / ağ hatası: TST-24; görünüm değişmez', (
      tester,
    ) async {
      await tester.pumpApp(const ResetPasswordView());
      await _submit(tester);
      await _elapse(tester, _cooldown);

      _connectivity().isOffline = true;
      await _tap(tester, _resend);
      await tester.pump();
      expect(_feedback().toasts, [ToastId.tst24]);
      expect(_auth().callsTo('sendPasswordReset'), hasLength(1));

      _connectivity().isOffline = false;
      _auth().service.failNext(AuthError.network);
      await _tap(tester, _resend);
      await tester.pump();
      expect(_feedback().toasts, [ToastId.tst24, ToastId.tst24]);
      expect(find.byType(ResetPasswordSent), findsOneWidget);
      expect(_button(tester, _resend).disabled, isFalse);
      expect(find.text(tester.l10n.sysErrorTitle), findsNothing);
    });

    testWidgets('bilinmeyen hata: "Tekrar gönder"in altında genel hata '
        'satırı; sonraki başarılı gönderimde kaybolur', (tester) async {
      await tester.pumpApp(const ResetPasswordView());
      final l10n = tester.l10n;
      await _submit(tester);
      await _elapse(tester, _cooldown);

      _auth().failNext(AuthError.unknown);
      await _tap(tester, _resend);
      await tester.pump();
      final error = find.text(l10n.sysErrorTitle);
      expect(error, findsOneWidget);
      expect(
        tester.getTopLeft(error).dy,
        greaterThan(tester.getBottomLeft(find.byKey(_resend)).dy),
      );
      expect(_feedback().toasts, isEmpty);

      await _tap(tester, _resend);
      await tester.pump();
      expect(error, findsNothing);
      expect(_feedback().toasts, [ToastId.tst03]);
    });
  });

  group('AUT-04 · Şifre sıfırlama · gezinme', () {
    testWidgets('gerçek rota: `/login/reset` misafire açılır; bağlantı '
        'istenince ekran gezinmez', (tester) async {
      final app = await TestRouter.pump(
        tester,
        session: FakeSessionStates.signedOut,
        location: '/login/reset',
      );
      expect(app.location, '/login/reset');
      expect(find.byType(ResetPasswordView), findsOneWidget);

      await _submit(tester);
      expect(_auth().resetSent, [_validEmail]);
      expect(app.location, '/login/reset');
      expect(find.byType(ResetPasswordSent), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AUT-04.back: AUT-01 ekranına döner', (tester) async {
      final router = await _pumpRouter(tester);
      expect(find.byType(ResetPasswordView), findsOneWidget);
      await tester.tap(find.byKey(_back));
      await tester.pumpAndSettle();
      expect(find.byType(ResetPasswordView), findsNothing);
      expect(find.text('/login'), findsOneWidget);
      expect(router.routerDelegate.currentConfiguration.uri.path, '/login');
    });

    testWidgets('AUT-04.back: yığında sayfa yoksa AUT-01 ekranına gider', (
      tester,
    ) async {
      final router = await _pumpRouter(tester, location: '/solo');
      await tester.tap(find.byKey(_back));
      await tester.pumpAndSettle();
      expect(find.text('/login'), findsOneWidget);
      expect(router.routerDelegate.currentConfiguration.uri.path, '/login');
    });

    testWidgets(
      'AUT-04.back: "gönderildi" görünümünden de AUT-01 ekranına döner',
      (
        tester,
      ) async {
        final router = await _pumpRouter(tester);
        await _submit(tester);
        await tester.tap(find.byKey(_back));
        await tester.pumpAndSettle();
        expect(find.text('/login'), findsOneWidget);
        expect(router.routerDelegate.currentConfiguration.uri.path, '/login');
      },
    );

    testWidgets('AUT-04.toLogin: AUT-01 (`go`); yeniden açılınca form '
        'sıfırdan başlar', (tester) async {
      final router = await _pumpRouter(tester);
      await _submit(tester);
      await tester.tap(find.byKey(_toLogin));
      await tester.pumpAndSettle();
      expect(find.text('/login'), findsOneWidget);
      expect(find.byType(ResetPasswordView), findsNothing);
      expect(router.routerDelegate.currentConfiguration.uri.path, '/login');
      expect(router.canPop(), isFalse);

      router.go('/login/reset');
      await tester.pumpAndSettle();
      expect(find.byType(ResetPasswordSent), findsNothing);
      expect(find.byKey(_email), findsOneWidget);
      expect(_field(tester).controller!.text, isEmpty);
    });
  });
}
