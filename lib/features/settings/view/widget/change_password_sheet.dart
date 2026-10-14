import 'package:flutter/services.dart' show TextInputAction;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/settings/provider/change_password_state.dart';
import 'package:gu_kulupler/features/settings/provider/change_password_view_model.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/form/password_strength.dart';
import 'package:gu_kulupler/product/mixin/unsaved_changes_mixin.dart';
import 'package:gu_kulupler/product/widget/form/form_error_line.dart';
import 'package:gu_kulupler/product/widget/form/password_strength_bar.dart';
import 'package:gu_ui/gu_ui.dart';

/// SHT-32 Şifre değiştir — SET-01 "Şifre değiştir" satırı
/// (`sheets.js:149–152`).
///
/// Gövde (`.col.gap12.pb16`): "Mevcut şifre" (otomatik odak) · "Yeni şifre" ·
/// güç çubuğu (`PasswordStrengthBar`, 4 dilim) · "Yeni şifre tekrar"; üçü de
/// gizli metin + `key-round` ikonu. Alt alanda "Kaydet".
///
/// "Kaydet" `ChangePasswordViewModel.submit` (`authRepository.changePassword`
/// — yeniden doğrulama + güncelleme tek metot) çağırır; başarıda TST-44
/// gösterilir ve sayfa `true` ile kapanır. Hatalı mevcut şifre, zayıf yeni
/// şifre ve uyuşmayan tekrar alan hatasıdır; "çok fazla deneme" ve bilinmeyen
/// hata form altı hata satırıdır; ağ hatası TST-24. Mevcut ya da yeni şifre
/// doluyken X / scrim / sürükleme / geri DLG-25'i sorar (prototip `dirty`);
/// kapatma / vazgeçme `null` döner:
///
/// ```dart
/// final changed = await feedback.showSheet<bool>(
///   SheetId.sht32,
///   builder: (_) => const ChangePasswordSheet(),
/// );
/// ```
///
/// Prototipteki "Tüm demo hesapların şifresi" satırı mock'tur, uygulanmaz
/// (CLAUDE.md §12).
///
/// Anahtarlar `SHT-32.current`, `.new`, `.repeat`, `.save`, `.close`.
///
/// Design: SHT-32
class ChangePasswordSheet extends ConsumerStatefulWidget {
  /// Şifre değiştirme alt sayfası.
  const ChangePasswordSheet({super.key});

  @override
  ConsumerState<ChangePasswordSheet> createState() =>
      _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<ChangePasswordSheet> {
  ChangePasswordViewModel get _viewModel =>
      ref.read(changePasswordViewModelProvider.notifier);

  Future<void> _save() async {
    await _viewModel.submit();
    if (!mounted) return;
    if (ref.read(changePasswordViewModelProvider).isDone) context.pop(true);
  }

  /// Kapanma kapısı: form temizse doğrudan kapanır; kirliyse DLG-25 sorar.
  /// Gönderim sürerken sayfa kapanmaz.
  Future<bool> _confirmClose() async {
    final state = ref.read(changePasswordViewModelProvider);
    if (state.isSubmitting) return false;
    if (!state.isDirty) return true;
    final answer = await showUnsavedChangesDialog(
      ref.read(feedbackServiceProvider),
    );
    return answer == UnsavedChangesResult.discard;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(changePasswordViewModelProvider);
    final formError = _formErrorText(state, l10n);
    return GuSheetFrame(
      title: l10n.sht32Title,
      closeSemanticLabel: l10n.a11yClose,
      closeKey: FeedbackKeys.of(SheetId.sht32.designId, 'close'),
      onWillClose: _confirmClose,
      footer: [
        GuButton(
          key: GuKey.action('SHT-32.save'),
          label: l10n.commonSave,
          loading: state.isSubmitting,
          onPressed: _save,
        ),
      ],
      body: Padding(
        padding: GuInsets.only(bottom: GuSpacing.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: GuSpacing.s12,
          children: [
            GuInput(
              label: l10n.sht32Current,
              icon: GuIcons.keyRound,
              obscure: true,
              autofocus: true,
              textInputAction: TextInputAction.next,
              errorText: _currentErrorText(state, l10n),
              actionKey: GuKey.action('SHT-32.current'),
              onChanged: _viewModel.setCurrentPassword,
            ),
            GuInput(
              label: l10n.sht32New,
              icon: GuIcons.keyRound,
              obscure: true,
              textInputAction: TextInputAction.next,
              errorText: switch (state.errors[PasswordField.newPassword]) {
                null => null,
                _ => l10n.authErrPassword,
              },
              actionKey: GuKey.action('SHT-32.new'),
              onChanged: _viewModel.setNewPassword,
            ),
            PasswordStrengthBar(
              strength: state.strength,
              max: PasswordStrength.max,
            ),
            GuInput(
              label: l10n.sht32Repeat,
              icon: GuIcons.keyRound,
              obscure: true,
              textInputAction: TextInputAction.done,
              errorText: switch (state.errors[PasswordField.confirm]) {
                null => null,
                _ => l10n.authErrMismatch,
              },
              actionKey: GuKey.action('SHT-32.repeat'),
              onChanged: _viewModel.setConfirm,
              onSubmitted: _save,
            ),
            if (formError != null) FormErrorLine(formError),
          ],
        ),
      ),
    );
  }

  /// Mevcut şifre: boş → "Bu alan zorunlu"; sunucu "hatalı" → "Şifre hatalı".
  static String? _currentErrorText(
    ChangePasswordState state,
    AppLocalizations l10n,
  ) {
    if (state.errors[PasswordField.current] == FormFieldError.required) {
      return l10n.authErrRequired;
    }
    return state.submitError == ChangePasswordError.wrongPassword
        ? l10n.authErrWrongPassword
        : null;
  }

  /// Alana bağlanmayan sunucu hatası (form altı satır).
  static String? _formErrorText(
    ChangePasswordState state,
    AppLocalizations l10n,
  ) => switch (state.submitError) {
    ChangePasswordError.tooManyRequests => l10n.dlg02Title,
    ChangePasswordError.unknown => l10n.sysErrorTitle,
    ChangePasswordError.wrongPassword ||
    ChangePasswordError.weak ||
    ChangePasswordError.network ||
    null => null,
  };
}
