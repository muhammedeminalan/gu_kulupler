import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/icons/gu_icon.dart';
import 'package:gu_ui/src/icons/gu_icons.dart';
import 'package:gu_ui/src/theme/gu_theme_extension.dart';
import 'package:gu_ui/src/tokens/gu_motion.dart';
import 'package:gu_ui/src/tokens/gu_opacity.dart';
import 'package:gu_ui/src/tokens/gu_radius.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';
import 'package:gu_ui/src/widgets/feedback/gu_spinner.dart';
import 'package:gu_ui/src/widgets/primitives/gu_action_surface.dart';

/// Düğme varyantı — `ui.js:12`, CSS `.btn-*` (css:142–148).
enum GuButtonVariant {
  /// `.btn-primary`: `brand.primary` zemin; basılı `brand.primaryPressed`.
  primary,

  /// `.btn-tonal`: `brand.primaryContainer` zemin; basılı `brightness(.96)`.
  tonal,

  /// `.btn-outline`: 1 px `border.default` + `bg.surface`; basılı
  /// `bg.surfaceMuted`.
  outline,

  /// `.btn-text`: zeminsiz, `brand.primaryText`; yükseklik 44, dolgu 12
  /// (boyuttan bağımsız, css:145); basılı `brand.primaryContainer`.
  text,

  /// `.btn-danger-outline`: 1 px `state.danger`; basılı
  /// `state.dangerContainer`.
  dangerOutline,

  /// `.btn-danger`: `state.danger` zemin; basılı `brightness(.92)`.
  danger,

  /// `.btn-ghost`: zeminsiz, `text.heading`, dolgu 12; basılı
  /// `bg.surfaceMuted`.
  ghost,
}

/// Düğme boyutu — CSS `.btn` / `.btn-sm` / `.btn-lg` (css:139, 141).
enum GuButtonSize {
  /// 40 px, dolgu 14, yazı 13, ikon 18.
  sm(GuSizes.buttonHeightSm, GuSizes.buttonPaddingXSm, GuSizes.buttonIconSm),

  /// 48 px, dolgu 20, yazı 14, ikon 20.
  md(GuSizes.buttonHeight, GuSizes.buttonPaddingX, GuSizes.buttonIcon),

  /// 56 px, dolgu 24, yazı 16, ikon 20.
  lg(GuSizes.buttonHeightLg, GuSizes.buttonPaddingXLg, GuSizes.buttonIcon);

  const GuButtonSize(this.minHeight, this.paddingX, this.iconSize);

  /// En küçük yükseklik (dp); metin ölçeğiyle büyüyebilir.
  final double minHeight;

  /// Yatay iç dolgu (dp).
  final double paddingX;

  /// Baştaki ikonun kenarı (dp; `ui.js:14`).
  final double iconSize;
}

/// Düğme — prototip `Button` (`ui.js:9`), CSS `.btn` (css:139–152).
///
/// * Durumlar: basılı (ölçek .98 + varyantın basılı rengi, K-53), odak
///   halkası, [disabled] (opaklık .5; dokunma [onDisabledPressed]'e gider),
///   [loading] (içerik gizli, ortada `GuSpinner`; dokunma yok sayılır).
/// * [onPressed] `null` ise düğme [disabled] gibi davranır.
/// * [full] → satırı doldurur (`.btn-full`); `Expanded` içinde zaten genişler.
/// * [iconOnly] → yalnızca [icon]; [semanticLabel] zorunludur.
/// * Etiket tek satırdır; sığmazsa `…` ile kesilir.
/// * `key: GuKey.action('ID.aksiyon')` (CD-111).
class GuButton extends StatelessWidget {
  const GuButton({
    required this.label,
    required this.onPressed,
    this.variant = GuButtonVariant.primary,
    this.size = GuButtonSize.md,
    this.icon,
    this.iconTrailing,
    this.iconOnly = false,
    this.loading = false,
    this.disabled = false,
    this.onDisabledPressed,
    this.full = false,
    this.autofocus = false,
    this.semanticLabel,
    super.key,
  }) : assert(
         !iconOnly || (icon != null && semanticLabel != null),
         'iconOnly düğme icon ve semanticLabel ister.',
       );

  /// Düğme metni (çağırandan; ARB).
  final String label;

  /// Dokunma; `null` → devre dışı.
  final VoidCallback? onPressed;

  /// Renk varyantı.
  final GuButtonVariant variant;

  /// Boyut.
  final GuButtonSize size;

  /// Baştaki ikon (20; `sm` 18).
  final GuIcons? icon;

  /// Sondaki ikon (18).
  final GuIcons? iconTrailing;

  /// Yalnızca ikon çizilir; [label] gösterilmez.
  final bool iconOnly;

  /// Meşgul: içerik gizlenir, spinner döner, dokunma yok sayılır.
  final bool loading;

  /// Devre dışı görünüm (opaklık .5).
  final bool disabled;

  /// Devre dışıyken dokunma (neden kapalı olduğunu söyleyen toast, ui.js:11).
  final VoidCallback? onDisabledPressed;

  /// Tam genişlik (`.btn-full`, css:151).
  final bool full;

  /// İlk karede odağı alır.
  final bool autofocus;

  /// Erişilebilirlik etiketi; `null` → [label].
  final String? semanticLabel;

  bool get _isDisabled => disabled || onPressed == null;

  void _handleTap() {
    if (loading) return;
    if (_isDisabled) {
      onDisabledPressed?.call();
    } else {
      onPressed?.call();
    }
  }

  @override
  Widget build(BuildContext context) => GuActionSurface(
    onTap: _handleTap,
    enabled: !_isDisabled && !loading,
    semanticLabel: semanticLabel ?? label,
    borderRadius: GuRadius.borderSm,
    autofocus: autofocus,
    builder: _buildVisual,
  );

  Widget _buildVisual(BuildContext context, bool pressed) {
    final gu = context.gu;
    final colors = _GuButtonColors.resolve(variant, gu, pressed: pressed);
    final textStyle = switch (size) {
      GuButtonSize.sm => gu.text.buttonSm,
      GuButtonSize.md => gu.text.button,
      GuButtonSize.lg => gu.text.buttonLg,
    };
    final leading = icon;
    final trailing = iconTrailing;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: GuSizes.buttonGap,
      children: [
        if (leading != null)
          GuIcon(leading, size: size.iconSize, color: colors.foreground),
        if (!iconOnly)
          Flexible(
            child: Text(
              label,
              style: textStyle.copyWith(color: colors.foreground),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (trailing != null)
          GuIcon(
            trailing,
            size: GuSizes.buttonIconTrailing,
            color: colors.foreground,
          ),
      ],
    );
    final border = colors.border;
    final duration = gu.duration(GuMotion.fast);
    final body = Stack(
      fit: StackFit.passthrough,
      children: [
        AnimatedContainer(
          duration: duration,
          curve: GuMotion.easeCss,
          constraints: BoxConstraints(
            minHeight: variant == GuButtonVariant.text
                ? GuSizes.textButtonHeight
                : size.minHeight,
          ),
          padding: GuInsets.sym(
            h: switch (variant) {
              GuButtonVariant.text => GuSizes.textButtonPaddingX,
              GuButtonVariant.ghost => GuSizes.ghostButtonPaddingX,
              _ => size.paddingX,
            },
          ),
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: GuRadius.borderSm,
            border: border == null
                ? null
                : Border.all(
                    color: border,
                    // Token değeri varsayılanla (1) aynı; kaynak token kalır.
                    // ignore: avoid_redundant_argument_values
                    width: GuSizes.buttonBorder,
                  ),
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            // css:152 `visibility:hidden`: yer korunur, içerik çizilmez.
            child: Visibility.maintain(visible: !loading, child: content),
          ),
        ),
        if (loading)
          Positioned.fill(
            child: Center(child: GuSpinner(color: colors.foreground)),
          ),
      ],
    );
    final scaled = AnimatedScale(
      scale: pressed ? GuMotion.pressScale : 1,
      duration: duration,
      curve: GuMotion.easeCss,
      child: Opacity(
        opacity: _isDisabled ? GuOpacity.disabled : 1,
        child: body,
      ),
    );
    return full ? SizedBox(width: double.infinity, child: scaled) : scaled;
  }
}

/// Varyantın (zemin, ön plan, kenarlık) renkleri — css:142–148; basılı
/// renkler `:hover` kurallarından (K-53).
@immutable
class _GuButtonColors {
  const _GuButtonColors(this.background, this.foreground, [this.border]);

  factory _GuButtonColors.resolve(
    GuButtonVariant variant,
    GuThemeExtension gu, {
    required bool pressed,
  }) {
    final c = gu.colors;
    switch (variant) {
      case GuButtonVariant.primary:
        return _GuButtonColors(
          pressed ? c.brandPrimaryPressed : c.brandPrimary,
          c.brandOnPrimary,
        );
      case GuButtonVariant.tonal:
        final amount = pressed ? GuOpacity.tonalPressedDarken : 0.0;
        return _GuButtonColors(
          _darken(c.brandPrimaryContainer, amount),
          _darken(c.brandOnPrimaryContainer, amount),
        );
      case GuButtonVariant.outline:
        return _GuButtonColors(
          pressed ? c.bgSurfaceMuted : c.bgSurface,
          c.textHeading,
          c.borderDefault,
        );
      case GuButtonVariant.text:
        return _GuButtonColors(
          pressed ? c.brandPrimaryContainer : null,
          c.brandPrimaryText,
        );
      case GuButtonVariant.dangerOutline:
        return _GuButtonColors(
          pressed ? c.stateDangerContainer : null,
          c.stateDanger,
          c.stateDanger,
        );
      case GuButtonVariant.danger:
        final amount = pressed ? GuOpacity.dangerPressedDarken : 0.0;
        return _GuButtonColors(
          _darken(c.stateDanger, amount),
          _darken(c.brandOnPrimary, amount),
        );
      case GuButtonVariant.ghost:
        return _GuButtonColors(
          pressed ? c.bgSurfaceMuted : null,
          c.textHeading,
        );
    }
  }

  /// Zemin; `null` → saydam.
  final Color? background;

  /// Metin, ikon ve spinner rengi.
  final Color foreground;

  /// 1 px kenarlık; `null` → yok.
  final Color? border;

  /// CSS `filter:brightness(1 − amount)` (css:143, 147): sRGB kanalları
  /// çarpılır; filtre öğenin tamamına (zemin + metin) uygulanır.
  static Color _darken(Color color, double amount) => amount == 0
      ? color
      : color.withValues(
          red: color.r * (1 - amount),
          green: color.g * (1 - amount),
          blue: color.b * (1 - amount),
        );
}
