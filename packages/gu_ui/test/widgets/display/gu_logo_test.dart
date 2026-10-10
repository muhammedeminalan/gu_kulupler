// T-03 · GuLogo (widget-catalog #48; CD-90, K-10).
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
    testWidgets('amblem: gu-logo.png daire kırpılmış, dekoratif (CD-90)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpApp(const Center(child: GuLogo(size: 96)));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(GuLogo)), const Size.square(96));
      expect(find.byType(ClipOval), findsOneWidget);
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.width, 96);
      expect(image.height, 96);
      expect(image.fit, BoxFit.cover);
      // Hedef piksel boyutunda çözülür (kaynak 1854 px).
      final resized = image.image as ResizeImage;
      expect(resized.width, 96);
      expect(
        (resized.imageProvider as AssetImage).assetName,
        GuLogoAssets.logo,
      );
      expect(find.byType(SvgPicture), findsNothing);
      expect(find.bySemanticsLabel(RegExp('.+')), findsNothing);

      // PNG gerçekten çözülür (kod çözme motor tarafında → runAsync).
      await tester.runAsync(
        () => precacheImage(image.image, tester.element(find.byType(Image))),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final decoded = tester.widget<RawImage>(find.byType(RawImage)).image;
      expect(decoded, isNotNull);
      expect(decoded!.width, 96);
      expect(decoded.height, 96);
      handle.dispose();
    });

    testWidgets('semanticLabel → Semantics(label, image)', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpApp(
        const Center(
          child: GuLogo(size: 72, semanticLabel: 'Gümüşhane Üniversitesi'),
        ),
      );
      await tester.pump();
      expect(
        tester.getSemantics(find.bySemanticsLabel('Gümüşhane Üniversitesi')),
        matchesSemantics(label: 'Gümüşhane Üniversitesi', isImage: true),
      );
      handle.dispose();
    });

    testWidgets('placeholder: yer tutucu amblem SVG (açık / koyu, K-10)', (
      tester,
    ) async {
      await tester.pumpApp(
        const Center(child: GuLogo(size: 80, placeholder: true)),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(GuLogo)), const Size.square(80));
      expect(_svgAsset(tester), GuLogoAssets.placeholderEmblem);
      expect(find.byType(Image), findsNothing);

      await tester.pumpApp(
        const Center(child: GuLogo(size: 20, placeholder: true)),
        theme: ThemeMode.dark,
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(GuLogo)), const Size.square(20));
      expect(_svgAsset(tester), GuLogoAssets.placeholderEmblemDark);
    });
  });
}
