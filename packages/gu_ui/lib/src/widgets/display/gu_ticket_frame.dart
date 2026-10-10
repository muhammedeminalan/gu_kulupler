import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/tokens/gu_radius.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';

/// Bilet çerçevesi — CSS `.ticket` + `.ticket-cut` (css:323–325), prototip
/// `screens-events.js:81–83` (EVT-03; CD-25): `bg.surface`, radius lg, 1 px
/// `border.soft`; üst gövde ([header]) ile alt gövde ([body]) arasında 2 px
/// kesik `border.default` çizgi ve iki yanda 24 px `bg.canvas` çentik.
///
/// Gövdeler `.card-body` dolgusuyla (16) sarılır; iç yerleşim (aralık,
/// hizalama) çağırana aittir. Çerçeve kenarlığı çentiğin üstünden kesintisiz
/// geçer (`overflow:hidden` iç kenardan kırpar).
class GuTicketFrame extends StatelessWidget {
  const GuTicketFrame({required this.header, required this.body, super.key});

  /// Üst gövde (kulüp, başlık, durum rozeti, tarih / mekân).
  final Widget header;

  /// Alt gövde (QR, kod, ad).
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final colors = context.gu.colors;
    final bodyPadding = GuInsets.sym(
      h: GuSizes.cardBodyPadding,
      v: GuSizes.cardBodyPadding,
    );
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: GuInsets.sym(h: GuSizes.cardBorder, v: GuSizes.cardBorder),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: GuRadius.borderLg,
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: GuRadius.borderLg,
        border: Border.all(
          color: colors.borderSoft,
          // Token değeri varsayılanla (1) aynı; kaynak token kalır.
          // ignore: avoid_redundant_argument_values
          width: GuSizes.cardBorder,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(padding: bodyPadding, child: header),
          Padding(
            padding: GuInsets.sym(h: GuSizes.ticketCutMarginX),
            child: SizedBox(
              height: GuSizes.ticketCutDash,
              child: CustomPaint(
                painter: _TicketCutPainter(
                  dash: colors.borderDefault,
                  notch: colors.bgCanvas,
                ),
              ),
            ),
          ),
          Padding(padding: bodyPadding, child: body),
        ],
      ),
    );
  }
}

/// `.ticket-cut` (css:324–325): kutu 2 px (`border-box`), kesik çizgi tüm
/// genişlikte; çentikler `top:-13px` / `left|right:-28px` → merkezleri
/// çizginin ortasında ve çerçevenin iç kenarında.
class _TicketCutPainter extends CustomPainter {
  const _TicketCutPainter({required this.dash, required this.notch});

  final Color dash;
  final Color notch;

  // Tarayıcı kesik kenarlık oranları (Blink `StyledStrokeData`): kalınlık
  // < 3 px → tire 3×, boşluk 2× kalınlık; boşluk iki uç da tire olacak
  // biçimde en yakın değere ayarlanır (referans EVT-03: tire 6, boşluk ≈ 4).
  // ignore-hardcode: eksik token — css:324 (`dashed` tire/boşluk oranı)
  static const double _dashLength = GuSizes.ticketCutDash * 3;
  // ignore-hardcode: eksik token — css:324 (`dashed` tire/boşluk oranı)
  static const double _gapLength = GuSizes.ticketCutDash * 2;

  static const double _notchRadius = GuSizes.ticketNotch / 2;

  /// [length] boyunca tire sayısı ve ayarlanmış boşluk (uçlar tire).
  static (int count, double gap) _dashesFor(double length) {
    if (length <= _dashLength * 2) return (1, 0);
    final fewer = ((length + _gapLength) / (_dashLength + _gapLength)).floor();
    final more = fewer + 1;
    final wideGap = fewer > 1
        ? (length - fewer * _dashLength) / (fewer - 1)
        : double.infinity;
    final narrowGap = (length - more * _dashLength) / (more - 1);
    final useWide =
        narrowGap <= 0 ||
        (wideGap - _gapLength).abs() < (narrowGap - _gapLength).abs();
    return useWide ? (fewer, wideGap) : (more, narrowGap);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final dashPaint = Paint()..color = dash;
    final notchPaint = Paint()..color = notch;
    final (count, gap) = _dashesFor(size.width);
    // Tek tire → boşluğa yer yok, çizgi kesiksiz.
    final dashWidth = count == 1 ? size.width : _dashLength;
    for (var i = 0; i < count; i++) {
      canvas.drawRect(
        Rect.fromLTWH(i * (_dashLength + gap), 0, dashWidth, size.height),
        dashPaint,
      );
    }
    const centerX = _notchRadius - GuSizes.ticketNotchOffset;
    const centerY =
        GuSizes.ticketCutDash - GuSizes.ticketNotchTop + _notchRadius;
    canvas
      ..drawCircle(const Offset(centerX, centerY), _notchRadius, notchPaint)
      ..drawCircle(
        Offset(size.width - centerX, centerY),
        _notchRadius,
        notchPaint,
      );
  }

  @override
  bool shouldRepaint(_TicketCutPainter oldDelegate) =>
      oldDelegate.dash != dash || oldDelegate.notch != notch;
}
