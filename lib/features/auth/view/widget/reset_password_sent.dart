import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_ui/gu_ui.dart';

/// AUT-04 "Gelen kutunu kontrol et" görünümü — bağlantı istendikten sonra
/// formun yerini alır (prototip `f.sent`, `screens-auth.js:130`).
///
/// Ortalı sütun (üst 24, aralık 12): başarı işareti 96 · başlık · "{email}
/// adresine bir bağlantı gönderdik (kayıtlıysa)." · "Girişe dön" (tam
/// genişlik) · "Tekrar gönder".
///
/// "Tekrar gönder" [resendAvailableAt] anına kadar "Tekrar gönder ({s} sn)"
/// yazar ve devre dışı görünür; o hâlde dokunmak da [onResend]'i çağırır
/// (TST-X3'ü ViewModel gösterir).
class ResetPasswordSent extends ConsumerWidget {
  /// Gönderildi görünümü.
  const ResetPasswordSent({
    required this.email,
    required this.resendAvailableAt,
    required this.isResending,
    required this.onToLogin,
    required this.onResend,
    this.errorText,
    super.key,
  });

  /// Bağlantının gönderildiği adres.
  final String email;

  /// Yeniden gönderimin açılacağı an (UTC); bekleme yoksa `null`.
  final DateTime? resendAvailableAt;

  /// Yeniden gönderim isteği sürüyor mu (düğme meşgul)?
  final bool isResending;

  /// "Girişe dön" (`AUT-04.toLogin`).
  final VoidCallback onToLogin;

  /// "Tekrar gönder" (`AUT-04.resend`); bekleme sürerken de çağrılır.
  final VoidCallback onResend;

  /// Yeniden gönderimin alana bağlanamayan hatası ("Tekrar gönder"in
  /// altında); yoksa `null`.
  final String? errorText;

  Widget _resendButton(BuildContext context, Duration remaining) {
    final l10n = context.l10n;
    final waiting = remaining > Duration.zero;
    return GuButton(
      key: GuKey.action('AUT-04.resend'),
      label: waiting
          ? l10n.authResendIn(GuCountdown.secondsLeft(remaining).toString())
          : l10n.authResend,
      variant: GuButtonVariant.text,
      loading: isResending && !waiting,
      disabled: waiting,
      onPressed: onResend,
      onDisabledPressed: onResend,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gu = context.gu;
    final l10n = context.l10n;
    final availableAt = resendAvailableAt;

    return Padding(
      padding: GuInsets.only(top: GuSpacing.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: GuSpacing.s12,
        children: [
          Center(child: GuSuccessCheck(semanticLabel: l10n.commonSuccess)),
          Semantics(
            header: true,
            child: Text(
              l10n.authResetSentTitle,
              style: gu.text.titleM,
              textAlign: TextAlign.center,
            ),
          ),
          Text(
            l10n.authResetSentDesc(email),
            style: gu.text.bodyM.copyWith(color: gu.colors.textSecondary),
            textAlign: TextAlign.center,
          ),
          GuButton(
            key: GuKey.action('AUT-04.toLogin'),
            label: l10n.authResetToLogin,
            size: GuButtonSize.lg,
            full: true,
            onPressed: onToLogin,
          ),
          GuField(
            errorText: errorText,
            child: Center(
              child: availableAt == null
                  ? _resendButton(context, Duration.zero)
                  : GuCountdown(
                      until: availableAt,
                      now: ref.watch(appClockProvider).nowUtc,
                      builder: _resendButton,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
