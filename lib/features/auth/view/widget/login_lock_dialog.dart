import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_ui/gu_ui.dart';

/// DLG-02 "Çok fazla deneme" — giriş kilidi geri sayımı (`dialogs.js:20`).
///
/// Gövde her saniye güncellenir: kilit sürerken "… {s} saniye kilitledik",
/// süre dolunca "Kilit kalktı, tekrar deneyebilirsin." (dialog açık kalır;
/// [onUnlocked] bir kez çağrılır — kilit durumunu ViewModel temizler).
///
/// Özel gövdeli olduğu için katalogdan değil kurucuyla açılır:
///
/// ```dart
/// final forgot = await ref.read(feedbackServiceProvider).showDialog<bool>(
///   DialogId.dlg02,
///   builder: (_) => LoginLockDialog(lockedUntil: lockedUntil),
/// );
/// ```
///
/// Sonuç: `true` → "Şifremi unuttum" (çağıran AUT-04'e gider), `false` →
/// "Tamam", `null` → scrim / geri. Saat `appClockProvider`'dan okunur.
///
/// Design: DLG-02
class LoginLockDialog extends ConsumerWidget {
  /// [lockedUntil] kilidin açılacağı andır (`LoginState.lockedUntil`).
  const LoginLockDialog({
    required this.lockedUntil,
    this.onUnlocked,
    super.key,
  });

  /// Kilidin açılacağı an.
  final DateTime lockedUntil;

  /// Süre dolduğunda bir kez çağrılır.
  final VoidCallback? onUnlocked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return GuCountdown(
      until: lockedUntil,
      now: ref.watch(appClockProvider).nowUtc,
      onDone: onUnlocked,
      builder: (context, remaining) => GuDialogFrame(
        title: l10n.dlg02Title,
        body: remaining > Duration.zero
            ? l10n.dlg02Body(GuCountdown.secondsLeft(remaining).toString())
            : l10n.dlg02Unlocked,
        icon: GuIcons.lock,
        actions: [
          GuButton(
            key: GuKey.action('DLG-02.ok'),
            label: l10n.commonOk,
            onPressed: () => context.pop(false),
          ),
          GuButton(
            key: GuKey.action('DLG-02.forgot'),
            label: l10n.authForgot,
            variant: GuButtonVariant.text,
            onPressed: () => context.pop(true),
          ),
        ],
      ),
    );
  }
}
