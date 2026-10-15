import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/features/auth/provider/register_state.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/mixin/form_validation_mixin.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'register_view_model.g.dart';

/// Kayıt ekranının ViewModel'i (AUT-02; PLAN §12.5).
///
/// Formu tutar, doğrular ve hesabı açar. Hesap açıldığında:
///
/// * doğrulama e-postasını `AuthRepository.register` kendisi gönderir (ayrıca
///   çağrı yapılmaz; gönderilemezse AUT-03'te yeniden gönderilir);
/// * ad kimlik hesabının görünen adında taşınır, profil belgesi burada
///   **oluşturulmaz** (CD-134, W-56a — belge yalnızca doğrulanmış oturumda
///   yazılabilir); görünen ad yazılamazsa ad cihazda bekler
///   (`AppPreferencesStore.pendingDisplayName` — T-45 · F2);
/// * ekran değiştirmek bu sınıfın işi değildir: oturum akışı
///   `SessionViewModel`'i `unverified` yapar, router AUT-03'e yönlendirir.
@riverpod
final class RegisterViewModel extends _$RegisterViewModel
    with
        ProjectDependencyMixin,
        WriteGuardMixin,
        FormValidationMixin<RegisterField> {
  @override
  RegisterState build() => const RegisterState();

  /// Ad Soyad değişti.
  void setName(String value) {
    if (value == state.name) return;
    state = _edited(state.copyWith(name: value), const [RegisterField.name]);
  }

  /// E-posta değişti.
  void setEmail(String value) {
    if (value == state.email) return;
    state = _edited(state.copyWith(email: value), const [RegisterField.email]);
  }

  /// Şifre değişti; tekrar alanının "uyuşmuyor" hatası da geçersizleşir.
  void setPassword(String value) {
    if (value == state.password) return;
    state = _edited(state.copyWith(password: value), const [
      RegisterField.password,
      RegisterField.passwordConfirm,
    ]);
  }

  /// Şifre tekrarı değişti.
  void setPasswordConfirm(String value) {
    if (value == state.passwordConfirm) return;
    state = _edited(state.copyWith(passwordConfirm: value), const [
      RegisterField.passwordConfirm,
    ]);
  }

  /// Şifre alanlarını düz metin / gizli arasında değiştirir.
  void togglePasswordVisibility() =>
      state = state.copyWith(isPasswordVisible: !state.isPasswordVisible);

  /// KVKK + gizlilik onayını değiştirir.
  void toggleLegal() => state = _edited(
    state.copyWith(acceptedLegal: !state.acceptedLegal),
    const [RegisterField.legal],
  );

  /// Onayı verir — AUT-06'da "Okudum, anladım" denildiğinde çağrılır
  /// (`screens-auth.js:154`); kutu zaten işaretliyse etkisizdir.
  void acceptLegal() {
    if (state.acceptedLegal) return;
    toggleLegal();
  }

  /// Formu doğrular ve alan hatalarını state'e yazar; hata yoksa `true`.
  ///
  /// Kurallar: ad `Limits.nameMin` – `Limits.nameMax` (kırpılmış); e-posta
  /// dolu, biçimi geçerli ve alan adı izinli (D-27); şifre
  /// `Limits.passwordPattern` (en az 8 karakter + büyük harf + rakam); tekrar
  /// şifreyle aynı; onay verilmiş.
  bool validate() {
    final errors = validateFields({
      RegisterField.name: () =>
          fromFieldError(FieldValidators.name(state.name.trim())),
      RegisterField.email: () => emailError(state.email),
      RegisterField.password: () => passwordError(state.password),
      RegisterField.passwordConfirm: () =>
          confirmError(state.password, state.passwordConfirm),
      RegisterField.legal: () =>
          state.acceptedLegal ? null : FormFieldError.consentMissing,
    });
    state = state.copyWith(errors: errors);
    return errors.isEmpty;
  }

  /// Formu doğrular ve hesabı açar.
  ///
  /// Süren gönderim varken gelen çağrı yok sayılır (çift dokunma). Çevrimdışı
  /// ve ağ hatasında TST-24 gösterilir. Başarıda [RegisterState.isSubmitting]
  /// `true` kalır (ekran yönlendirmeyle kapanır).
  Future<RegisterOutcome> submit() async {
    if (state.isSubmitting) return RegisterOutcome.ignored;
    if (!validate()) return RegisterOutcome.invalid;
    if (!ensureOnline()) return RegisterOutcome.offline;
    state = state.copyWith(isSubmitting: true, clearSubmitError: true);
    final name = state.name.trim();
    final result = await authRepository.register(
      email: state.email.trim(),
      password: state.password,
      name: name,
    );
    switch (result) {
      case FirebaseSuccess(:final data):
        // Görünen ad yazılamadıysa (CD-134 madde 2) ad cihazda bekler; AUT-05
        // profili ondan yazar. E-postadan ad türetilmez (D-29; T-45 · F2).
        if (data.displayName?.trim().isEmpty ?? true) {
          final saved = await appPreferencesStore.setPendingDisplayName(
            data.uid,
            name,
          );
          if (!saved) AppLogger.warn('Bekleyen ad cihaza yazılamadı');
        }
        return RegisterOutcome.success;
      case FirebaseFailure(:final error, :final message):
        // Oturum olayı ekranı kapatmış olabilir; kapanmış state'e yazılmaz.
        if (ref.mounted) _onFailure(error, message);
        return RegisterOutcome.failed;
    }
  }

  void _onFailure(AuthError error, String? message) {
    final failed = state.copyWith(isSubmitting: false);
    switch (error) {
      case AuthError.emailAlreadyInUse:
        state = failed.copyWith(submitError: RegisterError.emailInUse);
      case AuthError.domainNotAllowed:
        state = failed.copyWith(
          submitError: RegisterError.domainNotAllowed,
          errors: _withError(
            RegisterField.email,
            FormFieldError.domainNotAllowed,
          ),
        );
      case AuthError.invalidEmail:
        state = failed.copyWith(
          errors: _withError(RegisterField.email, FormFieldError.invalidEmail),
        );
      case AuthError.weakPassword:
        state = failed.copyWith(
          submitError: RegisterError.weakPassword,
          errors: _withError(
            RegisterField.password,
            FormFieldError.passwordWeak,
          ),
        );
      case AuthError.network:
        state = failed.copyWith(submitError: RegisterError.network);
        feedback.showToast(ToastId.tst24);
      case AuthError.userDisabled ||
          AuthError.invalidCredentials ||
          AuthError.tooManyRequests ||
          AuthError.requiresRecentLogin ||
          AuthError.sessionExpired ||
          AuthError.invalidActionCode ||
          AuthError.operationNotAllowed ||
          AuthError.unknown ||
          AuthError.lockedOut ||
          AuthError.resendCooldown ||
          AuthError.emailNotVerified:
        AppLogger.warn('Kayıt başarısız: ${error.name}', error: message);
        state = failed.copyWith(submitError: RegisterError.unknown);
    }
  }

  /// Düzenleme sonrası ortak güncelleme: form kirlenir, [fields] alanlarının
  /// hatası ve eski sunucu hatası silinir.
  RegisterState _edited(RegisterState next, List<RegisterField> fields) =>
      next.copyWith(
        isDirty: true,
        clearSubmitError: true,
        errors: {
          for (final entry in next.errors.entries)
            if (!fields.contains(entry.key)) entry.key: entry.value,
        },
      );

  Map<RegisterField, FormFieldError> _withError(
    RegisterField field,
    FormFieldError error,
  ) => {...state.errors, field: error};
}
