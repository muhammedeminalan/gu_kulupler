// T-01 · AA kontrast — token-map §10 (CD-22, CD-98, CD-100, CD-110; K-25,
// K-41, K-43). Renkler `GuColors.light/dark` (+ `GuComponentColors`)
// üzerinden hesaplanır; beklenen oranlar token-map §10.1/§10.2/§10.3
// tablolarındaki sayılardır (±0.01). Renkler değişmez (Q-15): eşik altı
// çiftler bilinen kusur listelerinde tutulur.
//
// Kural (CD-100): liste dışı bir çift eşiğin altına inerse test KIRMIZI;
// listedeki bir çift eşiği geçerse test KIRMIZI (liste güncellenir).
import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/src/tokens/gu_colors.dart';
import 'package:gu_ui/src/tokens/gu_component_colors.dart';

import '../helpers/design_sources.dart';

/// Normal metin eşiği (WCAG 1.4.3).
const double _textThreshold = 4.5;

/// Metin dışı öğe / büyük metin eşiği (WCAG 1.4.11).
const double _nonTextThreshold = 3;

/// token-map sayıları 2 ondalık; hesaplanan oran bu toleransla eşleşir.
const double _tolerance = 0.01;

enum _Theme {
  light('açık', GuColors.light, GuComponentColors.light),
  dark('koyu', GuColors.dark, GuComponentColors.dark);

  const _Theme(this.label, this.colors, this.component);

  final String label;
  final GuColors colors;
  final GuComponentColors component;
}

/// Ön plan / arka plan çifti + token-map'teki açık/koyu oranları.
typedef _Pair = ({
  String fg,
  String bg,
  String usage,
  double light,
  double dark,
});

/// Bilinen kusur: (ön plan, arka plan, tema, token-map oranı).
typedef _Known = ({String fg, String bg, _Theme theme, double ratio});

// ── §10.1 metin çiftleri (eşik 4.5) ──────────────────────────────────────────
// `brandOnPrimary` on `stateSuccess`/`stateWarning`: kullanım yok → test dışı.
// `textDisabled` çiftleri WCAG 1.4.3 "inactive" istisnası → `_exemptPairs`.
// dart format off
const List<_Pair> _textPairs = [
  (fg: 'textPrimary', bg: 'bgCanvas', usage: 'gövde (css:77)', light: 16.86, dark: 15.55),
  (fg: 'textPrimary', bg: 'bgSurface', usage: 'kart gövdesi', light: 17.75, dark: 14.41),
  (fg: 'textPrimary', bg: 'bgSurfaceMuted', usage: 'girdi metni (css:163)', light: 16.20, dark: 12.07),
  (fg: 'textPrimary', bg: 'bgSurfaceRaised', usage: 'sheet gövdesi', light: 17.75, dark: 13.24),
  (fg: 'textHeading', bg: 'bgCanvas', usage: 'başlıklar', light: 13.88, dark: 16.12),
  (fg: 'textHeading', bg: 'bgSurface', usage: 'başlıklar, btn-outline (css:144)', light: 14.62, dark: 14.93),
  (fg: 'textHeading', bg: 'bgSurfaceRaised', usage: 'başlıklar, seg seçili', light: 14.62, dark: 13.71),
  (fg: 'textHeading', bg: 'bgSurfaceMuted', usage: 'başlıklar', light: 13.34, dark: 12.50),
  (fg: 'textSecondary', bg: 'bgSurface', usage: 'ikincil, badge-member (css:192)', light: 7.58, dark: 10.09),
  (fg: 'textSecondary', bg: 'bgCanvas', usage: 'ikincil', light: 7.20, dark: 10.89),
  (fg: 'textSecondary', bg: 'bgSurfaceMuted', usage: 'seg pasif (css:221), banner-readonly (css:254)', light: 6.92, dark: 8.45),
  (fg: 'textSecondary', bg: 'bgSurfaceRaised', usage: 'field-label (css:162)', light: 7.58, dark: 9.27),
  (fg: 'textMuted', bg: 'bgSurface', usage: 'caption, sekme pasif (css:226)', light: 4.76, dark: 7.89),
  (fg: 'textMuted', bg: 'bgCanvas', usage: 'caption, alt sekme pasif (css:134)', light: 4.52, dark: 8.52),
  (fg: 'textMuted', bg: 'bgSurfaceRaised', usage: 'wheel pasif (css:322)', light: 4.76, dark: 7.25),
  (fg: 'textMuted', bg: 'bgSurfaceMuted', usage: 'badge-neutral/badge-full (css:198), .picker .ph (css:174), yer tutucu (css:167)', light: 4.35, dark: 6.61),
  (fg: 'brandOnPrimary', bg: 'brandPrimary', usage: 'dolu buton (css:142), badge-brand (css:199)', light: 5.58, dark: 5.58),
  (fg: 'brandOnPrimary', bg: 'brandPrimaryPressed', usage: 'dolu buton basılı', light: 7.71, dark: 6.76),
  (fg: 'brandOnPrimaryContainer', bg: 'brandPrimaryContainer', usage: 'tonal buton (css:143), badge-president (css:189)', light: 9.58, dark: 13.06),
  (fg: 'brandPrimaryText', bg: 'bgSurface', usage: 'link (css:81), btn-text (css:145), aktif sekme (css:227)', light: 5.58, dark: 4.84),
  (fg: 'brandPrimaryText', bg: 'bgCanvas', usage: 'link, kpi.is-accent (css:304)', light: 5.30, dark: 5.22),
  (fg: 'brandPrimaryText', bg: 'bgSurfaceRaised', usage: 'sheet içi bağlantı metni', light: 5.58, dark: 4.45),
  (fg: 'brandPrimaryText', bg: 'brandPrimaryContainer', usage: 'quick-icon (css:306)', light: 4.75, dark: 5.01),
  (fg: 'stateSuccess', bg: 'stateSuccessContainer', usage: 'badge-success (css:195), banner-success (css:255)', light: 4.57, dark: 8.45),
  (fg: 'stateSuccess', bg: 'bgSurface', usage: 'ni-success (css:406)', light: 5.02, dark: 9.36),
  (fg: 'stateSuccess', bg: 'bgCanvas', usage: 'ni-success', light: 4.76, dark: 10.11),
  (fg: 'stateWarning', bg: 'stateWarningContainer', usage: 'badge-pending/advisor (css:194/191), banner-warning (css:252)', light: 4.51, dark: 8.30),
  (fg: 'stateWarning', bg: 'bgSurface', usage: 'uyarı metni', light: 5.02, dark: 9.77),
  (fg: 'stateWarning', bg: 'bgCanvas', usage: 'uyarı metni', light: 4.77, dark: 10.55),
  (fg: 'stateDanger', bg: 'stateDangerContainer', usage: 'badge-danger (css:196), banner-danger (css:253)', light: 5.45, dark: 6.35),
  (fg: 'stateDanger', bg: 'bgSurface', usage: 'hata metni (css:171), btn-danger-outline (css:146)', light: 6.57, dark: 6.42),
  (fg: 'stateDanger', bg: 'bgCanvas', usage: 'tile.is-danger (css:213)', light: 6.24, dark: 6.94),
  (fg: 'stateInfo', bg: 'stateInfoContainer', usage: 'badge-info (css:197), banner-info (css:251)', light: 5.51, dark: 7.40),
  (fg: 'stateInfo', bg: 'bgSurface', usage: 'bilgi metni', light: 6.38, dark: 7.71),
  (fg: 'stateInfo', bg: 'bgCanvas', usage: 'bilgi metni', light: 6.06, dark: 8.33),
  (fg: 'bgSurface', bg: 'textHeading', usage: 'toast metni (css:290), badge-superadmin (css:193), banner-offline (css:250), tooltip (css:341)', light: 14.62, dark: 14.93),
  (fg: 'textHeading', bg: 'brandPrimaryContainer', usage: 'seçili option-card (css:246)', light: 12.45, dark: 15.44),
  (fg: 'brandOnPrimary', bg: 'stateInfo', usage: '.notif-under .u-left (css:338)', light: 6.38, dark: 2.12),
  (fg: 'brandOnPrimary', bg: 'stateDanger', usage: '.notif-under .u-right (css:338), .btn-danger (css:147)', light: 6.57, dark: 2.54),
];

/// `expectedContrastFailures` — CD-22'nin 3 çifti + CD-100 4. çift (K-25).
const List<_Known> _expectedContrastFailures = [
  (fg: 'textMuted', bg: 'bgSurfaceMuted', theme: _Theme.light, ratio: 4.35),
  (fg: 'brandOnPrimary', bg: 'stateInfo', theme: _Theme.dark, ratio: 2.12),
  (fg: 'brandOnPrimary', bg: 'stateDanger', theme: _Theme.dark, ratio: 2.54),
  (fg: 'brandPrimaryText', bg: 'bgSurfaceRaised', theme: _Theme.dark, ratio: 4.45),
];

/// `textDisabled` — WCAG 1.4.3 "inactive" istisnası: eşik uygulanmaz, yalnızca
/// token-map değeri doğrulanır.
const List<_Pair> _exemptPairs = [
  (fg: 'textDisabled', bg: 'bgSurface', usage: 'devre dışı', light: 2.24, dark: 3.45),
  (fg: 'textDisabled', bg: 'bgCanvas', usage: 'cal-day.is-other (css:315)', light: 2.13, dark: 3.72),
];

// ── §10.2 metin dışı öğeler (eşik 3.0) — `nonTextPairs` (CD-100) ─────────────
// `borderDefault` on `bgCanvas`/`bgSurfaceRaised` (sheet-handle, stepbar,
// timeline) token-map §10.2 gereği kapsam dışı.
const List<_Pair> _nonTextPairs = [
  (fg: 'stateSuccess', bg: 'textHeading', usage: 'toast ikonu (css:291)', light: 2.91, dark: 1.59),
  (fg: 'stateDanger', bg: 'textHeading', usage: 'toast ikonu (css:291)', light: 2.22, dark: 2.32),
  (fg: 'stateInfo', bg: 'textHeading', usage: 'toast ikonu (css:291)', light: 2.29, dark: 1.94),
  (fg: 'brandPrimary', bg: 'bgSurface', usage: 'alt sekme göstergesi, switch açık ray, check dolu, dot, nav-badge', light: 5.58, dark: 2.92),
  (fg: 'brandPrimary', bg: 'bgSurfaceMuted', usage: 'ilerleme dolumu/ray (css:259–260)', light: 5.09, dark: 2.45),
  (fg: 'brandPrimary', bg: 'bgSurfaceRaised', usage: 'sheet içi brandPrimary öğeleri', light: 5.58, dark: 2.69),
  (fg: 'borderDefault', bg: 'bgSurface', usage: 'switch kapalı rayı (CD-110)', light: 1.23, dark: 1.58),
  (fg: 'focusRing', bg: 'bgCanvas', usage: 'odak halkası', light: 5.30, dark: 5.22),
  (fg: 'focusRing', bg: 'bgSurface', usage: 'odak halkası', light: 5.58, dark: 4.84),
  (fg: 'textMuted', bg: 'bgSurface', usage: 'check/radio boş kenarlık', light: 4.76, dark: 7.89),
];

/// `expectedNonTextContrastFailures` — K-43 / CD-100 + CD-110. token-map
/// "10 çift" sayar (switch rayı açık+koyu tek çift); tema bazında 11 kayıt.
const List<_Known> _expectedNonTextContrastFailures = [
  (fg: 'stateSuccess', bg: 'textHeading', theme: _Theme.light, ratio: 2.91),
  (fg: 'stateDanger', bg: 'textHeading', theme: _Theme.light, ratio: 2.22),
  (fg: 'stateInfo', bg: 'textHeading', theme: _Theme.light, ratio: 2.29),
  (fg: 'stateSuccess', bg: 'textHeading', theme: _Theme.dark, ratio: 1.59),
  (fg: 'stateDanger', bg: 'textHeading', theme: _Theme.dark, ratio: 2.32),
  (fg: 'stateInfo', bg: 'textHeading', theme: _Theme.dark, ratio: 1.94),
  (fg: 'brandPrimary', bg: 'bgSurface', theme: _Theme.dark, ratio: 2.92),
  (fg: 'brandPrimary', bg: 'bgSurfaceMuted', theme: _Theme.dark, ratio: 2.45),
  (fg: 'brandPrimary', bg: 'bgSurfaceRaised', theme: _Theme.dark, ratio: 2.69),
  (fg: 'borderDefault', bg: 'bgSurface', theme: _Theme.light, ratio: 1.23),
  (fg: 'borderDefault', bg: 'bgSurface', theme: _Theme.dark, ratio: 1.58),
];
// dart format on

/// `GuColors` alanı ada göre.
Color _color(GuColors c, String name) {
  final map = <String, Color>{
    'brandPrimary': c.brandPrimary,
    'brandPrimaryText': c.brandPrimaryText,
    'brandPrimaryPressed': c.brandPrimaryPressed,
    'brandOnPrimary': c.brandOnPrimary,
    'brandPrimaryContainer': c.brandPrimaryContainer,
    'brandOnPrimaryContainer': c.brandOnPrimaryContainer,
    'bgCanvas': c.bgCanvas,
    'bgSurface': c.bgSurface,
    'bgSurfaceMuted': c.bgSurfaceMuted,
    'bgSurfaceRaised': c.bgSurfaceRaised,
    'borderDefault': c.borderDefault,
    'borderSoft': c.borderSoft,
    'textPrimary': c.textPrimary,
    'textHeading': c.textHeading,
    'textSecondary': c.textSecondary,
    'textMuted': c.textMuted,
    'textDisabled': c.textDisabled,
    'stateSuccess': c.stateSuccess,
    'stateSuccessContainer': c.stateSuccessContainer,
    'stateWarning': c.stateWarning,
    'stateWarningContainer': c.stateWarningContainer,
    'stateDanger': c.stateDanger,
    'stateDangerContainer': c.stateDangerContainer,
    'stateInfo': c.stateInfo,
    'stateInfoContainer': c.stateInfoContainer,
    'overlayScrim': c.overlayScrim,
    'focusRing': c.focusRing,
  };
  final color = map[name];
  if (color == null) {
    throw ArgumentError.value(name, 'name', 'GuColors alanı yok');
  }
  return color;
}

int _channel(Color c, int shift) => (c.toARGB32() >> shift) & 0xFF;

bool _isOpaque(Color c) => (c.toARGB32() >>> 24) == 0xFF;

/// WCAG 2.1 bağıl parlaklık (sRGB, 8 bit kanal).
double _relativeLuminance(Color c) {
  double linear(int shift) {
    final s = _channel(c, shift) / 255;
    return s <= 0.03928
        ? s / 12.92
        : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * linear(16) + 0.7152 * linear(8) + 0.0722 * linear(0);
}

/// WCAG 2.1 kontrast oranı `(L1 + 0.05) / (L2 + 0.05)`; renkler opak olmalı.
double _contrast(Color a, Color b) {
  expect(_isOpaque(a) && _isOpaque(b), isTrue, reason: 'kontrast opak renkle');
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// CSS `rgba(r,g,b,a)` → kanallar + ondalık alfa (CSS'teki tam değer).
({int r, int g, int b, double a}) _rgba(String literal) {
  final m = RegExp(
    r'^rgba\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*([\d.]+)\s*\)$',
  ).firstMatch(literal.trim());
  expect(m, isNotNull, reason: 'rgba değil: $literal');
  return (
    r: int.parse(m!.group(1)!),
    g: int.parse(m.group(2)!),
    b: int.parse(m.group(3)!),
    a: double.parse(m.group(4)!),
  );
}

/// `top` (CSS alfası) ∘ opak `bottom`, kanal başına 8 bite yuvarlanır
/// (token-map §10 yöntemi: `#384354`, `#E1E1DE`).
Color _composite(({int r, int g, int b, double a}) top, Color bottom) {
  int mix(int t, int shift) =>
      (t * top.a + _channel(bottom, shift) * (1 - top.a)).round();
  return Color.fromARGB(
    0xFF,
    mix(top.r, 16),
    mix(top.g, 8),
    mix(top.b, 0),
  );
}

String _capture(String source, String pattern, {bool multiLine = false}) {
  final m = RegExp(pattern, multiLine: multiLine).firstMatch(source);
  expect(m, isNotNull, reason: 'kaynakta bulunamadı: $pattern');
  return m!.group(1)!;
}

String _key(String fg, String bg, _Theme theme) => '$fg / $bg · ${theme.label}';

void _pairGroup({
  required String name,
  required List<_Pair> pairs,
  required double threshold,
  required List<_Known> known,
}) {
  group(name, () {
    final knownByKey = {for (final k in known) _key(k.fg, k.bg, k.theme): k};

    test('bilinen kusur listesi: tekrarsız ve yalnızca tablodaki çiftler', () {
      expect(knownByKey.length, known.length, reason: 'tekrarlı kayıt');
      final tableKeys = {
        for (final p in pairs)
          for (final t in _Theme.values) _key(p.fg, p.bg, t),
      };
      for (final k in knownByKey.keys) {
        expect(tableKeys, contains(k), reason: 'tabloda olmayan kayıt: $k');
      }
    });

    for (final p in pairs) {
      for (final theme in _Theme.values) {
        final documented = theme == _Theme.light ? p.light : p.dark;
        final k = knownByKey[_key(p.fg, p.bg, theme)];
        final verdict = k == null ? '≥ $threshold' : '< $threshold (bilinen)';
        test(
          '${_key(p.fg, p.bg, theme)} = ${documented.toStringAsFixed(2)} $verdict',
          () {
            final ratio = _contrast(
              _color(theme.colors, p.fg),
              _color(theme.colors, p.bg),
            );
            if (k == null) {
              expect(
                ratio,
                greaterThanOrEqualTo(threshold),
                reason: 'liste dışı çift eşik altında (${p.usage})',
              );
            } else {
              expect(
                ratio,
                lessThan(threshold),
                reason: 'listedeki çift eşiği geçti → listeden çıkar',
              );
              expect(ratio, closeTo(k.ratio, _tolerance));
            }
            expect(
              ratio,
              closeTo(documented, _tolerance),
              reason: 'token-map §10 değeri (${p.usage})',
            );
          },
        );
      }
    }
  });
}

void main() {
  group('T-01 · Kontrast · WCAG bağıl parlaklık fonksiyonu', () {
    test('beyaz/siyah 21:1, aynı renk 1:1, simetrik', () {
      const white = Color(0xFFFFFFFF);
      const black = Color(0xFF000000);
      expect(_contrast(white, black), closeTo(21, 1e-9));
      expect(_contrast(black, white), closeTo(21, 1e-9));
      expect(_contrast(white, white), 1);
      expect(_relativeLuminance(white), closeTo(1, 1e-9));
      expect(_relativeLuminance(black), 0);
    });

    test('WCAG referansı: #777777 on #FFFFFF ≈ 4.48', () {
      expect(
        _contrast(const Color(0xFF777777), const Color(0xFFFFFFFF)),
        closeTo(4.48, _tolerance),
      );
    });
  });

  group('T-01 · Kontrast · liste boyutları (CD-22 → CD-100, CD-110)', () {
    test('expectedContrastFailures = 4 çift', () {
      expect(_expectedContrastFailures.length, 4);
    });

    test('expectedNonTextContrastFailures = 11 kayıt (10 çift; switch rayı '
        'açık + koyu)', () {
      expect(_expectedNonTextContrastFailures.length, 11);
      final pairs = {
        for (final k in _expectedNonTextContrastFailures) '${k.fg}/${k.bg}',
      };
      expect(pairs, {
        'stateSuccess/textHeading',
        'stateDanger/textHeading',
        'stateInfo/textHeading',
        'brandPrimary/bgSurface',
        'brandPrimary/bgSurfaceMuted',
        'brandPrimary/bgSurfaceRaised',
        'borderDefault/bgSurface',
      });
    });
  });

  _pairGroup(
    name: 'T-01 · Kontrast · §10.1 metin çiftleri (eşik 4.5)',
    pairs: _textPairs,
    threshold: _textThreshold,
    known: _expectedContrastFailures,
  );

  group('T-01 · Kontrast · §10.1 textDisabled muaf (WCAG 1.4.3 inactive)', () {
    for (final p in _exemptPairs) {
      for (final theme in _Theme.values) {
        final documented = theme == _Theme.light ? p.light : p.dark;
        test(
          '${_key(p.fg, p.bg, theme)} = ${documented.toStringAsFixed(2)} (eşik uygulanmaz)',
          () {
            final ratio = _contrast(
              _color(theme.colors, p.fg),
              _color(theme.colors, p.bg),
            );
            expect(ratio, closeTo(documented, _tolerance));
          },
        );
      }
    }
  });

  _pairGroup(
    name: 'T-01 · Kontrast · §10.2 metin dışı nonTextPairs (eşik 3.0)',
    pairs: _nonTextPairs,
    threshold: _nonTextThreshold,
    known: _expectedNonTextContrastFailures,
  );

  group('T-01 · Kontrast · §10.1 illüstrasyon tabanı (grafik, eşik 3.0)', () {
    // Varlık SVG'lerinde sabit `#62748E` = `GuColors.light.textMuted` (K-20).
    for (final (theme, documented) in [
      (_Theme.light, 4.52),
      (_Theme.dark, 3.70),
    ]) {
      test(
        '#62748E / bgCanvas · ${theme.label} = ${documented.toStringAsFixed(2)} ≥ 3.0',
        () {
          final ratio = _contrast(
            GuColors.light.textMuted,
            theme.colors.bgCanvas,
          );
          expect(ratio, greaterThanOrEqualTo(_nonTextThreshold));
          expect(ratio, closeTo(documented, _tolerance));
        },
      );
    }
  });

  group('T-01 · Kontrast · §10.3 toast eylem metni (K-41, CD-98)', () {
    late String css;
    setUpAll(() => css = componentCss());

    String actionBackground(_Theme theme) => theme == _Theme.light
        ? _capture(
            css,
            r'^\.toast \.toast-action\{[^}]*background:(rgba\([^)]*\))',
            multiLine: true,
          )
        : _capture(
            css,
            r'\.gu-root\[data-theme="dark"\] \.toast \.toast-action\{[^}]*background:(rgba\([^)]*\))',
          );

    test('toast zemini textHeading (css:290)', () {
      expect(
        _capture(
          css,
          r'^\.toast\{[^}]*background:(var\([^)]*\))',
          multiLine: true,
        ),
        'var(--text-heading)',
      );
    });

    for (final (theme, documentedBg, documented) in [
      (_Theme.light, '#384354', 10.0),
      (_Theme.dark, '#E1E1DE', 12.45),
    ]) {
      test('${theme.label}: toastActionForeground on (textHeading ∘ CSS '
          'aksiyon zemini = $documentedBg) = $documented ≥ 4.5', () {
        final bg = _composite(
          _rgba(actionBackground(theme)),
          theme.colors.textHeading,
        );
        expect(bg.toARGB32(), parseCssColor(documentedBg));
        final ratio = _contrast(theme.component.toastActionForeground, bg);
        expect(ratio, greaterThanOrEqualTo(_textThreshold));
        expect(ratio, closeTo(documented, _tolerance));
      });

      test('${theme.label}: Dart token alfasıyla (Color.alphaBlend) ≥ 4.5', () {
        final bg = Color.alphaBlend(
          theme.component.toastActionBackground,
          theme.colors.textHeading,
        );
        expect(
          _contrast(theme.component.toastActionForeground, bg),
          greaterThanOrEqualTo(_textThreshold),
        );
      });
    }

    test('kanıt: CSS koyu değeri var(--text-heading) = 1.2 (okunamaz)', () {
      final bg = _composite(
        _rgba(actionBackground(_Theme.dark)),
        GuColors.dark.textHeading,
      );
      final ratio = _contrast(GuColors.dark.textHeading, bg);
      expect(ratio, lessThan(_textThreshold));
      expect(ratio, closeTo(1.2, _tolerance));
    });
  });

  group('T-01 · Kontrast · §10.2 kayıt satırları (avatar, on-cover)', () {
    test('avatar baş harfleri #FFF on hsl(h 48% 42%): en düşük 2.80 '
        '(ton 0–359°; büyük metin sınırda, listeye girmez — kayıt)', () {
      var minRatio = double.infinity;
      for (var h = 0; h < 360; h++) {
        final bg = HSLColor.fromAHSL(
          1,
          h.toDouble(),
          GuComponentColors.avatarSaturation1,
          GuComponentColors.avatarLightness1,
        ).toColor();
        minRatio = math.min(
          minRatio,
          _contrast(GuComponentColors.light.avatarInitials, bg),
        );
      }
      expect(minRatio, closeTo(2.80, _tolerance));
    });

    test('on-cover ikon #FFF on rgba(0,0,0,.28) ∘ kapak durakları: '
        '3.23 – 17.76 ≥ 3.0', () {
      final art = prototypeJs('art.js');
      final stops = [
        for (final m in RegExp(
          r"stops: \['(#[0-9A-Fa-f]{6})', '(#[0-9A-Fa-f]{6})', '(#[0-9A-Fa-f]{6})'\]",
        ).allMatches(art))
          for (final i in [1, 2, 3]) Color(parseCssColor(m.group(i)!)),
      ];
      expect(stops.length, 9, reason: 'art.js:5–7 üç palet × 3 durak');
      final scrim = _rgba(
        _capture(
          componentCss(),
          r'\.iconbtn\.on-cover\{[^}]*background:(rgba\([^)]*\))',
        ),
      );
      const fg = GuComponentColors.light;
      final ratios = [
        for (final s in stops)
          _contrast(fg.onCoverForeground, _composite(scrim, s)),
      ];
      expect(ratios.reduce(math.min), closeTo(3.23, _tolerance));
      expect(ratios.reduce(math.max), closeTo(17.76, _tolerance));
      expect(ratios.reduce(math.min), greaterThanOrEqualTo(_nonTextThreshold));
      // Dart token alfası (0x47) ile de eşik geçilir.
      for (final s in stops) {
        expect(
          _contrast(
            fg.onCoverForeground,
            Color.alphaBlend(fg.onCoverScrim, s),
          ),
          greaterThanOrEqualTo(_nonTextThreshold),
        );
      }
    });
  });
}
