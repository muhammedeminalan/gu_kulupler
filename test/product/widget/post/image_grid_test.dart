// T-20 · ImageGrid + PostImage (widget-catalog P14) — gönderi görselleri
// ızgarası: 1 / 2 / 3 / 4 (+ fazlası) yerleşimleri, aralık ve dış köşe, yer
// tutucu (kulüp paleti / varsayılan — K-18), görsel çözücü (yükleniyor / hata
// → yer tutucu altta kalır), dokunma → hücre sırası, anahtarlar,
// erişilebilirlik. Kaynak: prototip `cards.js:92–95`, css:407–408.
import 'dart:typed_data';

import 'package:flutter/material.dart';
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

    testWidgets('görsel çözücü: görsel yer tutucunun üstüne çizilir; çözücü '
        '`null` dönerse ve görsel yüklenemezse yer tutucu kalır (hata '
        'fırlatılmaz)', (tester) async {
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
      await tester.pumpAndSettle();

      final covers = tester.widgetList<GuCover>(find.byType(GuCover)).toList();
      expect(covers.first.overlays, hasLength(1));
      expect(covers.last.overlays, isEmpty);
      final photo = tester.widget<Image>(find.byType(Image));
      expect(photo.image, broken);
      expect(photo.fit, BoxFit.cover);
      expect(photo.errorBuilder, isNotNull);
      expect(tester.takeException(), isNull);
      // Yer tutucu iki hücrede de çizili.
      expect(covers.map((cover) => cover.palette).toSet(), {
        CoverMapper.palette(kClub.palette),
      });
    });
  });
}
