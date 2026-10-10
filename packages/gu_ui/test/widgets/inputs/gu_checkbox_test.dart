// T-05 · GuCheckbox (widget-catalog #7; A.2 #7; K-03, K-19, K-24, CD-111).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

const Key _off = ValueKey<String>('off');
const Key _on = ValueKey<String>('on');
const Key _disabled = ValueKey<String>('disabled');
const Key _static = ValueKey<String>('static');

AnimatedContainer _box(WidgetTester tester, Key key) =>
    tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(key),
        matching: find.byType(AnimatedContainer),
      ),
    );

Finder _icon(Key key) =>
    find.descendant(of: find.byKey(key), matching: find.byType(GuIcon));

Widget _set(List<String> log) => Center(
  child: Column(
    mainAxisSize: MainAxisSize.min,
    spacing: GuSpacing.s32,
    children: [
      GuCheckbox(
        key: _off,
        value: false,
        semanticLabel: 'KVKK metnini okudum',
        onChanged: (v) => log.add('off→$v'),
      ),
      GuCheckbox(
        key: _on,
        value: true,
        semanticLabel: 'Bildirim gönder',
        onChanged: (v) => log.add('on→$v'),
      ),
      GuCheckbox(
        key: _disabled,
        value: true,
        disabled: true,
        semanticLabel: 'Kapalı',
        onChanged: (v) => log.add('disabled→$v'),
      ),
      const GuCheckbox(
        key: _static,
        value: true,
        semanticLabel: 'Salt gösterge',
        onChanged: null,
      ),
    ],
  ),
);

void main() {
  group('T-05 · GuCheckbox', () {
    testWidgets('T-05 · GuCheckbox · boş / işaretli / disabled açık + koyu '
        'token değerleriyle', (tester) async {
      for (final (theme, c) in [
        (ThemeMode.light, GuColors.light),
        (ThemeMode.dark, GuColors.dark),
      ]) {
        await tester.pumpApp(_set([]), theme: theme);

        // 22×22, radius 6, 2 px text.muted kenarlık (css:237–238).
        expect(tester.getSize(find.byKey(_off)), const Size(22, 22));
        var box = _box(tester, _off);
        expect(
          box.decoration,
          BoxDecoration(
            borderRadius: GuRadius.borderCheckbox,
            border: Border.all(color: c.textMuted, width: 2),
          ),
        );
        expect(box.duration, GuMotion.fast);
        expect(box.curve, GuMotion.easeCss);
        expect(_icon(_off), findsNothing);

        // İşaretli: zemin + kenarlık brand.primary, 16 px beyaz `check`
        // ortada (css:240; ui.js:46).
        box = _box(tester, _on);
        expect(
          box.decoration,
          BoxDecoration(
            color: c.brandPrimary,
            borderRadius: GuRadius.borderCheckbox,
            border: Border.all(color: c.brandPrimary, width: 2),
          ),
        );
        final icon = tester.widget<GuIcon>(_icon(_on));
        expect(
          (icon.icon, icon.size, icon.color),
          (GuIcons.check, 16, c.brandOnPrimary),
        );
        expect(
          tester.getCenter(_icon(_on)),
          tester.getCenter(find.byKey(_on)),
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

    testWidgets('T-05 · GuCheckbox · dokunma → onChanged(!value); disabled → '
        'çağrılmaz; Semantics(checked); dokunma hedefi; klavye odağı', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final log = <String>[];
      await tester.pumpApp(_set(log));

      // 22 px görsel, etkin alan 48×48 (css:239 `inset:-13px`).
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await tester.tap(find.byKey(_off));
      await tester.tap(find.byKey(_on));
      // Görünmez dolgu: kutunun 12 px üstü de etkin.
      await tester.tapAt(
        tester.getTopLeft(find.byKey(_on)) + const Offset(11, -12),
      );
      await tester.tap(find.byKey(_disabled));
      await tester.tap(find.byKey(_static));
      expect(log, ['off→true', 'on→false', 'on→false']);

      expect(
        tester.getSemantics(find.byKey(_on)),
        isSemantics(
          label: 'Bildirim gönder',
          hasCheckedState: true,
          isChecked: true,
          isInMutuallyExclusiveGroup: false,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          isButton: false,
        ),
      );
      expect(
        tester.getSemantics(find.byKey(_off)),
        isSemantics(hasCheckedState: true, isChecked: false),
      );
      expect(
        tester.getSemantics(find.byKey(_disabled)),
        isSemantics(
          label: 'Kapalı',
          isChecked: true,
          hasEnabledState: true,
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

      // Klavye odağı (K-19): halka 2 px dışarıda 2 px; Enter → onChanged.
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      log.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final ring = find.descendant(
        of: find.byKey(_off),
        matching: find.byType(IgnorePointer),
      );
      expect(tester.getSize(ring), const Size(22 + 8, 22 + 8));
      expect(
        tester
            .widget<DecoratedBox>(
              find.descendant(of: ring, matching: find.byType(DecoratedBox)),
            )
            .decoration,
        BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(6 + 4)),
          border: Border.all(color: GuColors.light.focusRing, width: 2),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(log, ['off→true']);
      handle.dispose();
    });
  });
}
