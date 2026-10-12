// AUT-03 · E-postanı doğrula — içerik (TR / EN), 4 aksiyon ve sonuçları
// (TST-02, TST-03, TST-X3, TST-24, DLG-06, başarı görünümü, yönlendirme),
// geri sayım, meşgul / hata durumları, geri tuşu, cihaz matrisi, aksiyon
// envanteri, açık + koyu golden (varsayılan, bekleme + hata, başarı).
// `AUT-03.demoVerify` muaftır (K-02).
// Referans: design/reference-shots/screens/AUT-03__*.webp.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/auth/provider/verify_email_state.dart';
import 'package:gu_kulupler/features/auth/provider/verify_email_view_model.dart';
import 'package:gu_kulupler/features/auth/view/verify_email_view.dart';
import 'package:gu_kulupler/product/feedback/catalogs/toasts/toast_catalog.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/navigation/app_redirect.dart';
import 'package:gu_kulupler/product/navigation/session_refresh_listenable.dart';
import 'package:gu_kulupler/product/navigation/splash_hold.dart';
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

final Key _confirm = GuKey.action('AUT-03.confirm');
final Key _resend = GuKey.action('AUT-03.resend');
final Key _changeEmail = GuKey.action('AUT-03.changeEmail');
final Key _logout = GuKey.action('AUT-03.logout');

const String _email = 'unverified@ogr.gumushane.edu.tr';
const String _uid = 'u1';
const Duration _second = Duration(seconds: 1);

/// Varsayılan görünüm: adres belli, bekleme yok.
const VerifyEmailState _idle = VerifyEmailState(email: _email);

/// "Tekrar gönder" beklemesi sürüyor (60 sn) + beklenmeyen hata satırı.
final VerifyEmailState _waiting = VerifyEmailState(
  email: _email,
  resendAvailableAt: kDefaultFakeNowUtc.add(
    Limits.verificationResendCooldown,
  ),
  isError: true,
);

/// Başarı görünümü (onay işareti + "E-postan doğrulandı").
const VerifyEmailState _done = VerifyEmailState(
  email: _email,
  isVerified: true,
);

List<Override> _withState(VerifyEmailState state) => [
  verifyEmailViewModelProvider.overrideWithBuild((ref, notifier) => state),
];

FakeAuthRepository _auth() => GetIt.I<AuthRepository>() as FakeAuthRepository;

FakeUserRepository _users() => GetIt.I<UserRepository>() as FakeUserRepository;

FakeFeedbackService _feedback() =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;

FakeAppClock _clock() => GetIt.I<AppClock>() as FakeAppClock;

FakeConnectivityService _connectivity() =>
    GetIt.I<ConnectivityService>() as FakeConnectivityService;

FakeAppPreferencesStore _store() =>
    GetIt.I<AppPreferencesStore>() as FakeAppPreferencesStore;

AuthUserInfo _user() =>
    const AuthUserInfo(uid: _uid, email: _email, emailVerified: false);

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(VerifyEmailView)));

VerifyEmailState _stateOf(WidgetTester tester) =>
    _container(tester).read(verifyEmailViewModelProvider);

GuButton _button(WidgetTester tester, Key key) =>
    tester.widget<GuButton>(find.byKey(key));

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.tap(find.byKey(key));
  await tester.pump();
}

/// Ekranı [state] ile çizer ve doğrulanmamış oturumu kurar (`pumpApp`
/// sahteleri baştan kaydettiği için oturum çizimden sonra yazılır).
Future<void> _pump(
  WidgetTester tester, {
  VerifyEmailState state = _idle,
  Locale locale = const Locale('tr'),
  EdgeInsets viewPadding = EdgeInsets.zero,
}) async {
  await tester.pumpApp(
    const VerifyEmailView(),
    locale: locale,
    viewPadding: viewPadding,
    overrides: _withState(state),
  );
  _auth()
    ..service.uid = _uid
    ..currentUser = _user();
}

/// Ekranı gerçek yönlendirmeyle (`AppRedirect`) ve gerçek oturum katmanıyla
/// çizer; hedef ekranlar yer tutucudur (yollarını gösterir). Doğrulanmamış
/// oturum açılır ve `/verify`'a yerleşilir.
Future<GoRouter> _pumpRouter(WidgetTester tester) async {
  GoRouter? created;
  await tester.pumpAppRouter(
    routerOf: (ref) => created ??= GoRouter(
      initialLocation: '/verify',
      redirect: AppRedirect.goRouterRedirect,
      refreshListenable: ref.read(sessionRefreshListenableProvider),
      routes: [
        GoRoute(
          path: '/verify',
          builder: (context, state) => const VerifyEmailView(),
        ),
        for (final path in [
          '/splash',
          '/onboarding',
          '/login',
          '/setup-profile',
          '/clubs',
        ])
          GoRoute(path: path, builder: (context, state) => _Stub(path)),
      ],
    ),
    overrides: [splashHoldProvider.overrideWithBuild((ref, notifier) => false)],
  );
  final router = created!;
  addTearDown(router.dispose);
  _store().values[AppPreferenceKeys.onboardingSeen] = true;
  _auth()
    ..service.uid = _uid
    ..currentUser = _user()
    ..watchAuthStateController.add(_user());
  await tester.pumpAndSettle();
  expect(_location(router), '/verify');
  return router;
}

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

class _Stub extends StatelessWidget {
  const _Stub(this.path);

  final String path;

  @override
  Widget build(BuildContext context) => Scaffold(body: Text(path));
}

void main() {
  group('AUT-03 · E-postanı doğrula', () {
    for (final locale in DeviceMatrix.locales) {
      testWidgets('içerik (${locale.languageCode}): illüstrasyon, başlık, '
          'adresli açıklama, dört düğme', (tester) async {
        await _pump(tester, locale: locale);
        final l10n = tester.l10n;
        final gu = tester.element(find.byType(VerifyEmailView)).gu;

        // Başlık çubuğu yok; illüstrasyon 160.
        expect(find.byType(GuAppBar), findsNothing);
        final illustration = tester.widget<GuIllustration>(
          find.byType(GuIllustration),
        );
        expect(illustration.illustration, GuIllustrations.emailVerify);
        expect(illustration.size, 160);
        expect(find.byType(GuSuccessCheck), findsNothing);

        // Başlık.
        final title = tester.widget<Text>(find.text(l10n.authVerifyTitle));
        expect(title.style, gu.text.titleL);
        expect(title.textAlign, TextAlign.center);

        // Açıklama: cümle ARB'den, adres kalın (etiket ağırlığı), ortalı.
        final description = tester.widget<RichText>(
          find.textContaining(_email, findRichText: true),
        );
        expect(description.text.toPlainText(), l10n.authVerifyDesc(_email));
        expect(description.textAlign, TextAlign.center);
        expect(description.text.style?.color, gu.colors.textSecondary);
        expect(description.text.style?.fontSize, gu.text.bodyM.fontSize);
        expect(description.text.style?.fontWeight, gu.text.bodyM.fontWeight);
        final sentence = (description.text as TextSpan).children!.single;
        final bold = (sentence as TextSpan).children!.first as TextSpan;
        expect(bold.text, _email);
        expect(bold.style?.fontWeight, gu.text.labelL.fontWeight);
        expect(bold.style?.fontSize, gu.text.bodyM.fontSize);
        expect(bold.style?.color, gu.colors.textSecondary);

        // Düğmeler.
        final confirm = _button(tester, _confirm);
        expect(confirm.label, l10n.authVerifyConfirm);
        expect(confirm.variant, GuButtonVariant.primary);
        expect(confirm.size, GuButtonSize.lg);
        expect(confirm.full, isTrue);
        expect(confirm.loading, isFalse);

        final resend = _button(tester, _resend);
        expect(resend.label, l10n.authResend);
        expect(resend.variant, GuButtonVariant.outline);
        expect(resend.size, GuButtonSize.md);
        expect(resend.full, isTrue);
        expect(resend.disabled, isFalse);
        expect(resend.loading, isFalse);

        for (final (key, label) in [
          (_changeEmail, l10n.authChangeEmail),
          (_logout, l10n.authLogout),
        ]) {
          final button = _button(tester, key);
          expect(button.label, label);
          expect(button.variant, GuButtonVariant.text);
          expect(button.full, isTrue);
        }
        for (final label in [
          l10n.authVerifyConfirm,
          l10n.authResend,
          l10n.authChangeEmail,
          l10n.authLogout,
        ]) {
          expect(find.bySemanticsLabel(label), findsOneWidget);
        }

        // Hata satırı yok; demo bağlantısı uygulanmaz (K-02).
        expect(find.text(l10n.sysErrorTitle), findsNothing);
        expect(find.byKey(GuKey.action('AUT-03.demoVerify')), findsNothing);
        expect(
          find.textContaining(l10n.authVerifyDemoLink, findRichText: true),
          findsNothing,
        );
      });
    }

    testWidgets('adres ve bekleme gerçek oturumdan okunur (kayıt sonrası)', (
      tester,
    ) async {
      // Önce sahteler kurulur, sonra ekran aynı ağaçta açılır.
      await tester.pumpApp(const _Gate());
      _auth().service.uid = _uid;
      final registered = await _auth().register(
        email: _email,
        password: 'Sifre123',
        name: 'Ayşe Demir',
      );
      expect(registered.isSuccess, isTrue);

      await tester.tap(find.byType(_Gate));
      await tester.pump();

      final l10n = tester.l10n;
      expect(
        find.textContaining(_email, findRichText: true),
        findsOneWidget,
      );
      expect(_button(tester, _resend).label, l10n.authResendIn('60'));
      expect(_button(tester, _resend).disabled, isTrue);
      expect(
        _stateOf(tester).resendAvailableAt,
        kDefaultFakeNowUtc.add(Limits.verificationResendCooldown),
      );
    });

    testWidgets('aksiyon envanteri: 4 aksiyon (demoVerify muaf)', (
      tester,
    ) async {
      await _pump(tester);
      expectActionInventory(tester, 'AUT-03');
    });

    testWidgets('aksiyon envanteri: bekleme sürerken de aynı', (tester) async {
      await _pump(tester, state: _waiting);
      expectActionInventory(tester, 'AUT-03');
    });

    testWidgets('cihaz matrisi: taşma yok (güvenli alanlar)', (tester) async {
      await DeviceMatrix.run(
        tester,
        (_) => const VerifyEmailView(),
        overrides: _withState(_idle),
        safeAreas: true,
      );
    });

    testWidgets('cihaz matrisi: bekleme + hata satırı açıkken taşma yok', (
      tester,
    ) async {
      await DeviceMatrix.run(
        tester,
        (_) => const VerifyEmailView(),
        overrides: _withState(_waiting),
      );
    });

    testWidgets('cihaz matrisi: başarı görünümünde taşma yok', (tester) async {
      await DeviceMatrix.run(
        tester,
        (_) => const VerifyEmailView(),
        overrides: _withState(_done),
      );
    });

    testWidgets('yerleşim: üst gerçek güvenli alan + 40, yatay 24, aralık 16 / '
        '12; düğmeler 56 · 48 · 44 · 44; alt güvenli alan + 8', (tester) async {
      await _pump(
        tester,
        viewPadding: const EdgeInsets.only(top: 47, bottom: 34),
      );
      final illustration = tester.getRect(find.byType(GuIllustration));
      expect(illustration, const Rect.fromLTWH(115, 47 + 40, 160, 160));

      final title = tester.getRect(find.text(tester.l10n.authVerifyTitle));
      expect(title.top, illustration.bottom + 16);
      final description = tester.getRect(
        find.textContaining(_email, findRichText: true),
      );
      expect(description.top, title.bottom + 16);
      expect(description.left, greaterThanOrEqualTo(24));
      expect(description.right, lessThanOrEqualTo(390 - 24));

      final confirm = tester.getRect(find.byKey(_confirm));
      final resend = tester.getRect(find.byKey(_resend));
      final changeEmail = tester.getRect(find.byKey(_changeEmail));
      final logout = tester.getRect(find.byKey(_logout));
      expect(confirm.top, description.bottom + 16);
      expect(confirm, Rect.fromLTWH(24, confirm.top, 342, 56));
      expect(resend, Rect.fromLTWH(24, confirm.bottom + 12, 342, 48));
      expect(changeEmail, Rect.fromLTWH(24, resend.bottom + 12, 342, 44));
      expect(logout, Rect.fromLTWH(24, changeEmail.bottom + 12, 342, 44));

      // Kaydırma alanının alt boşluğu: 24 + güvenli alan + 8.
      final scroll = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(
        scroll.padding,
        const EdgeInsets.fromLTRB(24, 40, 24, 24 + 34 + 8),
      );
    });

    testWidgets('golden: açık + koyu', (tester) async {
      await goldenForThemes(
        tester,
        'AUT-03',
        const VerifyEmailView(),
        overrides: _withState(_idle),
      );
    });

    testWidgets('golden: bekleme (geri sayım) + hata satırı', (tester) async {
      await goldenForThemes(
        tester,
        'AUT-03__cooldown',
        const VerifyEmailView(),
        overrides: _withState(_waiting),
      );
    });

    testWidgets('golden: başarı görünümü (çizim bitmiş)', (tester) async {
      const locale = Locale('tr');
      for (final theme in kGoldenThemes) {
        await tester.pumpApp(
          const VerifyEmailView(),
          theme: theme,
          overrides: _withState(_done),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(kPumpAppBoundaryKey),
          matchesGoldenFile(
            goldenUri(goldenPath('AUT-03__done', theme, locale)),
          ),
        );
      }
    });
  });

  group('AUT-03 · E-postanı doğrula · AUT-03.confirm', () {
    testWidgets('hâlâ doğrulanmamış → TST-02; ekran aynı kalır', (
      tester,
    ) async {
      await _pump(tester);

      await _tap(tester, _confirm);

      expect(_feedback().toasts, [ToastId.tst02]);
      expect(_auth().callsTo('reloadUser'), hasLength(1));
      expect(_button(tester, _confirm).loading, isFalse);
      expect(find.byType(GuIllustration), findsOneWidget);
      expect(find.text(tester.l10n.authVerifyTitle), findsOneWidget);
    });

    testWidgets('doğrulanmış → başarı görünümü (onay işareti, "E-postan '
        'doğrulandı", düğmeler yok) → oturum çözülür', (tester) async {
      await _pump(tester);
      _auth().service.emailVerified = true;
      final l10n = tester.l10n;

      await _tap(tester, _confirm);

      expect(find.byType(GuSuccessCheck), findsOneWidget);
      expect(find.byType(GuIllustration), findsNothing);
      expect(find.text(l10n.authVerifySuccess), findsOneWidget);
      expect(find.text(l10n.authVerifyTitle), findsNothing);
      expect(find.bySemanticsLabel(l10n.commonSuccess), findsOneWidget);
      // Açıklama kalır; düğmeler kalkar.
      expect(find.textContaining(_email, findRichText: true), findsOneWidget);
      for (final key in [_confirm, _resend, _changeEmail, _logout]) {
        expect(find.byKey(key), findsNothing);
      }
      expect(_feedback().toasts, isEmpty);

      // Başarı görünümü bir süre kalır; ardından oturum yeniden çözülür.
      await tester.pump(VerifyEmailViewModel.successHold);
      await tester.pump();
      expect(
        _container(tester).read(sessionViewModelProvider).status,
        AuthStatus.profileIncomplete,
      );
      expect(find.byType(GuSuccessCheck), findsOneWidget);
    });

    testWidgets('denetim sürerken düğme meşgul', (tester) async {
      await _pump(
        tester,
        state: const VerifyEmailState(email: _email, isChecking: true),
      );
      expect(_button(tester, _confirm).loading, isTrue);
      expect(
        find.descendant(
          of: find.byKey(_confirm),
          matching: find.byType(GuSpinner),
        ),
        findsOneWidget,
      );
      // Meşgul düğme yeni denetim başlatmaz.
      await _tap(tester, _confirm);
      expect(_auth().callsTo('reloadUser'), isEmpty);
    });

    testWidgets('çevrimdışı → TST-24; sunucuya gidilmez', (tester) async {
      await _pump(tester);
      _connectivity().isOffline = true;

      await _tap(tester, _confirm);

      expect(_feedback().toasts, [ToastId.tst24]);
      expect(_auth().callsTo('reloadUser'), isEmpty);
    });

    testWidgets('beklenmeyen hata → düğmenin altında hata satırı; sonraki '
        'denetimde kalkar', (tester) async {
      await _pump(tester);
      final l10n = tester.l10n;
      _auth().failNext(AuthError.unknown);

      await _tap(tester, _confirm);

      final error = find.text(l10n.sysErrorTitle);
      expect(error, findsOneWidget);
      expect(
        tester.getTopLeft(error).dy,
        greaterThan(tester.getRect(find.byKey(_confirm)).bottom),
      );
      expect(
        tester.getBottomLeft(error).dy,
        lessThan(tester.getRect(find.byKey(_resend)).top),
      );
      expect(_feedback().toasts, isEmpty);

      await _tap(tester, _confirm);
      expect(find.text(l10n.sysErrorTitle), findsNothing);
      expect(_feedback().toasts, [ToastId.tst02]);
    });
  });

  group('AUT-03 · E-postanı doğrula · AUT-03.resend', () {
    testWidgets('gönderildi → TST-03; düğme "Tekrar gönder (60 sn)" geri '
        'sayımına döner ve her saniye azalır', (tester) async {
      await _pump(tester);
      final l10n = tester.l10n;

      await _tap(tester, _resend);

      expect(_feedback().toasts, [ToastId.tst03]);
      expect(_auth().callsTo('sendEmailVerification'), hasLength(1));
      expect(_button(tester, _resend).label, l10n.authResendIn('60'));
      expect(_button(tester, _resend).disabled, isTrue);
      expect(_button(tester, _resend).loading, isFalse);

      _clock().advance(_second);
      await tester.pump(_second);
      expect(_button(tester, _resend).label, l10n.authResendIn('59'));

      _clock().advance(const Duration(seconds: 17));
      await tester.pump(_second);
      expect(_button(tester, _resend).label, l10n.authResendIn('42'));
    });

    testWidgets('bekleme sürerken dokunma → TST-X3 kalan saniyeyle; yeniden '
        'gönderilmez', (tester) async {
      await _pump(tester, state: _waiting);
      _clock().advance(const Duration(seconds: 18));
      await tester.pump(_second);
      expect(_button(tester, _resend).label, tester.l10n.authResendIn('42'));

      await _tap(tester, _resend);

      expect(_feedback().toasts, [ToastId.tstX3]);
      expect(_feedback().toastParams, const [ToastParams(s: '42')]);
      expect(_auth().callsTo('sendEmailVerification'), isEmpty);
    });

    testWidgets('bekleme dolunca düğme yeniden açılır ve gönderir', (
      tester,
    ) async {
      await _pump(tester, state: _waiting);
      final l10n = tester.l10n;

      _clock().advance(Limits.verificationResendCooldown);
      await tester.pump(_second);
      await tester.pump();

      expect(_stateOf(tester).resendAvailableAt, isNull);
      expect(_button(tester, _resend).label, l10n.authResend);
      expect(_button(tester, _resend).disabled, isFalse);
      expect(find.byType(GuCountdown), findsNothing);

      await _tap(tester, _resend);
      expect(_feedback().toasts, [ToastId.tst03]);
      expect(_button(tester, _resend).label, l10n.authResendIn('60'));
    });

    testWidgets('gönderim sürerken düğme meşgul', (tester) async {
      await _pump(
        tester,
        state: const VerifyEmailState(email: _email, isResending: true),
      );
      expect(_button(tester, _resend).loading, isTrue);
      expect(_button(tester, _resend).disabled, isFalse);
      await _tap(tester, _resend);
      expect(_auth().callsTo('sendEmailVerification'), isEmpty);
    });

    testWidgets('çevrimdışı → TST-24; bekleme başlamaz', (tester) async {
      await _pump(tester);
      _connectivity().isOffline = true;

      await _tap(tester, _resend);

      expect(_feedback().toasts, [ToastId.tst24]);
      expect(_button(tester, _resend).label, tester.l10n.authResend);
      expect(_auth().callsTo('sendEmailVerification'), isEmpty);
    });
  });

  group('AUT-03 · E-postanı doğrula · çıkış (DLG-06)', () {
    for (final (name, key) in [
      ('AUT-03.logout', _logout),
      ('AUT-03.changeEmail', _changeEmail),
    ]) {
      testWidgets('$name → DLG-06; "Çıkış yap" oturumu kapatır', (
        tester,
      ) async {
        await _pump(tester);
        _feedback().nextDialogResult = true;

        await _tap(tester, key);
        await tester.pump();

        expect(_feedback().dialogs, [DialogId.dlg06]);
        expect(_auth().callsTo('signOut'), hasLength(1));
        expect(_auth().currentUser, isNull);
      });

      for (final result in [false, null]) {
        testWidgets(
          '$name → DLG-06; vazgeçilirse ($result) oturum açık kalır',
          (
            tester,
          ) async {
            await _pump(tester);
            _feedback().nextDialogResult = result;

            await _tap(tester, key);
            await tester.pump();

            expect(_feedback().dialogs, [DialogId.dlg06]);
            expect(_auth().callsTo('signOut'), isEmpty);
            expect(_auth().currentUser, isNotNull);
            expect(find.byKey(_confirm), findsOneWidget);
          },
        );
      }
    }
  });

  group('AUT-03 · E-postanı doğrula · gezinme', () {
    testWidgets('geri tuşu ekrandan çıkarmaz', (tester) async {
      await _pump(tester);

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pump();

      expect(find.byType(VerifyEmailView), findsOneWidget);
      expect(_auth().callsTo('signOut'), isEmpty);
      expect(_feedback().dialogs, isEmpty);
    });

    testWidgets('AUT-03.confirm doğrulanmış, profil yok → router AUT-05 '
        '(`/setup-profile`)', (tester) async {
      final router = await _pumpRouter(tester);
      expect(
        find.textContaining(_email, findRichText: true),
        findsOneWidget,
      );
      _auth().service.emailVerified = true;

      await _tap(tester, _confirm);
      // Başarı görünümü sürerken yönlendirme yok.
      expect(_location(router), '/verify');
      expect(find.byType(GuSuccessCheck), findsOneWidget);

      await tester.pump(VerifyEmailViewModel.successHold);
      await tester.pumpAndSettle();
      expect(_location(router), '/setup-profile');
      expect(find.byType(VerifyEmailView), findsNothing);
    });

    testWidgets('AUT-03.confirm doğrulanmış, profil tamam → router uygulama '
        'kabuğu (`/clubs`)', (tester) async {
      final router = await _pumpRouter(tester);
      _users().putActive(_uid);
      _auth().service.emailVerified = true;

      await _tap(tester, _confirm);
      await tester.pump(VerifyEmailViewModel.successHold);
      await tester.pumpAndSettle();

      expect(_location(router), '/clubs');
    });

    testWidgets(
      'AUT-03.confirm doğrulanmamış → `/verify` yolunda kalır (TST-02)',
      (
        tester,
      ) async {
        final router = await _pumpRouter(tester);

        await _tap(tester, _confirm);
        await tester.pumpAndSettle();

        expect(_location(router), '/verify');
        expect(_feedback().toasts, [ToastId.tst02]);
      },
    );

    testWidgets('AUT-03.logout onaylanınca → router AUT-01 (`/login`)', (
      tester,
    ) async {
      final router = await _pumpRouter(tester);
      _feedback().nextDialogResult = true;

      await _tap(tester, _logout);
      await tester.pumpAndSettle();

      expect(_feedback().dialogs, [DialogId.dlg06]);
      expect(_location(router), '/login');
      expect(find.byType(VerifyEmailView), findsNothing);
    });
  });
}

/// Dokununca [VerifyEmailView]'ı açan kapı: ekran, sahte oturum kurulduktan
/// sonra aynı ağaçta ilk kez çizilir (ViewModel başlangıç değerlerini gerçek
/// oturumdan okur).
class _Gate extends StatefulWidget {
  const _Gate();

  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  bool _open = false;

  @override
  Widget build(BuildContext context) => _open
      ? const VerifyEmailView()
      : GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _open = true),
          child: const SizedBox.expand(),
        );
}
