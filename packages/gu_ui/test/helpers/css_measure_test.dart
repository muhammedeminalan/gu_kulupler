import 'package:flutter_test/flutter_test.dart';

import 'css_measure.dart';

const String _fixture = '''
/* yorum { içinde süslü } parantez */
.a{min-height:48px;padding:4px 8px;gap:6px}
.b,.c > i{width:20px;border:2px solid var(--x)}
.a{min-height:56px}
.d{padding:12px 16px calc(12px + var(--safe-bottom));margin:8px auto 0;inset:-11px -4px}
.e{padding:10px 12px 12px 14px;top:calc(var(--safe-top) - 4px);left:calc(50% + 4px)}
.f{max-height:90%;aspect-ratio:16/9;opacity:.45;transform:translate(-50%,-110%) rotate(-30deg)}
.g{mask-image:linear-gradient(transparent,#000 30%,#000 70%,transparent);filter:brightness(.96)}
.h{background:repeating-linear-gradient(45deg,var(--m) 0 10px,var(--s) 10px 20px);width:min(320px,calc(100% - 48px))}
.i{box-shadow:inset 0 0 0 2px var(--brand);content:"a;b{c}"}
.j[aria-current="page"]::before{width:28px}
.k{transform:translateY(calc(var(--py,0) * .4px))}
@keyframes scan{0%,100%{top:8%}50%{top:90%}}
@media (prefers-reduced-motion:reduce){.a{min-height:1px!important}}
''';

void main() {
  group('T-01 · CssMeasure ayrıştırıcı (sabit dizge)', () {
    final css = CssMeasure.parse(_fixture);

    test('aynı seçicide son tanım kazanır; satır numarası son kuraldır', () {
      expect(css.px('.a', 'min-height'), 56);
      // ''' sonrası ilk satır sonu dizgeye girmez: satır 1 = yorum.
      expect(css.line('.a', 'min-height'), 4);
      // Son kural yalnızca min-height'i ezdi; diğer özellikler korunur.
      expect(css.px('.a', 'gap'), 6);
      expect(css.line('.a', 'gap'), 2);
    });

    test(
      'virgüllü seçici listesi ayrı ayrı eşlenir; birleştirici normalize',
      () {
        expect(css.px('.b', 'width'), 20);
        expect(css.px('.c>i', 'width'), 20);
        expect(css.px('.c > i', 'width'), 20);
        expect(css.has('.b,.c > i'), isFalse);
      },
    );

    test('yorum içindeki süslü parantez ayrıştırmayı bozmaz', () {
      expect(css.has('.a'), isTrue);
      expect(css.selectors, isNot(contains(contains('yorum'))));
    });

    test('tırnak içindeki ; ve { } bildirimi bölmez', () {
      expect(css.raw('.i', 'content'), '"a;b{c}"');
    });

    test('box: 1–4 değer [üst, sağ, alt, sol] açılımı ve calc sabiti', () {
      expect(css.box('.a', 'padding'), [4, 8, 4, 8]);
      expect(css.box('.d', 'padding'), [12, 16, 12, 16]);
      expect(css.box('.e', 'padding'), [10, 12, 12, 14]);
      expect(css.box('.d', 'inset'), [-11, -4, -11, -4]);
      final margin = css.box('.d', 'margin');
      expect(margin[0], 8);
      expect(margin[1].isNaN, isTrue, reason: 'auto → NaN');
      expect(margin[2], 0);
    });

    test('box: kısa yazım dışı özelliklerde yalnızca uzunluklar', () {
      expect(css.box('.b', 'border'), [2]);
      expect(css.box('.i', 'box-shadow'), [0, 0, 0, 2]);
    });

    test('px: calc içindeki işaretli sabit terim', () {
      expect(css.px('.e', 'top'), -4);
      expect(css.px('.e', 'left'), 4);
    });

    test('percent / number / fn', () {
      expect(css.percent('.f', 'max-height'), closeTo(0.9, 1e-12));
      expect(css.number('.f', 'aspect-ratio'), closeTo(16 / 9, 1e-12));
      expect(css.number('.f', 'opacity'), closeTo(0.45, 1e-12));
      expect(
        css.fn('.f', 'transform', 'translate', arg: 1),
        closeTo(-1.1, 1e-12),
      );
      expect(css.fn('.f', 'transform', 'rotate'), -30);
      expect(
        css.fn('.g', 'mask-image', 'linear-gradient', arg: 1),
        closeTo(0.3, 1e-12),
      );
      expect(
        css.fn('.g', 'mask-image', 'linear-gradient', arg: 2),
        closeTo(0.7, 1e-12),
      );
      expect(css.fn('.g', 'filter', 'brightness'), closeTo(0.96, 1e-12));
      expect(
        css.fn('.h', 'background', 'repeating-linear-gradient', arg: 1),
        10,
      );
      expect(css.fn('.h', 'width', 'min'), 320);
      expect(css.fn('.h', 'width', 'min', arg: 1), -48);
    });

    test('fn: kelime parçası eşleşmez (linear-gradient ≠ repeating-…)', () {
      expect(
        () => css.fn('.h', 'background', 'linear-gradient'),
        throwsStateError,
      );
    });

    test('fnArg: ham argüman; çarpımsal calc px → FormatException', () {
      expect(
        css.fnArg('.k', 'transform', 'translateY'),
        'calc(var(--py,0) * .4px)',
      );
      expect(
        () => css.fn('.k', 'transform', 'translateY'),
        throwsFormatException,
      );
    });

    test('öznitelik seçicisi ve sözde öğe', () {
      expect(css.px('.j[aria-current="page"]::before', 'width'), 28);
    });

    test('@keyframes adımları sözde seçiciyle; virgüllü adımlar ayrı', () {
      expect(css.keyframes, contains('scan'));
      expect(css.percent('@keyframes scan 0%', 'top'), closeTo(0.08, 1e-12));
      expect(css.percent('@keyframes scan 100%', 'top'), closeTo(0.08, 1e-12));
      expect(css.percent('@keyframes scan 50%', 'top'), closeTo(0.9, 1e-12));
    });

    test('@media ana tabloya karışmaz; ayrı okunur (!important kırpılır)', () {
      expect(css.px('.a', 'min-height'), 56);
      final reduced = css.media('(prefers-reduced-motion:reduce)');
      expect(reduced.px('.a', 'min-height'), 1);
      expect(reduced.raw('.a', 'min-height'), '1px!important');
    });

    test('bulunamayan seçici / özellik → StateError', () {
      expect(() => css.px('.yok', 'width'), throwsStateError);
      expect(() => css.px('.a', 'width'), throwsStateError);
      expect(() => css.media('(yok)'), throwsStateError);
      expect(
        () => css.fnArg('.f', 'transform', 'rotate', arg: 3),
        throwsStateError,
      );
    });

    test('px olmayan değer → FormatException', () {
      expect(() => css.px('.f', 'max-height'), throwsFormatException);
      expect(() => css.px('.a', 'padding'), throwsFormatException);
      expect(() => CssMeasure.parsePx('auto'), throwsFormatException);
      expect(() => CssMeasure.parsePercent('3px'), throwsFormatException);
      expect(() => CssMeasure.parseNumber('3px'), throwsFormatException);
    });

    test('declarations: ezilen tanımlar, virgüllü seçiciler, @keyframes ve '
        '@media kaynak sırasıyla', () {
      final minHeights = [
        for (final d in css.declarations)
          if (d.selector == '.a' && d.prop == 'min-height') d,
      ];
      expect(minHeights.map((d) => (d.value, d.line, d.media)).toList(), [
        ('48px', 2, null),
        ('56px', 4, null),
        ('1px!important', 14, '(prefers-reduced-motion:reduce)'),
      ]);
      // Son tanım kazanır tablosu değişmez; declarations yalnızca ek görünüm.
      expect(css.px('.a', 'min-height'), 56);
      final widths = css.declarations
          .where((d) => d.prop == 'width' && d.line == 3)
          .map((d) => d.selector)
          .toList();
      expect(widths, ['.b', '.c>i']);
      expect(
        css.declarations.where((d) => d.selector.startsWith('@keyframes scan')),
        hasLength(3),
      );
      final lines = css.declarations.map((d) => d.line).toList();
      expect(lines, orderedEquals([...lines]..sort()));
    });

    test(
      'splitList: üst düzey virgül; parantez içi korunur, boşluk kırpılır',
      () {
        expect(
          CssMeasure.splitList('background .12s, color var(--motion-fast)'),
          ['background .12s', 'color var(--motion-fast)'],
        );
        expect(
          CssMeasure.splitList(
            'transform .2s cubic-bezier(.2,0,0,1),opacity 1s',
          ),
          ['transform .2s cubic-bezier(.2,0,0,1)', 'opacity 1s'],
        );
        expect(CssMeasure.splitList('none'), ['none']);
        expect(CssMeasure.splitList(''), isEmpty);
      },
    );

    test('eşleşmeyen süslü parantez → FormatException', () {
      expect(() => CssMeasure.parse('.a{width:1px'), throwsFormatException);
      expect(() => CssMeasure.parse('.a{width:1px}}'), throwsFormatException);
    });
  });

  group('T-01 · CssMeasure ayrıştırıcı (component-css.css)', () {
    final css = CssMeasure.load();

    test("'.btn' min-height 48 (css:139)", () {
      expect(css.px('.btn', 'min-height'), 48);
      expect(css.line('.btn', 'min-height'), 139);
    });

    test('virgüllü kural: .check ve .radio genişliği 22 (css:237)', () {
      expect(css.px('.check', 'width'), 22);
      expect(css.px('.radio', 'width'), 22);
      expect(css.line('.check', 'width'), 237);
      // .check ikinci kez css:238'de tanımlanır (border-radius); width korunur.
      expect(css.line('.check', 'border-radius'), 238);
    });

    test('@keyframes ve @media blokları tanınır', () {
      expect(
        css.keyframes,
        containsAll(<String>['highlight', 'scan', 'spin', 'shimmer']),
      );
      expect(css.mediaConditions, contains('(prefers-reduced-motion:reduce)'));
      expect(css.box('@keyframes highlight 0%', 'box-shadow'), [0, 0, 0, 3]);
      expect(css.line('@keyframes highlight 0%', 'box-shadow'), 426);
    });

    test('declarations: @media içindeki animation ve ezilmeyen kopyalar', () {
      final reduced = css.declarations.where(
        (d) => d.media == '(prefers-reduced-motion:reduce)',
      );
      expect(reduced.map((d) => d.line).toSet(), {427});
      expect(
        reduced.where((d) => d.prop == 'animation').map((d) => d.selector),
        containsAll(<String>['.gu-root .sheet', '.gu-root .sk']),
      );
      // Ana tablo @media'yı görmez.
      expect(css.has('.gu-root .sheet'), isFalse);
    });

    test('tema değişkenleri (custom property) okunur', () {
      expect(
        css.raw('.gu-root[data-theme="light"]', '--brand-primary'),
        '#D00A2D',
      );
    });
  });
}
