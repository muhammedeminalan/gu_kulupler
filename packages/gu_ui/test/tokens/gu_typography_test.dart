// T-01 · GuTypography — token-map §3. Ölçek registry + typography.json'dan,
// bileşen stilleri component-css.css `font:` bildirimlerinden (`CssMeasure`)
// OKUNUR; JS kaynaklı değerler (`splashTitle`, `ticketCode`, avatar/donut
// oranları) `dosya:satır` parçasıyla doğrulanır.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/src/tokens/gu_colors.dart';
import 'package:gu_ui/src/tokens/gu_component_colors.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/tokens/gu_typography.dart';

import '../helpers/css_measure.dart';
import '../helpers/design_sources.dart';
import '../helpers/theme_extension_sentinel.dart';

// ── CSS okuyucu (token-map §12: `font:` bildirimleri) ─────────────────────

final CssMeasure _css = CssMeasure.load();

/// `font: <ağırlık> <boyut>[/<satır>] <aile>` — `calc(Npx*var(--ts))` ya da
/// düz `Npx`; satır birimsiz ya da `px`.
final RegExp _fontRe = RegExp(
  r'^(\d+)\s+(?:calc\(([\d.]+)px\*var\(--ts\)\)|([\d.]+)px)'
  r'(?:\/([\d.]+)(px)?)?\s+([A-Za-z-]+)',
);

typedef _CssFont = ({int weight, double size, double? height, String family});

_CssFont _cssFont(String selector) {
  final m = _fontRe.firstMatch(_css.raw(selector, 'font'));
  expect(m, isNotNull, reason: '$selector `font:` biçimi tanınmadı');
  final size = double.parse(m!.group(2) ?? m.group(3)!);
  final line = m.group(4);
  final double? height;
  if (line == null) {
    height = null;
  } else if (m.group(5) == 'px') {
    height = double.parse(line) / size;
  } else {
    height = double.parse(line);
  }
  return (
    weight: int.parse(m.group(1)!),
    size: size,
    height: height,
    family: m.group(6)!,
  );
}

/// `font-size: calc(Npx*var(--ts))` (`.btn-sm`, `.btn-lg`).
double _cssFontSize(String selector) {
  final m = RegExp(
    r'^calc\(([\d.]+)px\*var\(--ts\)\)$',
  ).firstMatch(_css.raw(selector, 'font-size'));
  expect(m, isNotNull, reason: '$selector `font-size:` biçimi tanınmadı');
  return double.parse(m!.group(1)!);
}

/// Kuralın kendi `color:` değeri (son tanım); yoksa null.
String? _cssColor(String selector) =>
    _css.has(selector, 'color') ? _css.raw(selector, 'color') : null;

/// Renk zinciri: ilk `inherit` olmayan `color:` değeri (CSS kalıtımı).
String _cssColorFromChain(List<String> chain) {
  for (final selector in chain) {
    final value = _cssColor(selector);
    if (value != null && value != 'inherit') return value;
  }
  fail('Renk bulunamadı: $chain');
}

/// CSS renk değeri → beklenen ARGB (`var(--x-y)` → `reg.COLORS['x.y']`).
int _expectedArgb(String cssValue, int themeIndex) {
  final v = RegExp(r'^var\(--([a-z-]+)\)$').firstMatch(cssValue);
  if (v == null) return parseCssColor(cssValue);
  final parts = v.group(1)!.split('-');
  final key =
      '${parts.first}.${parts[1]}'
      '${parts.skip(2).map((p) => p[0].toUpperCase() + p.substring(1)).join()}';
  final colors = registryTokens()['COLORS'] as Map<String, dynamic>;
  final pair = colors[key] as List<dynamic>?;
  expect(pair, isNotNull, reason: 'registry rengi yok: $key ($cssValue)');
  return parseCssColor(pair![themeIndex] as String);
}

/// `em` cinsinden `letter-spacing` değeri (`.08em` → 0.08).
double _em(String raw) {
  final m = RegExp(r'^([\d.]+)em$').firstMatch(raw.trim());
  expect(m, isNotNull, reason: 'em değeri değil: $raw');
  return double.parse(m!.group(1)!);
}

/// 1 tabanlı JS satırı.
String _jsLine(String file, int line) =>
    prototypeJs(file).split('\n')[line - 1];

String _kebab(String camel) =>
    camel.replaceAllMapped(RegExp('[A-Z]'), (m) => '-${m[0]!.toLowerCase()}');

FontWeight _weight(int value) =>
    FontWeight.values.firstWhere((w) => w.value == value);

/// 43 alan, ad → stil (`copyWith` parametre adları, `props` sırası).
Map<String, Object?> _fields(GuTypography t) => {
  'display': t.display,
  'titleL': t.titleL,
  'titleM': t.titleM,
  'titleS': t.titleS,
  'bodyL': t.bodyL,
  'bodyM': t.bodyM,
  'bodyS': t.bodyS,
  'labelL': t.labelL,
  'labelM': t.labelM,
  'caption': t.caption,
  'overline': t.overline,
  'button': t.button,
  'buttonSm': t.buttonSm,
  'buttonLg': t.buttonLg,
  'chip': t.chip,
  'badge': t.badge,
  'countBadge': t.countBadge,
  'countBadgeLg': t.countBadgeLg,
  'fieldLabel': t.fieldLabel,
  'input': t.input,
  'fieldHelp': t.fieldHelp,
  'segment': t.segment,
  'tab': t.tab,
  'navLabel': t.navLabel,
  'banner': t.banner,
  'toast': t.toast,
  'swipeAction': t.swipeAction,
  'kpiValue': t.kpiValue,
  'dateBadgeDay': t.dateBadgeDay,
  'dateBadgeMonth': t.dateBadgeMonth,
  'calendarHead': t.calendarHead,
  'calendarDay': t.calendarDay,
  'wheel': t.wheel,
  'avatarMore': t.avatarMore,
  'quick': t.quick,
  'tooltip': t.tooltip,
  'mapPlaceholder': t.mapPlaceholder,
  'bannerAction': t.bannerAction,
  'splashTitle': t.splashTitle,
  'ticketCode': t.ticketCode,
  'toastAction': t.toastAction,
  'avatarInitialsBase': t.avatarInitialsBase,
  'donutValueBase': t.donutValueBase,
};

/// `_fields` yalnızca `TextStyle` değerleriyle.
Map<String, TextStyle> _styles(GuTypography t) =>
    _fields(t).map((k, v) => MapEntry(k, v! as TextStyle));

// ── Beklenti tabloları ────────────────────────────────────────────────────

typedef _Get = TextStyle Function(GuTypography t);

/// registry `TYPE_SCALE` id → alan.
final Map<String, _Get> _scale = {
  'display': (t) => t.display,
  'titleL': (t) => t.titleL,
  'titleM': (t) => t.titleM,
  'titleS': (t) => t.titleS,
  'bodyL': (t) => t.bodyL,
  'bodyM': (t) => t.bodyM,
  'bodyS': (t) => t.bodyS,
  'labelL': (t) => t.labelL,
  'labelM': (t) => t.labelM,
  'caption': (t) => t.caption,
  'overline': (t) => t.overline,
};

/// CSS bileşen stili (token-map §3.2): yazı seçicisi, aynı yazıyı taşıyan
/// diğer seçiciler, renk zinciri (CSS kalıtımı, kök `.gu-root`).
typedef _Comp = ({
  String field,
  _Get get,
  String font,
  String? sizeFrom,
  List<String> also,
  List<String> color,
});

final List<_Comp> _components = [
  (
    field: 'button',
    get: (t) => t.button,
    font: '.btn',
    sizeFrom: null,
    also: ['.fab'],
    color: ['.btn', '.gu-root'],
  ),
  (
    field: 'buttonSm',
    get: (t) => t.buttonSm,
    font: '.btn',
    sizeFrom: '.btn-sm',
    also: [],
    color: ['.btn-sm', '.btn', '.gu-root'],
  ),
  (
    field: 'buttonLg',
    get: (t) => t.buttonLg,
    font: '.btn',
    sizeFrom: '.btn-lg',
    also: [],
    color: ['.btn-lg', '.btn', '.gu-root'],
  ),
  (
    field: 'chip',
    get: (t) => t.chip,
    font: '.chip',
    sizeFrom: null,
    also: [],
    color: ['.chip'],
  ),
  (
    field: 'badge',
    get: (t) => t.badge,
    font: '.badge',
    sizeFrom: null,
    also: [],
    color: ['.badge', '.gu-root'],
  ),
  (
    field: 'countBadge',
    get: (t) => t.countBadge,
    font: '.nav-badge',
    sizeFrom: null,
    also: ['.iconbtn .dot-badge', '.chip .chip-count'],
    color: ['.nav-badge'],
  ),
  (
    field: 'countBadgeLg',
    get: (t) => t.countBadgeLg,
    font: '.badge-count',
    sizeFrom: null,
    also: [],
    color: ['.badge-count'],
  ),
  (
    field: 'fieldLabel',
    get: (t) => t.fieldLabel,
    font: '.field-label',
    sizeFrom: null,
    also: [],
    color: ['.field-label'],
  ),
  (
    field: 'input',
    get: (t) => t.input,
    font: '.input input',
    sizeFrom: null,
    also: ['.input textarea'],
    color: ['.input input'],
  ),
  (
    field: 'fieldHelp',
    get: (t) => t.fieldHelp,
    font: '.field-help',
    sizeFrom: null,
    also: ['.field-counter'],
    color: ['.field-help'],
  ),
  (
    field: 'segment',
    get: (t) => t.segment,
    font: '.seg>button',
    sizeFrom: null,
    also: [],
    color: ['.seg>button'],
  ),
  (
    field: 'tab',
    get: (t) => t.tab,
    font: '.tabs>button',
    sizeFrom: null,
    also: [],
    color: ['.tabs>button'],
  ),
  (
    field: 'navLabel',
    get: (t) => t.navLabel,
    font: '.bottomnav>button',
    sizeFrom: null,
    also: [],
    color: ['.bottomnav>button'],
  ),
  (
    field: 'banner',
    get: (t) => t.banner,
    font: '.banner',
    sizeFrom: null,
    also: [],
    color: ['.banner', '.gu-root'],
  ),
  (
    field: 'toast',
    get: (t) => t.toast,
    font: '.toast',
    sizeFrom: null,
    also: [],
    color: ['.toast'],
  ),
  (
    field: 'swipeAction',
    get: (t) => t.swipeAction,
    font: '.notif-under',
    sizeFrom: null,
    also: [],
    color: ['.notif-under'],
  ),
  (
    field: 'kpiValue',
    get: (t) => t.kpiValue,
    font: '.kpi .kpi-value',
    sizeFrom: null,
    also: [],
    color: ['.kpi .kpi-value'],
  ),
  (
    field: 'dateBadgeDay',
    get: (t) => t.dateBadgeDay,
    font: '.date-badge b',
    sizeFrom: null,
    also: [],
    color: ['.date-badge b', '.date-badge'],
  ),
  (
    field: 'dateBadgeMonth',
    get: (t) => t.dateBadgeMonth,
    font: '.date-badge span',
    sizeFrom: null,
    also: [],
    color: ['.date-badge span', '.date-badge'],
  ),
  (
    field: 'calendarHead',
    get: (t) => t.calendarHead,
    font: '.cal-head',
    sizeFrom: null,
    also: [],
    color: ['.cal-head'],
  ),
  (
    field: 'calendarDay',
    get: (t) => t.calendarDay,
    font: '.cal-day',
    sizeFrom: null,
    also: [],
    color: ['.cal-day'],
  ),
  (
    field: 'wheel',
    get: (t) => t.wheel,
    font: '.wheel>button',
    sizeFrom: null,
    also: [],
    color: ['.wheel>button'],
  ),
  (
    field: 'avatarMore',
    get: (t) => t.avatarMore,
    font: '.avatar-group .more',
    sizeFrom: null,
    also: [],
    color: ['.avatar-group .more'],
  ),
  (
    field: 'quick',
    get: (t) => t.quick,
    font: '.quick',
    sizeFrom: null,
    also: [],
    color: ['.quick'],
  ),
  (
    field: 'tooltip',
    get: (t) => t.tooltip,
    font: '.tooltip',
    sizeFrom: null,
    also: [],
    color: ['.tooltip'],
  ),
  (
    field: 'mapPlaceholder',
    get: (t) => t.mapPlaceholder,
    font: '.map-ph',
    sizeFrom: null,
    also: [],
    color: ['.map-ph'],
  ),
];

/// PLAN'a ek `bannerAction` (css:257 + `.btn` yazısı).
final _Comp _bannerAction = (
  field: 'bannerAction',
  get: (t) => t.bannerAction,
  font: '.btn',
  sizeFrom: null,
  also: [],
  color: ['.banner .btn-text', '.banner', '.gu-root'],
);

const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

final GuTypography _light = GuTypography.resolve(GuColors.light);
final GuTypography _dark = GuTypography.resolve(GuColors.dark);

void _expectFont(TextStyle style, _CssFont css, String reason) {
  expect(style.fontSize, css.size, reason: '$reason fontSize');
  expect(style.fontWeight, _weight(css.weight), reason: '$reason fontWeight');
  expect(style.fontFamily, css.family, reason: '$reason fontFamily');
  if (css.height == null) {
    expect(style.height, isNull, reason: '$reason height');
  } else {
    expect(
      style.height,
      closeTo(css.height!, 0.0005),
      reason: '$reason height',
    );
  }
}

/// C4 — sabit px `font`/`font-size` bildirimi olan CSS seçicileri →
/// `GuTypography` stili (K-57).
const Map<String, String> _fixedPxStyles = {
  '.nav-badge': 'countBadge',
  '.iconbtn .dot-badge': 'countBadge',
  '.chip .chip-count': 'countBadge',
  '.badge-count': 'countBadgeLg',
  '.avatar-group .more': 'avatarMore',
  '.cal-head': 'calendarHead',
  '.date-badge span': 'dateBadgeMonth',
  '.notif-under': 'swipeAction',
  '.tooltip': 'tooltip',
  '.map-ph': 'mapPlaceholder',
};

/// C4 — sabit px font kuralı olup uygulamaya girmeyen seçiciler (gerekçe).
const Map<String, String> _fixedPxExcluded = {
  '.statusbar': 'sahte durum çubuğu (D-20)',
  '.code': 'DEMO_PASSWORD mock (AUT-01, K-02)',
  '.pre': 'DEMO_PASSWORD mock (AUT-01, K-02)',
  '.sidemenu .menu-item': 'prototip vitrin kabuğu (site chrome css:345)',
  '.panel-row': 'prototip kontrol paneli (mock)',
  '.panel .seg>button': 'prototip kontrol paneli (mock)',
  '.panel .btn': 'prototip kontrol paneli (mock)',
  '.page-tabs>button': 'prototip sayfa sekmeleri (site chrome)',
  '.asset-card .asset-name': 'prototip varlık sayfası (site chrome)',
  '.asset-card .asset-actions .btn': 'prototip varlık sayfası (site chrome)',
  '.table': 'prototip QA tablosu (site chrome)',
  '.table th': 'prototip QA tablosu (site chrome)',
  '.flow-node': 'prototip akış haritası (site chrome)',
  '.demo-fab': 'Demo FAB (mock, CLAUDE.md §12)',
};

/// C4 — JS satır içi sabit px yazı boyutu: stil → (`dosya:satır`, parça).
const Map<String, (String, int, String)> _fixedPxJs = {
  'avatarInitialsBase': ('art.js', 46, "fontSize: fs + 'px'"),
  'avatarMore': (
    'art.js',
    50,
    "fontSize: Math.max(10, Math.round(size * 0.38)) + 'px'",
  ),
  'donutValueBase': ('ui.js', 93, r'font-size=${size / 4.5}'),
};

void main() {
  group('T-01 · GuTypography ölçek (reg.TYPE_SCALE, token-map §3.1)', () {
    final scale = (registryTokens()['TYPE_SCALE'] as List<dynamic>)
        .cast<Map<String, dynamic>>();

    test('registry TYPE_SCALE == typography.json#scale, 11 stil', () {
      expect(scale, hasLength(11));
      expect(typographyJson()['scale'], equals(scale));
      expect(scale.map((e) => e['id']).toSet(), _scale.keys.toSet());
    });

    for (final entry in scale) {
      final id = entry['id'] as String;
      test('$id — boyut/ağırlık/aile/height (registry)', () {
        final size = (entry['size'] as num).toDouble();
        final line = (entry['line'] as num).toDouble();
        for (final t in [_light, _dark]) {
          final style = _scale[id]!(t);
          expect(style.fontSize, size);
          expect(style.fontWeight, _weight(entry['weight'] as int));
          expect(style.fontFamily, entry['font']);
          // height = line / size, 4 ondalık.
          expect(style.height, closeTo(line / size, 0.00005));
          final ls = entry['letterSpacing'] as String?;
          final em = ls == null ? 0.0 : _em(ls);
          expect(style.letterSpacing, closeTo(em * size, 1e-9));
        }
      });

      test('$id — CSS `.t-${_kebab(id)}` satırı (css:87–97)', () {
        final css = _cssFont('.t-${_kebab(id)}');
        _expectFont(_scale[id]!(_light), css, id);
        _expectFont(_scale[id]!(_dark), css, id);
      });
    }

    test('overline — letterSpacing = CSS em × boyut (css:97), büyük harf', () {
      final em = _em(_css.raw('.t-overline', 'letter-spacing'));
      for (final t in [_light, _dark]) {
        expect(
          t.overline.letterSpacing,
          closeTo(em * t.overline.fontSize!, 1e-9),
        );
      }
      expect(_css.raw('.t-overline', 'text-transform'), 'uppercase');
    });

    test('aile sabitleri ve registry aileleri', () {
      expect(GuTypography.fontFamilyMontserrat, 'Montserrat');
      expect(GuTypography.fontFamilyInter, 'Inter');
      final fonts = typographyJson()['fonts'] as Map<String, dynamic>;
      expect(fonts['heading'], GuTypography.fontFamilyMontserrat);
      expect(fonts['body'], GuTypography.fontFamilyInter);
      expect(
        scale.map((e) => e['font']).toSet(),
        {GuTypography.fontFamilyMontserrat, GuTypography.fontFamilyInter},
      );
    });
  });

  group('T-01 · GuTypography CSS bileşen stilleri (token-map §3.2)', () {
    test('26 bileşen stili tabloda', () {
      expect(_components, hasLength(26));
      expect(_components.map((c) => c.field).toSet(), hasLength(26));
    });

    for (final c in [..._components, _bannerAction]) {
      test('${c.field} — `${c.sizeFrom ?? c.font}` font satırı', () {
        final base = _cssFont(c.font);
        final css = c.sizeFrom == null
            ? base
            : (
                weight: base.weight,
                size: _cssFontSize(c.sizeFrom!),
                height: base.height,
                family: base.family,
              );
        final expected = c.field == 'mapPlaceholder'
            // CD-19 / K-26: CSS `ui-monospace` → Inter (mono paketlenmez).
            ? (
                weight: css.weight,
                size: css.size,
                height: css.height,
                family: GuTypography.fontFamilyInter,
              )
            : css;
        for (final t in [_light, _dark]) {
          final style = c.get(t);
          _expectFont(style, expected, c.field);
          expect(style.letterSpacing, 0, reason: '${c.field} letterSpacing');
        }
        for (final other in c.also) {
          final o = _cssFont(other);
          expect(o.weight, css.weight, reason: '$other weight');
          expect(o.size, css.size, reason: '$other size');
          expect(o.family, css.family, reason: '$other family');
          if (o.height != null) {
            expect(o.height, closeTo(css.height!, 0.0005), reason: other);
          }
        }
      });
    }

    test(
      'mapPlaceholder — CSS ui-monospace, Flutter Inter + tabular (CD-19)',
      () {
        expect(_cssFont('.map-ph').family, 'ui-monospace');
        expect(_light.mapPlaceholder.fontFamily, 'Inter');
        expect(_light.mapPlaceholder.fontFeatures, _tabular);
      },
    );

    test('kpiValue — tabular-nums (css:303)', () {
      expect(
        _css.raw('.kpi .kpi-value', 'font-variant-numeric'),
        'tabular-nums',
      );
      expect(_light.kpiValue.fontFeatures, _tabular);
    });

    test('A4 türevleri: buttonSm/Lg = button.copyWith(fontSize) (css:141)', () {
      for (final t in [_light, _dark]) {
        expect(
          t.buttonSm,
          t.button.copyWith(fontSize: _cssFontSize('.btn-sm')),
        );
        expect(
          t.buttonLg,
          t.button.copyWith(fontSize: _cssFontSize('.btn-lg')),
        );
      }
    });

    test('bannerAction = button.copyWith(underline) (css:257)', () {
      expect(_css.raw('.banner .btn-text', 'text-decoration'), 'underline');
      for (final t in [_light, _dark]) {
        expect(t.bannerAction.decoration, TextDecoration.underline);
        expect(
          t.bannerAction,
          t.button.copyWith(decoration: TextDecoration.underline),
        );
      }
    });

    test('tabular yalnızca kpiValue, mapPlaceholder, ticketCode', () {
      final withTabular = {
        for (final e in _styles(_light).entries)
          if (e.value.fontFeatures != null) e.key,
      };
      expect(withTabular, {'kpiValue', 'mapPlaceholder', 'ticketCode'});
    });

    test('C3 — Inter 700 isteyen stiller == {countBadge, countBadgeLg, '
        'toastAction}; paketli olmayan tek ağırlık bu (D-12, K-56)', () {
      final inter700 = {
        for (final e in _styles(_light).entries)
          if (e.value.fontFamily == GuTypography.fontFamilyInter &&
              e.value.fontWeight == FontWeight.w700)
            e.key,
      };
      expect(inter700, {'countBadge', 'countBadgeLg', 'toastAction'});
      final fonts = typographyJson()['fonts'] as Map<String, dynamic>;
      final weights = fonts['weights'] as Map<String, dynamic>;
      final missing = {
        for (final e in _styles(_light).entries)
          if (!(weights[e.value.fontFamily] as List<dynamic>).contains(
            e.value.fontWeight!.value,
          ))
            e.key,
      };
      // css:137/157/186/200 `700 11px Inter`, css:293 `font-weight:700`;
      // Inter 700 paketli değil (D-12) → motor en yakın 600'ü çizer (K-56).
      expect(missing, inter700);
      expect(weights[GuTypography.fontFamilyInter], isNot(contains(700)));
    });
  });

  group('T-01 · GuTypography ek stiller (token-map §3.2 #27–30)', () {
    test('splashTitle = titleL + letterSpacing .04em × 22 (screens-auth.js:33, '
        'shell.js:35)', () {
      for (final (file, line) in [('screens-auth.js', 33), ('shell.js', 35)]) {
        final m = RegExp(
          r'class="t-title-l" style="letter-spacing:([\d.]+)em"',
        ).firstMatch(_jsLine(file, line));
        expect(m, isNotNull, reason: '$file:$line');
        final em = double.parse(m!.group(1)!);
        for (final t in [_light, _dark]) {
          final ls = em * t.titleL.fontSize!;
          expect(t.splashTitle.letterSpacing, closeTo(ls, 1e-9));
          expect(t.splashTitle, t.titleL.copyWith(letterSpacing: ls));
        }
      }
    });

    test('ticketCode = titleS + letterSpacing .12em × 16 + tabular '
        '(screens-events.js:83)', () {
      final m = RegExp(
        r'class="t-title-s tnum" style="letter-spacing:([\d.]+)em"',
      ).firstMatch(_jsLine('screens-events.js', 83));
      expect(m, isNotNull);
      final em = double.parse(m!.group(1)!);
      expect(_css.raw('.tnum', 'font-variant-numeric'), 'tabular-nums');
      for (final t in [_light, _dark]) {
        final ls = em * t.titleS.fontSize!;
        expect(t.ticketCode.letterSpacing, closeTo(ls, 1e-9));
        expect(
          t.ticketCode,
          t.titleS.copyWith(letterSpacing: ls, fontFeatures: _tabular),
        );
      }
    });

    test('C5 toastAction — `.toast` yazısı + `.toast-action` 700 (css:290, '
        '293; düğme font:inherit css:79; shell.js:21)', () {
      expect(_css.raw('.toast .toast-action', 'font-weight'), '700');
      expect(_css.line('.toast .toast-action', 'font-weight'), 293);
      expect(_css.line('.toast', 'font'), 290);
      expect(_css.raw('.gu-root :where(button)', 'font'), 'inherit');
      expect(
        _jsLine('shell.js', 21),
        contains('<button type="button" class="toast-action"'),
      );
      final toast = _cssFont('.toast');
      for (final t in [_light, _dark]) {
        _expectFont(
          t.toastAction,
          (
            weight: int.parse(_css.raw('.toast .toast-action', 'font-weight')),
            size: toast.size,
            height: toast.height,
            family: toast.family,
          ),
          'toastAction',
        );
        expect(t.toastAction.letterSpacing, 0);
        expect(t.toastAction, t.toast.copyWith(fontWeight: FontWeight.w700));
      }
    });

    test('C5 toastAction rengi = bgSurface = '
        'GuComponentColors.toastActionForeground (açık css:293 #fff; koyu '
        'CD-98)', () {
      for (final (c, comp, t) in [
        (GuColors.light, GuComponentColors.light, _light),
        (GuColors.dark, GuComponentColors.dark, _dark),
      ]) {
        expect(t.toastAction.color, c.bgSurface);
        expect(t.toastAction.color, comp.toastActionForeground);
      }
      expect(
        _light.toastAction.color!.toARGB32(),
        parseCssColor(_css.raw('.toast .toast-action', 'color')),
      );
    });
  });

  group('T-01 · GuTypography boyut türevleri (art.js:45/50, ui.js:93)', () {
    test('avatarInitialsFor — round(size × ratio) (art.js:45), '
        'letterSpacing .02em (css:217)', () {
      final ratio = double.parse(
        RegExp(
          r'const fs = Math\.round\(size \* ([\d.]+)\)',
        ).firstMatch(_jsLine('art.js', 45))!.group(1)!,
      );
      final em = _em(_css.raw('.avatar', 'letter-spacing'));
      expect(GuSizes.avatarInitialsRatio, ratio);
      expect(_css.raw('.avatar', 'font'), startsWith('700 1em Montserrat'));
      final sizes = {...GuSizes.avatarSizes, ...GuSizes.avatarGroupSizes};
      expect(sizes, isNotEmpty);
      for (final size in sizes) {
        final style = _light.avatarInitialsFor(size);
        final fontSize = (size * ratio).round().toDouble();
        expect(style.fontSize, fontSize, reason: 'size $size');
        expect(style.letterSpacing, closeTo(fontSize * em, 1e-9));
        expect(
          style,
          _light.avatarInitialsBase.copyWith(
            fontSize: fontSize,
            letterSpacing: fontSize * em,
          ),
        );
      }
      expect(_light.avatarInitialsBase.fontSize, isNull);
      expect(_light.avatarInitialsBase.fontFamily, 'Montserrat');
      expect(_light.avatarInitialsBase.fontWeight, FontWeight.w700);
    });

    test('A7 avatarMoreFor — max(min, round(size × ratio)) (art.js:50)', () {
      final m = RegExp(
        r'Math\.max\((\d+), Math\.round\(size \* ([\d.]+)\)\)',
      ).firstMatch(_jsLine('art.js', 50));
      expect(m, isNotNull);
      final minFont = double.parse(m!.group(1)!);
      final ratio = double.parse(m.group(2)!);
      expect(GuSizes.avatarMoreMinFont, minFont);
      expect(GuSizes.avatarMoreFontRatio, ratio);
      double expected(double size) {
        final scaled = (size * ratio).round().toDouble();
        return scaled > minFont ? scaled : minFont;
      }

      // GuSizes.avatarGroupSizes + alt sınırı (min) tetikleyen boyutlar.
      for (final size in {...GuSizes.avatarGroupSizes, 16.0, 20.0, 26.0}) {
        for (final t in [_light, _dark]) {
          final style = t.avatarMoreFor(size);
          expect(style.fontSize, expected(size), reason: 'size $size');
          expect(style, t.avatarMore.copyWith(fontSize: expected(size)));
        }
      }
      expect(_light.avatarMoreFor(20).fontSize, minFont);
    });

    test('donutValueFor — size / divisor, Montserrat 700, textHeading', () {
      final m = RegExp(
        r'font-family="Montserrat" font-weight="(\d+)" '
        r'font-size=\$\{size / ([\d.]+)\} fill="(var\(--[a-z-]+\))"',
      ).firstMatch(_jsLine('ui.js', 93));
      expect(m, isNotNull);
      final divisor = double.parse(m!.group(2)!);
      expect(GuSizes.donutValueDivisor, divisor);
      for (final size in <double>[72, GuSizes.donut, 120]) {
        final style = _dark.donutValueFor(size);
        expect(style.fontSize, closeTo(size / divisor, 1e-9));
        expect(style.fontFamily, 'Montserrat');
        expect(style.fontWeight, _weight(int.parse(m.group(1)!)));
        expect(style.color!.toARGB32(), _expectedArgb(m.group(3)!, 1));
      }
      expect(_light.donutValueBase.fontSize, isNull);
    });
  });

  group('T-01 · GuTypography.resolve renk bağlama (CSS `color:` zinciri)', () {
    for (final (index, name, t) in [(0, 'açık', _light), (1, 'koyu', _dark)]) {
      test('$name — 11 ölçek stili', () {
        for (final id in _scale.keys) {
          final value = _cssColorFromChain(['.t-${_kebab(id)}', '.gu-root']);
          expect(
            _scale[id]!(t).color!.toARGB32(),
            _expectedArgb(value, index),
            reason: '$id ← $value',
          );
        }
      });

      test('$name — 26 bileşen + bannerAction', () {
        for (final c in [..._components, _bannerAction]) {
          final value = _cssColorFromChain(c.color);
          expect(
            c.get(t).color!.toARGB32(),
            _expectedArgb(value, index),
            reason: '${c.field} ← $value',
          );
        }
      });

      test('$name — splashTitle, ticketCode, avatarInitialsBase', () {
        expect(
          t.splashTitle.color!.toARGB32(),
          _expectedArgb(_cssColorFromChain(['.t-title-l']), index),
        );
        expect(
          t.ticketCode.color!.toARGB32(),
          _expectedArgb(_cssColorFromChain(['.t-title-s']), index),
        );
        expect(
          t.avatarInitialsBase.color!.toARGB32(),
          _expectedArgb(_cssColorFromChain(['.avatar']), index),
        );
      });
    }

    test('A8 — avatarInitialsBase rengi = GuComponentColors.avatarInitials '
        '(iki tema)', () {
      expect(
        _light.avatarInitialsBase.color,
        GuComponentColors.light.avatarInitials,
      );
      expect(
        _dark.avatarInitialsBase.color,
        GuComponentColors.dark.avatarInitials,
      );
    });

    test('token bağları (GuColors alanları)', () {
      for (final (c, t) in [(GuColors.light, _light), (GuColors.dark, _dark)]) {
        expect(t.display.color, c.textHeading);
        expect(t.bodyM.color, c.textPrimary);
        expect(t.caption.color, c.textMuted);
        expect(t.overline.color, c.textMuted);
        expect(t.fieldLabel.color, c.textSecondary);
        expect(t.countBadge.color, c.brandOnPrimary);
        expect(t.swipeAction.color, c.brandOnPrimary);
        expect(t.toast.color, c.bgSurface);
        expect(t.toastAction.color, c.bgSurface);
        expect(t.tooltip.color, c.bgSurface);
        expect(t.dateBadgeDay.color, c.brandOnPrimaryContainer);
        expect(t.donutValueBase.color, c.textHeading);
        expect(t.avatarInitialsBase.color, c.brandOnPrimary);
      }
    });
  });

  group('T-01 · GuTypography ölçeklenmeyen stiller (C4, K-57)', () {
    bool fixedPx(String value) =>
        !value.contains('var(--ts)') && RegExp(r'\d+px').hasMatch(value);

    final fixed = [
      for (final d in _css.declarations)
        if ((d.prop == 'font' || d.prop == 'font-size') &&
            d.media == null &&
            fixedPx(d.value))
          d,
    ];

    test('CSS sabit px font kuralları == eşlenen ∪ kapsam dışı (yeni kural '
        'kırmızı)', () {
      expect(
        fixed.map((d) => d.selector).toSet(),
        {..._fixedPxStyles.keys, ..._fixedPxExcluded.keys},
      );
      expect(
        _fixedPxStyles.keys.toSet().intersection(_fixedPxExcluded.keys.toSet()),
        isEmpty,
      );
    });

    test('eşlenen kuralların satırları (css:137 … 410)', () {
      expect(
        {
          for (final d in fixed)
            if (_fixedPxStyles.containsKey(d.selector)) d.line,
        },
        {137, 157, 186, 200, 218, 317, 319, 337, 341, 410},
      );
    });

    test('JS satır içi sabit px yazı boyutları (art.js:46, :50, ui.js:93)', () {
      for (final e in _fixedPxJs.entries) {
        final (file, line, snippet) = e.value;
        expect(_jsLine(file, line), contains(snippet), reason: e.key);
      }
      // art.js:45 avatar baş harfi px boyutu (`--ts` yok).
      expect(_jsLine('art.js', 45), contains('const fs = Math.round(size *'));
    });

    test('nonScalingStyleNames == CSS eşlemesi ∪ JS eşlemesi', () {
      expect(GuTypography.nonScalingStyleNames, {
        ..._fixedPxStyles.values,
        ..._fixedPxJs.keys,
      });
      expect(
        _fields(_light).keys,
        containsAll(GuTypography.nonScalingStyleNames),
      );
    });

    test('tümleyen: CSS bileşen stili `var(--ts)` ile ölçekleniyorsa listede '
        'değil, sabit px ise listede', () {
      for (final c in [..._components, _bannerAction]) {
        final scales = _css.raw(c.font, 'font').contains('var(--ts)');
        expect(
          GuTypography.nonScalingStyleNames.contains(c.field),
          !scales,
          reason: '${c.field} (${c.font})',
        );
      }
      for (final id in _scale.keys) {
        expect(_css.raw('.t-${_kebab(id)}', 'font'), contains('var(--ts)'));
        expect(GuTypography.nonScalingStyleNames, isNot(contains(id)));
      }
      expect(_css.raw('.toast', 'font'), contains('var(--ts)'));
      expect(GuTypography.nonScalingStyleNames, isNot(contains('toastAction')));
    });
  });

  group('T-01 · GuTypography ThemeExtension (alanlar, eşitlik, lerp)', () {
    test('43 alan; props == _fields sırası; Equatable eşitliği', () {
      expect(_light.props, hasLength(43));
      expect(_light.props, _fields(_light).values.toList());
      expect(_light.props.whereType<TextStyle>(), hasLength(43));
      expect(GuTypography.resolve(GuColors.light), _light);
      expect(GuTypography.resolve(GuColors.light).hashCode, _light.hashCode);
      expect(_light, isNot(_dark));
    });

    test('her alan Montserrat ya da Inter, yedek sans-serif', () {
      for (final style in _light.props.cast<TextStyle>()) {
        expect(
          style.fontFamily,
          anyOf(
            GuTypography.fontFamilyMontserrat,
            GuTypography.fontFamilyInter,
          ),
        );
        expect(style.fontFamilyFallback, ['sans-serif']);
      }
    });

    test('C9 — tüm stiller ve *For türevleri leadingDistribution.even', () {
      for (final t in [_light, _dark]) {
        for (final e in _styles(t).entries) {
          expect(
            e.value.leadingDistribution,
            TextLeadingDistribution.even,
            reason: e.key,
          );
        }
        expect(
          t.avatarInitialsFor(40).leadingDistribution,
          TextLeadingDistribution.even,
        );
        expect(
          t.avatarMoreFor(28).leadingDistribution,
          TextLeadingDistribution.even,
        );
        expect(
          t.donutValueFor(96).leadingDistribution,
          TextLeadingDistribution.even,
        );
      }
    });

    test('lerp(0) == bu, lerp(1) == diğeri (gerçek temalar)', () {
      expect(_light.lerp(_dark, 0), _light);
      expect(_light.lerp(_dark, 1), _dark);
    });

    test('ThemeData.extension<GuTypography>() ile okunur', () {
      final theme = ThemeData(extensions: [_dark]);
      expect(theme.extension<GuTypography>(), same(_dark));
      expect(_dark.type, GuTypography);
    });
  });

  registerSentinelTests<GuTypography>(
    name: 'GuTypography',
    original: _light,
    fields: _fields,
    sentinel: (field, i, salt) => TextStyle(fontSize: i + 1.0 + salt * 100),
    lerpField: (field, a, b, t) =>
        TextStyle.lerp(a as TextStyle?, b as TextStyle?, t),
  );
}
