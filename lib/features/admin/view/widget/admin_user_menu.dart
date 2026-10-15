import 'package:flutter/widgets.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_ui/gu_ui.dart';

/// ADM-05 satır menüsünde seçilen öğe — `showMenu<AdminUserMenuAction>`
/// dönüş değeri. Sıra tasarımdaki satır sırasıdır (`screens-admin.js:78`).
enum AdminUserMenuAction {
  /// "Profili gör" (`ADM-05.menu.<id>.profile`) → CLB-07.
  profile,

  /// "Askıya al" / "Askıyı kaldır" (`ADM-05.menu.<id>.suspend`) → DLG-30.
  suspend,
}

/// ADM-05 satırının açılır menüsü — prototip `PopMenu id="ADM-05"`
/// (`screens-admin.js:78`; konum CD-83).
///
/// Menü hiçbir şey yürütmez: seçilen öğe [AdminUserMenuAction] olarak döner;
/// eylemi `AdminUsersViewMixin` başlatır. Askı öğesi hesabın durumuna göre
/// "Askıya al" (`ban`, yıkıcı) ya da "Askıyı kaldır" (`circle-check`) olur;
/// anahtarı ikisinde de `.suspend`'dir. Oturumdaki süper adminin kendi
/// satırında (`self`) askı öğesi yoktur (W-101 b).
///
/// Design: ADM-05
abstract final class AdminUserMenu {
  /// Menünün saydam scrim'i (`ADM-05.scrim`, `ui.js:191`).
  static final Key scrimKey = GuKey.action('ADM-05.scrim');

  /// [user] satırının menü öğeleri.
  static List<GuPopMenuItem> items(
    AppLocalizations l10n,
    UserModel user, {
    required bool self,
  }) {
    final suspended = user.status == UserStatus.suspended;
    return [
      GuPopMenuItem(
        key: keyOf(user.uid, AdminUserMenuAction.profile),
        label: l10n.userprofileView,
        icon: GuIcons.user,
        value: AdminUserMenuAction.profile,
      ),
      if (!self)
        GuPopMenuItem(
          key: keyOf(user.uid, AdminUserMenuAction.suspend),
          label: suspended ? l10n.adminUsersUnsuspend : l10n.adminUsersSuspend,
          icon: suspended ? GuIcons.circleCheck : GuIcons.ban,
          danger: !suspended,
          value: AdminUserMenuAction.suspend,
        ),
    ];
  }

  /// [userId] satırının [action] öğesinin anahtarı.
  static Key keyOf(String userId, AdminUserMenuAction action) =>
      switch (action) {
        AdminUserMenuAction.profile => GuKey.action(
          'ADM-05.menu.$userId.profile',
        ),
        AdminUserMenuAction.suspend => GuKey.action(
          'ADM-05.menu.$userId.suspend',
        ),
      };
}
