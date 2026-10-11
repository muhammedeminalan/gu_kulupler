import 'dart:async';

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/features/auth/provider/login_state.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/mixin/form_validation_mixin.dart';
import 'package:gu_kulupler/product/mixin/suspended_account_mixin.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'login_view_model.g.dart';

/// AUT-01 Giriş formunun ViewModel'i (PLAN §12.5; prototip
/// `screens-auth.js:54`).
///
/// Formu doğrular ve `AuthRepository.signIn` ile oturum açar. **Yönlendirme
/// yapmaz:** başarılı girişte oturum akışı `SessionViewModel`'i, o da router'ı
/// tetikler (`/login?from=` dönüşü dahil, R7).
///
/// | Sonuç | State | Geri bildirim |
/// |---|---|---|
/// | başarı | şifre temizlenir, sayaç sıfırlanır; doğrulanmış hesapta son giriş anı yazılır | — (router) |
/// | e-posta / şifre hatalı | `failedAttempts + 1`, `invalidCredential` | TST-01 |
/// | … ve adres kilitlendi (5. hata) | + `lockedUntil` | TST-01, view DLG-02 |
/// | kilit sürüyor | `lockedUntil` | view DLG-02 |
/// | hesap askıda | `suspended` | oturum kapatılır + DLG-01 |
/// | çevrimdışı / ağ | `network` | TST-24 |
/// | adres biçimi / alan adı (repository) | `errors[email]` | alan hatası |
/// | diğer | `unknown` | ekran içi hata bandı |
///
/// Design: AUT-01
@riverpod
final class LoginViewModel extends _$LoginViewModel
    with
        ProjectDependencyMixin,
        WriteGuardMixin,
        SuspendedAccountMixin,
        FormValidationMixin<LoginField> {
  @override
  LoginState build() => const LoginState();

  /// E-posta alanı değişti: alanın hatası ve gönderim hatası temizlenir.
  void setEmail(String value) {
    if (value == state.email) return;
    state = state.copyWith(
      email: value,
      isDirty: true,
      errors: _errorsWithout(LoginField.email),
      clearSubmitError: true,
    );
  }

  /// Şifre alanı değişti: alanın hatası ve gönderim hatası temizlenir.
  void setPassword(String value) {
    if (value == state.password) return;
    state = state.copyWith(
      password: value,
      isDirty: true,
      errors: _errorsWithout(LoginField.password),
      clearSubmitError: true,
    );
  }

  /// Şifreyi göster / gizle (`AUT-01.togglePassword`).
  void togglePasswordVisibility() {
    state = state.copyWith(isPasswordVisible: !state.isPasswordVisible);
  }

  /// Formu doğrular, hataları state'e yazar; hata yoksa `true`.
  ///
  /// Kurallar (prototip `screens-auth.js:57`): e-posta zorunlu → biçim →
  /// izinli alan adı (kırpılarak); şifre zorunlu → en az
  /// `Limits.passwordMinLength` karakter (büyük harf / rakam kuralı yalnızca
  /// kayıtta aranır).
  bool validate() {
    final errors = validateFields({
      LoginField.email: () => emailError(state.email),
      LoginField.password: () => _passwordError(state.password),
    });
    state = state.copyWith(errors: errors);
    return errors.isEmpty;
  }

  /// Giriş yapar (`AUT-01.login`, `AUT-01.form`).
  ///
  /// Sıra: süren gönderim → yok say; kilit → [LoginOutcome.locked];
  /// doğrulama; çevrimdışı kapısı (TST-24); `signIn`. E-posta kırpılarak
  /// gönderilir.
  Future<LoginOutcome> submit() async {
    if (state.isSubmitting) return LoginOutcome.failed;
    if (isLockedAt(appClock.nowUtc())) return LoginOutcome.locked;
    if (!validate()) return LoginOutcome.failed;
    if (!ensureOnline()) {
      state = state.copyWith(submitError: LoginError.network);
      return LoginOutcome.failed;
    }

    final email = state.email.trim();
    state = state.copyWith(isSubmitting: true, clearSubmitError: true);
    final result = await authRepository.signIn(
      email: email,
      password: state.password,
    );
    // Profil belgesi yalnızca doğrulanmış hesapta vardır (rules-spec §3.2).
    if (result case FirebaseSuccess(:final data) when data.emailVerified) {
      unawaited(_touchLastLogin(data.uid));
    }
    if (!ref.mounted) {
      return result.isSuccess ? LoginOutcome.success : LoginOutcome.failed;
    }
    switch (result) {
      case FirebaseSuccess():
        state = state.copyWith(
          password: '',
          errors: const <LoginField, FormFieldError>{},
          isDirty: false,
          isSubmitting: false,
          failedAttempts: 0,
          clearLockedUntil: true,
          clearSubmitError: true,
        );
        return LoginOutcome.success;
      case FirebaseFailure(:final error, :final message, :final detail):
        return _onFailure(
          error,
          email: email,
          message: message,
          detail: detail,
        );
    }
  }

  /// Gönderim hatasını temizler (hata bandı kapanır).
  void clearSubmitError() {
    if (state.submitError == null) return;
    state = state.copyWith(clearSubmitError: true);
  }

  /// Süresi dolan kilidi kaldırır (geri sayım bitince view çağırır). Kilit
  /// sürüyorsa etkisizdir.
  void clearLock() {
    if (state.lockedUntil == null || isLockedAt(appClock.nowUtc())) return;
    state = state.copyWith(clearLockedUntil: true, failedAttempts: 0);
  }

  /// [now] anında giriş kilitli mi?
  bool isLockedAt(DateTime now) => state.isLockedAt(now);

  static FormFieldError? _passwordError(String password) {
    if (password.isEmpty) return FormFieldError.required;
    return password.length < Limits.passwordMinLength
        ? FormFieldError.passwordWeak
        : null;
  }

  /// Son giriş anını yazar (`private/account.lastLoginAt`; W-56d). Girişi
  /// bekletmez; hata yalnızca günlüğe düşer. Hesap belgesi henüz yoksa
  /// (profil kurulmadı) yazılacak yer yoktur — sessizce geçilir.
  Future<void> _touchLastLogin(String uid) async {
    final result = await userRepository.touchLastLogin(uid);
    if (result case FirebaseFailure(
      :final error,
    ) when error != FirestoreError.notFound) {
      AppLogger.warn('Son giriş anı yazılamadı: ${error.name}');
    }
  }

  Future<LoginOutcome> _onFailure(
    AuthError error, {
    required String email,
    required String? message,
    required Object? detail,
  }) async {
    switch (error) {
      case AuthError.invalidCredentials:
        final remaining = authRepository.loginLockRemaining(email);
        final isLocked = remaining != null && remaining > Duration.zero;
        state = state.copyWith(
          isSubmitting: false,
          failedAttempts: state.failedAttempts + 1,
          submitError: LoginError.invalidCredential,
          lockedUntil: isLocked ? appClock.nowUtc().add(remaining) : null,
        );
        feedback.showToast(ToastId.tst01);
        return isLocked ? LoginOutcome.locked : LoginOutcome.invalid;
      case AuthError.lockedOut:
        state = state.copyWith(
          isSubmitting: false,
          lockedUntil: detail is AuthFailureDetail
              ? detail.retryAfter
              : _defaultLockEnd(),
        );
        return LoginOutcome.locked;
      case AuthError.tooManyRequests:
        // Sunucu kısıtı süre bildirmez: yerel kilit süresi kadar beklenir.
        state = state.copyWith(
          isSubmitting: false,
          lockedUntil: _defaultLockEnd(),
        );
        return LoginOutcome.locked;
      case AuthError.userDisabled:
        state = state.copyWith(
          isSubmitting: false,
          password: '',
          submitError: LoginError.suspended,
        );
        final signedOut = await authRepository.signOut();
        if (signedOut case FirebaseFailure(error: final signOutError)) {
          AppLogger.warn('Askıdaki oturum kapatılamadı: ${signOutError.name}');
        }
        await showSuspendedAccountDialog();
        return LoginOutcome.suspended;
      case AuthError.network:
        state = state.copyWith(
          isSubmitting: false,
          submitError: LoginError.network,
        );
        feedback.showToast(ToastId.tst24);
        return LoginOutcome.failed;
      case AuthError.invalidEmail:
        state = state.copyWith(
          isSubmitting: false,
          errors: {
            ...state.errors,
            LoginField.email: FormFieldError.invalidEmail,
          },
        );
        return LoginOutcome.failed;
      case AuthError.domainNotAllowed:
        state = state.copyWith(
          isSubmitting: false,
          errors: {
            ...state.errors,
            LoginField.email: FormFieldError.domainNotAllowed,
          },
        );
        return LoginOutcome.failed;
      case AuthError.emailAlreadyInUse:
      case AuthError.weakPassword:
      case AuthError.requiresRecentLogin:
      case AuthError.sessionExpired:
      case AuthError.invalidActionCode:
      case AuthError.operationNotAllowed:
      case AuthError.unknown:
      case AuthError.resendCooldown:
      case AuthError.emailNotVerified:
        AppLogger.warn('Giriş yapılamadı: ${error.name}', error: message);
        state = state.copyWith(
          isSubmitting: false,
          submitError: LoginError.unknown,
        );
        return LoginOutcome.failed;
    }
  }

  DateTime _defaultLockEnd() => appClock.nowUtc().add(Limits.loginLockout);

  Map<LoginField, FormFieldError> _errorsWithout(LoginField field) {
    if (!state.errors.containsKey(field)) return state.errors;
    return {
      for (final MapEntry(:key, :value) in state.errors.entries)
        if (key != field) key: value,
    };
  }
}
