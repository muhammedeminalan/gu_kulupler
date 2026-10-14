import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Bilet QR'ı — prototip `.qr` (`component-css.css:326–327`,
/// `screens-events.js:83`; A.2 #78, CD-25, D-30).
///
/// * [data] QR yüküdür: `gu:ticket:v1:{eventId}:{ticketCode}`
///   (`RsvpModel.qrPayload`). Hata düzeltme `M` (ekrandan okutma).
/// * [state]: `valid` normal · `used` bulanık (`blur` 3 + opaklık .5,
///   `.qr.is-blur svg`) · `voided` çapraz `state.danger` çizgisi
///   (`.qr.is-void::after`: sol %10, üst %50, genişlik %80, 4 px, −30°).
/// * 220 × 220, dolgu 12, `GuRadius.sm`; zemin `qrBackground` ve modül
///   `qrModule` her temada sabittir (koyu temada da beyaz kart).
/// * [semanticLabel] bilet durumunu söyler (QR görüntüsü okunmaz).
class QrCodeView extends StatelessWidget {
  /// [data] yükünün [state] durumundaki QR'ı.
  const QrCodeView({
    required this.data,
    required this.state,
    required this.semanticLabel,
    super.key,
  });

  /// QR yükü (`gu:ticket:v1:…`).
  final String data;

  /// Bilet durumu.
  final TicketState state;

  /// Ekran okuyucu etiketi.
  final String semanticLabel;

  /// İptal çizgisinin açısı (radyan; css:327 `rotate(-30deg)`).
  static const double voidAngle = GuSizes.qrVoidAngleDeg * math.pi / 180;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final component = gu.component;
    Widget code = QrImageView(
      data: data,
      padding: EdgeInsets.zero,
      backgroundColor: component.qrBackground,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      eyeStyle: QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: component.qrModule,
      ),
      dataModuleStyle: QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: component.qrModule,
      ),
    );
    if (state == TicketState.used) {
      code = Opacity(
        opacity: GuOpacity.qrBlurred,
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: GuSizes.qrBlurSigma,
            sigmaY: GuSizes.qrBlurSigma,
          ),
          child: code,
        ),
      );
    }
    return Semantics(
      label: semanticLabel,
      image: true,
      excludeSemantics: true,
      child: Container(
        width: GuSizes.qr,
        height: GuSizes.qr,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: component.qrBackground,
          borderRadius: GuRadius.borderSm,
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: GuInsets.all12,
                child: code,
              ),
            ),
            if (state == TicketState.voided)
              Positioned(
                left: GuSizes.qr * GuSizes.qrVoidLeft,
                top: GuSizes.qr / 2,
                width: GuSizes.qr * GuSizes.qrVoidWidth,
                height: GuSizes.qrVoidLineHeight,
                child: Transform.rotate(
                  angle: voidAngle,
                  child: ColoredBox(color: gu.colors.stateDanger),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
