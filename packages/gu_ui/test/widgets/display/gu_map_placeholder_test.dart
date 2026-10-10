// T-06 · GuMapPlaceholder (widget-catalog #79; A.2 #79; css:410;
// screens-events.js:65; CD-25, CD-19 / K-26, K-57, CD-88).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

const _label = 'map placeholder · Bilgisayar Laboratuvarı-2';

final Finder _placeholder = find.byType(GuMapPlaceholder);
final Finder _paint = find.descendant(
  of: _placeholder,
  matching: find.byType(CustomPaint),
);

void main() {
  group('T-06 · GuMapPlaceholder', () {
    testWidgets('T-06 · GuMapPlaceholder · 120 yükseklik, radius 12, şerit '
        'zemini + 1 px border.soft, yazı mapPlaceholder (ölçeklenmez) açık + '
        'koyu; Semantics', (tester) async {
      final handle = tester.ensureSemantics();
      for (final (mode, colors) in [
        (ThemeMode.light, GuColors.light),
        (ThemeMode.dark, GuColors.dark),
      ]) {
        await tester.pumpApp(
          const Center(
            child: Padding(
              padding: GuInsets.all16,
              child: GuMapPlaceholder(label: _label),
            ),
          ),
          theme: mode,
        );
        expect(
          tester.getSize(_placeholder),
          const Size(358, GuSizes.mapPlaceholderHeight),
        );
        final outer = RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 0, 358, 120),
          const Radius.circular(GuRadius.sm),
        );
        expect(
          _paint,
          paints
            // Şeritler: yinelenen sert geçişli gradyan (shader) ile dolgu.
            ..something(
              (method, arguments) =>
                  method == #drawRRect &&
                  arguments[0] == outer &&
                  (arguments[1] as Paint).shader != null,
            )
            ..rrect(
              rrect: outer.deflate(GuSizes.mapPlaceholderBorder / 2),
              color: colors.borderSoft,
              strokeWidth: GuSizes.mapPlaceholderBorder,
              style: PaintingStyle.stroke,
            ),
          reason: '$mode',
        );

        final text = tester.widget<Text>(find.text(_label));
        expect(text.style, GuTypography.resolve(colors).mapPlaceholder);
        expect(text.style!.color, colors.textMuted);
        expect(text.textScaler, TextScaler.noScaling);
        expect(text.textAlign, TextAlign.center);
        expect(
          tester.getCenter(find.text(_label)),
          tester.getCenter(_placeholder),
        );
        expect(
          tester.getSemantics(find.text(_label)),
          isSemantics(label: _label),
        );
      }
      handle.dispose();
    });

    testWidgets('T-06 · GuMapPlaceholder · 320 × 640, ölçek 1.6: uzun metin '
        'taşmaz (en çok 3 satır), kutu 120 kalır', (tester) async {
      final long = ValueNotifier<bool>(false);
      addTearDown(long.dispose);
      await tester.pumpApp(
        Padding(
          padding: GuInsets.all16,
          child: ValueListenableBuilder<bool>(
            valueListenable: long,
            builder: (context, isLong, _) => Align(
              alignment: Alignment.topCenter,
              child: GuMapPlaceholder(
                label: isLong ? '$_label ' * 12 : _label,
              ),
            ),
          ),
        ),
        size: const Size(320, 640),
        textScale: 1.6,
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(_placeholder), const Size(288, 120));
      // Ölçek 1.6'da da 12 px tek satır (K-57).
      final single = tester.getSize(find.byType(Text));

      long.value = true;
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(_placeholder), const Size(288, 120));
      final wrapped = tester.getSize(find.byType(Text));
      expect(wrapped.height, closeTo(single.height * 3, 0.01));
      expect(wrapped.width, lessThanOrEqualTo(288 - 2 * GuSpacing.s8));
    });
  });
}
