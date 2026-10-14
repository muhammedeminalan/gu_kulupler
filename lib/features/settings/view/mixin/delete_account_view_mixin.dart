import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/settings/provider/delete_account_state.dart';
import 'package:gu_kulupler/features/settings/provider/delete_account_view_model.dart';
import 'package:gu_kulupler/features/settings/view/delete_account_view.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';

/// SET-03 davranışı (`screens-profile.js:80–92`): adım gezintisi, girdi
/// denetleyicileri ve hata metni eşlemesi.
///
/// * Geri (`SET-03.back`) ve sistem geri tuşu: 2. / 3. adımda önceki adıma
///   döner; 1. adımda ekran kapanır (yığında önceki sayfa yoksa SET-01).
///   Silme sürerken geri etkisizdir.
/// * Girdiler (neden metni, şifre, onay sözcüğü) adım değişince yeniden
///   kurulur; denetleyiciler bu durumda yaşar, değer kaybolmaz.
/// * Silme bitince burada gezinme **yapılmaz**: oturum kapanır, router giriş
///   ekranına (AUT-01) taşır; TST-22 ViewModel'dedir.
/// * "Devret" (`SET-03.transfer.<clubId>`) → SHT-25 → DLG-21 başkanlık devri
///   bu ekranda açılır (W-34; ViewModel); devirden sonra engel yeniden
///   denetlenir ve akış kaldığı adımdan sürer.
mixin DeleteAccountViewMixin on ConsumerState<DeleteAccountView> {
  /// Ekranın ViewModel'i.
  DeleteAccountViewModel get viewModel =>
      ref.read(deleteAccountViewModelProvider.notifier);

  /// 2. adımın serbest metni (`SET-03.reasonText`).
  final TextEditingController reasonController = TextEditingController();

  /// 3. adımın şifresi (`SET-03.password`).
  final TextEditingController passwordController = TextEditingController();

  /// 3. adımın onay sözcüğü (`SET-03.confirmWord`).
  final TextEditingController confirmWordController = TextEditingController();

  @override
  void dispose() {
    reasonController.dispose();
    passwordController.dispose();
    confirmWordController.dispose();
    super.dispose();
  }

  /// Geri: önceki adım ya da ekranı kapatma.
  void back() {
    if (viewModel.back()) return;
    context.canPop() ? context.pop() : const SettingsRoute().go(context);
  }

  /// Sistem geri hareketi ([PopScope]): 1. adımda değilse adım geri gider.
  void onPopInvoked(bool didPop) {
    if (didPop) return;
    back();
  }

  /// "Devam" (`SET-03.next`); başkanlık engeli ve TST-X10 ViewModel'dedir.
  void next() => viewModel.next();

  /// "Devret" (`SET-03.transfer.<clubId>`) → SHT-25 → DLG-21 (W-34).
  void transfer(String clubId) => unawaited(viewModel.transfer(clubId));

  /// "Hesabımı kalıcı olarak sil" (`SET-03.confirm`).
  void confirm() => unawaited(viewModel.confirm(context.l10n.set03ConfirmWord));

  /// Kapalı onay düğmesine dokunma → TST-X11.
  void onConfirmDisabled() => viewModel.validate(context.l10n.set03ConfirmWord);

  /// Şifre alanının hata metni; yoksa `null`.
  String? passwordErrorOf(DeleteAccountState state, AppLocalizations l10n) =>
      state.submitError == DeleteError.wrongPassword
      ? l10n.authErrWrongPassword
      : null;

  /// Alana bağlanamayan gönderim hatasının metni (ağ hatası TST-24,
  /// başkanlık TST-X10 ile bildirilir).
  String? submitErrorOf(DeleteAccountState state, AppLocalizations l10n) =>
      switch (state.submitError) {
        DeleteError.tooManyRequests => l10n.dlg02Title,
        DeleteError.unknown => l10n.sysErrorTitle,
        DeleteError.wrongPassword ||
        DeleteError.isPresident ||
        DeleteError.network ||
        null => null,
      };
}
