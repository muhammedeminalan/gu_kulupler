// T-04 · rozet / avatar grubu galeri golden'ı
// (`gu_gallery_badges__default__*.png`): GuBadge, GuRoleBadge, GuStatusBadge,
// GuAvatar, GuAvatarGroup. Referans: `ds_badges.webp` (pages-ds.js:32 — 5 rol,
// 8 durum, avatar 24–96 + `u_long` + `u_deniz`, grup 28 "+227").
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/golden_helper.dart';

const List<GuAvatarData> _members = [
  GuAvatarData(initials: 'BŞ', seed: 'u_burak'),
  GuAvatarData(initials: 'DY', seed: 'u_derya'),
  GuAvatarData(initials: 'EY', seed: 'u_emre'),
  GuAvatarData(initials: 'EU', seed: 'u_elif'),
  GuAvatarData(initials: 'ZK', seed: 'u_zeynep'),
];

class _Gallery extends StatelessWidget {
  const _Gallery();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      // DS sayfası rozetleri kart (bg.surface) üstünde gösterir.
      color: context.gu.colors.bgSurface,
      child: Padding(
        padding: GuInsets.all12,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Roller (ROLE_BADGE 5).
            const Wrap(
              spacing: GuSpacing.s6,
              runSpacing: GuSpacing.s8,
              children: [
                GuRoleBadge(kind: GuRoleBadgeKind.president, label: 'Başkan'),
                GuRoleBadge(
                  kind: GuRoleBadgeKind.board,
                  label: 'Yönetim Kurulu',
                ),
                GuRoleBadge(kind: GuRoleBadgeKind.advisor, label: 'Danışman'),
                GuRoleBadge(kind: GuRoleBadgeKind.member, label: 'Üye'),
                GuRoleBadge(
                  kind: GuRoleBadgeKind.superadmin,
                  label: 'Süper Admin',
                ),
              ],
            ),
            GuGap.v8,
            // Durumlar (DS sayfasındaki 8 + her ikonlu tür: removed, suspended,
            // past, open, used).
            const Wrap(
              spacing: GuSpacing.s6,
              runSpacing: GuSpacing.s8,
              children: [
                GuStatusBadge(
                  kind: GuStatusBadgeKind.pending,
                  label: 'Beklemede',
                ),
                GuStatusBadge(
                  kind: GuStatusBadgeKind.approved,
                  label: 'Onaylandı',
                ),
                GuStatusBadge(
                  kind: GuStatusBadgeKind.rejected,
                  label: 'Reddedildi',
                ),
                GuStatusBadge(kind: GuStatusBadgeKind.full, label: 'Dolu'),
                GuStatusBadge(
                  kind: GuStatusBadgeKind.waitlist,
                  label: 'Bekleme listesi',
                ),
                GuStatusBadge(
                  kind: GuStatusBadgeKind.members,
                  label: 'Üyelere özel',
                ),
                GuStatusBadge(
                  kind: GuStatusBadgeKind.cancelled,
                  label: 'İptal',
                ),
                GuStatusBadge(kind: GuStatusBadgeKind.draft, label: 'Taslak'),
                GuStatusBadge(
                  kind: GuStatusBadgeKind.removed,
                  label: 'Çıkarıldı',
                ),
                GuStatusBadge(
                  kind: GuStatusBadgeKind.suspended,
                  label: 'Askıda',
                ),
                GuStatusBadge(kind: GuStatusBadgeKind.past, label: 'Geçmiş'),
                GuStatusBadge(kind: GuStatusBadgeKind.open, label: 'Açık'),
                GuStatusBadge(kind: GuStatusBadgeKind.used, label: 'Okutuldu'),
              ],
            ),
            GuGap.v8,
            // Düz rozetler: ikonsuz neutral, ikonlu info / president, brand.
            const Wrap(
              spacing: GuSpacing.s6,
              runSpacing: GuSpacing.s8,
              children: [
                GuBadge(label: 'Spor ve Doğa'),
                GuBadge(
                  label: 'Onay gerekli',
                  kind: GuBadgeKind.info,
                  icon: GuIcons.shieldCheck,
                ),
                GuBadge(
                  label: 'Duyuru',
                  kind: GuBadgeKind.president,
                  icon: GuIcons.megaphone,
                ),
                GuBadge(
                  label: 'Anında katılım',
                  kind: GuBadgeKind.success,
                  icon: GuIcons.circleCheck,
                ),
                GuBadge(label: 'Marka', kind: GuBadgeKind.brand),
              ],
            ),
            GuGap.v16,
            // Avatarlar: `u_ayse` 30 → 96, `u_long`, `u_deniz` (pages-ds.js:32).
            const Wrap(
              spacing: GuSpacing.s12,
              runSpacing: GuSpacing.s12,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                GuAvatar(initials: 'AD', seed: 'u_ayse', size: 30),
                GuAvatar(initials: 'AD', seed: 'u_ayse', size: 32),
                GuAvatar(initials: 'AD', seed: 'u_ayse'),
                GuAvatar(initials: 'AD', seed: 'u_ayse', size: 56),
                GuAvatar(initials: 'AD', seed: 'u_ayse', size: 96),
                GuAvatar(initials: 'MA', seed: 'u_long'),
                GuAvatar(initials: 'D', seed: 'u_deniz'),
              ],
            ),
            GuGap.v16,
            // Gruplar: 28 "+227" (CLB-03), 24 × 3 "+228" (ClubCard), 32 "+12"
            // (EVT-02), hapsız.
            Wrap(
              spacing: GuSpacing.s16,
              runSpacing: GuSpacing.s12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const GuAvatarGroup(avatars: _members, moreLabel: '+227'),
                const GuAvatarGroup(
                  avatars: _members,
                  moreLabel: '+228',
                  size: 24,
                  max: 3,
                ),
                const GuAvatarGroup(
                  avatars: _members,
                  moreLabel: '+12',
                  size: 32,
                ),
                GuAvatarGroup(avatars: _members.sublist(0, 3)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  testWidgets('T-04 · rozet / avatar grubu · galeri golden (açık + koyu)', (
    tester,
  ) async {
    await goldenForWidget(tester, 'gu_gallery_badges', {
      'default': const _Gallery(),
    });
  });
}
