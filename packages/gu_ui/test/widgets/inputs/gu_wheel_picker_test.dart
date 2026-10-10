// T-05 · GuWheelPicker (widget-catalog #63; A.2 #63; css:321–322;
// sheets.js:137–138; CD-25, CD-111, K-08).
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

final List<String> _hours = [
  for (var hour = 0; hour < 24; hour++) hour.toString().padLeft(2, '0'),
];

Key _key(int index) => ValueKey<String>('wheel.$index');

final Finder _wheel = find.byType(GuWheelPicker);

Widget _host(Widget child) => Center(child: SizedBox(width: 120, child: child));

/// Öğe merkezinin tekerlek merkezine dikey uzaklığı.
double _offsetFromCenter(WidgetTester tester, int index) =>
    tester.getCenter(find.byKey(_key(index))).dy - tester.getCenter(_wheel).dy;

void main() {
  group('T-05 · GuWheelPicker', () {
    testWidgets('T-05 · GuWheelPicker · 160 / 40 ölçüler, seçili öğe ortada, '
        'seçili text.heading / diğerleri text.muted açık + koyu, maske; '
        'Semantics etiket + değer + artır / azalt', (tester) async {
      final handle = tester.ensureSemantics();
      for (final (mode, colors) in [
        (ThemeMode.light, GuColors.light),
        (ThemeMode.dark, GuColors.dark),
      ]) {
        final text = GuTypography.resolve(colors);
        await tester.pumpApp(
          _host(
            GuWheelPicker(
              values: _hours,
              value: '18',
              onChanged: (_) {},
              semanticLabel: 'Saat',
              itemKeyBuilder: _key,
            ),
          ),
          theme: mode,
        );
        expect(tester.getSize(_wheel), const Size(120, 160));
        // Öğe 40 px; seçili ortada, komşular ±40 (düz liste).
        expect(tester.getSize(find.byKey(_key(18))), const Size(120, 40));
        expect(_offsetFromCenter(tester, 18), closeTo(0, 0.01));
        expect(_offsetFromCenter(tester, 17), closeTo(-40, 0.1));
        expect(_offsetFromCenter(tester, 19), closeTo(40, 0.1));

        // Montserrat 600 18: seçili text.heading, diğerleri text.muted.
        expect(
          tester.widget<Text>(find.text('18')).style,
          text.wheel.copyWith(color: colors.textHeading),
          reason: '$mode',
        );
        expect(tester.widget<Text>(find.text('17')).style, text.wheel);
        expect(text.wheel.color, colors.textMuted);

        // css:321 maske: üst / alt %30 saydamlaşır.
        final mask = tester.widget<ShaderMask>(
          find.descendant(of: _wheel, matching: find.byType(ShaderMask)),
        );
        expect(mask.blendMode, BlendMode.dstIn);
        expect(GuSizes.wheelMaskStart, 0.3);
        expect(GuSizes.wheelMaskEnd, 0.7);

        expect(
          tester.getSemantics(_wheel),
          isSemantics(
            label: 'Saat',
            value: '18',
            increasedValue: '19',
            decreasedValue: '17',
            hasIncreaseAction: true,
            hasDecreaseAction: true,
          ),
        );
      }
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));

      // İlk öğe: azalt yok; son öğe: artır yok.
      await tester.pumpApp(
        _host(
          GuWheelPicker(
            values: _hours,
            value: '00',
            onChanged: (_) {},
            semanticLabel: 'Saat',
          ),
        ),
      );
      expect(
        tester.getSemantics(_wheel),
        isSemantics(
          value: '00',
          increasedValue: '01',
          hasIncreaseAction: true,
          hasDecreaseAction: false,
        ),
      );
      await tester.pumpApp(
        _host(
          GuWheelPicker(
            values: _hours,
            value: '23',
            onChanged: (_) {},
            semanticLabel: 'Saat',
          ),
        ),
      );
      expect(
        tester.getSemantics(_wheel),
        isSemantics(
          value: '23',
          decreasedValue: '22',
          hasIncreaseAction: false,
          hasDecreaseAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('T-05 · GuWheelPicker · kaydırma ortadaki öğeyi seçer; öğeye '
        'dokunma seçer + ortalar; artır / azalt eylemi; dış değişimde atlar; '
        'hareket azaltmada animasyonsuz', (tester) async {
      final handle = tester.ensureSemantics();
      final log = <String>[];
      var value = '18';
      var reduceMotion = false;
      late StateSetter update;
      await tester.pumpApp(
        _host(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(disableAnimations: reduceMotion),
                child: GuWheelPicker(
                  values: _hours,
                  value: value,
                  onChanged: (next) {
                    log.add(next);
                    setState(() => value = next);
                  },
                  semanticLabel: 'Saat',
                  itemKeyBuilder: _key,
                ),
              );
            },
          ),
        ),
      );

      // Kaydırma: bir öğe yukarı → 19 (sheets.js:137 `round(scrollTop/40)`).
      await tester.drag(_wheel, const Offset(0, -40));
      await tester.pumpAndSettle();
      expect(log, ['19']);
      // Yapışma toleransı 1 / dpr (testte dpr 1 → 1 px).
      expect(_offsetFromCenter(tester, 19), closeTo(0, 1));
      expect(
        tester.widget<Text>(find.text('19')).style!.color,
        GuColors.light.textHeading,
      );
      expect(
        tester.widget<Text>(find.text('18')).style!.color,
        GuColors.light.textMuted,
      );

      // Dokunma: hemen bildirir, sonra yumuşak kaydırır (sheets.js:138).
      await tester.tap(find.byKey(_key(20)));
      expect(log, ['19', '20']);
      await tester.pump();
      await tester.pump(GuMotion.base ~/ 2);
      expect(_offsetFromCenter(tester, 20), inExclusiveRange(0, 40));
      await tester.pumpAndSettle();
      expect(_offsetFromCenter(tester, 20), closeTo(0, 0.01));
      expect(log, ['19', '20']);

      // Erişilebilirlik eylemleri.
      void perform(SemanticsAction action) {
        final node = tester.getSemantics(_wheel);
        node.owner!.performAction(node.id, action);
      }

      perform(SemanticsAction.increase);
      await tester.pumpAndSettle();
      expect(log.last, '21');
      expect(_offsetFromCenter(tester, 21), closeTo(0, 0.01));
      perform(SemanticsAction.decrease);
      await tester.pumpAndSettle();
      expect(log, ['19', '20', '21', '20']);

      // Dış değişim: tekerlek yeni değere atlar, onChanged çağrılmaz.
      update(() => value = '05');
      await tester.pumpAndSettle();
      expect(_offsetFromCenter(tester, 5), closeTo(0, 0.01));
      expect(log, hasLength(4));
      update(() => value = '00');
      await tester.pumpAndSettle();
      expect(_offsetFromCenter(tester, 0), closeTo(0, 0.01));
      // Listede olmayan değer ilk öğeye karşılık gelir: konum aynı, atlama
      // ve bildirim yok.
      update(() => value = 'yok');
      await tester.pumpAndSettle();
      expect(_offsetFromCenter(tester, 0), closeTo(0, 0.01));
      expect(log, hasLength(4));

      // Hareket azaltma: dokunma animasyonsuz ortalar.
      update(() => reduceMotion = true);
      await tester.pump();
      await tester.tap(find.byKey(_key(1)));
      await tester.pump();
      expect(log, ['19', '20', '21', '20', '01']);
      expect(_offsetFromCenter(tester, 1), closeTo(0, 0.01));
      handle.dispose();
    });

    testWidgets('T-05 · GuWheelPicker · 320 dp × 1.6 uzun değer taşmaz; öğe ve '
        'yükseklik yazı ölçeğiyle büyür; listede olmayan değer', (
      tester,
    ) async {
      await tester.pumpApp(
        Center(
          child: Row(
            children: [
              for (final label in ['Saat', 'Dakika'])
                Expanded(
                  child: GuWheelPicker(
                    values: [
                      for (var index = 0; index < 6; index++)
                        'Çok uzun bir tekerlek değeri $index',
                    ],
                    value: 'yok',
                    onChanged: (_) {},
                    semanticLabel: label,
                    itemKeyBuilder: label == 'Saat' ? _key : null,
                  ),
                ),
            ],
          ),
        ),
        size: const Size(320, 640),
        textScale: 1.6,
      );
      expect(tester.takeException(), isNull);
      // 160 × 1.6 ve 40 × 1.6 (K-08).
      expect(tester.getSize(_wheel.first), const Size(160, 256));
      expect(tester.getSize(find.byKey(_key(0))), const Size(160, 64));
      // Listede olmayan değer: ilk öğe ortada, hiçbiri seçili çizilmez.
      expect(
        tester.getCenter(find.byKey(_key(0))).dy,
        closeTo(tester.getCenter(_wheel.first).dy, 0.01),
      );
      final text = GuTypography.resolve(GuColors.light);
      for (final label in tester.widgetList<Text>(
        find.descendant(of: _wheel.first, matching: find.byType(Text)),
      )) {
        expect(label.style, text.wheel);
      }
    });
  });
}
