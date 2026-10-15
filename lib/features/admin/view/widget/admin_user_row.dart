import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/media/user_avatar_image.dart';
import 'package:gu_kulupler/product/widget/member/member_row.dart';
import 'package:gu_kulupler/product/widget/member/user_row.dart';
import 'package:gu_ui/gu_ui.dart';

/// ADM-05 kullanıcı satırı — prototip `Tile` (`screens-admin.js:76`):
/// avatar 40 · ad (+ askıdaysa "Askıda" rozeti) · "Bölüm · N. sınıf ·
/// {n} kulüp" · "Diğer" (`more-vertical`). Kabuk `UserRow`'dur (CD-27).
///
/// [clubCount] okunamadıysa (`null`) alt metin yalnızca bölüm · sınıftır.
/// Anahtarları çağıran verir ([actionKey] `ADM-05.row.<id>`, [menuKey]
/// `ADM-05.menu.<id>`; D-18, CD-86).
class AdminUserRow extends ConsumerWidget {
  /// [user] kullanıcısının satırı.
  const AdminUserRow({
    required this.user,
    required this.clubCount,
    required this.actionKey,
    required this.menuKey,
    required this.onTap,
    required this.onMenu,
    super.key,
  });

  /// Alt metin parçalarının ayracı (`' · '`, prototip şablonu).
  static const String _separator = ' · ';

  /// Satırın kullanıcısı.
  final UserModel user;

  /// Etkin üyelik sayısı; okunamadıysa `null`.
  final int? clubCount;

  /// Satırın aksiyon anahtarı.
  final Key actionKey;

  /// "Diğer" düğmesinin anahtarı.
  final Key menuKey;

  /// Satıra dokunma (CLB-07).
  final VoidCallback onTap;

  /// "Diğer" menüsü.
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final clubCount = this.clubCount;
    final sub = [
      MemberRow.departmentAndYear(
        context,
        department: user.department,
        year: user.year,
      ),
      if (clubCount != null) l10n.adminUsersClubCount(clubCount),
    ].where((part) => part.isNotEmpty).join(_separator);
    return UserRow(
      user: user,
      sub: sub,
      avatarImage: ref.userAvatarImage(user, displaySize: GuSizes.avatar),
      badge: user.status == UserStatus.suspended
          ? GuStatusBadge(
              kind: GuStatusBadgeKind.suspended,
              label: l10n.statusSuspended,
            )
          : null,
      trailing: GuIconButton(
        key: menuKey,
        icon: GuIcons.moreVertical,
        semanticLabel: l10n.a11yMore,
        onPressed: onMenu,
      ),
      actionKey: actionKey,
      onTap: onTap,
    );
  }
}
