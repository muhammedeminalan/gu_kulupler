// SHT-27 · Kullanıcı (`UserMenuSheet`): satırlar (profili gör, yorum
// satırları, engelle / engeli kaldır, kullanıcıyı şikayet et), süzme (kendi
// menüsü, engel durumu — oturumdan ya da çağırandan, yorum bağlamı),
// anahtarlar (`SHT-27.profile`, `.deleteComment`, `.reportComment`, `.block`,
// `.report`, `.close`, `.scrim`), seçim sonucu (`pop(UserMenuAction)`),
// kapanma yolları, dar ekran + büyük metin, açık + koyu golden.
// Referans: design/reference-shots/sheets/SHT-27__light.webp, __dark.webp;
// prototip sheets.js:130–132.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/user_menu_sheet.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../fakes/fake_session_states.dart';
import '../../helpers/action_inventory.dart';
import '../../helpers/design_files.dart';
import '../../helpers/golden_helper.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/test_l10n.dart';
import 'sheet_test_support.dart';

const Locale _tr = Locale('tr');
const Locale _en = Locale('en');

/// Referans görüntüdeki kullanıcı.
const String _userId = 'u001';
const String _userName = 'Yiğit Kılıç';

Key _key(String action) => GuKey.action('SHT-27.$action');

SheetHarness<UserMenuAction> _harness({
  String userId = _userId,
  String? userName = _userName,
  String? commentId,
  bool canDeleteComment = false,
  bool? isBlocked,
}) => SheetHarness<UserMenuAction>(
  SheetId.sht27,
  (_) => UserMenuSheet(
    userId: userId,
    userName: userName,
    commentId: commentId,
    canDeleteComment: canDeleteComment,
    isBlocked: isBlocked,
  ),
);

/// Sayfanın arkasındaki gezgini [session] oturumuyla çizer (`SheetHarness
/// .pump`'ın oturum ezmeli karşılığı).
Future<void> _pump(
  WidgetTester tester,
  SheetHarness<UserMenuAction> harness, {
  SessionState session = FakeSessionStates.active,
  Locale locale = _tr,
  ThemeMode theme = ThemeMode.light,
  Size size = const Size(390, 844),
  double textScale = 1.0,
}) => tester.pumpApp(
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
  theme: theme,
  size: size,
  textScale: textScale,
  overrides: [sessionViewModelProvider.overrideWithBuild((_, _) => session)],
);

/// [harness] sayfasını [session] oturumuyla açar.
Future<SheetHarness<UserMenuAction>> _open(
  WidgetTester tester,
  SheetHarness<UserMenuAction> harness, {
  SessionState session = FakeSessionStates.active,
  Locale locale = _tr,
  ThemeMode theme = ThemeMode.light,
}) async {
  addTearDown(harness.controller.dispose);
  await _pump(tester, harness, session: session, locale: locale, theme: theme);
  await harness.open(tester);
  return harness;
}

List<GuTile> _tiles(WidgetTester tester) =>
    tester.widgetList<GuTile>(find.byType(GuTile)).toList();

void main() {
  group('SHT-27 · Kullanıcı · sözleşme', () {
    test('öğeler tasarım sırasındadır; anahtarlar prototipteki aksiyon '
        'adlarıdır ("Engeli kaldır" `block` satırını paylaşır)', () {
      expect(UserMenuAction.values.map((action) => action.action), [
        'profile',
        'deleteComment',
        'reportComment',
        'block',
        'block',
        'report',
      ]);
      expect(UserMenuAction.values.map((action) => action.icon), [
        GuIcons.user,
        GuIcons.trash2,
        GuIcons.flag,
        GuIcons.ban,
        GuIcons.ban,
        GuIcons.flag,
      ]);
      expect(
        [for (final action in UserMenuAction.values) action.isDanger],
        [false, true, false, true, false, false],
      );
      expect(UserMenuSheet.keyOf(UserMenuAction.viewProfile), _key('profile'));
      expect(UserMenuSheet.keyOf(UserMenuAction.unblock), _key('block'));
    });

    test('`actionsFor`: kendi menüsü, engel durumu ve yorum bağlamı', () {
      expect(UserMenuSheet.actionsFor(isSelf: false, isBlocked: false), [
        UserMenuAction.viewProfile,
        UserMenuAction.block,
        UserMenuAction.report,
      ]);
      expect(UserMenuSheet.actionsFor(isSelf: false, isBlocked: true), [
        UserMenuAction.viewProfile,
        UserMenuAction.unblock,
        UserMenuAction.report,
      ]);
      expect(UserMenuSheet.actionsFor(isSelf: true, isBlocked: false), [
        UserMenuAction.viewProfile,
      ]);
      expect(
        UserMenuSheet.actionsFor(
          isSelf: false,
          isBlocked: false,
          hasComment: true,
          canDeleteComment: true,
        ),
        [
          UserMenuAction.viewProfile,
          UserMenuAction.removeComment,
          UserMenuAction.reportComment,
          UserMenuAction.block,
          UserMenuAction.report,
        ],
      );
      // "Yorumu sil" yalnızca yorum bağlamında.
      expect(
        UserMenuSheet.actionsFor(
          isSelf: true,
          isBlocked: false,
          canDeleteComment: true,
        ),
        [UserMenuAction.viewProfile],
      );
    });

    test('satır adları — TR ve EN', () {
      for (final locale in [_tr, _en]) {
        final l10n = lookupAppLocalizations(locale);
        expect(
          [
            for (final action in UserMenuAction.values)
              UserMenuSheet.labelOf(l10n, action),
          ],
          [
            l10n.userprofileView,
            l10n.sht27DeleteComment,
            l10n.sht27ReportComment,
            l10n.sht27Block,
            l10n.userprofileUnblock,
            l10n.sht27ReportUser,
          ],
        );
      }
    });

    test('`/// Design: SHT-27` izi UserMenuSheet sınıfındadır', () {
      final source = readText(
        'lib/product/feedback/catalogs/sheets/user_menu_sheet.dart',
      );
      expect(
        source,
        contains(RegExp(r'/// Design: SHT-27\s*\nclass UserMenuSheet\b')),
      );
    });
  });

  group('SHT-27 · Kullanıcı · içerik', () {
    testWidgets('başka kullanıcı: başlık adı, menü + flush çerçeve, üç satır; '
        '"Engelle" yıkıcı — TR ve EN, açık + koyu', (tester) async {
      for (final theme in [ThemeMode.light, ThemeMode.dark]) {
        for (final locale in [_tr, _en]) {
          await _open(tester, _harness(), locale: locale, theme: theme);
          final l10n = tester.l10nFor(locale);
          final gu = tester.element(find.byType(GuSheetFrame)).gu;

          final frame = tester.widget<GuSheetFrame>(find.byType(GuSheetFrame));
          expect(frame.title, _userName);
          expect(frame.closeSemanticLabel, l10n.a11yClose);
          expect(frame.menu, isTrue);
          expect(frame.flush, isTrue);
          expect(frame.footer, isNull);

          final tiles = _tiles(tester);
          expect(tiles.map((tile) => tile.title), [
            l10n.userprofileView,
            l10n.sht27Block,
            l10n.sht27ReportUser,
          ]);
          expect(tiles.map((tile) => tile.danger), [false, true, false]);
          final icons = [for (final tile in tiles) tile.leading! as GuIcon];
          expect(icons.map((icon) => icon.icon), [
            GuIcons.user,
            GuIcons.ban,
            GuIcons.flag,
          ]);
          expect(icons.map((icon) => icon.size).toSet(), {GuSizes.icon22});
          expect(icons.map((icon) => icon.color), [
            gu.colors.textHeading,
            gu.colors.stateDanger,
            gu.colors.textHeading,
          ]);
          expect(ActionInventory.found(tester), {
            'SHT-27.profile',
            'SHT-27.block',
            'SHT-27.report',
            'SHT-27.close',
            'SHT-27.scrim',
          });
        }
      }
    });

    testWidgets('engelli kullanıcı: "Engeli kaldır" olağan renkte; engel '
        'durumu oturumdan gelir, çağıran verirse o geçerlidir', (tester) async {
      final blockedSession = FakeSessionStates.active.copyWith(
        blockedUserIds: {_userId},
      );
      for (final (session, isBlocked, expectUnblock) in [
        (blockedSession, null, true),
        (FakeSessionStates.active, true, true),
        (blockedSession, false, false),
      ]) {
        await _open(tester, _harness(isBlocked: isBlocked), session: session);
        final l10n = tester.l10n;
        final gu = tester.element(find.byType(GuSheetFrame)).gu;

        final tile = tester.widget<GuTile>(find.byKey(_key('block')));
        expect(
          tile.title,
          expectUnblock ? l10n.userprofileUnblock : l10n.sht27Block,
        );
        expect(tile.danger, !expectUnblock);
        expect(
          (tile.leading! as GuIcon).color,
          expectUnblock ? gu.colors.textHeading : gu.colors.stateDanger,
        );
      }
    });

    testWidgets('kendi menüsü: yalnızca "Profili gör"; ad verilmezse genel '
        'başlık', (tester) async {
      await _open(
        tester,
        _harness(userId: FakeSessionStates.uid, userName: null),
      );

      expect(_tiles(tester).map((tile) => tile.key), [_key('profile')]);
      expect(
        tester.widget<GuSheetFrame>(find.byType(GuSheetFrame)).title,
        tester.l10n.sht27Title,
      );
    });

    testWidgets('yorum bağlamı: "Yorumu sil" (yıkıcı, yalnızca yetkiliyse) ve '
        '"Yorumu şikayet et" satırları', (tester) async {
      await _open(tester, _harness(commentId: 'cm01', canDeleteComment: true));
      final l10n = tester.l10n;

      final tiles = _tiles(tester);
      expect(tiles.map((tile) => tile.key), [
        _key('profile'),
        _key('deleteComment'),
        _key('reportComment'),
        _key('block'),
        _key('report'),
      ]);
      expect(tiles[1].title, l10n.sht27DeleteComment);
      expect(tiles[1].danger, isTrue);
      expect(tiles[2].title, l10n.sht27ReportComment);

      await _open(tester, _harness(commentId: 'cm01'));
      expect(find.byKey(_key('deleteComment')), findsNothing);
      expect(find.byKey(_key('reportComment')), findsOneWidget);
    });

    testWidgets('320 dp + metin ölçeği 1.6, uzun ad — TR + EN: taşma yok '
        '(taşma testi düşürür)', (tester) async {
      for (final locale in [_tr, _en]) {
        final harness = _harness(
          userName: 'Abdurrahman Gazi Karahisarlıoğulları Yıldırımtürk',
          commentId: 'cm01',
          canDeleteComment: true,
        );
        addTearDown(harness.controller.dispose);
        await _pump(
          tester,
          harness,
          locale: locale,
          size: const Size(320, 568),
          textScale: 1.6,
        );
        await harness.open(tester);
        expect(find.byType(GuTile), findsNWidgets(5));
        await harness.back(tester);
      }
    });
  });

  group('SHT-27 · Kullanıcı · sonuç', () {
    testWidgets('her satır sayfayı kendi öğesiyle kapatır', (tester) async {
      final harness = await _open(
        tester,
        _harness(commentId: 'cm01', canDeleteComment: true),
      );
      for (final action in [
        UserMenuAction.viewProfile,
        UserMenuAction.removeComment,
        UserMenuAction.reportComment,
        UserMenuAction.block,
        UserMenuAction.report,
      ]) {
        if (harness.isClosed) await harness.open(tester);
        await tester.tap(find.byKey(UserMenuSheet.keyOf(action)));
        await tester.pumpAndSettle();

        expect(find.byType(GuSheetFrame), findsNothing, reason: action.name);
        expect(harness.result, action, reason: action.name);
      }
    });

    testWidgets('engelliyken `block` satırı `unblock` döndürür; kapat, scrim '
        've geri `null`', (tester) async {
      final harness = await _open(tester, _harness(isBlocked: true));
      await tester.tap(find.byKey(_key('block')));
      await tester.pumpAndSettle();
      expect(harness.result, UserMenuAction.unblock);

      for (final action in ['close', 'scrim']) {
        await harness.open(tester);
        if (action == 'scrim') {
          await tester.tapAt(const Offset(8, 8));
        } else {
          await tester.tap(find.byKey(_key(action)));
        }
        await tester.pumpAndSettle();
        expect(harness.result, isNull, reason: action);
      }

      await harness.open(tester);
      await harness.back(tester);
      expect(harness.result, isNull);
    });
  });

  group('SHT-27 · Kullanıcı · golden', () {
    testWidgets('golden: açık sayfa (scrim dahil) — açık + koyu (TR)', (
      tester,
    ) async {
      for (final theme in kGoldenThemes) {
        await _open(tester, _harness(), theme: theme);
        await expectLater(
          find.byKey(kPumpAppBoundaryKey),
          matchesGoldenFile(goldenUri(goldenPath('SHT-27', theme, _tr))),
        );
      }
    });
  });
}
