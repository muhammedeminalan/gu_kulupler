// T-04 · GuCard (widget-catalog #16; css:203–208, keyframes css:426).
import 'dart:ui' show SemanticsAction;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

const _content = SizedBox.square(dimension: 40);

BoxDecoration _box(WidgetTester tester) =>
    tester
            .widget<DecoratedBox>(
              find
                  .descendant(
                    of: find.byType(GuCard),
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .decoration
        as BoxDecoration;

double _scale(WidgetTester tester) => tester
    .widget<AnimatedScale>(
      find.descendant(
        of: find.byType(GuCard),
        matching: find.byType(AnimatedScale),
      ),
    )
    .scale;

void main() {
  group('T-04 · GuCard', () {
    testWidgets('T-04 · GuCard · default / muted / borderColor açık ve koyu '
        'temada token değerleriyle; gövde dolgusu ve iç köşe kırpması', (
      tester,
    ) async {
      for (final (mode, colors, shadows) in [
        (ThemeMode.light, GuColors.light, GuShadows.light),
        (ThemeMode.dark, GuColors.dark, GuShadows.dark),
      ]) {
        final dark = mode == ThemeMode.dark;
        await tester.pumpApp(
          const Center(
            child: GuCard(padding: GuCard.bodyPadding, child: _content),
          ),
          theme: mode,
        );
        var box = _box(tester);
        expect(box.color, colors.bgSurface, reason: '$mode');
        expect(box.borderRadius, GuRadius.borderLg);
        // css:204: koyu temada kenarlık border.default.
        expect(
          box.border,
          Border.all(color: dark ? colors.borderDefault : colors.borderSoft),
        );
        expect(box.boxShadow, shadows.e1);
        // 40 + 2 × 16 (card-body) + 2 × 1 (kenarlık).
        expect(tester.getSize(find.byType(GuCard)), const Size.square(74));
        expect(
          tester.widget<ClipRRect>(find.byType(ClipRRect)).borderRadius,
          BorderRadius.circular(GuRadius.lg - GuSizes.cardBorder),
        );

        await tester.pumpApp(
          const Center(child: GuCard(muted: true, child: _content)),
          theme: mode,
        );
        box = _box(tester);
        expect(box.color, colors.bgSurfaceMuted, reason: '$mode');
        expect(box.boxShadow, isEmpty);
        // css:205 saydam kenarlık; koyu temada css:204 özgüllüğü kazanır.
        expect(
          box.border,
          dark ? Border.all(color: colors.borderDefault) : isNull,
        );
        // Dolgu yok; saydam kenarlık yine 1 px yer kaplar.
        expect(tester.getSize(find.byType(GuCard)), const Size.square(42));

        await tester.pumpApp(
          Center(
            child: GuCard(borderColor: colors.stateWarning, child: _content),
          ),
          theme: mode,
        );
        expect(_box(tester).border, Border.all(color: colors.stateWarning));
      }
    });

    testWidgets('T-04 · GuCard · dokunma → callback, basılı ölçek .99, '
        'Semantics düğme + etiket, dokunma hedefi; statik kart etiketi', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final key = GuKey.action('CLB-01.card.c01');
      var taps = 0;
      await tester.pumpApp(
        Center(
          child: GuCard(
            key: key,
            onTap: () => taps++,
            semanticLabel: 'Doğa Sporları Kulübü',
            // 30 + 2 = 32 px yükseklik: dokunma alanı 48'e tamamlanır.
            child: const SizedBox(
              width: 200,
              height: 30,
              child: Text('içerik'),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byKey(key)), const Size(202, 32));
      expect(_scale(tester), 1);
      await tester.tap(find.byKey(key));
      expect(taps, 1);
      expect(
        tester.getSemantics(find.byKey(key)),
        matchesSemantics(
          label: 'Doğa Sporları Kulübü',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(key)),
      );
      await tester.pump(kPressTimeout);
      expect(_scale(tester), GuMotion.cardPressScale);
      await gesture.up();
      await tester.pump();
      expect(_scale(tester), 1);
      expect(taps, 2);
      await tester.pumpAndSettle();

      // Statik kart: düğme değil; etiket kap düğümünde.
      await tester.pumpApp(
        const Center(
          child: GuCard(semanticLabel: 'Özet', child: Text('içerik')),
        ),
      );
      expect(find.byType(AnimatedScale), findsNothing);
      final node = tester.getSemantics(find.bySemanticsLabel(RegExp('^Özet')));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      expect(node.getSemanticsData().flagsCollection.isButton, isFalse);
      handle.dispose();
    });

    testWidgets('T-04 · GuCard · highlight: 3 px brand.primary halkası 1,5 '
        "sn'de e1'e söner (ilk çizim ve false → true); hareket azaltılmışsa "
        'oynatılmaz', (tester) async {
      final ring = BoxShadow(
        color: GuColors.light.brandPrimary,
        spreadRadius: GuSizes.highlightRingWidth,
      );
      late StateSetter update;
      var highlight = false;
      await tester.pumpApp(
        Center(
          child: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return GuCard(highlight: highlight, child: _content);
            },
          ),
        ),
      );
      expect(_box(tester).boxShadow, GuShadows.light.e1);

      update(() => highlight = true);
      await tester.pump();
      expect(_box(tester).boxShadow!.first, ring);
      await tester.pump(GuMotion.highlight ~/ 2);
      final mid = _box(tester).boxShadow!.first.spreadRadius;
      expect(mid, inExclusiveRange(0, GuSizes.highlightRingWidth));
      await tester.pumpAndSettle();
      expect(_box(tester).boxShadow, GuShadows.light.e1);

      // İlk çizimde highlight.
      await tester.pumpApp(
        const Center(child: GuCard(highlight: true, child: _content)),
      );
      expect(_box(tester).boxShadow!.first, ring);
      await tester.pumpAndSettle();

      // Hareket azaltılmış: halka yok.
      await tester.pumpApp(
        Center(
          child: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: const GuCard(highlight: true, child: _content),
            ),
          ),
        ),
      );
      expect(_box(tester).boxShadow, GuShadows.light.e1);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
