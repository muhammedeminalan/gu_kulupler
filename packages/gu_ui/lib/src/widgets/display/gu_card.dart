import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/tokens/gu_motion.dart';
import 'package:gu_ui/src/tokens/gu_radius.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/utils/gu_tap_target.dart';

/// Kart kabı — prototip `Card` (`ui.js:70`), CSS `.card` / `.card-body` /
/// `.is-tappable` / `.is-muted` / `.is-highlight` (css:203–208, keyframes
/// css:426). Tek kap gövdesi (G3, CD-27): `GuKpi`, `ClubCard`, `EventCard`,
/// `PostCard`, `MyClubChip` bunun içeriğidir.
///
/// * Zemin `bg.surface`, radius `lg`, kenarlık 1 px `border.soft` (koyu
///   temada `border.default`, css:204), gölge `e1`, içerik iç köşeye kırpılır
///   (`overflow:hidden`).
/// * [muted] — `bg.surfaceMuted`, gölgesiz, açık temada kenarlık saydam
///   (css:205; koyu temada css:204 özgüllüğü kazanır → `border.default`).
/// * [borderColor] — çağıran token verir (SET-03 uyarı kartı
///   `context.gu.colors.stateWarning`, `screens-profile.js:87`; CD-118).
/// * [highlight] — `true` olduğunda (ilk çizim ya da `false → true`) bir kez
///   3 px `brand.primary` halkası 1,5 sn'de `e1`'e söner (css:208); hareket
///   azaltılmışsa oynatılmaz.
/// * [onTap] verilirse kart düğmedir: basılıyken [pressScale] kadar küçülür
///   (`.is-tappable:active` .99; `.pressable` kartlar için
///   `GuMotion.pressScale`), `Semantics(button)` + [semanticLabel].
/// * [padding] `null` → dolgu yok (kapaklı kartlar); gövde dolgusu için
///   [bodyPadding] (`.card-body` 16).
///
/// Genişliği ebeveyn belirler (CSS blok öğe: `Column` içinde
/// `CrossAxisAlignment.stretch`). `key` (`GuKey.action`) kartın kendisidir.
class GuCard extends StatefulWidget {
  const GuCard({
    required this.child,
    this.onTap,
    this.muted = false,
    this.highlight = false,
    this.borderColor,
    this.padding,
    this.semanticLabel,
    this.pressScale = GuMotion.cardPressScale,
    super.key,
  });

  /// `.card-body{padding:16px}` (css:207).
  static const EdgeInsets bodyPadding = EdgeInsets.all(
    GuSizes.cardBodyPadding,
  );

  /// Kart içeriği.
  final Widget child;

  /// Dokunma; `null` → statik kart.
  final VoidCallback? onTap;

  /// `.is-muted` görünümü.
  final bool muted;

  /// Tek seferlik vurgu halkası.
  final bool highlight;

  /// Kenarlık rengi üst yazımı; `null` → tema kuralı.
  final Color? borderColor;

  /// İçerik dolgusu; `null` → yok.
  final EdgeInsetsGeometry? padding;

  /// Erişilebilirlik etiketi (prototip `label` → `aria-label`); verilirse
  /// dokunulabilir kartta çocuk semantiğinin yerine geçer.
  final String? semanticLabel;

  /// Basılı ölçek (yalnızca [onTap] varken).
  final double pressScale;

  @override
  State<GuCard> createState() => _GuCardState();
}

class _GuCardState extends State<GuCard> with SingleTickerProviderStateMixin {
  /// İçerik kırpması: dış radius − kenarlık (CSS dolgu kutusu köşesi).
  static final BorderRadius _innerRadius =
      GuRadius.borderLg - BorderRadius.circular(GuSizes.cardBorder);

  // 1 = halka sönmüş (durağan görünüm).
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: GuMotion.highlight,
    value: 1,
  );
  bool _pressed = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    if (widget.highlight) _playHighlight();
  }

  @override
  void didUpdateWidget(GuCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlight && !oldWidget.highlight) _playHighlight();
  }

  @override
  void dispose() {
    _ring.dispose();
    super.dispose();
  }

  void _playHighlight() {
    if (context.gu.reduceMotion) return;
    unawaited(_ring.forward(from: 0));
  }

  void _setPressed(bool value) {
    if (mounted && _pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final colors = gu.colors;
    final e1 = gu.shadows.e1;
    final restShadows = widget.muted ? const <BoxShadow>[] : e1;
    final ring = [
      BoxShadow(
        color: colors.brandPrimary,
        spreadRadius: GuSizes.highlightRingWidth,
      ),
    ];
    final borderColor =
        widget.borderColor ??
        (gu.isDark
            ? colors.borderDefault
            : (widget.muted ? null : colors.borderSoft));
    final padding = widget.padding;

    final card = AnimatedBuilder(
      animation: _ring,
      builder: (context, child) => DecoratedBox(
        decoration: BoxDecoration(
          color: widget.muted ? colors.bgSurfaceMuted : colors.bgSurface,
          borderRadius: GuRadius.borderLg,
          border: borderColor == null
              ? null
              : Border.all(
                  color: borderColor,
                  // Token açık kalsın (varsayılanla aynı değer).
                  // ignore: avoid_redundant_argument_values
                  width: GuSizes.cardBorder,
                ),
          boxShadow: _ring.isCompleted
              ? restShadows
              : BoxShadow.lerpList(
                  ring,
                  e1,
                  GuMotion.easeStandard.transform(_ring.value),
                ),
        ),
        child: child,
      ),
      // Kenarlık saydamken de 1 px yer kaplar (CSS `border-color` değişir,
      // genişlik değişmez).
      child: Padding(
        padding: const EdgeInsets.all(GuSizes.cardBorder),
        child: ClipRRect(
          borderRadius: _innerRadius,
          child: padding == null
              ? widget.child
              : Padding(padding: padding, child: widget.child),
        ),
      ),
    );

    final label = widget.semanticLabel;
    if (widget.onTap == null) {
      if (label == null) return card;
      return Semantics(container: true, label: label, child: card);
    }
    return GuTapTarget(
      onTap: widget.onTap,
      onPressedChanged: _setPressed,
      semanticLabel: label,
      child: AnimatedScale(
        scale: _pressed ? widget.pressScale : 1,
        duration: gu.duration(GuMotion.fast),
        curve: GuMotion.easeCss,
        child: card,
      ),
    );
  }
}
