import 'package:flutter/widgets.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_ui/gu_ui.dart';

/// PRF-03 satır menüsünde seçilen öğe — `showMenu<MyClubMenuAction>` dönüş
/// değeri. Sıra tasarımdaki satır sırasıdır (`screens-profile.js:46–49`).
enum MyClubMenuAction {
  /// "Aç" (`PRF-03.menu.<id>.open`) — her satırda.
  open('open', GuIcons.externalLink),

  /// "Kulüpten ayrıl" (`PRF-03.menu.<id>.leave`) — aktif üyelikte.
  leave('leave', GuIcons.logOut),

  /// "İsteği iptal et" (`PRF-03.menu.<id>.cancel`) — bekleyen başvuruda.
  cancel('cancel', GuIcons.x),

  /// "Tekrar başvur" (`PRF-03.menu.<id>.reapply`) — reddedilen / çıkarılan
  /// üyelikte.
  reapply('reapply', GuIcons.refreshCw);

  const MyClubMenuAction(this.action, this.icon);

  /// Aksiyon adı (`PRF-03.menu.<clubId>.<action>`).
  final String action;

  /// Satırın ikonu.
  final GuIcons icon;
}

/// PRF-03 satırının açılır menüsü — prototip `PopMenu id="PRF-03"`
/// (`screens-profile.js:46–49`; konum CD-83).
///
/// Menü hiçbir şey yürütmez: seçilen öğe [MyClubMenuAction] olarak döner;
/// eylemi `MyClubsViewMixin` başlatır.
///
/// Design: PRF-03
abstract final class MyClubMenu {
  /// Menünün saydam scrim'i (`PRF-03.scrim`, `ui.js:191`).
  static final Key scrimKey = GuKey.action('PRF-03.scrim');

  /// [membership] üyeliğinin menü öğeleri. Danışman üye sayılmaz ve
  /// ayrılamaz (`FirestoreRuleCode.notMember`): "Kulüpten ayrıl" çizilmez.
  static List<GuPopMenuItem> items(
    AppLocalizations l10n,
    MembershipModel membership,
  ) => [
    for (final action in actionsOf(membership))
      GuPopMenuItem(
        key: keyOf(membership.clubId, action),
        label: labelOf(l10n, action),
        icon: action.icon,
        danger:
            action == MyClubMenuAction.leave ||
            action == MyClubMenuAction.cancel,
        value: action,
      ),
  ];

  /// [membership] durumunda gösterilen öğeler.
  static List<MyClubMenuAction> actionsOf(MembershipModel membership) => [
    MyClubMenuAction.open,
    ...switch (membership.status) {
      MembershipStatus.active when membership.role != ClubRole.advisor => [
        MyClubMenuAction.leave,
      ],
      MembershipStatus.pending => [MyClubMenuAction.cancel],
      MembershipStatus.rejected || MembershipStatus.removed => [
        MyClubMenuAction.reapply,
      ],
      _ => const <MyClubMenuAction>[],
    },
  ];

  /// [clubId] satırının [action] öğesinin anahtarı.
  static Key keyOf(String clubId, MyClubMenuAction action) => switch (action) {
    MyClubMenuAction.open => GuKey.action('PRF-03.menu.$clubId.open'),
    MyClubMenuAction.leave => GuKey.action('PRF-03.menu.$clubId.leave'),
    MyClubMenuAction.cancel => GuKey.action('PRF-03.menu.$clubId.cancel'),
    MyClubMenuAction.reapply => GuKey.action('PRF-03.menu.$clubId.reapply'),
  };

  /// [action] öğesinin metni.
  static String labelOf(AppLocalizations l10n, MyClubMenuAction action) =>
      switch (action) {
        MyClubMenuAction.open => l10n.commonOpen,
        MyClubMenuAction.leave => l10n.clubLeave,
        MyClubMenuAction.cancel => l10n.applicationCancel,
        MyClubMenuAction.reapply => l10n.applicationReapply,
      };
}
