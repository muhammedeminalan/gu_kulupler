import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/features/auth/provider/reset_password_state.dart';
import 'package:gu_kulupler/features/auth/provider/reset_password_view_model.dart';
import 'package:gu_kulupler/features/auth/view/reset_password_view.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/mixin/keyboard_focus_mixin.dart';
import 'package:gu_kulupler/product/navigation/routes/auth_routes.dart';

/// AUT-04 davranışı: gönderim, yeniden gönderim, hata metni eşlemesi ve
/// gezinme.
///
/// * Klavye eylem tuşu formu gönderir (prototip `Input onEnter`,
///   `screens-auth.js:131`).
/// * Gönderim reddedilirse (doğrulama ya da sunucunun adres hatası) odak
///   e-posta alanına döner.
/// * "Tekrar gönder" bekleme sürerken de ViewModel'e gider: TST-X3'ü o
///   gösterir (prototip `onDisabledClick`, `screens-auth.js:130`).
mixin ResetPasswordViewMixin
    on KeyboardFocusMixin<ResetPasswordView, ResetField> {
  @override
  List<ResetField> get focusOrder => ResetField.values;

  /// Ekranın ViewModel'i.
  ResetPasswordViewModel get viewModel =>
      ref.read(resetPasswordViewModelProvider.notifier);

  /// Formu gönderir (`AUT-04.send`, klavye eylem tuşu); reddedilirse odağı
  /// e-posta alanına taşır.
  Future<void> submit() async {
    await viewModel.submit();
    if (!mounted) return;
    focusFirstError(ref.read(resetPasswordViewModelProvider).errors);
  }

  /// "Tekrar gönder" (`AUT-04.resend`; bekleme sürerken de çağrılır).
  void resend() => unawaited(viewModel.resend());

  /// E-posta alanının altında gösterilecek hata metni; hata yoksa `null`.
  String? emailErrorText(ResetPasswordState state, AppLocalizations l10n) =>
      switch (state.errors[ResetField.email]) {
        null => null,
        FormFieldError.required => l10n.authErrRequired,
        FormFieldError.invalidEmail => l10n.authErrEmail,
        FormFieldError.domainNotAllowed => l10n.authErrDomain,
        // Bu formda üretilmeyen türler.
        FormFieldError.tooShort ||
        FormFieldError.tooLong ||
        FormFieldError.passwordWeak ||
        FormFieldError.passwordMismatch ||
        FormFieldError.consentMissing ||
        FormFieldError.limitExceeded ||
        FormFieldError.invalidFormat ||
        FormFieldError.endBeforeStart ||
        FormFieldError.capacityBelowGoing => null,
      };

  /// Alana bağlanamayan gönderim hatasının metni (düğmenin altında); ağ
  /// hatası toast ile bildirildiği için satır içi gösterilmez.
  String? submitErrorText(ResetPasswordState state, AppLocalizations l10n) =>
      state.submitError == SubmitError.unknown ? l10n.sysErrorTitle : null;

  /// Geri (`AUT-04.back`): AUT-01'e döner (prototip `nav.back()`).
  void goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      goToLogin();
    }
  }

  /// "Girişe dön" (`AUT-04.toLogin`): AUT-01 (prototip
  /// `nav.resetTo('AUT-01')`).
  void goToLogin() => const LoginRoute().go(context);
}
