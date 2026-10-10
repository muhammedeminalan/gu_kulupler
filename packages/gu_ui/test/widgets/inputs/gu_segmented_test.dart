// T-05 · GuSegmented (widget-catalog #11; A.2 #11; css:220–223; CD-82,
// CD-111, K-03).
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

const List<GuSegmentOption> _options = [
  GuSegmentOption(id: 'list', label: 'Liste', icon: GuIcons.list),
  GuSegmentOption(id: 'calendar', label: 'Takvim', icon: GuIcons.calendarDays),
];

Key _key(int index) => ValueKey<String>('segment.$index');

BoxDecoration _decoration(WidgetTester tester, Finder segment) =>
    tester
            .widget<AnimatedContainer>(
              find.descendant(
                of: segment,
                matching: find.byType(AnimatedContainer),
              ),
            )
            .decoration!
        as BoxDecoration;

Widget _host(Widget child) => Center(
  child: Padding(padding: GuInsets.h16, child: child),
);

void main() {
  group('T-05 · GuSegmented', () {
    testWidgets('T-05 · GuSegmented · kap + varsayılan / seçili açık + koyu '
        'token değerleriyle; ölçüler', (tester) async {
      for (final (mode, colors, shadows) in [
        (ThemeMode.light, GuColors.light, GuShadows.light),
        (ThemeMode.dark, GuColors.dark, GuShadows.dark),
      ]) {
        final text = GuTypography.resolve(colors);
        final dark = mode == ThemeMode.dark;
        await tester.pumpApp(
          _host(
            GuSegmented(
              options: _options,
              value: 'list',
              onChanged: (_) {},
              optionKeyBuilder: _key,
            ),
          ),
          theme: mode,
        );
        final bar = find.byType(GuSegmented);
        // Kap: dolgu 3 + öğe 40 + dolgu 3; zemin bg.surfaceMuted, radius 12.
        expect(tester.getSize(bar), const Size(358, 46));
        final box =
            tester
                    .widget<DecoratedBox>(
                      find
                          .descendant(
                            of: bar,
                            matching: find.byType(DecoratedBox),
                          )
                          .first,
                    )
                    .decoration
                as BoxDecoration;
        expect(box.color, colors.bgSurfaceMuted, reason: '$mode');
        expect(box.borderRadius, GuRadius.borderSm);

        // Eşit genişlik: (358 − 2×3 − 2) / 2; aralık 2.
        final selected = find.byKey(_key(0));
        final plain = find.byKey(_key(1));
        expect(tester.getSize(selected), const Size(175, 40));
        expect(tester.getSize(plain), const Size(175, 40));
        expect(
          tester.getTopLeft(selected) - tester.getTopLeft(bar),
          const Offset(3, 3),
        );
        expect(
          tester.getTopLeft(plain).dx - tester.getTopRight(selected).dx,
          2,
        );

        // Seçili: açık bg.surface + e1; koyu bg.surfaceRaised + kenarlık.
        final on = _decoration(tester, selected);
        expect(
          on.color,
          dark ? colors.bgSurfaceRaised : colors.bgSurface,
          reason: '$mode',
        );
        expect(on.borderRadius, GuRadius.borderChip);
        expect(on.boxShadow, shadows.e1);
        expect(
          on.border,
          dark ? Border.all(color: colors.borderDefault) : null,
        );
        final off = _decoration(tester, plain);
        expect(off.color, isNull);
        expect(off.border, isNull);
        expect(off.boxShadow, isNull);

        // Metin 600 13: seçili text.heading, diğeri text.secondary.
        expect(
          tester.widget<Text>(find.text('Liste')).style,
          text.segment.copyWith(color: colors.textHeading),
        );
        expect(tester.widget<Text>(find.text('Takvim')).style, text.segment);
        expect(text.segment.color, colors.textSecondary);

        // İkon 16, metinle aynı renk, aralık 6.
        final icon = find.descendant(
          of: selected,
          matching: find.byType(GuIcon),
        );
        expect(tester.widget<GuIcon>(icon).color, colors.textHeading);
        expect(tester.getSize(icon), const Size(16, 16));
        expect(
          tester.getTopLeft(find.text('Liste')).dx -
              tester.getTopRight(icon).dx,
          6,
        );
        expect(
          tester
              .widget<GuIcon>(
                find.descendant(of: plain, matching: find.byType(GuIcon)),
              )
              .color,
          colors.textSecondary,
        );
      }
    });

    testWidgets('T-05 · GuSegmented · dokunma / klavye → onChanged(id); seçim '
        'geçer; Semantics tabBar / tab + selected; dokunma hedefi', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      const colors = GuColors.light;
      final log = <String>[];
      var value = 'list';
      await tester.pumpApp(
        _host(
          StatefulBuilder(
            builder: (context, setState) => GuSegmented(
              options: _options,
              value: value,
              onChanged: (id) {
                log.add(id);
                setState(() => value = id);
              },
              optionKeyBuilder: _key,
            ),
          ),
        ),
      );
      final first = find.byKey(_key(0));
      final second = find.byKey(_key(1));
      // 40 px bölme: etkin alan 48 dp'ye tamamlanır (K-03).
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));

      final node = tester.getSemantics(first);
      expect(
        node,
        isSemantics(
          label: 'Liste',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      expect(node.getSemanticsData().role, SemanticsRole.tab);
      expect(node.parent!.getSemanticsData().role, SemanticsRole.tabBar);
      expect(
        tester.getSemantics(second),
        isSemantics(
          label: 'Takvim',
          hasSelectedState: true,
          isSelected: false,
          hasTapAction: true,
        ),
      );

      await tester.tap(second);
      await tester.pump();
      expect(log, ['calendar']);
      // Geçiş `GuMotion.fast`: bittiğinde seçili görünüm ikinci bölmede.
      await tester.pump(GuMotion.fast);
      expect(_decoration(tester, second).color, colors.bgSurface);
      expect(_decoration(tester, first).color, isNull);
      expect(
        tester.widget<Text>(find.text('Takvim')).style!.color,
        colors.textHeading,
      );
      expect(
        tester.widget<Text>(find.text('Liste')).style!.color,
        colors.textSecondary,
      );
      expect(tester.getSemantics(second), isSemantics(isSelected: true));

      // Seçili olana dokunma da bildirilir (ui.js:59).
      await tester.tap(second);
      expect(log, ['calendar', 'calendar']);

      // Klavye: Tab ile odak, Enter ile seçim.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(log, ['calendar', 'calendar', 'list']);
      handle.dispose();
    });

    testWidgets('T-05 · GuSegmented · 320 dp × 1.6, 4 uzun seçenek taşmaz '
        '(üç nokta)', (tester) async {
      await tester.pumpApp(
        _host(
          GuSegmented(
            options: [
              for (var index = 0; index < 4; index++)
                GuSegmentOption(
                  id: '$index',
                  label: 'Üye olmadıklarım ve bekleyenler $index',
                  icon: index.isEven ? GuIcons.list : null,
                ),
            ],
            value: '2',
            onChanged: (_) {},
            optionKeyBuilder: _key,
          ),
        ),
        size: const Size(320, 640),
        textScale: 1.6,
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(GuSegmented)).width, 288);
      for (var index = 0; index < 4; index++) {
        // (288 − 2×3 − 3×2) / 4.
        final size = tester.getSize(find.byKey(_key(index)));
        expect(size.width, 69);
        expect(size.height, greaterThanOrEqualTo(40));
      }
      final label = tester.renderObject<RenderParagraph>(
        find.text('Üye olmadıklarım ve bekleyenler 1'),
      );
      expect(label.didExceedMaxLines, isTrue);
    });
  });
}
