// SHT-32 · Şifre değiştir — `ChangePasswordViewModel` + `ChangePasswordState`:
// alan düzenleme (hata temizleme, kirlilik), doğrulama (zorunlu mevcut şifre,
// `Limits.passwordPattern`, tekrar uyuşması), gönderim dalları — başarı
// (yeniden doğrulama + güncelleme, TST-44), hatalı mevcut şifre, zayıf şifre
// (sunucu), çok fazla deneme, çevrimdışı / ağ (TST-24), bilinmeyen hata —
// ve çift gönderim kilidi. Referans: sheets.js:149–152, PLAN §12.12.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/settings/provider/change_password_state.dart';
import 'package:gu_kulupler/features/settings/provider/change_password_view_model.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';

import '../../../fakes/fake_auth_repository.dart';
import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/register_fakes.dart';
import '../../../helpers/test_container.dart';

const String _current = 'Demo1234!';
const String _next = 'Yeni5678!';
const AuthUserInfo _user = AuthUserInfo(
  uid: 'u_mehmet',
  email: 'mehmet.kaya@ogr.gumushane.edu.tr',
  emailVerified: true,
);

void main() {
  late FakeAuthRepository auth;
  late FakeFeedbackService feedback;
  late FakeConnectivityService connectivity;

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    auth = GetIt.I<AuthRepository>() as FakeAuthRepository..currentUser = _user;
    feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
    connectivity = GetIt.I<ConnectivityService>() as FakeConnectivityService;
  });

  ProviderContainer containerOf() {
    final container = createContainer();
    addTearDown(
      container.listen(changePasswordViewModelProvider, (_, _) {}).close,
    );
    return container;
  }

  ChangePasswordViewModel vmOf(ProviderContainer c) =>
      c.read(changePasswordViewModelProvider.notifier);

  ChangePasswordState stateOf(ProviderContainer c) =>
      c.read(changePasswordViewModelProvider);

  /// Geçerli form.
  ProviderContainer filled({String next = _next, String? confirm}) {
    final c = containerOf();
    vmOf(c)
      ..setCurrentPassword(_current)
      ..setNewPassword(next)
      ..setConfirm(confirm ?? next);
    return c;
  }

  group('SHT-32 · ChangePasswordState', () {
    test('varsayılan: boş, temiz, güç 0; props tüm alanları içerir', () {
      const state = ChangePasswordState();
      expect(state.isDirty, isFalse);
      expect(state.strength, 0);
      expect(state.props, hasLength(7));
      expect(
        state.copyWith(submitError: ChangePasswordError.unknown),
        isNot(state),
      );
      expect(
        state
            .copyWith(submitError: ChangePasswordError.unknown)
            .copyWith(clearSubmitError: true),
        state,
      );
    });

    test('kirlilik: mevcut ya da yeni şifre doluyken (tekrar sayılmaz); '
        'başarıdan sonra temiz', () {
      const empty = ChangePasswordState();
      expect(empty.copyWith(currentPassword: 'a').isDirty, isTrue);
      expect(empty.copyWith(newPassword: 'a').isDirty, isTrue);
      expect(empty.copyWith(confirm: 'a').isDirty, isFalse);
      expect(
        empty.copyWith(currentPassword: 'a', isDone: true).isDirty,
        isFalse,
      );
    });

    test('güç: AUT-02 ile aynı dört ölçüt', () {
      expect(const ChangePasswordState(newPassword: 'abcdefgh').strength, 1);
      expect(const ChangePasswordState(newPassword: 'Abcdefg1').strength, 3);
      expect(const ChangePasswordState(newPassword: _next).strength, 4);
    });
  });

  group('SHT-32 · ChangePasswordViewModel · doğrulama', () {
    test('boş form: mevcut zorunlu, yeni şifre zayıf; istek yok', () async {
      final c = containerOf();
      await vmOf(c).submit();
      expect(stateOf(c).errors, {
        PasswordField.current: FormFieldError.required,
        PasswordField.newPassword: FormFieldError.passwordWeak,
      });
      expect(auth.callsTo('changePassword'), isEmpty);
    });

    test('politika dışı yeni şifre ve uyuşmayan tekrar', () async {
      final c = filled(next: 'abcdefgh', confirm: 'abcdefgX');
      await vmOf(c).submit();
      expect(stateOf(c).errors, {
        PasswordField.newPassword: FormFieldError.passwordWeak,
        PasswordField.confirm: FormFieldError.passwordMismatch,
      });
      expect(auth.callsTo('changePassword'), isEmpty);
    });

    test('alan düzenlemesi yalnızca o alanın hatasını ve sunucu hatasını '
        'siler', () async {
      final c = containerOf();
      await vmOf(c).submit();
      vmOf(c).setCurrentPassword('x');
      expect(stateOf(c).errors.keys, [PasswordField.newPassword]);
    });
  });

  group('SHT-32 · ChangePasswordViewModel · gönderim', () {
    test('başarı: yeniden doğrulama (mevcut şifre) + güncelleme → isDone, '
        'TST-44', () async {
      final c = filled();
      await vmOf(c).submit();
      expect(auth.callsTo('changePassword').single.args, [_current, _next]);
      expect(auth.service.callsTo('reauthenticate').single.args, [_current]);
      expect(auth.service.callsTo('updatePassword').single.args, [_next]);
      expect(stateOf(c).isDone, isTrue);
      expect(stateOf(c).isSubmitting, isFalse);
      expect(stateOf(c).submitError, isNull);
      expect(feedback.toasts, [ToastId.tst44]);
    });

    test('hatalı mevcut şifre: yeniden doğrulama reddedilir, şifre '
        'güncellenmez → wrongPassword', () async {
      auth.service.failNext(AuthError.invalidCredentials);
      final c = filled();
      await vmOf(c).submit();
      expect(auth.service.callsTo('updatePassword'), isEmpty);
      expect(stateOf(c).submitError, ChangePasswordError.wrongPassword);
      expect(stateOf(c).isDone, isFalse);
      expect(feedback.toasts, isEmpty);
      // Mevcut şifre düzeltilince hata silinir.
      vmOf(c).setCurrentPassword('Demo1234?');
      expect(stateOf(c).submitError, isNull);
    });

    test('çok fazla deneme → tooManyRequests', () async {
      auth.service.failNext(AuthError.tooManyRequests);
      final c = filled();
      await vmOf(c).submit();
      expect(stateOf(c).submitError, ChangePasswordError.tooManyRequests);
    });

    test('zayıf şifre (sunucu) → weak + yeni şifre alan hatası', () async {
      auth.failNext(AuthError.weakPassword);
      final c = filled();
      await vmOf(c).submit();
      expect(stateOf(c).submitError, ChangePasswordError.weak);
      expect(
        stateOf(c).errors[PasswordField.newPassword],
        FormFieldError.passwordWeak,
      );
    });

    test('ağ hatası → network + TST-24', () async {
      auth.failNext(AuthError.network);
      final c = filled();
      await vmOf(c).submit();
      expect(stateOf(c).submitError, ChangePasswordError.network);
      expect(feedback.toasts, [ToastId.tst24]);
    });

    test('bilinmeyen hata → unknown', () async {
      auth.failNext(AuthError.unknown);
      final c = filled();
      await vmOf(c).submit();
      expect(stateOf(c).submitError, ChangePasswordError.unknown);
      expect(stateOf(c).isSubmitting, isFalse);
    });

    test('çevrimdışı: istek gönderilmez, TST-24', () async {
      connectivity.isOffline = true;
      final c = filled();
      await vmOf(c).submit();
      expect(auth.callsTo('changePassword'), isEmpty);
      expect(stateOf(c).submitError, ChangePasswordError.network);
      expect(feedback.toasts, [ToastId.tst24]);
    });

    test('süren ya da tamamlanmış gönderim yok sayılır', () async {
      final c = filled();
      final first = vmOf(c).submit();
      expect(stateOf(c).isSubmitting, isTrue);
      await vmOf(c).submit();
      await first;
      await vmOf(c).submit();
      expect(auth.callsTo('changePassword'), hasLength(1));
    });
  });
}
