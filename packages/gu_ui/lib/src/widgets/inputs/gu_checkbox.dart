import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/icons/gu_icon.dart';
import 'package:gu_ui/src/icons/gu_icons.dart';
import 'package:gu_ui/src/tokens/gu_motion.dart';
import 'package:gu_ui/src/tokens/gu_opacity.dart';
import 'package:gu_ui/src/tokens/gu_radius.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';
import 'package:gu_ui/src/widgets/inputs/gu_selection_surface.dart';

/// Onay kutusu — prototip `Checkbox` (`ui.js:46`), CSS `.check`
/// (css:237–240, 242).
///
/// 22×22, radius 6, 2 px `text.muted` kenarlık; işaretliyken zemin ve
/// kenarlık `brand.primary`, içinde 16 px beyaz `check` (kalınlık 1.75 sabit,
/// K-24). Zemin / kenarlık geçişi `GuMotion.fast` + `easeCss` (css:237).
/// Dokunma alanı her yönde 13 px genişler (css:239 → 48×48; K-03).
///
/// * [disabled]: opaklık .5 (css:242), [onChanged] çağrılmaz.
/// * [onChanged] `null` → etkileşimsiz gösterge (`GuOptionRow` sonu).
/// * Basılı görünüm yok (CSS'te `:active` / `:hover` kuralı yok).
/// * `Semantics(checked, enabled, label)`; `key: GuKey.action('ID.aksiyon')`
///   (CD-111).
class GuCheckbox extends StatelessWidget {
  const GuCheckbox({
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
    this.disabled = false,
    super.key,
  });

  /// İşaretli mi (`aria-checked`).
  final bool value;

  /// Dokunmada yeni değerle çağrılır; `null` → etkileşimsiz gösterge.
  final ValueChanged<bool>? onChanged;

  /// Erişilebilirlik etiketi (çağırandan; ARB).
  final String semanticLabel;

  /// Devre dışı görünüm (opaklık .5); [onChanged] çağrılmaz.
  final bool disabled;

  void _handleTap() {
    if (!disabled) onChanged?.call(!value);
  }

  @override
  Widget build(BuildContext context) => GuSelectionSurface(
    role: GuSelectionRole.checkbox,
    value: value,
    enabled: !disabled,
    semanticLabel: semanticLabel,
    onTap: onChanged == null ? null : _handleTap,
    borderRadius: GuRadius.borderCheckbox,
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
          color: value ? colors.brandPrimary : null,
          borderRadius: GuRadius.borderCheckbox,
          border: Border.all(
            color: value ? colors.brandPrimary : colors.textMuted,
            width: GuSizes.checkboxBorder,
          ),
        ),
        child: value
            ? GuIcon(
                GuIcons.check,
                size: GuSizes.checkboxIcon,
                // css:237 `color:#fff` = `brand.onPrimary` (iki tema).
                color: colors.brandOnPrimary,
              )
            : null,
      ),
    );
  }
}
