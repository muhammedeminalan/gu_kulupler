import 'dart:async';

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/auth/provider/verify_email_state.dart';
import 'package:gu_kulupler/product/feedback/catalogs/toasts/toast_catalog.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'verify_email_view_model.g.dart';

/// AUT-03 "E-postanı doğrula" ekranının ViewModel'i (PLAN §12.5; prototip
/// `screens-auth.js:107`).
///
/// Doğrulama bağlantısına tıklandı mı diye sunucuya sorar ve doğrulama
/// e-postasını yeniden gönderir. **Yönlendirme yapmaz:** doğrulama
/// görülünce oturum yeniden çözülür (`SessionViewModel.resolve`, W-56c) ve
/// router kullanıcıyı AUT-05'e ya da uygulama kabuğuna taşır. Çıkış view'daki
/// `SignOutMixin` ile yapılır (DLG-06).
///
/// | İşlem | Sonuç | State | Geri bildirim |
/// |---|---|---|---|
/// | [checkVerified] | doğrulanmış | `isVerified` → [successHold] → oturum çözülür | başarı görünümü (router) |
/// | | hâlâ doğrulanmamış | `lastCheckWasUnverified` | TST-02 |
/// | | oturum çözülemedi | `isVerified` geri alınır, `isError` | ekran içi hata satırı |
/// | [resend] | gönderildi | `resendAvailableAt` = şimdi + 60 sn | TST-03 |
/// | | bekleme sürüyor | `resendAvailableAt` | TST-X3 `{s}` |
/// | ikisi de | çevrimdışı / ağ | — | TST-24 |
/// | | oturum geçersiz / hesap askıda | — | oturum katmanı (DLG-27 / DLG-01) |
/// | | diğer | `isError` | ekran içi hata satırı |
///
/// Design: AUT-03
@riverpod
final class VerifyEmailViewModel extends _$VerifyEmailViewModel
    with ProjectDependencyMixin, WriteGuardMixin {
  /// Başarı görünümünün ekranda kaldığı süre: onay işareti çizilsin ve
  /// "E-postan doğrulandı" okunabilsin diye oturum bu süre dolmadan
  /// çözülmez. Prototipteki 1100 ms beklemenin (`screens-auth.js:109`) token
  /// karşılığı: daire çizimi + tik gecikmesi + tik çizimi (1020 ms).
  static final Duration successHold =
      GuMotion.circleDraw + GuMotion.checkDrawDelay + GuMotion.checkDraw;

  @override
  VerifyEmailState build() => VerifyEmailState(
    email: authRepository.currentUser?.email ?? '',
    // Kayıt, doğrulama e-postasını gönderip beklemeyi başlatmış olabilir.
    resendAvailableAt: _cooldownEnd(authRepository.resendCooldownRemaining),
  );

  /// "Doğruladım" (`AUT-03.confirm`): e-posta doğrulandı mı diye sunucuya
  /// sorar.
  ///
  /// Sıra: süren denetim / başarı görünümü → yok say; çevrimdışı kapısı
  /// (TST-24); `reloadUser` (kimlik jetonunu da yeniler). Doğrulanmışsa
  /// başarı görünümü [successHold] kadar gösterilir, ardından oturum yeniden
  /// çözülür; oturum ilerlemezse (belge / claim okunamadı) başarı görünümü
  /// geri alınır ki kullanıcı yeniden deneyebilsin.
  Future<VerifyOutcome> checkVerified() async {
    if (state.isChecking || state.isVerified) return VerifyOutcome.failed;
    if (!ensureOnline()) return VerifyOutcome.failed;

    state = state.copyWith(isChecking: true, isError: false);
    final result = await authRepository.reloadUser();
    if (!ref.mounted) return VerifyOutcome.failed;
    switch (result) {
      case FirebaseSuccess():
        state = state.copyWith(
          isChecking: false,
          lastCheckWasUnverified: false,
          isVerified: true,
        );
        await _holdSuccess();
        if (!ref.mounted) return VerifyOutcome.verified;
        return _resolveSession();
      case FirebaseFailure(error: AuthError.emailNotVerified):
        state = state.copyWith(
          isChecking: false,
          lastCheckWasUnverified: true,
        );
        feedback.showToast(ToastId.tst02);
        return VerifyOutcome.unverified;
      case FirebaseFailure(:final error, :final message):
        state = state.copyWith(isChecking: false);
        _onFailure(error, 'E-posta doğrulaması denetlenemedi', message);
        return VerifyOutcome.failed;
    }
  }

  /// "Tekrar gönder" (`AUT-03.resend`): doğrulama e-postasını yeniden
  /// gönderir ve `Limits.verificationResendCooldown` beklemesini başlatır.
  ///
  /// Bekleme sürüyorsa (düğme devre dışı görünür) gönderim yapılmaz, kalan
  /// saniyeyle TST-X3 gösterilir. Sıra: süren gönderim / başarı görünümü →
  /// yok say; bekleme (TST-X3); çevrimdışı kapısı (TST-24);
  /// `sendEmailVerification`.
  Future<void> resend() async {
    if (state.isResending || state.isVerified) return;
    final remaining = remainingResend(appClock.nowUtc());
    if (remaining > Duration.zero) {
      _showCooldown(remaining);
      return;
    }
    if (!ensureOnline()) return;

    state = state.copyWith(
      isResending: true,
      isError: false,
      clearResendAvailableAt: true,
    );
    final result = await authRepository.sendEmailVerification();
    if (!ref.mounted) return;
    switch (result) {
      case FirebaseSuccess():
        state = state.copyWith(
          isResending: false,
          resendAvailableAt: _cooldownEnd(
            authRepository.resendCooldownRemaining ??
                Limits.verificationResendCooldown,
          ),
        );
        feedback.showToast(ToastId.tst03);
      case FirebaseFailure(error: AuthError.resendCooldown, :final detail):
        _startCooldown(detail is AuthFailureDetail ? detail.retryAfter : null);
      case FirebaseFailure(error: AuthError.tooManyRequests):
        // Sunucu kısıtı süre bildirmez: yerel bekleme süresi kadar beklenir.
        _startCooldown(null);
      case FirebaseFailure(:final error, :final message):
        state = state.copyWith(isResending: false);
        _onFailure(error, 'Doğrulama e-postası gönderilemedi', message);
    }
  }

  /// Süresi dolan beklemeyi kaldırır (geri sayım bitince view çağırır).
  /// Bekleme sürüyorsa etkisizdir.
  void clearResendCooldown() {
    if (state.resendAvailableAt == null) return;
    if (remainingResend(appClock.nowUtc()) > Duration.zero) return;
    state = state.copyWith(clearResendAvailableAt: true);
  }

  /// [now] anında "Tekrar gönder" için kalan bekleme; yoksa [Duration.zero].
  Duration remainingResend(DateTime now) => state.remainingResend(now);

  /// Oturumu yeniden çözer (W-56c). Oturum `unverified`'dan çıktıysa router
  /// yönlendirir; çıkmadıysa başarı görünümü geri alınır.
  Future<VerifyOutcome> _resolveSession() async {
    await ref.read(sessionViewModelProvider.notifier).resolve();
    if (!ref.mounted) return VerifyOutcome.verified;
    final session = ref.read(sessionViewModelProvider);
    if (session.status != AuthStatus.unverified) return VerifyOutcome.verified;
    AppLogger.warn('E-posta doğrulandı ama oturum çözülemedi');
    state = state.copyWith(isVerified: false, isError: session.isError);
    return VerifyOutcome.failed;
  }

  /// [successHold] kadar bekler; ViewModel bu sırada bırakılırsa hemen döner
  /// (bekleyen zamanlayıcı kalmaz).
  Future<void> _holdSuccess() {
    final completer = Completer<void>();
    void complete() {
      if (!completer.isCompleted) completer.complete();
    }

    final timer = Timer(successHold, complete);
    ref.onDispose(() {
      timer.cancel();
      complete();
    });
    return completer.future;
  }

  /// Beklemeyi [until] anına (bilinmiyorsa şimdi + yerel bekleme süresi)
  /// kurar ve kalan saniyeyle TST-X3 gösterir.
  void _startCooldown(DateTime? until) {
    final end = until ?? _cooldownEnd(Limits.verificationResendCooldown);
    state = state.copyWith(isResending: false, resendAvailableAt: end);
    _showCooldown(remainingResend(appClock.nowUtc()));
  }

  /// TST-X3 "Tekrar göndermek için {s} sn bekle." — saniye düğmedeki geri
  /// sayımla aynı yuvarlanır.
  void _showCooldown(Duration remaining) {
    if (remaining <= Duration.zero) return;
    feedback.showToast(
      ToastId.tstX3,
      params: ToastParams(s: GuCountdown.secondsLeft(remaining).toString()),
    );
  }

  /// [remaining] kadar sonraki an; bekleme yoksa (`null` ya da dolmuş) `null`.
  DateTime? _cooldownEnd(Duration? remaining) {
    if (remaining == null || remaining <= Duration.zero) return null;
    return appClock.nowUtc().add(remaining);
  }

  /// Denetim ve yeniden göndermenin ortak hata eşlemesi.
  void _onFailure(AuthError error, String what, String? message) {
    switch (error) {
      case AuthError.network:
        feedback.showToast(ToastId.tst24);
      case AuthError.sessionExpired:
      case AuthError.userDisabled:
        // Oturum katmanı `tokenErrors` üzerinden ele alır (DLG-27 / DLG-01).
        break;
      case AuthError.invalidEmail:
      case AuthError.invalidCredentials:
      case AuthError.emailAlreadyInUse:
      case AuthError.weakPassword:
      case AuthError.tooManyRequests:
      case AuthError.requiresRecentLogin:
      case AuthError.invalidActionCode:
      case AuthError.operationNotAllowed:
      case AuthError.unknown:
      case AuthError.domainNotAllowed:
      case AuthError.lockedOut:
      case AuthError.resendCooldown:
      case AuthError.emailNotVerified:
        AppLogger.warn('$what: ${error.name}', error: message);
        state = state.copyWith(isError: true);
    }
  }
}
