// T-04 · GuProgress (widget-catalog #20; CD-105).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

Finder _fill(Finder progress) =>
    find.descendant(of: progress, matching: find.byType(DecoratedBox));

void main() {
  group('T-04 · GuProgress', () {
    testWidgets('T-04 · GuProgress · 6 / 4 px, radius 3, tür renkleri ve '
        'value / max oranı', (tester) async {
      const normal = ValueKey<String>('normal');
      const muted = ValueKey<String>('muted');
      const warning = ValueKey<String>('warning');
      const success = ValueKey<String>('success');
      const empty = ValueKey<String>('empty');
      const loose = ValueKey<String>('loose');
      await tester.pumpApp(
        const Center(
          child: SizedBox(
            width: 200,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GuProgress(key: normal, value: 48, max: 60, semanticLabel: 'a'),
                GuProgress(
                  key: muted,
                  value: 60,
                  max: 60,
                  kind: GuProgressKind.muted,
                  semanticLabel: 'b',
                ),
                GuProgress(
                  key: warning,
                  value: 90,
                  kind: GuProgressKind.warning,
                  thin: true,
                  semanticLabel: 'c',
                ),
                GuProgress(
                  key: success,
                  value: 10,
                  kind: GuProgressKind.success,
                  semanticLabel: 'd',
                ),
                GuProgress(key: empty, value: 5, max: 0, semanticLabel: 'e'),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GuProgress(key: loose, value: 150, semanticLabel: 'f'),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      const c = GuColors.light;

      // css:259 — 6 px, radius 3, iz bg.surfaceMuted, tüm genişlik.
      expect(tester.getSize(find.byKey(normal)), const Size(200, 6));
      final clip = tester.widget<ClipRRect>(
        find.descendant(
          of: find.byKey(normal),
          matching: find.byType(ClipRRect),
        ),
      );
      expect(clip.borderRadius, GuRadius.borderProgress);
      final track = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byKey(normal),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(track.color, c.bgSurfaceMuted);

      // Dolum: genişlik = oran, renk = tür (css:260–261).
      BoxDecoration fill(Key key) =>
          tester.widget<DecoratedBox>(_fill(find.byKey(key))).decoration
              as BoxDecoration;
      expect(tester.getSize(_fill(find.byKey(normal))), const Size(160, 6));
      expect(fill(normal).color, c.brandPrimary);
      expect(fill(normal).borderRadius, GuRadius.borderProgress);
      expect(tester.getSize(_fill(find.byKey(muted))).width, 200);
      expect(fill(muted).color, c.textMuted);
      expect(tester.getSize(find.byKey(warning)), const Size(200, 4));
      expect(tester.getSize(_fill(find.byKey(warning))), const Size(180, 4));
      expect(fill(warning).color, c.stateWarning);
      expect(tester.getSize(_fill(find.byKey(success))).width, 20);
      expect(fill(success).color, c.stateSuccess);
      // max 0 → dolum yok; sınırsız genişlik → min 40; değer > max → %100.
      expect(tester.getSize(_fill(find.byKey(empty))).width, 0);
      expect(tester.getSize(find.byKey(loose)), const Size(40, 6));
      expect(tester.getSize(_fill(find.byKey(loose))).width, 40);
      // Yüzde yuvarlanır (ui.js:92); geçersiz giriş 0.
      expect(
        const GuProgress(value: 1, max: 3, semanticLabel: 'g').fraction,
        0.33,
      );
      expect(
        const GuProgress(value: double.nan, semanticLabel: 'h').fraction,
        0,
      );
      expect(const GuProgress(value: -5, semanticLabel: 'i').fraction, 0);
    });

    testWidgets('T-04 · GuProgress · Semantics etiketi; dolum genişliği '
        'GuMotion.slow ile geçer', (tester) async {
      final handle = tester.ensureSemantics();
      final value = ValueNotifier<double>(0);
      addTearDown(value.dispose);
      await tester.pumpApp(
        Center(
          child: SizedBox(
            width: 200,
            child: ValueListenableBuilder<double>(
              valueListenable: value,
              builder: (context, current, _) =>
                  GuProgress(value: current, max: 2, semanticLabel: 'Kota 0/2'),
            ),
          ),
        ),
      );
      expect(find.bySemanticsLabel('Kota 0/2'), findsOneWidget);
      final fill = _fill(find.byType(GuProgress));
      expect(tester.getSize(fill).width, 0);

      value.value = 2;
      await tester.pump();
      await tester.pump(GuMotion.slow ~/ 2);
      expect(tester.getSize(fill).width, inExclusiveRange(0, 200));
      await tester.pump(GuMotion.slow);
      expect(tester.getSize(fill).width, 200);
      handle.dispose();
    });
  });
}
