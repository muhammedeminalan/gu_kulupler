// T-20 · ImageGrid + PostImage (widget-catalog P14) — gönderi görselleri
// ızgarası: 1 / 2 / 3 / 4 (+ fazlası) yerleşimleri, aralık ve dış köşe, yer
// tutucu (kulüp paleti / varsayılan — K-18), görsel çözücü (yer tutucu
// yalnızca yükleniyor / hata sırasında — T-44), dokunma → hücre sırası,
// anahtarlar,
// erişilebilirlik. Kaynak: prototip `cards.js:92–95`, css:407–408.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/product/widget/club/cover_mapper.dart';
import 'package:gu_kulupler/product/widget/post/image_grid.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../helpers/test_l10n.dart';
import 'post_test_support.dart';

Key _imageKey(int index) => GuKey.action('FED-01.image.p99.$index');

/// 390 − 2 × 16 dolgu.
const double _width = 358;
const double _gap = GuSizes.imageGridGap;

Future<void> _pump(
  WidgetTester tester,
  int count, {
  ValueChanged<int>? onOpen,
}) => pumpPost(
  tester,
  ImageGrid(
    images: imagesOf(count),
    club: kClub,
    onOpen: onOpen,
    imageKey: _imageKey,
  ),
);

Rect _cell(WidgetTester tester, int index) =>
    tester.getRect(find.byKey(_imageKey(index)));

/// Gerçek kod çözücünün sonucu için beklenen süre.
const Duration _decodeSettle = Duration(milliseconds: 200);

/// 2 × 2 opak (siyah) PNG — gerçek kodlayıcıyla.
Future<Uint8List> _opaquePng() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 2, 2), Paint());
  final picture = recorder.endRecording();
  final image = await picture.toImage(2, 2);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  group('T-20 · ImageGrid · yerleşim', () {
    testWidgets('1 görsel: tek hücre 16:9; dış köşe 14 ile kırpılır', (
      tester,
    ) async {
      await _pump(tester, 1);
      final cell = _cell(tester, 0);
      expect(cell.width, _width);
      expect(cell.height, closeTo(_width * 9 / 16, 0.01));
      expect(find.byType(PostImage), findsOneWidget);
      expect(
        tester
            .widget<ClipRRect>(
              find
                  .descendant(
                    of: find.byType(ImageGrid),
                    matching: find.byType(ClipRRect),
                  )
                  .first,
            )
            .borderRadius,
        GuRadius.borderImageGrid,
      );
    });

    testWidgets('2 görsel: yan yana iki kare, aralık 4', (tester) async {
      await _pump(tester, 2);
      const side = (_width - _gap) / 2;
      final a = _cell(tester, 0);
      final b = _cell(tester, 1);
      expect(a.size, const Size(side, side));
      expect(b.size, const Size(side, side));
      expect(b.left - a.right, _gap);
      expect(b.top, a.top);
    });

    testWidgets('3 görsel: solda iki satırlık geniş hücre (2 pay), sağda alt '
        'alta iki kare (1 pay)', (tester) async {
      await _pump(tester, 3);
      const small = (_width - _gap) / 3;
      final wide = _cell(tester, 0);
      final top = _cell(tester, 1);
      final bottom = _cell(tester, 2);
      expect(wide.width, closeTo(small * 2, 0.01));
      expect(wide.height, closeTo(small * 2 + _gap, 0.01));
      for (final cell in [top, bottom]) {
        expect(cell.width, closeTo(small, 0.01));
        expect(cell.height, closeTo(small, 0.01));
        expect(cell.left - wide.right, closeTo(_gap, 0.01));
      }
      expect(bottom.top - top.bottom, closeTo(_gap, 0.01));
      expect(bottom.bottom, closeTo(wide.bottom, 0.01));
    });

    testWidgets('4 görsel: 2 × 2 kare; dörtten fazlası çizilmez; boş liste '
        'yer kaplamaz', (tester) async {
      for (final count in [4, 6]) {
        await _pump(tester, count);
        const side = (_width - _gap) / 2;
        expect(find.byType(PostImage), findsNWidgets(ImageGrid.maxCells));
        for (var index = 0; index < ImageGrid.maxCells; index++) {
          expect(_cell(tester, index).size, const Size(side, side));
        }
        expect(_cell(tester, 1).left - _cell(tester, 0).right, _gap);
        expect(_cell(tester, 2).top - _cell(tester, 0).bottom, _gap);
        expect(_cell(tester, 3).left, _cell(tester, 1).left);
      }

      await _pump(tester, 0);
      expect(find.byType(PostImage), findsNothing);
      expect(tester.getSize(find.byType(ImageGrid)).height, 0);
    });
  });

  group('T-20 · ImageGrid · hücre', () {
    testWidgets('dokunma hücre sırasını verir; hücre "Görseli aç (n)" etiketli '
        'düğmedir; `onOpen` yoksa düğme değildir', (tester) async {
      final handle = tester.ensureSemantics();
      final opened = <int>[];
      await _pump(tester, 3, onOpen: opened.add);
      final l10n = tester.l10n;

      await tester.tap(find.byKey(_imageKey(2)));
      await tester.tap(find.byKey(_imageKey(0)));
      expect(opened, [2, 0]);
      for (var index = 0; index < 3; index++) {
        expect(
          tester.getSemantics(find.byKey(_imageKey(index))),
          isSemantics(
            label: l10n.a11yOpenImage(index + 1),
            isButton: true,
            hasTapAction: true,
          ),
        );
      }

      await _pump(tester, 1);
      expect(find.bySemanticsLabel(l10n.a11yOpenImage(1)), findsNothing);
      handle.dispose();
    });

    testWidgets('yer tutucu (K-18): kulüp varsa palet × desen + kulüp ikonu, '
        'yoksa `slate` + `image`; üst öğeyi doldurur', (tester) async {
      await _pump(tester, 1);
      var cover = tester.widget<GuCover>(find.byType(GuCover));
      expect(cover.palette, CoverMapper.palette(kClub.palette));
      expect(cover.pattern, CoverMapper.pattern(kClub.pattern));
      expect(cover.icon, CoverMapper.icon(kClub.iconName));
      expect(cover.ratio, GuCoverRatio.fill);
      expect(cover.overlays, isEmpty);

      await pumpPost(tester, ImageGrid(images: imagesOf(1)));
      cover = tester.widget<GuCover>(find.byType(GuCover));
      expect(cover.palette, GuCoverPalette.slate);
      expect(cover.pattern, GuCoverPattern.dots);
      expect(cover.icon, GuIcons.image);
    });

    testWidgets('görsel çözücü: görsel yüklenemezse `errorBuilder` hücreye '
        'yer tutucuyu çizer (hata fırlatılmaz)', (tester) async {
      final images = imagesOf(2);
      // Bozuk baytlar: çözümleme hatası → `errorBuilder`.
      final broken = MemoryImage(Uint8List.fromList([0, 1, 2, 3]));
      await pumpPost(
        tester,
        ImageGrid(
          images: images,
          club: kClub,
          imageOf: (image) => image == images.first ? broken : null,
        ),
      );
      // Gerçek kod çözücünün hatası gerçek zamanda gelir.
      await tester.runAsync(() => Future<void>.delayed(_decodeSettle));
      await tester.pump();

      expect(tester.takeException(), isNull);
      final photo = tester.widget<Image>(find.byType(Image));
      expect(photo.image, broken);
      expect(photo.fit, BoxFit.cover);
      expect(
        find.descendant(of: find.byType(Image), matching: find.byType(GuCover)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(Image),
          matching: find.byType(RawImage),
        ),
        findsNothing,
      );
      final covers = tester.widgetList<GuCover>(find.byType(GuCover)).toList();
      expect(covers, hasLength(2));
      expect(covers.map((cover) => cover.palette).toSet(), {
        CoverMapper.palette(kClub.palette),
      });
    });

    testWidgets('görsel çözücü `null` dönerse hücre yalnızca yer tutucudur', (
      tester,
    ) async {
      await pumpPost(
        tester,
        ImageGrid(images: imagesOf(1), club: kClub, imageOf: (_) => null),
      );
      expect(find.byType(GuCover), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('T-44 · P1-04: opak görselin ilk karesi gelince yer tutucu '
        '(SVG) çizilmez; yüklenirken yer tutucu görünür', (tester) async {
      late final Uint8List bytes;
      await tester.runAsync(() async => bytes = await _opaquePng());
      final photo = MemoryImage(bytes);
      await pumpPost(
        tester,
        ImageGrid(images: imagesOf(1), club: kClub, imageOf: (_) => photo),
      );
      // Kare gelmeden: yer tutucu + görsel katmanı.
      expect(find.byType(GuCover), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);

      await tester.runAsync(
        () => precacheImage(photo, tester.element(find.byType(Image))),
      );
      await tester.pump();

      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(GuCover), findsNothing);
      expect(find.byType(SvgPicture), findsNothing);
      expect(
        tester.widget<RawImage>(find.byType(RawImage)).image,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
