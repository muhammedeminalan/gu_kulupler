import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/auth/provider/verify_email_view_model.dart';
import 'package:gu_kulupler/features/auth/view/mixin/verify_email_view_mixin.dart';
import 'package:gu_kulupler/product/mixin/sign_out_mixin.dart';
import 'package:gu_ui/gu_ui.dart';

/// E-postanı doğrula ekranı — `VerifyEmailRoute` (`/verify`); prototip
/// `Verify` (`screens-auth.js:107–123`).
///
/// Başlık çubuğu yoktur. Yukarıdan aşağıya, ortalı sütun (yatay 24, üst 40,
/// aralık 16): illüstrasyon 160 · "E-postanı doğrula" · "{e-posta} adresine
/// bir doğrulama bağlantısı gönderdik." (adres kalın) · düğmeler (aralık 12):
/// "Doğruladım" · "Tekrar gönder" · "E-postayı değiştir" · "Çıkış yap".
///
/// * "Doğruladım" sunucuya sorar: hâlâ doğrulanmamışsa TST-02; doğrulanmışsa
///   ekran başarı görünümüne geçer (onay işareti + "E-postan doğrulandı",
///   düğmeler kalkar) ve oturum çözülünce router yönlendirir (AUT-05 ya da
///   uygulama kabuğu). Ekran kendisi gezinmez.
/// * "Tekrar gönder" e-postayı yeniden yollar (TST-03) ve 60 sn bekler:
///   düğme "Tekrar gönder ({s} sn)" geri sayımına döner, devre dışı görünür;
///   dokununca TST-X3 kalan süreyi söyler.
/// * "Çıkış yap" ve "E-postayı değiştir" DLG-06 onayıyla oturumu kapatır.
/// * Geri tuşu ekrandan çıkarmaz (PLAN §13.8): tek çıkış yolu "Çıkış yap"tır.
/// * "(Demo) Bağlantıya tıkladım" uygulanmaz (K-02). Üst boşluk gerçek
///   güvenli alandır, alt boşluk güvenli alan + 8 (K-07).
///
/// Davranış `VerifyEmailViewMixin`'dedir.
///
/// Design: AUT-03
class VerifyEmailView extends ConsumerStatefulWidget {
  /// E-postanı doğrula ekranı.
  const VerifyEmailView({super.key});

  @override
  ConsumerState<VerifyEmailView> createState() => _VerifyEmailViewState();
}

class _VerifyEmailViewState extends ConsumerState<VerifyEmailView>
    with SignOutMixin<VerifyEmailView>, VerifyEmailViewMixin {
  /// `screens-auth.js:114` `Illustration size=160` —
  /// `GuSizes.illustrationSizes` (56 · 72 · 80 · 96 · 100 · 140 · 160 · 200)
  /// içindeki AUT-03 değeri.
  static final double _illustrationSize = GuSizes.illustrationSizes[6];

  /// "Tekrar gönder" düğmesi. Bekleme sürerken ([remaining] > 0) "Tekrar
  /// gönder ({s} sn)" yazar, devre dışı görünür ve dokununca TST-X3 gösterir
  /// (`screens-auth.js:119`).
  Widget _resendButton(Duration remaining, {required bool busy}) {
    final l10n = context.l10n;
    final waiting = remaining > Duration.zero;
    return GuButton(
      key: GuKey.action('AUT-03.resend'),
      label: waiting
          ? l10n.authResendIn(GuCountdown.secondsLeft(remaining).toString())
          : l10n.authResend,
      variant: GuButtonVariant.outline,
      full: true,
      loading: busy && !waiting,
      disabled: waiting,
      onPressed: resend,
      onDisabledPressed: resend,
    );
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final state = ref.watch(verifyEmailViewModelProvider);
    final done = state.isVerified;
    final resendAvailableAt = state.resendAvailableAt;
    final description = splitAroundEmail(
      l10n.authVerifyDesc(state.email),
      state.email,
    );
    final body = gu.text.bodyM.copyWith(color: gu.colors.textSecondary);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: gu.colors.bgCanvas,
        body: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: GuInsets.only(
              left: GuSpacing.s24,
              top: GuSpacing.s40,
              right: GuSpacing.s24,
              bottom:
                  GuSpacing.s24 +
                  MediaQuery.paddingOf(context).bottom +
                  GuSizes.screenScrollBottomExtra,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: done
                      ? GuSuccessCheck(semanticLabel: l10n.commonSuccess)
                      : GuIllustration(
                          GuIllustrations.emailVerify,
                          size: _illustrationSize,
                        ),
                ),
                GuGap.v16,
                Semantics(
                  header: true,
                  liveRegion: done,
                  child: Text(
                    done ? l10n.authVerifySuccess : l10n.authVerifyTitle,
                    style: gu.text.titleL,
                    textAlign: TextAlign.center,
                  ),
                ),
                GuGap.v16,
                Text.rich(
                  TextSpan(
                    text: description.before,
                    children: [
                      TextSpan(
                        text: description.email,
                        // `<b>` (`screens-auth.js:116`): gövde metni + etiket
                        // ağırlığı (600; Inter'in en kalın yüklü kesimi).
                        style: body.copyWith(
                          fontWeight: gu.text.labelL.fontWeight,
                        ),
                      ),
                      TextSpan(text: description.after),
                    ],
                  ),
                  style: body,
                  textAlign: TextAlign.center,
                ),
                if (!done) ...[
                  GuGap.v16,
                  // Beklenmeyen hata düğmenin altında gösterilir.
                  GuField(
                    errorText: state.isError ? l10n.sysErrorTitle : null,
                    child: GuButton(
                      key: GuKey.action('AUT-03.confirm'),
                      label: l10n.authVerifyConfirm,
                      size: GuButtonSize.lg,
                      full: true,
                      loading: state.isChecking,
                      onPressed: confirm,
                    ),
                  ),
                  GuGap.v12,
                  if (resendAvailableAt == null)
                    _resendButton(Duration.zero, busy: state.isResending)
                  else
                    GuCountdown(
                      until: resendAvailableAt,
                      now: ref.watch(appClockProvider).nowUtc,
                      onDone: clearResendCooldown,
                      builder: (context, remaining) =>
                          _resendButton(remaining, busy: state.isResending),
                    ),
                  GuGap.v12,
                  GuButton(
                    key: GuKey.action('AUT-03.changeEmail'),
                    label: l10n.authChangeEmail,
                    variant: GuButtonVariant.text,
                    full: true,
                    onPressed: changeEmail,
                  ),
                  GuGap.v12,
                  GuButton(
                    key: GuKey.action('AUT-03.logout'),
                    label: l10n.authLogout,
                    variant: GuButtonVariant.text,
                    full: true,
                    onPressed: logout,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
