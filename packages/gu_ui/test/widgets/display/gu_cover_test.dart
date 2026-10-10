// T-03 · GuCover (widget-catalog #49; K-12, K-35, CD-26).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

/// 1 × 1 saydam PNG.
final Uint8List _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

/// Yüklemesi her zaman hata veren görsel sağlayıcı.
class _BrokenImage extends ImageProvider<_BrokenImage> {
  const _BrokenImage();

  @override
  Future<_BrokenImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _BrokenImage key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(
    Future<ImageInfo>.error(StateError('kırık görsel')),
  );
}

ColoredBox _background(WidgetTester tester) => tester.widget<ColoredBox>(
  find.descendant(of: find.byType(GuCover), matching: find.byType(ColoredBox)),
);

SvgPicture _picture(WidgetTester tester) =>
    tester.widget<SvgPicture>(find.byType(SvgPicture));

String _asset(WidgetTester tester) =>
    (_picture(tester).bytesLoader as SvgAssetLoader).assetName;

/// 320 px genişlikte, üstten hizalı kapak.
Widget _host(Widget cover) => Align(
  alignment: Alignment.topLeft,
  child: SizedBox(width: 320, child: cover),
);

void main() {
  group('T-03 · GuCover', () {
    testWidgets('template: varsayılan 16:9, BoxFit.cover, RepaintBoundary', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpApp(
        _host(
          const GuCover.template(
            palette: GuCoverPalette.red,
            pattern: GuCoverPattern.mountain,
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(GuCover)), const Size(320, 180));
      expect(_asset(tester), 'assets/covers/template-red-mountain.svg');
      expect(_picture(tester).fit, BoxFit.cover);
      expect(_picture(tester).excludeFromSemantics, isTrue);
      expect(
        find.descendant(
          of: find.byType(GuCover),
          matching: find.byType(RepaintBoundary),
        ),
        findsOneWidget,
      );
      // Yüklenene kadar görünen zemin: bg.surfaceMuted (css:209).
      expect(_background(tester).color, GuColors.light.bgSurfaceMuted);
      // Köşe kırpması verilmedi → kırpmayı kart yapar.
      expect(find.byType(ClipRRect), findsNothing);
      expect(find.bySemanticsLabel(RegExp('.+')), findsNothing);
      handle.dispose();
    });

    testWidgets('oranlar: 3:2, 1:1 ve fill', (tester) async {
      await tester.pumpApp(
        _host(
          const GuCover.template(
            palette: GuCoverPalette.slate,
            pattern: GuCoverPattern.lines,
            ratio: GuCoverRatio.r3x2,
          ),
        ),
      );
      expect(tester.getSize(find.byType(GuCover)).height, closeTo(213.33, .01));

      await tester.pumpApp(
        _host(
          const GuCover.template(
            palette: GuCoverPalette.slate,
            pattern: GuCoverPattern.lines,
            ratio: GuCoverRatio.r1x1,
          ),
        ),
      );
      expect(tester.getSize(find.byType(GuCover)), const Size(320, 320));

      // fill: parallax başlığı — üst öğenin alanını doldurur (css:395–396).
      await tester.pumpApp(
        const Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            height: GuSizes.parallaxHeight,
            child: GuCover.template(
              palette: GuCoverPalette.bordeaux,
              pattern: GuCoverPattern.waves,
              ratio: GuCoverRatio.fill,
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(GuCover)), const Size(390, 220));
      expect(find.byType(AspectRatio), findsNothing);
      expect(GuCoverRatio.fill.aspectRatio, isNull);
      expect(GuCoverRatio.r16x9.aspectRatio, GuSizes.coverRatio16x9);
    });

    testWidgets('size + borderRadius: EventCard küçük kapağı 48, chip (K-35)', (
      tester,
    ) async {
      await tester.pumpApp(
        const Center(
          child: GuCover.demo(
            slug: 'tiyatro-kulubu',
            ratio: GuCoverRatio.r1x1,
            size: 48,
            borderRadius: GuRadius.borderChip,
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(GuCover)), const Size.square(48));
      expect(_asset(tester), 'assets/covers/tiyatro-kulubu.svg');
      expect(
        tester.widget<ClipRRect>(find.byType(ClipRRect)).borderRadius,
        GuRadius.borderChip,
      );
    });

    testWidgets("overlays kapağın üstünde; CD-26: ayrı ikon widget'ı yok", (
      tester,
    ) async {
      await tester.pumpApp(
        _host(
          const GuCover.template(
            palette: GuCoverPalette.red,
            pattern: GuCoverPattern.dots,
            icon: GuIcons.drama,
            overlays: [
              Positioned(
                left: 10,
                bottom: 10,
                child: SizedBox.square(
                  key: ValueKey<String>('overlay'),
                  dimension: 32,
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final cover = tester.getRect(find.byType(GuCover));
      final overlay = tester.getRect(
        find.byKey(const ValueKey<String>('overlay')),
      );
      expect(overlay.left - cover.left, 10);
      expect(cover.bottom - overlay.bottom, 10);
      // İkon SVG katmanında değiştirilir; ayrı GuIcon widget'ı yok.
      expect(find.byType(GuIcon), findsNothing);
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(_picture(tester).bytesLoader, isNot(isA<SvgAssetLoader>()));
    });

    testWidgets('template: icon yok ya da sparkles → şablon olduğu gibi', (
      tester,
    ) async {
      for (final icon in [null, GuIcons.sparkles]) {
        await tester.pumpApp(
          _host(
            GuCover.template(
              palette: GuCoverPalette.slate,
              pattern: GuCoverPattern.lines,
              icon: icon,
            ),
          ),
        );
        await tester.pump();
        expect(_asset(tester), 'assets/covers/template-slate-lines.svg');
      }
    });

    test('composeTemplate: gömülü sparkles kulüp ikonuyla değişir '
        '(art.js coverArtSVG)', () {
      final template = File(
        '../../assets/covers/template-red-lines.svg',
      ).readAsStringSync();
      final users = File('../../assets/icons/users.svg').readAsStringSync();
      const sparkles = 'M9.937 15.5';
      const usersCircle = '<circle cx="9" cy="7" r="4"/>';
      expect(template, contains(sparkles));

      final composed = GuCovers.composeTemplate(template, users);
      expect(composed, isNot(contains(sparkles)));
      expect(composed, contains(usersCircle));
      // Katman öznitelikleri (beyaz, 1.1, %12) ve desen korunur.
      expect(composed, contains('stroke-width="1.1"'));
      expect(composed, contains('opacity=".12">'));
      expect(composed.length, greaterThan(template.length ~/ 2));
      expect(composed.trimRight(), endsWith('</g></svg>'));

      // Katman ya da ikon gövdesi yoksa şablon aynen döner.
      expect(GuCovers.composeTemplate('<svg></svg>', users), '<svg></svg>');
      expect(GuCovers.composeTemplate(template, 'bozuk'), template);
    });

    testWidgets('image: ImageProvider BoxFit.cover ile çizilir', (
      tester,
    ) async {
      final provider = MemoryImage(_pixel);
      await tester.pumpApp(_host(GuCover.image(image: provider)));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(GuCover)), const Size(320, 180));
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, provider);
      expect(image.fit, BoxFit.cover);
      expect(image.excludeFromSemantics, isTrue);
      expect(find.byType(SvgPicture), findsNothing);
      expect(
        tester.widget<GuCover>(find.byType(GuCover)).assetPath,
        isNull,
      );
    });

    testWidgets('kayıtsız demo kapağı ve kırık görsel: yalnızca zemin', (
      tester,
    ) async {
      await tester.pumpApp(
        _host(const GuCover.demo(slug: 'olmayan-kulup')),
        theme: ThemeMode.dark,
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(GuCover)), const Size(320, 180));
      expect(find.byType(SvgPicture), findsNothing);
      expect(_background(tester).color, GuColors.dark.bgSurfaceMuted);

      await tester.pumpApp(_host(const GuCover.image(image: _BrokenImage())));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(GuCover)), const Size(320, 180));
      expect(find.byType(RawImage), findsNothing);
      expect(_background(tester).color, GuColors.light.bgSurfaceMuted);
    });
  });
}
