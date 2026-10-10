import 'dart:ui' show FontFeature, ImageFilter;

import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/icons/gu_icon.dart';
import 'package:gu_ui/src/icons/gu_icons.dart';
import 'package:gu_ui/src/tokens/gu_motion.dart';
import 'package:gu_ui/src/tokens/gu_opacity.dart';
import 'package:gu_ui/src/tokens/gu_radius.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';
import 'package:gu_ui/src/widgets/primitives/gu_action_surface.dart';
import 'package:gu_ui/src/widgets/primitives/gu_count_badge.dart';

/// İkon düğmesi boyutu — CSS `.iconbtn` / `.is-sm` (css:154, 156) ve toast
/// kapat satır içi 32 (`shell.js:21`, K-32).
enum GuIconButtonSize {
  /// 48 px (varsayılan).
  md(GuSizes.iconButton),

  /// 40 px — girdi içi, banner kapat (`ui.js:90`).
  sm(GuSizes.iconButtonSm),

  /// 32 px — toast kapat; ikon 16 çağırandan.
  xs(GuSizes.iconButtonXs);

  const GuIconButtonSize(this.dimension);

  /// Daire çapı (dp).
  final double dimension;
}

/// İkon düğmesi tonu (K-32).
enum GuIconButtonTone {
  /// `text.heading` ikon, zeminsiz.
  none,

  /// `.is-brand`: `brand.primaryText` ikon (css:156).
  brand,

  /// 44 px + `state.successContainer` zemin, `state.success` ikon
  /// (ApplicationRow onay, `cards.js:176`).
  success,

  /// 44 px + `state.dangerContainer` zemin, `state.danger` ikon
  /// (ApplicationRow ret, `cards.js:176`).
  danger,
}

/// İkon düğmesi — prototip `IconButton` (`ui.js:17`), CSS `.iconbtn`
/// (css:154–157) + satır içi dört görünüm tek sınıfta (K-32).
///
/// * Basılı: `bg.surfaceMuted` zemin (K-53); [onCover] → koyu örtü + blur 6,
///   basılı daha koyu örtü; `success` / `danger` tonunda basılı rengi yok.
/// * [badge] → sağ üstte `GuCountBadge(sm)`; "9+" metni çağırandan (CD-81).
/// * [countLabel] → otomatik genişlik, dolgu 10, aralık 6, radius 12 + sayaç
///   metni (PostCard beğen / yorum, `cards.js:124`); boş metin de aralığı
///   korur.
/// * [foregroundInherit] → ikon kapsayıcının metin rengini alır
///   (`color:inherit`: banner / toast kapat).
/// * [disabled] ya da [onPressed] `null` → opaklık .45; dokunma
///   [onDisabledPressed]'e gider.
/// * `key: GuKey.action('ID.aksiyon')` (CD-111).
class GuIconButton extends StatelessWidget {
  const GuIconButton({
    required this.icon,
    required this.semanticLabel,
    this.onPressed,
    this.size = GuIconButtonSize.md,
    this.tone = GuIconButtonTone.none,
    this.onCover = false,
    this.badge,
    this.countLabel,
    this.foregroundInherit = false,
    this.iconSize = GuSizes.iconButtonIcon,
    this.disabled = false,
    this.onDisabledPressed,
    this.autofocus = false,
    super.key,
  });

  /// Çizilecek ikon.
  final GuIcons icon;

  /// Erişilebilirlik etiketi (`aria-label`, ui.js:18).
  final String semanticLabel;

  /// Dokunma; `null` → devre dışı.
  final VoidCallback? onPressed;

  /// Boyut (48 / 40 / 32); `success` / `danger` tonunda 44.
  final GuIconButtonSize size;

  /// Renk tonu.
  final GuIconButtonTone tone;

  /// Kapak üstü görünüm (`.on-cover`, css:155).
  final bool onCover;

  /// Sağ üst sayaç rozeti metni (`.dot-badge`, css:157).
  final String? badge;

  /// İkonun yanındaki sayaç metni (K-32).
  final String? countLabel;

  /// İkon rengi kapsayıcıdan (`DefaultTextStyle`) alınır.
  final bool foregroundInherit;

  /// İkon kenarı (varsayılan 24).
  final double iconSize;

  /// Devre dışı görünüm (opaklık .45).
  final bool disabled;

  /// Devre dışıyken dokunma (ui.js:18 `onDisabledClick`).
  final VoidCallback? onDisabledPressed;

  /// İlk karede odağı alır (SHT-34).
  final bool autofocus;

  bool get _isDisabled => disabled || onPressed == null;

  bool get _isTonal =>
      tone == GuIconButtonTone.success || tone == GuIconButtonTone.danger;

  BorderRadius get _radius =>
      countLabel == null ? GuRadius.borderFull : GuRadius.borderSm;

  void _handleTap() {
    if (_isDisabled) {
      onDisabledPressed?.call();
    } else {
      onPressed?.call();
    }
  }

  @override
  Widget build(BuildContext context) => GuActionSurface(
    onTap: _handleTap,
    enabled: !_isDisabled,
    semanticLabel: semanticLabel,
    borderRadius: _radius,
    autofocus: autofocus,
    builder: _buildVisual,
  );

  Widget _buildVisual(BuildContext context, bool pressed) {
    final gu = context.gu;
    final colors = gu.colors;
    final Color foreground;
    if (foregroundInherit) {
      foreground =
          DefaultTextStyle.of(context).style.color ?? colors.textHeading;
    } else if (onCover) {
      foreground = gu.component.onCoverForeground;
    } else {
      foreground = switch (tone) {
        GuIconButtonTone.none => colors.textHeading,
        GuIconButtonTone.brand => colors.brandPrimaryText,
        GuIconButtonTone.success => colors.stateSuccess,
        GuIconButtonTone.danger => colors.stateDanger,
      };
    }
    final Color? background;
    if (onCover) {
      background = pressed
          ? gu.component.onCoverScrimPressed
          : gu.component.onCoverScrim;
    } else {
      background = switch (tone) {
        GuIconButtonTone.success => colors.stateSuccessContainer,
        GuIconButtonTone.danger => colors.stateDangerContainer,
        _ => pressed ? colors.bgSurfaceMuted : null,
      };
    }
    final dimension = _isTonal ? GuSizes.iconButtonTonal : size.dimension;
    final count = countLabel;
    final glyph = GuIcon(icon, size: iconSize, color: foreground);
    Widget body = AnimatedContainer(
      duration: gu.duration(GuMotion.fast),
      curve: GuMotion.easeCss,
      width: count == null ? dimension : null,
      height: dimension,
      padding: count == null
          ? null
          : GuInsets.sym(h: GuSizes.iconButtonCountPaddingX),
      decoration: BoxDecoration(color: background, borderRadius: _radius),
      child: Center(
        widthFactor: 1,
        child: count == null
            ? glyph
            : Row(
                mainAxisSize: MainAxisSize.min,
                spacing: GuSizes.iconButtonCountGap,
                children: [
                  glyph,
                  // `.t-label-m.tnum` (cards.js:124); renk düğmeden gelir.
                  Text(
                    count,
                    style: gu.text.labelM.copyWith(
                      color: foreground,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    maxLines: 1,
                    softWrap: false,
                  ),
                ],
              ),
      ),
    );
    if (onCover) {
      body = ClipRRect(
        borderRadius: _radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: GuSizes.onCoverBlur,
            sigmaY: GuSizes.onCoverBlur,
          ),
          child: body,
        ),
      );
    }
    final label = badge;
    if (label != null) {
      body = Stack(
        clipBehavior: Clip.none,
        children: [
          body,
          Positioned(
            top: GuSizes.dotBadgeTop,
            right: GuSizes.dotBadgeRight,
            child: GuCountBadge(label: label),
          ),
        ],
      );
    }
    return Opacity(
      opacity: _isDisabled ? GuOpacity.iconButtonDisabled : 1,
      child: body,
    );
  }
}
