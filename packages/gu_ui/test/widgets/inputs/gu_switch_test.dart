// T-05 · GuSwitch (widget-catalog #6; A.2 #6; K-03, K-19, K-43, CD-82,
// CD-111).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

const Key _off = ValueKey<String>('off');
const Key _on = ValueKey<String>('on');
const Key _disabled = ValueKey<String>('disabled');
const Key _static = ValueKey<String>('static');

AnimatedContainer _track(WidgetTester tester, Key key) =>
    tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(key),
        matching: find.byType(AnimatedContainer),
      ),
    );

Finder _thumb(Key key) => find.descendant(
  of: find.byKey(key),
  matching: find.byType(AnimatedPositioned),
);

Widget _set(List<String> log) => Center(
  child: Column(
    mainAxisSize: MainAxisSize.min,
    spacing: GuSpacing.s32,
    children: [
      GuSwitch(
        key: _off,
        value: false,
        semanticLabel: 'Yalnızca başvurusu açık',
        onChanged: (v) => log.add('off→$v'),
      ),
      GuSwitch(
        key: _on,
        value: true,
        semanticLabel: 'Anında katılım',
        onChanged: (v) => log.add('on→$v'),
      ),
      GuSwitch(
        key: _disabled,
        value: true,
        disabled: true,
        semanticLabel: 'Görsel limiti',
        onChanged: (v) => log.add('disabled→$v'),
        onDisabledPressed: () => log.add('disabledPressed'),
      ),
      const GuSwitch(
        key: _static,
        value: false,
        semanticLabel: 'Salt gösterge',
        onChanged: null,
      ),
    ],
  ),
);

void main() {
  group('T-05 · GuSwitch', () {
    testWidgets('T-05 · GuSwitch · kapalı / açık / disabled açık + koyu token '
        'değerleriyle; ray easeCss, topuz easeStandard', (tester) async {
      for (final (theme, c) in [
        (ThemeMode.light, GuColors.light),
        (ThemeMode.dark, GuColors.dark),
      ]) {
        await tester.pumpApp(_set([]), theme: theme);

        // Ray 44×26 radius 13 (css:231); kapalı border.default, açık
        // brand.primary (css:233; K-43 renk değişmez).
        expect(tester.getSize(find.byKey(_off)), const Size(44, 26));
        var track = _track(tester, _off);
        expect(
          track.decoration,
          BoxDecoration(
            color: c.borderDefault,
            borderRadius: GuRadius.borderSwitchTrack,
          ),
        );
        expect(track.duration, GuMotion.base);
        expect(track.curve, GuMotion.easeCss);
        track = _track(tester, _on);
        expect((track.decoration! as BoxDecoration).color, c.brandPrimary);

        // Topuz 20 px beyaz, 3 px içte; açıkken 18 px sağda (css:234–235).
        final offRect = tester.getRect(_thumb(_off));
        final onRect = tester.getRect(_thumb(_on));
        expect(offRect.size, const Size(20, 20));
        expect(
          offRect.topLeft - tester.getTopLeft(find.byKey(_off)),
          const Offset(3, 3),
        );
        expect(
          onRect.topLeft - tester.getTopLeft(find.byKey(_on)),
          const Offset(3 + 18, 3),
        );
        final thumb = tester.widget<AnimatedPositioned>(_thumb(_on));
        expect(thumb.duration, GuMotion.base);
        expect(thumb.curve, GuMotion.easeStandard);
        expect(
          tester
              .widget<DecoratedBox>(
                find.descendant(
                  of: _thumb(_on),
                  matching: find.byType(DecoratedBox),
                ),
              )
              .decoration,
          BoxDecoration(
            color: c.brandOnPrimary,
            shape: BoxShape.circle,
            boxShadow: GuShadows.light.switchThumb,
          ),
        );

        // disabled: opaklık .5 (css:236); diğerleri 1.
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

    testWidgets('T-05 · GuSwitch · dokunma → onChanged(!value); disabled → '
        'onDisabledPressed; Semantics(toggled); dokunma hedefi; klavye odağı', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final log = <String>[];
      await tester.pumpApp(_set(log));

      // 44×26 görsel, etkin alan 52×48 (css:232 `inset:-11px -4px`).
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await tester.tap(find.byKey(_off));
      await tester.tap(find.byKey(_on));
      // Görünmez dolgu: rayın 10 px üstü de etkin.
      await tester.tapAt(
        tester.getTopLeft(find.byKey(_on)) + const Offset(10, -10),
      );
      expect(log, ['off→true', 'on→false', 'on→false']);

      log.clear();
      await tester.tap(find.byKey(_disabled));
      expect(log, ['disabledPressed']);
      // Gösterge: dokunma yutulmaz, geri çağrı yok.
      await tester.tap(find.byKey(_static));
      expect(log, ['disabledPressed']);

      expect(
        tester.getSemantics(find.byKey(_on)),
        isSemantics(
          label: 'Anında katılım',
          hasToggledState: true,
          isToggled: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          isButton: false,
        ),
      );
      expect(
        tester.getSemantics(find.byKey(_off)),
        isSemantics(hasToggledState: true, isToggled: false),
      );
      expect(
        tester.getSemantics(find.byKey(_disabled)),
        isSemantics(
          label: 'Görsel limiti',
          isToggled: true,
          hasEnabledState: true,
          isEnabled: false,
          hasTapAction: false,
        ),
      );
      expect(
        tester.getSemantics(find.byKey(_static)),
        isSemantics(
          label: 'Salt gösterge',
          hasToggledState: true,
          isToggled: false,
          hasEnabledState: false,
          hasTapAction: false,
        ),
      );

      // Klavye odağı (K-19): 2 px focus.ring halkası 2 px dışarıda, ray
      // yarıçapını izler; Boşluk → onChanged.
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      log.clear();
      final ring = find.descendant(
        of: find.byKey(_off),
        matching: find.byType(IgnorePointer),
      );
      expect(ring, findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(tester.getSize(ring), const Size(44 + 8, 26 + 8));
      expect(
        tester
            .widget<DecoratedBox>(
              find.descendant(of: ring, matching: find.byType(DecoratedBox)),
            )
            .decoration,
        BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(13 + 4)),
          border: Border.all(color: GuColors.light.focusRing, width: 2),
        ),
      );
      // Halka yerleşimi etkilemez.
      expect(tester.getSize(find.byKey(_off)), const Size(44, 26));
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(log, ['off→true']);
      handle.dispose();
    });
  });
}
