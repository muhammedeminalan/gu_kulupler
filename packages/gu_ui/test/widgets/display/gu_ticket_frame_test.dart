// T-04 · GuTicketFrame (widget-catalog #77; CD-25).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

final Finder _cut = find.descendant(
  of: find.byType(GuTicketFrame),
  matching: find.byType(CustomPaint),
);

Widget _frame(double width) => Center(
  child: SizedBox(
    width: width,
    child: const GuTicketFrame(
      header: SizedBox(key: ValueKey<String>('header'), height: 40),
      body: SizedBox(key: ValueKey<String>('body'), height: 100),
    ),
  ),
);

void main() {
  group('T-04 · GuTicketFrame', () {
    testWidgets('T-04 · GuTicketFrame · surface + radius lg + 1 px kenarlık; '
        'gövde dolgusu 16; 2 px kesik çizgi ve 24 px çentikler', (
      tester,
    ) async {
      await tester.pumpApp(_frame(358));
      const c = GuColors.light;
      final frame = find.byType(GuTicketFrame);
      final origin = tester.getTopLeft(frame);
      // 1 + (16 + 40 + 16) + 2 + (16 + 100 + 16) + 1.
      expect(tester.getSize(frame), const Size(358, 208));
      final container = tester.widget<Container>(
        find.descendant(of: frame, matching: find.byType(Container)),
      );
      expect(container.clipBehavior, Clip.antiAlias);
      expect(
        container.decoration,
        BoxDecoration(color: c.bgSurface, borderRadius: GuRadius.borderLg),
      );
      expect(
        container.foregroundDecoration,
        BoxDecoration(
          borderRadius: GuRadius.borderLg,
          border: Border.all(color: c.borderSoft),
        ),
      );
      expect(
        tester.getRect(find.byKey(const ValueKey<String>('header'))),
        Rect.fromLTWH(origin.dx + 17, origin.dy + 17, 324, 40),
      );
      expect(
        tester.getRect(find.byKey(const ValueKey<String>('body'))),
        Rect.fromLTWH(origin.dx + 17, origin.dy + 91, 324, 100),
      );

      // css:324 — çizgi kutusu 2 px, yatay boşluk 16; tire 6, boşluk ≈ 4
      // (324 px → 33 tire, boşluk 3.9375). css:325 — çentik merkezi çizgi
      // ortasında (y 1) ve çerçevenin iç kenarında (x −16 / genişlik + 16).
      expect(
        tester.getRect(_cut),
        Rect.fromLTWH(origin.dx + 17, origin.dy + 73, 324, 2),
      );
      expect(
        _cut,
        paints
          ..rect(rect: const Rect.fromLTWH(0, 0, 6, 2), color: c.borderDefault)
          ..rect(
            rect: const Rect.fromLTWH(9.9375, 0, 6, 2),
            color: c.borderDefault,
          )
          ..circle(x: -16, y: 1, radius: 12, color: c.bgCanvas)
          ..circle(x: 340, y: 1, radius: 12, color: c.bgCanvas),
      );
    });

    testWidgets(
      'T-04 · GuTicketFrame · tire boşluğu genişliğe uyar; koyu tema; '
      '320 dp × 1.6 uzun metin taşmaz',
      (tester) async {
        const c = GuColors.dark;
        // Çizgi 326 px → 33 tire, boşluk tam 4.
        await tester.pumpApp(_frame(360), theme: ThemeMode.dark);
        expect(
          _cut,
          paints
            ..rect(
              rect: const Rect.fromLTWH(0, 0, 6, 2),
              color: c.borderDefault,
            )
            ..rect(rect: const Rect.fromLTWH(10, 0, 6, 2))
            ..circle(x: -16, y: 1, radius: 12, color: c.bgCanvas)
            ..circle(x: 342, y: 1, radius: 12, color: c.bgCanvas),
        );
        // Çizgi 14 px → 2 tire, boşluk 2.
        await tester.pumpApp(_frame(48), theme: ThemeMode.dark);
        expect(
          _cut,
          paints
            ..rect(rect: const Rect.fromLTWH(0, 0, 6, 2))
            ..rect(rect: const Rect.fromLTWH(8, 0, 6, 2)),
        );
        // Çizgi 10 px → boşluğa yer yok, kesiksiz.
        await tester.pumpApp(_frame(44), theme: ThemeMode.dark);
        expect(_cut, paints..rect(rect: const Rect.fromLTWH(0, 0, 10, 2)));
        expect(
          _cut,
          isNot(
            paints
              ..rect()
              ..rect(),
          ),
        );

        final long = 'Yapay Zekâya Giriş Atölyesi ' * 3;
        final style = GuTypography.resolve(GuColors.light).titleM;
        await tester.pumpApp(
          Center(
            child: GuTicketFrame(
              header: Text(long, style: style),
              body: Text(long, style: style),
            ),
          ),
          size: const Size(320, 640),
          textScale: 1.6,
        );
        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byType(GuTicketFrame)).width, 320);
        expect(tester.getSize(find.text(long).first).width, 320 - 2 - 32);
      },
    );
  });
}
