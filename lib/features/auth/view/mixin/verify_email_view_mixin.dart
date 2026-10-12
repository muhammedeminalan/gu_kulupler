import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/features/auth/provider/verify_email_view_model.dart';
import 'package:gu_kulupler/features/auth/view/verify_email_view.dart';
import 'package:gu_kulupler/product/mixin/sign_out_mixin.dart';

/// AUT-03 davranışı: denetim, yeniden gönderme, beklemenin kalkması, çıkış ve
/// açıklama cümlesinin parçalanması.
///
/// * "Doğruladım" ve "Tekrar gönder" ViewModel'e gider; geri bildirim (TST-02,
///   TST-03, TST-X3, TST-24) oradan gösterilir.
/// * "Çıkış yap" ve "E-postayı değiştir" DLG-06 onayıyla oturumu kapatır
///   (`SignOutMixin`). E-posta/şifre hesabının adresi doğrulanmadan
///   değiştirilemez: yanlış adresle kayıt olan kullanıcı çıkış yapıp doğru
///   adresle yeniden kayıt olur.
/// * Ekran kendisi gezinmez: doğrulama ve çıkış sonrasında router yönlendirir.
mixin VerifyEmailViewMixin
    on ConsumerState<VerifyEmailView>, SignOutMixin<VerifyEmailView> {
  /// Ekranın ViewModel'i.
  VerifyEmailViewModel get viewModel =>
      ref.read(verifyEmailViewModelProvider.notifier);

  /// "Doğruladım" (`AUT-03.confirm`).
  void confirm() => unawaited(viewModel.checkVerified());

  /// "Tekrar gönder" (`AUT-03.resend`); bekleme sürerken (düğme devre dışı)
  /// dokunuş kalan süreyi söyleyen TST-X3'e gider.
  void resend() => unawaited(viewModel.resend());

  /// Süresi dolan beklemeyi kaldırır (düğmedeki geri sayım bitince).
  void clearResendCooldown() {
    if (mounted) viewModel.clearResendCooldown();
  }

  /// "E-postayı değiştir" (`AUT-03.changeEmail`) → DLG-06 → çıkış.
  void changeEmail() => unawaited(confirmSignOut());

  /// "Çıkış yap" (`AUT-03.logout`) → DLG-06 → çıkış.
  void logout() => unawaited(confirmSignOut());

  /// [sentence] cümlesini [email] adresinin çevresinden üçe böler: adresin
  /// öncesi, adres (kalın yazılır) ve sonrası. Adres cümlede yoksa cümle tek
  /// parçadır.
  ({String before, String email, String after}) splitAroundEmail(
    String sentence,
    String email,
  ) {
    final start = email.isEmpty ? -1 : sentence.indexOf(email);
    if (start < 0) return (before: sentence, email: '', after: '');
    return (
      before: sentence.substring(0, start),
      email: email,
      after: sentence.substring(start + email.length),
    );
  }
}
