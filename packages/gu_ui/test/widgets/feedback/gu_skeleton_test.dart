// T-06 · GuSkeleton + GuSkeletonList (widget-catalog #22a / #22b; CD-122(2);
// css:263–264, 417, 427; ui.js:94–99).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

Finder _paintOf(Finder skeleton) =>
    find.descendant(of: skeleton, matching: find.byType(CustomPaint));

/// Boyacının `progress` animasyonunun değeri (0–1).
double _progress(WidgetTester tester) {
  final painter = tester
      .widget<CustomPaint>(_paintOf(find.byType(GuSkeleton)))
      .painter;
  // Özel boyacı sınıfının herkese açık alanı.
  final progress = (painter as dynamic).progress as Animation<double>;
  return progress.value;
}

void _expectRect(Rect actual, Rect expected) {
  for (final (a, e) in [
    (actual.left, expected.left),
    (actual.top, expected.top),
    (actual.width, expected.width),
    (actual.height, expected.height),
  ]) {
    expect(
      a,
      moreOrLessEquals(e, epsilon: 0.01),
      reason: '$actual ≠ $expected',
    );
  }
}

void main() {
  group('T-06 · GuSkeleton', () {
    testWidgets('T-06 · GuSkeleton · tam / oran / sabit genişlik, daire, '
        'radius 8 / 0; dekoratif; pumpApp altında durağan', (tester) async {
      const full = ValueKey<String>('full');
      const ratio = ValueKey<String>('ratio');
      const avatar = ValueKey<String>('avatar');
      const cover = ValueKey<String>('cover');
      await tester.pumpApp(
        const Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GuSkeleton(key: full),
                GuSkeleton(
                  key: ratio,
                  widthFactor: 0.55,
                  height: GuSizes.skeletonSubHeight,
                ),
                GuSkeleton(
                  key: avatar,
                  width: GuSizes.skeletonAvatar,
                  height: GuSizes.skeletonAvatar,
                  circle: true,
                ),
                GuSkeleton(
                  key: cover,
                  height: GuSizes.skeletonCardCover,
                  borderRadius: BorderRadius.zero,
                ),
              ],
            ),
          ),
        ),
      );
      // CD-122(2): pumpApp shimmer'ı kapatır.
      expect(GuSkeleton.debugAnimate, isFalse);
      expect(tester.hasRunningAnimations, isFalse);

      expect(tester.getSize(find.byKey(full)), const Size(300, 14));
      expect(tester.getSize(find.byKey(ratio)), const Size(165, 12));
      expect(tester.getSize(find.byKey(avatar)), const Size.square(40));
      expect(tester.getSize(find.byKey(cover)), const Size(300, 140));
      expect(
        _paintOf(find.byKey(full)),
        paints..rrect(
          rrect: RRect.fromRectAndRadius(
            const Rect.fromLTWH(0, 0, 300, 14),
            const Radius.circular(GuRadius.skeleton),
          ),
        ),
      );
      expect(
        _paintOf(find.byKey(avatar)),
        paints..something(
          (method, arguments) =>
              method == #drawOval &&
              arguments.first == const Rect.fromLTWH(0, 0, 40, 40),
        ),
      );
      expect(
        _paintOf(find.byKey(cover)),
        paints..rrect(
          rrect: RRect.fromRectAndRadius(
            const Rect.fromLTWH(0, 0, 300, 140),
            Radius.zero,
          ),
        ),
      );
      // `aria-hidden`.
      expect(
        find.descendant(
          of: find.byKey(full),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
    });

    testWidgets('T-06 · GuSkeleton · shimmer 1200 ms doğrusal döngü; '
        'azaltılmış hareket ve debugAnimate=false → durağan', (tester) async {
      final reduce = ValueNotifier<bool>(true);
      addTearDown(reduce.dispose);
      await tester.pumpApp(
        ValueListenableBuilder<bool>(
          valueListenable: reduce,
          builder: (context, disable, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: disable),
            child: child!,
          ),
          child: const Center(child: SizedBox(width: 100, child: GuSkeleton())),
        ),
      );
      // pumpApp kapattı; test sonunda pumpApp'in tearDown'ı yeniden açar.
      GuSkeleton.debugAnimate = true;
      expect(tester.hasRunningAnimations, isFalse);
      // `animation:none` → `background-position:0` (kaymanın ortası).
      expect(_progress(tester), 0.5);

      reduce.value = false;
      await tester.pump();
      expect(tester.hasRunningAnimations, isTrue);
      expect(_progress(tester), 0);
      await tester.pump(GuMotion.shimmer * 0.25);
      expect(_progress(tester), moreOrLessEquals(0.25, epsilon: 1e-9));
      await tester.pump(GuMotion.shimmer);
      expect(_progress(tester), moreOrLessEquals(0.25, epsilon: 1e-9));

      reduce.value = true;
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(_progress(tester), 0.5);

      GuSkeleton.debugAnimate = false;
      reduce.value = false;
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(_progress(tester), 0.5);
    });
  });

  group('T-06 · GuSkeletonList', () {
    testWidgets('T-06 · GuSkeletonList · tile (56 satır, 40 daire, %55 / %80) '
        've card (140 kapak, %60 / %90 / %40) yerleşimi; Semantics', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpApp(
        const Align(
          alignment: Alignment.topCenter,
          child: GuSkeletonList(count: 3, semanticLabel: 'Yükleniyor'),
        ),
      );
      final blocks = find.byType(GuSkeleton);
      expect(blocks, findsNWidgets(9));
      expect(
        tester.getSize(find.byType(GuSkeletonList)),
        const Size(390, 3 * GuSizes.tileMinHeight),
      );
      // Metin sütunu: 390 − 16 − 40 − 12 − 16 = 306.
      _expectRect(
        tester.getRect(blocks.at(0)),
        const Rect.fromLTWH(16, 8, 40, 40),
      );
      _expectRect(
        tester.getRect(blocks.at(1)),
        const Rect.fromLTWH(68, 12, 306 * 0.55, 14),
      );
      _expectRect(
        tester.getRect(blocks.at(2)),
        const Rect.fromLTWH(68, 32, 306 * 0.80, 12),
      );
      expect(tester.getTopLeft(blocks.at(3)).dy, GuSizes.tileMinHeight + 8);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Yükleniyor')),
        matchesSemantics(label: 'Yükleniyor', isLiveRegion: true),
      );

      await tester.pumpApp(
        const Align(
          alignment: Alignment.topCenter,
          child: GuSkeletonList(
            count: 2,
            variant: GuSkeletonVariant.card,
            semanticLabel: 'Yükleniyor',
          ),
        ),
      );
      expect(find.byType(GuCard), findsNWidgets(2));
      expect(blocks, findsNWidgets(8));
      // Kart 16…374; kenarlık 1; gövde iç genişliği 358 − 2 − 32 = 324.
      // Kart yüksekliği 2 + 140 + (16 + 16 + 8 + 14 + 8 + 14 + 16) = 234.
      expect(
        tester.getRect(find.byType(GuCard).first),
        const Rect.fromLTWH(16, 0, 358, 234),
      );
      expect(tester.getTopLeft(find.byType(GuCard).last).dy, 234 + 12);
      _expectRect(
        tester.getRect(blocks.at(0)),
        const Rect.fromLTWH(17, 1, 356, 140),
      );
      _expectRect(
        tester.getRect(blocks.at(1)),
        const Rect.fromLTWH(33, 157, 324 * 0.60, 16),
      );
      _expectRect(
        tester.getRect(blocks.at(2)),
        const Rect.fromLTWH(33, 181, 324 * 0.90, 14),
      );
      _expectRect(
        tester.getRect(blocks.at(3)),
        const Rect.fromLTWH(33, 203, 324 * 0.40, 14),
      );
      expect(tester.hasRunningAnimations, isFalse);
      handle.dispose();
    });
  });
}
