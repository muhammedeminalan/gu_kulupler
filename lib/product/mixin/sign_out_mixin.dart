import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';

/// [SignOutMixin.confirmSignOut] sonucu.
enum SignOutOutcome {
  /// Kullanıcı vazgeçti ("Vazgeç", scrim, geri); oturum açık.
  cancelled,

  /// Oturum kapandı; yönlendirme router'dadır (`AppRedirect` → AUT-01).
  signedOut,

  /// Onaylandı ama oturum kapatılamadı; oturum açık kalır (hata günlükte).
  failed,
}

/// Onaylı çıkış — DLG-06 "Çıkış yapılsın mı?" → `SessionViewModel.signOut()`
/// (`dialogs.js:21`; `AUT-03.logout` `screens-auth.js:121`, `SET-01.logout`
/// `screens-profile.js:69`).
///
/// Çıkış düğmesi olan her ekran aynı akışı bu mixin ile çalıştırır:
///
/// ```dart
/// GuButton(
///   key: GuKey.action('AUT-03.logout'),
///   label: context.l10n.authLogout,
///   variant: GuButtonVariant.text,
///   onPressed: confirmSignOut,
/// )
/// ```
///
/// Ekran yönlendirme yapmaz: oturum kapanınca router kullanıcıyı giriş
/// ekranına taşır (CLAUDE.md §5).
///
/// Design: DLG-06
mixin SignOutMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  bool _isSigningOut = false;

  /// DLG-06'yı gösterir; "Çıkış yap" seçilirse oturumu kapatır.
  ///
  /// Süren bir çıkış akışı varken (dialog açık ya da oturum kapanıyor)
  /// ikinci çağrı etkisizdir ve [SignOutOutcome.cancelled] döner.
  Future<SignOutOutcome> confirmSignOut() async {
    if (_isSigningOut) return SignOutOutcome.cancelled;
    _isSigningOut = true;
    try {
      // Dialog kapandıktan sonra ekran sökülmüş olabilir: okumalar önce.
      final session = ref.read(sessionViewModelProvider.notifier);
      final confirmed = await ref
          .read(feedbackServiceProvider)
          .showDialog<bool>(DialogId.dlg06);
      if (!(confirmed ?? false)) return SignOutOutcome.cancelled;
      return await session.signOut()
          ? SignOutOutcome.signedOut
          : SignOutOutcome.failed;
    } finally {
      _isSigningOut = false;
    }
  }
}
