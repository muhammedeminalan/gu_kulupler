import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/tokens/gu_radius.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';

/// Sayaç pili boyutu (CD-81).
enum GuCountBadgeSize {
  /// 18 px, yatay dolgu 5 — `.nav-badge` (css:137), `.dot-badge` (css:157),
  /// `.chip-count` (css:186); tipografi `countBadge` (11/18).
  sm(
    GuSizes.chipCountMinWidth,
    GuSizes.chipCountHeight,
    GuSizes.chipCountPaddingX,
  ),

  /// 20 px, yatay dolgu 6 — `.badge-count` (css:200); tipografi
  /// `countBadgeLg` (11/20).
  md(
    GuSizes.countBadgeMinWidth,
    GuSizes.countBadgeHeight,
    GuSizes.countBadgePaddingX,
  );

  const GuCountBadgeSize(this.minWidth, this.height, this.paddingX);

  /// En küçük genişlik (dp).
  final double minWidth;

  /// Yükseklik (dp).
  final double height;

  /// Yatay iç dolgu (dp).
  final double paddingX;
}

/// Sayaç pili tonu (CD-81).
enum GuCountBadgeTone {
  /// `brand.primary` zemin + `brand.onPrimary` metin (varsayılan).
  brand,

  /// `text.muted` zemin — MGT-06 bekleme sırası (`screens-manage.js:135`).
  muted,

  /// `brand.onPrimary` zemin + `brand.primary` metin — koyu temada seçili çip
  /// (css:183).
  inverted,
}

/// Sayı rozeti — CSS `.badge-count` / `.nav-badge` / `.dot-badge` /
/// `.chip-count` (css:200, 137, 157, 186) tek pilde (CD-81, G8; prototipte
/// ayrı bileşen yok). `GuTabs`, `GuChip`, `GuIconButton.badge` ve
/// `GuBottomNav` bunu kullanır.
///
/// * [label] çağırandan gelir; "9+" sınırı ürün katmanındadır
///   (`countBadgeLabel`, T-11).
/// * [ring] → 2 px `bg.surface` halka (`.nav-badge`, `box-sizing:content-box`:
///   dış ölçü 4 px büyür).
/// * Metin ölçeklenmez (K-57): `TextScaler.noScaling`.
class GuCountBadge extends StatelessWidget {
  const GuCountBadge({
    required this.label,
    this.size = GuCountBadgeSize.sm,
    this.tone = GuCountBadgeTone.brand,
    this.ring = false,
    super.key,
  });

  /// Rozet metni (sayı ya da "9+").
  final String label;

  /// Boyut varyantı.
  final GuCountBadgeSize size;

  /// Renk tonu.
  final GuCountBadgeTone tone;

  /// `bg.surface` halka (alt sekme rozeti).
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final colors = gu.colors;
    final (background, foreground) = switch (tone) {
      GuCountBadgeTone.brand => (colors.brandPrimary, colors.brandOnPrimary),
      GuCountBadgeTone.muted => (colors.textMuted, colors.brandOnPrimary),
      GuCountBadgeTone.inverted => (colors.brandOnPrimary, colors.brandPrimary),
    };
    final style = switch (size) {
      GuCountBadgeSize.sm => gu.text.countBadge,
      GuCountBadgeSize.md => gu.text.countBadgeLg,
    };
    final pill = ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: size.minWidth,
        minHeight: size.height,
        maxHeight: size.height,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: GuRadius.borderFull,
        ),
        child: Padding(
          padding: GuInsets.sym(h: size.paddingX),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: style.copyWith(color: foreground),
              textScaler: TextScaler.noScaling,
              textAlign: TextAlign.center,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
    if (!ring) return pill;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: GuRadius.borderFull,
      ),
      child: Padding(
        padding: GuInsets.sym(
          h: GuSizes.navBadgeBorder,
          v: GuSizes.navBadgeBorder,
        ),
        child: pill,
      ),
    );
  }
}
