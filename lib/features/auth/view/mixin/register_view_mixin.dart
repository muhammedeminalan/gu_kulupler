import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/auth/provider/register_state.dart';
import 'package:gu_kulupler/features/auth/provider/register_view_model.dart';
import 'package:gu_kulupler/features/auth/view/register_view.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/mixin/keyboard_focus_mixin.dart';
import 'package:gu_kulupler/product/navigation/routes/auth_routes.dart';
import 'package:gu_ui/gu_ui.dart';

/// AUT-02 davranışı: odak sırası, gönderim, hata metni eşlemesi ve gezinme.
///
/// * Klavye eylem tuşu sıradaki metin alanına geçer; son alanda (şifre
///   tekrar) formu gönderir (prototip `form onSubmit`, `screens-auth.js:94`).
/// * Gönderim reddedilirse odak ilk hatalı alana taşınır
///   (`screens-auth.js:89`); hatalı alan onay kutusuysa klavye kapanır ve
///   satır görünür alana kaydırılır.
/// * Kayıt başarılı olunca burada gezinme **yapılmaz**: oturum `unverified`
///   olur, router AUT-03'e yönlendirir.
mixin RegisterViewMixin on KeyboardFocusMixin<RegisterView, RegisterField> {
  /// Yasal onay satırının yeri (hatada görünür alana kaydırmak için).
  final GlobalKey legalRowKey = GlobalKey(debugLabel: 'register.legal');

  /// Klavyeyle sırayla gezilen metin alanları (onay kutusu sırada değildir).
  @override
  List<RegisterField> get focusOrder => const [
    RegisterField.name,
    RegisterField.email,
    RegisterField.password,
    RegisterField.passwordConfirm,
  ];

  /// Ekranın ViewModel'i.
  RegisterViewModel get viewModel =>
      ref.read(registerViewModelProvider.notifier);

  /// [field] alanında klavye eylem tuşuna basıldı: sonraki alana geçer, son
  /// alanda formu gönderir.
  void onFieldSubmitted(RegisterField field) {
    if (!focusNext(field)) unawaited(submit());
  }

  /// Formu gönderir; reddedilirse odağı ilk hatalı alana taşır.
  Future<void> submit() async {
    final outcome = await viewModel.submit();
    if (!mounted) return;
    if (outcome == RegisterOutcome.invalid ||
        outcome == RegisterOutcome.failed) {
      _focusFirstInvalid();
    }
  }

  void _focusFirstInvalid() {
    final field = ref.read(registerViewModelProvider).firstInvalidField;
    if (field == null) return;
    if (field != RegisterField.legal) {
      focusNodeOf(field).requestFocus();
      return;
    }
    unfocusAll();
    final legalContext = legalRowKey.currentContext;
    if (legalContext == null) return;
    unawaited(
      Scrollable.ensureVisible(
        legalContext,
        duration: context.gu.duration(GuMotion.base),
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      ),
    );
  }

  /// [field] alanının altında gösterilecek hata metni; hata yoksa `null`.
  String? errorTextOf(
    RegisterField field,
    RegisterState state,
    AppLocalizations l10n,
  ) {
    if (field == RegisterField.email &&
        state.submitError == RegisterError.emailInUse) {
      return l10n.authErrExists;
    }
    return switch (state.errors[field]) {
      null => null,
      FormFieldError.required => l10n.authErrRequired,
      FormFieldError.tooShort || FormFieldError.tooLong =>
        l10n.authErrNameLength(Limits.nameMin, Limits.nameMax),
      FormFieldError.invalidEmail => l10n.authErrEmail,
      FormFieldError.domainNotAllowed => l10n.authErrDomain,
      FormFieldError.passwordWeak => l10n.authErrPassword,
      FormFieldError.passwordMismatch => l10n.authErrMismatch,
      FormFieldError.consentMissing => l10n.authErrLegal,
      // Bu formda üretilmeyen türler.
      FormFieldError.limitExceeded ||
      FormFieldError.invalidFormat ||
      FormFieldError.endBeforeStart ||
      FormFieldError.capacityBelowGoing => null,
    };
  }

  /// Geri: AUT-01'e döner (prototip `nav.back()`).
  void goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      goToLogin();
    }
  }

  /// "Giriş yap": AUT-01 (prototip `nav.resetTo('AUT-01')`).
  void goToLogin() => const LoginRoute().go(context);
}
