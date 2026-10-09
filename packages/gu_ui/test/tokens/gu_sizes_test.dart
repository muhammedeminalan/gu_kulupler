// T-01 · GuSizes / GuOpacity token testi (token-map §8; CD-97; design-contract L1).
//
// Her §8 satırı tabloda bir kayıttır: (açıklama, beklenen, gerçek).
// * CSS-derived: beklenen `CssMeasure` ile `component-css.css`'ten OKUNUR;
//   ayrıca token-map'teki `css:N` satırı ayrıştırıcının bulduğu satırla eşlenir.
// * JS-derived: beklenen sabittir (token-map §8 kuralı); kaynak parçası
//   belirtilen `dosya:satır`da aranır. Liste sabitleri ve ikon boyutları
//   prototip çağrılarından hesaplanır.
// * Platform-derived: sabit beklenti (D-22, K-03; CD-97).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/src/tokens/gu_opacity.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';

import '../helpers/css_measure.dart';
import '../helpers/design_sources.dart';

/// Nihai `GuSizes` sayısı (CD-97 formülü, token-map §8 sayım paragrafı):
/// PLAN §7.7.1–§7.7.6 ölçüleri 353 − `miniChartFillOpacity` (token-map §8.5:
/// `GuOpacity.miniChartFill`'e taşındı) = 352; + F-L ek 26 + Platform-derived 2
/// + K-46 JS-derived 10 (8 + `viewerZoomScale`, `applicationLeaveOffsetX`)
/// + K-47 `avatarGroupSizes` 1 + §8.7 ikon 11 = 402. (token-map'teki "aday
/// 401", `miniChartFillOpacity`'yi hâlâ 353'ün içinde sayar ve 2 K-46 ekini
/// içermez.)
const int _gusizesCount = 402;

/// `GuOpacity`: §8.8 8 + `coverIcon` 1.
const int _guOpacityCount = 9;

/// Prototip bileşen dosyaları (bundle, pages-*, core, i18n hariç).
const List<String> _uiFiles = prototypeAppFiles;

/// Yalnızca ekran dosyaları (`Logo` kabuk çağrıları hariç, CD-90).
const List<String> _screenFiles = [
  'screens-admin.js',
  'screens-auth.js',
  'screens-clubs.js',
  'screens-events.js',
  'screens-manage.js',
  'screens-profile.js',
];

/// `emblemIconSizes` kanıtları (token-map §8.5).
const List<_JsRef> _emblemIconRefs = [
  _JsRef(
    'screens-profile.js',
    11,
    r'''<${Icon} name="camera" size=${14} />''',
  ),
  _JsRef(
    'screens-profile.js',
    28,
    r'''<${Icon} name="camera" size=${14} />''',
  ),
  _JsRef(
    'cards.js',
    31,
    r'background:var(--bg-surface)"><${Icon} name=${club.iconName} size=${16} />',
  ),
  _JsRef(
    'sheets.js',
    88,
    r'<span class="emblem is-sm"><${Icon} name=${m.club.iconName} size=${20} />',
  ),
  _JsRef(
    'cards.js',
    36,
    r'<span class="emblem is-sm"><${Icon} name=${club.iconName} size=${22} />',
  ),
];

final class _CssRef {
  const _CssRef(this.line, this.selector, this.prop);

  final int line;
  final String selector;
  final String prop;
}

final class _JsRef {
  const _JsRef(this.file, this.line, this.snippet);

  final String file;
  final int line;
  final String snippet;

  String get label => '$file:$line';
}

/// Tablo kaydı: (açıklama, beklenen, gerçek) + kaynak kanıtı.
final class _Row {
  const _Row({
    required this.name,
    required this.source,
    required this.expected,
    required this.actual,
    this.css,
    this.js = const [],
  });

  final String name;
  final String source;

  /// Testin içinde değerlendirilir; kaynak okunamazsa yalnızca o kayıt düşer.
  final Object Function() expected;
  final Object actual;
  final _CssRef? css;
  final List<_JsRef> js;

  String get description => '$name · $source';
}

_Row _css(
  String name,
  Object actual,
  Object Function() expected,
  int line,
  String selector,
  String prop,
) => _Row(
  name: name,
  source: 'css:$line $selector $prop',
  expected: expected,
  actual: actual,
  css: _CssRef(line, selector, prop),
);

_Row _js(String name, Object actual, Object expected, List<_JsRef> refs) =>
    _Row(
      name: name,
      source: 'JS ${refs.map((r) => r.label).join(', ')}',
      expected: () => expected,
      actual: actual,
      js: refs,
    );

_Row _jsList(
  String name,
  List<double> actual,
  List<double> Function() expected,
  String source,
) => _Row(name: name, source: 'JS $source', expected: expected, actual: actual);

_Row _icon(String name, double actual, double size, _Js js) => _Row(
  name: name,
  source: 'JS prototip Icon size= kümesi',
  expected: () => js.iconSizes().contains(size)
      ? size
      : 'prototip Icon size= kümesinde yok: $size',
  actual: actual,
);

_Row _platform(String name, double actual, double expected, String source) =>
    _Row(
      name: name,
      source: 'Platform $source',
      expected: () => expected,
      actual: actual,
    );

/// `translateY(calc(var(--py,0) * .4px))` → 0.4.
double _calcFactor(String calc) {
  final m = RegExp(r'\*\s*(\d*\.?\d+)px').firstMatch(calc);
  if (m == null) throw FormatException('calc içinde çarpan yok: $calc');
  return double.parse(m.group(1)!);
}

Matcher _matches(Object expected) {
  if (expected is num) return closeTo(expected, 1e-9);
  if (expected is List<double>) {
    return pairwiseCompare<double, double>(
      expected,
      (e, a) => (e - a).abs() < 1e-9,
      'yaklaşık eşit',
    );
  }
  return equals(expected);
}

/// Kaynak dosyadaki `static const <tip> <ad> =` adları (her tip; sıra
/// korunur). Tüm `static const ` bildirimlerinin sayıldığı ayrıca doğrulanır.
List<String> _declaredConstants(String path) {
  final source = File(path).readAsStringSync();
  final names = RegExp(
    r'static const \S+ (\w+)\s*=',
  ).allMatches(source).map((m) => m.group(1)!).toList();
  expect(
    names.length,
    'static const '.allMatches(source).length,
    reason: '$path: regex dışında kalan static const bildirimi var',
  );
  return names;
}

/// Prototip JS okuyucusu (önbellekli).
final class _Js {
  final Map<String, String> _files = {};
  List<double>? _icons;

  String source(String file) =>
      _files.putIfAbsent(file, () => prototypeJs(file));

  /// 1 tabanlı satır.
  String line(String file, int line) {
    final lines = source(file).split('\n');
    if (line < 1 || line > lines.length) {
      throw RangeError('$file: $line satırı yok (${lines.length} satır)');
    }
    return lines[line - 1];
  }

  /// `<${Bileşen} … size=${…} />` çağrılarındaki sayısal boyutlar (üçlü
  /// ifadelerin her iki dalı dahil) ∪ `defaults`; sıralı ve tekil.
  List<double> callSizes(
    String component, {
    List<String> files = _uiFiles,
    List<double> defaults = const [],
  }) {
    final call = RegExp(
      [
        r'<\$\{(?:GU\.)?',
        RegExp.escape(component),
        r'\}((?:(?!/>).)*?)/>',
      ].join(),
      dotAll: true,
    );
    final sizeExpr = RegExp(r'size=\$\{([^}]*)\}');
    final number = RegExp(r'\d+(?:\.\d+)?');
    final out = <double>{...defaults};
    for (final f in files) {
      for (final m in call.allMatches(source(f))) {
        final s = sizeExpr.firstMatch(m.group(1)!);
        if (s == null) continue;
        for (final n in number.allMatches(s.group(1)!)) {
          out.add(double.parse(n.group(0)!));
        }
      }
    }
    return out.toList()..sort();
  }

  /// `Icon size=` kümesi (§8.7).
  List<double> iconSizes() => _icons ??= callSizes('Icon');

  /// Satırdaki `w="N%"` değerleri oran olarak (sırayla).
  List<double> percentsOnLine(String file, int lineNo) => RegExp(r'w="(\d+)%"')
      .allMatches(line(file, lineNo))
      .map((m) => double.parse(m.group(1)!) / 100)
      .toList();

  /// `.emblem.is-xs/.is-sm` içindeki `Icon size=` kullanımları.
  List<({String file, int line, double size})> emblemIconUsages() {
    final re = RegExp(
      r'class="emblem is-(?:xs|sm)"[^>]*><\$\{(?:GU\.)?Icon\} (?:(?!/>).)*?size=\$\{(\d+)\}',
    );
    return [
      for (final f in _uiFiles)
        for (final m in re.allMatches(source(f)))
          (
            file: f,
            line: '\n'.allMatches(source(f).substring(0, m.start)).length + 1,
            size: double.parse(m.group(1)!),
          ),
    ];
  }
}

List<_Row> _sizesTable(CssMeasure css, _Js js) => [
  // §8.1
  _css(
    'appBarMinHeight',
    GuSizes.appBarMinHeight,
    () => css.px('.appbar', 'min-height'),
    127,
    '.appbar',
    'min-height',
  ),
  _css(
    'appBarPaddingY',
    GuSizes.appBarPaddingY,
    () => css.box('.appbar', 'padding')[0],
    127,
    '.appbar',
    'padding',
  ),
  _css(
    'appBarPaddingX',
    GuSizes.appBarPaddingX,
    () => css.box('.appbar', 'padding')[1],
    127,
    '.appbar',
    'padding',
  ),
  _css(
    'appBarGap',
    GuSizes.appBarGap,
    () => css.px('.appbar', 'gap'),
    127,
    '.appbar',
    'gap',
  ),
  _css(
    'appBarTitlePaddingX',
    GuSizes.appBarTitlePaddingX,
    () => css.box('.appbar-title', 'padding')[1],
    129,
    '.appbar-title',
    'padding',
  ),
  _css(
    'appBarLargePaddingTop',
    GuSizes.appBarLargePaddingTop,
    () => css.box('.appbar-large', 'padding')[0],
    130,
    '.appbar-large',
    'padding',
  ),
  _css(
    'appBarLargePaddingX',
    GuSizes.appBarLargePaddingX,
    () => css.box('.appbar-large', 'padding')[1],
    130,
    '.appbar-large',
    'padding',
  ),
  _css(
    'appBarLargePaddingBottom',
    GuSizes.appBarLargePaddingBottom,
    () => css.box('.appbar-large', 'padding')[2],
    130,
    '.appbar-large',
    'padding',
  ),
  _css(
    'appBarBorder',
    GuSizes.appBarBorder,
    () => css.box('.appbar.is-surface', 'border-bottom')[0],
    128,
    '.appbar.is-surface',
    'border-bottom',
  ),
  _css(
    'bottomNavHeight',
    GuSizes.bottomNavHeight,
    () => css.px('.bottomnav>button', 'min-height'),
    134,
    '.bottomnav>button',
    'min-height',
  ),
  _css(
    'bottomNavGap',
    GuSizes.bottomNavGap,
    () => css.px('.bottomnav>button', 'gap'),
    134,
    '.bottomnav>button',
    'gap',
  ),
  _js('bottomNavIcon', GuSizes.bottomNavIcon, 24, const [
    _JsRef('shell.js', 12, r'name=${icons[tb]} size=${24}'),
  ]),
  _css(
    'bottomNavBorder',
    GuSizes.bottomNavBorder,
    () => css.box('.bottomnav', 'border-top')[0],
    133,
    '.bottomnav',
    'border-top',
  ),
  _css(
    'bottomNavIndicatorWidth',
    GuSizes.bottomNavIndicatorWidth,
    () => css.px('.bottomnav>button[aria-current="page"]::before', 'width'),
    136,
    '.bottomnav>button[aria-current="page"]::before',
    'width',
  ),
  _css(
    'bottomNavIndicatorHeight',
    GuSizes.bottomNavIndicatorHeight,
    () => css.px('.bottomnav>button[aria-current="page"]::before', 'height'),
    136,
    '.bottomnav>button[aria-current="page"]::before',
    'height',
  ),
  _css(
    'navBadgeMinWidth',
    GuSizes.navBadgeMinWidth,
    () => css.px('.nav-badge', 'min-width'),
    137,
    '.nav-badge',
    'min-width',
  ),
  _css(
    'navBadgeHeight',
    GuSizes.navBadgeHeight,
    () => css.px('.nav-badge', 'height'),
    137,
    '.nav-badge',
    'height',
  ),
  _css(
    'navBadgePaddingX',
    GuSizes.navBadgePaddingX,
    () => css.box('.nav-badge', 'padding')[1],
    137,
    '.nav-badge',
    'padding',
  ),
  _css(
    'navBadgeBorder',
    GuSizes.navBadgeBorder,
    () => css.box('.nav-badge', 'border')[0],
    137,
    '.nav-badge',
    'border',
  ),
  _css(
    'navBadgeTop',
    GuSizes.navBadgeTop,
    () => css.px('.nav-badge', 'top'),
    137,
    '.nav-badge',
    'top',
  ),
  _css(
    'navBadgeOffsetX',
    GuSizes.navBadgeOffsetX,
    () => css.px('.nav-badge', 'left'),
    137,
    '.nav-badge',
    'left',
  ),
  _css(
    'ctaBarPaddingY',
    GuSizes.ctaBarPaddingY,
    () => css.box('.ctabar', 'padding')[0],
    296,
    '.ctabar',
    'padding',
  ),
  _css(
    'ctaBarPaddingX',
    GuSizes.ctaBarPaddingX,
    () => css.box('.ctabar', 'padding')[1],
    296,
    '.ctabar',
    'padding',
  ),
  _css(
    'ctaBarGap',
    GuSizes.ctaBarGap,
    () => css.px('.ctabar', 'gap'),
    296,
    '.ctabar',
    'gap',
  ),
  _css(
    'ctaBarBorder',
    GuSizes.ctaBarBorder,
    () => css.box('.ctabar', 'border-top')[0],
    296,
    '.ctabar',
    'border-top',
  ),
  // §8.2
  _css(
    'buttonHeight',
    GuSizes.buttonHeight,
    () => css.px('.btn', 'min-height'),
    139,
    '.btn',
    'min-height',
  ),
  _css(
    'buttonHeightSm',
    GuSizes.buttonHeightSm,
    () => css.px('.btn-sm', 'min-height'),
    141,
    '.btn-sm',
    'min-height',
  ),
  _css(
    'buttonHeightLg',
    GuSizes.buttonHeightLg,
    () => css.px('.btn-lg', 'min-height'),
    141,
    '.btn-lg',
    'min-height',
  ),
  _css(
    'buttonPaddingX',
    GuSizes.buttonPaddingX,
    () => css.box('.btn', 'padding')[1],
    139,
    '.btn',
    'padding',
  ),
  _css(
    'buttonPaddingXSm',
    GuSizes.buttonPaddingXSm,
    () => css.box('.btn-sm', 'padding')[1],
    141,
    '.btn-sm',
    'padding',
  ),
  _css(
    'buttonPaddingXLg',
    GuSizes.buttonPaddingXLg,
    () => css.box('.btn-lg', 'padding')[1],
    141,
    '.btn-lg',
    'padding',
  ),
  _css(
    'buttonGap',
    GuSizes.buttonGap,
    () => css.px('.btn', 'gap'),
    139,
    '.btn',
    'gap',
  ),
  _js('buttonIcon', GuSizes.buttonIcon, 20, const [
    _JsRef('ui.js', 14, r"size=${size === 'sm' ? 18 : 20}"),
  ]),
  _js('buttonIconSm', GuSizes.buttonIconSm, 18, const [
    _JsRef('ui.js', 14, r"size=${size === 'sm' ? 18 : 20}"),
  ]),
  _js('buttonIconTrailing', GuSizes.buttonIconTrailing, 18, const [
    _JsRef('ui.js', 14, r'name=${iconRight} size=${18}'),
  ]),
  _css(
    'buttonBorder',
    GuSizes.buttonBorder,
    () => css.box('.btn-outline', 'border')[0],
    144,
    '.btn-outline',
    'border',
  ),
  _css(
    'textButtonHeight',
    GuSizes.textButtonHeight,
    () => css.px('.btn-text', 'min-height'),
    145,
    '.btn-text',
    'min-height',
  ),
  _css(
    'textButtonPaddingX',
    GuSizes.textButtonPaddingX,
    () => css.box('.btn-text', 'padding')[1],
    145,
    '.btn-text',
    'padding',
  ),
  _css(
    'ghostButtonPaddingX',
    GuSizes.ghostButtonPaddingX,
    () => css.box('.btn-ghost', 'padding')[1],
    148,
    '.btn-ghost',
    'padding',
  ),
  _css(
    'bannerTextButtonHeight',
    GuSizes.bannerTextButtonHeight,
    () => css.px('.banner .btn-text', 'min-height'),
    257,
    '.banner .btn-text',
    'min-height',
  ),
  _css(
    'bannerTextButtonPaddingX',
    GuSizes.bannerTextButtonPaddingX,
    () => css.box('.banner .btn-text', 'padding')[1],
    257,
    '.banner .btn-text',
    'padding',
  ),
  _css(
    'spinner',
    GuSizes.spinner,
    () => css.px('.spinner', 'width'),
    153,
    '.spinner',
    'width',
  ),
  _css(
    'spinnerStroke',
    GuSizes.spinnerStroke,
    () => css.box('.spinner', 'border')[0],
    153,
    '.spinner',
    'border',
  ),
  _css(
    'focusRingWidth',
    GuSizes.focusRingWidth,
    () => css.box('.gu-root :focus-visible', 'outline')[0],
    82,
    '.gu-root :focus-visible',
    'outline',
  ),
  _css(
    'focusRingOffset',
    GuSizes.focusRingOffset,
    () => css.px('.gu-root :focus-visible', 'outline-offset'),
    82,
    '.gu-root :focus-visible',
    'outline-offset',
  ),
  _css(
    'iconButton',
    GuSizes.iconButton,
    () => css.px('.iconbtn', 'width'),
    154,
    '.iconbtn',
    'width',
  ),
  _css(
    'iconButtonSm',
    GuSizes.iconButtonSm,
    () => css.px('.iconbtn.is-sm', 'width'),
    156,
    '.iconbtn.is-sm',
    'width',
  ),
  _js('iconButtonXs', GuSizes.iconButtonXs, 32, const [
    _JsRef('shell.js', 21, 'width:32px;height:32px'),
  ]),
  _js('iconButtonIcon', GuSizes.iconButtonIcon, 24, const [
    _JsRef('ui.js', 17, 'size = 24'),
  ]),
  _css(
    'dotBadgeTop',
    GuSizes.dotBadgeTop,
    () => css.px('.iconbtn .dot-badge', 'top'),
    157,
    '.iconbtn .dot-badge',
    'top',
  ),
  _css(
    'dotBadgeRight',
    GuSizes.dotBadgeRight,
    () => css.px('.iconbtn .dot-badge', 'right'),
    157,
    '.iconbtn .dot-badge',
    'right',
  ),
  _css(
    'dotBadgeMinWidth',
    GuSizes.dotBadgeMinWidth,
    () => css.px('.iconbtn .dot-badge', 'min-width'),
    157,
    '.iconbtn .dot-badge',
    'min-width',
  ),
  _css(
    'dotBadgeHeight',
    GuSizes.dotBadgeHeight,
    () => css.px('.iconbtn .dot-badge', 'height'),
    157,
    '.iconbtn .dot-badge',
    'height',
  ),
  _css(
    'dotBadgePaddingX',
    GuSizes.dotBadgePaddingX,
    () => css.box('.iconbtn .dot-badge', 'padding')[1],
    157,
    '.iconbtn .dot-badge',
    'padding',
  ),
  _css(
    'onCoverBlur',
    GuSizes.onCoverBlur,
    () => css.fn('.iconbtn.on-cover', 'backdrop-filter', 'blur'),
    155,
    '.iconbtn.on-cover',
    'backdrop-filter',
  ),
  _css(
    'fabHeight',
    GuSizes.fabHeight,
    () => css.px('.fab', 'height'),
    158,
    '.fab',
    'height',
  ),
  _css(
    'fabPaddingLeft',
    GuSizes.fabPaddingLeft,
    () => css.box('.fab', 'padding')[3],
    158,
    '.fab',
    'padding',
  ),
  _css(
    'fabPaddingRight',
    GuSizes.fabPaddingRight,
    () => css.box('.fab', 'padding')[1],
    158,
    '.fab',
    'padding',
  ),
  _css(
    'fabGap',
    GuSizes.fabGap,
    () => css.px('.fab', 'gap'),
    158,
    '.fab',
    'gap',
  ),
  _css(
    'fabMargin',
    GuSizes.fabMargin,
    () => css.px('.fab', 'right'),
    158,
    '.fab',
    'right',
  ),
  _css(
    'quickPaddingY',
    GuSizes.quickPaddingY,
    () => css.box('.quick', 'padding')[0],
    305,
    '.quick',
    'padding',
  ),
  _css(
    'quickPaddingX',
    GuSizes.quickPaddingX,
    () => css.box('.quick', 'padding')[1],
    305,
    '.quick',
    'padding',
  ),
  _css(
    'quickGap',
    GuSizes.quickGap,
    () => css.px('.quick', 'gap'),
    305,
    '.quick',
    'gap',
  ),
  _css(
    'quickIconBox',
    GuSizes.quickIconBox,
    () => css.px('.quick .quick-icon', 'width'),
    306,
    '.quick .quick-icon',
    'width',
  ),
  _js('quickIcon', GuSizes.quickIcon, 20, const [
    _JsRef('ui.js', 128, r'name=${icon} size=${20}'),
  ]),
  _css(
    'quickBorder',
    GuSizes.quickBorder,
    () => css.box('.quick', 'border')[0],
    305,
    '.quick',
    'border',
  ),
  // §8.3
  _css(
    'fieldGap',
    GuSizes.fieldGap,
    () => css.px('.field', 'gap'),
    161,
    '.field',
    'gap',
  ),
  _css(
    'inputHeight',
    GuSizes.inputHeight,
    () => css.px('.input', 'min-height'),
    163,
    '.input',
    'min-height',
  ),
  _css(
    'inputPaddingX',
    GuSizes.inputPaddingX,
    () => css.box('.input', 'padding')[1],
    163,
    '.input',
    'padding',
  ),
  _css(
    'inputGap',
    GuSizes.inputGap,
    () => css.px('.input', 'gap'),
    163,
    '.input',
    'gap',
  ),
  _css(
    'inputBorder',
    GuSizes.inputBorder,
    () => css.box('.input', 'border')[0],
    163,
    '.input',
    'border',
  ),
  _css(
    'inputMultilinePaddingY',
    GuSizes.inputMultilinePaddingY,
    () => css.box('.input.is-multiline', 'padding')[0],
    169,
    '.input.is-multiline',
    'padding',
  ),
  _css(
    'textareaMinHeight',
    GuSizes.textareaMinHeight,
    () => css.px('.input textarea', 'min-height'),
    169,
    '.input textarea',
    'min-height',
  ),
  _js('textareaRows', GuSizes.textareaRows, 4, const [
    _JsRef('ui.js', 29, r'rows=${rows || 4}'),
  ]),
  _js('inputIcon', GuSizes.inputIcon, 20, const [
    _JsRef(
      'ui.js',
      28,
      r'<span class="in-icon"><${Icon} name=${icon} size=${20} />',
    ),
  ]),
  _js('inputLockIcon', GuSizes.inputLockIcon, 18, const [
    _JsRef('ui.js', 30, r'name="lock" size=${18}'),
  ]),
  _js('fieldHelpIcon', GuSizes.fieldHelpIcon, 14, const [
    _JsRef('ui.js', 33, r'name="triangle-alert" size=${14}'),
  ]),
  _css(
    'fieldHelpGap',
    GuSizes.fieldHelpGap,
    () => css.px('.field-help', 'gap'),
    171,
    '.field-help',
    'gap',
  ),
  _js('counterThresholdRatio', GuSizes.counterThresholdRatio, 0.8, const [
    _JsRef('ui.js', 23, 'Math.floor(maxLength * 0.8)'),
  ]),
  _css(
    'pickerHeight',
    GuSizes.pickerHeight,
    () => css.px('.picker', 'min-height'),
    173,
    '.picker',
    'min-height',
  ),
  _css(
    'pickerPaddingX',
    GuSizes.pickerPaddingX,
    () => css.box('.picker', 'padding')[1],
    173,
    '.picker',
    'padding',
  ),
  _js('pickerChevron', GuSizes.pickerChevron, 20, const [
    _JsRef('ui.js', 39, r'name="chevron-down" size=${20}'),
  ]),
  _css(
    'switchWidth',
    GuSizes.switchWidth,
    () => css.px('.switch', 'width'),
    231,
    '.switch',
    'width',
  ),
  _css(
    'switchHeight',
    GuSizes.switchHeight,
    () => css.px('.switch', 'height'),
    231,
    '.switch',
    'height',
  ),
  _css(
    'switchThumb',
    GuSizes.switchThumb,
    () => css.px('.switch>i', 'width'),
    234,
    '.switch>i',
    'width',
  ),
  _css(
    'switchThumbInset',
    GuSizes.switchThumbInset,
    () => css.px('.switch>i', 'top'),
    234,
    '.switch>i',
    'top',
  ),
  _css(
    'switchThumbTravel',
    GuSizes.switchThumbTravel,
    () => css.fn('.switch[aria-checked="true"]>i', 'transform', 'translateX'),
    235,
    '.switch[aria-checked="true"]>i',
    'transform',
  ),
  _css(
    'switchHitInsetY',
    GuSizes.switchHitInsetY,
    () => -css.box('.switch::after', 'inset')[0],
    232,
    '.switch::after',
    'inset',
  ),
  _css(
    'switchHitInsetX',
    GuSizes.switchHitInsetX,
    () => -css.box('.switch::after', 'inset')[1],
    232,
    '.switch::after',
    'inset',
  ),
  _css(
    'checkbox',
    GuSizes.checkbox,
    () => css.px('.check', 'width'),
    237,
    '.check',
    'width',
  ),
  _css(
    'checkboxBorder',
    GuSizes.checkboxBorder,
    () => css.box('.check', 'border')[0],
    237,
    '.check',
    'border',
  ),
  _js('checkboxIcon', GuSizes.checkboxIcon, 16, const [
    _JsRef('ui.js', 46, r'name="check" size=${16} stroke=${3}'),
  ]),
  _css(
    'radioDot',
    GuSizes.radioDot,
    () => css.px('.radio[aria-checked="true"]>i', 'width'),
    241,
    '.radio[aria-checked="true"]>i',
    'width',
  ),
  _css(
    'checkHitInset',
    GuSizes.checkHitInset,
    () => -css.box('.check::after', 'inset')[0],
    239,
    '.check::after',
    'inset',
  ),
  _css(
    'optionRowMinHeight',
    GuSizes.optionRowMinHeight,
    () => css.px('.option-row', 'min-height'),
    243,
    '.option-row',
    'min-height',
  ),
  _css(
    'optionRowPaddingY',
    GuSizes.optionRowPaddingY,
    () => css.box('.option-row', 'padding')[0],
    243,
    '.option-row',
    'padding',
  ),
  _css(
    'optionRowPaddingX',
    GuSizes.optionRowPaddingX,
    () => css.box('.option-row', 'padding')[1],
    243,
    '.option-row',
    'padding',
  ),
  _css(
    'optionRowGap',
    GuSizes.optionRowGap,
    () => css.px('.option-row', 'gap'),
    243,
    '.option-row',
    'gap',
  ),
  _css(
    'optionCardPaddingY',
    GuSizes.optionCardPaddingY,
    () => css.box('.option-card', 'padding')[0],
    245,
    '.option-card',
    'padding',
  ),
  _css(
    'optionCardPaddingX',
    GuSizes.optionCardPaddingX,
    () => css.box('.option-card', 'padding')[1],
    245,
    '.option-card',
    'padding',
  ),
  _css(
    'optionCardGap',
    GuSizes.optionCardGap,
    () => css.px('.option-card', 'gap'),
    245,
    '.option-card',
    'gap',
  ),
  _css(
    'optionCardBorder',
    GuSizes.optionCardBorder,
    () => css.box('.option-card', 'border')[0],
    245,
    '.option-card',
    'border',
  ),
  _css(
    'segmentPadding',
    GuSizes.segmentPadding,
    () => css.box('.seg', 'padding')[0],
    220,
    '.seg',
    'padding',
  ),
  _css(
    'segmentGap',
    GuSizes.segmentGap,
    () => css.px('.seg', 'gap'),
    220,
    '.seg',
    'gap',
  ),
  _css(
    'segmentHeight',
    GuSizes.segmentHeight,
    () => css.px('.seg>button', 'min-height'),
    221,
    '.seg>button',
    'min-height',
  ),
  _css(
    'segmentPaddingX',
    GuSizes.segmentPaddingX,
    () => css.box('.seg>button', 'padding')[1],
    221,
    '.seg>button',
    'padding',
  ),
  _css(
    'segmentItemGap',
    GuSizes.segmentItemGap,
    () => css.px('.seg>button', 'gap'),
    221,
    '.seg>button',
    'gap',
  ),
  _js('segmentIcon', GuSizes.segmentIcon, 16, const [
    _JsRef('ui.js', 59, r'name=${o.icon} size=${16}'),
  ]),
  _css(
    'tabHeight',
    GuSizes.tabHeight,
    () => css.px('.tabs>button', 'min-height'),
    226,
    '.tabs>button',
    'min-height',
  ),
  _css(
    'tabPaddingX',
    GuSizes.tabPaddingX,
    () => css.box('.tabs>button', 'padding')[1],
    226,
    '.tabs>button',
    'padding',
  ),
  _css(
    'tabPaddingXScroll',
    GuSizes.tabPaddingXScroll,
    () => css.box('.tabs.is-scroll>button', 'padding')[1],
    229,
    '.tabs.is-scroll>button',
    'padding',
  ),
  _css(
    'tabGap',
    GuSizes.tabGap,
    () => css.px('.tabs>button', 'gap'),
    226,
    '.tabs>button',
    'gap',
  ),
  _js('tabIcon', GuSizes.tabIcon, 16, const [
    _JsRef('ui.js', 62, r'name=${tb.icon} size=${16}'),
  ]),
  _css(
    'tabIndicatorHeight',
    GuSizes.tabIndicatorHeight,
    () => css.px('.tabs>button[aria-selected="true"]::after', 'height'),
    228,
    '.tabs>button[aria-selected="true"]::after',
    'height',
  ),
  _css(
    'tabIndicatorInset',
    GuSizes.tabIndicatorInset,
    () => css.px('.tabs>button[aria-selected="true"]::after', 'left'),
    228,
    '.tabs>button[aria-selected="true"]::after',
    'left',
  ),
  _css(
    'tabBorder',
    GuSizes.tabBorder,
    () => css.box('.tabs', 'border-bottom')[0],
    224,
    '.tabs',
    'border-bottom',
  ),
  _css(
    'tabIndicatorBottomOverlap',
    GuSizes.tabIndicatorBottomOverlap,
    () => -css.px('.tabs>button[aria-selected="true"]::after', 'bottom'),
    228,
    '.tabs>button[aria-selected="true"]::after',
    'bottom',
  ),
  _css(
    'stepbarGap',
    GuSizes.stepbarGap,
    () => css.px('.stepbar', 'gap'),
    320,
    '.stepbar',
    'gap',
  ),
  _css(
    'stepbarHeight',
    GuSizes.stepbarHeight,
    () => css.px('.stepbar>i', 'height'),
    320,
    '.stepbar>i',
    'height',
  ),
  _css(
    'wheelHeight',
    GuSizes.wheelHeight,
    () => css.px('.wheel', 'height'),
    321,
    '.wheel',
    'height',
  ),
  _css(
    'wheelItemHeight',
    GuSizes.wheelItemHeight,
    () => css.px('.wheel>button', 'height'),
    322,
    '.wheel>button',
    'height',
  ),
  _css(
    'wheelMaskStart',
    GuSizes.wheelMaskStart,
    () => css.fn('.wheel', 'mask-image', 'linear-gradient', arg: 1),
    321,
    '.wheel',
    'mask-image',
  ),
  _css(
    'wheelMaskEnd',
    GuSizes.wheelMaskEnd,
    () => css.fn('.wheel', 'mask-image', 'linear-gradient', arg: 2),
    321,
    '.wheel',
    'mask-image',
  ),
  _js('wheelSpacer', GuSizes.wheelSpacer, 60, const [
    _JsRef('sheets.js', 138, '<div style="height:60px" />'),
  ]),
  _js('wheelSelectionBorder', GuSizes.wheelSelectionBorder, 1, const [
    _JsRef(
      'sheets.js',
      140,
      'border-top:1px solid var(--border-default);border-bottom:1px solid var(--border-default)',
    ),
  ]),
  // §8.4
  _css(
    'chipHeight',
    GuSizes.chipHeight,
    () => css.px('.chip', 'min-height'),
    176,
    '.chip',
    'min-height',
  ),
  _css(
    'chipPaddingX',
    GuSizes.chipPaddingX,
    () => css.box('.chip', 'padding')[1],
    176,
    '.chip',
    'padding',
  ),
  _css(
    'chipGap',
    GuSizes.chipGap,
    () => css.px('.chip', 'gap'),
    176,
    '.chip',
    'gap',
  ),
  _css(
    'chipBorder',
    GuSizes.chipBorder,
    () => css.box('.chip', 'border')[0],
    176,
    '.chip',
    'border',
  ),
  _js('chipIcon', GuSizes.chipIcon, 16, const [
    _JsRef('ui.js', 55, r'name=${icon} size=${16}'),
  ]),
  _js('chipRemoveIcon', GuSizes.chipRemoveIcon, 14, const [
    _JsRef('ui.js', 56, r'name="x" size=${14}'),
  ]),
  _css(
    'chipHitInset',
    GuSizes.chipHitInset,
    () => -css.box('.chip::after', 'inset')[0],
    179,
    '.chip::after',
    'inset',
  ),
  _js('chipRemoveMarginRight', GuSizes.chipRemoveMarginRight, -4, const [
    _JsRef('ui.js', 56, 'margin-right:-4px'),
  ]),
  _css(
    'chipCountMinWidth',
    GuSizes.chipCountMinWidth,
    () => css.px('.chip .chip-count', 'min-width'),
    186,
    '.chip .chip-count',
    'min-width',
  ),
  _css(
    'chipCountHeight',
    GuSizes.chipCountHeight,
    () => css.px('.chip .chip-count', 'height'),
    186,
    '.chip .chip-count',
    'height',
  ),
  _css(
    'chipCountPaddingX',
    GuSizes.chipCountPaddingX,
    () => css.box('.chip .chip-count', 'padding')[1],
    186,
    '.chip .chip-count',
    'padding',
  ),
  _css(
    'badgeHeight',
    GuSizes.badgeHeight,
    () => css.px('.badge', 'height'),
    188,
    '.badge',
    'height',
  ),
  _css(
    'badgePaddingX',
    GuSizes.badgePaddingX,
    () => css.box('.badge', 'padding')[1],
    188,
    '.badge',
    'padding',
  ),
  _css(
    'badgeGap',
    GuSizes.badgeGap,
    () => css.px('.badge', 'gap'),
    188,
    '.badge',
    'gap',
  ),
  _js('badgeIcon', GuSizes.badgeIcon, 12, const [
    _JsRef('ui.js', 66, r'size=${12} stroke=${2.2}'),
  ]),
  _css(
    'badgeBorder',
    GuSizes.badgeBorder,
    () => css.box('.badge-board', 'border')[0],
    190,
    '.badge-board',
    'border',
  ),
  _css(
    'countBadgeMinWidth',
    GuSizes.countBadgeMinWidth,
    () => css.px('.badge-count', 'min-width'),
    200,
    '.badge-count',
    'min-width',
  ),
  _css(
    'countBadgeHeight',
    GuSizes.countBadgeHeight,
    () => css.px('.badge-count', 'height'),
    200,
    '.badge-count',
    'height',
  ),
  _css(
    'countBadgePaddingX',
    GuSizes.countBadgePaddingX,
    () => css.box('.badge-count', 'padding')[1],
    200,
    '.badge-count',
    'padding',
  ),
  _css('dot', GuSizes.dot, () => css.px('.dot', 'width'), 201, '.dot', 'width'),
  _css(
    'hitInset',
    GuSizes.hitInset,
    () => -css.box('.hit::after', 'inset')[0],
    107,
    '.hit::after',
    'inset',
  ),
  // §8.5
  _css(
    'cardBorder',
    GuSizes.cardBorder,
    () => css.box('.card', 'border')[0],
    203,
    '.card',
    'border',
  ),
  _css(
    'cardBodyPadding',
    GuSizes.cardBodyPadding,
    () => css.box('.card-body', 'padding')[0],
    207,
    '.card-body',
    'padding',
  ),
  _css(
    'highlightRingWidth',
    GuSizes.highlightRingWidth,
    () => css.box('@keyframes highlight 0%', 'box-shadow')[3],
    426,
    '@keyframes highlight 0%',
    'box-shadow',
  ),
  _css(
    'tileMinHeight',
    GuSizes.tileMinHeight,
    () => css.px('.tile', 'min-height'),
    211,
    '.tile',
    'min-height',
  ),
  _css(
    'tilePaddingY',
    GuSizes.tilePaddingY,
    () => css.box('.tile', 'padding')[0],
    211,
    '.tile',
    'padding',
  ),
  _css(
    'tilePaddingX',
    GuSizes.tilePaddingX,
    () => css.box('.tile', 'padding')[1],
    211,
    '.tile',
    'padding',
  ),
  _css(
    'tileGap',
    GuSizes.tileGap,
    () => css.px('.tile', 'gap'),
    211,
    '.tile',
    'gap',
  ),
  _css(
    'tileInCardPaddingY',
    GuSizes.tileInCardPaddingY,
    () => css.box('.tile.in-card', 'padding')[0],
    214,
    '.tile.in-card',
    'padding',
  ),
  _js('tileChevron', GuSizes.tileChevron, 20, const [
    _JsRef('ui.js', 75, r'"chevron-right" size=${20}'),
  ]),
  _css(
    'groupHeadPaddingTop',
    GuSizes.groupHeadPaddingTop,
    () => css.box('.group-head', 'padding')[0],
    215,
    '.group-head',
    'padding',
  ),
  _css(
    'groupHeadPaddingX',
    GuSizes.groupHeadPaddingX,
    () => css.box('.group-head', 'padding')[1],
    215,
    '.group-head',
    'padding',
  ),
  _css(
    'groupHeadPaddingBottom',
    GuSizes.groupHeadPaddingBottom,
    () => css.box('.group-head', 'padding')[2],
    215,
    '.group-head',
    'padding',
  ),
  _css(
    'sectionTitleMarginTop',
    GuSizes.sectionTitleMarginTop,
    () => css.box('.section-title', 'margin')[0],
    108,
    '.section-title',
    'margin',
  ),
  _css(
    'sectionTitleMarginBottom',
    GuSizes.sectionTitleMarginBottom,
    () => css.box('.section-title', 'margin')[2],
    108,
    '.section-title',
    'margin',
  ),
  _css(
    'sectionTitleFirstMarginTop',
    GuSizes.sectionTitleFirstMarginTop,
    () => css.px('.section-title:first-child', 'margin-top'),
    109,
    '.section-title:first-child',
    'margin-top',
  ),
  _css(
    'sectionTitleGap',
    GuSizes.sectionTitleGap,
    () => css.px('.section-title', 'gap'),
    108,
    '.section-title',
    'gap',
  ),
  _css(
    'divider',
    GuSizes.divider,
    () => css.px('.divider', 'height'),
    106,
    '.divider',
    'height',
  ),
  _js('avatar', GuSizes.avatar, 40, const [_JsRef('art.js', 43, 'size = 40')]),
  _jsList(
    'avatarSizes',
    GuSizes.avatarSizes,
    () => js.callSizes('Avatar'),
    'prototip `Avatar size=` dağılımı (bundle/pages hariç 26 çağrı)',
  ),
  _js('avatarGroupSize', GuSizes.avatarGroupSize, 28, const [
    _JsRef('art.js', 48, 'size = 28'),
  ]),
  _css(
    'avatarGroupOverlap',
    GuSizes.avatarGroupOverlap,
    () => -css.px('.avatar-group .avatar', 'margin-left'),
    218,
    '.avatar-group .avatar',
    'margin-left',
  ),
  _css(
    'avatarGroupBorder',
    GuSizes.avatarGroupBorder,
    () => css.box('.avatar-group .avatar', 'border')[0],
    218,
    '.avatar-group .avatar',
    'border',
  ),
  _js('avatarGroupMax', GuSizes.avatarGroupMax, 4, const [
    _JsRef('art.js', 48, 'max = 4'),
  ]),
  _js('avatarMorePaddingX', GuSizes.avatarMorePaddingX, 6, const [
    _JsRef('art.js', 50, "padding: '0 6px'"),
  ]),
  _js('avatarMoreMinFont', GuSizes.avatarMoreMinFont, 10, const [
    _JsRef('art.js', 50, 'Math.max(10, Math.round(size * 0.38))'),
  ]),
  _js('avatarMoreFontRatio', GuSizes.avatarMoreFontRatio, 0.38, const [
    _JsRef('art.js', 50, 'Math.max(10, Math.round(size * 0.38))'),
  ]),
  _jsList(
    'avatarGroupSizes',
    GuSizes.avatarGroupSizes,
    () => js.callSizes('AvatarGroup'),
    'cards.js:38 ClubCard 24, screens-clubs.js:92 CLB-03 28, screens-events.js:69 EVT-02 32 (K-47)',
  ),
  _js('avatarInitialsRatio', GuSizes.avatarInitialsRatio, 0.4, const [
    _JsRef('art.js', 45, 'Math.round(size * 0.4)'),
  ]),
  _css(
    'emblem',
    GuSizes.emblem,
    () => css.px('.emblem', 'width'),
    398,
    '.emblem',
    'width',
  ),
  _css(
    'emblemSm',
    GuSizes.emblemSm,
    () => css.px('.emblem.is-sm', 'width'),
    399,
    '.emblem.is-sm',
    'width',
  ),
  _css(
    'emblemXs',
    GuSizes.emblemXs,
    () => css.px('.emblem.is-xs', 'width'),
    400,
    '.emblem.is-xs',
    'width',
  ),
  _css(
    'emblemBorder',
    GuSizes.emblemBorder,
    () => css.box('.emblem', 'border')[0],
    398,
    '.emblem',
    'border',
  ),
  _js('emblemIconSizes', GuSizes.emblemIconSizes, const <double>[
    14,
    16,
    20,
    22,
  ], _emblemIconRefs),
  _jsList(
    'logoSizes',
    GuSizes.logoSizes,
    () => js.callSizes('Logo', files: _screenFiles),
    'ekran `Logo size=` kullanımları: FED-03 20, AUT-01 72, SET-04 80, SYS-01 96 (CD-90; shell.js:52 SideMenu 32 maketi hariç)',
  ),
  _css(
    'kpiPaddingY',
    GuSizes.kpiPaddingY,
    () => css.box('.kpi', 'padding')[0],
    302,
    '.kpi',
    'padding',
  ),
  _css(
    'kpiPaddingX',
    GuSizes.kpiPaddingX,
    () => css.box('.kpi', 'padding')[1],
    302,
    '.kpi',
    'padding',
  ),
  _css(
    'kpiGap',
    GuSizes.kpiGap,
    () => css.px('.kpi', 'gap'),
    302,
    '.kpi',
    'gap',
  ),
  _js('kpiIcon', GuSizes.kpiIcon, 16, const [
    _JsRef('ui.js', 127, r'name=${icon} size=${16}'),
  ]),
  _css(
    'dateBadgeWidth',
    GuSizes.dateBadgeWidth,
    () => css.px('.date-badge', 'width'),
    318,
    '.date-badge',
    'width',
  ),
  _css(
    'dateBadgeHeight',
    GuSizes.dateBadgeHeight,
    () => css.px('.date-badge', 'height'),
    318,
    '.date-badge',
    'height',
  ),
  _css(
    'dateBadgeMonthTop',
    GuSizes.dateBadgeMonthTop,
    () => css.px('.date-badge span', 'margin-top'),
    319,
    '.date-badge span',
    'margin-top',
  ),
  _css(
    'coverRatio16x9',
    GuSizes.coverRatio16x9,
    () => css.number('.cover.r16-9', 'aspect-ratio'),
    209,
    '.cover.r16-9',
    'aspect-ratio',
  ),
  _css(
    'coverRatio3x2',
    GuSizes.coverRatio3x2,
    () => css.number('.cover.r3-2', 'aspect-ratio'),
    209,
    '.cover.r3-2',
    'aspect-ratio',
  ),
  _css(
    'coverRatio1x1',
    GuSizes.coverRatio1x1,
    () => css.number('.cover.r1-1', 'aspect-ratio'),
    209,
    '.cover.r1-1',
    'aspect-ratio',
  ),
  _js('coverIconScale', GuSizes.coverIconScale, 0.8, const [
    _JsRef('art.js', 33, 'const k = h / 24 * 0.8'),
  ]),
  _js('coverIconOffsetXRatio', GuSizes.coverIconOffsetXRatio, 0.85, const [
    _JsRef('art.js', 33, 'const ix = w - 24 * k * 0.85'),
  ]),
  _js('coverIconOffsetYRatio', GuSizes.coverIconOffsetYRatio, 0.9, const [
    _JsRef('art.js', 33, 'const iy = h - 24 * k * 0.9'),
  ]),
  _js('coverIconStroke', GuSizes.coverIconStroke, 1.1, const [
    _JsRef('art.js', 34, 'stroke-width="1.1"'),
  ]),
  _css(
    'parallaxHeight',
    GuSizes.parallaxHeight,
    () => css.px('.parallax', 'height'),
    395,
    '.parallax',
    'height',
  ),
  _css(
    'parallaxFactor',
    GuSizes.parallaxFactor,
    () => _calcFactor(css.fnArg('.parallax .cover', 'transform', 'translateY')),
    396,
    '.parallax .cover',
    'transform',
  ),
  _css(
    'parallaxBarPaddingX',
    GuSizes.parallaxBarPaddingX,
    () => css.box('.parallax-bar', 'padding')[1],
    397,
    '.parallax-bar',
    'padding',
  ),
  _css(
    'parallaxBarTopOffset',
    GuSizes.parallaxBarTopOffset,
    () => -css.box('.parallax-bar', 'padding')[0],
    397,
    '.parallax-bar',
    'padding',
  ),
  _css(
    'imageGridGap',
    GuSizes.imageGridGap,
    () => css.px('.img-grid', 'gap'),
    407,
    '.img-grid',
    'gap',
  ),
  _css(
    'imageGridRadius',
    GuSizes.imageGridRadius,
    () => css.px('.img-grid', 'border-radius'),
    407,
    '.img-grid',
    'border-radius',
  ),
  _css(
    'notifIcon',
    GuSizes.notifIcon,
    () => css.px('.notif-icon', 'width'),
    405,
    '.notif-icon',
    'width',
  ),
  _js('notifIconLg', GuSizes.notifIconLg, 72, const [
    _JsRef('sheets.js', 116, 'style="width:72px;height:72px"'),
  ]),
  _js('notifIconLgIcon', GuSizes.notifIconLgIcon, 36, const [
    _JsRef('sheets.js', 116, r'name=${icon} size=${36}'),
  ]),
  _css(
    'timelineItemMinHeight',
    GuSizes.timelineItemMinHeight,
    () => css.px('.timeline-item', 'min-height'),
    308,
    '.timeline-item',
    'min-height',
  ),
  _css(
    'timelineGap',
    GuSizes.timelineGap,
    () => css.px('.timeline-item', 'gap'),
    308,
    '.timeline-item',
    'gap',
  ),
  _css(
    'timelineRailWidth',
    GuSizes.timelineRailWidth,
    () => css.px('.timeline-rail', 'width'),
    309,
    '.timeline-rail',
    'width',
  ),
  _css(
    'timelineDot',
    GuSizes.timelineDot,
    () => css.px('.timeline-dot', 'width'),
    310,
    '.timeline-dot',
    'width',
  ),
  _css(
    'timelineDotBorder',
    GuSizes.timelineDotBorder,
    () => css.box('.timeline-dot', 'border')[0],
    310,
    '.timeline-dot',
    'border',
  ),
  _css(
    'timelineDotRing',
    GuSizes.timelineDotRing,
    () => css.box('.timeline-dot', 'box-shadow')[3],
    310,
    '.timeline-dot',
    'box-shadow',
  ),
  _css(
    'timelineDotTop',
    GuSizes.timelineDotTop,
    () => css.px('.timeline-dot', 'margin-top'),
    310,
    '.timeline-dot',
    'margin-top',
  ),
  _css(
    'timelineLineWidth',
    GuSizes.timelineLineWidth,
    () => css.px('.timeline-line', 'width'),
    312,
    '.timeline-line',
    'width',
  ),
  _css(
    'timelineLineMarginY',
    GuSizes.timelineLineMarginY,
    () => css.box('.timeline-line', 'margin')[0],
    312,
    '.timeline-line',
    'margin',
  ),
  _css(
    'pollOptionPaddingY',
    GuSizes.pollOptionPaddingY,
    () => css.box('.poll-opt', 'padding')[0],
    328,
    '.poll-opt',
    'padding',
  ),
  _css(
    'pollOptionPaddingX',
    GuSizes.pollOptionPaddingX,
    () => css.box('.poll-opt', 'padding')[1],
    328,
    '.poll-opt',
    'padding',
  ),
  _css(
    'pollOptionGap',
    GuSizes.pollOptionGap,
    () => css.px('.poll-opt', 'gap'),
    328,
    '.poll-opt',
    'gap',
  ),
  _css(
    'pollOptionBorder',
    GuSizes.pollOptionBorder,
    () => css.box('.poll-opt', 'border')[0],
    328,
    '.poll-opt',
    'border',
  ),
  _css(
    'ticketCutDash',
    GuSizes.ticketCutDash,
    () => css.box('.ticket-cut', 'border-top')[0],
    324,
    '.ticket-cut',
    'border-top',
  ),
  _css(
    'ticketNotch',
    GuSizes.ticketNotch,
    () => css.px('.ticket-cut::before', 'width'),
    325,
    '.ticket-cut::before',
    'width',
  ),
  _css(
    'ticketNotchTop',
    GuSizes.ticketNotchTop,
    () => -css.px('.ticket-cut::before', 'top'),
    325,
    '.ticket-cut::before',
    'top',
  ),
  _css(
    'ticketNotchOffset',
    GuSizes.ticketNotchOffset,
    () => -css.px('.ticket-cut::before', 'left'),
    325,
    '.ticket-cut::before',
    'left',
  ),
  _css(
    'ticketCutMarginX',
    GuSizes.ticketCutMarginX,
    () => css.box('.ticket-cut', 'margin')[1],
    324,
    '.ticket-cut',
    'margin',
  ),
  _css('qr', GuSizes.qr, () => css.px('.qr', 'width'), 326, '.qr', 'width'),
  _css(
    'qrPadding',
    GuSizes.qrPadding,
    () => css.box('.qr', 'padding')[0],
    326,
    '.qr',
    'padding',
  ),
  _css(
    'qrBlurSigma',
    GuSizes.qrBlurSigma,
    () => css.fn('.qr.is-blur svg', 'filter', 'blur'),
    327,
    '.qr.is-blur svg',
    'filter',
  ),
  _css(
    'qrVoidLineHeight',
    GuSizes.qrVoidLineHeight,
    () => css.px('.qr.is-void::after', 'height'),
    327,
    '.qr.is-void::after',
    'height',
  ),
  _css(
    'qrVoidAngleDeg',
    GuSizes.qrVoidAngleDeg,
    () => css.fn('.qr.is-void::after', 'transform', 'rotate'),
    327,
    '.qr.is-void::after',
    'transform',
  ),
  _css(
    'qrVoidLeft',
    GuSizes.qrVoidLeft,
    () => css.percent('.qr.is-void::after', 'left'),
    327,
    '.qr.is-void::after',
    'left',
  ),
  _css(
    'qrVoidWidth',
    GuSizes.qrVoidWidth,
    () => css.percent('.qr.is-void::after', 'width'),
    327,
    '.qr.is-void::after',
    'width',
  ),
  _css(
    'scanBox',
    GuSizes.scanBox,
    () => css.px('.scan-box', 'width'),
    402,
    '.scan-box',
    'width',
  ),
  _css(
    'scanCorner',
    GuSizes.scanCorner,
    () => css.px('.scan-box>i', 'width'),
    403,
    '.scan-box>i',
    'width',
  ),
  _css(
    'scanCornerStroke',
    GuSizes.scanCornerStroke,
    () => css.box('.scan-box>i', 'border')[0],
    403,
    '.scan-box>i',
    'border',
  ),
  _css(
    'scanLineHeight',
    GuSizes.scanLineHeight,
    () => css.px('.scanline', 'height'),
    335,
    '.scanline',
    'height',
  ),
  _css(
    'scanLineInsetX',
    GuSizes.scanLineInsetX,
    () => css.percent('.scanline', 'left'),
    335,
    '.scanline',
    'left',
  ),
  _css(
    'scanLineGlow',
    GuSizes.scanLineGlow,
    () => css.box('.scanline', 'box-shadow')[2],
    335,
    '.scanline',
    'box-shadow',
  ),
  _css(
    'scanLineTopMin',
    GuSizes.scanLineTopMin,
    () => css.percent('@keyframes scan 0%', 'top'),
    422,
    '@keyframes scan 0%',
    'top',
  ),
  _css(
    'scanLineTopMax',
    GuSizes.scanLineTopMax,
    () => css.percent('@keyframes scan 50%', 'top'),
    422,
    '@keyframes scan 50%',
    'top',
  ),
  _css(
    'scanGradientStop',
    GuSizes.scanGradientStop,
    () => css.fn('.scan-view', 'background', 'radial-gradient', arg: 2),
    401,
    '.scan-view',
    'background',
  ),
  _css(
    'mapPlaceholderHeight',
    GuSizes.mapPlaceholderHeight,
    () => css.px('.map-ph', 'height'),
    410,
    '.map-ph',
    'height',
  ),
  _css(
    'mapPlaceholderStripe',
    GuSizes.mapPlaceholderStripe,
    () => css.fn('.map-ph', 'background', 'repeating-linear-gradient', arg: 1),
    410,
    '.map-ph',
    'background',
  ),
  _css(
    'mapPlaceholderBorder',
    GuSizes.mapPlaceholderBorder,
    () => css.box('.map-ph', 'border')[0],
    410,
    '.map-ph',
    'border',
  ),
  _css(
    'miniChartHeight',
    GuSizes.miniChartHeight,
    () => css.px('.mini-chart', 'height'),
    342,
    '.mini-chart',
    'height',
  ),
  _js('miniChartViewW', GuSizes.miniChartViewW, 320, const [
    _JsRef('ui.js', 134, 'const w = 320, h = 110, pad = 10'),
  ]),
  _js('miniChartViewH', GuSizes.miniChartViewH, 110, const [
    _JsRef('ui.js', 134, 'const w = 320, h = 110, pad = 10'),
  ]),
  _js('miniChartPad', GuSizes.miniChartPad, 10, const [
    _JsRef('ui.js', 134, 'const w = 320, h = 110, pad = 10'),
  ]),
  _js('miniChartPoint', GuSizes.miniChartPoint, 4, const [
    _JsRef('ui.js', 137, r'r=${sel === i ? 6 : 4}'),
  ]),
  _js('miniChartPointSelected', GuSizes.miniChartPointSelected, 6, const [
    _JsRef('ui.js', 137, r'r=${sel === i ? 6 : 4}'),
  ]),
  _js('miniChartPointStroke', GuSizes.miniChartPointStroke, 2, const [
    _JsRef('ui.js', 137, 'stroke-width="2"'),
  ]),
  _js('miniChartLine', GuSizes.miniChartLine, 2.5, const [
    _JsRef('ui.js', 137, 'stroke-width="2.5"'),
  ]),
  _css(
    'tooltipPaddingY',
    GuSizes.tooltipPaddingY,
    () => css.box('.tooltip', 'padding')[0],
    341,
    '.tooltip',
    'padding',
  ),
  _css(
    'tooltipPaddingX',
    GuSizes.tooltipPaddingX,
    () => css.box('.tooltip', 'padding')[1],
    341,
    '.tooltip',
    'padding',
  ),
  _css(
    'tooltipOffsetYRatio',
    GuSizes.tooltipOffsetYRatio,
    () => css.fn('.tooltip', 'transform', 'translate', arg: 1),
    341,
    '.tooltip',
    'transform',
  ),
  _js('donut', GuSizes.donut, 96, const [
    _JsRef('ui.js', 93, 'size = 96, stroke = 10'),
  ]),
  _js('donutStroke', GuSizes.donutStroke, 10, const [
    _JsRef('ui.js', 93, 'size = 96, stroke = 10'),
  ]),
  _js('donutValueDivisor', GuSizes.donutValueDivisor, 4.5, const [
    _JsRef('ui.js', 93, r'font-size=${size / 4.5}'),
  ]),
  _js('successCheck', GuSizes.successCheck, 96, const [
    _JsRef('ui.js', 151, 'function SuccessCheck({ size = 96 })'),
  ]),
  _jsList(
    'successCheckSizes',
    GuSizes.successCheckSizes,
    () => js.callSizes('SuccessCheck'),
    '`SuccessCheck size=` kullanımları 72×1, 110×1',
  ),
  _js('successCircleStroke', GuSizes.successCircleStroke, 4, const [
    _JsRef(
      'ui.js',
      151,
      'r="40" fill="none" stroke="var(--state-success)" stroke-width="4"',
    ),
  ]),
  _js('successCheckStroke', GuSizes.successCheckStroke, 5, const [
    _JsRef('ui.js', 151, 'stroke-width="5"'),
  ]),
  _js('successCircleR', GuSizes.successCircleR, 40, const [
    _JsRef('ui.js', 151, 'cx="48" cy="48" r="40"'),
  ]),
  _css(
    'progressHeight',
    GuSizes.progressHeight,
    () => css.px('.prog', 'height'),
    259,
    '.prog',
    'height',
  ),
  _css(
    'progressHeightThin',
    GuSizes.progressHeightThin,
    () => css.px('.prog.is-thin', 'height'),
    261,
    '.prog.is-thin',
    'height',
  ),
  _css(
    'progressMinWidth',
    GuSizes.progressMinWidth,
    () => css.px('.prog', 'min-width'),
    259,
    '.prog',
    'min-width',
  ),
  _css(
    'skeletonRadius',
    GuSizes.skeletonRadius,
    () => css.px('.sk', 'border-radius'),
    263,
    '.sk',
    'border-radius',
  ),
  _js('skeletonLineHeight', GuSizes.skeletonLineHeight, 14, const [
    _JsRef('ui.js', 94, 'h = 14'),
  ]),
  _js('skeletonTitleHeight', GuSizes.skeletonTitleHeight, 16, const [
    _JsRef('ui.js', 97, r'w="60%" h=${16}'),
  ]),
  _js('skeletonSubHeight', GuSizes.skeletonSubHeight, 12, const [
    _JsRef('ui.js', 98, r'w="80%" h=${12}'),
  ]),
  _js('skeletonCardCover', GuSizes.skeletonCardCover, 140, const [
    _JsRef('ui.js', 97, r'h=${140}'),
  ]),
  _js('skeletonAvatar', GuSizes.skeletonAvatar, 40, const [
    _JsRef('ui.js', 98, r'w=${40} h=${40} circle'),
  ]),
  _jsList(
    'skeletonWidthRatios',
    GuSizes.skeletonWidthRatios,
    () => [
      ...js.percentsOnLine('ui.js', 98),
      ...js.percentsOnLine('ui.js', 97),
    ],
    'ui.js:98 satır (55%, 80%) + ui.js:97 kart (60%, 90%, 40%)',
  ),
  _css(
    'emptyPaddingY',
    GuSizes.emptyPaddingY,
    () => css.box('.empty', 'padding')[0],
    300,
    '.empty',
    'padding',
  ),
  _css(
    'emptyPaddingX',
    GuSizes.emptyPaddingX,
    () => css.box('.empty', 'padding')[1],
    300,
    '.empty',
    'padding',
  ),
  _css(
    'emptyGap',
    GuSizes.emptyGap,
    () => css.px('.empty', 'gap'),
    300,
    '.empty',
    'gap',
  ),
  _js('emptyCompactPaddingY', GuSizes.emptyCompactPaddingY, 20, const [
    _JsRef('ui.js', 101, "padding: '20px 16px'"),
  ]),
  _js('emptyCompactPaddingX', GuSizes.emptyCompactPaddingX, 16, const [
    _JsRef('ui.js', 101, "padding: '20px 16px'"),
  ]),
  _js('emptyDescMaxWidth', GuSizes.emptyDescMaxWidth, 280, const [
    _JsRef('ui.js', 101, 'max-width:280px'),
  ]),
  _js('emptyInlinePaddingY', GuSizes.emptyInlinePaddingY, 24, const [
    _JsRef('ui.js', 107, "padding: '24px 16px'"),
  ]),
  _js('illustration', GuSizes.illustration, 140, const [
    _JsRef('art.js', 88, 'size = 140'),
  ]),
  _js('illustrationCompact', GuSizes.illustrationCompact, 96, const [
    _JsRef('ui.js', 101, r'size=${compact ? 96 : 140}'),
  ]),
  _jsList(
    'illustrationSizes',
    GuSizes.illustrationSizes,
    () => js.callSizes('Illustration', defaults: const [140]),
    '`Illustration size=` kullanımları + varsayılan 140 (K-48)',
  ),
  _js('listEndPaddingTop', GuSizes.listEndPaddingTop, 20, const [
    _JsRef('ui.js', 123, 'padding:20px 16px 8px'),
  ]),
  _js('listEndPaddingX', GuSizes.listEndPaddingX, 16, const [
    _JsRef('ui.js', 123, 'padding:20px 16px 8px'),
  ]),
  _js('listEndPaddingBottom', GuSizes.listEndPaddingBottom, 8, const [
    _JsRef('ui.js', 123, 'padding:20px 16px 8px'),
  ]),
  _css(
    'hscrollPaddingY',
    GuSizes.hscrollPaddingY,
    () => css.box('.hscroll', 'padding')[0],
    105,
    '.hscroll',
    'padding',
  ),
  _css(
    'hscrollGap',
    GuSizes.hscrollGap,
    () => css.px('.hscroll', 'gap'),
    105,
    '.hscroll',
    'gap',
  ),
  _css(
    'gridGap',
    GuSizes.gridGap,
    () => css.px('.grid2', 'gap'),
    110,
    '.grid2',
    'gap',
  ),
  _css(
    'screenScrollBottomExtra',
    GuSizes.screenScrollBottomExtra,
    () => css.px('.screen-scroll', 'padding-bottom'),
    123,
    '.screen-scroll',
    'padding-bottom',
  ),
  _css(
    'pageDot',
    GuSizes.pageDot,
    () => css.px('.dots>i', 'width'),
    394,
    '.dots>i',
    'width',
  ),
  _css(
    'pageDotActiveWidth',
    GuSizes.pageDotActiveWidth,
    () => css.px('.dots>i.is-active', 'width'),
    394,
    '.dots>i.is-active',
    'width',
  ),
  _css(
    'pageDotGap',
    GuSizes.pageDotGap,
    () => css.px('.dots', 'gap'),
    394,
    '.dots',
    'gap',
  ),
  _css(
    'splashGap',
    GuSizes.splashGap,
    () => css.px('.splash', 'gap'),
    391,
    '.splash',
    'gap',
  ),
  _js('splashLogo', GuSizes.splashLogo, 96, const [
    _JsRef('screens-auth.js', 33, r'Logo} size=${96}'),
  ]),
  _js('splashVersionBottom', GuSizes.splashVersionBottom, 40, const [
    _JsRef('screens-auth.js', 33, 'position:absolute;bottom:40px'),
  ]),
  _css(
    'onboardingPaddingX',
    GuSizes.onboardingPaddingX,
    () => css.box('.onb-track>section', 'padding')[1],
    393,
    '.onb-track>section',
    'padding',
  ),
  _css(
    'onboardingGap',
    GuSizes.onboardingGap,
    () => css.px('.onb-track>section', 'gap'),
    393,
    '.onb-track>section',
    'gap',
  ),
  _css(
    'calendarGap',
    GuSizes.calendarGap,
    () => css.px('.cal-grid', 'gap'),
    313,
    '.cal-grid',
    'gap',
  ),
  _css(
    'calendarDayMinHeight',
    GuSizes.calendarDayMinHeight,
    () => css.px('.cal-day', 'min-height'),
    314,
    '.cal-day',
    'min-height',
  ),
  _js(
    'calendarDayMinHeightCompact',
    GuSizes.calendarDayMinHeightCompact,
    36,
    const [_JsRef('ui.js', 149, "minHeight: '36px'")],
  ),
  _css(
    'calendarDayGap',
    GuSizes.calendarDayGap,
    () => css.px('.cal-day', 'gap'),
    314,
    '.cal-day',
    'gap',
  ),
  _css(
    'calendarTodayRing',
    GuSizes.calendarTodayRing,
    () => css.box('.cal-day.is-today', 'box-shadow')[3],
    315,
    '.cal-day.is-today',
    'box-shadow',
  ),
  _css(
    'calendarDot',
    GuSizes.calendarDot,
    () => css.px('.cal-day .dots i', 'width'),
    316,
    '.cal-day .dots i',
    'width',
  ),
  _css(
    'calendarDotGap',
    GuSizes.calendarDotGap,
    () => css.px('.cal-day .dots', 'gap'),
    316,
    '.cal-day .dots',
    'gap',
  ),
  _css(
    'calendarDotsHeight',
    GuSizes.calendarDotsHeight,
    () => css.px('.cal-day .dots', 'height'),
    316,
    '.cal-day .dots',
    'height',
  ),
  _js('calendarDotsMax', GuSizes.calendarDotsMax, 3, const [
    _JsRef('ui.js', 149, 'Math.min(3, dotsFor(k))'),
  ]),
  _css(
    'calendarHeadPaddingY',
    GuSizes.calendarHeadPaddingY,
    () => css.box('.cal-head', 'padding')[0],
    317,
    '.cal-head',
    'padding',
  ),
  _js('calendarWeeks', GuSizes.calendarWeeks, 6, const [
    _JsRef('ui.js', 143, 'for (let i = 0; i < 42; i++)'),
  ]),
  // §8.6
  _css(
    'sheetMaxHeightRatio',
    GuSizes.sheetMaxHeightRatio,
    () => css.percent('.sheet', 'max-height'),
    268,
    '.sheet',
    'max-height',
  ),
  _css(
    'sheetMenuMaxHeightRatio',
    GuSizes.sheetMenuMaxHeightRatio,
    () => css.percent('.sheet.is-menu', 'max-height'),
    270,
    '.sheet.is-menu',
    'max-height',
  ),
  _css(
    'sheetFullHeightRatio',
    GuSizes.sheetFullHeightRatio,
    () => css.percent('.sheet-full', 'height'),
    278,
    '.sheet-full',
    'height',
  ),
  _css(
    'sheetHandleWidth',
    GuSizes.sheetHandleWidth,
    () => css.px('.sheet-handle', 'width'),
    271,
    '.sheet-handle',
    'width',
  ),
  _css(
    'sheetHandleHeight',
    GuSizes.sheetHandleHeight,
    () => css.px('.sheet-handle', 'height'),
    271,
    '.sheet-handle',
    'height',
  ),
  _css(
    'sheetHandleTop',
    GuSizes.sheetHandleTop,
    () => css.box('.sheet-handle', 'margin')[0],
    271,
    '.sheet-handle',
    'margin',
  ),
  _css(
    'sheetHeadMinHeight',
    GuSizes.sheetHeadMinHeight,
    () => css.px('.sheet-head', 'min-height'),
    272,
    '.sheet-head',
    'min-height',
  ),
  _css(
    'sheetHeadPaddingY',
    GuSizes.sheetHeadPaddingY,
    () => css.box('.sheet-head', 'padding')[0],
    272,
    '.sheet-head',
    'padding',
  ),
  _css(
    'sheetHeadPaddingLeft',
    GuSizes.sheetHeadPaddingLeft,
    () => css.box('.sheet-head', 'padding')[3],
    272,
    '.sheet-head',
    'padding',
  ),
  _css(
    'sheetHeadPaddingRight',
    GuSizes.sheetHeadPaddingRight,
    () => css.box('.sheet-head', 'padding')[1],
    272,
    '.sheet-head',
    'padding',
  ),
  _css(
    'sheetHeadGap',
    GuSizes.sheetHeadGap,
    () => css.px('.sheet-head', 'gap'),
    272,
    '.sheet-head',
    'gap',
  ),
  _css(
    'sheetBodyPaddingX',
    GuSizes.sheetBodyPaddingX,
    () => css.box('.sheet-body', 'padding')[1],
    274,
    '.sheet-body',
    'padding',
  ),
  _css(
    'sheetBodyPaddingBottom',
    GuSizes.sheetBodyPaddingBottom,
    () => css.box('.sheet-body', 'padding')[2],
    274,
    '.sheet-body',
    'padding',
  ),
  _css(
    'sheetBodyFlushPaddingBottom',
    GuSizes.sheetBodyFlushPaddingBottom,
    () => css.box('.sheet-body.is-flush', 'padding')[2],
    275,
    '.sheet-body.is-flush',
    'padding',
  ),
  _css(
    'sheetFootPaddingY',
    GuSizes.sheetFootPaddingY,
    () => css.box('.sheet-foot', 'padding')[0],
    276,
    '.sheet-foot',
    'padding',
  ),
  _css(
    'sheetFootPaddingX',
    GuSizes.sheetFootPaddingX,
    () => css.box('.sheet-foot', 'padding')[1],
    276,
    '.sheet-foot',
    'padding',
  ),
  _css(
    'sheetFootGap',
    GuSizes.sheetFootGap,
    () => css.px('.sheet-foot', 'gap'),
    276,
    '.sheet-foot',
    'gap',
  ),
  _css(
    'sheetFootBorder',
    GuSizes.sheetFootBorder,
    () => css.box('.sheet-foot', 'border-top')[0],
    276,
    '.sheet-foot',
    'border-top',
  ),
  _js('sheetDragCloseThreshold', GuSizes.sheetDragCloseThreshold, 120, const [
    _JsRef('ui.js', 173, 'if (dy > 120) close()'),
  ]),
  _js('viewerDragFadeDistance', GuSizes.viewerDragFadeDistance, 400, const [
    _JsRef('sheets.js', 160, '1 - dy / 400'),
  ]),
  _css(
    'sheetBorderDark',
    GuSizes.sheetBorderDark,
    () => css.box('.gu-root[data-theme="dark"] .sheet', 'border-top')[0],
    269,
    '.gu-root[data-theme="dark"] .sheet',
    'border-top',
  ),
  _css(
    'popMenuTop',
    GuSizes.popMenuTop,
    () => css.px('.popmenu', 'top'),
    279,
    '.popmenu',
    'top',
  ),
  _css(
    'popMenuRight',
    GuSizes.popMenuRight,
    () => css.px('.popmenu', 'right'),
    279,
    '.popmenu',
    'right',
  ),
  _css(
    'popMenuMinWidth',
    GuSizes.popMenuMinWidth,
    () => css.px('.popmenu', 'min-width'),
    279,
    '.popmenu',
    'min-width',
  ),
  _css(
    'popMenuPadding',
    GuSizes.popMenuPadding,
    () => css.box('.popmenu', 'padding')[0],
    279,
    '.popmenu',
    'padding',
  ),
  _css(
    'popMenuBorder',
    GuSizes.popMenuBorder,
    () => css.box('.popmenu', 'border')[0],
    279,
    '.popmenu',
    'border',
  ),
  _css(
    'popMenuTileMinHeight',
    GuSizes.popMenuTileMinHeight,
    () => css.px('.popmenu .tile', 'min-height'),
    280,
    '.popmenu .tile',
    'min-height',
  ),
  _css(
    'popMenuTilePaddingY',
    GuSizes.popMenuTilePaddingY,
    () => css.box('.popmenu .tile', 'padding')[0],
    280,
    '.popmenu .tile',
    'padding',
  ),
  _css(
    'popMenuTilePaddingX',
    GuSizes.popMenuTilePaddingX,
    () => css.box('.popmenu .tile', 'padding')[1],
    280,
    '.popmenu .tile',
    'padding',
  ),
  _css(
    'dialogMaxWidth',
    GuSizes.dialogMaxWidth,
    () => css.fn('.dialog', 'width', 'min'),
    282,
    '.dialog',
    'width',
  ),
  _css(
    'dialogMarginX',
    GuSizes.dialogMarginX,
    () => -css.fn('.dialog', 'width', 'min', arg: 1) / 2,
    282,
    '.dialog',
    'width',
  ),
  _css(
    'dialogPaddingTop',
    GuSizes.dialogPaddingTop,
    () => css.box('.dialog', 'padding')[0],
    282,
    '.dialog',
    'padding',
  ),
  _css(
    'dialogPaddingX',
    GuSizes.dialogPaddingX,
    () => css.box('.dialog', 'padding')[1],
    282,
    '.dialog',
    'padding',
  ),
  _css(
    'dialogPaddingBottom',
    GuSizes.dialogPaddingBottom,
    () => css.box('.dialog', 'padding')[2],
    282,
    '.dialog',
    'padding',
  ),
  _css(
    'dialogGap',
    GuSizes.dialogGap,
    () => css.px('.dialog', 'gap'),
    282,
    '.dialog',
    'gap',
  ),
  _css(
    'dialogMaxHeightRatio',
    GuSizes.dialogMaxHeightRatio,
    () => css.percent('.dialog', 'max-height'),
    282,
    '.dialog',
    'max-height',
  ),
  _css(
    'dialogActionsGap',
    GuSizes.dialogActionsGap,
    () => css.px('.dialog-actions', 'gap'),
    284,
    '.dialog-actions',
    'gap',
  ),
  _css(
    'dialogActionsTop',
    GuSizes.dialogActionsTop,
    () => css.px('.dialog-actions', 'margin-top'),
    284,
    '.dialog-actions',
    'margin-top',
  ),
  _css(
    'dialogIconBox',
    GuSizes.dialogIconBox,
    () => css.px('.notif-icon', 'width'),
    405,
    '.notif-icon',
    'width',
  ),
  _js('dialogIcon', GuSizes.dialogIcon, 20, const [
    _JsRef('ui.js', 186, r'name=${icon} size=${20}'),
  ]),
  _css(
    'toastMarginX',
    GuSizes.toastMarginX,
    () => css.px('.toast-wrap', 'left'),
    288,
    '.toast-wrap',
    'left',
  ),
  _css(
    'toastBottomExtra',
    GuSizes.toastBottomExtra,
    () => css.px('.toast-wrap', 'bottom'),
    288,
    '.toast-wrap',
    'bottom',
  ),
  _css(
    'toastPaddingTop',
    GuSizes.toastPaddingTop,
    () => css.box('.toast', 'padding')[0],
    290,
    '.toast',
    'padding',
  ),
  _css(
    'toastPaddingRight',
    GuSizes.toastPaddingRight,
    () => css.box('.toast', 'padding')[1],
    290,
    '.toast',
    'padding',
  ),
  _css(
    'toastPaddingBottom',
    GuSizes.toastPaddingBottom,
    () => css.box('.toast', 'padding')[2],
    290,
    '.toast',
    'padding',
  ),
  _css(
    'toastPaddingLeft',
    GuSizes.toastPaddingLeft,
    () => css.box('.toast', 'padding')[3],
    290,
    '.toast',
    'padding',
  ),
  _css(
    'toastGap',
    GuSizes.toastGap,
    () => css.px('.toast', 'gap'),
    290,
    '.toast',
    'gap',
  ),
  _css(
    'toastAccent',
    GuSizes.toastAccent,
    () => css.box('.toast', 'border-left')[0],
    290,
    '.toast',
    'border-left',
  ),
  _js('toastIcon', GuSizes.toastIcon, 18, const [
    _JsRef('shell.js', 21, r'name=${icon} size=${18}'),
  ]),
  _css(
    'toastActionHeight',
    GuSizes.toastActionHeight,
    () => css.px('.toast .toast-action', 'min-height'),
    293,
    '.toast .toast-action',
    'min-height',
  ),
  _css(
    'toastActionPaddingX',
    GuSizes.toastActionPaddingX,
    () => css.box('.toast .toast-action', 'padding')[1],
    293,
    '.toast .toast-action',
    'padding',
  ),
  _js('toastCloseButton', GuSizes.toastCloseButton, 32, const [
    _JsRef('shell.js', 21, 'width:32px;height:32px'),
  ]),
  _js('toastCloseIcon', GuSizes.toastCloseIcon, 16, const [
    _JsRef('shell.js', 21, r'name="x" size=${16}'),
  ]),
  _css(
    'bannerPaddingY',
    GuSizes.bannerPaddingY,
    () => css.box('.banner', 'padding')[0],
    248,
    '.banner',
    'padding',
  ),
  _css(
    'bannerPaddingX',
    GuSizes.bannerPaddingX,
    () => css.box('.banner', 'padding')[1],
    248,
    '.banner',
    'padding',
  ),
  _css(
    'bannerGap',
    GuSizes.bannerGap,
    () => css.px('.banner', 'gap'),
    248,
    '.banner',
    'gap',
  ),
  _js('bannerIcon', GuSizes.bannerIcon, 18, const [
    _JsRef('ui.js', 88, r'name=${icon || defIcon} size=${18}'),
  ]),
  _css(
    'bannerCardMarginX',
    GuSizes.bannerCardMarginX,
    () => css.box('.banner.is-card', 'margin')[1],
    249,
    '.banner.is-card',
    'margin',
  ),
  _js('bannerDismissIcon', GuSizes.bannerDismissIcon, 18, const [
    _JsRef('ui.js', 90, r'name="x" size=${18}'),
  ]),
  _js('refreshTriggerDistance', GuSizes.refreshTriggerDistance, 60, const [
    _JsRef('ui.js', 160, 'pull > 60'),
  ]),
  _js('refreshMaxPull', GuSizes.refreshMaxPull, 90, const [
    _JsRef('ui.js', 159, 'Math.min(90, dy * 0.6)'),
  ]),
  _js('refreshIndicatorHeight', GuSizes.refreshIndicatorHeight, 48, const [
    _JsRef('ui.js', 162, 'refreshing ? 48 : pull'),
  ]),
  _js('refreshPullFactor', GuSizes.refreshPullFactor, 0.6, const [
    _JsRef('ui.js', 159, 'Math.min(90, dy * 0.6)'),
  ]),
  _js('refreshIcon', GuSizes.refreshIcon, 20, const [
    _JsRef('ui.js', 162, r'name="arrow-up" size=${20}'),
  ]),
  // §8.7
  _icon('icon12', GuSizes.icon12, 12, js),
  _icon('icon14', GuSizes.icon14, 14, js),
  _icon('icon16', GuSizes.icon16, 16, js),
  _icon('icon18', GuSizes.icon18, 18, js),
  _icon('icon20', GuSizes.icon20, 20, js),
  _icon('icon22', GuSizes.icon22, 22, js),
  _icon('icon24', GuSizes.icon24, 24, js),
  _icon('icon30', GuSizes.icon30, 30, js),
  _icon('icon34', GuSizes.icon34, 34, js),
  _icon('icon36', GuSizes.icon36, 36, js),
  _icon('icon64', GuSizes.icon64, 64, js),
  // §8.9
  _js('iconButtonCountPaddingX', GuSizes.iconButtonCountPaddingX, 10, const [
    _JsRef(
      'cards.js',
      124,
      'style="width:auto;padding:0 10px;gap:6px;border-radius:12px"',
    ),
  ]),
  _js('iconButtonCountGap', GuSizes.iconButtonCountGap, 6, const [
    _JsRef(
      'cards.js',
      124,
      'style="width:auto;padding:0 10px;gap:6px;border-radius:12px"',
    ),
  ]),
  _js('postActionIcon', GuSizes.postActionIcon, 22, const [
    _JsRef('cards.js', 124, r'name="heart" size=${22}'),
  ]),
  _js('clubCardBodyPaddingTop', GuSizes.clubCardBodyPaddingTop, 10, const [
    _JsRef('cards.js', 32, 'style="padding:10px 12px 12px"'),
  ]),
  _js('clubCardBodyPaddingX', GuSizes.clubCardBodyPaddingX, 12, const [
    _JsRef('cards.js', 32, 'style="padding:10px 12px 12px"'),
  ]),
  _js(
    'clubCardBodyPaddingBottom',
    GuSizes.clubCardBodyPaddingBottom,
    12,
    const [_JsRef('cards.js', 32, 'style="padding:10px 12px 12px"')],
  ),
  _js('clubCardEmblemOffset', GuSizes.clubCardEmblemOffset, 10, const [
    _JsRef('cards.js', 31, 'position:absolute;left:10px;bottom:10px'),
  ]),
  _js('commentAvatar', GuSizes.commentAvatar, 32, const [
    _JsRef('sheets.js', 48, r'Avatar} user=${a} size=${32}'),
  ]),
  _js('applicationRowAvatar', GuSizes.applicationRowAvatar, 44, const [
    _JsRef('cards.js', 175, r'Avatar} user=${u} size=${44}'),
  ]),
  _js('postAvatar', GuSizes.postAvatar, 40, const [
    _JsRef('cards.js', 110, r'Avatar} user=${author} size=${40}'),
  ]),
  _js('iconButtonTonal', GuSizes.iconButtonTonal, 44, const [
    _JsRef('cards.js', 176, "width: '44px', height: '44px'"),
  ]),
  _js('myClubCardWidth', GuSizes.myClubCardWidth, 132, const [
    _JsRef('cards.js', 42, 'style="width:132px;text-align:left"'),
  ]),
  _js('applicationRowMinHeight', GuSizes.applicationRowMinHeight, 64, const [
    _JsRef('cards.js', 172, 'padding:6px 8px 6px 16px;min-height:64px'),
  ]),
  _js('avatarBadgeBorder', GuSizes.avatarBadgeBorder, 2, const [
    _JsRef('screens-profile.js', 11, 'border:2px solid var(--bg-canvas)'),
  ]),
  _js('parallaxEmblemOverlap', GuSizes.parallaxEmblemOverlap, 36, const [
    _JsRef('screens-clubs.js', 89, 'margin-top:-36px'),
  ]),
  _js('notificationSwipeDeadZone', GuSizes.notificationSwipeDeadZone, 8, const [
    _JsRef('cards.js', 145, 'Math.abs(d) > 8'),
  ]),
  _js(
    'notificationSwipeThreshold',
    GuSizes.notificationSwipeThreshold,
    90,
    const [_JsRef('cards.js', 146, 'if (dx < -90)')],
  ),
  _js('notificationSwipeMax', GuSizes.notificationSwipeMax, 140, const [
    _JsRef('cards.js', 145, 'Math.max(-140, Math.min(140, d))'),
  ]),
  _js('viewerZoomScale', GuSizes.viewerZoomScale, 1.8, const [
    _JsRef('sheets.js', 161, "transform: zoom && k === i ? 'scale(1.8)'"),
  ]),
  _js('applicationLeaveOffsetX', GuSizes.applicationLeaveOffsetX, 40, const [
    _JsRef(
      'screens-manage.js',
      57,
      "transform: leaving.includes(m.userId) ? 'translateX(40px)' : 'none'",
    ),
  ]),
  // §8.10
  _platform(
    'tapTargetIos',
    GuSizes.tapTargetIos,
    44,
    'D-22, K-03 — iOS etkin dokunma alanı ≥ 44 pt',
  ),
  _platform(
    'tapTargetAndroid',
    GuSizes.tapTargetAndroid,
    48,
    'D-22, K-03 — Android etkin dokunma alanı ≥ 48 dp',
  ),
];

List<_Row> _opacityTable(CssMeasure css) => [
  _css(
    'disabled',
    GuOpacity.disabled,
    () => css.number('.btn[aria-disabled="true"]', 'opacity'),
    149,
    '.btn[aria-disabled="true"]',
    'opacity',
  ),
  _css(
    'iconButtonDisabled',
    GuOpacity.iconButtonDisabled,
    () => css.number('.iconbtn[aria-disabled="true"]', 'opacity'),
    156,
    '.iconbtn[aria-disabled="true"]',
    'opacity',
  ),
  _css(
    'inputDisabled',
    GuOpacity.inputDisabled,
    () => css.number('.input.is-disabled', 'opacity'),
    165,
    '.input.is-disabled',
    'opacity',
  ),
  _css(
    'qrBlurred',
    GuOpacity.qrBlurred,
    () => css.number('.qr.is-blur svg', 'opacity'),
    327,
    '.qr.is-blur svg',
    'opacity',
  ),
  _js('miniChartFill', GuOpacity.miniChartFill, 0.6, const [
    _JsRef('ui.js', 137, 'opacity=".6"'),
  ]),
  _css(
    'tonalPressedBrightness',
    GuOpacity.tonalPressedBrightness,
    () => css.fn('.btn-tonal:hover', 'filter', 'brightness'),
    143,
    '.btn-tonal:hover',
    'filter',
  ),
  _css(
    'tonalPressedDarken',
    GuOpacity.tonalPressedDarken,
    () => 1 - css.fn('.btn-tonal:hover', 'filter', 'brightness'),
    143,
    '.btn-tonal:hover',
    'filter',
  ),
  _css(
    'dangerPressedDarken',
    GuOpacity.dangerPressedDarken,
    () => 1 - css.fn('.btn-danger:hover', 'filter', 'brightness'),
    147,
    '.btn-danger:hover',
    'filter',
  ),
  _js('coverIcon', GuOpacity.coverIcon, 0.12, const [
    _JsRef('art.js', 34, 'opacity=".12"'),
  ]),
];

/// Aynı değerin ikinci (eş) kaynakları: tabloda tek kaynak gösterilen
/// sabitlerin diğer CSS/JS tanımlarıyla tutarlılığı.
List<_Row> _secondarySources(CssMeasure css) => [
  _css(
    'buttonBorder ↔ .btn-danger-outline',
    GuSizes.buttonBorder,
    () => css.box('.btn-danger-outline', 'border')[0],
    146,
    '.btn-danger-outline',
    'border',
  ),
  _css(
    'focusRingWidth ↔ .btn.is-focus',
    GuSizes.focusRingWidth,
    () => css.box('.btn.is-focus', 'outline')[0],
    150,
    '.btn.is-focus',
    'outline',
  ),
  _css(
    'focusRingOffset ↔ .btn.is-focus',
    GuSizes.focusRingOffset,
    () => css.px('.btn.is-focus', 'outline-offset'),
    150,
    '.btn.is-focus',
    'outline-offset',
  ),
  _css(
    'spinner (yükseklik)',
    GuSizes.spinner,
    () => css.px('.spinner', 'height'),
    153,
    '.spinner',
    'height',
  ),
  _css(
    'spinner / 2 ↔ .btn .spinner merkez kaydırma',
    GuSizes.spinner / 2,
    () => -css.box('.btn .spinner', 'margin')[0],
    152,
    '.btn .spinner',
    'margin',
  ),
  _css(
    'iconButton (yükseklik)',
    GuSizes.iconButton,
    () => css.px('.iconbtn', 'height'),
    154,
    '.iconbtn',
    'height',
  ),
  _css(
    'iconButtonSm (yükseklik)',
    GuSizes.iconButtonSm,
    () => css.px('.iconbtn.is-sm', 'height'),
    156,
    '.iconbtn.is-sm',
    'height',
  ),
  _css(
    'fabMargin ↔ .fab bottom (safe + 16)',
    GuSizes.fabMargin,
    () => css.px('.fab', 'bottom'),
    158,
    '.fab',
    'bottom',
  ),
  _css(
    'ctaBarPaddingY ↔ alt dolgu (12 + safe)',
    GuSizes.ctaBarPaddingY,
    () => css.box('.ctabar', 'padding')[2],
    296,
    '.ctabar',
    'padding',
  ),
  _css(
    'ctaBarPaddingY ↔ .ctabar.in-nav',
    GuSizes.ctaBarPaddingY,
    () => css.px('.ctabar.in-nav', 'padding-bottom'),
    297,
    '.ctabar.in-nav',
    'padding-bottom',
  ),
  _css(
    'checkbox ↔ .radio',
    GuSizes.checkbox,
    () => css.px('.radio', 'height'),
    237,
    '.radio',
    'height',
  ),
  _css(
    'checkboxBorder ↔ .radio',
    GuSizes.checkboxBorder,
    () => css.box('.radio', 'border')[0],
    237,
    '.radio',
    'border',
  ),
  _css(
    'checkHitInset ↔ .radio::after (4 kenar)',
    <double>[
      GuSizes.checkHitInset,
      GuSizes.checkHitInset,
      GuSizes.checkHitInset,
      GuSizes.checkHitInset,
    ],
    () => css.box('.radio::after', 'inset').map((v) => -v).toList(),
    239,
    '.radio::after',
    'inset',
  ),
  _css(
    'switchThumb (yükseklik)',
    GuSizes.switchThumb,
    () => css.px('.switch>i', 'height'),
    234,
    '.switch>i',
    'height',
  ),
  _css(
    'switchThumbInset (sol)',
    GuSizes.switchThumbInset,
    () => css.px('.switch>i', 'left'),
    234,
    '.switch>i',
    'left',
  ),
  _css(
    'radioDot (yükseklik)',
    GuSizes.radioDot,
    () => css.px('.radio[aria-checked="true"]>i', 'height'),
    241,
    '.radio[aria-checked="true"]>i',
    'height',
  ),
  _css(
    'tabIndicatorInset (sağ)',
    GuSizes.tabIndicatorInset,
    () => css.px('.tabs>button[aria-selected="true"]::after', 'right'),
    228,
    '.tabs>button[aria-selected="true"]::after',
    'right',
  ),
  _css(
    'chipHitInset (4 kenar)',
    <double>[
      GuSizes.chipHitInset,
      GuSizes.chipHitInset,
      GuSizes.chipHitInset,
      GuSizes.chipHitInset,
    ],
    () => css.box('.chip::after', 'inset').map((v) => -v).toList(),
    179,
    '.chip::after',
    'inset',
  ),
  _css(
    'dot (yükseklik)',
    GuSizes.dot,
    () => css.px('.dot', 'height'),
    201,
    '.dot',
    'height',
  ),
  _css(
    'avatarGroupOverlap ↔ .avatar-group .more',
    GuSizes.avatarGroupOverlap,
    () => -css.px('.avatar-group .more', 'margin-left'),
    218,
    '.avatar-group .more',
    'margin-left',
  ),
  _css(
    'avatarGroupBorder ↔ .avatar-group .more',
    GuSizes.avatarGroupBorder,
    () => css.box('.avatar-group .more', 'border')[0],
    218,
    '.avatar-group .more',
    'border',
  ),
  _css(
    'emblem (yükseklik)',
    GuSizes.emblem,
    () => css.px('.emblem', 'height'),
    398,
    '.emblem',
    'height',
  ),
  _css(
    'emblemSm (yükseklik)',
    GuSizes.emblemSm,
    () => css.px('.emblem.is-sm', 'height'),
    399,
    '.emblem.is-sm',
    'height',
  ),
  _css(
    'emblemXs (yükseklik)',
    GuSizes.emblemXs,
    () => css.px('.emblem.is-xs', 'height'),
    400,
    '.emblem.is-xs',
    'height',
  ),
  _css(
    'notifIcon (yükseklik)',
    GuSizes.notifIcon,
    () => css.px('.notif-icon', 'height'),
    405,
    '.notif-icon',
    'height',
  ),
  _css(
    'timelineDot (yükseklik)',
    GuSizes.timelineDot,
    () => css.px('.timeline-dot', 'height'),
    310,
    '.timeline-dot',
    'height',
  ),
  _css(
    'ticketNotch (yükseklik)',
    GuSizes.ticketNotch,
    () => css.px('.ticket-cut::before', 'height'),
    325,
    '.ticket-cut::before',
    'height',
  ),
  _css(
    'ticketNotchOffset ↔ ::after right',
    GuSizes.ticketNotchOffset,
    () => -css.px('.ticket-cut::after', 'right'),
    325,
    '.ticket-cut::after',
    'right',
  ),
  _css(
    'qr (yükseklik)',
    GuSizes.qr,
    () => css.px('.qr', 'height'),
    326,
    '.qr',
    'height',
  ),
  _css(
    'scanBox (yükseklik)',
    GuSizes.scanBox,
    () => css.px('.scan-box', 'height'),
    402,
    '.scan-box',
    'height',
  ),
  _css(
    'scanCorner (yükseklik)',
    GuSizes.scanCorner,
    () => css.px('.scan-box>i', 'height'),
    403,
    '.scan-box>i',
    'height',
  ),
  _css(
    'scanLineInsetX (sağ)',
    GuSizes.scanLineInsetX,
    () => css.percent('.scanline', 'right'),
    335,
    '.scanline',
    'right',
  ),
  _css(
    'scanLineTopMin ↔ @keyframes scan 100%',
    GuSizes.scanLineTopMin,
    () => css.percent('@keyframes scan 100%', 'top'),
    422,
    '@keyframes scan 100%',
    'top',
  ),
  _css(
    'quickIconBox (yükseklik)',
    GuSizes.quickIconBox,
    () => css.px('.quick .quick-icon', 'height'),
    306,
    '.quick .quick-icon',
    'height',
  ),
  _css(
    'gridGap ↔ .grid3',
    GuSizes.gridGap,
    () => css.px('.grid3', 'gap'),
    110,
    '.grid3',
    'gap',
  ),
  _css(
    'pageDot (yükseklik)',
    GuSizes.pageDot,
    () => css.px('.dots>i', 'height'),
    394,
    '.dots>i',
    'height',
  ),
  _css(
    'calendarDot (yükseklik)',
    GuSizes.calendarDot,
    () => css.px('.cal-day .dots i', 'height'),
    316,
    '.cal-day .dots i',
    'height',
  ),
  _css(
    'sheetFootPaddingY ↔ alt dolgu (12 + safe)',
    GuSizes.sheetFootPaddingY,
    () => css.box('.sheet-foot', 'padding')[2],
    276,
    '.sheet-foot',
    'padding',
  ),
  _css(
    'dialogIconBox (yükseklik)',
    GuSizes.dialogIconBox,
    () => css.px('.notif-icon', 'height'),
    405,
    '.notif-icon',
    'height',
  ),
  _css(
    'toastMarginX (sağ)',
    GuSizes.toastMarginX,
    () => css.px('.toast-wrap', 'right'),
    288,
    '.toast-wrap',
    'right',
  ),
  _css(
    'toastBottomExtra ↔ .above-nav (nav-h + 12)',
    GuSizes.toastBottomExtra,
    () => css.px('.toast-wrap.above-nav', 'bottom'),
    289,
    '.toast-wrap.above-nav',
    'bottom',
  ),
  _css(
    'popMenuPadding (4 kenar)',
    <double>[
      GuSizes.popMenuPadding,
      GuSizes.popMenuPadding,
      GuSizes.popMenuPadding,
      GuSizes.popMenuPadding,
    ],
    () => css.box('.popmenu', 'padding'),
    279,
    '.popmenu',
    'padding',
  ),
  _css(
    'qrPadding (4 kenar)',
    <double>[
      GuSizes.qrPadding,
      GuSizes.qrPadding,
      GuSizes.qrPadding,
      GuSizes.qrPadding,
    ],
    () => css.box('.qr', 'padding'),
    326,
    '.qr',
    'padding',
  ),
  _css(
    'disabled ↔ .chip',
    GuOpacity.disabled,
    () => css.number('.chip[aria-disabled="true"]', 'opacity'),
    185,
    '.chip[aria-disabled="true"]',
    'opacity',
  ),
  _css(
    'disabled ↔ .tile',
    GuOpacity.disabled,
    () => css.number('.tile[aria-disabled="true"]', 'opacity'),
    213,
    '.tile[aria-disabled="true"]',
    'opacity',
  ),
  _css(
    'disabled ↔ .switch',
    GuOpacity.disabled,
    () => css.number('.switch[aria-disabled="true"]', 'opacity'),
    236,
    '.switch[aria-disabled="true"]',
    'opacity',
  ),
  _css(
    'disabled ↔ .check',
    GuOpacity.disabled,
    () => css.number('.check[aria-disabled="true"]', 'opacity'),
    242,
    '.check[aria-disabled="true"]',
    'opacity',
  ),
  _css(
    'disabled ↔ .radio',
    GuOpacity.disabled,
    () => css.number('.radio[aria-disabled="true"]', 'opacity'),
    242,
    '.radio[aria-disabled="true"]',
    'opacity',
  ),
  _js('disabled ↔ OptionRow satır içi', GuOpacity.disabled, 0.5, const [
    _JsRef('ui.js', 49, '{ opacity: .5 }'),
  ]),
  _js(
    'sheetDragCloseThreshold ↔ görüntüleyici',
    GuSizes.sheetDragCloseThreshold,
    120,
    const [_JsRef('sheets.js', 158, 'if (dy > 120) close()')],
  ),
  _js('postActionIcon ↔ yorum / kaydet', GuSizes.postActionIcon, 22, const [
    _JsRef('cards.js', 125, r'name="message-circle" size=${22}'),
    _JsRef('cards.js', 128, r'name="bookmark" size=${22}'),
  ]),
  _js(
    'notificationSwipeThreshold ↔ okundu yönü',
    GuSizes.notificationSwipeThreshold,
    90,
    const [_JsRef('cards.js', 146, 'else if (dx > 90)')],
  ),
  _js(
    'parallaxBarTopOffset ↔ .viewer üst satırı',
    GuSizes.parallaxBarTopOffset,
    4,
    const [
      _JsRef('sheets.js', 160, 'padding:calc(var(--safe-top) - 4px) 8px 0'),
    ],
  ),
  _js(
    'splashLogo / splashVersionBottom ↔ kabuk splash',
    GuSizes.splashLogo,
    96,
    [
      const _JsRef('shell.js', 35, r'Logo} size=${96}'),
      _JsRef('shell.js', 35, 'bottom:${GuSizes.splashVersionBottom.toInt()}px'),
    ],
  ),
];

void _runTable(List<_Row> rows, CssMeasure css, _Js js) {
  for (final row in rows) {
    test(row.description, () {
      expect(row.actual, _matches(row.expected()), reason: row.description);
      final ref = row.css;
      if (ref != null) {
        expect(
          css.line(ref.selector, ref.prop),
          ref.line,
          reason: '${row.name}: kaynak satırı css:${ref.line}',
        );
      }
      for (final r in row.js) {
        expect(
          js.line(r.file, r.line),
          contains(r.snippet),
          reason: '${row.name}: kaynak parçası ${r.label}',
        );
      }
    });
  }
}

void main() {
  final css = CssMeasure.load();
  final js = _Js();
  final sizes = _sizesTable(css, js);
  final opacity = _opacityTable(css);

  group('T-01 · GuSizes tablo sayımı (CD-97)', () {
    test('tablo uzunluğu N = $_gusizesCount', () {
      expect(sizes.length, _gusizesCount);
    });

    test('tablo adları benzersiz', () {
      final names = sizes.map((r) => r.name).toList();
      expect(names.toSet().length, names.length);
    });

    test('tablo == gu_sizes.dart sabitleri (eksik / fazla yok)', () {
      final declared = _declaredConstants('lib/src/tokens/gu_sizes.dart');
      expect(declared.length, _gusizesCount);
      expect(declared.toSet(), sizes.map((r) => r.name).toSet());
    });

    test('sayaç sabitleri int (tüketici imzaları)', () {
      expect(GuSizes.textareaRows, isA<int>());
      expect(GuSizes.avatarGroupMax, isA<int>());
      expect(GuSizes.calendarDotsMax, isA<int>());
      expect(GuSizes.calendarWeeks, isA<int>());
    });
  });

  group('T-01 · GuSizes §8 satırları', () => _runTable(sizes, css, js));

  group(
    'T-01 · GuSizes ikincil kaynaklar',
    () => _runTable(_secondarySources(css), css, js),
  );

  group('T-01 · GuSizes JS kümeleri ve türev tutarlılığı', () {
    test('§8.7 ikon sabitleri == prototip Icon size= kümesi', () {
      expect(js.iconSizes(), <double>[
        GuSizes.icon12,
        GuSizes.icon14,
        GuSizes.icon16,
        GuSizes.icon18,
        GuSizes.icon20,
        GuSizes.icon22,
        GuSizes.icon24,
        GuSizes.icon30,
        GuSizes.icon34,
        GuSizes.icon36,
        GuSizes.icon64,
      ]);
    });

    test(
      'amblem içi ikonlar: prototipteki tüm amblem ikon boyutları '
      'emblemIconSizes ile birebir (14 = PRF-01/02 kamera rozeti, CD-120)',
      () {
        final usages = js.emblemIconUsages();
        expect(
          usages.map((u) => u.size).toSet(),
          GuSizes.emblemIconSizes.toSet(),
        );
        final camera = usages
            .where((u) => u.size == GuSizes.icon14)
            .map((u) => '${u.file}:${u.line}')
            .toSet();
        expect(camera, {'screens-profile.js:11', 'screens-profile.js:28'});
      },
    );

    test('logoSizes: kabuk SideMenu 32 (shell.js:52) kümede yok (CD-90)', () {
      expect(js.callSizes('Logo'), containsAll(<double>[32]));
      expect(GuSizes.logoSizes, isNot(contains(32)));
      expect(GuSizes.logoSizes, contains(GuSizes.splashLogo));
    });

    test('ürün avatar sabitleri avatarSizes kümesinde', () {
      for (final size in <double>[
        GuSizes.avatar,
        GuSizes.commentAvatar,
        GuSizes.applicationRowAvatar,
        GuSizes.postAvatar,
        GuSizes.skeletonAvatar,
      ]) {
        expect(GuSizes.avatarSizes, contains(size));
      }
    });

    test('varsayılanlar kendi kümelerinde', () {
      expect(GuSizes.avatarGroupSizes, contains(GuSizes.avatarGroupSize));
      expect(
        GuSizes.illustrationSizes,
        containsAll(<double>[
          GuSizes.illustration,
          GuSizes.illustrationCompact,
        ]),
      );
    });

    test('türetilmiş ilişkiler', () {
      expect(
        GuSizes.wheelSpacer,
        (GuSizes.wheelHeight - GuSizes.wheelItemHeight) / 2,
      );
      expect(GuSizes.calendarWeeks * 7, 42);
      expect(
        GuSizes.switchThumbTravel,
        GuSizes.switchWidth -
            GuSizes.switchThumb -
            2 * GuSizes.switchThumbInset,
      );
      expect(GuSizes.switchWidth + 2 * GuSizes.switchHitInsetX, 52);
      expect(GuSizes.switchHeight + 2 * GuSizes.switchHitInsetY, 48);
      expect(GuSizes.checkbox + 2 * GuSizes.checkHitInset, 48);
    });
  });

  group('T-01 · GuOpacity (token-map §8.8)', () {
    test('tablo uzunluğu $_guOpacityCount; gu_opacity.dart ile aynı adlar', () {
      expect(opacity.length, _guOpacityCount);
      final declared = _declaredConstants('lib/src/tokens/gu_opacity.dart');
      expect(declared.length, _guOpacityCount);
      expect(declared.toSet(), opacity.map((r) => r.name).toSet());
    });

    test('tonalPressedBrightness + tonalPressedDarken = 1', () {
      expect(
        GuOpacity.tonalPressedBrightness + GuOpacity.tonalPressedDarken,
        closeTo(1, 1e-12),
      );
    });

    _runTable(opacity, css, js);
  });
}
