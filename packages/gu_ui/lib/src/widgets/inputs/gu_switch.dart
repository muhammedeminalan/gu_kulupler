import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/tokens/gu_motion.dart';
import 'package:gu_ui/src/tokens/gu_opacity.dart';
import 'package:gu_ui/src/tokens/gu_radius.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';
import 'package:gu_ui/src/widgets/inputs/gu_selection_surface.dart';

/// Anahtar — prototip `Switch` (`ui.js:42`), CSS `.switch` (css:231–236).
///
/// Ray 44×26 radius 13; kapalı `border.default`, açık `brand.primary`
/// (metin dışı kontrast K-43: renk değişmez). Topuz 20 px beyaz, 3 px içte,
/// açıkken 18 px sağa kayar. Ray rengi `GuMotion.base` + `easeCss` (css:231,
/// eğri yazılmamış), topuz `GuMotion.base` + `easeStandard` (css:234).
/// Dokunma alanı yatay 4 / dikey 11 genişler (css:232 → 52×48; K-03).
///
/// * [disabled]: opaklık .5 (css:236); dokunma [onChanged] yerine
///   [onDisabledPressed]'i çağırır (ui.js:43).
/// * [onChanged] ve [onDisabledPressed] `null` → etkileşimsiz gösterge.
/// * Basılı görünüm yok (CD-82: `.switch` için `:active` kuralı yok).
/// * `Semantics(toggled, enabled, label)`; `key: GuKey.action('ID.aksiyon')`
///   (CD-111).
class GuSwitch extends StatelessWidget {
  const GuSwitch({
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
    this.disabled = false,
    this.onDisabledPressed,
    super.key,
  });

  /// Açık mı (`aria-checked`).
  final bool value;

  /// Dokunmada yeni değerle çağrılır; `null` → değiştirilemez.
  final ValueChanged<bool>? onChanged;

  /// Erişilebilirlik etiketi (çağırandan; ARB).
  final String semanticLabel;

  /// Devre dışı görünüm (opaklık .5); [onChanged] çağrılmaz.
  final bool disabled;

  /// Devre dışıyken dokunma (ör. neden kapalı olduğunu söyleyen toast).
  final VoidCallback? onDisabledPressed;

  void _handleTap() {
    if (disabled) {
      onDisabledPressed?.call();
    } else {
      onChanged?.call(!value);
    }
  }

  @override
  Widget build(BuildContext context) => GuSelectionSurface(
    role: GuSelectionRole.toggle,
    value: value,
    enabled: !disabled && onChanged != null,
    semanticLabel: semanticLabel,
    onTap: onChanged == null && onDisabledPressed == null ? null : _handleTap,
    borderRadius: GuRadius.borderSwitchTrack,
    inset: GuInsets.sym(
      h: GuSizes.switchHitInsetX,
      v: GuSizes.switchHitInsetY,
    ),
    builder: _buildVisual,
  );

  Widget _buildVisual(BuildContext context, bool pressed) {
    final gu = context.gu;
    final colors = gu.colors;
    final duration = gu.duration(GuMotion.base);
    return Opacity(
      opacity: disabled ? GuOpacity.disabled : 1,
      child: AnimatedContainer(
        duration: duration,
        curve: GuMotion.easeCss,
        width: GuSizes.switchWidth,
        height: GuSizes.switchHeight,
        decoration: BoxDecoration(
          color: value ? colors.brandPrimary : colors.borderDefault,
          borderRadius: GuRadius.borderSwitchTrack,
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: duration,
              curve: GuMotion.easeStandard,
              top: GuSizes.switchThumbInset,
              left:
                  GuSizes.switchThumbInset +
                  (value ? GuSizes.switchThumbTravel : 0),
              width: GuSizes.switchThumb,
              height: GuSizes.switchThumb,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  // css:234 `background:#fff` = `brand.onPrimary` (iki tema).
                  color: colors.brandOnPrimary,
                  shape: BoxShape.circle,
                  boxShadow: gu.shadows.switchThumb,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
