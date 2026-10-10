import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/icons/gu_icon.dart';
import 'package:gu_ui/src/icons/gu_icons.dart';
import 'package:gu_ui/src/tokens/gu_motion.dart';
import 'package:gu_ui/src/tokens/gu_opacity.dart';
import 'package:gu_ui/src/tokens/gu_radius.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';
import 'package:gu_ui/src/utils/gu_tap_target.dart';
import 'package:gu_ui/src/widgets/primitives/gu_action_surface.dart';
import 'package:gu_ui/src/widgets/primitives/gu_count_badge.dart';

/// Çip — prototip `Chip` (`ui.js:53`), CSS `.chip` (css:176–186).
///
/// En az 38 px, dolgu 14, radius 10, 1 px kenarlık; tek ve çok seçimde aynı
/// bileşen. Dokunma alanı her yönde 6 px genişler (css:179) ve platform
/// alt sınırına tamamlanır (K-03).
///
/// * [selected]: açık temada `brand.primaryContainer` zemin + `brand.primary`
///   kenarlık; koyu temada `brand.primary` zemin + beyaz metin, sayaç ters
///   renkli (css:181–183).
/// * Basılı: `bg.surfaceMuted` (K-53) — yalnızca açık temada, seçili ya da
///   [input] değilken görünür (koyu temada zemin zaten aynı renk, css:177).
/// * [count] > 0 → `GuCountBadge(sm)` (ham sayı, ui.js:55).
/// * [removable] → sonda 14 px `x`; kendi dokunma hedefi, [onRemove],
///   [removeSemanticLabel] (zorunlu) ve [removeKey] (`<aksiyon>.remove`).
/// * [input]: açık temada `bg.surfaceMuted` zemin, kenarlıksız (css:184; koyu
///   temada css:177 baskın, görünüm değişmez).
/// * [disabled]: opaklık .5, dokunma yok sayılır.
/// * [onTap] `null` → etkileşimsiz etiket çipi (CLB-07 ilgi alanları).
/// * `key: GuKey.action('ID.aksiyon')` (CD-111).
class GuChip extends StatelessWidget {
  const GuChip({
    required this.label,
    this.onTap,
    this.selected = false,
    this.icon,
    this.count,
    this.removable = false,
    this.onRemove,
    this.removeSemanticLabel,
    this.removeKey,
    this.input = false,
    this.disabled = false,
    super.key,
  }) : assert(
         !removable || removeSemanticLabel != null,
         'removable çip removeSemanticLabel ister.',
       );

  /// Çip metni (çağırandan; ARB).
  final String label;

  /// Dokunma; `null` → etkileşimsiz.
  final VoidCallback? onTap;

  /// Seçili durum (`aria-pressed`).
  final bool selected;

  /// Baştaki 16 px ikon.
  final GuIcons? icon;

  /// Sayaç; `null` ya da 0 → gösterilmez.
  final int? count;

  /// Sonda kaldır (`x`) düğmesi.
  final bool removable;

  /// Kaldır düğmesine dokunma.
  final VoidCallback? onRemove;

  /// Kaldır düğmesinin erişilebilirlik etiketi (ARB `commonRemove`).
  final String? removeSemanticLabel;

  /// Kaldır düğmesinin aksiyon anahtarı.
  final Key? removeKey;

  /// Girdi çipi görünümü (`.is-input`).
  final bool input;

  /// Devre dışı görünüm (opaklık .5).
  final bool disabled;

  void _handleTap() {
    if (!disabled) onTap?.call();
  }

  @override
  Widget build(BuildContext context) => GuActionSurface(
    onTap: onTap == null ? null : _handleTap,
    enabled: !disabled,
    selected: selected,
    borderRadius: GuRadius.borderChip,
    inset: GuInsets.sym(h: GuSizes.chipHitInset, v: GuSizes.chipHitInset),
    builder: _buildVisual,
  );

  Widget _buildVisual(BuildContext context, bool pressed) {
    final gu = context.gu;
    final colors = gu.colors;
    final darkSelected = gu.isDark && selected;
    final lightSelected = !gu.isDark && selected;
    final lightInput = !gu.isDark && input;

    final Color background;
    if (darkSelected) {
      background = colors.brandPrimary;
    } else if (gu.isDark || lightInput || (pressed && !selected)) {
      background = colors.bgSurfaceMuted;
    } else {
      background = selected ? colors.brandPrimaryContainer : colors.bgSurface;
    }
    // css:184 `border-color:transparent`: kenarlık alanında zemin görünür.
    final border = lightInput
        ? background
        : (selected ? colors.brandPrimary : gu.component.chipBorder);
    final foreground = darkSelected
        ? colors.brandOnPrimary
        : (lightSelected ? colors.brandOnPrimaryContainer : colors.textPrimary);
    final iconColor = darkSelected
        ? colors.brandOnPrimary
        : (lightSelected ? colors.brandPrimaryText : colors.textMuted);

    final leading = icon;
    final badge = count;
    return Opacity(
      opacity: disabled ? GuOpacity.disabled : 1,
      child: AnimatedContainer(
        duration: gu.duration(GuMotion.fast),
        curve: GuMotion.easeCss,
        constraints: const BoxConstraints(minHeight: GuSizes.chipHeight),
        padding: GuInsets.only(
          left: GuSizes.chipPaddingX,
          right:
              GuSizes.chipPaddingX +
              (removable ? GuSizes.chipRemoveMarginRight : 0),
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: GuRadius.borderChip,
          border: Border.all(
            color: border,
            // Token değeri varsayılanla (1) aynı; kaynak token kalır.
            // ignore: avoid_redundant_argument_values
            width: GuSizes.chipBorder,
          ),
        ),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: GuSizes.chipGap,
            children: [
              if (leading != null)
                GuIcon(leading, size: GuSizes.chipIcon, color: iconColor),
              Flexible(
                child: Text(
                  label,
                  style: gu.text.chip.copyWith(color: foreground),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badge != null && badge > 0)
                GuCountBadge(
                  label: '$badge',
                  tone: darkSelected
                      ? GuCountBadgeTone.inverted
                      : GuCountBadgeTone.brand,
                ),
              if (removable)
                GuTapTarget(
                  key: removeKey,
                  onTap: onRemove,
                  semanticLabel: removeSemanticLabel,
                  enabled: !disabled,
                  child: GuIcon(
                    GuIcons.x,
                    size: GuSizes.chipRemoveIcon,
                    color: iconColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
