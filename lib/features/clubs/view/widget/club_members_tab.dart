import 'package:flutter/widgets.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/widget/member/member_row.dart';
import 'package:gu_ui/gu_ui.dart';

/// CLB-03 "Üyeler" sekmesi (kulübün içini görenler) — prototip
/// `screens-clubs.js:106`: "{n} üye" (`labelL`, `text.secondary`) · ilk beş
/// üye satırı (`MemberRow`, tam genişlik — `CLB-03.member.<userId>`, CLB-07'ye
/// gider) · "Tüm üyeler" (çerçeveli, tam genişlik, sağda ok —
/// `CLB-03.allMembers`, CLB-06'ya gider).
///
/// Üst 16, alt 24 dolgulu sütun, öğeler arası 8; sayı ve düğme yatay 16
/// dolguludur, satırlar kendi dolgusunu taşır. Anahtarlar çağırandan gelir
/// (D-18).
class ClubMembersTab extends StatelessWidget {
  /// [memberCount] üyeli kulübün üyeler sekmesi; [members] önizlemedir.
  const ClubMembersTab({
    required this.memberCount,
    required this.onMember,
    required this.onAllMembers,
    required this.memberKeyOf,
    this.members = const [],
    this.allMembersKey,
    super.key,
  });

  /// Aktif üye sayısı (`clubs.memberCount`).
  final int memberCount;

  /// Önizlenen üyeler (ilk beş — `ClubDetailState.memberPreviewLimit`).
  final List<MembershipModel> members;

  /// Üye satırı (`CLB-03.member.<userId>`).
  final ValueChanged<String> onMember;

  /// "Tüm üyeler" (`CLB-03.allMembers`).
  final VoidCallback onAllMembers;

  /// Üye satırının anahtarı (`CLB-03.member.<userId>`).
  final Key Function(String userId) memberKeyOf;

  /// "Tüm üyeler" düğmesinin anahtarı.
  final Key? allMembersKey;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    return Padding(
      padding: GuInsets.only(top: GuSpacing.s16, bottom: GuSpacing.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: GuSpacing.s8,
        children: [
          Padding(
            padding: GuInsets.h16,
            child: Text(
              l10n.clubsCardMembers(memberCount),
              style: gu.text.labelL.copyWith(
                color: gu.colors.textSecondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          for (final member in members)
            MemberRow(
              membership: member,
              actionKey: memberKeyOf(member.userId),
              onTap: () => onMember(member.userId),
            ),
          Padding(
            padding: GuInsets.h16,
            child: GuButton(
              key: allMembersKey,
              label: l10n.clubAllMembers,
              iconTrailing: GuIcons.arrowRight,
              variant: GuButtonVariant.outline,
              full: true,
              onPressed: onAllMembers,
            ),
          ),
        ],
      ),
    );
  }
}
