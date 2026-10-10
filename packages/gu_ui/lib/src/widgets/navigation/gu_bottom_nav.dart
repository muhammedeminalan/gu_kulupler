import 'dart:ui' show SemanticsRole;

import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/icons/gu_icon.dart';
import 'package:gu_ui/src/icons/gu_icons.dart';
import 'package:gu_ui/src/tokens/gu_motion.dart';
import 'package:gu_ui/src/tokens/gu_radius.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';
import 'package:gu_ui/src/widgets/primitives/gu_action_surface.dart';
import 'package:gu_ui/src/widgets/primitives/gu_count_badge.dart';

/// [GuBottomNav] sekmesi — prototip `tabs.map` (`shell.js:12`).
@immutable
class GuBottomNavItem {
  const GuBottomNavItem({required this.icon, required this.label, this.badge});

  /// Sekme ikonu (24).
  final GuIcons icon;

  /// Sekme etiketi (çağırandan; ARB `nav.*`).
  final String label;

  /// Sayaç rozeti metni; `null` → rozet yok. "9+" sınırı çağırandadır
  /// (`countBadgeLabel`, CD-81).
  final String? badge;
}

/// Alt sekme çubuğu — prototip `BottomNav` (`shell.js:11`), CSS `.bottomnav`
/// `.nav-badge` (css:133–137).
///
/// * Zemin `bg.surface`, üstte 1 px `border.soft`; sekmeler eşit genişlikte,
///   ikon 24 + etiket (Inter 600 11, tek satır `…`), aralık 3.
/// * Yükseklik `GuSizes.bottomNavHeight` (56, kenarlık dahil) + gerçek
///   `MediaQuery.viewPadding.bottom` (K-07; CSS `--nav-h` 84 = 56 + 28
///   maket). Tam genişliktir (CD-29).
/// * Seçili ([currentIndex]): renk `brand.primaryText` + üstte 28×3
///   `brand.primary` gösterge (alt köşeler 3); diğerleri `text.muted`. Renk
///   `GuMotion.fast` ile geçer. Basılı görünüm yoktur (CD-82); klavye odağı
///   2 px `focus.ring`.
/// * [GuBottomNavItem.badge] → `GuCountBadge(sm, ring: true)`; üst 6, sol
///   `%50 + 4` (css:137).
/// * Semantik: kap `navigation` + [semanticLabel] (`a11y.mainNav`); sekme
///   düğme + `selected` (`aria-current="page"`).
/// * [onTap] seçili sekmede de çağrılır (köke dön / başa kaydır kabuğun işi,
///   navigation.md §4). `admin` sekmesini çağıran süzer (4 / 5 sekme).
/// * Sekme anahtarı çağırandan ([tabKeyBuilder]:
///   `(i) => GuKey.action('NAV.tab.<ad>')`, CD-111).
class GuBottomNav extends StatelessWidget {
  const GuBottomNav({
    required this.items,
    required this.currentIndex,
    required this.onTap,
    required this.semanticLabel,
    this.tabKeyBuilder,
    super.key,
  });

  /// Sekmeler (4–5).
  final List<GuBottomNavItem> items;

  /// Seçili sekmenin sırası.
  final int currentIndex;

  /// Sekmeye dokunma.
  final ValueChanged<int> onTap;

  /// Çubuğun erişilebilirlik etiketi (`aria-label`, shell.js:12).
  final String semanticLabel;

  /// Sekme anahtarı üreticisi.
  final Key Function(int index)? tabKeyBuilder;

  @override
  Widget build(BuildContext context) {
    final colors = context.gu.colors;
    return Semantics(
      role: SemanticsRole.navigation,
      container: true,
      explicitChildNodes: true,
      label: semanticLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.bgSurface,
          border: Border(
            top: BorderSide(
              color: colors.borderSoft,
              // Token değeri varsayılanla (1) aynı; kaynak token kalır.
              // ignore: avoid_redundant_argument_values
              width: GuSizes.bottomNavBorder,
            ),
          ),
        ),
        child: Padding(
          padding: GuInsets.only(
            top: GuSizes.bottomNavBorder,
            bottom: MediaQuery.viewPaddingOf(context).bottom,
          ),
          child: Row(
            children: [
              for (var index = 0; index < items.length; index++)
                Expanded(
                  child: _GuBottomNavTab(
                    key: tabKeyBuilder?.call(index),
                    item: items[index],
                    selected: index == currentIndex,
                    onTap: () => onTap(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tek sekme — CSS `.bottomnav>button` (css:134–136).
class _GuBottomNavTab extends StatelessWidget {
  const _GuBottomNavTab({
    required this.item,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final GuBottomNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GuActionSurface(
    onTap: onTap,
    selected: selected,
    // css:82 `:focus-visible{border-radius:6px}`.
    borderRadius: GuRadius.borderCheckbox,
    builder: _buildVisual,
  );

  Widget _buildVisual(BuildContext context, bool _) {
    final gu = context.gu;
    final colors = gu.colors;
    final badge = item.badge;
    return Stack(
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: GuSizes.bottomNavHeight - GuSizes.bottomNavBorder,
          ),
          child: Center(
            heightFactor: 1,
            child: TweenAnimationBuilder<Color?>(
              tween: ColorTween(
                end: selected ? colors.brandPrimaryText : colors.textMuted,
              ),
              duration: gu.duration(GuMotion.fast),
              curve: GuMotion.easeCss,
              builder: (context, color, _) => Column(
                mainAxisSize: MainAxisSize.min,
                spacing: GuSizes.bottomNavGap,
                children: [
                  GuIcon(
                    item.icon,
                    // Token değeri varsayılanla (24) aynı; kaynak token kalır.
                    // ignore: avoid_redundant_argument_values
                    size: GuSizes.bottomNavIcon,
                    color: color,
                  ),
                  Text(
                    item.label,
                    style: gu.text.navLabel.copyWith(color: color),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (selected)
          Positioned(
            top: 0,
            child: SizedBox(
              width: GuSizes.bottomNavIndicatorWidth,
              height: GuSizes.bottomNavIndicatorHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.brandPrimary,
                  borderRadius: GuRadius.navIndicator,
                ),
              ),
            ),
          ),
        if (badge != null)
          // css:137 `left:calc(50% + 4px)`: sağ yarının başından 4 px sonra.
          Positioned(
            top: GuSizes.navBadgeTop,
            left: 0,
            right: 0,
            child: Row(
              children: [
                const Spacer(),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: GuInsets.only(left: GuSizes.navBadgeOffsetX),
                      child: GuCountBadge(label: badge, ring: true),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
