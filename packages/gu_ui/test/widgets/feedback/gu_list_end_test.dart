// T-06 · GuListEnd (widget-catalog #28; ui.js:123; css:96, 99).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

void main() {
  group('T-06 · GuListEnd', () {
    testWidgets('T-06 · GuListEnd · "— etiket —" ortalı caption, dolgu '
        '20 / 16 / 8; ekran okuyucu yalnız etiketi okur', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpApp(
        const Align(
          alignment: Alignment.topCenter,
          child: GuListEnd(label: 'Hepsi bu kadar'),
        ),
      );
      final line = find.text('— Hepsi bu kadar —');
      final text = tester.widget<Text>(line);
      expect(text.style, GuTypography.resolve(GuColors.light).caption);
      expect(text.style?.color, GuColors.light.textMuted);
      expect(text.textAlign, TextAlign.center);
      // caption satırı 12 × 1.3333 = 16.
      expect(
        tester.getSize(find.byType(GuListEnd)),
        const Size(
          390,
          GuSizes.listEndPaddingTop + 16 + GuSizes.listEndPaddingBottom,
        ),
      );
      expect(tester.getTopLeft(line).dy, GuSizes.listEndPaddingTop);
      expect(tester.getCenter(line).dx, 195);
      expect(
        tester.getSemantics(line),
        matchesSemantics(label: 'Hepsi bu kadar'),
      );
      handle.dispose();
    });

    testWidgets('T-06 · GuListEnd · 320 dp × metin ölçeği 1.6 + uzun etiket '
        '→ sarar, taşma yok', (tester) async {
      // Çalışma anı değeri: etiket ARB'den gelir (const değil).
      final label = [
        'Bu kulübün tüm hareket kayıtlarını',
        'görüntüledin',
      ].join(' ');
      await tester.pumpApp(
        Align(
          alignment: Alignment.topCenter,
          child: GuListEnd(label: label),
        ),
        size: const Size(320, 640),
        textScale: 1.6,
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(Text)).width,
        lessThanOrEqualTo(320 - 2 * GuSizes.listEndPaddingX),
      );
    });
  });
}
