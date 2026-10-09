// T-01 · GuComponentColors — token-map §2 / §12. Değerler component-css.css
// ve prototip JS literallerinden OKUNUR; sabit beklenti yalnızca koyu
// `toastActionForeground` (CD-98, K-41).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/src/tokens/gu_colors.dart';
import 'package:gu_ui/src/tokens/gu_component_colors.dart';

import '../helpers/design_sources.dart';
import '../helpers/theme_extension_sentinel.dart';

/// 18 alan, token-map §2 sırasıyla.
Map<String, Color> _fields(GuComponentColors c) => {
  'chipBorder': c.chipBorder,
  'onCoverScrim': c.onCoverScrim,
  'onCoverScrimPressed': c.onCoverScrimPressed,
  'onCoverForeground': c.onCoverForeground,
  'toastActionBackground': c.toastActionBackground,
  'toastActionForeground': c.toastActionForeground,
  'scanViewGradientStart': c.scanViewGradientStart,
  'scanViewGradientEnd': c.scanViewGradientEnd,
  'scanBoxCorner': c.scanBoxCorner,
  'viewerBackground': c.viewerBackground,
  'qrBackground': c.qrBackground,
  'avatarInitials': c.avatarInitials,
  'coverInk': c.coverInk,
  'scanMutedForeground': c.scanMutedForeground,
  'scanPanelScrim': c.scanPanelScrim,
  'scanOutlineBorder': c.scanOutlineBorder,
  'viewerHintForeground': c.viewerHintForeground,
  'qrModule': c.qrModule,
};

/// Koyu = açık olan alanlar (§2 "aynı"; #1, #5, #6 hariç).
const _sameInBothThemes = [
  'onCoverScrim',
  'onCoverScrimPressed',
  'onCoverForeground',
  'scanViewGradientStart',
  'scanViewGradientEnd',
  'scanBoxCorner',
  'viewerBackground',
  'qrBackground',
  'avatarInitials',
  'coverInk',
  'scanMutedForeground',
  'scanPanelScrim',
  'scanOutlineBorder',
  'viewerHintForeground',
  'qrModule',
];

/// `source` içinde `pattern`'in ilk eşleşmesinin 1. grubu (yoksa test kırmızı).
String _capture(String source, String pattern, {bool multiLine = false}) {
  final m = RegExp(pattern, multiLine: multiLine).firstMatch(source);
  expect(m, isNotNull, reason: 'kaynakta bulunamadı: $pattern');
  return m!.group(1)!;
}

/// 1 tabanlı satır numarası (token-map'teki `dosya:N`).
String _line(String source, int lineNo) => source.split('\n')[lineNo - 1];

void main() {
  late String css;
  late String art;
  late String manage;
  late String sheets;
  late Map<String, dynamic> regColors;

  setUpAll(() {
    css = componentCss();
    art = prototypeJs('art.js');
    manage = prototypeJs('screens-manage.js');
    sheets = prototypeJs('sheets.js');
    regColors = registryTokens()['COLORS'] as Map<String, dynamic>;
  });

  const light = GuComponentColors.light;
  const dark = GuComponentColors.dark;

  void expectBoth(Color Function(GuComponentColors c) field, int expected) {
    expect(field(light).toARGB32(), expected, reason: 'açık');
    expect(field(dark).toARGB32(), expected, reason: 'koyu');
  }

  group('T-01 · GuComponentColors · yapı', () {
    test('18 alan (CD-87); props sırası = token-map §2', () {
      for (final c in [light, dark]) {
        expect(c.props.length, 18);
        expect(c.props, _fields(c).values.toList());
      }
    });

    test('§2 "aynı" alanlar açık = koyu (15 alan)', () {
      final l = _fields(light);
      final d = _fields(dark);
      for (final name in _sameInBothThemes) {
        expect(d[name], l[name], reason: name);
      }
      expect(_sameInBothThemes.toSet().length, 15);
    });
  });

  group('T-01 · GuComponentColors · CSS-derived (§2 #1–13)', () {
    test('#1 chipBorder: açık var(--border-default) css:176, koyu css:177', () {
      final lightRule = _capture(
        css,
        r'^\.chip\{([^}]*)\}',
        multiLine: true,
      );
      expect(lightRule, contains('border:1px solid var(--border-default)'));
      final borderDefault = (regColors['border.default'] as List<dynamic>)[0];
      expect(
        light.chipBorder.toARGB32(),
        parseCssColor(borderDefault as String),
      );
      expect(light.chipBorder, GuColors.light.borderDefault);
      final darkValue = _capture(
        css,
        r'\.gu-root\[data-theme="dark"\] \.chip\{[^}]*border-color:(#[0-9A-Fa-f]{3,6})',
      );
      expect(dark.chipBorder.toARGB32(), parseCssColor(darkValue));
    });

    test('#2 onCoverScrim: .iconbtn.on-cover background (css:155)', () {
      expectBoth(
        (c) => c.onCoverScrim,
        parseCssColor(
          _capture(
            css,
            r'\.iconbtn\.on-cover\{[^}]*background:(rgba\([^)]*\))',
          ),
        ),
      );
    });

    test('#3 onCoverScrimPressed: .iconbtn.on-cover:hover (css:155)', () {
      expectBoth(
        (c) => c.onCoverScrimPressed,
        parseCssColor(
          _capture(
            css,
            r'\.iconbtn\.on-cover:hover\{[^}]*background:(rgba\([^)]*\))',
          ),
        ),
      );
    });

    test('#4 onCoverForeground: on-cover / scan-view / viewer color', () {
      final sources = [
        _capture(css, r'\.iconbtn\.on-cover\{(?:[^}]*;)?color:(#[0-9a-fA-F]+)'),
        _capture(
          css,
          r'\.statusbar\.on-dark\{(?:[^}]*;)?color:(#[0-9a-fA-F]+)',
        ),
        _capture(css, r'\.scan-view\{(?:[^}]*;)?color:(#[0-9a-fA-F]+)'),
        _capture(css, r'\.viewer\{(?:[^}]*;)?color:(#[0-9a-fA-F]+)'),
      ];
      for (final s in sources) {
        expectBoth((c) => c.onCoverForeground, parseCssColor(s));
      }
    });

    test('#5 toastActionBackground: açık css:293, koyu css:294', () {
      final l = _capture(
        css,
        r'^\.toast \.toast-action\{[^}]*background:(rgba\([^)]*\))',
        multiLine: true,
      );
      final d = _capture(
        css,
        r'\.gu-root\[data-theme="dark"\] \.toast \.toast-action\{[^}]*background:(rgba\([^)]*\))',
      );
      expect(light.toastActionBackground.toARGB32(), parseCssColor(l));
      expect(dark.toastActionBackground.toARGB32(), parseCssColor(d));
    });

    test('#6 toastActionForeground: açık css:293 #fff; koyu CD-98 '
        '0xFF1E2024 (CSS var(--text-heading) yerine)', () {
      final l = _capture(
        css,
        r'^\.toast \.toast-action\{(?:[^}]*;)?color:(#[0-9a-fA-F]+)',
        multiLine: true,
      );
      expect(light.toastActionForeground.toARGB32(), parseCssColor(l));
      // Koyu CSS kuralı hâlâ var(--text-heading) → sapma bilinçli (K-41).
      final darkCss = _capture(
        css,
        r'\.gu-root\[data-theme="dark"\] \.toast \.toast-action\{color:([^;]+);',
      );
      expect(darkCss, 'var(--text-heading)');
      expect(dark.toastActionForeground.toARGB32(), 0xFF1E2024);
      expect(dark.toastActionForeground, GuColors.dark.bgSurface);
      expect(dark.toastActionForeground, isNot(GuColors.dark.textHeading));
    });

    test('#7–8 scanViewGradientStart/End: radial-gradient css:401', () {
      final m = RegExp(
        r'\.scan-view\{[^}]*radial-gradient\(ellipse at 50% 40%,(#[0-9a-fA-F]{6}),(#[0-9a-fA-F]{6}) 75%\)',
      ).firstMatch(css);
      expect(m, isNotNull);
      expectBoth((c) => c.scanViewGradientStart, parseCssColor(m!.group(1)!));
      expectBoth((c) => c.scanViewGradientEnd, parseCssColor(m.group(2)!));
    });

    test('#9 scanBoxCorner: .scan-box>i border css:403', () {
      expectBoth(
        (c) => c.scanBoxCorner,
        parseCssColor(
          _capture(css, r'\.scan-box>i\{[^}]*border:3px solid (#[0-9a-fA-F]+)'),
        ),
      );
    });

    test('#10 viewerBackground: .viewer background css:409', () {
      expectBoth(
        (c) => c.viewerBackground,
        parseCssColor(
          _capture(css, r'\.viewer\{[^}]*background:(#[0-9a-fA-F]+)'),
        ),
      );
    });

    test('#11 qrBackground: .qr background css:326 + art.js:102 rect', () {
      expectBoth(
        (c) => c.qrBackground,
        parseCssColor(_capture(css, r'\.qr\{[^}]*background:(#[0-9a-fA-F]+)')),
      );
      expectBoth(
        (c) => c.qrBackground,
        parseCssColor(
          _capture(
            _line(art, 102),
            r'<rect width="\$\{n\}" height="\$\{n\}" fill="(#[0-9a-fA-F]+)"/>',
          ),
        ),
      );
    });

    test('#12 avatarInitials: .avatar color css:217 + art.js:42 text', () {
      expectBoth(
        (c) => c.avatarInitials,
        parseCssColor(
          _capture(css, r'\.avatar\{(?:[^}]*;)?color:(#[0-9a-fA-F]+)'),
        ),
      );
      expectBoth(
        (c) => c.avatarInitials,
        parseCssColor(
          _capture(
            _line(art, 42),
            'font-size="38" fill="(#[0-9a-fA-F]+)"',
          ),
        ),
      );
    });

    test('#13 coverInk: art.js:5–7 PALETTES.*.ink (3 palet)', () {
      final inks = [5, 6, 7]
          .map((n) => _capture(_line(art, n), "ink: '(#[0-9A-Fa-f]{6})'"))
          .toList();
      expect(inks.length, 3);
      for (final ink in inks) {
        expectBoth((c) => c.coverInk, parseCssColor(ink));
      }
    });
  });

  group('T-01 · GuComponentColors · JS-derived (§2 #14–18, CD-87)', () {
    test('#14 scanMutedForeground: screens-manage.js:149, :151, :152', () {
      for (final n in [149, 151, 152]) {
        final v = _capture(_line(manage, n), r'style="color:(rgba\([^)]*\))');
        expectBoth((c) => c.scanMutedForeground, parseCssColor(v));
      }
    });

    test('#15 scanPanelScrim: screens-manage.js:153', () {
      expectBoth(
        (c) => c.scanPanelScrim,
        parseCssColor(
          _capture(_line(manage, 153), r'background:(rgba\([^)]*\))'),
        ),
      );
    });

    test('#16 scanOutlineBorder: screens-manage.js:149, :154', () {
      for (final n in [149, 154]) {
        final v = _capture(_line(manage, n), r"borderColor: '(rgba\([^)]*\))'");
        expectBoth((c) => c.scanOutlineBorder, parseCssColor(v));
      }
    });

    test('#17 viewerHintForeground: sheets.js:162 (sht.34.zoomHint)', () {
      final line = _line(sheets, 162);
      expect(line, contains('sht.34.zoomHint'));
      expectBoth(
        (c) => c.viewerHintForeground,
        parseCssColor(_capture(line, r'style="color:(rgba\([^)]*\))')),
      );
    });

    test('#18 qrModule: art.js:102 qrSVG varsayılan rengi', () {
      final v = _capture(
        _line(art, 102),
        r"function qrSVG\(seed, size = 220, color = '(#[0-9A-Fa-f]{6})'\)",
      );
      expectBoth((c) => c.qrModule, parseCssColor(v));
      expect(light.qrModule, GuColors.light.textPrimary);
    });
  });

  group('T-01 · GuComponentColors · avatar HSL sabitleri (art.js:41)', () {
    test('hue kayması, doygunluk ve açıklıklar avatarColors ile aynı', () {
      final line = _line(art, 41);
      expect(line, contains('function avatarColors'));
      final shift = _capture(line, r'hue2 = \(hue \+ (\d+)\) % 360');
      final first = RegExp(r'hsl\(\$\{hue\} (\d+)% (\d+)%\)').firstMatch(line);
      final second = RegExp(
        r'hsl\(\$\{hue2\} (\d+)% (\d+)%\)',
      ).firstMatch(line);
      expect(first, isNotNull);
      expect(second, isNotNull);
      expect(GuComponentColors.avatarHueShift, int.parse(shift));
      expect(
        GuComponentColors.avatarSaturation1,
        int.parse(first!.group(1)!) / 100,
      );
      expect(
        GuComponentColors.avatarLightness1,
        int.parse(first.group(2)!) / 100,
      );
      expect(
        GuComponentColors.avatarSaturation2,
        int.parse(second!.group(1)!) / 100,
      );
      expect(
        GuComponentColors.avatarLightness2,
        int.parse(second.group(2)!) / 100,
      );
    });
  });

  group('T-01 · GuComponentColors · eşitlik (Equatable)', () {
    test('copyWith(): eşit, özdeş değil; == ve hashCode; light != dark', () {
      final copy = light.copyWith();
      expect(identical(copy, light), isFalse);
      expect(copy, light);
      expect(copy.hashCode, light.hashCode);
      expect(light, isNot(dark));
    });

    test('lerp(dark, 0) == light; lerp(dark, 1) == dark', () {
      expect(light.lerp(dark, 0), light);
      expect(light.lerp(dark, 1), dark);
    });
  });

  registerSentinelTests<GuComponentColors>(
    name: 'GuComponentColors',
    original: light,
    fields: _fields,
    sentinel: (field, i, salt) => Color(0xFF000001 + i + salt * 0x100),
    lerpField: (field, a, b, t) => Color.lerp(a as Color?, b as Color?, t),
  );
}
