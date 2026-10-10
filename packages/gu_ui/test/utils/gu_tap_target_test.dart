// T-04 · GuTapTarget (widget-catalog ek-3; D-22, K-03, CD-97).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../helpers/pump_app.dart';

const _visual = SizedBox.square(dimension: 38);

RenderGuTapTarget _render(WidgetTester tester, Finder finder) =>
    tester.renderObject<RenderGuTapTarget>(
      find.descendant(
        of: finder,
        matching: find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_GuTapTargetBox',
        ),
      ),
    );

void main() {
  group('T-04 · GuTapTarget', () {
    testWidgets('T-04 · GuTapTarget · 38 px görsel, etkin alan 48 dp Android / '
        '44 pt iOS; Semantics düğme + etiket', (tester) async {
      final handle = tester.ensureSemantics();
      const key = ValueKey<String>('target');
      var taps = 0;
      Widget target() => Center(
        child: GuTapTarget(
          key: key,
          onTap: () => taps++,
          semanticLabel: 'Filtrele',
          child: _visual,
        ),
      );

      await tester.pumpApp(target());
      expect(GuTapTarget.minSizeFor(TargetPlatform.android), 48);
      expect(GuTapTarget.minSizeFor(TargetPlatform.iOS), 44);
      expect(GuTapTarget.minSizeFor(TargetPlatform.macOS), 44);
      // Görsel boyut ve yerleşim değişmez.
      expect(tester.getSize(find.byKey(key)), const Size.square(38));
      expect(
        _render(tester, find.byKey(key)).hitRect,
        const Rect.fromLTWH(-5, -5, 48, 48),
      );
      final center = tester.getCenter(find.byKey(key));
      await tester.tapAt(center);
      await tester.tapAt(center + const Offset(23, 0));
      await tester.tapAt(center + const Offset(0, -23));
      expect(taps, 3);
      await tester.tapAt(center + const Offset(25, 0));
      expect(taps, 3);

      final node = tester.getSemantics(find.byKey(key));
      expect(
        node,
        matchesSemantics(
          label: 'Filtrele',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      expect(node.rect.size, const Size.square(48));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      await tester.pumpApp(target(), platform: TargetPlatform.iOS);
      final iosCenter = tester.getCenter(find.byKey(key));
      await tester.tapAt(iosCenter + const Offset(21, 0));
      expect(taps, 4);
      await tester.tapAt(iosCenter + const Offset(23, 0));
      expect(taps, 4);
      expect(
        tester.getSemantics(find.byKey(key)).rect.size,
        const Size.square(44),
      );
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('T-04 · GuTapTarget · devre dışı çağrılmaz ve genişlemez; uzun '
        'basma, basılı durum, komşular çakışmaz', (tester) async {
      final handle = tester.ensureSemantics();
      final log = <String>[];
      final enabled = ValueNotifier<bool>(true);
      addTearDown(enabled.dispose);
      await tester.pumpApp(
        Center(
          child: ValueListenableBuilder<bool>(
            valueListenable: enabled,
            builder: (context, isEnabled, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GuTapTarget(
                  key: const ValueKey<String>('a'),
                  onTap: () => log.add('a'),
                  onLongPress: () => log.add('a.long'),
                  enabled: isEnabled,
                  minSize: isEnabled ? null : GuSizes.tapTargetIos,
                  inset: isEnabled ? null : GuInsets.all4,
                  child: _visual,
                ),
                GuGap.h8,
                GuTapTarget(
                  key: const ValueKey<String>('b'),
                  onTap: () => log.add('b'),
                  onPressedChanged: (pressed) => log.add('b.$pressed'),
                  child: _visual,
                ),
              ],
            ),
          ),
        ),
      );
      final a = find.byKey(const ValueKey<String>('a'));
      final b = find.byKey(const ValueKey<String>('b'));

      // Komşular: her biri kendi görsel kutusundan vurulur (boşluk 8, dolgu 5).
      await tester.tapAt(tester.getCenter(a) + const Offset(18, 0));
      await tester.tapAt(tester.getCenter(b) - const Offset(18, 0));
      expect(log, ['a', 'b.true', 'b.false', 'b']);
      log.clear();

      await tester.longPress(a);
      expect(log, ['a.long']);
      log.clear();

      final gesture = await tester.startGesture(tester.getCenter(b));
      await tester.pump();
      expect(log, ['b.true']);
      await gesture.cancel();
      expect(log, ['b.true', 'b.false']);
      log.clear();

      enabled.value = false;
      await tester.pump();
      expect(_render(tester, a).hitRect, const Rect.fromLTWH(0, 0, 38, 38));
      expect(_render(tester, a).minSize, GuSizes.tapTargetIos);
      expect(_render(tester, a).inset, GuInsets.all4);
      expect(_render(tester, a).enabled, isFalse);
      await tester.tapAt(tester.getCenter(a));
      await tester.longPressAt(tester.getCenter(a));
      await tester.tapAt(tester.getCenter(a) - const Offset(22, 0));
      expect(log, isEmpty);
      final node = tester.getSemantics(a);
      expect(
        node,
        matchesSemantics(isButton: true, hasEnabledState: true),
      );
      expect(node.rect.size, const Size.square(38));
      handle.dispose();
    });

    testWidgets('T-04 · GuTapTarget · yalnız genişletme: iç algılayıcı dolgudan '
        'vurulur; inset + minSize, excludeFromSemantics', (tester) async {
      final handle = tester.ensureSemantics();
      var inner = 0;
      var toggles = 0;
      await tester.pumpApp(
        Center(
          // Dolgu ataların kutusu içinde etkindir: sütun 44'ten geniş tutulur.
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 120),
              // CSS `.switch::after{inset:-11px -4px}` (css:232): 44×26 → 52×48.
              GuTapTarget(
                key: const ValueKey<String>('switch'),
                inset: GuInsets.sym(
                  h: GuSizes.switchHitInsetX,
                  v: GuSizes.switchHitInsetY,
                ),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => inner++,
                  child: const SizedBox(width: 44, height: 26),
                ),
              ),
              GuGap.v48,
              GuTapTarget(
                key: const ValueKey<String>('custom'),
                onTap: () => toggles++,
                excludeFromSemantics: true,
                child: Semantics(
                  label: 'Sessize al',
                  toggled: true,
                  onTap: () => toggles++,
                  child: _visual,
                ),
              ),
            ],
          ),
        ),
      );
      final target = find.byKey(const ValueKey<String>('switch'));
      expect(tester.getSize(target), const Size(44, 26));
      expect(
        _render(tester, target).hitRect,
        const Rect.fromLTWH(-4, -11, 52, 48),
      );
      final center = tester.getCenter(target);
      await tester.tapAt(center + const Offset(25, 0));
      await tester.tapAt(center + const Offset(0, 23));
      expect(inner, 2);
      await tester.tapAt(center + const Offset(27, 0));
      expect(inner, 2);

      // Çağıranın `container: false` semantiği genişletilmiş düğüme birleşir.
      final custom = find.byKey(const ValueKey<String>('custom'));
      final node = tester.getSemantics(custom);
      expect(
        node,
        matchesSemantics(
          label: 'Sessize al',
          hasToggledState: true,
          isToggled: true,
          hasTapAction: true,
        ),
      );
      expect(node.rect.size, const Size.square(48));
      await tester.tapAt(tester.getCenter(custom) + const Offset(22, 0));
      expect(toggles, 1);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });
  });
}
