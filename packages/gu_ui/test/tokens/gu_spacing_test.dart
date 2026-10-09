import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';

import '../helpers/css_measure.dart';
import '../helpers/design_sources.dart';

void main() {
  late List<double> registrySpacing;
  final css = CssMeasure.load();

  /// `.gapN{gap:Npx}` yardımcı sınıfları (css:101): N → px.
  final cssGaps = <int, int>{
    for (final selector in css.selectors)
      if (RegExp(r'^\.gap(\d+)$').firstMatch(selector) case final m?)
        int.parse(m.group(1)!): css.px(selector, 'gap').toInt(),
  };

  setUpAll(() {
    registrySpacing = (registryTokens()['SPACING'] as List<dynamic>)
        .map((dynamic v) => (v as num).toDouble())
        .toList();
  });

  group('T-01 · GuSpacing registry (reg.SPACING, 9)', () {
    test('registry 9 değer ve sıra GuSpacing.s4–s48 ile eşit', () {
      expect(registrySpacing, hasLength(9));
      expect(registrySpacing, [
        GuSpacing.s4,
        GuSpacing.s8,
        GuSpacing.s12,
        GuSpacing.s16,
        GuSpacing.s20,
        GuSpacing.s24,
        GuSpacing.s32,
        GuSpacing.s40,
        GuSpacing.s48,
      ]);
    });

    test('tokens.json#spacing registry ile eşit', () {
      final tj = (tokensJson()['spacing'] as List<dynamic>)
          .map((dynamic v) => (v as num).toDouble())
          .toList();
      expect(tj, registrySpacing);
    });

    test('CSS .gapN sınıfı olan registry değerleri CSS ile tutarlı', () {
      for (final v in registrySpacing) {
        final key = v.toInt();
        if (cssGaps.containsKey(key)) {
          expect(cssGaps[key], key, reason: '.gap$key');
        }
      }
    });
  });

  group('T-01 · GuSpacing CSS-derived (css:101; CD-99)', () {
    test('s2 = .gap2, s6 = .gap6 (CSS okunur)', () {
      expect(GuSpacing.s2, cssGaps[2]!.toDouble());
      expect(GuSpacing.s6, cssGaps[6]!.toDouble());
    });

    test('CSS-derived grup yalnızca 2 değer: registry dışı .gapN = {2, 6}', () {
      final registryInts = registrySpacing.map((v) => v.toInt()).toSet();
      final derived = cssGaps.keys.where((k) => !registryInts.contains(k));
      expect(derived.toSet(), {2, 6});
    });

    test('CD-99/K-42: .gap10 CSS kuralı tanımsız → s10 yazılmaz', () {
      expect(cssGaps.containsKey(10), isFalse);
      expect(css.has('.gap10'), isFalse);
    });
  });

  group('T-01 · GuGap', () {
    test('h* genişlik, v* yükseklik (9 × 2)', () {
      const gaps = <(SizedBox, SizedBox, double)>[
        (GuGap.h4, GuGap.v4, GuSpacing.s4),
        (GuGap.h8, GuGap.v8, GuSpacing.s8),
        (GuGap.h12, GuGap.v12, GuSpacing.s12),
        (GuGap.h16, GuGap.v16, GuSpacing.s16),
        (GuGap.h20, GuGap.v20, GuSpacing.s20),
        (GuGap.h24, GuGap.v24, GuSpacing.s24),
        (GuGap.h32, GuGap.v32, GuSpacing.s32),
        (GuGap.h40, GuGap.v40, GuSpacing.s40),
        (GuGap.h48, GuGap.v48, GuSpacing.s48),
      ];
      expect(gaps, hasLength(registrySpacing.length));
      for (final (h, v, value) in gaps) {
        expect(h.width, value);
        expect(h.height, isNull);
        expect(v.height, value);
        expect(v.width, isNull);
      }
      expect(GuGap.v16.height, 16);
    });
  });

  group('T-01 · GuInsets', () {
    test('tablo değerleri (token-map §4)', () {
      expect(GuInsets.all4, const EdgeInsets.all(4));
      expect(GuInsets.all8, const EdgeInsets.all(8));
      expect(GuInsets.h8, const EdgeInsets.symmetric(horizontal: 8));
      expect(GuInsets.v8, const EdgeInsets.symmetric(vertical: 8));
      expect(GuInsets.all12, const EdgeInsets.all(12));
      expect(GuInsets.h12, const EdgeInsets.symmetric(horizontal: 12));
      expect(GuInsets.v12, const EdgeInsets.symmetric(vertical: 12));
      expect(GuInsets.all16, const EdgeInsets.all(16));
      expect(GuInsets.h16, const EdgeInsets.symmetric(horizontal: 16));
      expect(GuInsets.v16, const EdgeInsets.symmetric(vertical: 16));
      expect(
        GuInsets.h16v8,
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      );
      expect(
        GuInsets.h16v12,
        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      );
      expect(GuInsets.all20, const EdgeInsets.all(20));
      expect(
        GuInsets.h20v12,
        const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      );
      expect(GuInsets.all24, const EdgeInsets.all(24));
      expect(GuInsets.h24, const EdgeInsets.symmetric(horizontal: 24));
      expect(GuInsets.all32, const EdgeInsets.all(32));
    });

    test('CSS yardımcı dolgu sınıfları ile eşit (css:102)', () {
      expect(GuInsets.all16, EdgeInsets.all(css.px('.p16', 'padding')));
      expect(GuInsets.all12, EdgeInsets.all(css.px('.p12', 'padding')));
      expect(GuInsets.all20, EdgeInsets.all(css.px('.p20', 'padding')));
      expect(GuInsets.h16.left, css.px('.px16', 'padding-left'));
      expect(GuInsets.h16.right, css.px('.px16', 'padding-right'));
      expect(GuInsets.v8.top, css.px('.py8', 'padding-top'));
      expect(GuInsets.v8.bottom, css.px('.py8', 'padding-bottom'));
      expect(GuInsets.v12.top, css.px('.py12', 'padding-top'));
      expect(GuInsets.v12.bottom, css.px('.py12', 'padding-bottom'));
      expect(GuInsets.v16.top, css.px('.py16', 'padding-top'));
      expect(GuInsets.v16.bottom, css.px('.py16', 'padding-bottom'));
    });

    test('sym / only yardımcıları', () {
      expect(GuInsets.sym(), EdgeInsets.zero);
      expect(
        GuInsets.sym(h: GuSpacing.s16, v: GuSpacing.s12),
        GuInsets.h16v12,
      );
      expect(GuInsets.sym(h: GuSpacing.s8), GuInsets.h8);
      expect(GuInsets.sym(v: GuSpacing.s8), GuInsets.v8);
      expect(GuInsets.only(), EdgeInsets.zero);
      expect(
        GuInsets.only(
          left: GuSpacing.s4,
          top: GuSpacing.s8,
          right: GuSpacing.s12,
          bottom: GuSpacing.s16,
        ),
        const EdgeInsets.only(left: 4, top: 8, right: 12, bottom: 16),
      );
    });
  });
}
