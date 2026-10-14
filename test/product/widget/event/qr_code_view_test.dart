// QrCodeView (CD-25, D-30) — prototip `.qr` (component-css.css:326–327):
// 220 × 220, dolgu 12, GuRadius.sm, sabit beyaz zemin + koyu modül (her
// temada); `used` bulanık (blur 3 + opaklık .5), `voided` −30° tehlike
// çizgisi; erişilebilirlik etiketi (QR okunmaz); açık + koyu golden.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/widget/event/qr_code_view.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';

const String _payload = 'gu:ticket:v1:e01:GU-CWV4-JMW9';
const String _label = 'Bilet QR kodu, Geçerli';

Widget _qr(TicketState state) => Center(
  child: QrCodeView(data: _payload, state: state, semanticLabel: _label),
);

void main() {
  group('QrCodeView', () {
    testWidgets('ölçü, zemin ve modül renkleri (açık + koyu aynı); yük D-30', (
      tester,
    ) async {
      for (final theme in [ThemeMode.light, ThemeMode.dark]) {
        await tester.pumpApp(_qr(TicketState.valid), theme: theme);
        final gu = tester.element(find.byType(QrCodeView)).gu;

        final box = find.descendant(
          of: find.byType(QrCodeView),
          matching: find.byType(Container),
        );
        expect(tester.getSize(box.first), const Size(220, 220));
        final decoration =
            tester.widget<Container>(box.first).decoration! as BoxDecoration;
        expect(decoration.color, gu.component.qrBackground);
        expect(decoration.color, const Color(0xFFFFFFFF));
        expect(decoration.borderRadius, GuRadius.borderSm);

        final image = tester.widget<QrImageView>(find.byType(QrImageView));
        expect(image.eyeStyle.color, gu.component.qrModule);
        expect(image.dataModuleStyle.color, gu.component.qrModule);
        expect(image.errorCorrectionLevel, QrErrorCorrectLevel.M);
        // Modül alanı 220 − 2 × 12.
        expect(tester.getSize(find.byType(QrImageView)), const Size(196, 196));
        expect(find.byType(ImageFiltered), findsNothing);
        expect(find.byType(Transform), findsNothing);
      }
    });

    testWidgets('used: bulanık (sigma 3) + opaklık .5; voided: %80 genişlik, '
        '4 px, −30° tehlike çizgisi', (tester) async {
      await tester.pumpApp(_qr(TicketState.used));
      expect(find.byType(ImageFiltered), findsOneWidget);
      final opacity = tester.widget<Opacity>(
        find.ancestor(
          of: find.byType(ImageFiltered),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, GuOpacity.qrBlurred);
      expect(find.byType(Transform), findsNothing);

      await tester.pumpApp(_qr(TicketState.voided));
      final gu = tester.element(find.byType(QrCodeView)).gu;
      expect(find.byType(ImageFiltered), findsNothing);
      final line = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(Transform),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(line.color, gu.colors.stateDanger);
      final positioned = tester.widget<Positioned>(
        find.ancestor(
          of: find.byType(Transform),
          matching: find.byType(Positioned),
        ),
      );
      expect(positioned.left, 22);
      expect(positioned.top, 110);
      expect(positioned.width, 176);
      expect(positioned.height, 4);
      expect(QrCodeView.voidAngle, closeTo(-math.pi / 6, 1e-9));
    });

    testWidgets('erişilebilirlik: tek görsel düğümü, etiket durumu söyler', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpApp(_qr(TicketState.valid));
      expect(
        tester.getSemantics(find.byType(QrCodeView)),
        matchesSemantics(label: _label, isImage: true),
      );
      handle.dispose();
    });

    testWidgets('golden: geçerli / okutuldu / iptal — açık + koyu', (
      tester,
    ) async {
      await goldenForThemes(
        tester,
        'qr_code_view',
        Builder(
          builder: (context) => ColoredBox(
            color: context.gu.colors.bgSurface,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: GuSpacing.s16,
                children: [
                  for (final state in TicketState.values)
                    QrCodeView(
                      data: _payload,
                      state: state,
                      semanticLabel: _label,
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  });
}
