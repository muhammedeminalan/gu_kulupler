// T-06 · GuMapPlaceholder (widget-catalog #79; EVT-02 konum görseli;
// CD-25). H-24: kapak deseni + büyük pin (tasarımdaki şeritli kutu yerine).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

const _label = 'Bilgisayar Laboratuvarı-2';

final Finder _placeholder = find.byType(GuMapPlaceholder);
final Finder _paint = find.descendant(
  of: _placeholder,
  matching: find.byType(CustomPaint),
);

void main() {
  group('T-06 · GuMapPlaceholder', () {
    testWidgets('H-24 · 120 yükseklik, radius 12; brand.primaryContainer '
        'zemin + çizgi deseni + 1 px border.soft; pin dairesi ve mekân hapı '
        'açık + koyu; dekoratif', (tester) async {
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
            ..rrect(rrect: outer, color: colors.brandPrimaryContainer)
            ..line(
              color: colors.brandPrimary.withValues(
                alpha: GuOpacity.coverIcon,
              ),
              strokeWidth: GuSizes.mapPatternLine,
            )
            ..rrect(
              rrect: outer.deflate(GuSizes.mapPlaceholderBorder / 2),
              color: colors.borderSoft,
              strokeWidth: GuSizes.mapPlaceholderBorder,
              style: PaintingStyle.stroke,
            ),
          reason: '$mode',
        );

        final badge = find.ancestor(
          of: find.byType(GuIcon),
          matching: find.byType(DecoratedBox),
        );
        final decoration =
            tester.widget<DecoratedBox>(badge.first).decoration
                as BoxDecoration;
        expect(decoration.color, colors.brandPrimary);
        expect(decoration.shape, BoxShape.circle);
        expect(
          tester.getSize(badge.first),
          const Size.square(GuSizes.mapPinBadge),
        );
        final icon = tester.widget<GuIcon>(find.byType(GuIcon));
        expect(icon.icon, GuIcons.mapPin);
        expect(icon.color, colors.brandOnPrimary);

        final text = tester.widget<Text>(find.text(_label));
        expect(text.style, GuTypography.resolve(colors).labelM);
        expect(text.maxLines, 1);
        expect(text.overflow, TextOverflow.ellipsis);
        final pill =
            tester
                    .widget<DecoratedBox>(
                      find
                          .ancestor(
                            of: find.text(_label),
                            matching: find.byType(DecoratedBox),
                          )
                          .first,
                    )
                    .decoration
                as BoxDecoration;
        expect(pill.color, colors.bgSurface);
        expect(pill.borderRadius, GuRadius.borderFull);

        // Mekân adını üstteki satır okur; görsel ekran okuyucuya kapalı.
        expect(find.bySemanticsLabel(_label), findsNothing);
      }
      handle.dispose();
    });

    testWidgets('H-24 · 320 × 640, ölçek 1.6: uzun mekân adı taşmaz (tek '
        'satır, …), kutu 120 kalır', (tester) async {
      await tester.pumpApp(
        Padding(
          padding: GuInsets.all16,
          child: Align(
            alignment: Alignment.topCenter,
            child: GuMapPlaceholder(label: '$_label ' * 12),
          ),
        ),
        size: const Size(320, 640),
        textScale: 1.6,
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(_placeholder), const Size(288, 120));
      final row = tester.getRect(
        find.descendant(of: _placeholder, matching: find.byType(Row)),
      );
      expect(row.width, lessThanOrEqualTo(288 - 2 * GuSpacing.s16));
    });
  });
}
