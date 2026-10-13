// SHT-08 · Gönderi (`PostMenu`): satırlar (kaydet / kaydı kaldır, paylaş,
// bağlantıyı kopyala, şikayet et, kullanıcıyı engelle, düzenle, sabitle /
// sabitlemeyi kaldır, sil), rol × durum süzmesi (kendi gönderisi, içerik
// yöneticisi, kayıtlı, sabit), yönetim ayracı, anahtarlar (`SHT-08.save`,
// `.share`, `.copyLink`, `.report`, `.block`, `.edit`, `.pin`, `.delete`,
// `.close`, `.scrim`), seçim sonucu (`pop(PostMenuAction)`), kapanma yolları,
// dar ekran + büyük metin, açık + koyu golden.
// Referans: design/reference-shots/sheets/SHT-08__light.webp, __dark.webp;
// prototip sheets.js:40–43.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/post_menu.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/action_inventory.dart';
import '../../helpers/design_files.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/test_l10n.dart';
import 'sheet_test_support.dart';

const Locale _tr = Locale('tr');
const Locale _en = Locale('en');

Key _key(String action) => GuKey.action('SHT-08.$action');

SheetHarness<PostMenuAction> _harness({
  bool isOwn = false,
  bool canManage = false,
  bool isSaved = false,
  bool isPinned = false,
}) => SheetHarness<PostMenuAction>(
  SheetId.sht08,
  (_) => PostMenu(
    isOwn: isOwn,
    canManage: canManage,
    isSaved: isSaved,
    isPinned: isPinned,
  ),
);

Future<SheetHarness<PostMenuAction>> _open(
  WidgetTester tester,
  SheetHarness<PostMenuAction> harness, {
  Locale locale = _tr,
  ThemeMode theme = ThemeMode.light,
}) async {
  await harness.pump(tester, locale: locale, theme: theme);
  await harness.open(tester);
  return harness;
}

List<GuTile> _tiles(WidgetTester tester) =>
    tester.widgetList<GuTile>(find.byType(GuTile)).toList();

void main() {
  group('SHT-08 · Gönderi · sözleşme', () {
    test('öğeler tasarım sırasındadır; anahtarlar prototipteki aksiyon '
        'adlarıdır ("Kaydı kaldır" `save`, "Sabitlemeyi kaldır" `pin` '
        'satırını paylaşır)', () {
      expect(PostMenuAction.values.map((action) => action.action), [
        'save',
        'save',
        'share',
        'copyLink',
        'report',
        'block',
        'edit',
        'pin',
        'pin',
        'delete',
      ]);
      expect(PostMenuAction.values.map((action) => action.icon), [
        GuIcons.bookmark,
        GuIcons.bookmark,
        GuIcons.share2,
        GuIcons.link,
        GuIcons.flag,
        GuIcons.ban,
        GuIcons.pencil,
        GuIcons.pin,
        GuIcons.pinOff,
        GuIcons.trash2,
      ]);
      expect(
        [
          for (final action in PostMenuAction.values)
            if (action.isDanger) action,
        ],
        [PostMenuAction.remove],
      );
      expect(
        [
          for (final action in PostMenuAction.values)
            if (action.isManagement) action,
        ],
        [
          PostMenuAction.edit,
          PostMenuAction.pin,
          PostMenuAction.unpin,
          PostMenuAction.remove,
        ],
      );
      expect(PostMenu.keyOf(PostMenuAction.unsave), _key('save'));
      expect(PostMenu.keyOf(PostMenuAction.blockAuthor), _key('block'));
      expect(PostMenu.keyOf(PostMenuAction.remove), _key('delete'));
    });

    test('`actionsFor`: rol × durum satırları', () {
      List<PostMenuAction> rows({
        bool isOwn = false,
        bool canManage = false,
        bool isSaved = false,
        bool isPinned = false,
      }) => PostMenu.actionsFor(
        isOwn: isOwn,
        canManage: canManage,
        isSaved: isSaved,
        isPinned: isPinned,
      );

      // Üye, başkasının gönderisi (referans görüntü).
      expect(rows(), [
        PostMenuAction.save,
        PostMenuAction.share,
        PostMenuAction.copyLink,
        PostMenuAction.report,
        PostMenuAction.blockAuthor,
      ]);
      // Kayıtlı gönderi: "Kaydı kaldır".
      expect(rows(isSaved: true).first, PostMenuAction.unsave);
      // Yönetici, başkasının gönderisi: düzenleyemez (CD-141 (5)).
      expect(rows(canManage: true), [
        PostMenuAction.save,
        PostMenuAction.share,
        PostMenuAction.copyLink,
        PostMenuAction.report,
        PostMenuAction.blockAuthor,
        PostMenuAction.pin,
        PostMenuAction.remove,
      ]);
      // Yönetici, kendi sabit gönderisi: şikayet / engelle yok.
      expect(rows(isOwn: true, canManage: true, isPinned: true), [
        PostMenuAction.save,
        PostMenuAction.share,
        PostMenuAction.copyLink,
        PostMenuAction.edit,
        PostMenuAction.unpin,
        PostMenuAction.remove,
      ]);
      // Yazar ama yönetici değil (eski yönetici): yönetim satırı yok.
      expect(rows(isOwn: true, isPinned: true), [
        PostMenuAction.save,
        PostMenuAction.share,
        PostMenuAction.copyLink,
      ]);
    });

    test('satır adları — TR ve EN', () {
      for (final locale in [_tr, _en]) {
        final l10n = lookupAppLocalizations(locale);
        expect(
          [
            for (final action in PostMenuAction.values)
              PostMenu.labelOf(l10n, action),
          ],
          [
            l10n.feedSave,
            l10n.feedUnsave,
            l10n.commonShare,
            l10n.sht08CopyLink,
            l10n.sht06Report,
            l10n.sht08BlockUser,
            l10n.commonEdit,
            l10n.postPin,
            l10n.postUnpin,
            l10n.commonDelete,
          ],
        );
      }
    });

    test('`/// Design: SHT-08` izi PostMenu sınıfındadır', () {
      final source = readText(
        'lib/product/feedback/catalogs/sheets/post_menu.dart',
      );
      expect(
        source,
        contains(RegExp(r'/// Design: SHT-08\s*\nclass PostMenu\b')),
      );
    });
  });

  group('SHT-08 · Gönderi · içerik', () {
    testWidgets('üye, başkasının gönderisi: menü + flush çerçeve, beş satır, '
        'ayraç yok — TR ve EN, açık + koyu', (tester) async {
      for (final theme in [ThemeMode.light, ThemeMode.dark]) {
        for (final locale in [_tr, _en]) {
          await _open(tester, _harness(), locale: locale, theme: theme);
          final l10n = tester.l10nFor(locale);
          final gu = tester.element(find.byType(GuSheetFrame)).gu;

          final frame = tester.widget<GuSheetFrame>(find.byType(GuSheetFrame));
          expect(frame.title, l10n.sht08Title);
          expect(frame.closeSemanticLabel, l10n.a11yClose);
          expect(frame.menu, isTrue);
          expect(frame.flush, isTrue);
          expect(frame.footer, isNull);

          final tiles = _tiles(tester);
          expect(tiles.map((tile) => tile.title), [
            l10n.feedSave,
            l10n.commonShare,
            l10n.sht08CopyLink,
            l10n.sht06Report,
            l10n.sht08BlockUser,
          ]);
          expect(tiles.any((tile) => tile.danger), isFalse);
          final icons = [for (final tile in tiles) tile.leading! as GuIcon];
          expect(icons.map((icon) => icon.icon), [
            GuIcons.bookmark,
            GuIcons.share2,
            GuIcons.link,
            GuIcons.flag,
            GuIcons.ban,
          ]);
          expect(icons.map((icon) => icon.size).toSet(), {GuSizes.icon22});
          expect(icons.map((icon) => icon.color).toSet(), {
            gu.colors.textHeading,
          });
          expect(find.byType(GuDivider), findsNothing);
          expect(ActionInventory.found(tester), {
            'SHT-08.save',
            'SHT-08.share',
            'SHT-08.copyLink',
            'SHT-08.report',
            'SHT-08.block',
            'SHT-08.close',
            'SHT-08.scrim',
          });
        }
      }
    });

    testWidgets('yönetici, kendi kayıtlı + sabit gönderisi: "Kaydı kaldır", '
        'ayraç, "Düzenle", "Sabitlemeyi kaldır" (`pin-off`), yıkıcı "Sil"', (
      tester,
    ) async {
      await _open(
        tester,
        _harness(isOwn: true, canManage: true, isSaved: true, isPinned: true),
      );
      final l10n = tester.l10n;
      final gu = tester.element(find.byType(GuSheetFrame)).gu;

      final tiles = _tiles(tester);
      expect(tiles.map((tile) => tile.key), [
        _key('save'),
        _key('share'),
        _key('copyLink'),
        _key('edit'),
        _key('pin'),
        _key('delete'),
      ]);
      expect(tiles.map((tile) => tile.title), [
        l10n.feedUnsave,
        l10n.commonShare,
        l10n.sht08CopyLink,
        l10n.commonEdit,
        l10n.postUnpin,
        l10n.commonDelete,
      ]);
      expect((tiles[4].leading! as GuIcon).icon, GuIcons.pinOff);
      expect(tiles.map((tile) => tile.danger), [
        false,
        false,
        false,
        false,
        false,
        true,
      ]);
      expect((tiles.last.leading! as GuIcon).color, gu.colors.stateDanger);

      // Tek ayraç: paylaşım satırlarıyla yönetim satırları arasında.
      expect(find.byType(GuDivider), findsOneWidget);
      final divider = tester.getRect(find.byType(GuDivider));
      expect(
        divider.top,
        greaterThanOrEqualTo(
          tester.getRect(find.byKey(_key('copyLink'))).bottom,
        ),
      );
      expect(
        divider.bottom,
        lessThanOrEqualTo(tester.getRect(find.byKey(_key('edit'))).top),
      );
    });

    testWidgets('yönetici, başkasının gönderisi: ayraç "Sabitle"nin üstünde; '
        '"Düzenle" yok', (tester) async {
      await _open(tester, _harness(canManage: true));
      expect(find.byKey(_key('edit')), findsNothing);
      expect(find.byType(GuDivider), findsOneWidget);
      expect(
        tester.getRect(find.byType(GuDivider)).bottom,
        lessThanOrEqualTo(tester.getRect(find.byKey(_key('pin'))).top),
      );
      expect(
        tester.widget<GuTile>(find.byKey(_key('pin'))).title,
        tester.l10n.postPin,
      );
    });

    testWidgets('320 dp + metin ölçeği 1.6, en uzun menü — TR + EN: taşma yok '
        '(taşma testi düşürür)', (tester) async {
      for (final locale in [_tr, _en]) {
        final harness = _harness(
          canManage: true,
          isSaved: true,
          isPinned: true,
        );
        addTearDown(harness.controller.dispose);
        await tester.pumpApp(
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
          size: const Size(320, 568),
          textScale: 1.6,
        );
        await harness.open(tester);
        expect(find.byType(GuTile), findsNWidgets(7));
        await harness.back(tester);
      }
    });
  });

  group('SHT-08 · Gönderi · sonuç', () {
    testWidgets('her satır sayfayı kendi öğesiyle kapatır (kayıtlı / sabit '
        'durumda `unsave` / `unpin`)', (tester) async {
      for (final (harness, actions) in [
        (
          _harness(canManage: true),
          [
            PostMenuAction.save,
            PostMenuAction.share,
            PostMenuAction.copyLink,
            PostMenuAction.report,
            PostMenuAction.blockAuthor,
            PostMenuAction.pin,
            PostMenuAction.remove,
          ],
        ),
        (
          _harness(isOwn: true, canManage: true, isSaved: true, isPinned: true),
          [PostMenuAction.unsave, PostMenuAction.edit, PostMenuAction.unpin],
        ),
      ]) {
        await harness.pump(tester);
        for (final action in actions) {
          await harness.open(tester);
          await tester.tap(find.byKey(PostMenu.keyOf(action)));
          await tester.pumpAndSettle();

          expect(find.byType(GuSheetFrame), findsNothing, reason: action.name);
          expect(harness.result, action, reason: action.name);
        }
      }
    });

    testWidgets('kapat, scrim ve geri `null` döndürür', (tester) async {
      final harness = await _open(tester, _harness());
      await tester.tap(find.byKey(_key('close')));
      await tester.pumpAndSettle();
      expect(harness.result, isNull);

      await harness.open(tester);
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      expect(harness.result, isNull);

      await harness.open(tester);
      await harness.back(tester);
      expect(harness.result, isNull);
    });
  });

  group('SHT-08 · Gönderi · golden', () {
    testWidgets('golden: açık sayfa (scrim dahil) — açık + koyu (TR)', (
      tester,
    ) async {
      await _harness().golden(tester, 'SHT-08');
    });
  });
}
