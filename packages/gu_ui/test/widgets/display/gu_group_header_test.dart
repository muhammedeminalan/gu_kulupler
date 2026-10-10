// T-04 · GuGroupHeader (widget-catalog #65; CD-25; css:215).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

Widget _host(Widget child) =>
    Column(mainAxisSize: MainAxisSize.min, children: [child]);

void main() {
  group('T-04 · GuGroupHeader', () {
    testWidgets('T-04 · GuGroupHeader · bg.canvas, dolgu 12/16/6, overline + '
        'caption sayaç / özel trailing; başlık Semantics; 320 dp × 1.6 taşma '
        'yok', (tester) async {
      final handle = tester.ensureSemantics();
      for (final (mode, colors) in [
        (ThemeMode.light, GuColors.light),
        (ThemeMode.dark, GuColors.dark),
      ]) {
        final text = GuTypography.resolve(colors);
        await tester.pumpApp(
          _host(const GuGroupHeader(title: 'BU HAFTA', trailingText: '6')),
          theme: mode,
        );
        // 12 + caption satırı (16; overline 14 ortalanır) + 6.
        expect(tester.getSize(find.byType(GuGroupHeader)), const Size(390, 34));
        expect(tester.getTopLeft(find.text('BU HAFTA')).dy, 13);
        expect(
          tester
              .widget<ColoredBox>(
                find.descendant(
                  of: find.byType(GuGroupHeader),
                  matching: find.byType(ColoredBox),
                ),
              )
              .color,
          colors.bgCanvas,
          reason: '$mode',
        );
        expect(tester.getTopLeft(find.text('BU HAFTA')).dx, 16);
        expect(tester.widget<Text>(find.text('BU HAFTA')).style, text.overline);
        expect(
          tester.widget<Text>(find.text('6')).style,
          text.caption.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        );
        expect(tester.getTopRight(find.text('6')).dx, 390 - 16);
      }
      expect(
        tester.getSemantics(find.text('BU HAFTA')),
        matchesSemantics(label: 'BU HAFTA', isHeader: true),
      );

      // Özel trailing + sayaçsız (NTF-01) + dar ekran.
      await tester.pumpApp(
        _host(
          const GuGroupHeader(
            title: 'YÖNETİM KURULU ÜYELERİ VE DANIŞMAN ÖĞRETİM ELEMANLARI',
            trailing: GuIcon(GuIcons.users, size: GuSizes.icon16),
          ),
        ),
        size: const Size(320, 640),
        textScale: 1.6,
      );
      expect(tester.takeException(), isNull);
      expect(tester.getTopRight(find.byType(GuIcon)).dx, 320 - 16);

      await tester.pumpApp(_host(const GuGroupHeader(title: 'DÜN')));
      expect(find.byType(GuIcon), findsNothing);
      // Sayaçsız: 12 + overline satırı (14) + 6.
      expect(tester.getSize(find.byType(GuGroupHeader)), const Size(390, 32));
      handle.dispose();
    });

    testWidgets('T-04 · GuGroupHeader · sticky: sliver olarak üstte sabit '
        'kalır, grup bitince sonraki başlıkla itilir', (tester) async {
      Widget group(String title) => SliverMainAxisGroup(
        slivers: [
          GuGroupHeader(title: title, trailingText: '3', sticky: true),
          const SliverToBoxAdapter(child: SizedBox(height: 1200)),
        ],
      );
      await tester.pumpApp(
        CustomScrollView(slivers: [group('BUGÜN'), group('YARIN')]),
      );
      expect(tester.getTopLeft(find.text('BUGÜN')).dy, 13);
      // Grup içinde kaydır: başlık üstte kalır.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump();
      expect(tester.getTopLeft(find.text('BUGÜN')).dy, 13);
      // İkinci gruba geç: ilk başlık itilir, ikincisi sabitlenir.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
      await tester.pump();
      expect(tester.getTopLeft(find.text('YARIN')).dy, 13);
      expect(find.text('BUGÜN').hitTestable(), findsNothing);
    });
  });
}
