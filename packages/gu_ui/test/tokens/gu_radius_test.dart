import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/src/tokens/gu_radius.dart';

import '../helpers/css_measure.dart';
import '../helpers/design_sources.dart';

const String _lightRoot = '.gu-root[data-theme="light"]';

void main() {
  late Map<String, dynamic> registryRadius;
  final css = CssMeasure.load();

  /// Tüm `border-radius` bildirimlerindeki px uzunlukları (kısa yazım dahil).
  final cssRadiusPx = <double>{
    for (final d in css.declarations)
      if (d.prop == 'border-radius')
        for (final t in CssMeasure.splitTokens(d.value))
          if (t.endsWith('px')) CssMeasure.parsePx(t),
  };

  setUpAll(() {
    registryRadius = registryTokens()['RADIUS'] as Map<String, dynamic>;
  });

  /// `selector` kuralındaki `border-radius` değeri (ham metin).
  String radiusOf(String selector) => css.raw(selector, 'border-radius');

  /// Tek px `border-radius` değeri (`12px`).
  double singlePx(String selector) => css.px(selector, 'border-radius');

  group('T-01 · GuRadius registry (reg.RADIUS, 5)', () {
    test('registry 5 anahtar ve değer', () {
      expect(registryRadius.keys.toSet(), {'sm', 'md', 'lg', 'xl', 'full'});
      final actual = <String, double>{
        'sm': GuRadius.sm,
        'md': GuRadius.md,
        'lg': GuRadius.lg,
        'xl': GuRadius.xl,
        'full': GuRadius.full,
      };
      for (final e in actual.entries) {
        expect(
          e.value,
          (registryRadius[e.key] as num).toDouble(),
          reason: e.key,
        );
      }
    });

    test('tokens.json#radius registry ile eşit', () {
      expect(tokensJson()['radius'], registryRadius);
    });

    test('CSS --r-* değişkenleri registry ile eşit (css:31–35)', () {
      for (final key in registryRadius.keys) {
        expect(
          css.px(_lightRoot, '--r-$key'),
          (registryRadius[key] as num).toDouble(),
          reason: '--r-$key',
        );
      }
    });

    test('BorderRadius sabitleri (dört köşe)', () {
      final cases = <(BorderRadius, double)>[
        (GuRadius.borderSm, GuRadius.sm),
        (GuRadius.borderMd, GuRadius.md),
        (GuRadius.borderLg, GuRadius.lg),
        (GuRadius.borderXl, GuRadius.xl),
        (GuRadius.borderFull, GuRadius.full),
      ];
      for (final (br, r) in cases) {
        expect(br, BorderRadius.all(Radius.circular(r)));
      }
      expect(GuRadius.borderSm.topLeft.x, 12);
    });

    test('topXl = yalnızca üst köşeler xl (.sheet css:268)', () {
      expect(radiusOf('.sheet'), 'var(--r-xl) var(--r-xl) 0 0');
      expect(
        GuRadius.topXl,
        const BorderRadius.vertical(top: Radius.circular(28)),
      );
      expect(GuRadius.topXl.bottomLeft, Radius.zero);
      expect(GuRadius.topXl.bottomRight, Radius.zero);
    });
  });

  group('T-01 · GuRadius CSS-derived (9)', () {
    test('seçici bazlı CSS değerleri', () {
      final cases = <(String, double)>[
        ('.chip', GuRadius.chip),
        ('.emblem.is-xs', GuRadius.emblemXs),
        ('.sk', GuRadius.skeleton),
        ('.check', GuRadius.checkbox),
        ('.scan-box>i', GuRadius.scanCorner),
        ('.prog', GuRadius.progress),
        ('.sheet-handle', GuRadius.handle),
        ('.img-grid', GuRadius.imageGrid),
        ('.switch', GuRadius.switchTrack),
      ];
      expect(cases, hasLength(9));
      for (final (selector, value) in cases) {
        expect(singlePx(selector), value, reason: selector);
      }
    });

    test('ikincil kullanımlar aynı değeri taşır', () {
      expect(singlePx('.seg>button'), GuRadius.chip);
      expect(singlePx('.popmenu .tile'), GuRadius.chip);
      expect(singlePx('.toast .toast-action'), GuRadius.skeleton);
      expect(singlePx('.tooltip'), GuRadius.checkbox);
      expect(singlePx('.prog>i'), GuRadius.progress);
      expect(singlePx('.stepbar>i'), GuRadius.handle);
    });

    test('her türev CSS border-radius:Npx kümesinde', () {
      for (final v in [
        GuRadius.chip,
        GuRadius.emblemXs,
        GuRadius.skeleton,
        GuRadius.checkbox,
        GuRadius.scanCorner,
        GuRadius.progress,
        GuRadius.handle,
        GuRadius.imageGrid,
        GuRadius.switchTrack,
      ]) {
        expect(cssRadiusPx, contains(v));
      }
    });

    test('switchTrack = .switch yüksekliği / 2', () {
      expect(GuRadius.switchTrack, css.px('.switch', 'height') / 2);
    });

    test('navIndicator = 0 0 3px 3px (css:136)', () {
      final raw = radiusOf('.bottomnav>button[aria-current="page"]::before');
      expect(
        raw,
        '0 0 ${GuRadius.progress.toInt()}px '
        '${GuRadius.progress.toInt()}px',
      );
      expect(
        GuRadius.navIndicator,
        const BorderRadius.vertical(bottom: Radius.circular(3)),
      );
      expect(GuRadius.navIndicator.topLeft, Radius.zero);
    });

    test('tabIndicator = 2px 2px 0 0 (css:228)', () {
      final raw = radiusOf('.tabs>button[aria-selected="true"]::after');
      expect(
        raw,
        '${GuRadius.handle.toInt()}px '
        '${GuRadius.handle.toInt()}px 0 0',
      );
      expect(
        GuRadius.tabIndicator,
        const BorderRadius.vertical(top: Radius.circular(2)),
      );
      expect(GuRadius.tabIndicator.bottomLeft, Radius.zero);
    });

    test('türev BorderRadius sabitleri (dört köşe)', () {
      final cases = <(BorderRadius, double)>[
        (GuRadius.borderChip, GuRadius.chip),
        (GuRadius.borderEmblemXs, GuRadius.emblemXs),
        (GuRadius.borderSkeleton, GuRadius.skeleton),
        (GuRadius.borderCheckbox, GuRadius.checkbox),
        (GuRadius.borderScanCorner, GuRadius.scanCorner),
        (GuRadius.borderProgress, GuRadius.progress),
        (GuRadius.borderHandle, GuRadius.handle),
        (GuRadius.borderImageGrid, GuRadius.imageGrid),
        (GuRadius.borderSwitchTrack, GuRadius.switchTrack),
      ];
      for (final (br, r) in cases) {
        expect(br, BorderRadius.all(Radius.circular(r)));
      }
    });
  });
}
