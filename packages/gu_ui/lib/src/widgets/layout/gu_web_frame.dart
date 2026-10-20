import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/tokens/gu_breakpoints.dart';
import 'package:gu_ui/src/tokens/gu_motion.dart';
import 'package:gu_ui/src/tokens/gu_radius.dart';
import 'package:gu_ui/src/tokens/gu_web_layout.dart';
import 'package:gu_ui/src/widgets/layout/gu_content_column.dart';

/// Web çerçevesi (H-23) — tasarımda karşılığı yoktur (prototip 390 px
/// telefon). Düzen fikri referans projeden: geniş pencerede uygulama desenli
/// zeminin ortasında yuvarlak köşeli, gölgeli bir "telefon kartı" içinde
/// çizilir; [sidebar] kartın soluna kayarak gelir.
///
/// * [framed] `false` → [child] pencereyi doldurur, süs yoktur (telefon /
///   dar pencere; bugünkü davranış).
/// * [framed] `true` → kart genişliği kalan alana göre
///   `GuBreakpoints.maxContentWidth` (480) – `GuWebLayout.cardMaxWidth`
///   (768), yüksekliği pencere − 2 × `GuWebLayout.framePadding`; kart
///   içindeki `MediaQuery.size` kartın boyutudur ve `GuContentColumn` sütun
///   açmaz (sayfa, sheet, toast kartın tamamını kullanır).
/// * [showSidebar] → [sidebar] kartın soluna `GuMotion.slow` ile kayar ve
///   belirir, kart sağa kayar; hareket azaltılmışsa anında.
///
/// Ağacın biçimi hiçbir durumda değişmez (aynı üç `Stack` yuvası; yalnızca
/// konum ve süs değişir): [child] genellikle uygulamanın yönlendiricisidir
/// ve yeniden ebeveynlenirse sayfa durumunu yitirir.
class GuWebFrame extends StatefulWidget {
  const GuWebFrame({
    required this.child,
    required this.framed,
    this.sidebar,
    this.showSidebar = false,
    super.key,
  });

  /// Kartın içeriği (uygulama).
  final Widget child;

  /// Telefon kartı çerçevesi açık mı?
  final bool framed;

  /// Kartın solundaki yan menü; `null` → yok.
  final Widget? sidebar;

  /// Yan menü gösterilsin mi? (Yalnızca [framed] ve [sidebar] varken.)
  final bool showSidebar;

  @override
  State<GuWebFrame> createState() => _GuWebFrameState();
}

class _GuWebFrameState extends State<GuWebFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: GuMotion.slow,
    value: _wantsSidebar ? 1 : 0,
  );

  bool get _wantsSidebar =>
      widget.framed && widget.showSidebar && widget.sidebar != null;

  @override
  void didUpdateWidget(GuWebFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Denetleyici kareden sonra sürülür: başlatmak dinleyen kurucuları
    // kirletir, bu widget kurulurken buna izin yoktur.
    final target = _wantsSidebar ? 1.0 : 0.0;
    if (_controller.value == target && !_controller.isAnimating) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final now = _wantsSidebar ? 1.0 : 0.0;
      if (context.gu.reduceMotion) {
        _controller.value = now;
        return;
      }
      unawaited(
        now == 1 ? _controller.forward() : _controller.reverse(),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final colors = gu.colors;
    final framed = widget.framed;
    final media = MediaQuery.of(context);
    return ColoredBox(
      color: colors.bgCanvas,
      child: LayoutBuilder(
        builder: (context, constraints) => AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            // Çerçevesiz düzende yan menü ve kayma yoktur.
            final progress = framed
                ? GuMotion.easeEmphasized.transform(_controller.value)
                : 0.0;
            const pad = GuWebLayout.framePadding;
            const shift = GuWebLayout.sidebarWidth + GuWebLayout.sidebarGap;
            // Kart kalan genişliğe göre 480 – 768 arasında büyür.
            final cardWidth = framed
                ? (width - 2 * pad - shift * progress).clamp(
                    GuBreakpoints.maxContentWidth,
                    GuWebLayout.cardMaxWidth,
                  )
                : width;
            final cardHeight = framed ? height - 2 * pad : height;
            final total = cardWidth + shift * progress;
            final left = framed ? (width - total) / 2 : 0.0;
            final top = framed ? pad : 0.0;
            final cardLeft = left + shift * progress;
            final sidebarLeft =
                left +
                (1 - progress) *
                    GuWebLayout.sidebarWidth *
                    GuWebLayout.sidebarSlideRatio;
            final reveal =
                ((progress - GuWebLayout.sidebarRevealStart) /
                        (1 - GuWebLayout.sidebarRevealStart))
                    .clamp(0.0, 1.0);
            final sidebar = widget.sidebar;
            final cardRadius = framed ? GuRadius.borderXl : BorderRadius.zero;
            return Stack(
              children: [
                Positioned.fill(
                  child: framed
                      ? CustomPaint(
                          painter: _BackdropPainter(
                            top: colors.bgSurfaceMuted,
                            bottom: colors.bgCanvas,
                            dot: colors.borderDefault,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                Positioned(
                  left: sidebarLeft,
                  top: top,
                  width: GuWebLayout.sidebarWidth,
                  height: cardHeight,
                  child: sidebar != null && reveal > 0
                      ? Opacity(
                          opacity: reveal,
                          child: RepaintBoundary(child: sidebar),
                        )
                      : const SizedBox.shrink(),
                ),
                Positioned(
                  left: cardLeft,
                  top: top,
                  width: cardWidth,
                  height: cardHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.bgCanvas,
                      borderRadius: cardRadius,
                      border: framed
                          ? Border.all(
                              color: colors.borderSoft,
                              // Token değeri varsayılanla (1) aynı; kaynak
                              // token kalır.
                              // ignore: avoid_redundant_argument_values
                              width: GuWebLayout.outline,
                            )
                          : null,
                      boxShadow: framed ? gu.shadows.e2 : null,
                    ),
                    child: ClipRRect(
                      borderRadius: cardRadius,
                      child: MediaQuery(
                        data: media.copyWith(
                          size: Size(cardWidth, cardHeight),
                        ),
                        // Kart genişliği kartın kendisidir: içerideki
                        // sütun (`GuContentColumn`) kapalı.
                        child: GuContentColumnScope(
                          enabled: !framed,
                          child: RepaintBoundary(child: widget.child),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Zemin: yukarıdan aşağı [top] → [bottom] geçiş + [dot] renkli nokta ızgarası
/// (`GuWebLayout.backdropDotSpacing` aralık, `backdropDotRadius` yarıçap).
class _BackdropPainter extends CustomPainter {
  const _BackdropPainter({
    required this.top,
    required this.bottom,
    required this.dot,
  });

  final Color top;
  final Color bottom;
  final Color dot;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ).createShader(rect),
    );
    final paint = Paint()..color = dot;
    const step = GuWebLayout.backdropDotSpacing;
    for (var y = step / 2; y < size.height; y += step) {
      // Aşağı indikçe noktalar silikleşir (geçişle uyumlu).
      final fade = lerpDouble(1, 0, y / size.height)!;
      paint.color = dot.withValues(alpha: dot.a * fade);
      for (var x = step / 2; x < size.width; x += step) {
        canvas.drawCircle(
          Offset(x, y),
          GuWebLayout.backdropDotRadius,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter oldDelegate) =>
      oldDelegate.top != top ||
      oldDelegate.bottom != bottom ||
      oldDelegate.dot != dot;
}
