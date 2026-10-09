import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/src/tokens/gu_breakpoints.dart';

import '../helpers/design_sources.dart';

void main() {
  group('T-01 · GuBreakpoints sabitleri (token-map §9)', () {
    test('6 sabit (sabit beklenti; Q-13, CD-29, testing.md §5)', () {
      expect(GuBreakpoints.maxContentWidth, 480);
      expect(GuBreakpoints.phoneSmall, 320);
      expect(GuBreakpoints.phoneReference, 390);
      expect(GuBreakpoints.phoneLarge, 430);
      expect(GuBreakpoints.tablet, 768);
      expect(GuBreakpoints.referenceHeight, 844);
    });

    test('referans cihaz 390 × 844 = .device (css:112)', () {
      final m = RegExp(
        r'\.device\{[^}]*width:(\d+)px;height:(\d+)px',
      ).firstMatch(componentCss())!;
      expect(GuBreakpoints.phoneReference, double.parse(m.group(1)!));
      expect(GuBreakpoints.referenceHeight, double.parse(m.group(2)!));
    });

    test('tablet 768 = prototip mobile eşiği (shell.js:65)', () {
      final m = RegExp(
        r'const mobile = w < (\d+);',
      ).firstMatch(prototypeJs('shell.js'))!;
      expect(GuBreakpoints.tablet, double.parse(m.group(1)!));
    });

    test('sıralama: küçük < referans < büyük < içerik sütunu < tablet', () {
      expect(GuBreakpoints.phoneSmall, lessThan(GuBreakpoints.phoneReference));
      expect(GuBreakpoints.phoneReference, lessThan(GuBreakpoints.phoneLarge));
      expect(
        GuBreakpoints.phoneLarge,
        lessThan(GuBreakpoints.maxContentWidth),
      );
      expect(GuBreakpoints.maxContentWidth, lessThan(GuBreakpoints.tablet));
    });
  });

  group('T-01 · GuBreakpoints.isWide', () {
    Future<bool> isWideAt(WidgetTester tester, double width) async {
      late bool result;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: Size(width, GuBreakpoints.referenceHeight),
          ),
          child: Builder(
            builder: (context) {
              result = GuBreakpoints.isWide(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return result;
    }

    testWidgets('479 → false', (tester) async {
      expect(await isWideAt(tester, 479), isFalse);
    });

    testWidgets('480 → false (sınır dahil değil)', (tester) async {
      expect(await isWideAt(tester, 480), isFalse);
    });

    testWidgets('481 → true', (tester) async {
      expect(await isWideAt(tester, 481), isTrue);
    });

    testWidgets('cihaz matrisi: 320/390/430 dar, 768 geniş', (tester) async {
      expect(await isWideAt(tester, GuBreakpoints.phoneSmall), isFalse);
      expect(await isWideAt(tester, GuBreakpoints.phoneReference), isFalse);
      expect(await isWideAt(tester, GuBreakpoints.phoneLarge), isFalse);
      expect(await isWideAt(tester, GuBreakpoints.tablet), isTrue);
    });
  });
}
