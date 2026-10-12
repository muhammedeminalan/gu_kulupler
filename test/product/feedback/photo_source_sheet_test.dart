// SHT-16 · Fotoğraf kaynağı — kamera / galeri / kaldır menüsü
// (`PhotoSourceSheet`). İçerik, `hasPhoto` koşulu, anahtarlar
// (`SHT-16.camera`, `.gallery`, `.remove`, `.close`, `.scrim`), seçim sonucu
// (`pop(PhotoSourceChoice)`), kapanma yolları, mock ızgaranın yokluğu, cihaz
// matrisi, açık + koyu golden. Referans: design/reference-shots/sheets/
// SHT-16__light.webp, __dark.webp; prototip sheets.js:78–82.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/photo_source_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/action_inventory.dart';
import '../../helpers/design_files.dart';
import '../../helpers/device_matrix.dart';
import '../../helpers/test_l10n.dart';
import 'sheet_test_support.dart';

const Locale _tr = Locale('tr');
const Locale _en = Locale('en');

Key _key(String action) => FeedbackKeys.of(SheetId.sht16.designId, action);

SheetHarness<PhotoSourceChoice> _harness({bool hasPhoto = false}) =>
    SheetHarness<PhotoSourceChoice>(
      SheetId.sht16,
      (_) => PhotoSourceSheet(hasPhoto: hasPhoto),
    );

/// [row] satırının baştaki ikonu.
GuIcon _leading(WidgetTester tester, PhotoSourceChoice row) =>
    tester.widget<GuIcon>(
      find.descendant(
        of: find.byKey(PhotoSourceSheet.keyOf(row)),
        matching: find.byType(GuIcon),
      ),
    );

void main() {
  group('SHT-16 · Fotoğraf kaynağı · sözleşme', () {
    test('anahtarlar prototipteki aksiyon adlarıdır', () {
      expect(
        PhotoSourceSheet.keyOf(PhotoSourceChoice.camera),
        GuKey.action('SHT-16.camera'),
      );
      expect(
        PhotoSourceSheet.keyOf(PhotoSourceChoice.gallery),
        GuKey.action('SHT-16.gallery'),
      );
      expect(
        PhotoSourceSheet.keyOf(PhotoSourceChoice.remove),
        GuKey.action('SHT-16.remove'),
      );
      expect(PhotoSourceChoice.values.map((choice) => choice.action), [
        'camera',
        'gallery',
        'remove',
      ]);
    });

    test('varsayılanlar: görsel yok, tek seçim; `maxImages` en az 1', () {
      const sheet = PhotoSourceSheet();
      expect(sheet.hasPhoto, isFalse);
      expect(sheet.maxImages, 1);
      expect(const PhotoSourceSheet(maxImages: 4).maxImages, 4);
      expect(() => PhotoSourceSheet(maxImages: 0), throwsAssertionError);
    });

    test('`/// Design: SHT-16` izi PhotoSourceSheet sınıfındadır', () {
      final source = readText(
        'lib/product/feedback/catalogs/sheets/photo_source_sheet.dart',
      );
      expect(
        RegExp(r'///\s*Design:\s*SHT-16').allMatches(source),
        hasLength(1),
      );
      expect(
        source,
        contains(RegExp(r'/// Design: SHT-16\s*\nclass PhotoSourceSheet\b')),
      );
    });
  });

  group('SHT-16 · Fotoğraf kaynağı · içerik', () {
    testWidgets('menü çerçevesi; başlık, kapat, "Kamera" + "Galeri" satırları '
        '(22 dp ikon, text.heading) — TR ve EN, açık + koyu', (tester) async {
      for (final theme in [ThemeMode.light, ThemeMode.dark]) {
        for (final locale in [_tr, _en]) {
          final h = _harness();
          await h.pump(tester, locale: locale, theme: theme);
          await h.open(tester);
          final l10n = tester.l10nFor(locale);
          final colors = tester.element(find.byType(GuSheetFrame)).gu.colors;

          final frame = tester.widget<GuSheetFrame>(find.byType(GuSheetFrame));
          expect(frame.title, l10n.sht16Title);
          expect(frame.closeSemanticLabel, l10n.a11yClose);
          expect(frame.menu, isTrue);
          expect(frame.flush, isTrue);
          expect(frame.full, isFalse);
          expect(frame.footer, isNull);
          expect(find.byKey(_key('close')), findsOneWidget);
          expect(find.byKey(_key('scrim')), findsOneWidget);

          final tiles = tester.widgetList<GuTile>(find.byType(GuTile)).toList();
          expect(tiles.map((tile) => tile.title), [
            l10n.sht16Camera,
            l10n.sht16Gallery,
          ]);
          expect(tiles.map((tile) => tile.key), [
            PhotoSourceSheet.keyOf(PhotoSourceChoice.camera),
            PhotoSourceSheet.keyOf(PhotoSourceChoice.gallery),
          ]);
          expect(tiles.map((tile) => tile.danger).toSet(), {false});
          expect(tiles.map((tile) => tile.subtitle).toSet(), {null});
          expect(tiles.map((tile) => tile.chevron).toSet(), {false});
          expect(tiles.map((tile) => tile.padding).toSet(), {
            GuTilePadding.normal,
          });

          final camera = _leading(tester, PhotoSourceChoice.camera);
          expect(camera.icon, GuIcons.camera);
          expect(camera.size, 22);
          expect(camera.color, colors.textHeading);
          final gallery = _leading(tester, PhotoSourceChoice.gallery);
          expect(gallery.icon, GuIcons.images);
          expect(gallery.size, 22);
          expect(gallery.color, colors.textHeading);

          expect(
            find.byKey(PhotoSourceSheet.keyOf(PhotoSourceChoice.remove)),
            findsNothing,
          );
        }
      }
    });

    testWidgets('`hasPhoto`: üçüncü satır "Fotoğrafı kaldır" (trash-2, yıkıcı '
        'renk) — TR ve EN', (tester) async {
      for (final locale in [_tr, _en]) {
        final h = _harness(hasPhoto: true);
        await h.pump(tester, locale: locale);
        await h.open(tester);
        final l10n = tester.l10nFor(locale);
        final colors = tester.element(find.byType(GuSheetFrame)).gu.colors;

        final tiles = tester.widgetList<GuTile>(find.byType(GuTile)).toList();
        expect(tiles.map((tile) => tile.title), [
          l10n.sht16Camera,
          l10n.sht16Gallery,
          l10n.sht16Remove,
        ]);
        expect(tiles.map((tile) => tile.danger), [false, false, true]);
        final remove = _leading(tester, PhotoSourceChoice.remove);
        expect(remove.icon, GuIcons.trash2);
        expect(remove.size, 22);
        expect(remove.color, colors.stateDanger);
      }
    });

    testWidgets('prototipin örnek görsel ızgarası (mock) çizilmez: yalnızca '
        'kaynak satırları ve çerçeve anahtarları vardır', (tester) async {
      final h = _harness(hasPhoto: true);
      await h.pump(tester);
      await h.open(tester);

      expect(ActionInventory.found(tester), {
        'SHT-16.camera',
        'SHT-16.gallery',
        'SHT-16.remove',
        'SHT-16.close',
        'SHT-16.scrim',
      });
      expect(find.byType(GuButton), findsNothing);
      final l10n = tester.l10nFor(_tr);
      expect(find.text(l10n.sht16Pick), findsNothing);
    });

    testWidgets('satırlar 56 dp, tam genişlik; sayfa alta yapışık', (
      tester,
    ) async {
      final h = _harness();
      await h.pump(tester);
      await h.open(tester);

      final frame = tester.getRect(find.byType(GuSheetFrame));
      expect(frame.bottom, 844);
      final camera = tester.getRect(
        find.byKey(PhotoSourceSheet.keyOf(PhotoSourceChoice.camera)),
      );
      final gallery = tester.getRect(
        find.byKey(PhotoSourceSheet.keyOf(PhotoSourceChoice.gallery)),
      );
      expect(camera.height, GuSizes.tileMinHeight);
      expect(gallery.height, GuSizes.tileMinHeight);
      expect(camera.width, frame.width);
      expect(gallery.top, camera.bottom);
      // `.sheet-body.is-flush`: alt dolgu 8.
      expect(frame.bottom - gallery.bottom, 8);
    });
  });

  group('SHT-16 · Fotoğraf kaynağı · sonuç ve kapanma', () {
    testWidgets('satıra dokunma sayfayı seçimle kapatır — kamera, galeri, '
        'kaldır', (tester) async {
      final h = _harness(hasPhoto: true);
      await h.pump(tester);
      for (final choice in PhotoSourceChoice.values) {
        await h.open(tester);
        await tester.tap(find.byKey(PhotoSourceSheet.keyOf(choice)));
        await tester.pumpAndSettle();

        expect(find.byType(GuSheetFrame), findsNothing, reason: choice.name);
        expect(h.result, choice, reason: choice.name);
      }
    });

    testWidgets('kapat düğmesi, scrim ve geri tuşu `null` döndürür', (
      tester,
    ) async {
      final h = _harness();
      await h.pump(tester);
      for (final action in ['close', 'scrim']) {
        await h.open(tester);
        await tester.tap(find.byKey(_key(action)));
        await tester.pumpAndSettle();
        expect(find.byType(GuSheetFrame), findsNothing, reason: action);
        expect(h.isClosed, isTrue, reason: action);
        expect(h.result, isNull, reason: action);
      }

      await h.open(tester);
      await h.back(tester);
      expect(find.byType(GuSheetFrame), findsNothing);
      expect(h.isClosed, isTrue);
      expect(h.result, isNull);
    });

    testWidgets('başlıktan aşağı sürükleme `null` ile kapatır', (tester) async {
      final h = _harness();
      await h.pump(tester);
      await h.open(tester);

      await tester.drag(
        find.text(tester.l10nFor(_tr).sht16Title),
        const Offset(0, GuSizes.sheetDragCloseThreshold + 40),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GuSheetFrame), findsNothing);
      expect(h.isClosed, isTrue);
      expect(h.result, isNull);
    });
  });

  group('SHT-16 · Fotoğraf kaynağı · yerleşim', () {
    testWidgets('cihaz matrisi: taşma yok — iki ve üç satır', (tester) async {
      for (final hasPhoto in [false, true]) {
        await DeviceMatrix.run(
          tester,
          (context) => Align(
            alignment: Alignment.bottomCenter,
            child: PhotoSourceSheet(hasPhoto: hasPhoto),
          ),
          safeAreas: true,
        );
      }
    });

    testWidgets('golden: açık sayfa (scrim dahil) — açık + koyu (TR)', (
      tester,
    ) async {
      await _harness().golden(tester, 'SHT-16');
    });

    testWidgets('golden: "Fotoğrafı kaldır" satırıyla — açık + koyu (TR)', (
      tester,
    ) async {
      await _harness(hasPhoto: true).golden(tester, 'SHT-16__remove');
    });
  });
}
