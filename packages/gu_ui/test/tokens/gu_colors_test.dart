// T-01 · GuColors — token-map §1 / §12. Beklentiler tasarım kaynaklarından
// OKUNUR (registry.json, colors/tokens.json, component-css.css); sabit
// beklenti yalnızca `brightness` için.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/src/tokens/gu_colors.dart';

import '../helpers/design_sources.dart';
import '../helpers/theme_extension_sentinel.dart';

/// `GuColors` alanları, tablo sırasıyla (token-map §1). Alan adları
/// registry adından `grup.ad` → `grupAd` kuralıyla türetilir (§1).
Map<String, Color> _fields(GuColors c) => {
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

/// `brightness` + 27 renk alanı (nöbetçi testleri için `copyWith` adları).
Map<String, Object?> _allFields(GuColors c) => {
  'brightness': c.brightness,
  ..._fields(c),
};

/// `brand.primaryText` → `brandPrimaryText` (design-contract §4).
String _fieldName(String registryKey) => registryKey.replaceAllMapped(
  RegExp(r'\.([a-z])'),
  (m) => m.group(1)!.toUpperCase(),
);

/// `brand.primaryText` → `--brand-primary-text` (css:3–30, css:46–73).
String _cssVar(String registryKey) =>
    '--${registryKey.replaceAll('.', '-').replaceAllMapped(RegExp('[A-Z]'), (m) => '-${m.group(0)!.toLowerCase()}')}';

/// `.gu-root[data-theme="<theme>"] { … }` değişken bloğu.
String _cssThemeBlock(String css, String theme) {
  final m = RegExp(
    '\\.gu-root\\[data-theme="$theme"\\] \\{([^}]*)\\}',
  ).firstMatch(css);
  expect(m, isNotNull, reason: 'CSS $theme değişken bloğu bulunamadı');
  return m!.group(1)!;
}

void main() {
  late Map<String, dynamic> regColors;
  late Map<String, dynamic> regUsage;
  late Map<String, dynamic> tjColors;
  late String css;

  setUpAll(() {
    final tokens = registryTokens();
    regColors = tokens['COLORS'] as Map<String, dynamic>;
    regUsage = tokens['COLOR_USAGE'] as Map<String, dynamic>;
    tjColors = tokensJson()['colors'] as Map<String, dynamic>;
    css = componentCss();
  });

  (String, String) regPair(String key) {
    final pair = regColors[key] as List<dynamic>;
    return (pair[0] as String, pair[1] as String);
  }

  group('T-01 · GuColors · kaynaklar', () {
    test('registry COLORS 27 anahtar; COLOR_USAGE aynı 27 anahtar', () {
      expect(regColors.length, 27);
      expect(regUsage.keys.toSet(), regColors.keys.toSet());
    });

    test('colors/tokens.json = registry (light, dark, usage)', () {
      expect(tjColors.keys.toSet(), regColors.keys.toSet());
      for (final key in regColors.keys) {
        final tj = tjColors[key] as Map<String, dynamic>;
        final (light, dark) = regPair(key);
        expect(tj['light'], light, reason: '$key light');
        expect(tj['dark'], dark, reason: '$key dark');
        expect(tj['usage'], regUsage[key], reason: '$key usage');
      }
    });
  });

  group('T-01 · GuColors · değerler', () {
    test('alan adları = registry adları (grup.ad → grupAd), 27 alan', () {
      expect(
        _fields(GuColors.light).keys.toSet(),
        regColors.keys.map(_fieldName).toSet(),
      );
      expect(_fields(GuColors.light).length, 27);
    });

    for (final (label, theme, index) in [
      ('açık', GuColors.light, 0),
      ('koyu', GuColors.dark, 1),
    ]) {
      test('$label: 27 alan ARGB == registry hex/rgba', () {
        final fields = _fields(theme);
        for (final key in regColors.keys) {
          final (light, dark) = regPair(key);
          final expected = parseCssColor(index == 0 ? light : dark);
          expect(
            fields[_fieldName(key)]!.toARGB32(),
            expected,
            reason: '$key ($label)',
          );
        }
      });

      test('$label: 27 alan ARGB == CSS değişkeni (component-css.css)', () {
        final block = _cssThemeBlock(css, index == 0 ? 'light' : 'dark');
        final fields = _fields(theme);
        for (final key in regColors.keys) {
          final m = RegExp(
            '${RegExp.escape(_cssVar(key))}:\\s*([^;]+);',
          ).firstMatch(block);
          expect(m, isNotNull, reason: '${_cssVar(key)} ($label) yok');
          expect(
            fields[_fieldName(key)]!.toARGB32(),
            parseCssColor(m!.group(1)!),
            reason: '${_cssVar(key)} ($label)',
          );
        }
      });
    }

    test('overlayScrim alfa: .48 → 0x7A, .60 → 0x99 (round(a × 255))', () {
      expect(GuColors.light.overlayScrim.toARGB32() >>> 24, 0x7A);
      expect(GuColors.dark.overlayScrim.toARGB32() >>> 24, 0x99);
    });

    test('brightness: light → Brightness.light, dark → Brightness.dark', () {
      expect(GuColors.light.brightness, Brightness.light);
      expect(GuColors.dark.brightness, Brightness.dark);
    });
  });

  group('T-01 · GuColors · props / eşitlik', () {
    test('props.length == 27, alan sırasıyla', () {
      for (final c in [GuColors.light, GuColors.dark]) {
        expect(c.props.length, 27);
        expect(c.props, _fields(c).values.toList());
      }
    });

    test('== ve hashCode değer eşitliği; brightness farkı eşit değil', () {
      final copy = GuColors.light.copyWith();
      expect(identical(copy, GuColors.light), isFalse);
      expect(copy, GuColors.light);
      expect(copy.hashCode, GuColors.light.hashCode);
      expect(GuColors.light, isNot(GuColors.dark));
      expect(
        GuColors.light.copyWith(brightness: Brightness.dark),
        isNot(GuColors.light),
      );
    });
  });

  registerSentinelTests<GuColors>(
    name: 'GuColors',
    original: GuColors.light,
    fields: _allFields,
    sentinel: (field, i, salt) => field == 'brightness'
        ? (salt == 0 ? Brightness.dark : Brightness.light)
        : Color(0xFF000001 + i + salt * 0x100),
    lerpField: (field, a, b, t) => field == 'brightness'
        ? (t < 0.5 ? a : b)
        : Color.lerp(a as Color?, b as Color?, t),
  );

  group('T-01 · GuColors · lerp (gerçek temalar)', () {
    test('lerp(dark, 0) == light; lerp(dark, 1) == dark', () {
      expect(GuColors.light.lerp(GuColors.dark, 0), GuColors.light);
      expect(GuColors.light.lerp(GuColors.dark, 1), GuColors.dark);
    });

    test('brightness t < 0.5 → bu, t ≥ 0.5 → other', () {
      expect(
        GuColors.light.lerp(GuColors.dark, 0.49).brightness,
        Brightness.light,
      );
      expect(
        GuColors.light.lerp(GuColors.dark, 0.5).brightness,
        Brightness.dark,
      );
    });
  });
}
