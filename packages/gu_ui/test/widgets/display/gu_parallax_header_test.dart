// T-06 · GuParallaxHeader (widget-catalog #71; A.2 #71; css:395–397;
// screens-clubs.js:86, screens-events.js:57–58; CD-25, K-07).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

final Key _back = GuKey.action('EVT-02.back');
final Key _share = GuKey.action('EVT-02.share');
final Key _menu = GuKey.action('EVT-02.menu');
final Finder _header = find.byType(GuParallaxHeader);
final Finder _cover = find.byType(GuCover);

Widget _host(ValueNotifier<double> offset, {List<String>? log}) => Align(
  alignment: Alignment.topCenter,
  child: GuParallaxHeader(
    cover: const GuCover.template(
      palette: GuCoverPalette.red,
      pattern: GuCoverPattern.lines,
      ratio: GuCoverRatio.fill,
    ),
    scrollOffset: offset,
    leading: GuIconButton(
      key: _back,
      icon: GuIcons.arrowLeft,
      semanticLabel: 'Geri',
      onPressed: () => log?.add('back'),
      onCover: true,
    ),
    actions: [
      GuIconButton(
        key: _share,
        icon: GuIcons.share2,
        semanticLabel: 'Paylaş',
        onPressed: () => log?.add('share'),
        onCover: true,
      ),
      GuIconButton(
        key: _menu,
        icon: GuIcons.moreVertical,
        semanticLabel: 'Daha fazla',
        onPressed: () => log?.add('menu'),
        onCover: true,
      ),
    ],
  ),
);

void main() {
  group('T-06 · GuParallaxHeader', () {
    testWidgets('T-06 · GuParallaxHeader · 220 yükseklik, kapak ofset × .4 '
        '(0…220 sıkıştırılır), kırpma; çubuk dolgusu viewPadding.top − 4 / 8, '
        'aralık 4', (tester) async {
      final offset = ValueNotifier<double>(0);
      addTearDown(offset.dispose);
      await tester.pumpApp(
        _host(offset),
        viewPadding: const EdgeInsets.only(top: 54),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(_header),
        const Size(390, GuSizes.parallaxHeight),
      );
      expect(tester.getRect(_cover), const Rect.fromLTWH(0, 0, 390, 220));
      expect(
        find.descendant(of: _header, matching: find.byType(ClipRect)),
        findsOneWidget,
      );

      // `.parallax-bar{padding:calc(safe-top − 4px) 8px 0; gap:4px}`.
      expect(
        tester.getRect(find.byKey(_back)),
        const Rect.fromLTWH(8, 50, 48, 48),
      );
      expect(
        tester.getRect(find.byKey(_menu)),
        const Rect.fromLTWH(390 - 8 - 48, 50, 48, 48),
      );
      expect(
        tester.getRect(find.byKey(_menu)).left -
            tester.getRect(find.byKey(_share)).right,
        GuSpacing.s4,
      );

      // `translateY(py × .4px)`; ofset 0…220 aralığına sıkıştırılır.
      for (final (scroll, shift) in [
        (100.0, 40.0),
        (220.0, 88.0),
        (500.0, 88.0),
        (-30.0, 0.0),
      ]) {
        offset.value = scroll;
        await tester.pump();
        expect(
          tester.getTopLeft(_cover).dy,
          closeTo(shift, 1e-9),
          reason: '$scroll',
        );
        // Başlık kutusu ve çubuk yerinde kalır.
        expect(tester.getSize(_header).height, GuSizes.parallaxHeight);
        expect(tester.getTopLeft(find.byKey(_back)).dy, 50);
      }
      final header = tester.widget<GuParallaxHeader>(_header);
      expect(header.height, 220);
      expect(header.factor, 0.4);
      expect(header.coverShift(50), 20);
    });

    testWidgets('T-06 · GuParallaxHeader · düğmeler → callback, Semantics; '
        'üst inset yokken dolgu 0 (negatif olmaz); düğmesiz kullanım', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final offset = ValueNotifier<double>(0);
      addTearDown(offset.dispose);
      final log = <String>[];
      await tester.pumpApp(
        _host(offset, log: log),
        viewPadding: const EdgeInsets.only(top: 2),
      );
      await tester.pump();
      expect(tester.getTopLeft(find.byKey(_back)), const Offset(8, 0));

      await tester.tap(find.byKey(_back));
      await tester.tap(find.byKey(_share));
      await tester.tap(find.byKey(_menu));
      expect(log, ['back', 'share', 'menu']);
      for (final (key, label) in [
        (_back, 'Geri'),
        (_share, 'Paylaş'),
        (_menu, 'Daha fazla'),
      ]) {
        expect(
          tester.getSemantics(find.byKey(key)),
          isSemantics(label: label, isButton: true, hasTapAction: true),
        );
      }
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();

      // Düğmesiz + özel ölçü.
      await tester.pumpApp(
        Align(
          alignment: Alignment.topCenter,
          child: GuParallaxHeader(
            cover: const GuCover.demo(
              slug: 'yok',
              ratio: GuCoverRatio.fill,
            ),
            scrollOffset: offset,
            height: 160,
            factor: 0.5,
          ),
        ),
        size: const Size(320, 640),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(_header), const Size(320, 160));
      offset.value = 400;
      await tester.pump();
      expect(tester.getTopLeft(_cover).dy, 80);
    });
  });
}
