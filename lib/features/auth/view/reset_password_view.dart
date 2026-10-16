import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/auth/provider/reset_password_state.dart';
import 'package:gu_kulupler/features/auth/provider/reset_password_view_model.dart';
import 'package:gu_kulupler/features/auth/view/mixin/reset_password_view_mixin.dart';
import 'package:gu_kulupler/features/auth/view/widget/reset_password_sent.dart';
import 'package:gu_kulupler/product/mixin/keyboard_focus_mixin.dart';
import 'package:gu_ui/gu_ui.dart';

/// Şifre sıfırlama ekranı — `ResetPasswordRoute` (`/login/reset`); prototip
/// `Reset` (`screens-auth.js:126–131`).
///
/// Çubuk: geri + "Şifre sıfırlama". Gövde (yatay 16, üst 16, aralık 16) iki
/// görünümden biridir:
///
/// * **Form:** açıklama · üniversite e-postası (açılışta odakta) · "Bağlantı
///   gönder". Klavye eylem tuşu da gönderir.
/// * **Gönderildi** (`ResetPasswordSent`): başarı işareti · "Gelen kutunu
///   kontrol et" · adres · "Girişe dön" · "Tekrar gönder" (60 sn geri sayım).
///
/// Adresin kayıtlı olup olmadığı belli edilmez: geçerli her adres aynı
/// "gönderildi" görünümüne geçer. Davranış `ResetPasswordViewMixin`'dedir.
/// Alt boşluk gerçek güvenli alan + 8'dir (K-07); klavye açıkken içerik
/// kayar.
///
/// Design: AUT-04
class ResetPasswordView extends ConsumerStatefulWidget {
  /// Şifre sıfırlama ekranı.
  const ResetPasswordView({super.key});

  @override
  ConsumerState<ResetPasswordView> createState() => _ResetPasswordViewState();
}

class _ResetPasswordViewState extends ConsumerState<ResetPasswordView>
    with
        KeyboardFocusMixin<ResetPasswordView, ResetField>,
        ResetPasswordViewMixin {
  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final state = ref.watch(resetPasswordViewModelProvider);

    return Scaffold(
      backgroundColor: gu.colors.bgCanvas,
      appBar: GuAppBar(
        title: l10n.authResetTitle,
        onBack: goBack,
        backSemanticLabel: l10n.a11yBack,
        backActionKey: GuKey.action('AUT-04.back'),
      ),
      body: GuFormScrollView(
        padding: GuInsets.only(
          left: GuSpacing.s16,
          top: GuSpacing.s16,
          right: GuSpacing.s16,
          bottom:
              MediaQuery.paddingOf(context).bottom +
              GuSizes.screenScrollBottomExtra,
        ),
        child: state.isSent
            ? ResetPasswordSent(
                email: state.sentEmail,
                resendAvailableAt: state.resendAvailableAt,
                isResending: state.isSubmitting,
                errorText: submitErrorText(state, l10n),
                onToLogin: goToLogin,
                onResend: resend,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: GuSpacing.s16,
                children: [
                  Text(
                    l10n.authResetDesc,
                    style: gu.text.bodyM.copyWith(
                      color: gu.colors.textSecondary,
                    ),
                  ),
                  GuInput(
                    actionKey: GuKey.action('AUT-04.email'),
                    label: l10n.authUniEmail,
                    icon: GuIcons.mail,
                    errorText: emailErrorText(state, l10n),
                    keyboardType: TextInputType.emailAddress,
                    autofocus: true,
                    focusNode: focusNodeOf(ResetField.email),
                    textInputAction: actionFor(ResetField.email),
                    onChanged: viewModel.setEmail,
                    onSubmitted: () => unawaited(submit()),
                  ),
                  // Alana bağlanamayan hata düğmenin altında gösterilir.
                  GuField(
                    errorText: submitErrorText(state, l10n),
                    child: GuButton(
                      key: GuKey.action('AUT-04.send'),
                      label: l10n.authResetSend,
                      size: GuButtonSize.lg,
                      full: true,
                      loading: state.isSubmitting,
                      onPressed: () => unawaited(submit()),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
