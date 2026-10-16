import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/core/constants/app_constants.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/auth/provider/register_state.dart';
import 'package:gu_kulupler/features/auth/provider/register_view_model.dart';
import 'package:gu_kulupler/features/auth/view/mixin/register_view_mixin.dart';
import 'package:gu_kulupler/features/auth/view/widget/register_legal_consent.dart';
import 'package:gu_kulupler/features/auth/view/widget/register_password_strength.dart';
import 'package:gu_kulupler/product/mixin/keyboard_focus_mixin.dart';
import 'package:gu_kulupler/product/navigation/routes/auth_routes.dart';
import 'package:gu_kulupler/product/widget/system/language_menu_button.dart';
import 'package:gu_ui/gu_ui.dart';

/// Kayıt ekranı — `RegisterRoute` (`/login/register`); prototip `Register`
/// (`screens-auth.js:83–104`).
///
/// Çubuk: geri + "Kayıt ol" + dil düğmesi (SHT-01 açılır menü). Form (yatay
/// 16, üst 8, aralık 16): Ad Soyad · üniversite e-postası (yardım metniyle) ·
/// şifre + güç çubuğu + üç kural · şifre tekrar · yasal onay (kutu + AUT-06
/// bağlantıları) · "Hesap oluştur" · "Zaten hesabın var mı? Giriş yap".
///
/// Kayıt başarılı olunca ekran kendisi gezinmez; oturum `unverified` olur ve
/// router AUT-03'e yönlendirir. Davranış `RegisterViewMixin`'dedir. Alt
/// boşluk gerçek güvenli alan + 8'dir (K-07); klavye açıkken içerik kayar.
///
/// Design: AUT-02
class RegisterView extends ConsumerStatefulWidget {
  /// Kayıt ekranı.
  const RegisterView({super.key});

  @override
  ConsumerState<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends ConsumerState<RegisterView>
    with KeyboardFocusMixin<RegisterView, RegisterField>, RegisterViewMixin {
  /// Yasal metni kayıt formundan açar: AUT-06'nın altında "Okudum, anladım"
  /// çubuğu çıkar ve onay kutusunu işaretler (`screens-auth.js:101`, `:154`).
  void _openLegal(LegalTab tab) => unawaited(
    LegalRoute(tip: tab, from: LegalOrigin.register).push<void>(context),
  );

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final state = ref.watch(registerViewModelProvider);
    final bodyS = gu.text.bodyS.copyWith(color: gu.colors.textSecondary);
    final passwordVisible = state.isPasswordVisible;

    return Scaffold(
      backgroundColor: gu.colors.bgCanvas,
      appBar: GuAppBar(
        title: l10n.authRegisterTitle,
        onBack: goBack,
        backSemanticLabel: l10n.a11yBack,
        backActionKey: GuKey.action('AUT-02.back'),
        actions: [LanguageMenuButton(key: GuKey.action('AUT-02.lang'))],
      ),
      body: GuFormScrollView(
        padding: GuInsets.only(
          left: GuSpacing.s16,
          top: GuSpacing.s8,
          right: GuSpacing.s16,
          bottom:
              MediaQuery.paddingOf(context).bottom +
              GuSizes.screenScrollBottomExtra,
        ),
        child: FocusTraversalGroup(
          key: GuKey.action('AUT-02.form'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: GuSpacing.s16,
            children: [
              GuInput(
                actionKey: GuKey.action('AUT-02.name'),
                label: l10n.authFullName,
                icon: GuIcons.user,
                errorText: errorTextOf(RegisterField.name, state, l10n),
                keyboardType: TextInputType.name,
                focusNode: focusNodeOf(RegisterField.name),
                textInputAction: actionFor(RegisterField.name),
                onChanged: viewModel.setName,
                onSubmitted: () => onFieldSubmitted(RegisterField.name),
              ),
              GuInput(
                actionKey: GuKey.action('AUT-02.email'),
                label: l10n.authUniEmail,
                icon: GuIcons.mail,
                placeholder: l10n.authEmailPlaceholder(
                  AppConstants.allowedEmailDomains.first,
                ),
                help: l10n.authRegisterEmailHelp,
                errorText: errorTextOf(RegisterField.email, state, l10n),
                keyboardType: TextInputType.emailAddress,
                focusNode: focusNodeOf(RegisterField.email),
                textInputAction: actionFor(RegisterField.email),
                onChanged: viewModel.setEmail,
                onSubmitted: () => onFieldSubmitted(RegisterField.email),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: GuSpacing.s8,
                children: [
                  GuInput(
                    actionKey: GuKey.action('AUT-02.password'),
                    label: l10n.authPassword,
                    icon: GuIcons.keyRound,
                    obscure: !passwordVisible,
                    errorText: errorTextOf(RegisterField.password, state, l10n),
                    keyboardType: TextInputType.visiblePassword,
                    focusNode: focusNodeOf(RegisterField.password),
                    textInputAction: actionFor(RegisterField.password),
                    onChanged: viewModel.setPassword,
                    onSubmitted: () => onFieldSubmitted(RegisterField.password),
                    trailing: GuIconButton(
                      key: GuKey.action('AUT-02.togglePassword'),
                      icon: passwordVisible ? GuIcons.eyeOff : GuIcons.eye,
                      semanticLabel: passwordVisible
                          ? l10n.authHidePassword
                          : l10n.authShowPassword,
                      size: GuIconButtonSize.sm,
                      onPressed: viewModel.togglePasswordVisibility,
                    ),
                  ),
                  RegisterPasswordStrength(
                    strength: state.passwordStrength,
                    max: RegisterState.passwordStrengthMax,
                    rules: [
                      (met: state.hasMinLength, label: l10n.authRuleLen),
                      (met: state.hasUppercase, label: l10n.authRuleUpper),
                      (met: state.hasDigit, label: l10n.authRuleDigit),
                    ],
                  ),
                ],
              ),
              GuInput(
                actionKey: GuKey.action('AUT-02.password2'),
                label: l10n.authPasswordRepeat,
                icon: GuIcons.keyRound,
                obscure: !passwordVisible,
                errorText: errorTextOf(
                  RegisterField.passwordConfirm,
                  state,
                  l10n,
                ),
                keyboardType: TextInputType.visiblePassword,
                focusNode: focusNodeOf(RegisterField.passwordConfirm),
                textInputAction: actionFor(RegisterField.passwordConfirm),
                onChanged: viewModel.setPasswordConfirm,
                onSubmitted: () =>
                    onFieldSubmitted(RegisterField.passwordConfirm),
              ),
              RegisterLegalConsent(
                key: legalRowKey,
                value: state.acceptedLegal,
                onChanged: (_) => viewModel.toggleLegal(),
                onOpenKvkk: () => _openLegal(LegalTab.kvkk),
                onOpenPrivacy: () => _openLegal(LegalTab.gizlilik),
                checkboxKey: GuKey.action('AUT-02.legalCheck'),
                kvkkKey: GuKey.action('AUT-02.legal'),
                privacyKey: GuKey.action('AUT-02.legalPrivacy'),
                errorText: errorTextOf(RegisterField.legal, state, l10n),
              ),
              // Alana bağlanamayan sunucu hatası düğmenin altında gösterilir.
              GuField(
                errorText: state.submitError == RegisterError.unknown
                    ? l10n.sysErrorTitle
                    : null,
                child: GuButton(
                  key: GuKey.action('AUT-02.submit'),
                  label: l10n.authRegisterSubmit,
                  size: GuButtonSize.lg,
                  full: true,
                  loading: state.isSubmitting,
                  onPressed: () => unawaited(submit()),
                ),
              ),
              GuActionSurface(
                key: GuKey.action('AUT-02.toLogin'),
                onTap: goToLogin,
                borderRadius: GuRadius.borderHandle,
                builder: (context, pressed) => Text.rich(
                  TextSpan(
                    text: '${l10n.authHaveAccount} ',
                    children: [
                      TextSpan(
                        text: l10n.authLoginCta,
                        // `.c-brand.bold` (css:98–99): gövde metni + etiket
                        // ağırlığı (600).
                        style: bodyS.copyWith(
                          color: gu.colors.brandPrimaryText,
                          fontWeight: gu.text.labelL.fontWeight,
                        ),
                      ),
                    ],
                  ),
                  style: bodyS,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
