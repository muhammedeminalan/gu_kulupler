// T-04 · GuHorizontalList (widget-catalog #68; CD-25; css:102, 105).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

Widget _host(Widget child) =>
    Column(mainAxisSize: MainAxisSize.min, children: [child]);

/// 100 px genişlikte öğe; başlangıçları 0, 108, 216, …
Widget _item(int i, {double height = 38}) => SizedBox(
  key: ValueKey<int>(i),
  width: 100,
  height: height,
);

double _offset(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels;

void main() {
  group('T-04 · GuHorizontalList', () {
    testWidgets('T-04 · GuHorizontalList · dolgu varyantları (3/16, pb16, '
        'py8), aralık 8, en yüksek öğeye gerilme, sola yaslı dar içerik, '
        'kaydırma çubuğu yok', (tester) async {
      for (final (padding, top, bottom) in [
        (GuHorizontalListPadding.normal, 3.0, 3.0),
        (GuHorizontalListPadding.bottom, 3.0, 16.0),
        (GuHorizontalListPadding.vertical, 8.0, 8.0),
      ]) {
        await tester.pumpApp(
          _host(
            GuHorizontalList(
              padding: padding,
              children: [_item(0), _item(1, height: 50), _item(2)],
            ),
          ),
        );
        expect(padding.insets, EdgeInsets.fromLTRB(16, top, 16, bottom));
        // Yükseklik = üst + en yüksek öğe (50) + alt.
        expect(
          tester.getSize(find.byType(GuHorizontalList)).height,
          top + 50 + bottom,
          reason: '$padding',
        );
        expect(
          tester.getTopLeft(find.byKey(const ValueKey(0))),
          Offset(16, top),
        );
        // İç ölçüm ve kuru yerleşim de taşmasız yüksekliği verir.
        final box = tester.renderObject<RenderBox>(
          find.byType(GuHorizontalList),
        );
        expect(box.getMinIntrinsicHeight(390), top + 50 + bottom);
        expect(box.getMaxIntrinsicHeight(390), top + 50 + bottom);
        expect(
          box.getDryLayout(const BoxConstraints(maxWidth: 390)),
          Size(390, top + 50 + bottom),
        );
      }
      // Öğeler en yüksek öğenin boyuna gerilir; aralık 8.
      expect(
        tester.getSize(find.byKey(const ValueKey(0))),
        const Size(100, 50),
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey(1))).dx -
            tester.getTopRight(find.byKey(const ValueKey(0))).dx,
        GuSizes.hscrollGap,
      );
      // Dar içerik: şerit satırın soluna yaslanır, kaydırma yok.
      expect(tester.getTopLeft(find.byType(GuHorizontalList)).dx, 0);
      expect(tester.getSize(find.byType(GuHorizontalList)).width, 390);
      expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable))
            .position
            .maxScrollExtent,
        0,
      );
      expect(find.byType(Scrollbar), findsNothing);
      expect(find.byType(RawScrollbar), findsNothing);
    });

    testWidgets('T-04 · GuHorizontalList · snap: öğe başlangıcına yakın '
        'durunca oraya oturur, uzakta serbest kalır; snap kapalıyken yakalama '
        'yok', (tester) async {
      Widget list({required bool snap}) => _host(
        GuHorizontalList(
          snap: snap,
          children: [for (var i = 0; i < 12; i++) _item(i)],
        ),
      );
      Future<void> dragBy(double dx) async {
        await tester.drag(find.byType(GuHorizontalList), Offset(-dx, 0));
        await tester.pumpAndSettle();
      }

      await tester.pumpApp(list(snap: true));
      expect(GuHorizontalList.snapProximity, GuSpacing.s32);
      // 2. öğenin başlangıcı 108: 20 px geride bırakılır → 108'e oturur.
      await dragBy(88);
      expect(_offset(tester), moreOrLessEquals(108, epsilon: 0.5));
      expect(
        tester.getTopLeft(find.byKey(const ValueKey(1))).dx,
        moreOrLessEquals(16, epsilon: 0.5),
      );
      // 108 → 162: en yakın başlangıç (216) 54 px uzakta → serbest.
      await dragBy(54);
      expect(_offset(tester), moreOrLessEquals(162, epsilon: 0.5));
      // Sona kaydır: son konum en büyük kaydırma değeriyle sınırlı.
      await dragBy(2000);
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      expect(position.pixels, position.maxScrollExtent);

      await tester.pumpApp(list(snap: false));
      await dragBy(88);
      expect(_offset(tester), moreOrLessEquals(88, epsilon: 0.5));
    });

    testWidgets('T-04 · GuHorizontalList · 38 px dokunma hedefi şerit '
        'dolgusunu aşsa da 48 dp kalır: semantik kutu + taşma bölgesinde '
        'gerçek dokunma; yerleşim ölçüsü değişmez', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      var above = 0;
      await tester.pumpApp(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => above++,
              child: const SizedBox(width: 390, height: 20),
            ),
            GuHorizontalList(
              children: [
                GuTapTarget(
                  onTap: () => taps++,
                  semanticLabel: 'Tümü',
                  child: const SizedBox(width: 60, height: 38),
                ),
              ],
            ),
          ],
        ),
      );
      final list = find.byType(GuHorizontalList);
      // Yerleşim: 3 + 38 + 3, üstteki komşunun hemen altında.
      expect(tester.getRect(list), const Rect.fromLTWH(0, 20, 390, 44));
      final target = tester.getRect(find.bySemanticsLabel('Tümü'));
      expect(target, const Rect.fromLTWH(16, 23, 60, 38));
      // Hedefin 4 px üstü: şerit kutusunun dışında (y = 19), yine hedefe gider.
      await tester.tapAt(Offset(target.center.dx, target.top - 4));
      expect((taps, above), (1, 0));
      // Hedefin 5 px dolgusunun dışı: komşuya geçer.
      await tester.tapAt(Offset(target.center.dx, target.top - 7));
      await tester.tapAt(Offset(target.right + 20, target.top - 4));
      expect((taps, above), (1, 2));
      expect(
        tester.getSemantics(find.bySemanticsLabel('Tümü')).rect.size,
        const Size(60, GuSizes.tapTargetAndroid),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });
  });
}
