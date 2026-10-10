import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/icons/gu_icon.dart';
import 'package:gu_ui/src/icons/gu_icons.dart';
import 'package:gu_ui/src/tokens/gu_motion.dart';
import 'package:gu_ui/src/tokens/gu_opacity.dart';
import 'package:gu_ui/src/tokens/gu_radius.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/utils/gu_tap_target.dart';

/// Hızlı işlem karosu — prototip `Quick` (`ui.js:128`), CSS
/// `.quick.pressable` / `.quick-icon` (css:305–306, 340). MGT-01 `grid3`.
///
/// Dikey: 40 px ikon kutusu (kare, radius 12, `brand.primaryContainer`,
/// ikon 20 `brand.primaryText` — `GuIconBox` daire olduğundan iç parça, G9)
/// + ortalı [label] (`GuTypography.quick`, sarar). Kart: `bg.surface`,
/// 1 px `border.soft`, radius `md`, dolgu 14/8, aralık 8; gölgesiz (G3: ayrı
/// gövde, `GuCard` değil).
///
/// Durumlar: basılı ölçek `GuMotion.pressScale`; [disabled] →
/// `GuOpacity.disabled` + dokununca [onDisabledPressed] (MGT-01 danışman →
/// TST-26; CD-84, K-45). `key` (`GuKey.action`) karonun kendisidir.
class GuQuickAction extends StatefulWidget {
  const GuQuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.disabled = false,
    this.onDisabledPressed,
    super.key,
  });

  /// Kutudaki ikon.
  final GuIcons icon;

  /// Etiket (aynı zamanda erişilebilirlik etiketi).
  final String label;

  /// Dokunma ([disabled] değilken).
  final VoidCallback onTap;

  /// Devre dışı görünüm.
  final bool disabled;

  /// Devre dışıyken dokunma.
  final VoidCallback? onDisabledPressed;

  @override
  State<GuQuickAction> createState() => _GuQuickActionState();
}

class _GuQuickActionState extends State<GuQuickAction> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (mounted && _pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final colors = gu.colors;
    final disabled = widget.disabled;

    final tile = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: GuRadius.borderMd,
        border: Border.all(
          color: colors.borderSoft,
          // Token açık kalsın (varsayılanla aynı değer).
          // ignore: avoid_redundant_argument_values
          width: GuSizes.quickBorder,
        ),
      ),
      child: Padding(
        // CSS dolgusu kenarlığın içindedir (border-box).
        padding: const EdgeInsets.symmetric(
          horizontal: GuSizes.quickPaddingX + GuSizes.quickBorder,
          vertical: GuSizes.quickPaddingY + GuSizes.quickBorder,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: GuSizes.quickGap,
          children: [
            SizedBox.square(
              dimension: GuSizes.quickIconBox,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.brandPrimaryContainer,
                  borderRadius: GuRadius.borderSm,
                ),
                child: Center(
                  child: GuIcon(
                    widget.icon,
                    size: GuSizes.quickIcon,
                    color: colors.brandPrimaryText,
                  ),
                ),
              ),
            ),
            Text(
              widget.label,
              style: gu.text.quick,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    return GuTapTarget(
      onTap: disabled ? widget.onDisabledPressed : widget.onTap,
      onPressedChanged: disabled ? null : _setPressed,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        enabled: !disabled,
        label: widget.label,
        onTap: disabled ? null : widget.onTap,
        excludeSemantics: true,
        child: Opacity(
          opacity: disabled ? GuOpacity.disabled : 1,
          child: AnimatedScale(
            scale: _pressed && !disabled ? GuMotion.pressScale : 1,
            duration: gu.duration(GuMotion.fast),
            curve: GuMotion.easeCss,
            child: tile,
          ),
        ),
      ),
    );
  }
}
