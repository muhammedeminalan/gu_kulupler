// T-01 · GuShadows — token-map §6. Gölge dizeleri registry ve
// component-css.css'ten (`CssMeasure`) OKUNUR; CSS blur → Flutter
// `blurRadius` dönüşümü σ eşitliğiyle doğrulanır (C1).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/src/tokens/gu_shadows.dart';

import '../helpers/css_measure.dart';
import '../helpers/design_sources.dart';
import '../helpers/theme_extension_sentinel.dart';

/// CSS gölge katmanı: ofset, CSS blur (px) ve ARGB.
typedef _CssShadow = ({Offset offset, double blur, int argb});

/// CSS `box-shadow` dizesi → katmanlar (`x y blur rgba(r,g,b,a)`; `0`
/// birimsiz olabilir; `none` → boş).
List<_CssShadow> _parseCssShadows(String value) {
  final v = value.trim();
  if (v == 'none') return const [];
  final layers = CssMeasure.splitList(v);
  return [
    for (final layer in layers)
      () {
        final parts = CssMeasure.splitTokens(layer);
        expect(parts, hasLength(4), reason: 'gölge katmanı: $layer');
        return (
          offset: Offset(
            CssMeasure.parsePx(parts[0]),
            CssMeasure.parsePx(parts[1]),
          ),
          blur: CssMeasure.parsePx(parts[2]),
          argb: parseCssColor(parts[3]),
        );
      }(),
  ];
}

const String _lightRoot = '.gu-root[data-theme="light"]';
const String _darkRoot = '.gu-root[data-theme="dark"]';

/// `var(--x)` → açık tema bloğundaki değer (`--e*` css:36–39); değilse aynen.
String _resolveVar(CssMeasure css, String value) {
  final m = RegExp(r'^var\((--[\w-]+)\)$').firstMatch(value.trim());
  return m == null ? value : css.raw(_lightRoot, m.group(1)!);
}

/// `fields` haritası (copyWith adları, `props` sırası).
Map<String, Object?> _fields(GuShadows s) => {
  'e0': s.e0,
  'e1': s.e1,
  'e2': s.e2,
  'e3': s.e3,
  'ctaBar': s.ctaBar,
  'fab': s.fab,
  'switchThumb': s.switchThumb,
};

void main() {
  final css = CssMeasure.load();
  final registryShadows = registryTokens()['SHADOWS'] as Map<String, dynamic>;

  /// Her gölge alanının CSS kaynağı (tema, alan, CSS dizesi, açıklama).
  final sources = <(String, List<BoxShadow>, String, String)>[
    for (final key in ['e0', 'e1', 'e2', 'e3'])
      (
        'açık',
        _fields(GuShadows.light)[key]! as List<BoxShadow>,
        registryShadows[key] as String,
        'registry $key',
      ),
    (
      'koyu',
      GuShadows.dark.e0,
      css.raw(_lightRoot, '--e0'),
      'css:36 --e0 (koyu blokta tanımsız → açık none)',
    ),
    for (final key in ['e1', 'e2', 'e3'])
      (
        'koyu',
        _fields(GuShadows.dark)[key]! as List<BoxShadow>,
        css.raw(_darkRoot, '--$key'),
        'css:74 --$key',
      ),
    (
      'açık',
      GuShadows.light.ctaBar,
      css.raw('.ctabar', 'box-shadow'),
      '.ctabar css:296',
    ),
    (
      'koyu',
      GuShadows.dark.ctaBar,
      css.raw('$_darkRoot .ctabar', 'box-shadow'),
      'css:299',
    ),
    (
      'açık',
      GuShadows.light.fab,
      _resolveVar(css, css.raw('.fab', 'box-shadow')),
      '.fab css:158 var(--e2)',
    ),
    (
      'koyu',
      GuShadows.dark.fab,
      css.raw('$_darkRoot .fab', 'box-shadow'),
      'css:159',
    ),
    for (final (theme, s) in [
      ('açık', GuShadows.light),
      ('koyu', GuShadows.dark),
    ])
      (theme, s.switchThumb, css.raw('.switch>i', 'box-shadow'), 'css:234'),
  ];

  void expectShadows(List<BoxShadow> actual, String cssValue, String reason) {
    final expected = _parseCssShadows(cssValue);
    expect(actual, hasLength(expected.length), reason: reason);
    for (var i = 0; i < expected.length; i++) {
      final a = actual[i];
      final e = expected[i];
      expect(a.offset, e.offset, reason: '$reason #$i offset');
      expect(a.spreadRadius, 0, reason: '$reason #$i spread');
      expect(a.blurStyle, BlurStyle.normal, reason: '$reason #$i blurStyle');
      expect(a.color.toARGB32(), e.argb, reason: '$reason #$i renk');
      // C1: CSS σ = blur / 2 ↔ Flutter σ = r × 0.57735 + 0.5.
      expect(
        Shadow.convertRadiusToSigma(a.blurRadius),
        closeTo(e.blur / 2, 1e-9),
        reason: '$reason #$i σ',
      );
      expect(a.blurSigma, closeTo(e.blur / 2, 1e-9), reason: '$reason #$i');
      expect(
        a.blurRadius,
        GuShadows.cssBlurToRadius(e.blur),
        reason: '$reason #$i blurRadius == cssBlurToRadius(${e.blur})',
      );
    }
  }

  group('T-01 · GuShadows registry (reg.SHADOWS, 4)', () {
    test('registry 4 anahtar; tokens.json#shadows eşit', () {
      expect(registryShadows.keys.toSet(), {'e0', 'e1', 'e2', 'e3'});
      expect(tokensJson()['shadows'], registryShadows);
    });

    test('CSS --e* değişkenleri registry ile eşit (css:36–39)', () {
      for (final key in registryShadows.keys) {
        expect(
          css.raw(_lightRoot, '--$key'),
          registryShadows[key],
          reason: key,
        );
      }
    });

    test('koyu tema e0–e3 boş (css:74 --e1/--e2/--e3: none)', () {
      for (final key in ['e1', 'e2', 'e3']) {
        expect(css.raw(_darkRoot, '--$key'), 'none', reason: 'koyu --$key');
      }
      expect(GuShadows.dark.e0, isEmpty);
      expect(GuShadows.dark.e1, isEmpty);
      expect(GuShadows.dark.e2, isEmpty);
      expect(GuShadows.dark.e3, isEmpty);
      expect(GuShadows.light.e0, isEmpty);
      expect(GuShadows.light.e1, hasLength(2));
    });
  });

  group('T-01 · GuShadows CSS kaynaklarıyla (ofset, renk, σ)', () {
    test('kaynak tablosu 7 alan × 2 tema', () {
      expect(sources, hasLength(14));
    });

    for (final (theme, actual, cssValue, label) in sources) {
      test('$theme · $label', () => expectShadows(actual, cssValue, label));
    }

    test('fab açık = e2 (var(--e2) css:158); switchThumb iki temada aynı', () {
      expect(css.raw('.fab', 'box-shadow'), 'var(--e2)');
      expect(GuShadows.light.fab, GuShadows.light.e2);
      expect(css.has('$_darkRoot .switch>i', 'box-shadow'), isFalse);
      expect(GuShadows.dark.switchThumb, GuShadows.light.switchThumb);
    });

    test('alfa dönüşümleri (token-map §6)', () {
      expect(GuShadows.light.e1[0].color.toARGB32(), 0x0F101828);
      expect(GuShadows.light.e1[1].color.toARGB32(), 0x14101828);
      expect(GuShadows.light.e2[0].color.toARGB32(), 0x1A101828);
      expect(GuShadows.light.e3[0].color.toARGB32(), 0x29101828);
      expect(GuShadows.light.ctaBar[0].color.toARGB32(), 0x0F101828);
      expect(GuShadows.dark.fab[0].color.toARGB32(), 0x66000000);
      expect(GuShadows.light.switchThumb[0].color.toARGB32(), 0x33000000);
    });
  });

  group('T-01 · GuShadows.cssBlurToRadius (C1)', () {
    test('σ eşitliği: convertRadiusToSigma(cssBlurToRadius(b)) == b / 2', () {
      for (final blur in <double>[2, 3, 6, 12, 16, 32, 100]) {
        expect(
          Shadow.convertRadiusToSigma(GuShadows.cssBlurToRadius(blur)),
          closeTo(blur / 2, 1e-9),
          reason: 'blur $blur',
        );
      }
    });

    test('σ ≤ 0.5 → 0 (blur 0, 1, negatif)', () {
      expect(GuShadows.cssBlurToRadius(0), 0);
      expect(GuShadows.cssBlurToRadius(1), 0);
      expect(GuShadows.cssBlurToRadius(0.5), 0);
      expect(GuShadows.cssBlurToRadius(-4), 0);
    });

    test('CSS blur değeri Flutter blurRadius olarak yazılmaz (σ farkı)', () {
      // Eski eşleme `blurRadius: blur` → σ = 12 × 0.57735 + 0.5 ≈ 7.43 ≠ 6.
      expect(Shadow.convertRadiusToSigma(12), isNot(closeTo(6, 0.1)));
      expect(GuShadows.light.e2[0].blurRadius, lessThan(12));
    });
  });

  group('T-01 · GuShadows ThemeExtension', () {
    test('props 7 alan, _fields sırasıyla; light != dark', () {
      expect(GuShadows.light.props, hasLength(7));
      expect(GuShadows.light.props, _fields(GuShadows.light).values.toList());
      expect(GuShadows.light, isNot(GuShadows.dark));
    });

    test('lerp uçları (gerçek temalar)', () {
      expect(GuShadows.light.lerp(GuShadows.dark, 0), GuShadows.light);
      expect(GuShadows.dark.lerp(GuShadows.light, 1), GuShadows.light);
      expect(GuShadows.dark.lerp(GuShadows.dark, 0.5), GuShadows.dark);
      // Açık → koyu t=1: koyuda boş olan gölgeler sıfır ölçüye ölçeklenir.
      final end = GuShadows.light.lerp(GuShadows.dark, 1);
      for (final s in [...end.e1, ...end.e2, ...end.e3, ...end.ctaBar]) {
        expect(s.blurRadius, 0);
        expect(s.offset, Offset.zero);
      }
      expect(end.fab, GuShadows.dark.fab);
      expect(end.switchThumb, GuShadows.dark.switchThumb);
    });

    testWidgets('ThemeData.extension ile çözülür', (tester) async {
      GuShadows? resolved;
      await tester.pumpWidget(
        Theme(
          data: ThemeData(extensions: const [GuShadows.dark]),
          child: Builder(
            builder: (context) {
              resolved = Theme.of(context).extension<GuShadows>();
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(resolved, GuShadows.dark);
    });
  });

  registerSentinelTests<GuShadows>(
    name: 'GuShadows',
    original: GuShadows.light,
    fields: _fields,
    // Her alana farklı uzunluk ve bulanıklıkta liste.
    sentinel: (field, i, salt) => [
      for (var k = 0; k <= i % 2; k++)
        BoxShadow(
          offset: Offset(k.toDouble(), (i + 1).toDouble()),
          blurRadius: i + 1 + salt * 100,
          color: Color(0xFF000001 + i + salt * 0x100),
        ),
    ],
    lerpField: (field, a, b, t) =>
        BoxShadow.lerpList(a as List<BoxShadow>?, b as List<BoxShadow>?, t) ??
        const <BoxShadow>[],
  );
}
