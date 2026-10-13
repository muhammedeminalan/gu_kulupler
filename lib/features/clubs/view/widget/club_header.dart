import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/l10n/static_labels.dart';
import 'package:gu_kulupler/product/widget/club/cover_mapper.dart';
import 'package:gu_kulupler/product/widget/member/member_row.dart';
import 'package:gu_ui/gu_ui.dart';

/// CLB-03 "Kulüp" ekranının başlığı — prototip `screens-clubs.js:86–92`:
/// parallax kapak + üst çubuk, durum bantları, amblem, ad, rozetler ve üye
/// sayısı.
///
/// * Kapak 220 dp, ekranın en üstünden başlar (durum çubuğunun altına
///   uzanır): başlık, kaydırma alanında üst güvenli alan kadar aşağıda
///   durur ve kapağı o kadar yukarı taşırır. Üst çubuk: geri — boşluk —
///   paylaş — menü (`GuIconButton(onCover)`).
/// * Bantlar kapağın hemen altındadır: askıdaki kulüp → uyarı
///   ("Bu kulüp geçici olarak askıda."), danışman → salt okunur bandı.
/// * Amblem 72 dp, önceki öğenin üstüne 36 dp taşar (`margin-top:-36px`).
/// * Ad `titleL`; rozetler: kategori, katılım türü ("Onay gerekli" /
///   "Anında katılım") ve — aktif üyede — rol.
/// * Üye sayısı satırı düğmedir (`CLB-03.memberCount` → Üyeler sekmesi):
///   [memberPreview] doluysa avatar grubu + "+N", ardından "{n} üye".
///   Üyelik belgeleri yalnızca kulübün içini görenlere okunur; ziyaretçide
///   avatar çizilmez.
///
/// Anahtarlar çağırandan gelir (D-18): [backKey], [shareKey], [menuKey],
/// [memberCountKey].
class ClubHeader extends StatelessWidget {
  /// [club] kulübünün başlığı.
  const ClubHeader({
    required this.club,
    required this.scrollOffset,
    required this.onBack,
    required this.onShare,
    required this.onMenu,
    required this.onMemberCount,
    this.role,
    this.isAdvisor = false,
    this.memberPreview = const [],
    this.backKey,
    this.shareKey,
    this.menuKey,
    this.memberCountKey,
    super.key,
  });

  /// Kulüp.
  final ClubModel club;

  /// Sayfanın kaydırma ofseti (parallax).
  final ValueListenable<double> scrollOffset;

  /// Kullanıcının kulüpteki aktif rolü (rol rozeti); aktif üyelik yoksa
  /// `null`.
  final ClubRole? role;

  /// Kullanıcı danışman mı (salt okunur bandı)?
  final bool isAdvisor;

  /// Avatar grubunda gösterilecek aktif üyeler (ilk dördü çizilir).
  final List<MembershipModel> memberPreview;

  /// Geri (`CLB-03.back`).
  final VoidCallback onBack;

  /// Paylaş (`CLB-03.share`).
  final VoidCallback onShare;

  /// Menü (`CLB-03.menu`).
  final VoidCallback onMenu;

  /// Üye sayısı satırı (`CLB-03.memberCount`).
  final VoidCallback onMemberCount;

  /// Geri düğmesinin anahtarı.
  final Key? backKey;

  /// Paylaş düğmesinin anahtarı.
  final Key? shareKey;

  /// Menü düğmesinin anahtarı.
  final Key? menuKey;

  /// Üye sayısı satırının anahtarı.
  final Key? memberCountKey;

  /// Kulüp ikonu kayıtta yoksa amblemde çizilen ikon (kapak şablonunun
  /// gömülü ikonu — CD-124).
  static const GuIcons fallbackIcon = GuIcons.sparkles;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final colors = gu.colors;
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final role = this.role;
    final members = l10n.clubsCardMembers(club.memberCount);
    final shown = memberPreview.take(GuSizes.avatarGroupMax).toList();
    final rest = club.memberCount - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Kaydırma alanı üst güvenli alanın altından başlar; kapak o kadar
        // yukarı taşarak ekranın tepesine ulaşır.
        SizedBox(
          height: math.max(0, GuSizes.parallaxHeight - topInset),
          child: OverflowBox(
            alignment: Alignment.bottomCenter,
            minHeight: GuSizes.parallaxHeight,
            maxHeight: GuSizes.parallaxHeight,
            child: GuParallaxHeader(
              scrollOffset: scrollOffset,
              cover: CoverMapper.club(club, ratio: GuCoverRatio.fill),
              leading: GuIconButton(
                key: backKey,
                icon: GuIcons.arrowLeft,
                semanticLabel: l10n.a11yBack,
                onCover: true,
                onPressed: onBack,
              ),
              actions: [
                GuIconButton(
                  key: shareKey,
                  icon: GuIcons.share2,
                  semanticLabel: l10n.commonShare,
                  onCover: true,
                  onPressed: onShare,
                ),
                GuIconButton(
                  key: menuKey,
                  icon: GuIcons.moreVertical,
                  semanticLabel: l10n.a11yMore,
                  onCover: true,
                  onPressed: onMenu,
                ),
              ],
            ),
          ),
        ),
        if (club.isSuspended)
          GuBanner(
            kind: GuBannerKind.warning,
            icon: GuIcons.ban,
            text: l10n.clubSuspendedBanner,
          ),
        if (isAdvisor)
          GuBanner(
            kind: GuBannerKind.readonly,
            text: l10n.mgtReadOnlyBanner,
          ),
        Padding(
          padding: GuInsets.h16,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: SizedBox(
              width: GuSizes.emblem,
              height: GuSizes.emblem - GuSizes.parallaxEmblemOverlap,
              child: OverflowBox(
                alignment: Alignment.bottomCenter,
                minHeight: GuSizes.emblem,
                maxHeight: GuSizes.emblem,
                child: GuEmblem(
                  icon: CoverMapper.icon(club.iconName) ?? fallbackIcon,
                  size: GuEmblemSize.lg,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: GuInsets.only(
            left: GuSpacing.s16,
            top: GuSpacing.s8,
            right: GuSpacing.s16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: GuSpacing.s8,
            children: [
              Semantics(
                header: true,
                child: Text(club.name, style: gu.text.titleL),
              ),
              Wrap(
                spacing: GuSpacing.s6,
                runSpacing: GuSpacing.s6,
                children: [
                  GuBadge(
                    label: StaticLabels.category(context, club.categoryId),
                  ),
                  if (club.approvalRequired)
                    GuBadge(
                      label: l10n.clubTypeApproval,
                      kind: GuBadgeKind.info,
                      icon: GuIcons.shieldCheck,
                    )
                  else
                    GuBadge(
                      label: l10n.clubTypeInstant,
                      kind: GuBadgeKind.success,
                      icon: GuIcons.sparkles,
                    ),
                  if (role != null) MemberRow.roleBadge(l10n, role),
                ],
              ),
              GuTapTarget(
                key: memberCountKey,
                onTap: onMemberCount,
                semanticLabel: members,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: GuSpacing.s8,
                  children: [
                    if (shown.isNotEmpty)
                      GuAvatarGroup(
                        avatars: [
                          for (final member in shown)
                            GuAvatarData(
                              initials: member.applicant.name.initials,
                              seed: member.applicant.avatarSeed,
                            ),
                        ],
                        moreLabel: rest > 0 ? '+$rest' : null,
                      ),
                    Flexible(
                      child: Text(
                        members,
                        style: gu.text.bodyS.copyWith(
                          color: colors.textSecondary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
