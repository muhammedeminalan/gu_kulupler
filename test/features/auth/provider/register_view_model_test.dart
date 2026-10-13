// AUT-02 · RegisterViewModel (PLAN §12.5): başlangıç, her mutasyon, doğrulama
// kuralları, gönderim (başarı / çevrimdışı / sunucu hataları), art arda
// gönderim. Kayıt profil belgesi oluşturmaz, ad kimlik hesabında taşınır
// (CD-134, W-56a); doğrulama e-postasını `AuthRepository.register` gönderir.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/auth/provider/register_state.dart';
import 'package:gu_kulupler/features/auth/provider/register_view_model.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';

import '../../../fakes/fake_auth_repository.dart';
import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_user_repository.dart';
import '../../../fakes/register_fakes.dart';
import '../../../helpers/test_container.dart';

const String _name = 'Ayşe Yılmaz';
const String _email = 'ayse.yilmaz@ogr.gumushane.edu.tr';
const String _password = 'Parola123';

FakeAuthRepository _auth() => GetIt.I<AuthRepository>() as FakeAuthRepository;

FakeUserRepository _users() => GetIt.I<UserRepository>() as FakeUserRepository;

FakeFeedbackService _feedback() =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;

FakeConnectivityService _connectivity() =>
    GetIt.I<ConnectivityService>() as FakeConnectivityService;

/// Kapsayıcıyı kurar ve ViewModel'i test boyunca canlı tutar.
ProviderContainer _container() {
  final container = createContainer();
  addTearDown(container.listen(registerViewModelProvider, (_, _) {}).close);
  return container;
}

RegisterViewModel _viewModel(ProviderContainer container) =>
    container.read(registerViewModelProvider.notifier);

RegisterState _state(ProviderContainer container) =>
    container.read(registerViewModelProvider);

/// Geçerli formu doldurur.
void _fillValid(RegisterViewModel viewModel) => viewModel
  ..setName(_name)
  ..setEmail(_email)
  ..setPassword(_password)
  ..setPasswordConfirm(_password)
  ..toggleLegal();

/// Yalnızca [field] hatasını döndürür: geçerli form + [mutate].
FormFieldError? _errorAfter(
  RegisterField field,
  void Function(RegisterViewModel viewModel) mutate,
) {
  final container = _container();
  final viewModel = _viewModel(container);
  _fillValid(viewModel);
  mutate(viewModel);
  viewModel.validate();
  final errors = _state(container).errors;
  expect(
    errors.keys.where((key) => key != field),
    isEmpty,
    reason: 'yalnızca $field hatalı olmalı',
  );
  return errors[field];
}

void main() {
  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
  });

  group('AUT-02 · RegisterViewModel · form', () {
    test('başlangıç durumu boş formdur', () {
      expect(_state(_container()), const RegisterState());
    });

    test('setName / setEmail / setPassword / setPasswordConfirm değeri yazar '
        've formu kirletir', () {
      final container = _container();
      final viewModel = _viewModel(container)..setName(_name);
      expect(
        _state(container),
        const RegisterState(name: _name, isDirty: true),
      );
      viewModel
        ..setEmail(_email)
        ..setPassword(_password)
        ..setPasswordConfirm('Parola12');
      expect(
        _state(container),
        const RegisterState(
          name: _name,
          email: _email,
          password: _password,
          passwordConfirm: 'Parola12',
          isDirty: true,
        ),
      );
    });

    test('aynı değer yeniden yazılırsa state değişmez', () {
      final container = _container();
      final viewModel = _viewModel(container);
      final states = <RegisterState>[];
      addTearDown(
        container
            .listen(registerViewModelProvider, (_, next) => states.add(next))
            .close,
      );
      viewModel
        ..setName('')
        ..setEmail('')
        ..setPassword('')
        ..setPasswordConfirm('');
      expect(states, isEmpty);
      expect(_state(container).isDirty, isFalse);
    });

    test('togglePasswordVisibility göster / gizle; form kirlenmez', () {
      final container = _container();
      final viewModel = _viewModel(container)..togglePasswordVisibility();
      expect(_state(container), const RegisterState(isPasswordVisible: true));
      viewModel.togglePasswordVisibility();
      expect(_state(container), const RegisterState());
    });

    test('toggleLegal onayı değiştirir ve formu kirletir', () {
      final container = _container();
      final viewModel = _viewModel(container)..toggleLegal();
      expect(
        _state(container),
        const RegisterState(acceptedLegal: true, isDirty: true),
      );
      viewModel.toggleLegal();
      expect(_state(container), const RegisterState(isDirty: true));
    });
  });

  group('AUT-02 · RegisterViewModel · acceptLegal', () {
    test('onayı verir, onay hatasını siler; işaretliyse etkisizdir', () {
      final container = _container();
      final viewModel = _viewModel(container)
        ..validate()
        ..acceptLegal();
      expect(_state(container).acceptedLegal, isTrue);
      expect(_state(container).isDirty, isTrue);
      expect(
        _state(container).errors.containsKey(RegisterField.legal),
        isFalse,
      );

      final accepted = _state(container);
      viewModel.acceptLegal();
      expect(_state(container), same(accepted));
    });
  });

  group('AUT-02 · RegisterViewModel · doğrulama', () {
    test('boş form: ad, e-posta, şifre ve onay hatalı; tekrar hatasız', () {
      final container = _container();
      expect(_viewModel(container).validate(), isFalse);
      expect(_state(container).errors, {
        RegisterField.name: FormFieldError.required,
        RegisterField.email: FormFieldError.required,
        RegisterField.password: FormFieldError.passwordWeak,
        RegisterField.legal: FormFieldError.consentMissing,
      });
      // Hatalar form sırasıyla dizilir.
      expect(_state(container).errors.keys, [
        RegisterField.name,
        RegisterField.email,
        RegisterField.password,
        RegisterField.legal,
      ]);
    });

    test('geçerli form: hata yok', () {
      final container = _container();
      final viewModel = _viewModel(container);
      _fillValid(viewModel);
      expect(viewModel.validate(), isTrue);
      expect(_state(container).errors, isEmpty);
    });

    test('ad: zorunlu, kırpılmış 2 – 60 karakter', () {
      FormFieldError? of(String name) =>
          _errorAfter(RegisterField.name, (vm) => vm.setName(name));
      expect(of(''), FormFieldError.required);
      expect(of('   '), FormFieldError.required);
      expect(of('A'), FormFieldError.tooShort);
      expect(of('  A  '), FormFieldError.tooShort);
      expect(of('Al'), isNull);
      expect(of('  Al  '), isNull);
      expect(of('a' * Limits.nameMax), isNull);
      expect(of('a' * (Limits.nameMax + 1)), FormFieldError.tooLong);
    });

    test('e-posta: zorunlu, biçim, izinli alan adı (D-27)', () {
      FormFieldError? of(String email) =>
          _errorAfter(RegisterField.email, (vm) => vm.setEmail(email));
      expect(of(''), FormFieldError.required);
      expect(of('  '), FormFieldError.required);
      expect(of('ayse'), FormFieldError.invalidEmail);
      expect(of('@gumushane.edu.tr'), FormFieldError.invalidEmail);
      expect(of('a@b@gumushane.edu.tr'), FormFieldError.invalidEmail);
      expect(of('ayşe@gumushane.edu.tr'), FormFieldError.invalidEmail);
      expect(of('ayse@hotmail.com'), FormFieldError.domainNotAllowed);
      expect(of('ayse@x.gumushane.edu.tr'), FormFieldError.domainNotAllowed);
      expect(
        of('ayse@gumushane.edu.tr.evil.com'),
        FormFieldError.domainNotAllowed,
      );
      expect(of('ayse@gumushane.edu.tr'), isNull);
      expect(of('ayse@ogr.gumushane.edu.tr'), isNull);
      expect(of('AYSE@OGR.GUMUSHANE.EDU.TR'), isNull);
      // Baştaki / sondaki boşluk kırpılarak doğrulanır.
      expect(of('  ayse@ogr.gumushane.edu.tr '), isNull);
    });

    // Geri almada (`EmailDomainPolicy.temporaryTestDomains = []`) bu test
    // silinir.
    test('GEÇİCİ (W-61) · e-posta: gmail.com geçici izinli; benzerleri '
        'izinsiz', () {
      FormFieldError? of(String email) =>
          _errorAfter(RegisterField.email, (vm) => vm.setEmail(email));
      expect(of('ayse@gmail.com'), isNull);
      expect(of('AYSE@GMAIL.COM'), isNull);
      expect(of('  ayse@gmail.com '), isNull);
      expect(of('ayse@gmail.com.evil.com'), FormFieldError.domainNotAllowed);
      expect(of('ayse@xgmail.com'), FormFieldError.domainNotAllowed);
      expect(of('ayse@mail.gmail.com'), FormFieldError.domainNotAllowed);
      expect(of('@gmail.com'), FormFieldError.invalidEmail);
    });

    test('şifre: en az 8 karakter + büyük harf + rakam', () {
      FormFieldError? of(String password) => _errorAfter(
        RegisterField.password,
        (vm) => vm
          ..setPassword(password)
          ..setPasswordConfirm(password),
      );
      expect(of(''), FormFieldError.passwordWeak);
      expect(of('Par1'), FormFieldError.passwordWeak);
      expect(of('parola12'), FormFieldError.passwordWeak);
      expect(of('Parolaaa'), FormFieldError.passwordWeak);
      expect(of('PAROLA!!'), FormFieldError.passwordWeak);
      expect(of('Parola12'), isNull);
      expect(of('Şifrem12'), isNull);
      expect(of('1234567A'), isNull);
    });

    test('şifre tekrar: şifreyle birebir aynı olmalı', () {
      FormFieldError? of(String confirm) => _errorAfter(
        RegisterField.passwordConfirm,
        (vm) => vm.setPasswordConfirm(confirm),
      );
      expect(of(''), FormFieldError.passwordMismatch);
      expect(of('parola123'), FormFieldError.passwordMismatch);
      expect(of('$_password '), FormFieldError.passwordMismatch);
      expect(of(_password), isNull);
    });

    test('onay: kutu işaretli olmalı', () {
      expect(
        _errorAfter(RegisterField.legal, (vm) => vm.toggleLegal()),
        FormFieldError.consentMissing,
      );
    });

    test('yeniden doğrulama düzelen hataları siler', () {
      final container = _container();
      final viewModel = _viewModel(container)..validate();
      expect(_state(container).errors, hasLength(4));
      _fillValid(viewModel);
      expect(viewModel.validate(), isTrue);
      expect(_state(container).errors, isEmpty);
    });

    test('alan düzenlenince yalnızca o alanın hatası silinir', () {
      final container = _container();
      final viewModel = _viewModel(container)
        ..setPasswordConfirm('x')
        ..validate();
      expect(_state(container).errors.keys, RegisterField.values);

      viewModel.setName('A');
      expect(_state(container).errors.keys, [
        RegisterField.email,
        RegisterField.password,
        RegisterField.passwordConfirm,
        RegisterField.legal,
      ]);
      viewModel.setEmail('a');
      expect(_state(container).errors.keys, [
        RegisterField.password,
        RegisterField.passwordConfirm,
        RegisterField.legal,
      ]);
      viewModel.toggleLegal();
      expect(_state(container).errors.keys, [
        RegisterField.password,
        RegisterField.passwordConfirm,
      ]);
      viewModel.setPasswordConfirm('y');
      expect(_state(container).errors.keys, [RegisterField.password]);
    });

    test('şifre düzenlenince tekrar alanının hatası da silinir', () {
      final container = _container();
      final viewModel = _viewModel(container)
        ..setPasswordConfirm('x')
        ..validate()
        ..setPassword('P');
      expect(_state(container).errors.keys, [
        RegisterField.name,
        RegisterField.email,
        RegisterField.legal,
      ]);
      // Göster / gizle hataya dokunmaz.
      viewModel.togglePasswordVisibility();
      expect(_state(container).errors, hasLength(3));
    });
  });

  group('AUT-02 · RegisterViewModel · gönderim', () {
    test('geçersiz form: istek gitmez, hatalar duruma yazılır', () async {
      final container = _container();
      final outcome = await _viewModel(container).submit();
      expect(outcome, RegisterOutcome.invalid);
      expect(_auth().callsTo('register'), isEmpty);
      expect(_feedback().toasts, isEmpty);
      expect(_state(container).errors, hasLength(4));
      expect(_state(container).isSubmitting, isFalse);
    });

    test('başarı: hesap açılır, ad kimlik hesabında taşınır, form kilitli '
        'kalır', () async {
      final container = _container();
      final viewModel = _viewModel(container);
      _fillValid(viewModel);

      expect(await viewModel.submit(), RegisterOutcome.success);
      expect(_auth().registered, [
        (email: _email, password: _password, name: _name),
      ]);
      final user = _auth().currentUser!;
      expect(user.email, _email);
      expect(user.emailVerified, isFalse);
      expect(user.displayName, _name);
      // Ekran yönlendirmeyle kapanana kadar gönderim kilidi açılmaz.
      expect(_state(container).isSubmitting, isTrue);
      expect(_state(container).submitError, isNull);
      expect(_state(container).errors, isEmpty);
      expect(_feedback().toasts, isEmpty);
    });

    test('başarı: profil belgesi oluşturulmaz (CD-134, W-56a)', () async {
      final container = _container();
      final viewModel = _viewModel(container);
      _fillValid(viewModel);
      await viewModel.submit();
      expect(_users().calls, isEmpty);
    });

    test('başarı: doğrulama e-postasını repository gönderir; ikinci çağrı '
        'yapılmaz', () async {
      final container = _container();
      final viewModel = _viewModel(container);
      _fillValid(viewModel);
      await viewModel.submit();
      expect(_auth().service.callsTo('sendEmailVerification'), hasLength(1));
      expect(_auth().callsTo('sendEmailVerification'), isEmpty);
      expect(_auth().resendCooldownRemaining, isNotNull);
    });

    test('ad ve e-posta kırpılarak gönderilir; şifre olduğu gibi', () async {
      final container = _container();
      final viewModel = _viewModel(container)
        ..setName('  $_name ')
        ..setEmail(' $_email  ')
        ..setPassword(' Parola 123 ')
        ..setPasswordConfirm(' Parola 123 ')
        ..toggleLegal();
      expect(await viewModel.submit(), RegisterOutcome.success);
      expect(_auth().registered, [
        (email: _email, password: ' Parola 123 ', name: _name),
      ]);
    });

    test('çevrimdışı: TST-24, istek gitmez, form açık kalır', () async {
      final container = _container();
      final viewModel = _viewModel(container);
      _fillValid(viewModel);
      _connectivity().isOffline = true;

      expect(await viewModel.submit(), RegisterOutcome.offline);
      expect(_feedback().toasts, [ToastId.tst24]);
      expect(_auth().callsTo('register'), isEmpty);
      expect(_state(container).isSubmitting, isFalse);
      expect(_state(container).submitError, isNull);

      // Bağlantı gelince aynı form gönderilebilir.
      _connectivity().isOffline = false;
      expect(await viewModel.submit(), RegisterOutcome.success);
    });

    test(
      'gönderim sürerken state: isSubmitting true → hata sonrası false',
      () async {
        final container = _container();
        final viewModel = _viewModel(container);
        _fillValid(viewModel);
        final flags = <bool>[];
        addTearDown(
          container
              .listen(
                registerViewModelProvider.select((s) => s.isSubmitting),
                (_, next) => flags.add(next),
              )
              .close,
        );
        _auth().failNext(AuthError.unknown);
        await viewModel.submit();
        expect(flags, [true, false]);
      },
    );

    test('kayıtlı e-posta: e-posta alanı hatası (emailInUse)', () async {
      final container = _container();
      final viewModel = _viewModel(container);
      _fillValid(viewModel);
      _auth().service.failNext(AuthError.emailAlreadyInUse);

      expect(await viewModel.submit(), RegisterOutcome.failed);
      final state = _state(container);
      expect(state.submitError, RegisterError.emailInUse);
      expect(state.firstInvalidField, RegisterField.email);
      expect(state.errors, isEmpty);
      expect(state.isSubmitting, isFalse);
      expect(_feedback().toasts, isEmpty);
      expect(_auth().registered, isEmpty);
    });

    test('alan adı reddi: e-posta alanı hatası (domainNotAllowed)', () async {
      final container = _container();
      final viewModel = _viewModel(container);
      _fillValid(viewModel);
      _auth().failNext(AuthError.domainNotAllowed);

      expect(await viewModel.submit(), RegisterOutcome.failed);
      final state = _state(container);
      expect(state.submitError, RegisterError.domainNotAllowed);
      expect(state.errors, {
        RegisterField.email: FormFieldError.domainNotAllowed,
      });
      expect(state.isSubmitting, isFalse);
      expect(_feedback().toasts, isEmpty);
    });

    test('sunucu e-postayı geçersiz bulursa e-posta alanı hatası', () async {
      final container = _container();
      final viewModel = _viewModel(container);
      _fillValid(viewModel);
      _auth().service.failNext(AuthError.invalidEmail);

      expect(await viewModel.submit(), RegisterOutcome.failed);
      final state = _state(container);
      expect(state.errors, {RegisterField.email: FormFieldError.invalidEmail});
      expect(state.submitError, isNull);
      expect(state.isSubmitting, isFalse);
    });

    test('zayıf şifre: şifre alanı hatası (weakPassword)', () async {
      final container = _container();
      final viewModel = _viewModel(container);
      _fillValid(viewModel);
      _auth().service.failNext(AuthError.weakPassword);

      expect(await viewModel.submit(), RegisterOutcome.failed);
      final state = _state(container);
      expect(state.submitError, RegisterError.weakPassword);
      expect(state.errors, {
        RegisterField.password: FormFieldError.passwordWeak,
      });
      expect(state.isSubmitting, isFalse);
      expect(_feedback().toasts, isEmpty);
    });

    test('ağ hatası: TST-24 + submitError network; alan hatası yok', () async {
      final container = _container();
      final viewModel = _viewModel(container);
      _fillValid(viewModel);
      _auth().service.failNext(AuthError.network);

      expect(await viewModel.submit(), RegisterOutcome.failed);
      final state = _state(container);
      expect(state.submitError, RegisterError.network);
      expect(state.errors, isEmpty);
      expect(state.firstInvalidField, isNull);
      expect(state.isSubmitting, isFalse);
      expect(_feedback().toasts, [ToastId.tst24]);
    });

    test('diğer her hata: submitError unknown, toast yok', () async {
      for (final error in [
        AuthError.userDisabled,
        AuthError.invalidCredentials,
        AuthError.tooManyRequests,
        AuthError.requiresRecentLogin,
        AuthError.sessionExpired,
        AuthError.invalidActionCode,
        AuthError.operationNotAllowed,
        AuthError.unknown,
        AuthError.lockedOut,
        AuthError.resendCooldown,
        AuthError.emailNotVerified,
      ]) {
        final container = _container();
        final viewModel = _viewModel(container);
        _fillValid(viewModel);
        _auth().failNext(error);

        expect(
          await viewModel.submit(),
          RegisterOutcome.failed,
          reason: '$error',
        );
        final state = _state(container);
        expect(state.submitError, RegisterError.unknown, reason: '$error');
        expect(state.errors, isEmpty, reason: '$error');
        expect(state.isSubmitting, isFalse, reason: '$error');
      }
      expect(_feedback().toasts, isEmpty);
    });

    test('tüm AuthError değerleri eşlenir (eksik dal yok)', () async {
      // Yukarıdaki testlerin birlikte her üyeyi kapsadığını sabitler.
      const fieldOrNetwork = {
        AuthError.emailAlreadyInUse,
        AuthError.domainNotAllowed,
        AuthError.invalidEmail,
        AuthError.weakPassword,
        AuthError.network,
      };
      for (final error in AuthError.values) {
        final container = _container();
        final viewModel = _viewModel(container);
        _fillValid(viewModel);
        _auth().failNext(error);
        await viewModel.submit();
        expect(
          _state(container).submitError == RegisterError.unknown,
          !fieldOrNetwork.contains(error),
          reason: '$error',
        );
      }
    });

    test('form düzenlenince sunucu hatası silinir', () async {
      for (final edit in <void Function(RegisterViewModel)>[
        (vm) => vm.setName('Ali Veli'),
        (vm) => vm.setEmail('ali@gumushane.edu.tr'),
        (vm) => vm.setPassword('Parola124'),
        (vm) => vm.setPasswordConfirm('Parola124'),
        (vm) => vm.toggleLegal(),
      ]) {
        final container = _container();
        final viewModel = _viewModel(container);
        _fillValid(viewModel);
        _auth().service.failNext(AuthError.emailAlreadyInUse);
        await viewModel.submit();
        expect(_state(container).submitError, RegisterError.emailInUse);
        edit(viewModel);
        expect(_state(container).submitError, isNull);
      }
    });

    test(
      'hatadan sonra yeniden gönderim: eski hata silinir, kayıt başarılı',
      () async {
        final container = _container();
        final viewModel = _viewModel(container);
        _fillValid(viewModel);
        _auth().failNext(AuthError.unknown);
        expect(await viewModel.submit(), RegisterOutcome.failed);
        expect(_state(container).submitError, RegisterError.unknown);

        expect(await viewModel.submit(), RegisterOutcome.success);
        expect(_state(container).submitError, isNull);
        expect(_auth().registered, hasLength(1));
      },
    );

    test('art arda gönderim (çift dokunma): tek istek gider', () async {
      final container = _container();
      final viewModel = _viewModel(container);
      _fillValid(viewModel);

      final first = viewModel.submit();
      final second = viewModel.submit();
      expect(_state(container).isSubmitting, isTrue);
      expect(await second, RegisterOutcome.ignored);
      expect(await first, RegisterOutcome.success);
      expect(_auth().callsTo('register'), hasLength(1));
      expect(_auth().registered, hasLength(1));

      // Başarıdan sonra form kilitli: üçüncü dokunma da yok sayılır.
      expect(await viewModel.submit(), RegisterOutcome.ignored);
      expect(_auth().callsTo('register'), hasLength(1));
    });

    test('ekran kapandıktan sonra gelen hata duruma yazılmaz', () async {
      final container = createContainer();
      final subscription = container.listen(
        registerViewModelProvider,
        (_, _) {},
      );
      final viewModel = _viewModel(container);
      _fillValid(viewModel);
      _auth().failNext(AuthError.network);

      final pending = viewModel.submit();
      subscription.close();
      container.dispose();
      expect(await pending, RegisterOutcome.failed);
      expect(_feedback().toasts, isEmpty);
    });
  });
}
