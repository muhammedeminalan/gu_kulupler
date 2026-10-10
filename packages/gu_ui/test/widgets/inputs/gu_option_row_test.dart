// T-05 · GuOptionRow (widget-catalog #9a; A.2 #9; G1, K-03, K-19, K-53,
// CD-111).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

const Key _plain = ValueKey<String>('plain');
const Key _selected = ValueKey<String>('selected');
const Key _check = ValueKey<String>('check');
const Key _disabled = ValueKey<String>('disabled');
const Key _static = ValueKey<String>('static');

Color? _background(WidgetTester tester, Key key) =>
    (tester
                .widget<DecoratedBox>(
                  find
                      .descendant(
                        of: find.byKey(key),
                        matching: find.byType(DecoratedBox),
                      )
                      .first,
                )
                .decoration
            as BoxDecoration)
        .color;

Widget _set(List<String> log) => Column(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    GuOptionRow(
      key: _plain,
      label: 'Yeni eklenen',
      selected: false,
      onTap: () => log.add('plain'),
    ),
    GuOptionRow(
      key: _selected,
      label: 'Türkçe',
      sub: 'TR',
      selected: true,
      leading: const GuIcon(GuIcons.mapPin, size: GuSizes.icon18),
      trailing: const Text('1'),
      onTap: () => log.add('selected'),
    ),
    GuOptionRow(
      key: _check,
      label: 'Teknoloji',
      selected: true,
      control: GuOptionControl.checkbox,
      onTap: () => log.add('check'),
    ),
    GuOptionRow(
      key: _disabled,
      label: 'Kapalı',
      selected: false,
      disabled: true,
      onTap: () => log.add('disabled'),
    ),
    const GuOptionRow(
      key: _static,
      label: 'Statik',
      selected: true,
      onTap: null,
    ),
  ],
);

void main() {
  group('T-05 · GuOptionRow', () {
    testWidgets('T-05 · GuOptionRow · varsayılan / seçili / onay kutulu / '
        'disabled / basılı açık + koyu token değerleriyle', (tester) async {
      for (final (theme, c) in [
        (ThemeMode.light, GuColors.light),
        (ThemeMode.dark, GuColors.dark),
      ]) {
        await tester.pumpApp(_set([]), theme: theme);
        final text = GuTypography.resolve(c);
        final plain = find.byKey(_plain);
        final selected = find.byKey(_selected);

        // Tam genişlik, en az 52, dolgu 6/16, aralık 12 (css:243).
        expect(tester.getSize(plain), const Size(390, 52));
        expect(
          tester.getTopLeft(find.text('Yeni eklenen')).dx,
          GuSizes.optionRowPaddingX,
        );
        final radio = find.descendant(
          of: plain,
          matching: find.byType(GuRadio),
        );
        expect(tester.getSize(radio), const Size(22, 22));
        expect(tester.getTopRight(radio).dx, 390 - 16);
        expect(tester.getCenter(radio).dy, tester.getCenter(plain).dy);
        expect(tester.widget<GuRadio>(radio).selected, isFalse);
        expect(tester.widget<GuRadio>(radio).onSelected, isNull);
        expect(
          tester.widget<Text>(find.text('Yeni eklenen')).style,
          text.bodyM.copyWith(color: c.textHeading),
        );
        expect(_background(tester, _plain), isNull);

        // Seçili + sub + leading + trailing: leading 16'da, metin 12 sonra;
        // trailing göstergeden 12 önce.
        expect(
          tester.widget<Text>(find.text('TR')).style,
          text.bodyS.copyWith(color: c.textMuted),
        );
        final leading = find.descendant(
          of: selected,
          matching: find.byType(GuIcon),
        );
        expect(tester.getTopLeft(leading).dx, 16);
        expect(tester.getTopLeft(find.text('Türkçe')).dx, 16 + 18 + 12);
        expect(
          tester.getTopLeft(find.text('TR')).dy,
          tester.getBottomLeft(find.text('Türkçe')).dy,
        );
        final selectedRadio = find.descendant(
          of: selected,
          matching: find.byType(GuRadio),
        );
        expect(tester.widget<GuRadio>(selectedRadio).selected, isTrue);
        expect(
          tester.getTopRight(find.text('1')).dx,
          tester.getTopLeft(selectedRadio).dx - 12,
        );

        // checkbox göstergesi (ui.js:51).
        final checkbox = tester.widget<GuCheckbox>(
          find.descendant(
            of: find.byKey(_check),
            matching: find.byType(GuCheckbox),
          ),
        );
        expect((checkbox.value, checkbox.onChanged), (true, null));
        expect(
          find.descendant(
            of: find.byKey(_check),
            matching: find.byType(GuRadio),
          ),
          findsNothing,
        );

        // disabled: opaklık .5 (ui.js:49).
        expect(
          tester
              .widget<Opacity>(
                find
                    .descendant(
                      of: find.byKey(_disabled),
                      matching: find.byType(Opacity),
                    )
                    .first,
              )
              .opacity,
          GuOpacity.disabled,
        );

        // Basılı: bg.surfaceMuted (css:244, K-53); disabled satırda yok.
        var gesture = await tester.startGesture(tester.getCenter(plain));
        await tester.pump();
        expect(_background(tester, _plain), c.bgSurfaceMuted);
        await gesture.up();
        await tester.pump();
        expect(_background(tester, _plain), isNull);
        gesture = await tester.startGesture(
          tester.getCenter(find.byKey(_disabled)),
        );
        await tester.pump();
        expect(_background(tester, _disabled), isNull);
        await gesture.up();
      }
    });

    testWidgets('T-05 · GuOptionRow · dokunma → onTap; disabled → çağrılmaz; '
        'Semantics(radio / checkbox); dokunma hedefi; klavye odağı', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final log = <String>[];
      await tester.pumpApp(_set(log));

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await tester.tap(find.byKey(_plain));
      // Satırın tamamı etkin: sondaki gösterge de satırı tetikler.
      await tester.tap(
        find.descendant(
          of: find.byKey(_selected),
          matching: find.byType(GuRadio),
        ),
      );
      await tester.tap(find.byKey(_check));
      await tester.tap(find.byKey(_disabled));
      await tester.tap(find.byKey(_static));
      expect(log, ['plain', 'selected', 'check']);

      // Etiket satır metinlerinden; iç gösterge semantikten gizli.
      expect(
        tester.getSemantics(find.byKey(_selected)),
        isSemantics(
          label: 'Türkçe\nTR\n1',
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
        tester.getSemantics(find.byKey(_plain)),
        isSemantics(label: 'Yeni eklenen', isChecked: false),
      );
      expect(
        tester.getSemantics(find.byKey(_check)),
        isSemantics(
          label: 'Teknoloji',
          hasCheckedState: true,
          isChecked: true,
          isInMutuallyExclusiveGroup: false,
        ),
      );
      expect(
        tester.getSemantics(find.byKey(_disabled)),
        isSemantics(label: 'Kapalı', isEnabled: false, hasTapAction: false),
      );
      expect(
        tester.getSemantics(find.byKey(_static)),
        isSemantics(
          label: 'Statik',
          isChecked: true,
          hasEnabledState: false,
          hasTapAction: false,
        ),
      );

      // Klavye odağı (K-19): halka satırın 2 px dışında; Enter → onTap.
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
        of: find.byKey(_plain),
        matching: find.byType(IgnorePointer),
      );
      expect(tester.getSize(ring), const Size(390 + 8, 52 + 8));
      expect(
        (tester
                    .widget<DecoratedBox>(
                      find.descendant(
                        of: ring,
                        matching: find.byType(DecoratedBox),
                      ),
                    )
                    .decoration
                as BoxDecoration)
            .border,
        Border.all(color: GuColors.light.focusRing, width: 2),
      );
      expect(tester.getSize(find.byKey(_plain)), const Size(390, 52));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(log, ['plain']);
      handle.dispose();
    });

    testWidgets('T-05 · GuOptionRow · 320 dp × 1.6 uzun metin taşmaz, sarar', (
      tester,
    ) async {
      await tester.pumpApp(
        Center(
          child: GuOptionRow(
            label: 'Mühendislik ve Doğa Bilimleri Fakültesi ' * 3,
            sub: 'Yazılım Mühendisliği Bölümü ' * 3,
            selected: true,
            leading: const GuIcon(GuIcons.mapPin, size: GuSizes.icon18),
            onTap: () {},
          ),
        ),
        size: const Size(320, 640),
        textScale: 1.6,
      );
      expect(tester.takeException(), isNull);
      final size = tester.getSize(find.byType(GuOptionRow));
      expect(size.width, 320);
      expect(size.height, greaterThan(52));
      // Gösterge ölçeklenmez ve sağ dolguda kalır.
      final radio = find.byType(GuRadio);
      expect(tester.getSize(radio), const Size(22, 22));
      expect(tester.getTopRight(radio).dx, 320 - 16);
    });
  });
}
