import 'package:flutter/widgets.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/profile/view/widget/profile_avatar_button.dart';
import 'package:gu_kulupler/product/widget/member/member_row.dart';
import 'package:gu_ui/gu_ui.dart';

/// PRF-01 profil başlığı — prototip `Profile` başlık satırı
/// (`screens-profile.js:11`): avatar 96 düğmesi + kamera rozeti
/// (`PRF-01.avatar` → SHT-16) · ad (titleM) · bölüm · sınıf (bodyS
/// `text.secondary`) · "Süper Admin" rozeti · "Profili düzenle" düğmesi
/// (`GuButton(sm, outline)`, `PRF-01.edit`). İstatistik kartları
/// (`PRF-01.stat.*`) `ProfileStatsRow`'dadır.
///
/// Yerleşim `.row.gap16` (dikeyde ortalı); metin sütunu `.flex1.col.gap6`,
/// rozet ve düğme içerik genişliğindedir. Avatar + kamera rozeti PRF-02 ile
/// ortak [ProfileAvatarButton]'dır (`bordered`: 2 px `bg.canvas` kenarlık,
/// CD-91).
///
/// Anahtarları çağıran verir ([avatarKey], [editKey]; D-18). Avatar görseli
/// çağıranda `storageImageResolverProvider` ile çözülür ([avatarImage];
/// CD-143).
class ProfileHeader extends StatelessWidget {
  /// [user] kullanıcısının profil başlığı.
  const ProfileHeader({
    required this.user,
    required this.onAvatar,
    required this.onEdit,
    required this.avatarKey,
    required this.editKey,
    this.avatarImage,
    this.isSuperAdmin = false,
    super.key,
  });

  /// Oturumdaki kullanıcı.
  final UserModel user;

  /// Çözülmüş profil fotoğrafı (`avatarPath`); `null` → baş harfler.
  final ImageProvider? avatarImage;

  /// "Süper Admin" rozeti çizilsin mi (claim oturumdadır).
  final bool isSuperAdmin;

  /// Avatar düğmesi (SHT-16 fotoğraf kaynağı).
  final VoidCallback onAvatar;

  /// "Profili düzenle" düğmesi (PRF-02).
  final VoidCallback onEdit;

  /// Avatar düğmesinin anahtarı (`PRF-01.avatar`).
  final Key avatarKey;

  /// "Profili düzenle" düğmesinin anahtarı (`PRF-01.edit`).
  final Key editKey;

  /// `screens-profile.js:11` `Avatar size=96` ([ProfileAvatarButton]).
  static final double avatarSize = ProfileAvatarButton.avatarSize;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final colors = gu.colors;
    final l10n = context.l10n;
    final departmentAndYear = MemberRow.departmentAndYear(
      context,
      department: user.department,
      year: user.year,
    );
    return Row(
      spacing: GuSpacing.s16,
      children: [
        ProfileAvatarButton(
          actionKey: avatarKey,
          initials: user.name.initials,
          seed: user.avatarSeed,
          image: avatarImage,
          semanticLabel: l10n.profileChangePhoto,
          onTap: onAvatar,
          bordered: true,
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: GuSpacing.s6,
            children: [
              Semantics(
                header: true,
                child: Text(user.name, style: gu.text.titleM),
              ),
              if (departmentAndYear.isNotEmpty)
                Text(
                  departmentAndYear,
                  style: gu.text.bodyS.copyWith(color: colors.textSecondary),
                ),
              if (isSuperAdmin)
                GuRoleBadge(
                  kind: GuRoleBadgeKind.superadmin,
                  label: l10n.roleSuperadmin,
                ),
              GuButton(
                key: editKey,
                label: l10n.profileEdit,
                icon: GuIcons.pencil,
                variant: GuButtonVariant.outline,
                size: GuButtonSize.sm,
                onPressed: onEdit,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
