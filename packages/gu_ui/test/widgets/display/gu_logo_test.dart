// T-03 · GuLogo (widget-catalog #48; CD-90, K-10). Kullanıcı kararı
// 2026-10-16: üniversite mührü (`gu-logo.png`) çizilmez; her zaman uygulama
// amblemi (açık / koyu SVG).
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

String _svgAsset(WidgetTester tester) =>
    (tester.widget<SvgPicture>(find.byType(SvgPicture)).bytesLoader
            as SvgAssetLoader)
        .assetName;

void main() {
  group('T-03 · GuLogo', () {
    testWidgets('amblem SVG (açık / koyu), mühür PNG yok, dekoratif', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpApp(const Center(child: GuLogo(size: 96)));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(GuLogo)), const Size.square(96));
      expect(_svgAsset(tester), GuLogoAssets.emblem);
      final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(svg.width, 96);
      expect(svg.height, 96);
      expect(find.byType(Image), findsNothing);
      expect(find.byType(ClipOval), findsNothing);
      expect(find.bySemanticsLabel(RegExp('.+')), findsNothing);

      await tester.pumpApp(
        const Center(child: GuLogo(size: 20)),
        theme: ThemeMode.dark,
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(GuLogo)), const Size.square(20));
      expect(_svgAsset(tester), GuLogoAssets.emblemDark);
      expect(find.byType(Image), findsNothing);
      handle.dispose();
    });

    testWidgets('semanticLabel → Semantics(label, image)', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpApp(
        const Center(child: GuLogo(size: 72, semanticLabel: 'GÜ Kulüpler')),
      );
      await tester.pump();
      expect(
        tester.getSemantics(find.bySemanticsLabel('GÜ Kulüpler')),
        matchesSemantics(label: 'GÜ Kulüpler', isImage: true),
      );
      handle.dispose();
    });
  });
}
