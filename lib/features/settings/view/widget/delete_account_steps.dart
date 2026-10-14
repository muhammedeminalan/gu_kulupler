import 'package:flutter/material.dart';
import 'package:gu_data/gu_data.dart' show DeleteProgress;
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/settings/provider/delete_account_state.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/widget/form/form_error_line.dart';
import 'package:gu_ui/gu_ui.dart';

/// SET-03 1. adım — uyarı (`screens-profile.js:86–87`): tehlike bandı
/// ("Bu işlem geri alınamaz…"), "Silinecekler" (4 madde) + "Kalacaklar"
/// kartı; başkanlık varsa uyarı kenarlıklı "Önce başkanlığı devretmelisin"
/// kartı (kulüp başına ad + "Devret").
class DeleteAccountWarningStep extends StatelessWidget {
  /// [presidentOfClubIds] boşsa başkanlık kartı çizilmez.
  const DeleteAccountWarningStep({
    required this.presidentOfClubIds,
    required this.clubNames,
    required this.onTransfer,
    this.errorText,
    super.key,
  });

  /// Başkanı olunan kulüplerin kimlikleri (sırasıyla).
  final List<String> presidentOfClubIds;

  /// Kulüp adları; olmayan kulübün kimliği gösterilir.
  final Map<String, String> clubNames;

  /// "Devret" dokunması (`SET-03.transfer.<clubId>`).
  final ValueChanged<String> onTransfer;

  /// Ön denetim okunamadıysa form altı hata satırı.
  final String? errorText;

  /// [clubId] kulübünün "Devret" anahtarı.
  static Key transferKey(String clubId) =>
      GuKey.action('SET-03.transfer.$clubId');

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final colors = gu.colors;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final secondary = gu.text.bodyS.copyWith(color: colors.textSecondary);
    final errorText = this.errorText;

    Widget overline(String text) => Padding(
      padding: GuInsets.only(bottom: GuSpacing.s2),
      child: Semantics(
        header: true,
        child: Text(text.upperFor(locale), style: gu.text.overline),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: GuSpacing.s16,
      children: [
        GuBanner(
          kind: GuBannerKind.danger,
          text: l10n.deleteAccountWarning,
          card: true,
        ),
        GuCard(
          padding: GuCard.bodyPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: GuSpacing.s8,
            children: [
              overline(l10n.deleteAccountDeleted),
              GuBulletList(
                items: [
                  l10n.deleteAccountItemMemberships,
                  l10n.deleteAccountItemApplications,
                  l10n.deleteAccountItemTickets,
                  l10n.deleteAccountItemNotifications,
                ],
              ),
              Padding(
                padding: GuInsets.only(top: GuSpacing.s8),
                child: overline(l10n.deleteAccountKept),
              ),
              Text(l10n.deleteAccountKeptDesc, style: secondary),
            ],
          ),
        ),
        if (presidentOfClubIds.isNotEmpty)
          GuCard(
            padding: GuCard.bodyPadding,
            borderColor: colors.stateWarning,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: GuSpacing.s8,
              children: [
                Row(
                  spacing: GuSpacing.s6,
                  children: [
                    GuIcon(
                      GuIcons.triangleAlert,
                      size: GuSizes.icon18,
                      color: colors.stateWarning,
                    ),
                    Expanded(
                      child: Text(
                        l10n.deleteAccountPresidentBlock,
                        style: gu.text.labelL.copyWith(
                          color: colors.stateWarning,
                        ),
                      ),
                    ),
                  ],
                ),
                for (final clubId in presidentOfClubIds)
                  Row(
                    spacing: GuSpacing.s8,
                    children: [
                      Expanded(
                        child: Text(
                          clubNames[clubId] ?? clubId,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: gu.text.bodyS.copyWith(
                            color: colors.textHeading,
                          ),
                        ),
                      ),
                      GuButton(
                        key: transferKey(clubId),
                        label: l10n.deleteAccountTransfer,
                        size: GuButtonSize.sm,
                        variant: GuButtonVariant.tonal,
                        onPressed: () => onTransfer(clubId),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        if (errorText != null) FormErrorLine(errorText),
      ],
    );
  }
}

/// SET-03 2. adım — "Neden ayrılıyorsun?" (`screens-profile.js:88`):
/// başlık, "İsteğe bağlı", 5 seçenek (ayraçlı kart) ve 300 karakterlik
/// serbest metin (sayaçlı). Neden saklanmaz (CD-152).
class DeleteAccountReasonStep extends StatelessWidget {
  /// [reason] seçili neden (yoksa `null`).
  const DeleteAccountReasonStep({
    required this.reason,
    required this.controller,
    required this.onReason,
    required this.onReasonText,
    super.key,
  });

  /// Seçili neden.
  final DeleteReason? reason;

  /// Serbest metin denetleyicisi.
  final TextEditingController controller;

  /// Seçenek dokunması (`SET-03.reason.<neden>`).
  final ValueChanged<DeleteReason> onReason;

  /// Metin değişti (`SET-03.reasonText`).
  final ValueChanged<String> onReasonText;

  /// [reason] seçeneğinin anahtarı.
  static Key reasonKey(DeleteReason reason) =>
      GuKey.action('SET-03.reason.${reason.name}');

  /// [reason] seçeneğinin etiketi.
  static String labelOf(AppLocalizations l10n, DeleteReason reason) =>
      switch (reason) {
        DeleteReason.noUse => l10n.deleteAccountReasonNoUse,
        DeleteReason.tooMany => l10n.deleteAccountReasonTooMany,
        DeleteReason.privacy => l10n.deleteAccountReasonPrivacy,
        DeleteReason.graduated => l10n.deleteAccountReasonGraduated,
        DeleteReason.other => l10n.deleteAccountReasonOther,
      };

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: GuSpacing.s16,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.deleteAccountReasonTitle, style: gu.text.titleM),
        ),
        Text(
          l10n.commonOptional,
          style: gu.text.bodyS.copyWith(color: gu.colors.textSecondary),
        ),
        GuCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, option) in DeleteReason.values.indexed) ...[
                if (index > 0) const GuDivider(),
                GuOptionRow(
                  key: reasonKey(option),
                  label: labelOf(l10n, option),
                  selected: reason == option,
                  onTap: () => onReason(option),
                ),
              ],
            ],
          ),
        ),
        // `rows=3` prototipte de 4 satır çizilir (`textarea`
        // `min-height:88px`, css:169) → `GuInput` varsayılanı.
        GuInput(
          controller: controller,
          placeholder: l10n.deleteAccountReasonPlaceholder,
          semanticLabel: l10n.deleteAccountReasonTitle,
          multiline: true,
          maxLength: DeleteAccountState.reasonTextMax,
          showCounter: true,
          actionKey: GuKey.action('SET-03.reasonText'),
          onChanged: onReasonText,
        ),
      ],
    );
  }
}

/// SET-03 3. adım — "Son adım" (`screens-profile.js:89`): şifre (yeniden
/// doğrulama; hatalıysa "Şifre hatalı") ve "Onaylamak için SİL yaz".
/// Silme sürerken temizlik dizisinin ilerlemesi ince çubukla gösterilir
/// (CD-152).
class DeleteAccountConfirmStep extends StatelessWidget {
  /// Girdiler [passwordController] / [confirmWordController]'dadır.
  const DeleteAccountConfirmStep({
    required this.passwordController,
    required this.confirmWordController,
    required this.onPassword,
    required this.onConfirmWord,
    required this.isSubmitting,
    this.passwordError,
    this.errorText,
    this.progress,
    super.key,
  });

  /// Şifre denetleyicisi.
  final TextEditingController passwordController;

  /// Onay sözcüğü denetleyicisi.
  final TextEditingController confirmWordController;

  /// Şifre değişti (`SET-03.password`).
  final ValueChanged<String> onPassword;

  /// Onay sözcüğü değişti (`SET-03.confirmWord`).
  final ValueChanged<String> onConfirmWord;

  /// Silme sürüyor mu (girdiler kilitlenir)?
  final bool isSubmitting;

  /// Şifre alanının hata metni.
  final String? passwordError;

  /// Form altı hata satırı.
  final String? errorText;

  /// Temizlik ilerlemesi; `null` → çizilmez.
  final DeleteProgress? progress;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final errorText = this.errorText;
    final progress = this.progress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: GuSpacing.s16,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.deleteAccountConfirmTitle, style: gu.text.titleM),
        ),
        GuInput(
          controller: passwordController,
          label: l10n.authPassword,
          icon: GuIcons.keyRound,
          obscure: true,
          disabled: isSubmitting,
          textInputAction: TextInputAction.next,
          errorText: passwordError,
          actionKey: GuKey.action('SET-03.password'),
          onChanged: onPassword,
        ),
        GuInput(
          controller: confirmWordController,
          label: l10n.deleteAccountTypeDelete,
          placeholder: l10n.set03ConfirmWord,
          disabled: isSubmitting,
          textInputAction: TextInputAction.done,
          actionKey: GuKey.action('SET-03.confirmWord'),
          onChanged: onConfirmWord,
        ),
        if (errorText != null) FormErrorLine(errorText),
        if (progress != null)
          GuProgress(
            value: progress.done.toDouble(),
            max: progress.total.toDouble(),
            thin: true,
            semanticLabel: '${progress.done}/${progress.total}',
          ),
      ],
    );
  }
}
