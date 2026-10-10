import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';

/// Parallax kapak başlığı — CSS `.parallax` / `.parallax .cover` /
/// `.parallax-bar` (css:395–397); CLB-03 (`screens-clubs.js:86`), EVT-02
/// (`screens-events.js:58`); CD-25.
///
/// * [height] (220) yüksekliğinde, tam genişlikte kırpılmış kutu; [cover]
///   (`GuCover(ratio: GuCoverRatio.fill)`) kutuyu doldurur ve kaydırma
///   ofsetinin [factor] (.4) katı kadar aşağı kayar
///   (`translateY(py × .4px)`). Ofset `0…height` aralığına sıkıştırılır
///   (`screens-events.js:57` `min(220, scrollTop)`); `--pz` ölçeği hiçbir
///   ekranda verilmediği için yazılmaz.
/// * Üst çubuk: [leading] (geri) — boşluk — [actions]; aralık 4, yatay
///   dolgu 8, üst dolgu `viewPadding.top − 4` (gerçek inset, K-07; negatif
///   olmaz). Düğmeler `GuIconButton(onCover: true)`; anahtarlar çağırandan.
/// * [scrollOffset] çağıranın `ScrollController`'ından beslenen
///   `ValueListenable`'dır; yalnızca kapağın dönüşümü yeniden kurulur.
/// * Başlık üst güvenli alanın altına uzanır; durum çubuğu stili
///   (`GuSystemUi(lightIcons)`, D-20) çağırandadır.
class GuParallaxHeader extends StatelessWidget {
  const GuParallaxHeader({
    required this.cover,
    required this.scrollOffset,
    this.leading,
    this.actions = const [],
    this.height = GuSizes.parallaxHeight,
    this.factor = GuSizes.parallaxFactor,
    super.key,
  });

  /// Kapak (`GuCover`, oran `fill`).
  final Widget cover;

  /// Kaydırma ofseti (dp).
  final ValueListenable<double> scrollOffset;

  /// Sol düğme (geri).
  final Widget? leading;

  /// Sağ düğmeler (paylaş, menü).
  final List<Widget> actions;

  /// Başlık yüksekliği (dp).
  final double height;

  /// Kapak kayma çarpanı.
  final double factor;

  /// [offset] için kapağın dikey kayması (dp).
  double coverShift(double offset) => offset.clamp(0, height) * factor;

  @override
  Widget build(BuildContext context) {
    final top = math.max<double>(
      0,
      MediaQuery.viewPaddingOf(context).top - GuSizes.parallaxBarTopOffset,
    );
    final back = leading;
    return SizedBox(
      height: height,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ValueListenableBuilder<double>(
              valueListenable: scrollOffset,
              builder: (context, offset, child) => Transform.translate(
                offset: Offset(0, coverShift(offset)),
                child: child,
              ),
              child: cover,
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: GuInsets.only(
                  left: GuSizes.parallaxBarPaddingX,
                  top: top,
                  right: GuSizes.parallaxBarPaddingX,
                ),
                child: Row(
                  spacing: GuSpacing.s4,
                  children: [?back, const Spacer(), ...actions],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
