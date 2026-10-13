// SHT-34 · Görsel (`ImageViewerSheet` + `ImageViewer`, widget-catalog P16):
// tam ekran siyah görüntüleyici — üst satır (kapat, "i/n" sayacı, paylaş),
// yatay sayfalama, çift dokunuşla yakınlaştırma, aşağı sürükleyerek kapatma
// (eşik 120, solma), ipucu satırı, güvenli alanlar, açık durum çubuğu
// ikonları (CD-89), anahtarlar (`SHT-34.close`, `.share`, `.swipe`,
// `.zoom.<i>`), kapanma yolları, dar ekran + büyük metin, açık + koyu golden.
// Referans: design/reference-shots/sheets/SHT-34__light.webp, __dark.webp;
// prototip sheets.js:155–162, css:409.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/image_viewer_sheet.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/widget/post/image_grid.dart';
import 'package:gu_kulupler/product/widget/post/image_viewer.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../fixtures/club_model_fixtures.dart';
import '../../fixtures/post_model_fixtures.dart';
import '../../helpers/action_inventory.dart';
import '../../helpers/design_files.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/test_l10n.dart';
import 'sheet_test_support.dart';

const Locale _tr = Locale('tr');
const Locale _en = Locale('en');

/// `p02` — `c01` kulübünün iki görselli gönderisi (referans görüntü).
final List<PostImageModel> _images = PostModelFixtures.p02.images;
final ClubModel _club = ClubModelFixtures.c01;

Key _key(String action) => GuKey.action('SHT-34.$action');

SheetHarness<void> _harness({
  int initialIndex = 0,
  VoidCallback? onShare,
  List<PostImageModel>? images,
}) => SheetHarness<void>(
  SheetId.sht34,
  (_) => ImageViewerSheet(
    images: images ?? _images,
    initialIndex: initialIndex,
    club: _club,
    onShare: onShare,
  ),
);

Future<SheetHarness<void>> _open(
  WidgetTester tester,
  SheetHarness<void> harness, {
  Locale locale = _tr,
  ThemeMode theme = ThemeMode.light,
}) async {
  await harness.pump(tester, locale: locale, theme: theme);
  await harness.open(tester);
  return harness;
}

/// [harness] gezginini verilen ekran ölçüleriyle çizer.
Future<void> _pumpSized(
  WidgetTester tester,
  SheetHarness<void> harness, {
  Locale locale = _tr,
  Size size = const Size(390, 844),
  double textScale = 1,
  EdgeInsets viewPadding = EdgeInsets.zero,
}) {
  addTearDown(harness.controller.dispose);
  return tester.pumpApp(
    Builder(
      builder: (context) => DefaultTextStyle(
        style: context.gu.text.bodyM,
        child: Navigator(
          key: harness.navigatorKey,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: SizedBox.expand()),
          ),
        ),
      ),
    ),
    locale: locale,
    size: size,
    textScale: textScale,
    viewPadding: viewPadding,
  );
}

double _scaleOf(WidgetTester tester, int index) => tester
    .widget<AnimatedScale>(
      find.descendant(
        of: find.byKey(_key('zoom.$index')),
        matching: find.byType(AnimatedScale),
      ),
    )
    .scale;

Future<void> _doubleTap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pump(kDoubleTapMinTime);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('SHT-34 · Görsel · sözleşme', () {
    test('anahtarlar prototipteki aksiyon adlarıdır', () {
      expect(ImageViewerSheet.closeKey, _key('close'));
      expect(ImageViewerSheet.shareKey, _key('share'));
      expect(ImageViewerSheet.swipeKey, _key('swipe'));
      expect(ImageViewerSheet.zoomKey(3), _key('zoom.3'));
    });

    test('`/// Design: SHT-34` izi ImageViewerSheet sınıfındadır', () {
      final source = readText(
        'lib/product/feedback/catalogs/sheets/image_viewer_sheet.dart',
      );
      expect(
        source,
        contains(RegExp(r'/// Design: SHT-34\s*\nclass ImageViewerSheet\b')),
      );
    });
  });

  group('SHT-34 · Görsel · içerik', () {
    testWidgets('tam ekran siyah zemin; kapat (ilk odak) + "1/2" + paylaş '
        '(kapak üstü); kare sayfa; ipucu — TR ve EN, açık + koyu', (
      tester,
    ) async {
      for (final theme in [ThemeMode.light, ThemeMode.dark]) {
        for (final locale in [_tr, _en]) {
          await _open(tester, _harness(), locale: locale, theme: theme);
          final l10n = tester.l10nFor(locale);
          final gu = tester.element(find.byType(ImageViewer)).gu;

          expect(
            tester.getSize(find.byType(ImageViewer)),
            const Size(390, 844),
          );
          expect(
            tester
                .widget<ColoredBox>(
                  find
                      .descendant(
                        of: find.byType(ImageViewer),
                        matching: find.byType(ColoredBox),
                      )
                      .first,
                )
                .color,
            gu.component.viewerBackground,
          );
          expect(
            tester.widget<GuSystemUi>(find.byType(GuSystemUi)).style,
            GuSystemUiStyle.lightIcons,
          );
          expect(find.byType(GuSheetFrame), findsNothing);

          final close = tester.widget<GuIconButton>(find.byKey(_key('close')));
          expect(close.icon, GuIcons.x);
          expect(close.semanticLabel, l10n.a11yClose);
          expect(close.onCover, isTrue);
          expect(close.autofocus, isTrue);
          final share = tester.widget<GuIconButton>(find.byKey(_key('share')));
          expect(share.icon, GuIcons.share2);
          expect(share.semanticLabel, l10n.commonShare);
          expect(share.onCover, isTrue);

          final counter = tester.widget<Text>(find.text('1/2'));
          expect(counter.style!.color, gu.component.onCoverForeground);
          expect(counter.style!.fontSize, gu.text.labelL.fontSize);

          final page = tester.getRect(find.byKey(_key('zoom.0')));
          expect(page.size, const Size.square(390));
          final image = tester.widget<PostImage>(find.byType(PostImage));
          expect(image.image, _images.first);
          expect(image.club, _club);

          final hint = tester.widget<Text>(find.text(l10n.sht34ZoomHint));
          expect(hint.style!.color, gu.component.viewerHintForeground);
          expect(hint.textAlign, TextAlign.center);
          expect(ActionInventory.found(tester), {
            'SHT-34.close',
            'SHT-34.share',
            'SHT-34.swipe',
            'SHT-34.zoom.0',
            'SHT-34.scrim',
          });
        }
      }
    });

    testWidgets('yerleşim: üst satır güvenli alan − 4 / 8, ipucu alt güvenli '
        'alan + 12 / 16; güvenli alan yokken üst dolgu 0', (tester) async {
      final harness = _harness();
      await _pumpSized(
        tester,
        harness,
        viewPadding: const EdgeInsets.only(top: 54, bottom: 34),
      );
      await harness.open(tester);
      final l10n = tester.l10n;
      final close = tester.getRect(find.byKey(_key('close')));
      final share = tester.getRect(find.byKey(_key('share')));
      final hint = tester.getRect(find.text(l10n.sht34ZoomHint));
      expect(close.top, 54 - GuSizes.parallaxBarTopOffset);
      expect(close.left, GuSpacing.s8);
      expect(390 - share.right, GuSpacing.s8);
      expect(tester.getCenter(find.text('1/2')).dx, 195);
      expect(844 - hint.bottom, 34 + GuSpacing.s12);
      await harness.back(tester);

      final plain = await _open(tester, _harness());
      expect(tester.getRect(find.byKey(_key('close'))).top, 0);
      await plain.back(tester);
    });

    testWidgets(
      '`initialIndex` sayfasından açılır (sınır dışı değer kırpılır); '
      'kaydırınca sayaç ilerler',
      (tester) async {
        await _open(tester, _harness(initialIndex: 1));
        expect(find.text('2/2'), findsOneWidget);
        expect(find.byKey(_key('zoom.1')), findsOneWidget);

        await tester.fling(
          find.byKey(_key('swipe')),
          const Offset(300, 0),
          1000,
        );
        await tester.pumpAndSettle();
        expect(find.text('1/2'), findsOneWidget);

        await _open(tester, _harness(initialIndex: 9));
        expect(find.text('2/2'), findsOneWidget);
      },
    );

    testWidgets('320 dp + metin ölçeği 1.6 — TR + EN: taşma yok (taşma testi '
        'düşürür)', (tester) async {
      for (final locale in [_tr, _en]) {
        final harness = _harness();
        await _pumpSized(
          tester,
          harness,
          locale: locale,
          size: const Size(320, 568),
          textScale: 1.6,
        );
        await harness.open(tester);
        expect(find.byType(ImageViewer), findsOneWidget);
        await harness.back(tester);
      }
    });
  });

  group('SHT-34 · Görsel · etkileşim', () {
    testWidgets('çift dokunuş etkin sayfayı 1.8 kat yakınlaştırır, ikincisi '
        'geri alır (`GuMotion.viewerZoom`); tek dokunuş bir şey yapmaz', (
      tester,
    ) async {
      await _open(tester, _harness());
      final page = find.byKey(_key('zoom.0'));
      expect(_scaleOf(tester, 0), 1);

      await tester.tap(page);
      await tester.pumpAndSettle();
      expect(_scaleOf(tester, 0), 1);

      await _doubleTap(tester, page);
      expect(_scaleOf(tester, 0), GuSizes.viewerZoomScale);
      final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scale.duration, GuMotion.viewerZoom);
      expect(scale.curve, GuMotion.easeEmphasized);

      await _doubleTap(tester, page);
      expect(_scaleOf(tester, 0), 1);
    });

    testWidgets(
      'aşağı sürükleme: görüntüleyici parmakla iner ve solar; eşiği (120) '
      'aşınca kapanır, kısa sürükleme yerine döner; yakınlaştırılmışken '
      'sürüklenmez',
      (tester) async {
        final harness = await _open(tester, _harness());
        final center = tester.getCenter(find.byKey(_key('swipe')));
        double opacity() => tester
            .widget<Opacity>(
              find
                  .descendant(
                    of: find.byType(ImageViewer),
                    matching: find.byType(Opacity),
                  )
                  .first,
            )
            .opacity;
        double offset() => tester.getTopLeft(find.byKey(_key('close'))).dy;

        // Kısa sürükleme: taşınır + solar, bırakınca yerine döner.
        var gesture = await tester.startGesture(center);
        await gesture.moveBy(const Offset(0, 30));
        await gesture.moveBy(const Offset(0, 50));
        await tester.pump();
        final moved = offset();
        expect(moved, greaterThan(0));
        expect(moved, lessThanOrEqualTo(80));
        expect(
          opacity(),
          closeTo(1 - moved / GuSizes.viewerDragFadeDistance, 0.001),
        );
        await gesture.up();
        await tester.pumpAndSettle();
        expect(harness.isClosed, isFalse);
        expect(offset(), 0);
        expect(opacity(), 1);

        // Yakınlaştırılmışken sürükleme yok sayılır.
        await _doubleTap(tester, find.byKey(_key('zoom.0')));
        gesture = await tester.startGesture(center);
        await gesture.moveBy(const Offset(0, 30));
        await gesture.moveBy(const Offset(0, 200));
        await tester.pump();
        expect(offset(), 0);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(harness.isClosed, isFalse);
        await _doubleTap(tester, find.byKey(_key('zoom.0')));

        // Eşiği aşan sürükleme kapatır.
        gesture = await tester.startGesture(center);
        await gesture.moveBy(const Offset(0, 30));
        await gesture.moveBy(const Offset(0, 150));
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();
        expect(harness.isClosed, isTrue);
        expect(find.byType(ImageViewer), findsNothing);
      },
    );

    testWidgets('kapat ve geri sayfayı kapatır; paylaş `onShare` çağırır ve '
        'sayfa açık kalır', (tester) async {
      var shared = 0;
      final harness = await _open(tester, _harness(onShare: () => shared++));

      await tester.tap(find.byKey(_key('share')));
      await tester.pumpAndSettle();
      expect(shared, 1);
      expect(harness.isClosed, isFalse);

      await tester.tap(find.byKey(_key('close')));
      await tester.pumpAndSettle();
      expect(harness.isClosed, isTrue);

      await harness.open(tester);
      await harness.back(tester);
      expect(harness.isClosed, isTrue);
    });

    testWidgets('erişilebilirlik: "Görsel" adlı kapsam; sayfa ipucu metniyle '
        'okunan, dokunma eylemli düğmedir', (tester) async {
      final handle = tester.ensureSemantics();
      await _open(tester, _harness());
      final l10n = tester.l10n;
      expect(find.bySemanticsLabel(l10n.sht34Title), findsOneWidget);
      final page = tester.getSemantics(find.byKey(_key('zoom.0')));
      expect(
        page,
        isSemantics(
          label: l10n.sht34ZoomHint,
          isButton: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });
  });

  group('SHT-34 · Görsel · golden', () {
    testWidgets('golden: açık görüntüleyici — açık + koyu (TR)', (
      tester,
    ) async {
      await _harness().golden(tester, 'SHT-34');
    });
  });
}
