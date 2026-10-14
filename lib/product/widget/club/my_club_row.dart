import 'package:flutter/widgets.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/widget/club/cover_mapper.dart';
import 'package:gu_kulupler/product/widget/member/member_row.dart';
import 'package:gu_ui/gu_ui.dart';

/// Kulüp satırı — prototip `Tile` + `emblem is-sm` + `RoleBadge` /
/// `StatusBadge` (`screens-profile.js` PRF-01 "Yönettiğin kulüpler" /
/// "Kulüplerim" kartları, PRF-03 listesi).
///
/// * PRF-01: kart içinde ([inCard]), alt satır rol rozeti, sağda chevron.
/// * PRF-03: alt satır aktif üyelikte rol, diğerlerinde durum rozeti +
///   [caption] (karar / başvuru tarihi, çağıran `intl` ile biçimler); sağda
///   "Diğer" düğmesi ([onMenu], [menuKey]).
///
/// Alt satır `row gap6 wrap`'tır (`screens-profile.js:45`): rozet ve tarih
/// sığmazsa tarih alt satıra iner (K-05 — EN 320 × 1.3); satır taşmaz.
///
/// Anahtarları çağıran verir ([actionKey] satırın kendisi — `PRF-01.club.<id>`,
/// `PRF-01.managed.<id>`, `PRF-03.row.<id>`; [menuKey] `PRF-03.menu.<id>`;
/// D-18, CD-86).
class MyClubRow extends StatelessWidget {
  /// [club] kulübünün satırı.
  const MyClubRow({
    required this.club,
    required this.actionKey,
    required this.onTap,
    this.role = ClubRole.member,
    this.status = MembershipStatus.active,
    this.caption,
    this.inCard = false,
    this.onMenu,
    this.menuKey,
    super.key,
  }) : assert(
         (onMenu == null) == (menuKey == null),
         'onMenu ve menuKey birlikte verilir',
       );

  /// Amblemi tanınmayan kulübün ikonu.
  static const GuIcons _fallbackIcon = GuIcons.users;

  /// Satırın kulübü (ad, amblem ikonu).
  final ClubModel club;

  /// Satırın aksiyon anahtarı.
  final Key actionKey;

  /// Satıra dokunma (kulübe git / MGT-01).
  final VoidCallback onTap;

  /// Üyelikteki rol; [status] aktifken rozet olarak çizilir.
  final ClubRole role;

  /// Üyelik durumu; aktif değilse durum rozeti çizilir.
  final MembershipStatus status;

  /// Rozetin yanındaki ikincil metin (PRF-03 tarih); `null` → çizilmez.
  final String? caption;

  /// Kart içinde mi (PRF-01; dolgu ve ayraç kartındır).
  final bool inCard;

  /// "Diğer" menüsü (PRF-03); `null` → chevron.
  final VoidCallback? onMenu;

  /// "Diğer" düğmesinin anahtarı.
  final Key? menuKey;

  /// [status] üyeliğinin durum rozeti (prototip `StatusBadge`, `ui.js:68`);
  /// aktif üyelik rol rozeti taşır ([MemberRow.roleBadge]). Kendi ayrılan
  /// üyeliğin tasarımda rozeti yoktur: nötr "Geçmiş" görünümü + "Ayrıldı".
  static Widget badgeOf(
    AppLocalizations l10n, {
    required MembershipStatus status,
    required ClubRole role,
  }) => switch (status) {
    MembershipStatus.active => MemberRow.roleBadge(l10n, role),
    MembershipStatus.pending => GuStatusBadge(
      kind: GuStatusBadgeKind.pending,
      label: l10n.statusPending,
    ),
    MembershipStatus.rejected => GuStatusBadge(
      kind: GuStatusBadgeKind.rejected,
      label: l10n.statusRejected,
    ),
    MembershipStatus.removed => GuStatusBadge(
      kind: GuStatusBadgeKind.removed,
      label: l10n.statusRemoved,
    ),
    MembershipStatus.cancelled => GuStatusBadge(
      kind: GuStatusBadgeKind.cancelled,
      label: l10n.statusCancelled,
    ),
    MembershipStatus.left => GuStatusBadge(
      kind: GuStatusBadgeKind.past,
      label: l10n.statusLeft,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final caption = this.caption;
    final onMenu = this.onMenu;
    return GuTile(
      key: actionKey,
      leading: GuEmblem(icon: CoverMapper.icon(club.iconName) ?? _fallbackIcon),
      title: club.name,
      sub2Widget: Wrap(
        spacing: GuSpacing.s6,
        runSpacing: GuSpacing.s2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          badgeOf(l10n, status: status, role: role),
          if (caption != null) Text(caption),
        ],
      ),
      trailing: onMenu == null
          ? null
          : GuIconButton(
              key: menuKey,
              icon: GuIcons.moreVertical,
              semanticLabel: l10n.a11yMore,
              onPressed: onMenu,
            ),
      chevron: onMenu == null,
      padding: inCard ? GuTilePadding.inCard : GuTilePadding.normal,
      onTap: onTap,
    );
  }
}
