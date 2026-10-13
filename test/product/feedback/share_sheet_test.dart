// SHT-15 · Paylaş — öğe özeti + dört paylaşım yolu (`ShareSheet`). İçerik,
// anahtarlar (`SHT-15.copyLink`, `.whatsapp`, `.email`, `.other`, `.close`,
// `.scrim`), seçim sonucu (`pop(ShareChoice)`), kapanma yolları, harici
// adresler (`ShareLinks`), cihaz matrisi, açık + koyu golden. Referans:
// design/reference-shots/sheets/SHT-15__light.webp, __dark.webp; prototip
// sheets.js:74–76; K-D (`AppConstants.shareBaseUrl`).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/core/constants/app_constants.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/share_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../fixtures/club_model_fixtures.dart';
import '../../helpers/action_inventory.dart';
import '../../helpers/design_files.dart';
import '../../helpers/device_matrix.dart';
import '../../helpers/test_l10n.dart';
import 'sheet_test_support.dart';

const Locale _tr = Locale('tr');
const Locale _en = Locale('en');

/// Referans görüntüdeki öğe: `c01` kulübü.
final String _title = ClubModelFixtures.c01.name;
const String _url = '${AppConstants.shareBaseUrl}/clubs/c01';
const String _displayUrl = 'kulupler.gumushane.edu.tr/clubs/c01';

const String _longTitle =
    'Yazılım, Yapay Zekâ, Robotik, Siber Güvenlik ve Açık Kaynak Teknolojileri '
    'Öğrenci Topluluğu Genel Kurul Duyurusu ve Yeni Dönem Etkinlik Takvimi';
const String _longUrl =
    '${AppConstants.shareBaseUrl}/clubs/c01/posts/'
    'p0123456789abcdef0123456789abcdef0123456789abcdef';

Key _key(String action) => FeedbackKeys.of(SheetId.sht15.designId, action);

SheetHarness<ShareChoice> _harness({String? title, String url = _url}) =>
    SheetHarness<ShareChoice>(
      SheetId.sht15,
      (_) => ShareSheet(title: title ?? _title, url: url),
    );

GuIcon _leading(WidgetTester tester, ShareChoice row) => tester.widget<GuIcon>(
  find.descendant(
    of: find.byKey(ShareSheet.keyOf(row)),
    matching: find.byType(GuIcon),
  ),
);

void main() {
  group('SHT-15 · Paylaş · sözleşme', () {
    test('anahtarlar prototipteki aksiyon adlarıdır', () {
      expect(
        [for (final choice in ShareChoice.values) ShareSheet.keyOf(choice)],
        [
          GuKey.action('SHT-15.copyLink'),
          GuKey.action('SHT-15.whatsapp'),
          GuKey.action('SHT-15.email'),
          GuKey.action('SHT-15.other'),
        ],
      );
      expect(ShareChoice.values.map((choice) => choice.action), [
        'copyLink',
        'whatsapp',
        'email',
        'other',
      ]);
    });

    test('`/// Design: SHT-15` izi ShareSheet sınıfındadır', () {
      final source = readText(
        'lib/product/feedback/catalogs/sheets/share_sheet.dart',
      );
      expect(
        RegExp(r'///\s*Design:\s*SHT-15').allMatches(source),
        hasLength(1),
      );
      expect(
        source,
        contains(RegExp(r'/// Design: SHT-15\s*\nclass ShareSheet\b')),
      );
    });
  });

  group('SHT-15 · Paylaş · ShareLinks', () {
    test('display: şema atılır (`kulupler.gumushane.edu.tr/clubs/c01`)', () {
      expect(ShareLinks.display(_url), _displayUrl);
      expect(
        ShareLinks.display('${AppConstants.shareBaseUrl}/events/e01'),
        'kulupler.gumushane.edu.tr/events/e01',
      );
      expect(
        ShareLinks.display('http://example.org/a?b=c'),
        'example.org/a?b=c',
      );
      // Şemasız ya da ayrıştırılamayan metin olduğu gibi kalır.
      expect(ShareLinks.display(_displayUrl), _displayUrl);
      expect(ShareLinks.display(''), '');
      expect(ShareLinks.display('::::'), '::::');
    });

    test('whatsApp: `https://wa.me/?text=<kodlanmış bağlantı>`', () {
      final uri = ShareLinks.whatsApp(_url);
      expect(
        uri.toString(),
        'https://wa.me/?text=https%3A%2F%2Fkulupler.gumushane.edu.tr'
        '%2Fclubs%2Fc01',
      );
      expect(uri.scheme, 'https');
      expect(uri.host, 'wa.me');
      expect(uri.queryParameters, {'text': _url});
    });

    test('whatsApp: ayırıcılar ve boşluk yüzde kodlanır (`+` değil)', () {
      const text = 'a b&c=d?e#f+g';
      final uri = ShareLinks.whatsApp(text);
      expect(
        uri.toString(),
        'https://wa.me/?text=a%20b%26c%3Dd%3Fe%23f%2Bg',
      );
      expect(
        Uri.decodeComponent(uri.query.substring('text='.length)),
        text,
      );
    });

    test('email: `mailto:?subject=<kodlanmış başlık>`; Türkçe harf ve boşluk '
        'yüzde kodlanır', () {
      final uri = ShareLinks.email(_title);
      expect(uri.scheme, 'mailto');
      expect(uri.path, isEmpty);
      expect(uri.toString(), startsWith('mailto:?subject='));
      expect(uri.toString(), isNot(contains(' ')));
      expect(uri.toString(), isNot(contains('+')));
      expect(
        Uri.decodeComponent(uri.query.substring('subject='.length)),
        _title,
      );
      expect(
        ShareLinks.email('Bahar & Güz').toString(),
        'mailto:?subject=Bahar%20%26%20G%C3%BCz',
      );
      expect(ShareLinks.email('').toString(), 'mailto:?subject=');
    });
  });

  group('SHT-15 · Paylaş · içerik', () {
    testWidgets('menü çerçevesi; özet kartı (başlık + şemasız bağlantı); '
        'dört satır (22 dp ikon, text.heading) — TR ve EN, açık + koyu', (
      tester,
    ) async {
      for (final theme in [ThemeMode.light, ThemeMode.dark]) {
        for (final locale in [_tr, _en]) {
          final h = _harness();
          await h.pump(tester, locale: locale, theme: theme);
          await h.open(tester);
          final l10n = tester.l10nFor(locale);
          final gu = tester.element(find.byType(GuSheetFrame)).gu;

          final frame = tester.widget<GuSheetFrame>(find.byType(GuSheetFrame));
          expect(frame.title, l10n.sht15Title);
          expect(frame.closeSemanticLabel, l10n.a11yClose);
          expect(frame.menu, isTrue);
          expect(frame.flush, isTrue);
          expect(frame.full, isFalse);
          expect(frame.footer, isNull);
          expect(find.byKey(_key('close')), findsOneWidget);
          expect(find.byKey(_key('scrim')), findsOneWidget);

          final card = tester.widget<GuCard>(find.byType(GuCard));
          expect(card.muted, isTrue);
          expect(card.onTap, isNull);
          expect(card.padding, GuCard.bodyPadding);
          final title = tester.widget<Text>(find.text(_title));
          expect(title.style!.fontSize, gu.text.labelL.fontSize);
          expect(title.style!.fontWeight, gu.text.labelL.fontWeight);
          expect(title.style!.color, gu.colors.textHeading);
          expect(title.maxLines, 2);
          expect(title.overflow, TextOverflow.ellipsis);
          final link = tester.widget<Text>(find.text(_displayUrl));
          expect(link.style, gu.text.caption);
          expect(link.maxLines, 1);
          expect(link.overflow, TextOverflow.ellipsis);
          // Tam bağlantı (şemalı) ekranda yazmaz.
          expect(find.text(_url), findsNothing);

          final tiles = tester.widgetList<GuTile>(find.byType(GuTile)).toList();
          expect(tiles.map((tile) => tile.title), [
            l10n.sht08CopyLink,
            ShareSheet.whatsAppLabel,
            l10n.authEmail,
            l10n.sht15Other,
          ]);
          expect(tiles.map((tile) => tile.key), [
            for (final choice in ShareChoice.values) ShareSheet.keyOf(choice),
          ]);
          expect(tiles.map((tile) => tile.danger).toSet(), {false});
          expect(tiles.map((tile) => tile.subtitle).toSet(), {null});
          expect(tiles.map((tile) => tile.chevron).toSet(), {false});
          expect(tiles.map((tile) => tile.padding).toSet(), {
            GuTilePadding.normal,
          });

          const icons = <ShareChoice, GuIcons>{
            ShareChoice.copyLink: GuIcons.link,
            ShareChoice.whatsapp: GuIcons.messageCircle,
            ShareChoice.email: GuIcons.mail,
            ShareChoice.other: GuIcons.moreHorizontal,
          };
          for (final MapEntry(key: choice, value: icon) in icons.entries) {
            final leading = _leading(tester, choice);
            expect(leading.icon, icon, reason: choice.name);
            expect(leading.size, GuSizes.icon22, reason: choice.name);
            expect(leading.color, gu.colors.textHeading, reason: choice.name);
          }
        }
      }
    });

    testWidgets('marka adı çevrilmez: "WhatsApp" iki dilde aynıdır', (
      tester,
    ) async {
      expect(ShareSheet.whatsAppLabel, 'WhatsApp');
      for (final locale in [_tr, _en]) {
        final h = _harness();
        await h.pump(tester, locale: locale);
        await h.open(tester);
        expect(find.text('WhatsApp'), findsOneWidget);
      }
    });

    testWidgets('aksiyon anahtarları: dört satır + kapat + scrim; prototipin '
        'demo toast kaydı (TST-58) yoktur', (tester) async {
      final h = _harness();
      await h.pump(tester);
      await h.open(tester);
      expect(ActionInventory.found(tester), {
        'SHT-15.copyLink',
        'SHT-15.whatsapp',
        'SHT-15.email',
        'SHT-15.other',
        'SHT-15.close',
        'SHT-15.scrim',
      });
      expect(find.byType(GuButton), findsNothing);
    });

    testWidgets('ölçüler: kart 16 dp içeride, altında 16 boşluk; satırlar '
        '56 dp, tam genişlik; sayfa alta yapışık', (tester) async {
      final h = _harness();
      await h.pump(tester);
      await h.open(tester);

      final frame = tester.getRect(find.byType(GuSheetFrame));
      expect(frame.bottom, 844);
      final card = tester.getRect(find.byType(GuCard));
      expect(card.left, 16);
      expect(card.right, 390 - 16);
      final title = tester.getRect(find.text(_title));
      final link = tester.getRect(find.text(_displayUrl));
      // `.card-body` 16 (+ kart kenarlığı), `.col.gap4`.
      expect(
        title.left - card.left,
        GuSizes.cardBodyPadding + GuSizes.cardBorder,
      );
      expect(
        title.top - card.top,
        GuSizes.cardBodyPadding + GuSizes.cardBorder,
      );
      expect(link.top - title.bottom, GuSpacing.s4);
      expect(
        card.bottom - link.bottom,
        GuSizes.cardBodyPadding + GuSizes.cardBorder,
      );

      final rects = [
        for (final choice in ShareChoice.values)
          tester.getRect(find.byKey(ShareSheet.keyOf(choice))),
      ];
      expect(rects.first.top - card.bottom, GuSpacing.s16);
      for (final rect in rects) {
        expect(rect.height, GuSizes.tileMinHeight);
        expect(rect.width, frame.width);
      }
      for (var i = 1; i < rects.length; i++) {
        expect(rects[i].top, rects[i - 1].bottom);
      }
      // `.sheet-body.is-flush`: alt dolgu 8.
      expect(
        frame.bottom - rects.last.bottom,
        GuSizes.sheetBodyFlushPaddingBottom,
      );
    });

    testWidgets('uzun başlık iki satırda, uzun bağlantı tek satırda kesilir; '
        'kart taşmaz', (tester) async {
      final h = _harness(title: _longTitle, url: _longUrl);
      await h.pump(tester);
      await h.open(tester);
      final gu = tester.element(find.byType(GuSheetFrame)).gu;

      final card = tester.getRect(find.byType(GuCard));
      final title = tester.getRect(find.text(_longTitle));
      final link = tester.getRect(find.text(ShareLinks.display(_longUrl)));
      final titleLine = gu.text.labelL.fontSize! * gu.text.labelL.height!;
      final linkLine = gu.text.caption.fontSize! * gu.text.caption.height!;
      expect(title.height, closeTo(titleLine * 2, 0.5));
      expect(link.height, closeTo(linkLine, 0.5));
      expect(title.right, lessThanOrEqualTo(card.right));
      expect(link.right, lessThanOrEqualTo(card.right));
      expect(tester.takeException(), isNull);
    });
  });

  group('SHT-15 · Paylaş · sonuç ve kapanma', () {
    testWidgets('satıra dokunma sayfayı seçimle kapatır — kopyala, WhatsApp, '
        'e-posta, diğer', (tester) async {
      final h = _harness();
      await h.pump(tester);
      for (final choice in ShareChoice.values) {
        await h.open(tester);
        await tester.tap(find.byKey(ShareSheet.keyOf(choice)));
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
        await tester.tap(find.byKey(_key(action)), warnIfMissed: false);
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
        find.text(tester.l10nFor(_tr).sht15Title),
        const Offset(0, GuSizes.sheetDragCloseThreshold + 40),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GuSheetFrame), findsNothing);
      expect(h.isClosed, isTrue);
      expect(h.result, isNull);
    });
  });

  group('SHT-15 · Paylaş · yerleşim', () {
    testWidgets('cihaz matrisi: taşma yok — kısa ve uzun içerik', (
      tester,
    ) async {
      for (final (title, url) in [(_title, _url), (_longTitle, _longUrl)]) {
        await DeviceMatrix.run(
          tester,
          (context) => Align(
            alignment: Alignment.bottomCenter,
            child: ShareSheet(title: title, url: url),
          ),
          safeAreas: true,
        );
      }
    });

    testWidgets('golden: açık sayfa (scrim dahil) — açık + koyu (TR)', (
      tester,
    ) async {
      await _harness().golden(tester, 'SHT-15');
    });
  });
}
