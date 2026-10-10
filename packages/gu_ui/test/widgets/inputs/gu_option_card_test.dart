// T-05 · GuOptionCard (widget-catalog #9b; A.2 #9; G3, K-19, CD-82, CD-111).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

const Key _plain = ValueKey<String>('plain');
const Key _selected = ValueKey<String>('selected');

BoxDecoration _decoration(WidgetTester tester, Key key) =>
    tester
            .widget<DecoratedBox>(
              find
                  .descendant(
                    of: find.byKey(key),
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .decoration
        as BoxDecoration;

/// Kart içeriği: bodyS (13/18) — 22 px radyodan kısa, kart 52 px kalır.
class _Body extends StatelessWidget {
  const _Body(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: context.gu.text.bodyS);
}

Widget _set(List<String> log) => Padding(
  padding: GuInsets.all16,
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    spacing: GuSpacing.s8,
    children: [
      GuOptionCard(
        key: _plain,
        selected: false,
        onTap: () => log.add('plain'),
        leading: const ExcludeSemantics(
          child: GuRadio(
            selected: false,
            onSelected: null,
            semanticLabel: 'Yönetim Kurulu',
          ),
        ),
        child: const _Body('Yönetim Kurulu'),
      ),
      GuOptionCard(
        key: _selected,
        selected: true,
        semanticLabel: 'Açık tema',
        onTap: () => log.add('selected'),
        child: const _Body('Açık'),
      ),
    ],
  ),
);

void main() {
  group('T-05 · GuOptionCard', () {
    testWidgets('T-05 · GuOptionCard · varsayılan / seçili açık + koyu token '
        'değerleriyle; dolgu 14/16, aralık 12; basılı görünüm yok', (
      tester,
    ) async {
      for (final (theme, c) in [
        (ThemeMode.light, GuColors.light),
        (ThemeMode.dark, GuColors.dark),
      ]) {
        await tester.pumpApp(_set([]), theme: theme);
        final plain = find.byKey(_plain);

        // radius md, 1 px border.default, bg.surface (css:245).
        final idle = BoxDecoration(
          color: c.bgSurface,
          borderRadius: GuRadius.borderMd,
          border: Border.all(color: c.borderDefault),
        );
        expect(_decoration(tester, _plain), idle);
        // Seçili: brand.primary kenarlık + brand.primaryContainer (css:246).
        expect(
          _decoration(tester, _selected),
          BoxDecoration(
            color: c.brandPrimaryContainer,
            borderRadius: GuRadius.borderMd,
            border: Border.all(color: c.brandPrimary),
          ),
        );

        // Tam genişlik; kenarlık 1 + dolgu 14/16; leading üstten hizalı,
        // içerik 12 sonra.
        final origin = tester.getTopLeft(plain);
        expect(
          tester.getSize(plain),
          const Size(390 - 32, 1 + 14 + 22 + 14 + 1),
        );
        final radio = find.descendant(
          of: plain,
          matching: find.byType(GuRadio),
        );
        expect(tester.getTopLeft(radio) - origin, const Offset(17, 15));
        expect(
          tester.getTopLeft(find.text('Yönetim Kurulu')) - origin,
          const Offset(17 + 22 + 12, 15),
        );
        // leading yok → içerik dolgudan başlar.
        expect(
          tester.getTopLeft(find.text('Açık')) -
              tester.getTopLeft(find.byKey(_selected)),
          const Offset(17, 15),
        );

        // Basılı görünüm yok (CD-82).
        final gesture = await tester.startGesture(tester.getCenter(plain));
        await tester.pump();
        expect(_decoration(tester, _plain), idle);
        await gesture.up();
      }
    });

    testWidgets('T-05 · GuOptionCard · dokunma → onTap; Semantics(button, '
        'selected); dokunma hedefi; klavye odağı', (tester) async {
      final handle = tester.ensureSemantics();
      final log = <String>[];
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      await tester.pumpApp(_set(log));

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await tester.tap(find.byKey(_plain));
      await tester.tap(find.byKey(_selected));
      expect(log, ['plain', 'selected']);

      // Etiket verilmezse içerik metninden; verilirse onun yerine geçer.
      expect(
        tester.getSemantics(find.byKey(_plain)),
        isSemantics(
          label: 'Yönetim Kurulu',
          isButton: true,
          hasSelectedState: true,
          isSelected: false,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.byKey(_selected)),
        isSemantics(label: 'Açık tema', isButton: true, isSelected: true),
      );

      // Klavye odağı (K-19): `GuActionSurface` halkası; Enter → onTap.
      log.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        find.descendant(
          of: find.byKey(_plain),
          matching: find.byWidgetPredicate(
            (w) => w is CustomPaint && w.foregroundPainter != null,
          ),
        ),
        findsOneWidget,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(log, ['plain']);
      handle.dispose();
    });

    testWidgets('T-05 · GuOptionCard · 320 dp × 1.6 uzun metin taşmaz, sarar', (
      tester,
    ) async {
      await tester.pumpApp(
        Center(
          child: GuOptionCard(
            selected: true,
            onTap: () {},
            leading: const GuRadio(
              selected: true,
              onSelected: null,
              semanticLabel: 'Üye',
            ),
            child: _Body(
              'Gönderi ve etkinlik oluşturur, başvuruları onaylar. ' * 3,
            ),
          ),
        ),
        size: const Size(320, 640),
        textScale: 1.6,
      );
      expect(tester.takeException(), isNull);
      final size = tester.getSize(find.byType(GuOptionCard));
      expect(size.width, 320);
      expect(size.height, greaterThan(52));
      expect(tester.getSize(find.byType(GuRadio)), const Size(22, 22));
    });
  });
}
