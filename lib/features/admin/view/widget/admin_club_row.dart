import 'package:flutter/widgets.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/widget/club/cover_mapper.dart';
import 'package:gu_ui/gu_ui.dart';

/// ADM-02 kulüp satırı — prototip `Tile` (`screens-admin.js:33`): amblem
/// (`emblem is-sm`, ikon 20) · ad · "Başkan: {ad} · {n} üye" · durum rozeti
/// (Aktif / Askıda) · "Diğer" (`more-vertical`).
///
/// Başkanın profili okunamadıysa ([president] `null`) alt metin yalnızca üye
/// sayısıdır; silinmiş başkan "Silinmiş kullanıcı" olarak yazılır.
/// Anahtarları çağıran verir ([actionKey] `ADM-02.row.<id>`, [menuKey]
/// `ADM-02.menu.<id>`; D-18, CD-86).
class AdminClubRow extends StatelessWidget {
  /// [club] kulübünün satırı.
  const AdminClubRow({
    required this.club,
    required this.president,
    required this.actionKey,
    required this.menuKey,
    required this.onTap,
    required this.onMenu,
    super.key,
  });

  /// Amblemi tanınmayan kulübün ikonu.
  static const GuIcons _fallbackIcon = GuIcons.users;

  /// Alt metin parçalarının ayracı (`' · '`, prototip şablonu).
  static const String _separator = ' · ';

  /// Satırın kulübü.
  final ClubModel club;

  /// Kulübün başkanı; okunamadıysa `null`.
  final UserModel? president;

  /// Satırın aksiyon anahtarı.
  final Key actionKey;

  /// "Diğer" düğmesinin anahtarı.
  final Key menuKey;

  /// Satıra dokunma (CLB-03).
  final VoidCallback onTap;

  /// "Diğer" menüsü.
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final president = this.president;
    final members = l10n.clubsCardMembers(club.memberCount);
    return GuTile(
      key: actionKey,
      leading: GuEmblem(icon: CoverMapper.icon(club.iconName) ?? _fallbackIcon),
      title: club.name,
      subtitle: president == null
          ? members
          : [
              l10n.adminClubsPresident(
                president.isDeleted ? l10n.commonDeletedUser : president.name,
              ),
              members,
            ].join(_separator),
      sub2Widget: Align(
        alignment: AlignmentDirectional.centerStart,
        child: club.isSuspended
            ? GuStatusBadge(
                kind: GuStatusBadgeKind.suspended,
                label: l10n.statusSuspended,
              )
            : GuStatusBadge(
                kind: GuStatusBadgeKind.active,
                label: l10n.statusActive,
              ),
      ),
      trailing: GuIconButton(
        key: menuKey,
        icon: GuIcons.moreVertical,
        semanticLabel: l10n.a11yMore,
        onPressed: onMenu,
      ),
      onTap: onTap,
    );
  }
}
