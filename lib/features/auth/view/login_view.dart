import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/core/constants/app_constants.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/auth/provider/login_state.dart';
import 'package:gu_kulupler/features/auth/provider/login_view_model.dart';
import 'package:gu_kulupler/features/auth/view/mixin/login_view_mixin.dart';
import 'package:gu_kulupler/features/auth/view/widget/login_form_shake.dart';
import 'package:gu_kulupler/product/mixin/keyboard_focus_mixin.dart';
import 'package:gu_kulupler/product/navigation/routes/auth_routes.dart';
import 'package:gu_kulupler/product/widget/system/language_menu_button.dart';
import 'package:gu_ui/gu_ui.dart';

/// Giriş ekranı — `LoginRoute` (`/login?from=`); prototip `Login`
/// (`screens-auth.js:54–79`).
///
/// Yukarıdan aşağıya: dil düğmesi (sağ üst, SHT-01 açılır menü) · logo 72 +
/// "Hoş geldin" + slogan · form (yatay 16, aralık 16): e-posta · şifre
/// (göster / gizle) · "Şifremi unuttum" · "Giriş yap" · "Hesabın yok mu?
/// Kayıt ol" · yasal metin cümlesi (AUT-06 bağlantıları).
///
/// * Hatalı girişte form sallanır, şifre alanında "E-posta veya şifre hatalı"
///   görünür (TST-01 ViewModel'den). 5. hatada giriş kilitlenir: düğme
///   "{s} sn kilitli" geri sayımına döner, dokununca DLG-02 açılır.
/// * Giriş başarılı olunca ekran kendisi gezinmez: oturum çözülür ve router
///   yönlendirir (`from` dönüş adresi yoldan okunur, R7). Oturum çözülürken
///   düğme meşgul kalır.
/// * Demo hesap bölümü uygulanmaz (K-02). Üst boşluk gerçek güvenli alandır,
///   alt boşluk güvenli alan + 8 (K-07); klavye açıkken içerik kayar.
///
/// Davranış `LoginViewMixin`'dedir.
///
/// Design: AUT-01
class LoginView extends ConsumerStatefulWidget {
  /// Giriş ekranı.
  const LoginView({super.key});

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView>
    with KeyboardFocusMixin<LoginView, LoginField>, LoginViewMixin {
  /// `screens-auth.js:68` `Logo size=72` — `GuSizes.logoSizes` (20 · 72 · 80 ·
  /// 96) içindeki AUT-01 değeri.
  static final double _logoSize = GuSizes.logoSizes[1];

  void _openLegal(LegalTab tab) =>
      unawaited(LegalRoute(tip: tab).push<void>(context));

  /// "Giriş yap" düğmesi. Kilit sürerken ([remaining] > 0) "{s} sn kilitli"
  /// yazar, devre dışı görünür ve dokununca DLG-02'yi açar
  /// (`screens-auth.js:73`).
  Widget _loginButton(Duration remaining, {required bool busy}) {
    final l10n = context.l10n;
    final locked = remaining > Duration.zero;
    return GuButton(
      key: GuKey.action('AUT-01.login'),
      label: locked
          ? l10n.authLockedFor(GuCountdown.secondsLeft(remaining).toString())
          : l10n.authLoginCta,
      size: GuButtonSize.lg,
      full: true,
      loading: busy && !locked,
      disabled: locked,
      onPressed: () => unawaited(submit()),
      onDisabledPressed: () => unawaited(openLockDialog()),
    );
  }

  @override
  Widget build(BuildContext context) {
    listenPasswordReset();
    listenSuspendedNotice();
    final gu = context.gu;
    final l10n = context.l10n;
    final state = ref.watch(loginViewModelProvider);
    final busy = isBusy;
    final passwordVisible = state.isPasswordVisible;
    final lockedUntil = state.lockedUntil;
    final bodyS = gu.text.bodyS.copyWith(color: gu.colors.textSecondary);

    return Scaffold(
      backgroundColor: gu.colors.bgCanvas,
      body: SafeArea(
        bottom: false,
        child: GuFormScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: GuInsets.only(
                  left: GuSpacing.s8,
                  top: GuSpacing.s4,
                  right: GuSpacing.s8,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: LanguageMenuButton(
                    key: GuKey.action('AUT-01.lang'),
                    chevron: true,
                  ),
                ),
              ),
              Padding(
                padding: GuInsets.only(
                  left: GuSpacing.s24,
                  top: GuSpacing.s8,
                  right: GuSpacing.s24,
                  bottom: GuSpacing.s24,
                ),
                child: Column(
                  children: [
                    GuLogo(size: _logoSize),
                    // `.col.gap8`; başlıktaki `.mt8`, `.gu-root h1{margin:0}`
                    // (css:83) karşısında etkisizdir.
                    GuGap.v8,
                    Text(
                      l10n.authLoginWelcome,
                      style: gu.text.display,
                      textAlign: TextAlign.center,
                    ),
                    GuGap.v8,
                    Text(
                      l10n.appTagline,
                      style: gu.text.bodyM.copyWith(
                        color: gu.colors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              LoginFormShake(
                trigger: state.failedAttempts,
                child: Padding(
                  padding: GuInsets.h16,
                  // Ortalı sütun: "Kayıt ol" satırı metni kadar yer kaplar ve
                  // dokunma alanı sütunun içinde kalır (K-03).
                  child: Column(
                    children: [
                      FocusTraversalGroup(
                        key: GuKey.action('AUT-01.form'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            GuInput(
                              actionKey: GuKey.action('AUT-01.email'),
                              label: l10n.authEmail,
                              icon: GuIcons.mail,
                              placeholder: l10n.authEmailPlaceholder(
                                AppConstants.allowedEmailDomains.first,
                              ),
                              errorText: errorTextOf(
                                LoginField.email,
                                state,
                                l10n,
                              ),
                              keyboardType: TextInputType.emailAddress,
                              focusNode: focusNodeOf(LoginField.email),
                              textInputAction: actionFor(LoginField.email),
                              onChanged: viewModel.setEmail,
                              onSubmitted: () =>
                                  onFieldSubmitted(LoginField.email),
                            ),
                            GuGap.v16,
                            GuInput(
                              actionKey: GuKey.action('AUT-01.password'),
                              controller: passwordController,
                              label: l10n.authPassword,
                              icon: GuIcons.keyRound,
                              obscure: !passwordVisible,
                              errorText: errorTextOf(
                                LoginField.password,
                                state,
                                l10n,
                              ),
                              keyboardType: TextInputType.visiblePassword,
                              focusNode: focusNodeOf(LoginField.password),
                              textInputAction: actionFor(LoginField.password),
                              onChanged: viewModel.setPassword,
                              onSubmitted: () =>
                                  onFieldSubmitted(LoginField.password),
                              trailing: GuIconButton(
                                key: GuKey.action('AUT-01.togglePassword'),
                                icon: passwordVisible
                                    ? GuIcons.eyeOff
                                    : GuIcons.eye,
                                semanticLabel: passwordVisible
                                    ? l10n.authHidePassword
                                    : l10n.authShowPassword,
                                size: GuIconButtonSize.sm,
                                onPressed: viewModel.togglePasswordVisibility,
                              ),
                            ),
                            // `.row.end` `margin-top:-8px`: 16 − 8.
                            GuGap.v8,
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: GuButton(
                                key: GuKey.action('AUT-01.forgot'),
                                label: l10n.authForgot,
                                variant: GuButtonVariant.text,
                                size: GuButtonSize.sm,
                                onPressed: openResetPassword,
                              ),
                            ),
                            GuGap.v16,
                            // Alana bağlanamayan hata düğmenin altında
                            // gösterilir.
                            GuField(
                              errorText: state.submitError == LoginError.unknown
                                  ? l10n.sysErrorTitle
                                  : null,
                              child: lockedUntil == null
                                  ? _loginButton(Duration.zero, busy: busy)
                                  : GuCountdown(
                                      until: lockedUntil,
                                      now: ref.watch(appClockProvider).nowUtc,
                                      onDone: clearLock,
                                      builder: (context, remaining) =>
                                          _loginButton(remaining, busy: busy),
                                    ),
                            ),
                          ],
                        ),
                      ),
                      GuGap.v16,
                      GuActionSurface(
                        key: GuKey.action('AUT-01.register'),
                        onTap: openRegister,
                        borderRadius: GuRadius.borderHandle,
                        builder: (context, pressed) => Text.rich(
                          TextSpan(
                            text: '${l10n.authNoAccount} ',
                            children: [
                              TextSpan(
                                text: l10n.authRegisterCta,
                                // `.c-brand.bold` (css:98–99): gövde metni +
                                // etiket ağırlığı (600).
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
                      // Yasal metnin üst boşluğunun (24) ilk 16'sı: "Kayıt ol"
                      // satırının dokunma alanı bu sütunda kalsın diye burada.
                      GuGap.v16,
                    ],
                  ),
                ),
              ),
              // "Devam ederek Kullanım Koşulları ve Gizlilik Politikası'nı
              // kabul etmiş olursun." (`screens-auth.js:78`; `p.t-caption
              // .center`).
              GuLinkText(
                style: gu.text.caption,
                textAlign: TextAlign.center,
                padding: GuInsets.only(
                  left: GuSpacing.s24,
                  top: GuSpacing.s8,
                  right: GuSpacing.s24,
                  bottom:
                      GuSpacing.s8 +
                      MediaQuery.paddingOf(context).bottom +
                      GuSizes.screenScrollBottomExtra,
                ),
                spans: [
                  GuLinkSpan.text('${l10n.authLegalPrefix} '),
                  GuLinkSpan.link(
                    l10n.legalKosullarTitle,
                    actionKey: GuKey.action('AUT-01.terms'),
                    onTap: () => _openLegal(LegalTab.kosullar),
                  ),
                  GuLinkSpan.text(' ${l10n.commonAnd} '),
                  GuLinkSpan.link(
                    l10n.legalGizlilikTitle,
                    actionKey: GuKey.action('AUT-01.privacy'),
                    onTap: () => _openLegal(LegalTab.gizlilik),
                  ),
                  // Ek, bağlantıya bitişik yazılır ("…Politikası'nı",
                  // "…Policy.").
                  GuLinkSpan.text(l10n.authLegalSuffix),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
