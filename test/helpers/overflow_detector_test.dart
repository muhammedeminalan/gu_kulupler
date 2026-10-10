import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'overflow_detector.dart';
import 'pump_app.dart';

/// 350 dp genişliğinde satır: 320'de kasıtlı taşar, 390'da sığar.
Widget _overflowingRow() => const Row(
  children: [SizedBox(width: 250, height: 8), SizedBox(width: 100, height: 8)],
);

FlutterErrorDetails _details(Object exception) =>
    FlutterErrorDetails(exception: exception, library: 'T-02 testi');

void main() {
  group('T-02 · OverflowDetector', () {
    tearDown(() {
      OverflowDetector.uninstall();
      OverflowDetector.reset();
    });

    test('isOverflow: taşma / yerleşim mesajları', () {
      expect(
        OverflowDetector.isOverflow(
          _details(
            FlutterError('A RenderFlex overflowed by 80 pixels on the right.'),
          ),
        ),
        isTrue,
      );
      expect(
        OverflowDetector.isOverflow(
          _details(FlutterError('RenderBox was not laid out: RenderFlex#1')),
        ),
        isTrue,
      );
      expect(
        OverflowDetector.isOverflow(
          _details(
            FlutterError(
              'A RenderConstrainedOverflowBox overflowed by 2 pixels',
            ),
          ),
        ),
        isTrue,
      );
      expect(
        OverflowDetector.isOverflow(_details(StateError('boom'))),
        isFalse,
      );
    });

    testWidgets('kasıtlı taşan Row yakalanır; assertNone vaka adıyla düşer', (
      tester,
    ) async {
      OverflowDetector.install();
      try {
        await tester.pumpApp(
          Align(alignment: Alignment.topLeft, child: _overflowingRow()),
          size: const Size(320, 640),
        );
        expect(OverflowDetector.collected, hasLength(1));
        expect(
          OverflowDetector.collected.single.exceptionAsString(),
          contains('A RenderFlex overflowed'),
        );
        expect(
          () => OverflowDetector.assertNone('küçük 320'),
          throwsA(
            isA<TestFailure>().having(
              (e) => e.message,
              'message',
              allOf(contains('küçük 320'), contains('RenderFlex overflowed')),
            ),
          ),
        );
        // assertNone toplananı tüketir.
        expect(OverflowDetector.collected, isEmpty);
      } finally {
        OverflowDetector.uninstall();
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('taşma yokken assertNone geçer', (tester) async {
      OverflowDetector.install();
      try {
        await tester.pumpApp(
          Align(alignment: Alignment.topLeft, child: _overflowingRow()),
        );
        OverflowDetector.assertNone('referans 390');
      } finally {
        OverflowDetector.uninstall();
      }
    });

    test('taşma dışı hata yutulmaz: önceki işleyiciye iletilir', () {
      final original = FlutterError.onError;
      final forwarded = <FlutterErrorDetails>[];
      void handler(FlutterErrorDetails d) => forwarded.add(d);
      FlutterError.onError = handler;
      try {
        OverflowDetector.install();
        FlutterError.reportError(_details(StateError('boom')));
        FlutterError.reportError(
          _details(
            FlutterError('A RenderFlex overflowed by 4 pixels on the bottom.'),
          ),
        );
        OverflowDetector.uninstall();
        expect(FlutterError.onError, same(handler));
      } finally {
        OverflowDetector.uninstall();
        FlutterError.onError = original;
      }
      expect(forwarded.map((d) => d.exception), [isA<StateError>()]);
      expect(OverflowDetector.collected, hasLength(1));
    });

    test(
      'install/uninstall tekrar çağrıda etkisiz; önceki işleyici geri gelir',
      () {
        final before = FlutterError.onError;
        OverflowDetector.install();
        final wrapped = FlutterError.onError;
        OverflowDetector.install();
        final again = FlutterError.onError;
        OverflowDetector.uninstall();
        final restored = FlutterError.onError;
        OverflowDetector.uninstall();
        expect(wrapped, isNot(same(before)));
        expect(again, same(wrapped));
        expect(restored, same(before));
        expect(FlutterError.onError, same(before));
        expect(OverflowDetector.isInstalled, isFalse);
      },
    );
  });
}
