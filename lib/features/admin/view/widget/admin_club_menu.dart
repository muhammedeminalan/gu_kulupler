import 'package:flutter/widgets.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_ui/gu_ui.dart';

/// ADM-02 satır menüsünde seçilen öğe — `showMenu<AdminClubMenuAction>`
/// dönüş değeri. Sıra tasarımdaki satır sırasıdır (`screens-admin.js:35`).
enum AdminClubMenuAction {
  /// "Görüntüle" (`ADM-02.menu.<id>.view`) → CLB-03.
  view('view'),

  /// "Düzenle" (`ADM-02.menu.<id>.edit`) → ADM-03.
  edit('edit'),

  /// "Başkanı değiştir" (`ADM-02.menu.<id>.president`) → SHT-25 atama.
  president('president'),

  /// "Askıya al" / "Etkinleştir" (`ADM-02.menu.<id>.suspend`) → DLG-28.
  suspend('suspend');

  const AdminClubMenuAction(this.action);

  /// Aksiyon adı (`ADM-02.menu.<clubId>.<action>`).
  final String action;
}

/// ADM-02 satırının açılır menüsü — prototip `PopMenu id="ADM-02"`
/// (`screens-admin.js:35`; konum CD-83).
///
/// Menü hiçbir şey yürütmez: seçilen öğe [AdminClubMenuAction] olarak döner;
/// eylemi `AdminClubsViewMixin` başlatır. Askı öğesi kulübün durumuna göre
/// "Askıya al" (`ban`, yıkıcı) ya da "Etkinleştir" (`circle-check`) olur;
/// anahtarı ikisinde de `.suspend`'dir.
///
/// Design: ADM-02
abstract final class AdminClubMenu {
  /// Menünün saydam scrim'i (`ADM-02.scrim`, `ui.js:191`).
  static final Key scrimKey = GuKey.action('ADM-02.scrim');

  /// [club] satırının menü öğeleri.
  static List<GuPopMenuItem> items(AppLocalizations l10n, ClubModel club) => [
    for (final action in AdminClubMenuAction.values)
      GuPopMenuItem(
        key: keyOf(club.id, action),
        label: labelOf(l10n, action, club),
        icon: iconOf(action, club),
        danger: action == AdminClubMenuAction.suspend && !club.isSuspended,
        value: action,
      ),
  ];

  /// [clubId] satırının [action] öğesinin anahtarı.
  static Key keyOf(String clubId, AdminClubMenuAction action) =>
      switch (action) {
        AdminClubMenuAction.view => GuKey.action('ADM-02.menu.$clubId.view'),
        AdminClubMenuAction.edit => GuKey.action('ADM-02.menu.$clubId.edit'),
        AdminClubMenuAction.president => GuKey.action(
          'ADM-02.menu.$clubId.president',
        ),
        AdminClubMenuAction.suspend => GuKey.action(
          'ADM-02.menu.$clubId.suspend',
        ),
      };

  /// [action] öğesinin metni.
  static String labelOf(
    AppLocalizations l10n,
    AdminClubMenuAction action,
    ClubModel club,
  ) => switch (action) {
    AdminClubMenuAction.view => l10n.commonView,
    AdminClubMenuAction.edit => l10n.commonEdit,
    AdminClubMenuAction.president => l10n.adminClubsChangePresident,
    AdminClubMenuAction.suspend =>
      club.isSuspended ? l10n.adminClubsActivate : l10n.adminClubsSuspend,
  };

  /// [action] öğesinin ikonu.
  static GuIcons iconOf(AdminClubMenuAction action, ClubModel club) =>
      switch (action) {
        AdminClubMenuAction.view => GuIcons.eye,
        AdminClubMenuAction.edit => GuIcons.pencil,
        AdminClubMenuAction.president => GuIcons.crown,
        AdminClubMenuAction.suspend =>
          club.isSuspended ? GuIcons.circleCheck : GuIcons.ban,
      };
}
