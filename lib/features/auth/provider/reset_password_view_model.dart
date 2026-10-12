import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/features/auth/provider/reset_password_state.dart';
import 'package:gu_kulupler/product/feedback/catalogs/toasts/toast_catalog.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/mixin/form_validation_mixin.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reset_password_view_model.g.dart';

/// AUT-04 Şifre sıfırlama ekranının ViewModel'i (PLAN §12.5; prototip
/// `Reset`, `screens-auth.js:126–131`).
///
/// E-postayı doğrular ve `AuthRepository.sendPasswordReset` ile sıfırlama
/// bağlantısı ister. **Yönlendirme yapmaz** (geri / "Girişe dön" view'dadır).
///
/// | Sonuç | State | Geri bildirim |
/// |---|---|---|
/// | gönderildi (ilk) | `isSent`, 60 sn bekleme | "Gelen kutunu kontrol et" görünümü |
/// | gönderildi (yeniden) | bekleme yenilenir | TST-03 |
/// | bekleme sürerken yeniden gönder | — | TST-X3 `{s}` |
/// | çevrimdışı / ağ | `network` | TST-24 |
/// | sunucu kısıtı (çok fazla istek) | 60 sn bekleme | TST-X3 `{s}` |
/// | adres biçimi / alan adı (sunucu) | `errors[email]` | alan hatası |
/// | diğer | `unknown` | ekran içi hata satırı |
///
/// **Bu ekran hesabı sızdırmaz:** adresin kayıtlı ya da askıda olduğu AUT-04
/// üzerinden belli edilmez. Repository bulunmayan hesapta başarı döner;
/// askıdaki hesap cevabı da burada aynı "gönderildi" görünümüne çevrilir
/// (metin zaten "kayıtlıysa" der). Kapsam yalnızca bu ekrandır: AUT-02
/// kayıtlı adresi tasarım gereği söyler (`authErrExists`) ve sunucu tarafı
/// sayım koruması bir konsol ayarıdır (rules-spec §9.9).
///
/// 60 sn bekleme bir **arayüz kolaylığıdır, güvenlik sınırı değildir**:
/// state'te durur, ekran yeniden açılınca sıfırlanır ve doğrudan REST
/// çağrısı onu atlar; gerçek sınır Firebase Auth'un sunucu kotasıdır.
///
/// Design: AUT-04
@riverpod
final class ResetPasswordViewModel extends _$ResetPasswordViewModel
    with
        ProjectDependencyMixin,
        WriteGuardMixin,
        FormValidationMixin<ResetField> {
  @override
  ResetPasswordState build() => const ResetPasswordState();

  /// E-posta alanı değişti (`AUT-04.email`): alanın hatası ve gönderim hatası
  /// temizlenir.
  void setEmail(String value) {
    if (value == state.email) return;
    state = state.copyWith(
      email: value,
      errors: const <ResetField, FormFieldError>{},
      clearSubmitError: true,
    );
  }

  /// Formu doğrular, hatayı state'e yazar; hata yoksa `true`.
  ///
  /// Kural: zorunlu → biçim → izinli alan adı (D-27; AUT-01 / AUT-02 ile aynı
  /// `emailError`). Adres kırpılarak denetlenir.
  bool validate() {
    final errors = validateFields({
      ResetField.email: () => emailError(state.email),
    });
    state = state.copyWith(errors: errors);
    return errors.isEmpty;
  }

  /// Sıfırlama bağlantısı ister (`AUT-04.send`, klavye eylem tuşu).
  ///
  /// Sıra: süren gönderim ya da gönderilmiş form → yok say; doğrulama;
  /// bekleme (TST-X3); çevrimdışı kapısı (TST-24); `sendPasswordReset`.
  /// Başarıda toast gösterilmez: ekran "Gelen kutunu kontrol et" görünümüne
  /// geçer (`screens-auth.js:128`).
  Future<void> submit() async {
    if (state.isSubmitting || state.isSent) return;
    if (!validate()) return;
    await _send(isResend: false);
  }

  /// Bağlantıyı yeniden ister (`AUT-04.resend`). Bekleme sürüyorsa TST-X3
  /// `{s}` gösterir ve istek göndermez; gönderilince TST-03 gösterir ve
  /// beklemeyi yeniler. Form henüz gönderilmediyse etkisizdir.
  Future<void> resend() async {
    if (state.isSubmitting || !state.isSent) return;
    await _send(isResend: true);
  }

  /// [now] anında yeniden gönderime kalan süre (bekleme yoksa sıfır).
  Duration remainingResend(DateTime now) => state.remainingResend(now);

  Future<void> _send({required bool isResend}) async {
    final wait = remainingResend(appClock.nowUtc());
    if (wait > Duration.zero) {
      _showWait(wait);
      return;
    }
    if (!ensureOnline()) {
      state = state.copyWith(submitError: SubmitError.network);
      return;
    }

    final email = state.sentEmail;
    state = state.copyWith(isSubmitting: true, clearSubmitError: true);
    final result = await authRepository.sendPasswordReset(email: email);
    // Ekran bu arada kapanmış olabilir; kapanmış state'e yazılmaz.
    if (!ref.mounted) return;
    switch (result) {
      case FirebaseSuccess():
        _onSent(email, isResend: isResend);
      case FirebaseFailure(:final error, :final message):
        _onFailure(error, message, email: email, isResend: isResend);
    }
  }

  /// "Gönderildi" durumu: görünüm değişir, bekleme başlar. Gösterilen adres
  /// isteğin gittiği adrestir (istek sürerken alan değişmiş olabilir).
  void _onSent(String email, {required bool isResend}) {
    state = state.copyWith(
      email: email,
      errors: const <ResetField, FormFieldError>{},
      isSubmitting: false,
      isSent: true,
      resendAvailableAt: _cooldownEnd(),
      clearSubmitError: true,
    );
    if (isResend) feedback.showToast(ToastId.tst03);
  }

  void _onFailure(
    AuthError error,
    String? message, {
    required String email,
    required bool isResend,
  }) {
    final failed = state.copyWith(isSubmitting: false);
    switch (error) {
      // Hesabın yokluğu ya da askıda oluşu sızdırılmaz: gönderilmiş gibi.
      case AuthError.invalidCredentials || AuthError.userDisabled:
        _onSent(email, isResend: isResend);
      case AuthError.network:
        state = failed.copyWith(submitError: SubmitError.network);
        feedback.showToast(ToastId.tst24);
      case AuthError.tooManyRequests:
        // Sunucu kısıtı süre bildirmez: yeniden gönderim süresi kadar beklenir.
        state = failed.copyWith(resendAvailableAt: _cooldownEnd());
        _showWait(Limits.verificationResendCooldown);
      case AuthError.invalidEmail when !state.isSent:
        state = failed.copyWith(
          errors: const {ResetField.email: FormFieldError.invalidEmail},
        );
      case AuthError.domainNotAllowed when !state.isSent:
        state = failed.copyWith(
          errors: const {ResetField.email: FormFieldError.domainNotAllowed},
        );
      case AuthError.invalidEmail ||
          AuthError.domainNotAllowed ||
          AuthError.emailAlreadyInUse ||
          AuthError.weakPassword ||
          AuthError.requiresRecentLogin ||
          AuthError.sessionExpired ||
          AuthError.invalidActionCode ||
          AuthError.operationNotAllowed ||
          AuthError.unknown ||
          AuthError.lockedOut ||
          AuthError.resendCooldown ||
          AuthError.emailNotVerified:
        AppLogger.warn(
          'Şifre sıfırlama bağlantısı istenemedi: ${error.name}',
          error: message,
        );
        state = failed.copyWith(submitError: SubmitError.unknown);
    }
  }

  DateTime _cooldownEnd() =>
      appClock.nowUtc().add(Limits.verificationResendCooldown);

  /// TST-X3 "Tekrar göndermek için {s} sn bekle." — saniye yukarı yuvarlanır
  /// (düğmedeki geri sayımla aynı; prototip `Math.ceil`).
  void _showWait(Duration remaining) {
    final seconds =
        (remaining.inMicroseconds + Duration.microsecondsPerSecond - 1) ~/
        Duration.microsecondsPerSecond;
    feedback.showToast(ToastId.tstX3, params: ToastParams(s: '$seconds'));
  }
}
