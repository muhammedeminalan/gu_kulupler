import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_ui/gu_ui.dart';

/// SHT-06'da seçilen öğe — sayfanın `pop` değeri. Sıra tasarımdaki satır
/// sırasıdır (`sheets.js:35`).
enum ClubMenuAction {
  /// "Bildirimleri yönet" → SHT-07.
  notifications(GuIcons.bell),

  /// "Paylaş" → SHT-15.
  share(GuIcons.share2),

  /// "Üyeler" → CLB-06.
  members(GuIcons.users),

  /// "Şikayet et" → SHT-10.
  report(GuIcons.flag),

  /// "Kulüp ayarları" → MGT-09.
  settings(GuIcons.settings),

  /// "Kulüpten ayrıl" → DLG-08 (başkan → DLG-09).
  leave(GuIcons.logOut);

  const ClubMenuAction(this.icon);

  /// Satırın ikonu.
  final GuIcons icon;
}

/// SHT-06 "Kulüp menüsü" — CLB-03 üst çubuğundaki "⋯" menüsü (prototip
/// `SHEETS['SHT-06']`, `sheets.js:34–35`).
///
/// * Başlık kulübün adıdır ([clubName]). Satırlar kullanıcının kulüpteki
///   erişim kipine göre süzülür ([actionsFor]); kip oturumdan okunur
///   (`SessionState.accessTo`), çağıran vermez.
/// * Sayfa kendisi hiçbir şey yürütmez: dokunulan satır [ClubMenuAction]
///   olarak döner (`pop`), sayfa kapanır, eylemi çağıran başlatır (prototip
///   `go = (fn) => () => { close(); fn(); }`). X / scrim / sürükleme / geri →
///   `null`.
/// * Anahtarlar `SHT-06.notifications`, `.share`, `.members`, `.report`,
///   `.settings`, `.leave`, `SHT-06.close` (+ `SHT-06.scrim`,
///   `FeedbackService`).
///
/// ```dart
/// final action = await feedback.showSheet<ClubMenuAction>(
///   SheetId.sht06,
///   builder: (_) => ClubMenuSheet(clubId: club.id, clubName: club.name),
/// );
/// ```
///
/// Design: SHT-06
class ClubMenuSheet extends ConsumerWidget {
  /// [clubId] kulübünün menüsü; başlık [clubName].
  const ClubMenuSheet({required this.clubId, this.clubName, super.key});

  /// Menüsü açılan kulübün kimliği.
  final String clubId;

  /// Başlıkta gösterilen kulüp adı; verilmezse genel başlık ("Kulüp menüsü").
  final String? clubName;

  /// [access] kipindeki kullanıcının gördüğü satırlar, tasarım sırasıyla
  /// (`sheets.js:35`): bildirimler ve üyeler kulübün içindekilere (üye,
  /// yönetici, danışman); ayarlar yöneticiye ve süper admine; ayrılma üyeye
  /// ve yöneticiye. Paylaş ve şikayet herkese açıktır.
  static List<ClubMenuAction> actionsFor(ClubAccess access) {
    final isInside =
        access == ClubAccess.member ||
        access == ClubAccess.manager ||
        access == ClubAccess.advisor;
    return [
      if (isInside) ClubMenuAction.notifications,
      ClubMenuAction.share,
      if (isInside) ClubMenuAction.members,
      ClubMenuAction.report,
      if (access == ClubAccess.manager || access == ClubAccess.superAdmin)
        ClubMenuAction.settings,
      if (access == ClubAccess.member || access == ClubAccess.manager)
        ClubMenuAction.leave,
    ];
  }

  /// [action] satırının görünen adı.
  static String labelOf(AppLocalizations l10n, ClubMenuAction action) =>
      switch (action) {
        ClubMenuAction.notifications => l10n.sht06Notifications,
        ClubMenuAction.share => l10n.commonShare,
        ClubMenuAction.members => l10n.membersTitle,
        ClubMenuAction.report => l10n.sht06Report,
        ClubMenuAction.settings => l10n.clubSettingsTitle,
        ClubMenuAction.leave => l10n.clubLeave,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.gu.colors;
    final access = ref.watch(
      sessionViewModelProvider.select((session) => session.accessTo(clubId)),
    );
    return GuSheetFrame(
      title: clubName ?? l10n.sht06Title,
      closeSemanticLabel: l10n.a11yClose,
      closeKey: GuKey.action('SHT-06.close'),
      menu: true,
      flush: true,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final action in actionsFor(access))
            GuTile(
              key: GuKey.action('SHT-06.${action.name}'),
              title: labelOf(l10n, action),
              danger: action == ClubMenuAction.leave,
              leading: GuIcon(
                action.icon,
                size: GuSizes.icon22,
                color: action == ClubMenuAction.leave
                    ? colors.stateDanger
                    : colors.textHeading,
              ),
              onTap: () => context.pop(action),
            ),
        ],
      ),
    );
  }
}
