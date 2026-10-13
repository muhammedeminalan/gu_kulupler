import 'package:flutter/widgets.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_ui/gu_ui.dart';

/// CLB-03 "Üyeler" sekmesi (kulübün içini görenler) — prototip
/// `screens-clubs.js:106`: "{n} üye" (`labelL`, `text.secondary`) · ilk beş
/// üye satırı · "Tüm üyeler" (çerçeveli, tam genişlik, sağda ok —
/// `CLB-03.allMembers`).
///
/// Üye satırları (`MemberRow`) ve üye listesi ekranı (CLB-06) T-18'de gelir
/// (W-11); bu sürüm sayıyı ve düğmeyi çizer.
class ClubMembersTab extends StatelessWidget {
  /// [memberCount] üyeli kulübün üyeler sekmesi.
  const ClubMembersTab({
    required this.memberCount,
    required this.onAllMembers,
    this.allMembersKey,
    super.key,
  });

  /// Aktif üye sayısı (`clubs.memberCount`).
  final int memberCount;

  /// "Tüm üyeler" (`CLB-03.allMembers`).
  final VoidCallback onAllMembers;

  /// "Tüm üyeler" düğmesinin anahtarı.
  final Key? allMembersKey;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    return Padding(
      padding: GuInsets.only(
        left: GuSpacing.s16,
        top: GuSpacing.s16,
        right: GuSpacing.s16,
        bottom: GuSpacing.s24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: GuSpacing.s8,
        children: [
          Text(
            l10n.clubsCardMembers(memberCount),
            style: gu.text.labelL.copyWith(
              color: gu.colors.textSecondary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          // TODO(T-18): ilk beş üye — `MemberRow` satırları (W-11).
          GuButton(
            key: allMembersKey,
            label: l10n.clubAllMembers,
            iconTrailing: GuIcons.arrowRight,
            variant: GuButtonVariant.outline,
            full: true,
            onPressed: onAllMembers,
          ),
        ],
      ),
    );
  }
}
