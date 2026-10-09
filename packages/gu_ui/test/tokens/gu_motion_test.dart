import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/src/tokens/gu_motion.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';

import '../helpers/css_measure.dart';
import '../helpers/design_sources.dart';

const String _lightRoot = '.gu-root[data-theme="light"]';

/// CSS `<easing-function>` anahtar kelimeleri.
const Set<String> _easingKeywords = {
  'linear',
  'ease',
  'ease-in',
  'ease-out',
  'ease-in-out',
  'step-start',
  'step-end',
};

/// `transition`/`animation` listesinin bir öğesi zamanlama fonksiyonu
/// içeriyor mu (`var(--ease-*)`, `cubic-bezier(…)`, `steps(…)`, anahtar
/// kelime)?
bool _hasTiming(String item) => CssMeasure.splitTokens(item).any(
  (t) =>
      t.startsWith('var(--ease-') ||
      t.startsWith('cubic-bezier(') ||
      t.startsWith('steps(') ||
      _easingKeywords.contains(t),
);

/// Değer (`!important` kırpılır) zamanlama fonksiyonu yazılmamış en az bir
/// öğe içeriyor mu? `none` geçiş/animasyon yok sayılır.
bool _lacksTiming(String value) {
  final v = value.replaceFirst(RegExp(r'\s*!important$'), '').trim();
  if (v == 'none') return false;
  return CssMeasure.splitList(v).any((item) => !_hasTiming(item));
}

/// Prototip JS'teki `transition:` değerleri: nesne biçimi
/// (`transition: 'opacity .25s, …'`, `transition: c ? 'height .2s' : 'none'`)
/// ve satır içi CSS (`style="transition:stroke-dasharray .6s …"`).
List<({String label, String value})> _jsTransitions(String file) {
  final out = <({String label, String value})>[];
  final lines = prototypeJs(file).split('\n');
  for (var n = 0; n < lines.length; n++) {
    final line = lines[n];
    for (final m in RegExp(r'(?<![\w-])transition:\s*').allMatches(line)) {
      final rest = line.substring(m.end);
      final label = '$file:${n + 1}';
      if (rest.startsWith("'") || RegExp(r'^[\w.]+\s*\?').hasMatch(rest)) {
        // JS ifadesi: üst düzey `,` ya da `}`'e kadar; içindeki dizgeler.
        final expr = _jsExpression(rest);
        for (final lit in RegExp("'([^']*)'").allMatches(expr)) {
          out.add((label: label, value: lit.group(1)!));
        }
      } else {
        final end = RegExp('[;"\'}]').firstMatch(rest);
        out.add((
          label: label,
          value: end == null ? rest : rest.substring(0, end.start),
        ));
      }
    }
  }
  return out;
}

/// `s`'nin başındaki JS ifadesi (tırnak ve parantez içi `,`/`}` bölmez).
String _jsExpression(String s) {
  var depth = 0;
  String? quote;
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (quote != null) {
      if (c == quote) quote = null;
    } else if (c == "'" || c == '"' || c == '`') {
      quote = c;
    } else if (c == '(' || c == '[' || c == '{') {
      depth++;
    } else if (c == ')' || c == ']' || c == '}') {
      if (depth == 0) return s.substring(0, i);
      depth--;
    } else if (c == ',' && depth == 0) {
      return s.substring(0, i);
    }
  }
  return s;
}

/// CSS süre dizesi (`.8s`, `1.2s`, `120ms`) → `Duration`.
Duration cssDuration(String raw) {
  final m = RegExp(r'^([\d.]+)(ms|s)$').firstMatch(raw.trim());
  expect(m, isNotNull, reason: 'CSS süresi ayrıştırılamadı: $raw');
  final n = double.parse(m!.group(1)!);
  final ms = m.group(2) == 's' ? n * 1000 : n;
  return Duration(milliseconds: ms.round());
}

/// `cubic-bezier(a,b,c,d)` → `Cubic`.
Cubic cssCubic(String raw) {
  final m = RegExp(
    r'cubic-bezier\(([\d.]+),([\d.]+),([\d.]+),([\d.]+)\)',
  ).firstMatch(raw);
  expect(m, isNotNull, reason: 'cubic-bezier ayrıştırılamadı: $raw');
  return Cubic(
    double.parse(m!.group(1)!),
    double.parse(m.group(2)!),
    double.parse(m.group(3)!),
    double.parse(m.group(4)!),
  );
}

void expectCubic(Cubic actual, Cubic expected) {
  expect(actual.a, expected.a);
  expect(actual.b, expected.b);
  expect(actual.c, expected.c);
  expect(actual.d, expected.d);
}

void main() {
  late Map<String, dynamic> registryMotion;
  final css = CssMeasure.load();

  setUpAll(() {
    registryMotion = registryTokens()['MOTION'] as Map<String, dynamic>;
  });

  /// `selector` kuralındaki `animation:` değeri, boşlukla bölünmüş.
  List<String> animationOf(String selector) =>
      css.tokens(selector, 'animation');

  /// `@keyframes name` tanımlı mı (adım seçicileri `@keyframes <ad> <adım>`).
  void expectKeyframes(String name) =>
      expect(css.keyframes, contains(name), reason: '@keyframes $name');

  group('T-01 · GuMotion registry (reg.MOTION, 5)', () {
    test('registry 5 anahtar; tokens.json#motion eşit', () {
      expect(registryMotion.keys.toSet(), {
        'fast',
        'base',
        'slow',
        'easeStandard',
        'easeEmphasized',
      });
      expect(tokensJson()['motion'], registryMotion);
    });

    test('fast/base/slow ms', () {
      expect(GuMotion.fast.inMilliseconds, registryMotion['fast']);
      expect(GuMotion.base.inMilliseconds, registryMotion['base']);
      expect(GuMotion.slow.inMilliseconds, registryMotion['slow']);
    });

    test('easeStandard / easeEmphasized cubic-bezier', () {
      expectCubic(
        GuMotion.easeStandard,
        cssCubic(registryMotion['easeStandard'] as String),
      );
      expectCubic(
        GuMotion.easeEmphasized,
        cssCubic(registryMotion['easeEmphasized'] as String),
      );
      expect(
        GuMotion.easeStandard.transform(0.5),
        closeTo(const Cubic(0.2, 0, 0, 1).transform(0.5), 1e-9),
      );
    });

    test('CSS --motion-* / --ease-* değişkenleri registry ile eşit', () {
      for (final key in ['fast', 'base', 'slow']) {
        expect(
          cssDuration(css.raw(_lightRoot, '--motion-$key')).inMilliseconds,
          registryMotion[key],
          reason: '--motion-$key',
        );
      }
      expectCubic(
        GuMotion.easeStandard,
        cssCubic(css.raw(_lightRoot, '--ease-standard')),
      );
      expectCubic(
        GuMotion.easeEmphasized,
        cssCubic(css.raw(_lightRoot, '--ease-emphasized')),
      );
    });
  });

  group('T-01 · GuMotion CSS-derived (keyframe/animation)', () {
    test('spin = .spinner 800 ms linear sonsuz (css:153)', () {
      final a = animationOf('.spinner');
      expect(a, ['spin', a[1], 'linear', 'infinite']);
      expect(GuMotion.spin, cssDuration(a[1]));
      expect(GuMotion.spinCurve, Curves.linear);
      expectKeyframes('spin');
    });

    test('shimmer = .sk 1200 ms linear sonsuz (css:263)', () {
      final a = animationOf('.sk');
      expect(a, ['shimmer', a[1], 'linear', 'infinite']);
      expect(GuMotion.shimmer, cssDuration(a[1]));
      expect(GuMotion.shimmerCurve, Curves.linear);
      expectKeyframes('shimmer');
    });

    test('circleDraw = .circle-draw 500 ms standard (css:333)', () {
      final a = animationOf('.circle-draw');
      expect(a, ['draw', a[1], 'var(--ease-standard)', 'forwards']);
      expect(GuMotion.circleDraw, cssDuration(a[1]));
    });

    test('checkDraw = slow, gecikme 200 ms (css:332)', () {
      final a = animationOf('.check-draw');
      expect(a, [
        'draw',
        'var(--motion-slow)',
        a[2],
        'var(--ease-standard)',
        'forwards',
      ]);
      expect(GuMotion.checkDraw, GuMotion.slow);
      expect(GuMotion.checkDrawDelay, cssDuration(a[2]));
    });

    test('shake = 400 ms + offsets @keyframes shake (css:334, 421)', () {
      final a = animationOf('.shake');
      expect(a, ['shake', a[1], 'var(--ease-standard)']);
      expect(GuMotion.shake, cssDuration(a[1]));
      expectKeyframes('shake');
      double step(String pct) =>
          css.fn('@keyframes shake $pct', 'transform', 'translateX');
      expect(css.raw('@keyframes shake 0%', 'transform'), 'none');
      expect(css.raw('@keyframes shake 100%', 'transform'), 'none');
      expect(GuMotion.shakeOffsets, [
        0,
        step('20%'),
        step('40%'),
        step('60%'),
        step('80%'),
        0,
      ]);
    });

    test('scan = .scanline 2200 ms ease-in-out sonsuz (css:335)', () {
      final a = animationOf('.scanline');
      expect(a, ['scan', a[1], 'ease-in-out', 'infinite']);
      expect(GuMotion.scan, cssDuration(a[1]));
      // CSS `ease-in-out` = cubic-bezier(.42,0,.58,1) = Curves.easeInOut.
      expect(GuMotion.scanCurve, Curves.easeInOut);
      expectCubic(GuMotion.scanCurve as Cubic, const Cubic(0.42, 0, 0.58, 1));
      expectKeyframes('scan');
    });

    test('splash = .splash .logo 1200 ms emphasized (css:392)', () {
      final a = animationOf('.splash .logo');
      expect(a, ['splash', a[1], 'var(--ease-emphasized)']);
      expect(GuMotion.splash, cssDuration(a[1]));
      expectKeyframes('splash');
    });

    test('splashOut 300 ms, gecikme 1300 ms (css:425)', () {
      final a = animationOf('.splash-overlay');
      expect(a, ['splashOut', a[1], a[2], 'var(--ease-standard)', 'forwards']);
      expect(GuMotion.splashOut, cssDuration(a[1]));
      expect(GuMotion.splashOutDelay, cssDuration(a[2]));
    });

    test('highlight = .card.is-highlight 1500 ms (css:208)', () {
      final a = animationOf('.card.is-highlight');
      expect(a, ['highlight', a[1], 'var(--ease-standard)']);
      expect(GuMotion.highlight, cssDuration(a[1]));
      expectKeyframes('highlight');
    });

    test('fill = .poll-fill width .6s (css:329) + Donut ui.js:93', () {
      final t = css.tokens('.poll-opt .poll-fill', 'transition');
      expect(t, ['width', t[1], 'var(--ease-standard)']);
      expect(GuMotion.fill, cssDuration(t[1]));
      final donut = RegExp(
        r'transition:stroke-dasharray ([\d.]+s)',
      ).firstMatch(prototypeJs('ui.js'))!;
      expect(GuMotion.fill, cssDuration(donut.group(1)!));
    });

    test('pressScale = .btn:active / .pressable:active (css:140, 340)', () {
      for (final selector in [
        '.btn:active:not([aria-disabled="true"])',
        '.btn.is-pressed',
        '.pressable:active',
      ]) {
        expect(
          GuMotion.pressScale,
          css.fn(selector, 'transform', 'scale'),
          reason: selector,
        );
      }
    });

    test('cardPressScale = .card.is-tappable:active (css:206)', () {
      expect(
        GuMotion.cardPressScale,
        css.fn('.card.is-tappable:active', 'transform', 'scale'),
      );
    });

    test('heartPopScale = @keyframes pop %40 (css:419)', () {
      expect(
        GuMotion.heartPopScale,
        css.fn('@keyframes pop 40%', 'transform', 'scale'),
      );
      expect(animationOf('.heart.is-liked'), [
        'pop',
        'var(--motion-slow)',
        'var(--ease-emphasized)',
      ]);
    });

    test('dialogEnterScale = @keyframes dialogIn from (css:415)', () {
      expect(
        GuMotion.dialogEnterScale,
        css.fn('@keyframes dialogIn from', 'transform', 'scale'),
      );
    });

    test('toastEnterOffsetY = @keyframes toastIn from (css:416)', () {
      expect(
        GuMotion.toastEnterOffsetY,
        css.fn('@keyframes toastIn from', 'transform', 'translateY'),
      );
    });

    test('pushEnterOffsetX = pushIn 16 / popIn −16 (css:412–413)', () {
      expect(
        GuMotion.pushEnterOffsetX,
        css.fn('@keyframes pushIn from', 'transform', 'translateX'),
      );
      expect(
        -GuMotion.pushEnterOffsetX,
        css.fn('@keyframes popIn from', 'transform', 'translateX'),
      );
    });

    test('sheetEnter = .sheet sheetIn slow emphasized (css:268, 414)', () {
      expect(animationOf('.sheet'), [
        'sheetIn',
        'var(--motion-slow)',
        'var(--ease-emphasized)',
      ]);
      expect(GuMotion.sheetEnter, GuMotion.slow);
      expect(
        css.raw('@keyframes sheetIn from', 'transform'),
        'translateY(100%)',
      );
    });
  });

  group('T-01 · GuMotion.easeCss — eğrisi yazılmamış geçişler (C2)', () {
    /// token-map §7 `easeCss` satırı ile aynı liste.
    const cssLines = {
      134,
      139,
      154,
      163,
      176,
      206,
      221,
      226,
      231,
      237,
      267,
      340,
      394,
      409,
      427,
    };

    /// token-map §7 `easeCss` satırı: JS `transition` dizgeleri.
    const jsLabels = ['screens-manage.js:57', 'ui.js:162', 'ui.js:162'];

    test('easeCss = CSS `ease` = cubic-bezier(.25,.1,.25,1) = Curves.ease', () {
      expectCubic(GuMotion.easeCss, const Cubic(0.25, 0.1, 0.25, 1));
      expectCubic(GuMotion.easeCss, Curves.ease);
    });

    test('component-css.css: zamanlama fonksiyonu olmayan transition/animation '
        'satırları == token-map listesi', () {
      final lines = {
        for (final d in css.declarations)
          if ((d.prop == 'transition' || d.prop == 'animation') &&
              _lacksTiming(d.value))
            d.line,
      };
      expect(lines, cssLines);
    });

    test(
      'örnekler: switch rayı easeCss, topuzu easeStandard (css:231/234)',
      () {
        expect(_lacksTiming(css.raw('.switch', 'transition')), isTrue);
        expect(css.tokens('.switch>i', 'transition'), [
          'transform',
          'var(--motion-base)',
          'var(--ease-standard)',
        ]);
        // Zamanlamalı bildirimler listede değil.
        expect(_lacksTiming(css.raw('.sheet', 'animation')), isFalse);
        expect(_lacksTiming(css.raw('.spinner', 'animation')), isFalse);
        expect(_lacksTiming('none'), isFalse);
        expect(_lacksTiming('background .1s,color .1s ease'), isTrue);
      },
    );

    test('prototip JS: zamanlama fonksiyonu olmayan transition dizgeleri', () {
      final all = [for (final f in prototypeAppFiles) ..._jsTransitions(f)];
      // Okuyucu zamanlamalı örnekleri de görür (ui.js:93, sheets.js:161).
      expect(
        all.map((t) => t.label),
        containsAll(<String>['ui.js:93', 'sheets.js:161']),
      );
      final missing = [
        for (final t in all)
          if (_lacksTiming(t.value)) t.label,
      ]..sort();
      expect(missing, jsLabels);
    });
  });

  group('T-01 · GuMotion JS-derived (sabit beklenti + JS kaynağı)', () {
    test('toastDefault 4000 / toastUndo 6000 (core.js:567; CD-24)', () {
      expect(GuMotion.toastDefault, const Duration(milliseconds: 4000));
      expect(GuMotion.toastUndo, const Duration(milliseconds: 6000));
      final m = RegExp(
        r'props\.undo \|\| props\.action \? (\d+) : (\d+)',
      ).firstMatch(prototypeJs('core.js'))!;
      expect(GuMotion.toastUndo.inMilliseconds, int.parse(m.group(1)!));
      expect(GuMotion.toastDefault.inMilliseconds, int.parse(m.group(2)!));
    });

    test('countdownTick 1 s (core.js:658; CD-97)', () {
      expect(GuMotion.countdownTick, const Duration(seconds: 1));
      final m = RegExp(
        r'function useCountdown[^\n]*setInterval\([^\n]*?, (\d+)\)',
      ).firstMatch(prototypeJs('core.js'))!;
      expect(GuMotion.countdownTick.inMilliseconds, int.parse(m.group(1)!));
    });

    test('longPress 550 ms (cards.js:144; K-46)', () {
      expect(GuMotion.longPress, const Duration(milliseconds: 550));
      final m = RegExp(
        r'setMenu\(true\); moved\.current = true; \}, (\d+)\)',
      ).firstMatch(prototypeJs('cards.js'))!;
      expect(GuMotion.longPress.inMilliseconds, int.parse(m.group(1)!));
    });

    test('heartPopReset 400 ms (cards.js:100; K-46)', () {
      expect(GuMotion.heartPopReset, const Duration(milliseconds: 400));
      final m = RegExp(
        r'setTimeout\(\(\) => setPopped\(false\), (\d+)\)',
      ).firstMatch(prototypeJs('cards.js'))!;
      expect(GuMotion.heartPopReset.inMilliseconds, int.parse(m.group(1)!));
    });

    test('applicationLeave 250 ms (screens-manage.js:48, :57; K-46)', () {
      expect(GuMotion.applicationLeave, const Duration(milliseconds: 250));
      final js = prototypeJs('screens-manage.js');
      final timeout = RegExp(
        r"app\.toast\('TST-27'[^\n]*?\}, (\d+)\);",
      ).firstMatch(js)!;
      expect(
        GuMotion.applicationLeave.inMilliseconds,
        int.parse(timeout.group(1)!),
      );
      final transition = RegExp(
        r"transition: 'opacity ([\d.]+s), transform ([\d.]+s)'",
      ).firstMatch(js)!;
      expect(GuMotion.applicationLeave, cssDuration(transition.group(1)!));
      expect(GuMotion.applicationLeave, cssDuration(transition.group(2)!));
    });

    test('viewerDoubleTap 300 ms (sheets.js:159; K-46)', () {
      expect(GuMotion.viewerDoubleTap, const Duration(milliseconds: 300));
      final m = RegExp(
        r'now - lastTap\.current < (\d+)',
      ).firstMatch(prototypeJs('sheets.js'))!;
      expect(GuMotion.viewerDoubleTap.inMilliseconds, int.parse(m.group(1)!));
    });

    test('viewerZoom 300 ms emphasized (sheets.js:161; K-46)', () {
      expect(GuMotion.viewerZoom, const Duration(milliseconds: 300));
      final line = prototypeJs('sheets.js').split('\n')[161 - 1];
      expect(line, contains("transform: zoom && k === i ? 'scale(1.8)'"));
      final m = RegExp(
        r"transition: 'transform ([\d.]+s) (var\(--ease-[a-z]+\))'",
      ).firstMatch(line);
      expect(m, isNotNull);
      expect(GuMotion.viewerZoom, cssDuration(m!.group(1)!));
      expect(m.group(2), 'var(--ease-emphasized)');
      // Aynı anlamda 300 ms'lik mevcut süre yok: splashOut (css:425 splash
      // örtüsü) ve viewerDoubleTap (dokunma eşiği) farklı kavramlar.
      expect(GuSizes.viewerZoomScale, 1.8);
    });
  });
}
