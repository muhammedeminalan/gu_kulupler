import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_ui/gu_ui.dart';

/// MGT-07 tarayıcı katmanı — prototip `.scan-view` (`screens-manage.js:150–
/// 155`; css:335, 401–404, 422): kamera önizlemesinin ([preview]) üstünde
/// üst satır (kapat · etkinlik başlığı [title] + sayaç [counterLabel] ·
/// fener · kamera çevir), ortada köşe çerçevesi (240, köşe 36, çizgi 3) +
/// tarama çizgisi (`GuMotion.scan`; azaltılmış hareket → durağan) + ipucu
/// [hintLabel], altta yarı saydam panel: "Kodu elle gir" (outline) ya da
/// açıkken [manualField] (kod alanı + "Doğrula"; çağıran kurar). Demo tarama
/// düğmeleri yoktur (K-02, K-04).
///
/// * [torchOn] fener düğmesini dolu çizer; [frontCamera] çerçeveyi aynalar.
/// * Renkler `GuColors` `scanView*` + `scanMutedForeground` /
///   `scanPanelScrim` / `scanOutlineBorder` (CD-87); durum çubuğu açık ikonlu
///   `GuSystemUi(lightIcons)` view'dadır (D-20).
/// * Tek ekranlık feature widget'ıdır (CD-25): anahtarlar burada sabittir
///   ([closeKey], [torchKey], [flipKey], [manualCodeKey]).
///
/// Design: MGT-07
class ScanOverlay extends StatelessWidget {
  /// [preview] üstünde tarayıcı katmanı.
  const ScanOverlay({
    required this.preview,
    required this.title,
    required this.counterLabel,
    required this.hintLabel,
    required this.onClose,
    required this.onTorch,
    required this.onFlip,
    required this.onManualCode,
    this.torchOn = false,
    this.frontCamera = false,
    this.manualOpen = false,
    this.manualField,
    super.key,
  });

  /// Kamera önizlemesi (`QrScannerController.buildPreview`); tam alanı
  /// kaplar.
  final Widget preview;

  /// Etkinlik başlığı (tek satır, ellipsis).
  final String title;

  /// Sayaç ("Katıldı a/b" — `scanCounter`).
  final String counterLabel;

  /// Çerçeve altındaki ipucu (`scanHint`).
  final String hintLabel;

  /// Kapat (`MGT-07.close`).
  final VoidCallback onClose;

  /// Fener (`MGT-07.torch`).
  final VoidCallback onTorch;

  /// Kamera çevir (`MGT-07.flip`).
  final VoidCallback onFlip;

  /// "Kodu elle gir" (`MGT-07.manualCode`).
  final VoidCallback onManualCode;

  /// Fener açık mı.
  final bool torchOn;

  /// Ön kamera mı (çerçeve aynalanır).
  final bool frontCamera;

  /// Elle kod alanı açık mı ([manualField] çizilir).
  final bool manualOpen;

  /// Elle kod satırı (alan + "Doğrula"); [manualOpen] iken çizilir.
  final Widget? manualField;

  /// Kapat düğmesinin anahtarı (`MGT-07.close`).
  static final Key closeKey = GuKey.action('MGT-07.close');

  /// Fener düğmesinin anahtarı (`MGT-07.torch`).
  static final Key torchKey = GuKey.action('MGT-07.torch');

  /// Kamera çevir düğmesinin anahtarı (`MGT-07.flip`).
  static final Key flipKey = GuKey.action('MGT-07.flip');

  /// "Kodu elle gir" düğmesinin anahtarı (`MGT-07.manualCode`).
  static final Key manualCodeKey = GuKey.action('MGT-07.manualCode');

  /// Testte tarama çizgisi durağan çizilir (`pumpAndSettle` sonsuz
  /// animasyonda kilitlenmesin; `GuSkeleton.debugAnimate` kalıbı).
  @visibleForTesting
  static bool debugAnimate = true;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final onCover = gu.component.onCoverForeground;
    final muted = gu.component.scanMutedForeground;
    final field = manualField;
    return ScanBackdrop(
      child: Stack(
        fit: StackFit.expand,
        children: [
          preview,
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // `.row.gap4` `padding:4px 8px`.
                Padding(
                  padding: GuInsets.sym(h: GuSpacing.s8, v: GuSpacing.s4),
                  child: Row(
                    spacing: GuSpacing.s4,
                    children: [
                      GuIconButton(
                        key: closeKey,
                        icon: GuIcons.x,
                        semanticLabel: l10n.a11yClose,
                        onCover: true,
                        onPressed: onClose,
                      ),
                      Expanded(
                        child: Padding(
                          padding: GuInsets.h8,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                style: gu.text.titleS.copyWith(color: onCover),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                counterLabel,
                                style: gu.text.caption.copyWith(color: muted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                      _TorchButton(
                        key: torchKey,
                        on: torchOn,
                        label: l10n.scanTorch,
                        onPressed: onTorch,
                      ),
                      GuIconButton(
                        key: flipKey,
                        icon: GuIcons.switchCamera,
                        semanticLabel: l10n.scanFlip,
                        onCover: true,
                        onPressed: onFlip,
                      ),
                    ],
                  ),
                ),
                // `.flex1.col` ortalı, `gap:16px`.
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        spacing: GuSpacing.s16,
                        children: [
                          Transform.flip(
                            flipX: frontCamera,
                            child: const _ScanBox(),
                          ),
                          Padding(
                            padding: GuInsets.h16,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: GuSizes.scanHintMaxWidth,
                              ),
                              child: Text(
                                hintLabel,
                                style: gu.text.bodyS.copyWith(color: muted),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Alt panel: `padding:16px 16px calc(safe-bottom + 16px)`,
                // `background:rgba(0,0,0,.35)`.
                ColoredBox(
                  color: gu.component.scanPanelScrim,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: GuInsets.all16,
                      child: manualOpen && field != null
                          ? field
                          : ScanOutlineButton(
                              key: manualCodeKey,
                              icon: GuIcons.pencil,
                              label: l10n.scanManualCode,
                              onPressed: onManualCode,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// `.scan-view` zemini: `radial-gradient(ellipse at 50% 40%, #2a2f3a,
/// #0b0d12 75%)` (css:401). CSS `ellipse farthest-corner`: yarıçaplar
/// `√2 · max(cx, w − cx)` ve `√2 · max(cy, h − cy)`; Flutter'da daire
/// gradyanı dikeyde ölçeklenerek elips yapılır.
class ScanBackdrop extends StatelessWidget {
  /// [child] arkasında tarayıcı zemini.
  const ScanBackdrop({required this.child, super.key});

  /// Zeminin üstündeki içerik.
  final Widget child;

  /// Gradyan merkezi (`50% 40%`).
  static const Alignment center = Alignment(0, -0.2);

  @override
  Widget build(BuildContext context) {
    final component = context.gu.component;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final cx = size.width * (center.x + 1) / 2;
        final cy = size.height * (center.y + 1) / 2;
        final rx = math.sqrt2 * math.max(cx, size.width - cx);
        final ry = math.sqrt2 * math.max(cy, size.height - cy);
        final shortest = math.max(size.shortestSide, 1);
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: center,
              radius: rx / shortest,
              colors: [
                component.scanViewGradientStart,
                component.scanViewGradientEnd,
              ],
              stops: const [0, GuSizes.scanGradientStop],
              transform: _EllipseTransform(rx == 0 ? 1 : ry / rx),
            ),
          ),
          child: child,
        );
      },
    );
  }
}

/// Daire gradyanını merkezi etrafında dikeyde [scaleY] kadar uzatır.
class _EllipseTransform extends GradientTransform {
  const _EllipseTransform(this.scaleY);

  final double scaleY;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final cx = bounds.left + bounds.width * (ScanBackdrop.center.x + 1) / 2;
    final cy = bounds.top + bounds.height * (ScanBackdrop.center.y + 1) / 2;
    return Matrix4.identity()
      ..translateByDouble(cx, cy, 0, 1)
      ..scaleByDouble(1, scaleY, 1, 1)
      ..translateByDouble(-cx, -cy, 0, 1);
  }
}

/// Fener: kapalıyken `IconButton onCover`; açıkken beyaz zemin + siyah ikon
/// (prototip `style={background:'#fff',color:'#000'}`).
class _TorchButton extends StatelessWidget {
  const _TorchButton({
    required this.on,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final bool on;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final component = context.gu.component;
    if (!on) {
      return GuIconButton(
        icon: GuIcons.flashlight,
        semanticLabel: label,
        onCover: true,
        onPressed: onPressed,
      );
    }
    return Semantics(
      toggled: true,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.square(
            dimension: GuSizes.iconButton,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: component.onCoverForeground,
                borderRadius: GuRadius.borderFull,
              ),
            ),
          ),
          DefaultTextStyle.merge(
            style: TextStyle(color: component.viewerBackground),
            child: GuIconButton(
              icon: GuIcons.flashlight,
              semanticLabel: label,
              foregroundInherit: true,
              onPressed: onPressed,
            ),
          ),
        ],
      ),
    );
  }
}

/// MGT-07'nin karanlık zemin üstündeki outline düğmesi (prototip
/// `Button variant="outline"` + `style={color:'#fff', borderColor:
/// 'rgba(255,255,255,.4)', background:'transparent'}`; screens-manage.js:149,
/// :154): `GuButton` ölçüleri (md, tam genişlik), beyaz yazı / ikon,
/// `scanOutlineBorder` kenarlık, zeminsiz.
class ScanOutlineButton extends StatelessWidget {
  /// [label] etiketli düğme; [icon] varsa başta.
  const ScanOutlineButton({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  });

  /// Etiket.
  final String label;

  /// Dokunma.
  final VoidCallback onPressed;

  /// Baştaki ikon.
  final GuIcons? icon;

  @override
  Widget build(BuildContext context) => GuActionSurface(
    onTap: onPressed,
    semanticLabel: label,
    borderRadius: GuRadius.borderSm,
    builder: (context, pressed) {
      final gu = context.gu;
      final foreground = gu.component.onCoverForeground;
      final glyph = icon;
      final duration = gu.duration(GuMotion.fast);
      return AnimatedScale(
        scale: pressed ? GuMotion.pressScale : 1,
        duration: duration,
        curve: GuMotion.easeCss,
        child: Container(
          constraints: BoxConstraints(minHeight: GuButtonSize.md.minHeight),
          padding: GuInsets.sym(h: GuButtonSize.md.paddingX),
          decoration: BoxDecoration(
            borderRadius: GuRadius.borderSm,
            border: Border.all(color: gu.component.scanOutlineBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: GuSizes.buttonGap,
            children: [
              if (glyph != null)
                GuIcon(
                  glyph,
                  size: GuButtonSize.md.iconSize,
                  color: foreground,
                ),
              Flexible(
                child: Text(
                  label,
                  style: gu.text.button.copyWith(color: foreground),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// `.scan-box` (css:402–404) + `.scanline` (css:335, 422): 240 kare, dört
/// köşe (36, çizgi 3, köşe yarıçapı 4) ve %8 ↔ %90 arasında gidip gelen
/// marka rengi çizgi (2.2 sn, ease-in-out; azaltılmış hareket → durağan).
class _ScanBox extends ConsumerStatefulWidget {
  const _ScanBox();

  @override
  ConsumerState<_ScanBox> createState() => _ScanBoxState();
}

class _ScanBoxState extends ConsumerState<_ScanBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: GuMotion.scan,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate =
        ScanOverlay.debugAnimate &&
        context.gu.duration(GuMotion.scan) != Duration.zero;
    if (animate && !_controller.isAnimating) {
      unawaited(_controller.repeat());
    } else if (!animate && _controller.isAnimating) {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// `@keyframes scan{0%,100%{top:8%}50%{top:90%}}`; her yarı ease-in-out.
  static double _top(double t) {
    const span = GuSizes.scanLineTopMax - GuSizes.scanLineTopMin;
    final half = t < 0.5;
    final p = GuMotion.scanCurve.transform(half ? t * 2 : (t - 0.5) * 2);
    return half
        ? GuSizes.scanLineTopMin + span * p
        : GuSizes.scanLineTopMax - span * p;
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final corner = gu.component.scanBoxCorner;
    final brand = gu.colors.brandPrimary;
    return SizedBox.square(
      dimension: GuSizes.scanBox,
      child: Stack(
        children: [
          for (final position in _Corner.values)
            Positioned(
              top: position.top ? 0 : null,
              bottom: position.top ? null : 0,
              left: position.left ? 0 : null,
              right: position.left ? null : 0,
              child: CustomPaint(
                size: const Size.square(GuSizes.scanCorner),
                painter: _CornerPainter(position, corner),
              ),
            ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => Positioned(
              top: GuSizes.scanBox * _top(_controller.value),
              left: GuSizes.scanBox * GuSizes.scanLineInsetX,
              right: GuSizes.scanBox * GuSizes.scanLineInsetX,
              height: GuSizes.scanLineHeight,
              child: child!,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: brand,
                boxShadow: [
                  BoxShadow(
                    color: brand,
                    blurRadius: GuShadows.cssBlurToRadius(GuSizes.scanLineGlow),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Çerçeve köşesi (`.scan-box>i:nth-child(1…4)`).
enum _Corner {
  topLeft(top: true, left: true),
  topRight(top: true, left: false),
  bottomLeft(top: false, left: true),
  bottomRight(top: false, left: false);

  const _Corner({required this.top, required this.left});

  final bool top;
  final bool left;
}

/// Köşe: iki kenarı [GuSizes.scanCornerStroke] kalınlığında, dış köşesi
/// [GuRadius.scanCorner] yuvarlatılmış "L" (CSS `border` + `border-radius:4px`;
/// iki kenarı sıfır kutu).
class _CornerPainter extends CustomPainter {
  const _CornerPainter(this.corner, this.color);

  final _Corner corner;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = GuSizes.scanCornerStroke;
    const half = stroke / 2;
    const radius = GuRadius.scanCorner - half;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    // Sol üst köşe için çizilir; diğerleri aynalanır.
    canvas
      ..save()
      ..translate(corner.left ? 0 : size.width, corner.top ? 0 : size.height)
      ..scale(corner.left ? 1 : -1, corner.top ? 1 : -1);
    final path = Path()
      ..moveTo(half, size.height)
      ..lineTo(half, half + radius)
      ..arcToPoint(
        const Offset(half + radius, half),
        radius: const Radius.circular(radius),
      )
      ..lineTo(size.width, half);
    canvas
      ..drawPath(path, paint)
      ..restore();
  }

  @override
  bool shouldRepaint(_CornerPainter oldDelegate) =>
      oldDelegate.corner != corner || oldDelegate.color != color;
}
