import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/settings/provider/delete_account_state.dart';
import 'package:gu_kulupler/features/settings/provider/delete_account_view_model.dart';
import 'package:gu_kulupler/features/settings/view/mixin/delete_account_view_mixin.dart';
import 'package:gu_kulupler/features/settings/view/widget/delete_account_steps.dart';
import 'package:gu_ui/gu_ui.dart';

/// SET-03 Hesabı sil — `DeleteAccountRoute` (`/profile/settings/delete`);
/// prototip `DeleteAccount` (`screens-profile.js:80–92`).
///
/// Başlık çubuğu: geri + "Hesabı sil" + adım alt satırı ("1/3"). Kaydırma
/// alanı (`.col.gap16.px16.pb24`) adıma göre değişir:
///
/// 1. Uyarı + başkanlık engeli (`DeleteAccountWarningStep`) — alt çubukta
///    `dangerOutline` "Devam"; başkanken kapalı (dokunma → TST-X10).
/// 2. Ayrılma nedeni (`DeleteAccountReasonStep`) — `primary` "Devam".
/// 3. Şifre + "SİL" (`DeleteAccountConfirmStep`) — `danger` "Hesabımı
///    kalıcı olarak sil"; şifre boşken ya da sözcük eşleşmezken kapalı
///    (dokunma → TST-X11), silme sürerken yükleniyor.
///
/// Ekranın boş / çevrimdışı durumu yoktur: ön denetim sürerken "Devam"
/// yükleniyor görünür, okunamazsa form altı hata satırı çıkar ve "Devam"
/// yeniden dener; çevrimdışı gönderim TST-24'tür (yazma kapısı). Davranış
/// `DeleteAccountViewMixin`'de, dizi `DeleteAccountViewModel`'dedir.
///
/// Design: SET-03
class DeleteAccountView extends ConsumerStatefulWidget {
  /// Hesap silme akışı.
  const DeleteAccountView({super.key});

  @override
  ConsumerState<DeleteAccountView> createState() => _DeleteAccountViewState();
}

class _DeleteAccountViewState extends ConsumerState<DeleteAccountView>
    with DeleteAccountViewMixin {
  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final state = ref.watch(deleteAccountViewModelProvider);
    final step = state.step;
    final canConfirm = state.canConfirm(l10n.set03ConfirmWord);

    return PopScope(
      canPop: step == DeleteStep.warning && !state.isSubmitting,
      onPopInvokedWithResult: (didPop, _) => onPopInvoked(didPop),
      child: Scaffold(
        backgroundColor: gu.colors.bgCanvas,
        appBar: GuAppBar(
          title: l10n.deleteAccountTitle,
          subtitle: '${step.number}/${DeleteStep.values.length}',
          onBack: back,
          backSemanticLabel: l10n.a11yBack,
          backActionKey: GuKey.action('SET-03.back'),
        ),
        bottomNavigationBar: GuStickyCta(
          children: [
            if (step == DeleteStep.confirm)
              GuButton(
                key: GuKey.action('SET-03.confirm'),
                label: l10n.deleteAccountConfirmCta,
                variant: GuButtonVariant.danger,
                full: true,
                disabled: !canConfirm,
                loading: state.isSubmitting,
                onPressed: confirm,
                onDisabledPressed: onConfirmDisabled,
              )
            else
              GuButton(
                key: GuKey.action('SET-03.next'),
                label: l10n.commonContinue,
                variant: step == DeleteStep.warning
                    ? GuButtonVariant.dangerOutline
                    : GuButtonVariant.primary,
                full: true,
                disabled: step == DeleteStep.warning && state.isPresident,
                loading: step == DeleteStep.warning && state.isChecking,
                onPressed: next,
                onDisabledPressed: next,
              ),
          ],
        ),
        body: SingleChildScrollView(
          // Adım başına ayrı kaydırma konumu (prototip `routeKey="delete"`).
          key: PageStorageKey<String>('delete-${step.name}'),
          padding: GuInsets.only(
            left: GuSpacing.s16,
            right: GuSpacing.s16,
            bottom: GuSpacing.s24,
          ),
          child: switch (step) {
            DeleteStep.warning => DeleteAccountWarningStep(
              presidentOfClubIds: state.presidentOfClubIds,
              clubNames: state.clubNames,
              onTransfer: transfer,
              errorText: state.isCheckError ? l10n.sysErrorTitle : null,
            ),
            DeleteStep.reason => DeleteAccountReasonStep(
              reason: state.reason,
              controller: reasonController,
              onReason: viewModel.setReason,
              onReasonText: viewModel.setReasonText,
            ),
            DeleteStep.confirm => DeleteAccountConfirmStep(
              passwordController: passwordController,
              confirmWordController: confirmWordController,
              onPassword: viewModel.setPassword,
              onConfirmWord: viewModel.setConfirmWord,
              isSubmitting: state.isSubmitting,
              passwordError: passwordErrorOf(state, l10n),
              errorText: submitErrorOf(state, l10n),
              progress: state.isSubmitting ? state.progress : null,
            ),
          },
        ),
      ),
    );
  }
}
