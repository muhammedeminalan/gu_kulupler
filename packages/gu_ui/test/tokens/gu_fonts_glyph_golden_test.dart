import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/src/tokens/gu_colors.dart';
import 'package:gu_ui/src/tokens/gu_typography.dart';

import '../helpers/test_fonts.dart';

/// PLAN §7.10 Türkçe glif örneği.
const String _sample = 'ğ ş İ ı ç ö ü ₺ Ğ Ş Ç Ö Ü';

/// Paketli 7 yüz (D-12): Montserrat 400/500/600/700 + Inter 400/500/600 —
/// `testFontFaces` (= kök pubspec `fonts:`, `helpers/test_fonts_test.dart`).
final List<(String, FontWeight)> _faces = [
  for (final f in testFontFaces) (f.family, f.weight),
];

const double _fontSize = 20;

TextStyle _style(String family, FontWeight weight, Color color) => TextStyle(
  fontFamily: family,
  fontWeight: weight,
  fontSize: _fontSize,
  height: 1.4,
  color: color,
);

Widget _glyphSheet(GuColors c) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(
    child: RepaintBoundary(
      key: const ValueKey('glyphs'),
      child: ColoredBox(
        color: c.bgCanvas,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (family, weight) in _faces)
                Text(
                  '$family ${weight.value}  $_sample',
                  style: _style(family, weight, c.textPrimary),
                ),
            ],
          ),
        ),
      ),
    ),
  ),
);

double _width(String text, String family, FontWeight weight) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: _style(family, weight, GuColors.light.textPrimary),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

void main() {
  group('T-01 · Türkçe glif golden (PLAN §7.10, D-12)', () {
    for (final (name, colors) in [
      ('light', GuColors.light),
      ('dark', GuColors.dark),
    ]) {
      testWidgets('7 yüz × $name zemin', (tester) async {
        tester.view
          ..physicalSize = const Size(720, 360)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_glyphSheet(colors));
        await expectLater(
          find.byKey(const ValueKey('glyphs')),
          matchesGoldenFile('../goldens/fonts_glyphs__$name.png'),
        );
      });
    }
  });

  group('T-01 · ₺ ve Türkçe glifler gerçek fonttan çizilir (TextPainter)', () {
    for (final (family, weight) in _faces) {
      test('$family ${weight.value} — ₺ genişliği > 0 ve .notdef değil', () {
        final lira = _width('₺', family, weight);
        final notdef = _width('￿', family, weight);
        expect(lira, greaterThan(0));
        expect(lira, isNot(closeTo(notdef, 0.01)));
        for (final glyph in _sample.split(' ')) {
          final w = _width(glyph, family, weight);
          expect(w, greaterThan(0), reason: glyph);
          expect(w, isNot(closeTo(notdef, 0.01)), reason: glyph);
        }
      });
    }

    test('Montserrat ve Inter farklı yüzler (yedek fonta düşülmedi)', () {
      final montserrat = _width(
        _sample,
        GuTypography.fontFamilyMontserrat,
        FontWeight.w400,
      );
      final inter = _width(
        _sample,
        GuTypography.fontFamilyInter,
        FontWeight.w400,
      );
      final fallback = _width(_sample, 'FlutterTest', FontWeight.w400);
      expect(montserrat, isNot(closeTo(inter, 0.01)));
      expect(montserrat, isNot(closeTo(fallback, 0.01)));
      expect(inter, isNot(closeTo(fallback, 0.01)));
    });

    test('ağırlıklar ayrı dosyalardan (400 ≠ 700, 400 ≠ 600)', () {
      const text = 'Gümüşhane İlçesi ₺';
      expect(
        _width(text, GuTypography.fontFamilyMontserrat, FontWeight.w400),
        isNot(
          closeTo(
            _width(text, GuTypography.fontFamilyMontserrat, FontWeight.w700),
            0.01,
          ),
        ),
      );
      expect(
        _width(text, GuTypography.fontFamilyInter, FontWeight.w400),
        isNot(
          closeTo(
            _width(text, GuTypography.fontFamilyInter, FontWeight.w600),
            0.01,
          ),
        ),
      );
    });
  });
}
