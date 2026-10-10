import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'device_matrix.dart';
import 'overflow_detector.dart';

/// 350 dp genişliğinde satır: yalnızca 320 dp'de taşar.
Widget _overflowAt320(BuildContext context) => const Align(
  alignment: Alignment.topLeft,
  child: Row(
    children: [
      SizedBox(width: 250, height: 8),
      SizedBox(width: 100, height: 8),
    ],
  ),
);

/// Esnek, taşmayan içerik.
Widget _fits(BuildContext context) => const Align(
  alignment: Alignment.topLeft,
  child: Row(
    children: [
      Flexible(child: SizedBox(width: 250, height: 8)),
      SizedBox(width: 60, height: 8),
    ],
  ),
);

void main() {
  group('T-02 · DeviceMatrix (D-21, CD-42)', () {
    test('full = 48 (4 boyut × 2 tema × 2 dil × 3 ölçek), adlar benzersiz', () {
      final cases = DeviceMatrix.cases(mode: 'full');
      expect(cases, hasLength(48));
      expect(cases.toSet(), hasLength(48));
      expect(cases.map((c) => c.name).toSet(), hasLength(48));
      expect(cases.map((c) => c.size).toSet(), MatrixSize.values.toSet());
      expect(cases.map((c) => c.theme).toSet(), {
        ThemeMode.light,
        ThemeMode.dark,
      });
      expect(cases.map((c) => c.locale).toSet(), {
        const Locale('tr'),
        const Locale('en'),
      });
      expect(cases.map((c) => c.textScale).toSet(), {1.0, 1.3, 1.6});
      expect(
        cases.every(
          (c) => c.keyboardInset == 0 && c.viewPadding == EdgeInsets.zero,
        ),
        isTrue,
      );
    });

    test('fast = 4: {320, 390} × açık × TR × {1.0, 1.6}', () {
      final cases = DeviceMatrix.cases(mode: 'fast');
      expect(cases, hasLength(4));
      expect(cases.map((c) => (c.size, c.textScale)).toSet(), {
        (MatrixSize.small, 1.0),
        (MatrixSize.small, 1.6),
        (MatrixSize.reference, 1.0),
        (MatrixSize.reference, 1.6),
      });
      expect(cases.map((c) => c.theme).toSet(), {ThemeMode.light});
      expect(cases.map((c) => c.locale).toSet(), {const Locale('tr')});
    });

    test('mode varsayılanı GU_MATRIX (full); bilinmeyen mod ArgumentError', () {
      expect(DeviceMatrix.mode, anyOf('full', 'fast'));
      expect(DeviceMatrix.cases(), DeviceMatrix.cases(mode: DeviceMatrix.mode));
      expect(() => DeviceMatrix.cases(mode: 'yarım'), throwsArgumentError);
    });

    test('boyutlar: 320×640 · 390×844 · 430×932 · 768×1024', () {
      expect(MatrixSize.values.map((s) => s.size), const [
        Size(320, 640),
        Size(390, 844),
        Size(430, 932),
        Size(768, 1024),
      ]);
    });

    test('klavye / güvenli alan varyantları yalnızca referans vakada', () {
      expect(DeviceMatrix.variantCases(), isEmpty);
      final variants = DeviceMatrix.variantCases(
        keyboard: true,
        safeAreas: true,
      );
      expect(variants, hasLength(5));
      for (final v in variants) {
        expect(v.size, MatrixSize.reference);
        expect(v.theme, ThemeMode.light);
        expect(v.locale, const Locale('tr'));
        expect(v.textScale, 1.0);
      }
      expect(variants.first.keyboardInset, DeviceMatrix.keyboardInset);
      expect(variants.first.keyboardInset, 320);
      expect(
        variants.skip(1).map((v) => v.viewPadding),
        DeviceMatrix.safeAreaVariants,
      );
      expect(DeviceMatrix.safeAreaVariants, const [
        EdgeInsets.only(top: 47),
        EdgeInsets.only(top: 59),
        EdgeInsets.only(bottom: 34),
        EdgeInsets.only(top: 24, bottom: 48),
      ]);
      final names = {
        ...DeviceMatrix.cases(mode: 'full').map((c) => c.name),
        ...variants.map((c) => c.name),
      };
      expect(names, hasLength(53));
    });

    testWidgets('kasıtlı taşan widget matriste kırmızı (mesajda vaka adı)', (
      tester,
    ) async {
      final small = DeviceMatrix.cases(mode: 'fast').first;
      expect(small.size, MatrixSize.small);
      TestFailure? failure;
      try {
        await DeviceMatrix.run(tester, _overflowAt320, mode: 'fast');
      } on TestFailure catch (e) {
        failure = e;
      }
      expect(failure, isNotNull);
      expect(failure!.message, contains(small.name));
      expect(failure.message, contains('RenderFlex overflowed'));
      expect(OverflowDetector.isInstalled, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('kasıtlı taşan widget tam matriste de kırmızı', (tester) async {
      await expectLater(
        DeviceMatrix.run(tester, _overflowAt320, mode: 'full'),
        throwsA(isA<TestFailure>()),
      );
      expect(OverflowDetector.isInstalled, isFalse);
    });

    testWidgets('taşma dışı istisna vaka adıyla kırmızı', (tester) async {
      await expectLater(
        DeviceMatrix.run(
          tester,
          (context) => throw StateError('build hatası'),
          mode: 'fast',
        ),
        throwsA(
          isA<TestFailure>().having(
            (e) => e.message,
            'message',
            contains(DeviceMatrix.cases(mode: 'fast').first.name),
          ),
        ),
      );
    });

    testWidgets('taşmayan widget yeşil (GU_MATRIX modu + varyantlar)', (
      tester,
    ) async {
      final seen = <MediaQueryData>[];
      await DeviceMatrix.run(
        tester,
        (context) {
          seen.add(MediaQuery.of(context));
          return _fits(context);
        },
        keyboard: true,
        safeAreas: true,
      );
      final expected =
          DeviceMatrix.cases().length +
          DeviceMatrix.variantCases(keyboard: true, safeAreas: true).length;
      final sizes = seen.map((m) => m.size).toSet();
      expect(sizes, containsAll(const [Size(320, 640), Size(390, 844)]));
      expect(
        seen.where((m) => m.viewInsets.bottom == DeviceMatrix.keyboardInset),
        isNotEmpty,
      );
      for (final padding in DeviceMatrix.safeAreaVariants) {
        expect(seen.map((m) => m.viewPadding), contains(padding));
      }
      expect(seen.length, greaterThanOrEqualTo(expected));
      expect(OverflowDetector.isInstalled, isFalse);
    });
  });
}
