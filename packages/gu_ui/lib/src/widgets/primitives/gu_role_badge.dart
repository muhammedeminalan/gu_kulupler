import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/icons/gu_icons.dart';
import 'package:gu_ui/src/widgets/primitives/gu_badge.dart';

/// Rol rozeti türü — prototip `ROLE_BADGE` (`ui.js:64` =
/// `registry.json#roleBadge`, 5 rol): rozet sınıfı + ikon.
enum GuRoleBadgeKind {
  /// `badge-president` + `crown`.
  president(GuBadgeKind.president, GuIcons.crown),

  /// `badge-board` + `shield-check`.
  board(GuBadgeKind.board, GuIcons.shieldCheck),

  /// `badge-advisor` + `graduation-cap`.
  advisor(GuBadgeKind.advisor, GuIcons.graduationCap),

  /// `badge-member` + `user-check`.
  member(GuBadgeKind.member, GuIcons.userCheck),

  /// `badge-superadmin` + `badge-check`.
  superadmin(GuBadgeKind.superadmin, GuIcons.badgeCheck);

  const GuRoleBadgeKind(this.badgeKind, this.icon);

  /// Rozet gövdesinin renk türü (CSS `.badge-<rol>`, css:189–193).
  final GuBadgeKind badgeKind;

  /// Rol ikonu (12 px).
  final GuIcons icon;
}

/// Rol rozeti — prototip `RoleBadge` (`ui.js:67`), CSS `.badge` +
/// `.badge-<rol>` (css:188–193). Kendi gövdesi yoktur: [GuBadge]'i türün
/// rengi ve ikonu ile sarar (CD-27).
///
/// Metin (`role.<id>`) çağırandan gelir; alan rolü → tür eşlemesi ürün
/// katmanındadır (`role_badge_mapper.dart`, T-16).
class GuRoleBadge extends StatelessWidget {
  const GuRoleBadge({required this.kind, required this.label, super.key});

  /// Rol türü (renk + ikon).
  final GuRoleBadgeKind kind;

  /// Rol adı (çağıran ARB'den verir).
  final String label;

  @override
  Widget build(BuildContext context) =>
      GuBadge(label: label, kind: kind.badgeKind, icon: kind.icon);
}
