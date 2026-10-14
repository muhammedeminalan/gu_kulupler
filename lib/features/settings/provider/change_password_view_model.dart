import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/features/settings/provider/change_password_state.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/mixin/form_validation_mixin.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'change_password_view_model.g.dart';

/// SHT-32 Şifre değiştir sayfasının ViewModel'i (PLAN §12.12; prototip
/// `SHEETS['SHT-32']`, `sheets.js:149–152`).
///
/// Formu doğrular ve `AuthRepository.changePassword` çağırır: mevcut şifreyle
/// **yeniden doğrulama** + yeni şifreyi yazma tek metottur (§10.4). Sayfayı
/// kapatmaz; başarıda [ChangePasswordState.isDone] olur, sayfa `true` ile
/// kapanır.
///
/// | Sonuç | State | Geri bildirim |
/// |---|---|---|
/// | değişti | `isDone` | TST-44 |
/// | mevcut şifre hatalı | `wrongPassword` | mevcut şifre alanı "Şifre hatalı" |
/// | yeni şifre zayıf (sunucu) | `weak`, `errors[newPassword]` | alan hatası |
/// | çok fazla deneme | `tooManyRequests` | form altı hata satırı |
/// | çevrimdışı / ağ | `network` | TST-24 |
/// | diğer | `unknown` | form altı hata satırı |
///
/// Doğrulama (gönderimden önce, `FormValidationMixin`): mevcut şifre zorunlu;
/// yeni şifre `Limits.passwordPattern` (T-13 kuralı); tekrar yeni şifreyle
/// aynı.
///
/// Design: SHT-32
@riverpod
final class ChangePasswordViewModel extends _$ChangePasswordViewModel
    with
        ProjectDependencyMixin,
        WriteGuardMixin,
        FormValidationMixin<PasswordField> {
  @override
  ChangePasswordState build() => const ChangePasswordState();

  /// Mevcut şifre değişti (`SHT-32.current`).
  void setCurrentPassword(String value) {
    if (value == state.currentPassword) return;
    state = _edited(
      state.copyWith(currentPassword: value),
      PasswordField.current,
    );
  }

  /// Yeni şifre değişti (`SHT-32.new`).
  void setNewPassword(String value) {
    if (value == state.newPassword) return;
    state = _edited(
      state.copyWith(newPassword: value),
      PasswordField.newPassword,
    );
  }

  /// Yeni şifre tekrarı değişti (`SHT-32.repeat`).
  void setConfirm(String value) {
    if (value == state.confirm) return;
    state = _edited(state.copyWith(confirm: value), PasswordField.confirm);
  }

  /// Formu doğrular, hataları state'e yazar; hata yoksa `true`.
  bool validate() {
    final errors = validateFields({
      PasswordField.current: () =>
          state.currentPassword.isEmpty ? FormFieldError.required : null,
      PasswordField.newPassword: () => passwordError(state.newPassword),
      PasswordField.confirm: () =>
          confirmError(state.newPassword, state.confirm),
    });
    state = state.copyWith(errors: errors);
    return errors.isEmpty;
  }

  /// "Kaydet" (`SHT-32.save`): doğrulama → çevrimdışı kapısı (TST-24) →
  /// `changePassword`. Süren gönderim ya da tamamlanmış form yok sayılır.
  Future<void> submit() async {
    if (state.isSubmitting || state.isDone) return;
    if (!validate()) return;
    if (!ensureOnline()) {
      state = state.copyWith(submitError: ChangePasswordError.network);
      return;
    }
    state = state.copyWith(isSubmitting: true, clearSubmitError: true);
    final result = await authRepository.changePassword(
      currentPassword: state.currentPassword,
      newPassword: state.newPassword,
    );
    // Sayfa bu arada kapanmış olabilir; kapanmış state'e yazılmaz.
    if (!ref.mounted) return;
    switch (result) {
      case FirebaseSuccess():
        state = state.copyWith(isSubmitting: false, isDone: true);
        feedback.showToast(ToastId.tst44);
      case FirebaseFailure(:final error, :final message):
        _onFailure(error, message);
    }
  }

  void _onFailure(AuthError error, String? message) {
    final failed = state.copyWith(isSubmitting: false);
    switch (error) {
      case AuthError.invalidCredentials:
        state = failed.copyWith(submitError: ChangePasswordError.wrongPassword);
      case AuthError.weakPassword:
        state = failed.copyWith(
          submitError: ChangePasswordError.weak,
          errors: {
            ...failed.errors,
            PasswordField.newPassword: FormFieldError.passwordWeak,
          },
        );
      case AuthError.tooManyRequests || AuthError.lockedOut:
        state = failed.copyWith(
          submitError: ChangePasswordError.tooManyRequests,
        );
      case AuthError.network:
        state = failed.copyWith(submitError: ChangePasswordError.network);
        feedback.showToast(ToastId.tst24);
      case AuthError.invalidEmail ||
          AuthError.userDisabled ||
          AuthError.emailAlreadyInUse ||
          AuthError.requiresRecentLogin ||
          AuthError.sessionExpired ||
          AuthError.invalidActionCode ||
          AuthError.operationNotAllowed ||
          AuthError.unknown ||
          AuthError.domainNotAllowed ||
          AuthError.resendCooldown ||
          AuthError.emailNotVerified:
        AppLogger.warn('Şifre değiştirilemedi: ${error.name}', error: message);
        state = failed.copyWith(submitError: ChangePasswordError.unknown);
    }
  }

  /// Düzenleme sonrası ortak güncelleme: [field] alanının hatası ve sunucu
  /// hatası silinir.
  ChangePasswordState _edited(ChangePasswordState next, PasswordField field) =>
      next.copyWith(
        clearSubmitError: true,
        errors: {
          for (final MapEntry(:key, :value) in next.errors.entries)
            if (key != field) key: value,
        },
      );
}
