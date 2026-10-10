import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/tokens/gu_motion.dart';
import 'package:gu_ui/src/tokens/gu_radius.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';
import 'package:gu_ui/src/widgets/display/gu_card.dart';

/// İskelet bloğu — prototip `Skeleton` (`ui.js:94`), CSS `.sk` / `.sk.circle`
/// (css:263–264), `@keyframes shimmer` (css:417).
///
/// * Zemin: `bg.surfaceMuted` → `border.soft` → `bg.surfaceMuted` yatay
///   gradyanı (%25 / %50 / %75), kutunun iki katı genişlikte ve yinelenerek
///   1,2 sn'de doğrusal kayar (`GuMotion.shimmer`).
/// * Genişlik: [width] (dp), [widthFactor] (ebeveynin oranı, `w="55%"`) ya da
///   ikisi de `null` → tam genişlik (`w = '100%'`). Yükseklik [height]
///   (varsayılan 14).
/// * [circle] → `border-radius:50%`; değilse [borderRadius] (varsayılan 8;
///   kart kapağında `BorderRadius.zero`, `ui.js:97`).
/// * Azaltılmış harekette (css:427 `.sk{animation:none}`) ve
///   [debugAnimate] `false` iken durağandır.
/// * Dekoratiftir (`aria-hidden`, `ExcludeSemantics`); "yükleniyor" etiketi
///   [GuSkeletonList]'tedir.
class GuSkeleton extends StatefulWidget {
  const GuSkeleton({
    this.width,
    this.widthFactor,
    this.height = GuSizes.skeletonLineHeight,
    this.circle = false,
    this.borderRadius = GuRadius.borderSkeleton,
    super.key,
  }) : assert(
         width == null || widthFactor == null,
         'width ve widthFactor birlikte verilemez.',
       );

  /// `false` → shimmer oynatılmaz (durağan gradyan). Testlerde `pumpApp`
  /// kapatır: sonsuz animasyon `pumpAndSettle`'ı kilitler ve golden'ı
  /// kararsız yapar (CD-122(2), testing.md).
  static bool debugAnimate = true;

  /// Sabit genişlik (dp); `null` → [widthFactor] ya da tam genişlik.
  final double? width;

  /// Ebeveyn genişliğinin oranı (0–1).
  final double? widthFactor;

  /// Yükseklik (dp).
  final double height;

  /// Daire / elips (`.sk.circle`).
  final bool circle;

  /// Köşe yarıçapı ([circle] değilken).
  final BorderRadius borderRadius;

  @override
  State<GuSkeleton> createState() => _GuSkeletonState();
}

class _GuSkeletonState extends State<GuSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: GuMotion.shimmer,
    value: _SkeletonPainter.restProgress,
  );
  late final Animation<double> _progress = _controller.drive(
    CurveTween(curve: GuMotion.shimmerCurve),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!GuSkeleton.debugAnimate || context.gu.reduceMotion) {
      _controller
        ..stop()
        ..value = _SkeletonPainter.restProgress;
    } else if (!_controller.isAnimating) {
      // Sürekli kayma; `TickerFuture` beklenmez (widget ömrünce sürer).
      _controller.value = 0;
      unawaited(_controller.repeat());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.gu.colors;
    final factor = widget.widthFactor;
    final block = SizedBox(
      width: widget.width ?? double.infinity,
      height: widget.height,
      child: CustomPaint(
        painter: _SkeletonPainter(
          progress: _progress,
          base: colors.bgSurfaceMuted,
          highlight: colors.borderSoft,
          circle: widget.circle,
          borderRadius: widget.borderRadius,
        ),
      ),
    );
    return ExcludeSemantics(
      child: factor == null
          ? block
          : FractionallySizedBox(
              widthFactor: factor,
              alignment: AlignmentDirectional.centerStart,
              child: block,
            ),
    );
  }
}

/// CSS `background:linear-gradient(90deg, muted 25%, soft 50%, muted 75%);
/// background-size:200% 100%` (css:263) + `background-position` 200% → −200%
/// (css:417): 2 × genişlikteki karo −2W'den +2W'ye kayar.
class _SkeletonPainter extends CustomPainter {
  const _SkeletonPainter({
    required this.progress,
    required this.base,
    required this.highlight,
    required this.circle,
    required this.borderRadius,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final Color base;
  final Color highlight;
  final bool circle;
  final BorderRadius borderRadius;

  /// `animation:none` → `background-position:0` = kaymanın orta noktası.
  static const double restProgress = 0.5;

  /// `background-size:200%`: karo x = 0'dan 2W'ye uzanır.
  static const Alignment _tileEnd = Alignment(3, 0);

  /// Renk durakları (css:263).
  static const List<double> _stops = [0.25, 0.5, 0.75];

  /// Kayma aralığı, kutu genişliği cinsinden: −2 … +2 (css:417).
  static const double _travelStart = -2;
  static const double _travelSpan = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = LinearGradient(
        end: _tileEnd,
        colors: [base, highlight, base],
        stops: _stops,
        tileMode: TileMode.repeated,
        transform: _SlideTransform(
          _travelStart + _travelSpan * progress.value,
        ),
      ).createShader(rect);
    if (circle) {
      canvas.drawOval(rect, paint);
    } else {
      canvas.drawRRect(borderRadius.toRRect(rect), paint);
    }
  }

  @override
  bool shouldRepaint(_SkeletonPainter oldDelegate) =>
      oldDelegate.base != base ||
      oldDelegate.highlight != highlight ||
      oldDelegate.circle != circle ||
      oldDelegate.borderRadius != borderRadius;
}

/// Gradyanı kutu genişliğinin [widths] katı kadar yatay kaydırır.
class _SlideTransform extends GradientTransform {
  const _SlideTransform(this.widths);

  final double widths;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * widths, 0, 0);
}

/// Liste iskeleti türü (`ui.js:95` `variant`).
enum GuSkeletonVariant {
  /// Satır: 40 daire + %55 / 14 ve %80 / 12 çizgiler (`.tile.is-plain`).
  tile,

  /// Kart: 140 kapak + %60 / 16, %90 / 14, %40 / 14 çizgiler (`.card`).
  card,
}

/// Liste iskeleti — prototip `SkeletonList` (`ui.js:95–99`); `GuListState`
/// yükleniyor durumunun varsayılan gövdesi.
///
/// * `tile`: [count] satır; satır kabuğu `.tile.is-plain` (en az 56, dolgu
///   8 / 16, aralık 12), metin sütunu aralığı 6.
/// * `card`: yatay 16 dolgu, kartlar arası 12 (`col gap12 px16`); kart gövdesi
///   dolgu 16, çizgi aralığı 8.
/// * `aria-busy` + `aria-label`: gövde semantikten dışlanır, [semanticLabel]
///   canlı bölge olarak okunur (metin çağırandan — ARB `commonLoading`).
class GuSkeletonList extends StatelessWidget {
  const GuSkeletonList({
    required this.semanticLabel,
    this.count = 4,
    this.variant = GuSkeletonVariant.tile,
    super.key,
  });

  /// "Yükleniyor" etiketi.
  final String semanticLabel;

  /// Öğe sayısı (ekranlarda 3–6).
  final int count;

  /// Satır / kart.
  final GuSkeletonVariant variant;

  // `GuSizes.skeletonWidthRatios` sırası: satır %55, %80; kart %60, %90, %40.
  static double _ratio(int index) => GuSizes.skeletonWidthRatios[index];

  @override
  Widget build(BuildContext context) {
    final items = [
      for (var i = 0; i < count; i++)
        switch (variant) {
          GuSkeletonVariant.tile => _tile(),
          GuSkeletonVariant.card => _card(),
        },
    ];
    final list = switch (variant) {
      GuSkeletonVariant.tile => Column(
        mainAxisSize: MainAxisSize.min,
        children: items,
      ),
      GuSkeletonVariant.card => Padding(
        padding: GuInsets.h16,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: GuSpacing.s12,
          children: items,
        ),
      ),
    };
    return Semantics(
      container: true,
      liveRegion: true,
      label: semanticLabel,
      child: ExcludeSemantics(child: RepaintBoundary(child: list)),
    );
  }

  Widget _tile() => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: GuSizes.tileMinHeight),
    child: Padding(
      padding: GuInsets.sym(h: GuSizes.tilePaddingX, v: GuSizes.tilePaddingY),
      child: Row(
        spacing: GuSizes.tileGap,
        children: [
          const GuSkeleton(
            width: GuSizes.skeletonAvatar,
            height: GuSizes.skeletonAvatar,
            circle: true,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: GuSpacing.s6,
              children: [
                GuSkeleton(widthFactor: _ratio(0)),
                GuSkeleton(
                  widthFactor: _ratio(1),
                  height: GuSizes.skeletonSubHeight,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _card() => GuCard(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GuSkeleton(
          height: GuSizes.skeletonCardCover,
          borderRadius: BorderRadius.zero,
        ),
        Padding(
          padding: GuCard.bodyPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: GuSpacing.s8,
            children: [
              GuSkeleton(
                widthFactor: _ratio(2),
                height: GuSizes.skeletonTitleHeight,
              ),
              GuSkeleton(widthFactor: _ratio(3)),
              GuSkeleton(widthFactor: _ratio(4)),
            ],
          ),
        ),
      ],
    ),
  );
}
