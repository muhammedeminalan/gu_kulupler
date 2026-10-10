import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/tokens/gu_motion.dart';
import 'package:gu_ui/src/tokens/gu_opacity.dart';
import 'package:gu_ui/src/tokens/gu_radius.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';
import 'package:gu_ui/src/widgets/inputs/gu_selection_surface.dart';

/// Radyo — prototip `Radio` (`ui.js:47`), CSS `.radio` (css:237–239,
/// 241–242).
///
/// 22×22 daire, 2 px `text.muted` kenarlık; seçiliyken kenarlık ve 12 px iç
/// nokta `brand.primary`. Kenarlık geçişi `GuMotion.fast` + `easeCss`
/// (css:237). Dokunma alanı her yönde 13 px genişler (css:239 → 48×48;
/// K-03).
///
/// Ekranlarda tek başına kullanılmaz: `GuOptionRow` sonu ve `GuOptionCard`
/// başı (SHT-22) için tek radyo çizimidir (A.2 #8, H.2).
///
/// * [disabled]: opaklık .5 (css:242), [onSelected] çağrılmaz.
/// * [onSelected] `null` → etkileşimsiz gösterge.
/// * Basılı görünüm yok (CSS'te `:active` / `:hover` kuralı yok).
/// * `Semantics(checked, inMutuallyExclusiveGroup, enabled, label)`;
///   `key: GuKey.action('ID.aksiyon')` (CD-111).
class GuRadio extends StatelessWidget {
  const GuRadio({
    required this.selected,
    required this.onSelected,
    required this.semanticLabel,
    this.disabled = false,
    super.key,
  });

  /// Seçili mi (`aria-checked`).
  final bool selected;

  /// Dokunma (seçiliyken de çağrılır, ui.js:47); `null` → etkileşimsiz
  /// gösterge.
  final VoidCallback? onSelected;

  /// Erişilebilirlik etiketi (çağırandan; ARB).
  final String semanticLabel;

  /// Devre dışı görünüm (opaklık .5); [onSelected] çağrılmaz.
  final bool disabled;

  void _handleTap() {
    if (!disabled) onSelected?.call();
  }

  @override
  Widget build(BuildContext context) => GuSelectionSurface(
    role: GuSelectionRole.radio,
    value: selected,
    enabled: !disabled,
    semanticLabel: semanticLabel,
    onTap: onSelected == null ? null : _handleTap,
    borderRadius: GuRadius.borderFull,
    inset: GuInsets.sym(h: GuSizes.checkHitInset, v: GuSizes.checkHitInset),
    builder: _buildVisual,
  );

  Widget _buildVisual(BuildContext context, bool pressed) {
    final gu = context.gu;
    final colors = gu.colors;
    return Opacity(
      opacity: disabled ? GuOpacity.disabled : 1,
      child: AnimatedContainer(
        duration: gu.duration(GuMotion.fast),
        curve: GuMotion.easeCss,
        width: GuSizes.checkbox,
        height: GuSizes.checkbox,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? colors.brandPrimary : colors.textMuted,
            width: GuSizes.checkboxBorder,
          ),
        ),
        child: selected
            ? SizedBox.square(
                dimension: GuSizes.radioDot,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.brandPrimary,
                    shape: BoxShape.circle,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
