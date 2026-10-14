import 'package:flutter/widgets.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/l10n/static_labels.dart';
import 'package:gu_kulupler/product/widget/member/member_row.dart';
import 'package:gu_ui/gu_ui.dart';

/// CLB-07 profil başlığı — prototip `UserProfileScreen` başlık sütunu
/// (`screens-clubs.js:157`): avatar 96 · ad (titleL) · bölüm · sınıf (bodyM
/// `text.secondary`) · "Süper Admin" rozeti · ortak kulüplerdeki üye dışı
/// roller (rozetler, aralık 6, sarar) · biyografi (bodyS `text.secondary`,
/// en çok 280 dp). Hepsi ortalı, aralık 8; dolgu yatay 16, üst 16.
///
/// * Bölüm / sınıf ve biyografi yalnızca [showDetails] `true` iken çizilir:
///   ortak kulüp yoksa gizlenir (D-29, S-1; prototip `visible`).
/// * Silinmiş (anonimleştirilmiş) kullanıcının adı "Silinmiş kullanıcı"dır;
///   ayrıntıları çizilmez.
/// * Statiktir: dokunma ve aksiyon anahtarı yoktur.
///
/// ```dart
/// UserProfileHeader(
///   user: state.user!,
///   showDetails: state.showsDetails,
///   isSuperAdmin: state.isSuperAdmin,
///   roles: state.roles,
/// )
/// ```
class UserProfileHeader extends StatelessWidget {
  /// [user] kullanıcısının başlığı.
  const UserProfileHeader({
    required this.user,
    this.showDetails = true,
    this.isSuperAdmin = false,
    this.roles = const [],
    this.avatarImage,
    super.key,
  });

  /// Profili gösterilen kullanıcı.
  final UserModel user;

  /// Bölüm / sınıf ve biyografi çizilsin mi (profil görünür mü).
  final bool showDetails;

  /// "Süper Admin" rozeti çizilsin mi.
  final bool isSuperAdmin;

  /// Kulüp rolleri (rozetler); boşsa satır çizilmez.
  final List<ClubRole> roles;

  /// Profil fotoğrafı (`users.avatarPath`; çağıran `ref.userAvatarImage`
  /// ile çözer, T-27). `null` ya da silinmiş kullanıcı → baş harfler.
  final ImageProvider? avatarImage;

  /// `screens-clubs.js:157` `Avatar size=96` — `GuSizes.avatarSizes`
  /// (30 · 32 · 36 · 40 · 44 · 48 · 56 · 96 · 120) içindeki CLB-07 değeri.
  static final double avatarSize = GuSizes.avatarSizes[7];

  static const String _separator = ' · ';

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final isDeleted = user.isDeleted || user.isAnonymized;
    final name = isDeleted ? l10n.commonDeletedUser : user.name;
    final details = showDetails && !isDeleted;
    final department = user.department;
    final year = user.year;
    final departmentAndYear = [
      if (department != null) StaticLabels.department(context, department),
      if (year != null) StaticLabels.year(context, year),
    ].join(_separator);
    final secondary = gu.colors.textSecondary;
    return Padding(
      padding: GuInsets.only(
        left: GuSpacing.s16,
        top: GuSpacing.s16,
        right: GuSpacing.s16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: GuSpacing.s8,
        children: [
          GuAvatar(
            initials: name.initials,
            seed: user.avatarSeed,
            size: avatarSize,
            image: isDeleted ? null : avatarImage,
          ),
          Semantics(
            header: true,
            child: Text(
              name,
              style: gu.text.titleL,
              textAlign: TextAlign.center,
            ),
          ),
          if (details && departmentAndYear.isNotEmpty)
            Text(
              departmentAndYear,
              style: gu.text.bodyM.copyWith(color: secondary),
              textAlign: TextAlign.center,
            ),
          if (isSuperAdmin)
            GuRoleBadge(
              kind: GuRoleBadgeKind.superadmin,
              label: l10n.roleSuperadmin,
            ),
          if (roles.isNotEmpty)
            Wrap(
              alignment: WrapAlignment.center,
              spacing: GuSpacing.s6,
              runSpacing: GuSpacing.s6,
              children: [
                for (final role in roles) MemberRow.roleBadge(l10n, role),
              ],
            ),
          if (details && user.bio.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: GuSizes.emptyDescMaxWidth,
              ),
              child: Text(
                user.bio,
                style: gu.text.bodyS.copyWith(color: secondary),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
