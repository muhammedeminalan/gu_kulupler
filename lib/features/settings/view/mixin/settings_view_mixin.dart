import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/features/settings/view/settings_view.dart';
import 'package:gu_kulupler/features/settings/view/widget/change_password_sheet.dart';
import 'package:gu_kulupler/features/settings/view/widget/theme_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/language_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/init/app_preferences_view_model.dart';
import 'package:gu_kulupler/product/mixin/sign_out_mixin.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';
import 'package:gu_ui/gu_ui.dart';

/// SET-01 davranışı (`screens-profile.js:60–70`). Ekranın ayrı ViewModel'i
/// yoktur (PLAN §12.12): tercihler `AppPreferencesViewModel`'e yazılır, çıkış
/// `SignOutMixin` (DLG-06 → `SessionViewModel.signOut`) ile yapılır; satırlar
/// rota ya da alt sayfa açar.
///
/// * Profil dalındaki hedefler (NTF-02 kopyası, SET-02, SET-04, SET-05)
///   guard'lı rotalardır → `go` (CLAUDE.md §5). Yasal metin (AUT-06)
///   guard'sız geçici sayfadır → `push`; izinli `push` view dosyasındadır
///   (`SettingsView._openPrivacy`, PLAN §13.10 `push_scan_test`).
/// * Tema (SHT-17), dil (SHT-01) ve şifre (SHT-32) `FeedbackService` alt
///   sayfalarıdır.
mixin SettingsViewMixin
    on ConsumerState<SettingsView>, SignOutMixin<SettingsView> {
  FeedbackService get _feedback => ref.read(feedbackServiceProvider);

  /// Geri (`SET-01.back`): yığında önceki sayfa varsa ona, yoksa PRF-01'e.
  void back() =>
      context.canPop() ? context.pop() : const ProfileRoute().go(context);

  /// "Tema" (`SET-01.theme`) → SHT-17.
  Future<void> openTheme() => _feedback.showSheet<void>(
    SheetId.sht17,
    builder: (_) => const ThemeSheet(),
  );

  /// "Dil" (`SET-01.language`) → SHT-01.
  Future<void> openLanguage() => _feedback.showSheet<void>(
    SheetId.sht01,
    builder: (_) => const LanguageSheet(),
  );

  /// Yazı boyutu bölmesi (`SET-01.textScale.1|1.3|1.6`): tercih hemen
  /// uygulanır ve kalıcıdır (`pref.textScale`, Q-14).
  void setTextScale(GuTextScaleLevel level) => unawaited(
    ref.read(appPreferencesViewModelProvider.notifier).setTextScale(level),
  );

  /// "Bildirim tercihleri" (`SET-01.notifications`) → NTF-02 (Profil dalı).
  void openNotificationPrefs() =>
      const SettingsNotificationPrefsRoute().go(context);

  /// "Engellenen kullanıcılar" (`SET-01.blocked`) → SET-02.
  void openBlocked() => const BlockedRoute().go(context);

  /// "Şifre değiştir" (`SET-01.password`) → SHT-32. Başarı bildirimi
  /// (TST-44) sayfanın ViewModel'indedir.
  Future<void> openChangePassword() => _feedback.showSheet<bool>(
    SheetId.sht32,
    builder: (_) => const ChangePasswordSheet(),
  );

  /// "Yardım ve destek" (`SET-01.support`) → SET-05.
  void openSupport() => const SupportRoute().go(context);

  /// "Hakkında" (`SET-01.about`) → SET-04.
  void openAbout() => const AboutRoute().go(context);

  /// "Çıkış yap" (`SET-01.logout`) → DLG-06; onayda oturum kapanır, router
  /// AUT-01'e taşır.
  Future<void> logout() => confirmSignOut();

  /// "Hesabı sil" (`SET-01.delete`) → SET-03.
  void openDeleteAccount() {
    // TODO(T-29): `const DeleteAccountRoute().go(context)` (SET-03).
  }
}
