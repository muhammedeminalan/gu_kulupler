// T-04 · GuFab (widget-catalog #69; A.2 #69; K-34, CD-82).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

final Finder _box = find.byType(GuFab);

void main() {
  group('T-04 · GuFab', () {
    testWidgets('T-04 · GuFab · 56 px, token renk / gölge; sağ 16, alt güvenli '
        'alan + 16 (aboveNav + 56); dokunma, Semantics, dokunma hedefi', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      Widget host({required bool aboveNav}) => Stack(
        children: [
          GuFab(
            key: GuKey.action('ADM-02.create'),
            label: 'Kulüp oluştur',
            icon: GuIcons.plus,
            semanticLabel: 'Kulüp oluştur',
            aboveNav: aboveNav,
            onPressed: () => taps++,
          ),
        ],
      );
      const padding = EdgeInsets.only(bottom: 34);

      for (final theme in [ThemeMode.light, ThemeMode.dark]) {
        final dark = theme == ThemeMode.dark;
        final c = dark ? GuColors.dark : GuColors.light;
        await tester.pumpApp(
          host(aboveNav: false),
          theme: theme,
          viewPadding: padding,
        );
        final rect = tester.getRect(_box);
        final label = tester.getSize(find.text('Kulüp oluştur')).width;
        expect(rect.height, 56);
        expect(rect.width, closeTo(16 + 22 + 8 + label + 20, .01));
        expect(390 - rect.right, 16);
        expect(844 - rect.bottom, 34 + 16);
        final decoration =
            tester
                    .widget<Container>(
                      find.descendant(
                        of: _box,
                        matching: find.byType(Container),
                      ),
                    )
                    .decoration!
                as BoxDecoration;
        expect(decoration.color, c.brandPrimary);
        expect(decoration.borderRadius, GuRadius.borderMd);
        expect(
          decoration.boxShadow,
          dark ? GuShadows.dark.fab : GuShadows.light.e2,
        );
        final icon = tester.widget<GuIcon>(find.byType(GuIcon));
        expect((icon.size, icon.color), (22, c.brandOnPrimary));
        expect(
          tester.widget<Text>(find.text('Kulüp oluştur')).style,
          GuTypography.resolve(c).button.copyWith(color: c.brandOnPrimary),
        );
      }

      // Sekme kökü (ADM-02): alt sekme çubuğu yüksekliği eklenir (K-34).
      await tester.pumpApp(host(aboveNav: true), viewPadding: padding);
      expect(844 - tester.getRect(_box).bottom, 56 + 34 + 16);

      await tester.tap(find.byKey(GuKey.action('ADM-02.create')));
      expect(taps, 1);
      expect(
        tester.getSemantics(find.text('Kulüp oluştur')),
        isSemantics(
          label: 'Kulüp oluştur',
          isButton: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('T-04 · GuFab · 320 dp × 1.6 uzun etiket taşmaz, sol kenardan '
        '16 boşluk kalır', (tester) async {
      await tester.pumpApp(
        Stack(
          children: [
            GuFab(
              label: 'Yeni etkinlik oluştur ' * 6,
              icon: GuIcons.plus,
              semanticLabel: 'Etkinlik oluştur',
              onPressed: () {},
            ),
          ],
        ),
        size: const Size(320, 640),
        textScale: 1.6,
      );
      expect(tester.takeException(), isNull);
      final rect = tester.getRect(_box);
      expect((rect.left, rect.right, rect.height), (16, 304, 56));
      expect(640 - rect.bottom, 16);
    });
  });
}
