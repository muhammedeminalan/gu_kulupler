import 'package:flutter/widgets.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_ui/gu_ui.dart';

/// CLB-01 liste başlığı satırı (prototip `screens-clubs.js:28`,
/// `.row.between.px16.pb16`): solda kulüp sayısı (labelL, `text.secondary`,
/// tablo rakamları); sağda (aralık 4) "Filtre / Sırala" (küçük, çerçeveli,
/// `sliders-horizontal`), etkin süzgeç varsa sayaç rozeti ve liste ↔ ızgara
/// düğmesi (`layout-grid` / `list`).
///
/// Dar ekranda / büyük metinde sağ grup alt satıra iner (taşma yok); düğme
/// etiketi gerekirse kısalır. Anahtarlar çağırandan: [filterKey]
/// `CLB-01.filter`, [toggleViewKey] `CLB-01.toggleView`.
class ClubListToolbar extends StatelessWidget {
  /// [count] görünen kulüp sayısı; [activeFilterCount] > 0 ise rozet çizilir.
  const ClubListToolbar({
    required this.count,
    required this.activeFilterCount,
    required this.grid,
    required this.onFilter,
    required this.onToggleView,
    this.filterKey,
    this.toggleViewKey,
    super.key,
  });

  /// Listelenen kulüp sayısı.
  final int count;

  /// Etkin süzgeç sayısı (`ClubFilters.activeCount`).
  final int activeFilterCount;

  /// Izgara görünümü açık mı (düğme "Liste görünümü"ne döner).
  final bool grid;

  /// "Filtre / Sırala" — SHT-04.
  final VoidCallback onFilter;

  /// Liste ↔ ızgara.
  final VoidCallback onToggleView;

  /// "Filtre / Sırala" düğmesinin anahtarı.
  final Key? filterKey;

  /// Görünüm düğmesinin anahtarı.
  final Key? toggleViewKey;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    return Padding(
      padding: GuInsets.only(
        left: GuSpacing.s16,
        right: GuSpacing.s16,
        bottom: GuSpacing.s16,
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: GuSpacing.s8,
        runSpacing: GuSpacing.s8,
        children: [
          Text(
            l10n.clubsCount(count),
            style: gu.text.labelL.copyWith(
              color: gu.colors.textSecondary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: GuSpacing.s4,
            children: [
              Flexible(
                child: GuButton(
                  key: filterKey,
                  label: l10n.commonFilterSort,
                  icon: GuIcons.slidersHorizontal,
                  size: GuButtonSize.sm,
                  variant: GuButtonVariant.outline,
                  onPressed: onFilter,
                ),
              ),
              if (activeFilterCount > 0)
                Semantics(
                  label: l10n.clubsActiveFilters(activeFilterCount),
                  child: ExcludeSemantics(
                    child: GuCountBadge(label: '$activeFilterCount'),
                  ),
                ),
              GuIconButton(
                key: toggleViewKey,
                icon: grid ? GuIcons.list : GuIcons.layoutGrid,
                semanticLabel: grid ? l10n.commonListView : l10n.commonGridView,
                onPressed: onToggleView,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
