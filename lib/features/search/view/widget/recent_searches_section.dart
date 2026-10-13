import 'package:flutter/widgets.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_ui/gu_ui.dart';

/// CLB-02 "Son aramalar" bölümü — prototip `screens-clubs.js:48`: başlık +
/// "Temizle" eylemi, altında her arama için bir satır (`history` ikonu,
/// terim, sonda "Kaldır" düğmesi).
///
/// Bölüm kaydırma alanının ilk öğesidir: başlığın üst boşluğu
/// `.section-title:first-child` (8). Liste boşken çağıran bölümü çizmez.
///
/// Anahtarlar çağırandan gelir (D-18): [clearKey] `CLB-02.clearRecent`,
/// [rowKeyOf] `CLB-02.recent.<i>`, [removeKeyOf] `CLB-02.removeRecent.<i>`.
class RecentSearchesSection extends StatelessWidget {
  /// [recent] aramalarının bölümü (en yeni önde).
  const RecentSearchesSection({
    required this.recent,
    required this.onPick,
    required this.onRemove,
    required this.onClear,
    required this.clearKey,
    required this.rowKeyOf,
    required this.removeKeyOf,
    super.key,
  });

  /// Son aramalar.
  final List<String> recent;

  /// Satıra dokunma: terim arama alanına yazılır.
  final ValueChanged<String> onPick;

  /// "Kaldır": terim listeden çıkar.
  final ValueChanged<String> onRemove;

  /// "Temizle": tüm liste silinir (TST-06).
  final VoidCallback onClear;

  /// "Temizle" düğmesinin anahtarı.
  final Key clearKey;

  /// Verilen sıradaki satırın anahtarı.
  final Key Function(int index) rowKeyOf;

  /// Verilen sıradaki "Kaldır" düğmesinin anahtarı.
  final Key Function(int index) removeKeyOf;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final muted = context.gu.colors.textMuted;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GuSectionTitle(
          title: l10n.searchRecent,
          actionLabel: l10n.commonClear,
          onAction: onClear,
          actionKey: clearKey,
          topMargin: GuSectionTitleMargin.first,
        ),
        for (final (index, term) in recent.indexed)
          GuTile(
            key: rowKeyOf(index),
            leading: GuIcon(
              GuIcons.history,
              size: GuSizes.icon20,
              color: muted,
            ),
            title: term,
            onTap: () => onPick(term),
            trailing: GuIconButton(
              key: removeKeyOf(index),
              icon: GuIcons.x,
              semanticLabel: l10n.commonRemove,
              size: GuIconButtonSize.sm,
              onPressed: () => onRemove(term),
            ),
          ),
      ],
    );
  }
}
