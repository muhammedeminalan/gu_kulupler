import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/auth/provider/login_state.dart';
import 'package:gu_kulupler/features/auth/provider/login_view_model.dart';
import 'package:gu_kulupler/features/auth/view/login_view.dart';
import 'package:gu_kulupler/features/auth/view/widget/login_lock_dialog.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/mixin/keyboard_focus_mixin.dart';
import 'package:gu_kulupler/product/navigation/routes/auth_routes.dart';

/// AUT-01 davranışı: odak sırası, gönderim, kilit dialogu, askı bildirimi,
/// hata metni eşlemesi ve gezinme.
///
/// * Klavye eylem tuşu e-postadan şifreye geçer; şifrede formu gönderir
///   (prototip `form onSubmit` / `onEnter`, `screens-auth.js:69`, `:71`).
/// * Gönderim doğrulamadan dönerse odak ilk hatalı alana taşınır
///   (`screens-auth.js:57`).
/// * Giriş kilitliyse DLG-02 açılır; "Şifremi unuttum" seçilirse AUT-04'e
///   gidilir.
/// * Oturum katmanı hesabı askıda bulduysa (R6 kullanıcıyı buraya getirir)
///   bekleyen DLG-01 bu ekranın üstünde gösterilir (W-03).
/// * Giriş başarılı olunca burada gezinme **yapılmaz**: oturum çözülür ve
///   router yönlendirir (`/login?from=` dönüşü dahil).
mixin LoginViewMixin on KeyboardFocusMixin<LoginView, LoginField> {
  /// Şifre alanının denetleyicisi: başarılı girişte ViewModel şifreyi
  /// temizleyince alan da boşaltılır.
  final TextEditingController passwordController = TextEditingController();

  @override
  List<LoginField> get focusOrder => LoginField.values;

  /// Ekranın ViewModel'i.
  LoginViewModel get viewModel => ref.read(loginViewModelProvider.notifier);

  /// Giriş isteği ya da ardından gelen oturum çözümü sürüyor mu (düğme
  /// meşgul)? Giriş başarılı olduktan sonra kullanıcı belgesi okunurken form
  /// boşta görünmez.
  bool get isBusy =>
      ref.watch(loginViewModelProvider.select((s) => s.isSubmitting)) ||
      ref.watch(sessionViewModelProvider.select((s) => s.isResolving));

  @override
  void initState() {
    super.initState();
    // Askı yönlendirmesiyle (R6) açıldıysa: sayfa yerleştikten sonra.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showSuspendedNotice();
    });
  }

  /// [field] alanında klavye eylem tuşuna basıldı: sonraki alana geçer, son
  /// alanda formu gönderir.
  void onFieldSubmitted(LoginField field) {
    if (!focusNext(field)) unawaited(submit());
  }

  /// Oturum durumu her değiştiğinde bekleyen askı bildirimini gösterir
  /// (ekran açıkken askıya düşen giriş). `build` içinde çağrılır.
  void listenSuspendedNotice() {
    ref.listen(
      sessionViewModelProvider.select((s) => s.status),
      (_, _) => showSuspendedNotice(),
    );
  }

  /// Oturum katmanında bekleyen askı bildirimini (DLG-01) gösterir; bekleyen
  /// bildirim yoksa etkisizdir.
  void showSuspendedNotice() => unawaited(
    ref.read(sessionViewModelProvider.notifier).showPendingSuspendedNotice(),
  );

  /// ViewModel şifreyi temizlediğinde (başarılı giriş, askı) alanı boşaltır.
  /// `build` içinde çağrılır.
  void listenPasswordReset() {
    ref.listen(loginViewModelProvider.select((s) => s.password), (_, next) {
      if (next.isEmpty && passwordController.text.isNotEmpty) {
        passwordController.clear();
      }
    });
  }

  /// Formu gönderir (`AUT-01.login`, klavye eylem tuşu). Kilitliyse DLG-02;
  /// doğrulamadan dönerse odak ilk hatalı alana gider.
  Future<void> submit() async {
    if (ref.read(sessionViewModelProvider).isResolving) return;
    final outcome = await viewModel.submit();
    if (!mounted) return;
    switch (outcome) {
      case LoginOutcome.locked:
        await openLockDialog();
      case LoginOutcome.failed:
        focusFirstError(ref.read(loginViewModelProvider).errors);
      case LoginOutcome.success ||
          LoginOutcome.invalid ||
          LoginOutcome.suspended:
        break;
    }
  }

  /// DLG-02 "Çok fazla deneme"yi açar (kilitli düğmeye dokunma, kilitlenen
  /// gönderim). Kilit yoksa etkisizdir.
  Future<void> openLockDialog() async {
    final lockedUntil = ref.read(loginViewModelProvider).lockedUntil;
    if (lockedUntil == null) return;
    final forgot = await ref
        .read(feedbackServiceProvider)
        .showDialog<bool>(
          DialogId.dlg02,
          builder: (_) => LoginLockDialog(
            lockedUntil: lockedUntil,
            onUnlocked: clearLock,
          ),
        );
    if (!mounted) return;
    if (forgot ?? false) openResetPassword();
  }

  /// Süresi dolan kilidi kaldırır (düğmedeki ve DLG-02'deki geri sayım).
  void clearLock() {
    if (mounted) viewModel.clearLock();
  }

  /// "Şifremi unuttum" (`AUT-01.forgot`, DLG-02) → AUT-04.
  void openResetPassword() {
    // TODO(T-14): `const ResetPasswordRoute().go(context)` — AUT-04 rotası
    // T-14'te doğar (bağlama borcu W-05). O zamana kadar etkisizdir.
  }

  /// "Kayıt ol" (`AUT-01.register`) → AUT-02.
  void openRegister() => const RegisterRoute().go(context);

  /// [field] alanının altında gösterilecek hata metni; hata yoksa `null`.
  /// Hatalı kimlik bilgisi şifre alanında gösterilir (`auth.err.wrong`,
  /// `screens-auth.js:63`).
  String? errorTextOf(
    LoginField field,
    LoginState state,
    AppLocalizations l10n,
  ) {
    final error = state.errors[field];
    if (error == null) {
      final isWrong =
          field == LoginField.password &&
          state.submitError == LoginError.invalidCredential;
      return isWrong ? l10n.authErrWrong : null;
    }
    return switch (error) {
      FormFieldError.required => l10n.authErrRequired,
      FormFieldError.invalidEmail => l10n.authErrEmail,
      FormFieldError.domainNotAllowed => l10n.authErrDomain,
      FormFieldError.passwordWeak => l10n.authErrPassword,
      // Bu formda üretilmeyen türler.
      FormFieldError.tooShort ||
      FormFieldError.tooLong ||
      FormFieldError.passwordMismatch ||
      FormFieldError.consentMissing ||
      FormFieldError.limitExceeded ||
      FormFieldError.invalidFormat ||
      FormFieldError.endBeforeStart ||
      FormFieldError.capacityBelowGoing => null,
    };
  }

  @override
  void dispose() {
    passwordController.dispose();
    super.dispose();
  }
}
