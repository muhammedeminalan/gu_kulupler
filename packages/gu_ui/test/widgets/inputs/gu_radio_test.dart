// T-05 · GuRadio (widget-catalog #8; A.2 #8; K-03, K-19, CD-111, CD-118).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

const Key _off = ValueKey<String>('off');
const Key _on = ValueKey<String>('on');
const Key _disabled = ValueKey<String>('disabled');
const Key _static = ValueKey<String>('static');

AnimatedContainer _ring(WidgetTester tester, Key key) =>
    tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(key),
        matching: find.byType(AnimatedContainer),
      ),
    );

Finder _dot(Key key) => find.descendant(
  of: find.byKey(key),
  matching: find.byWidgetPredicate(
    (w) => w is SizedBox && w.width == GuSizes.radioDot,
  ),
);

Widget _set(List<String> log) => Center(
  child: Column(
    mainAxisSize: MainAxisSize.min,
    spacing: GuSpacing.s32,
    children: [
      GuRadio(
        key: _off,
        selected: false,
        semanticLabel: 'Yeni eklenen',
        onSelected: () => log.add('off'),
      ),
      GuRadio(
        key: _on,
        selected: true,
        semanticLabel: 'Popüler',
        onSelected: () => log.add('on'),
      ),
      GuRadio(
        key: _disabled,
        selected: false,
        disabled: true,
        semanticLabel: 'Kapalı',
        onSelected: () => log.add('disabled'),
      ),
      const GuRadio(
        key: _static,
        selected: true,
        semanticLabel: 'Salt gösterge',
        onSelected: null,
      ),
    ],
  ),
);

void main() {
  group('T-05 · GuRadio', () {
    testWidgets('T-05 · GuRadio · seçisiz / seçili / disabled açık + koyu '
        'token değerleriyle', (tester) async {
      for (final (theme, c) in [
        (ThemeMode.light, GuColors.light),
        (ThemeMode.dark, GuColors.dark),
      ]) {
        await tester.pumpApp(_set([]), theme: theme);

        // 22×22 daire, 2 px text.muted kenarlık (css:237–238).
        expect(tester.getSize(find.byKey(_off)), const Size(22, 22));
        var ring = _ring(tester, _off);
        expect(
          ring.decoration,
          BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: c.textMuted, width: 2),
          ),
        );
        expect(ring.duration, GuMotion.fast);
        expect(ring.curve, GuMotion.easeCss);
        expect(_dot(_off), findsNothing);

        // Seçili: kenarlık + 12 px nokta brand.primary, ortada (css:241).
        ring = _ring(tester, _on);
        expect(
          (ring.decoration! as BoxDecoration).border,
          Border.all(color: c.brandPrimary, width: 2),
        );
        expect(tester.getSize(_dot(_on)), const Size(12, 12));
        expect(tester.getCenter(_dot(_on)), tester.getCenter(find.byKey(_on)));
        expect(
          tester
              .widget<DecoratedBox>(
                find.descendant(
                  of: _dot(_on),
                  matching: find.byType(DecoratedBox),
                ),
              )
              .decoration,
          BoxDecoration(color: c.brandPrimary, shape: BoxShape.circle),
        );

        // disabled: opaklık .5 (css:242).
        double opacity(Key key) => tester
            .widget<Opacity>(
              find.descendant(
                of: find.byKey(key),
                matching: find.byType(Opacity),
              ),
            )
            .opacity;
        expect(opacity(_disabled), GuOpacity.disabled);
        expect(opacity(_on), 1);
      }
    });

    testWidgets('T-05 · GuRadio · dokunma → onSelected; disabled → çağrılmaz; '
        'Semantics(checked, grup); dokunma hedefi; klavye odağı', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final log = <String>[];
      await tester.pumpApp(_set(log));

      // 22 px görsel, etkin alan 48×48 (css:239 `inset:-13px`).
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await tester.tap(find.byKey(_off));
      // Seçiliyken de çağrılır (ui.js:47); görünmez dolgu etkin.
      await tester.tapAt(
        tester.getTopLeft(find.byKey(_on)) + const Offset(11, -12),
      );
      await tester.tap(find.byKey(_disabled));
      await tester.tap(find.byKey(_static));
      expect(log, ['off', 'on']);

      expect(
        tester.getSemantics(find.byKey(_on)),
        isSemantics(
          label: 'Popüler',
          hasCheckedState: true,
          isChecked: true,
          isInMutuallyExclusiveGroup: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          isButton: false,
        ),
      );
      expect(
        tester.getSemantics(find.byKey(_disabled)),
        isSemantics(
          label: 'Kapalı',
          hasCheckedState: true,
          isChecked: false,
          isInMutuallyExclusiveGroup: true,
          isEnabled: false,
          hasTapAction: false,
        ),
      );
      expect(
        tester.getSemantics(find.byKey(_static)),
        isSemantics(
          label: 'Salt gösterge',
          isChecked: true,
          hasEnabledState: false,
          hasTapAction: false,
        ),
      );

      // Klavye odağı (K-19): halka daireyi izler; Boşluk → onSelected.
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      log.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final focus = find.descendant(
        of: find.byKey(_off),
        matching: find.byType(IgnorePointer),
      );
      expect(tester.getSize(focus), const Size(22 + 8, 22 + 8));
      expect(
        tester
            .widget<DecoratedBox>(
              find.descendant(of: focus, matching: find.byType(DecoratedBox)),
            )
            .decoration,
        BoxDecoration(
          borderRadius: const BorderRadius.all(
            Radius.circular(GuRadius.full + 4),
          ),
          border: Border.all(color: GuColors.light.focusRing, width: 2),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(log, ['off']);
      handle.dispose();
    });
  });
}
