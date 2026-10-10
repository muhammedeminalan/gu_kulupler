// T-04 · GuTimeline + GuTimelineItem + GuTimelineDot (widget-catalog #73;
// CD-25, K-36).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

final Finder _lines = find.descendant(
  of: find.byType(GuTimeline),
  matching: find.byType(ColoredBox),
);

void main() {
  group('T-04 · GuTimeline', () {
    testWidgets(
      'T-04 · GuTimeline · öğe 56, ray 24, nokta 12 + halka, çizgi 2; '
      'nokta durum renkleri; Semantics adım başına tek düğüm',
      (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpApp(
          const Center(
            child: SizedBox(
              width: 300,
              child: GuTimeline(
                items: [
                  GuTimelineItem(
                    state: GuTimelineDotState.done,
                    title: 'Gönderildi',
                    caption: '6 Eki Sal, 20:04',
                  ),
                  GuTimelineItem(
                    state: GuTimelineDotState.active,
                    title: 'İnceleniyor',
                    caption: 'Kulüp yönetimi inceliyor',
                  ),
                  GuTimelineItem(
                    state: GuTimelineDotState.danger,
                    title: 'Sonuç',
                    caption: '',
                  ),
                  GuTimelineItem(
                    state: GuTimelineDotState.pending,
                    title: 'Arşiv',
                  ),
                ],
              ),
            ),
          ),
        );
        const c = GuColors.light;
        final typography = GuTypography.resolve(c);
        final origin = tester.getTopLeft(find.byType(GuTimeline));
        // css:308 — 4 öğe × min 56.
        expect(tester.getSize(find.byType(GuTimeline)), const Size(300, 224));

        // css:310–311 — 12 px nokta, 2 px bg.surface kenarlık, 2 px halka.
        final dots = find.byType(GuTimelineDot);
        expect(dots, findsNWidgets(4));
        final expected = [
          c.stateSuccess,
          c.brandPrimary,
          c.stateDanger,
          c.borderDefault,
        ];
        for (var i = 0; i < 4; i++) {
          expect(tester.getSize(dots.at(i)), const Size.square(12));
          // Ray 24'te yatay ortalı, üst boşluk 4.
          expect(tester.getTopLeft(dots.at(i)), origin + Offset(6, i * 56 + 4));
          final box =
              tester
                      .widget<DecoratedBox>(
                        find.descendant(
                          of: dots.at(i),
                          matching: find.byType(DecoratedBox),
                        ),
                      )
                      .decoration
                  as BoxDecoration;
          expect(box.shape, BoxShape.circle);
          expect(box.color, expected[i]);
          expect(box.border, Border.all(color: c.bgSurface, width: 2));
          expect(box.boxShadow, [
            BoxShadow(color: expected[i], spreadRadius: 2),
          ]);
        }

        // css:312 — son öğe dışında 2 px çizgi: üstten 20, alttan 4.
        expect(_lines, findsNWidgets(3));
        expect(tester.widget<ColoredBox>(_lines.first).color, c.borderDefault);
        expect(
          tester.getRect(_lines.first),
          Rect.fromLTWH(origin.dx + 11, origin.dy + 20, 2, 32),
        );

        // İçerik: ray 24 + aralık 12; başlık labelL heading, açıklama caption.
        expect(
          tester.getTopLeft(find.text('Gönderildi')),
          origin + const Offset(36, 0),
        );
        expect(
          tester.widget<Text>(find.text('Gönderildi')).style,
          typography.labelL.copyWith(color: c.textHeading),
        );
        expect(
          tester.widget<Text>(find.text('6 Eki Sal, 20:04')).style,
          typography.caption,
        );
        expect(
          tester.getTopLeft(find.text('6 Eki Sal, 20:04')).dy -
              tester.getBottomLeft(find.text('Gönderildi')).dy,
          2,
        );
        // Boş / null açıklama çizilmez.
        expect(find.byType(Text), findsNWidgets(6));
        expect(
          find.bySemanticsLabel('Gönderildi\n6 Eki Sal, 20:04'),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel('Arşiv'), findsOneWidget);
        handle.dispose();
      },
    );

    testWidgets('T-04 · GuTimeline · 320 dp × 1.6 uzun metin: taşma yok, öğe '
        'büyür, çizgi içerikle uzar', (tester) async {
      final long = 'Kulüp yönetimi başvurunu inceliyor ' * 6;
      await tester.pumpApp(
        Center(
          child: GuTimeline(
            items: [
              GuTimelineItem(
                state: GuTimelineDotState.active,
                title: long,
                caption: long,
              ),
              const GuTimelineItem(
                state: GuTimelineDotState.pending,
                title: 'Sonuç',
              ),
            ],
          ),
        ),
        size: const Size(320, 640),
        textScale: 1.6,
        theme: ThemeMode.dark,
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(GuTimeline)).width, 320);
      final first = tester.getRect(find.byType(GuTimelineDot).first);
      final second = tester.getRect(find.byType(GuTimelineDot).last);
      final itemHeight = second.top - first.top;
      expect(itemHeight, greaterThan(56));
      expect(_lines, findsOneWidget);
      expect(tester.getSize(_lines).height, itemHeight - 20 - 4);
      expect(
        tester.widget<ColoredBox>(_lines).color,
        GuColors.dark.borderDefault,
      );
      // Metin sağ kenarı aşmaz.
      expect(
        tester.getRect(find.text(long).first).right,
        lessThanOrEqualTo(320),
      );
    });
  });
}
