// AUT-01 · LoginViewModel: başlangıç, alan mutasyonları, doğrulama kuralları,
// gönderim (başarı / hatalı kimlik / kilit / askı / çevrimdışı / ağ / diğer),
// art arda gönderim, kilidin kalkması (PLAN §12.5). Kilit ve geri sayım sahte
// saatle (`FakeAppClock`), kimlik `FakeAuthRepository` ile (gerçek
// `LoginThrottle`: 5 hatalı deneme → 30 sn).
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/constants/app_constants.dart';
import 'package:gu_kulupler/features/auth/provider/login_state.dart';
import 'package:gu_kulupler/features/auth/provider/login_view_model.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';
import 'package:gu_kulupler/product/service/url_launcher_service.dart';

import '../../../fakes/fake_auth_repository.dart';
import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_url_launcher_service.dart';
import '../../../fakes/fake_user_repository.dart';
import '../../../fakes/register_fakes.dart';
import '../../../helpers/fake_app_clock.dart';
import '../../../helpers/test_container.dart';

const String _email = 'ayse.demir@ogr.gumushane.edu.tr';
const String _password = 'Sifre123';

void main() {
  late FakeAuthRepository auth;
  late FakeFeedbackService feedback;
  late FakeAppClock clock;
  late FakeConnectivityService connectivity;
  late FakeUrlLauncherService launcher;
  late List<String> logs;

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    auth = GetIt.I<AuthRepository>() as FakeAuthRepository;
    feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
    clock = GetIt.I<AppClock>() as FakeAppClock;
    connectivity = GetIt.I<ConnectivityService>() as FakeConnectivityService;
    launcher = GetIt.I<UrlLauncherService>() as FakeUrlLauncherService;
    logs = <String>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
    addTearDown(() => debugPrint = original);
  });

  /// Dinlenen (ömrü test boyunca süren) ViewModel'li kapsayıcı; [states]
  /// verilirse her state değişimi sırayla eklenir.
  ProviderContainer containerOf({List<LoginState>? states}) {
    final container = createContainer();
    addTearDown(
      container
          .listen(loginViewModelProvider, (_, next) => states?.add(next))
          .close,
    );
    return container;
  }

  LoginViewModel vmOf(ProviderContainer container) =>
      container.read(loginViewModelProvider.notifier);

  LoginState stateOf(ProviderContainer container) =>
      container.read(loginViewModelProvider);

  /// Formu geçerli değerlerle doldurur.
  void fill(
    ProviderContainer container, {
    String email = _email,
    String password = _password,
  }) {
    vmOf(container)
      ..setEmail(email)
      ..setPassword(password);
  }

  /// SDK'nın "hatalı kimlik" cevabıyla (sayılan deneme) [times] kez gönderir;
  /// son gönderimin sonucunu döndürür.
  Future<LoginOutcome> failWithWrongPassword(
    ProviderContainer container, {
    int times = 1,
  }) async {
    var outcome = LoginOutcome.failed;
    for (var i = 0; i < times; i++) {
      auth.service.failNext(AuthError.invalidCredentials);
      outcome = await vmOf(container).submit();
    }
    return outcome;
  }

  group('AUT-01 · LoginViewModel · alanlar', () {
    test('ilk state: boş form', () {
      expect(stateOf(containerOf()), const LoginState());
    });

    test('setEmail / setPassword değeri yazar ve formu kirletir; aynı değer '
        'state yayınlamaz', () {
      final states = <LoginState>[];
      final container = containerOf(states: states);
      vmOf(container).setEmail(_email);
      expect(
        stateOf(container),
        const LoginState(email: _email, isDirty: true),
      );

      vmOf(container).setPassword(_password);
      expect(
        stateOf(container),
        const LoginState(email: _email, password: _password, isDirty: true),
      );

      vmOf(container)
        ..setEmail(_email)
        ..setPassword(_password);
      expect(states, hasLength(2));
    });

    test('alan düzenlenince yalnızca o alanın hatası ve gönderim hatası '
        'silinir', () async {
      final container = containerOf();
      expect(vmOf(container).validate(), isFalse);
      expect(stateOf(container).errors, {
        LoginField.email: FormFieldError.required,
        LoginField.password: FormFieldError.required,
      });

      vmOf(container).setEmail('a');
      expect(stateOf(container).errors, {
        LoginField.password: FormFieldError.required,
      });
      vmOf(container).setPassword('b');
      expect(stateOf(container).errors, isEmpty);

      // Gönderim hatası: e-posta ya da şifre düzenlenince kalkar.
      for (final edit in <void Function(LoginViewModel)>[
        (vm) => vm.setEmail('yeni.$_email'),
        (vm) => vm.setPassword('${_password}4'),
      ]) {
        fill(container);
        await failWithWrongPassword(container);
        expect(stateOf(container).submitError, LoginError.invalidCredential);
        edit(vmOf(container));
        expect(stateOf(container).submitError, isNull);
      }
    });

    test('togglePasswordVisibility göster / gizle arasında değiştirir', () {
      final container = containerOf();
      vmOf(container).togglePasswordVisibility();
      expect(stateOf(container).isPasswordVisible, isTrue);
      vmOf(container).togglePasswordVisibility();
      expect(stateOf(container).isPasswordVisible, isFalse);
    });
  });

  group('AUT-01 · LoginViewModel · doğrulama', () {
    test('e-posta: zorunlu → biçim → izinli alan adı (kırpılarak)', () {
      final container = containerOf();
      Map<LoginField, FormFieldError> check(String email) {
        fill(container, email: email);
        vmOf(container).validate();
        return stateOf(container).errors;
      }

      expect(check(''), {LoginField.email: FormFieldError.required});
      expect(check('   '), {LoginField.email: FormFieldError.required});
      for (final malformed in [
        'ayse',
        'ayse@',
        '@ogr.gumushane.edu.tr',
        'ayse@@ogr.gumushane.edu.tr',
        'ayse demir@ogr.gumushane.edu.tr',
        'ayse@gumushane',
      ]) {
        expect(
          check(malformed),
          {LoginField.email: FormFieldError.invalidEmail},
          reason: malformed,
        );
      }
      for (final foreign in [
        'ayse@hotmail.com',
        'ayse@x.gumushane.edu.tr',
        'ayse@gumushane.edu.tr.evil.com',
      ]) {
        expect(
          check(foreign),
          {LoginField.email: FormFieldError.domainNotAllowed},
          reason: foreign,
        );
      }
      for (final domain in AppConstants.allowedEmailDomains) {
        expect(check('ayse.demir@$domain'), isEmpty, reason: domain);
      }
      expect(check('  $_email  '), isEmpty);
    });

    test('şifre: zorunlu → en az Limits.passwordMinLength karakter', () {
      final container = containerOf();
      Map<LoginField, FormFieldError> check(String password) {
        fill(container, password: password);
        vmOf(container).validate();
        return stateOf(container).errors;
      }

      expect(check(''), {LoginField.password: FormFieldError.required});
      expect(check('a' * (Limits.passwordMinLength - 1)), {
        LoginField.password: FormFieldError.passwordWeak,
      });
      // Girişte yalnızca uzunluk denetlenir (büyük harf / rakam kayıtta).
      expect(check('a' * Limits.passwordMinLength), isEmpty);
    });

    test('validate hataları state’e yazar; geçerli formda temizler', () {
      final container = containerOf();
      vmOf(container)
        ..setEmail('ayse@hotmail.com')
        ..setPassword('kisa');
      expect(vmOf(container).validate(), isFalse);
      expect(stateOf(container).errors, {
        LoginField.email: FormFieldError.domainNotAllowed,
        LoginField.password: FormFieldError.passwordWeak,
      });

      fill(container);
      // Düzenleme hataları siler; doğrulama yeniden boş küme yazar.
      expect(vmOf(container).validate(), isTrue);
      expect(stateOf(container).errors, isEmpty);
    });

    test('geçersiz form gönderilmez: failed, signIn çağrılmaz', () async {
      final container = containerOf();
      vmOf(container).setEmail(_email);
      expect(await vmOf(container).submit(), LoginOutcome.failed);
      expect(auth.signInAttempts, isEmpty);
      expect(stateOf(container).errors, {
        LoginField.password: FormFieldError.required,
      });
      expect(stateOf(container).isSubmitting, isFalse);
      expect(feedback.toasts, isEmpty);
    });
  });

  group('AUT-01 · LoginViewModel · gönderim', () {
    test('başarı: e-posta kırpılarak gönderilir; şifre temizlenir, sayaç ve '
        'bayraklar sıfırlanır; toast yok', () async {
      final states = <LoginState>[];
      final container = containerOf(states: states);
      fill(container, email: '  $_email ');
      states.clear();

      expect(await vmOf(container).submit(), LoginOutcome.success);
      expect(auth.signInAttempts, [(email: _email, password: _password)]);
      expect(auth.currentUser?.email, _email);
      // Meşgul → sonuç (hatasız doğrulama state'i değiştirmez).
      expect(states.map((s) => s.isSubmitting), [true, false]);
      expect(
        stateOf(container),
        const LoginState(email: '  $_email '),
      );
      expect(feedback.toasts, isEmpty);
      expect(feedback.dialogs, isEmpty);
    });

    test('başarı önceki hatalı denemelerin izini siler', () async {
      final container = containerOf();
      fill(container);
      await failWithWrongPassword(container, times: 2);
      expect(stateOf(container).failedAttempts, 2);

      expect(await vmOf(container).submit(), LoginOutcome.success);
      expect(stateOf(container).failedAttempts, 0);
      expect(stateOf(container).submitError, isNull);
      expect(stateOf(container).lockedUntil, isNull);
    });

    test('art arda gönderim (çift dokunma): tek signIn', () async {
      final container = containerOf();
      fill(container);
      final first = vmOf(container).submit();
      expect(stateOf(container).isSubmitting, isTrue);
      final second = vmOf(container).submit();

      expect(await second, LoginOutcome.failed);
      expect(await first, LoginOutcome.success);
      expect(auth.signInAttempts, hasLength(1));
    });

    test('e-posta ya da şifre hatalı: invalid, sayaç artar, TST-01; şifre '
        'korunur', () async {
      final container = containerOf();
      fill(container);
      expect(await failWithWrongPassword(container), LoginOutcome.invalid);
      expect(
        stateOf(container),
        const LoginState(
          email: _email,
          password: _password,
          isDirty: true,
          failedAttempts: 1,
          submitError: LoginError.invalidCredential,
        ),
      );
      expect(feedback.toasts, [ToastId.tst01]);
      expect(feedback.dialogs, isEmpty);
    });

    test('çevrimdışı: TST-24, signIn çağrılmaz, network', () async {
      final container = containerOf();
      fill(container);
      connectivity.isOffline = true;

      expect(await vmOf(container).submit(), LoginOutcome.failed);
      expect(auth.signInAttempts, isEmpty);
      expect(feedback.toasts, [ToastId.tst24]);
      expect(stateOf(container).submitError, LoginError.network);
      expect(stateOf(container).isSubmitting, isFalse);
    });

    test('ağ hatası: TST-24, network; deneme sayılmaz', () async {
      final container = containerOf();
      fill(container);
      auth.service.failNext(AuthError.network);

      expect(await vmOf(container).submit(), LoginOutcome.failed);
      expect(feedback.toasts, [ToastId.tst24]);
      expect(stateOf(container).submitError, LoginError.network);
      expect(stateOf(container).failedAttempts, 0);
      expect(stateOf(container).isSubmitting, isFalse);
    });

    test('repository adresi reddederse alan hatası olur', () async {
      for (final (error, expected) in [
        (AuthError.invalidEmail, FormFieldError.invalidEmail),
        (AuthError.domainNotAllowed, FormFieldError.domainNotAllowed),
      ]) {
        final container = containerOf();
        fill(container);
        auth.failNext(error);

        expect(await vmOf(container).submit(), LoginOutcome.failed);
        expect(stateOf(container).errors, {LoginField.email: expected});
        expect(stateOf(container).submitError, isNull);
        expect(stateOf(container).isSubmitting, isFalse);
      }
      expect(feedback.toasts, isEmpty);
    });

    test('diğer hatalar: unknown, günlüğe düşer, toast yok', () async {
      for (final error in [
        AuthError.unknown,
        AuthError.operationNotAllowed,
        AuthError.sessionExpired,
        AuthError.emailNotVerified,
      ]) {
        final container = containerOf();
        fill(container);
        auth.failNext(error);

        expect(await vmOf(container).submit(), LoginOutcome.failed);
        expect(stateOf(container).submitError, LoginError.unknown);
        expect(stateOf(container).isSubmitting, isFalse);
        expect(stateOf(container).failedAttempts, 0);
        expect(logs.last, contains(error.name));
      }
      expect(feedback.toasts, isEmpty);
      expect(feedback.dialogs, isEmpty);
    });

    test(
      'clearSubmitError hatayı siler; hata yokken state yayınlamaz',
      () async {
        final states = <LoginState>[];
        final container = containerOf(states: states);
        fill(container);
        auth.failNext(AuthError.unknown);
        await vmOf(container).submit();
        states.clear();

        vmOf(container).clearSubmitError();
        expect(stateOf(container).submitError, isNull);
        vmOf(container).clearSubmitError();
        expect(states, hasLength(1));
      },
    );

    test('istek sürerken ekran kapanırsa kapanmış state’e yazılmaz', () async {
      final container = createContainer();
      final subscription = container.listen(loginViewModelProvider, (_, _) {});
      fill(container);
      final pending = vmOf(container).submit();
      subscription.close();
      container.dispose();

      expect(await pending, LoginOutcome.success);
    });
  });

  group('AUT-01 · LoginViewModel · kilit', () {
    test('5. hatalı denemede kilitlenir: locked, lockedUntil = şimdi + '
        'Limits.loginLockout, her denemede TST-01', () async {
      final container = containerOf();
      fill(container);
      expect(
        await failWithWrongPassword(
          container,
          times: Limits.loginMaxFailedAttempts - 1,
        ),
        LoginOutcome.invalid,
      );
      expect(stateOf(container).lockedUntil, isNull);

      expect(await failWithWrongPassword(container), LoginOutcome.locked);
      final state = stateOf(container);
      expect(state.failedAttempts, Limits.loginMaxFailedAttempts);
      expect(state.lockedUntil, kDefaultFakeNowUtc.add(Limits.loginLockout));
      expect(state.submitError, LoginError.invalidCredential);
      expect(state.isSubmitting, isFalse);
      expect(
        feedback.toasts,
        List.filled(Limits.loginMaxFailedAttempts, ToastId.tst01),
      );
      expect(vmOf(container).isLockedAt(clock.nowUtc()), isTrue);
    });

    test('kilit sürerken gönderim: locked, signIn çağrılmaz, doğrulama '
        'çalışmaz', () async {
      final container = containerOf();
      fill(container);
      await failWithWrongPassword(
        container,
        times: Limits.loginMaxFailedAttempts,
      );
      final attempts = auth.signInAttempts.length;
      feedback.resetFake();
      vmOf(container).setPassword('');

      clock.advance(Limits.loginLockout - const Duration(seconds: 1));
      expect(await vmOf(container).submit(), LoginOutcome.locked);
      expect(auth.signInAttempts, hasLength(attempts));
      expect(stateOf(container).errors, isEmpty);
      expect(feedback.toasts, isEmpty);
    });

    test('clearLock: süre dolmadan etkisiz; dolunca kilidi ve sayacı '
        'sıfırlar; kilit yokken state yayınlamaz', () async {
      final states = <LoginState>[];
      final container = containerOf(states: states);
      vmOf(container).clearLock();
      expect(states, isEmpty);

      fill(container);
      await failWithWrongPassword(
        container,
        times: Limits.loginMaxFailedAttempts,
      );
      final lockedUntil = stateOf(container).lockedUntil;

      clock.advance(Limits.loginLockout - const Duration(milliseconds: 1));
      vmOf(container).clearLock();
      expect(stateOf(container).lockedUntil, lockedUntil);

      clock.advance(const Duration(milliseconds: 1));
      expect(vmOf(container).isLockedAt(clock.nowUtc()), isFalse);
      vmOf(container).clearLock();
      expect(stateOf(container).lockedUntil, isNull);
      expect(stateOf(container).failedAttempts, 0);

      // Kilit kalkınca yeniden giriş yapılabilir.
      expect(await vmOf(container).submit(), LoginOutcome.success);
    });

    test(
      'süresi dolmuş ama temizlenmemiş kilit gönderimi engellemez',
      () async {
        final container = containerOf();
        fill(container);
        await failWithWrongPassword(
          container,
          times: Limits.loginMaxFailedAttempts,
        );
        clock.advance(Limits.loginLockout);

        expect(await vmOf(container).submit(), LoginOutcome.success);
        expect(stateOf(container).lockedUntil, isNull);
      },
    );

    test('repository kilidi bildirirse (ekran yeniden açıldı): locked, '
        'lockedUntil = retryAfter; toast ve sayaç yok', () async {
      final first = containerOf();
      fill(first);
      await failWithWrongPassword(first, times: Limits.loginMaxFailedAttempts);
      final lockedUntil = stateOf(first).lockedUntil;
      feedback.resetFake();
      clock.advance(const Duration(seconds: 10));

      // Yeni ekran: state kilidi bilmez, repository bilir.
      final second = containerOf();
      fill(second);
      expect(stateOf(second).lockedUntil, isNull);
      expect(await vmOf(second).submit(), LoginOutcome.locked);
      expect(stateOf(second).lockedUntil, lockedUntil);
      expect(stateOf(second).failedAttempts, 0);
      expect(stateOf(second).submitError, isNull);
      expect(stateOf(second).isSubmitting, isFalse);
      expect(feedback.toasts, isEmpty);
    });

    test('ayrıntısız kilit ve sunucu kısıtı (too-many-requests): yerel kilit '
        'süresi kadar kilitlenir', () async {
      for (final error in [AuthError.lockedOut, AuthError.tooManyRequests]) {
        final container = containerOf();
        fill(container);
        auth.failNext(error);

        expect(await vmOf(container).submit(), LoginOutcome.locked);
        expect(
          stateOf(container).lockedUntil,
          clock.nowUtc().add(Limits.loginLockout),
          reason: error.name,
        );
        expect(stateOf(container).isSubmitting, isFalse);
      }
      expect(feedback.toasts, isEmpty);
    });
  });

  group('AUT-01 · LoginViewModel · askıdaki hesap', () {
    test('hesap devre dışı: suspended, oturum kapatılır, DLG-01 gösterilir, '
        'şifre temizlenir', () async {
      final container = containerOf();
      fill(container);
      auth.service.failNext(AuthError.userDisabled);

      expect(await vmOf(container).submit(), LoginOutcome.suspended);
      expect(auth.callsTo('signOut'), hasLength(1));
      expect(feedback.dialogs, [DialogId.dlg01]);
      expect(launcher.opened, isEmpty);
      expect(
        stateOf(container),
        const LoginState(
          email: _email,
          isDirty: true,
          submitError: LoginError.suspended,
        ),
      );
      expect(feedback.toasts, isEmpty);
    });

    test('DLG-01 "Destekle iletişime geç": destek e-postası açılır', () async {
      final container = containerOf();
      fill(container);
      auth.service.failNext(AuthError.userDisabled);
      feedback.nextDialogResult = true;

      expect(await vmOf(container).submit(), LoginOutcome.suspended);
      expect(launcher.opened, [AppConstants.supportMailUri]);
    });

    test('oturum kapatılamazsa da DLG-01 gösterilir (günlüğe düşer)', () async {
      final container = containerOf();
      fill(container);
      auth.service.failNext(AuthError.userDisabled);
      final pending = vmOf(container).submit();
      // signIn çağrısı yapıldı (hata denetimi eşzamanlı tüketildi); sıradaki
      // repository hatası signOut'a gider.
      auth.failNext(AuthError.network);

      expect(await pending, LoginOutcome.suspended);
      expect(feedback.dialogs, [DialogId.dlg01]);
      expect(logs, isNotEmpty);
    });
  });

  group('AUT-01 · LoginViewModel · son giriş anı (W-56d)', () {
    FakeUserRepository users() =>
        GetIt.I<UserRepository>() as FakeUserRepository;

    test('doğrulanmış hesapla başarılı girişte bir kez yazılır', () async {
      users().putActive(auth.service.uid);
      auth.service.emailVerified = true;
      final container = containerOf();
      fill(container);

      expect(await vmOf(container).submit(), LoginOutcome.success);
      await pumpEventQueue();
      expect(users().lastLoginTouches, [auth.service.uid]);
      expect(logs, isEmpty);
    });

    test('doğrulanmamış hesapta yazılmaz (hesap belgesi henüz yok)', () async {
      final container = containerOf();
      fill(container);

      expect(await vmOf(container).submit(), LoginOutcome.success);
      await pumpEventQueue();
      expect(users().callsTo('touchLastLogin'), isEmpty);
    });

    test('profili kurulmamış doğrulanmış hesapta sessizce geçilir', () async {
      auth.service.emailVerified = true;
      final container = containerOf();
      fill(container);

      expect(await vmOf(container).submit(), LoginOutcome.success);
      await pumpEventQueue();
      expect(users().callsTo('touchLastLogin'), hasLength(1));
      expect(users().lastLoginTouches, isEmpty);
      expect(logs, isEmpty);
    });

    test('yazılamazsa giriş yine başarıdır; hata günlüğe düşer', () async {
      users()
        ..putActive(auth.service.uid)
        ..failNext(FirestoreError.unavailable);
      auth.service.emailVerified = true;
      final container = containerOf();
      fill(container);

      expect(await vmOf(container).submit(), LoginOutcome.success);
      await pumpEventQueue();
      expect(users().lastLoginTouches, isEmpty);
      expect(logs.join('\n'), contains('Son giriş anı yazılamadı'));
      expect(stateOf(container).submitError, isNull);
    });

    test('başarısız girişte yazılmaz', () async {
      users().putActive(auth.service.uid);
      auth.service
        ..emailVerified = true
        ..failNext(AuthError.invalidCredentials);
      final container = containerOf();
      fill(container);

      expect(await vmOf(container).submit(), LoginOutcome.invalid);
      await pumpEventQueue();
      expect(users().callsTo('touchLastLogin'), isEmpty);
    });
  });
}
