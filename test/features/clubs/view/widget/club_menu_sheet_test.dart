// SHT-06 · Kulüp menüsü (`ClubMenuSheet`): erişim kipine göre satırlar
// (`sheets.js:35`), anahtarlar (`SHT-06.notifications`, `.share`, `.members`,
// `.report`, `.settings`, `.leave`, `.close`, `.scrim`), seçim sonucu
// (`pop(ClubMenuAction)`), kapanma yolları, cihaz matrisi, açık + koyu golden.
// Referans: design/reference-shots/sheets/SHT-06__light.webp, __dark.webp.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/clubs/view/widget/club_menu_sheet.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../../fakes/fake_session_states.dart';
import '../../../../fixtures/club_model_fixtures.dart';
import '../../../../helpers/action_inventory.dart';
import '../../../../helpers/design_files.dart';
import '../../../../helpers/device_matrix.dart';
import '../../../../helpers/golden_helper.dart';
import '../../../../helpers/test_l10n.dart';
import 'club_sheet_harness.dart';

const Locale _tr = Locale('tr');
const Locale _en = Locale('en');
const String _clubId = 'c01';
final String _clubName = ClubModelFixtures.c01.name;

Key _key(String action) => GuKey.action('SHT-06.$action');

/// Erişim kipi → oturum.
SessionState _sessionFor(ClubAccess access) => switch (access) {
  ClubAccess.visitor => FakeSessionStates.active,
  ClubAccess.pending => FakeSessionStates.activePending(_clubId),
  ClubAccess.rejected => FakeSessionStates.activeRejected(_clubId),
  ClubAccess.member => FakeSessionStates.activeMember(_clubId),
  ClubAccess.manager => FakeSessionStates.activeManager(_clubId),
  ClubAccess.advisor => FakeSessionStates.activeAdvisor(_clubId),
  ClubAccess.superAdmin => FakeSessionStates.activeSuper,
};

/// Tasarımdaki koşullar (`sheets.js:35`).
const Map<ClubAccess, List<ClubMenuAction>> _expected = {
  ClubAccess.visitor: [ClubMenuAction.share, ClubMenuAction.report],
  ClubAccess.pending: [ClubMenuAction.share, ClubMenuAction.report],
  ClubAccess.rejected: [ClubMenuAction.share, ClubMenuAction.report],
  ClubAccess.member: [
    ClubMenuAction.notifications,
    ClubMenuAction.share,
    ClubMenuAction.members,
    ClubMenuAction.report,
    ClubMenuAction.leave,
  ],
  ClubAccess.manager: [
    ClubMenuAction.notifications,
    ClubMenuAction.share,
    ClubMenuAction.members,
    ClubMenuAction.report,
    ClubMenuAction.settings,
    ClubMenuAction.leave,
  ],
  ClubAccess.advisor: [
    ClubMenuAction.notifications,
    ClubMenuAction.share,
    ClubMenuAction.members,
    ClubMenuAction.report,
  ],
  ClubAccess.superAdmin: [
    ClubMenuAction.share,
    ClubMenuAction.report,
    ClubMenuAction.settings,
  ],
};

ClubSheetHarness<ClubMenuAction> _harness({
  ClubAccess access = ClubAccess.member,
  SessionState? session,
  String? clubName,
  bool withName = true,
}) => ClubSheetHarness<ClubMenuAction>(
  SheetId.sht06,
  (_) => ClubMenuSheet(
    clubId: _clubId,
    clubName: withName ? clubName ?? _clubName : null,
  ),
  session: session ?? _sessionFor(access),
);

List<GuTile> _tiles(WidgetTester tester) =>
    tester.widgetList<GuTile>(find.byType(GuTile)).toList();

void main() {
  group('SHT-06 · Kulüp menüsü · sözleşme', () {
    test('öğeler tasarım sırasındadır; ad aksiyon anahtarının son parçası', () {
      expect(ClubMenuAction.values.map((action) => action.name), [
        'notifications',
        'share',
        'members',
        'report',
        'settings',
        'leave',
      ]);
      expect(ClubMenuAction.values.map((action) => action.icon), [
        GuIcons.bell,
        GuIcons.share2,
        GuIcons.users,
        GuIcons.flag,
        GuIcons.settings,
        GuIcons.logOut,
      ]);
    });

    test('`actionsFor`: yedi erişim kipinin satırları', () {
      expect(_expected.keys.toSet(), ClubAccess.values.toSet());
      for (final MapEntry(key: access, value: actions) in _expected.entries) {
        expect(ClubMenuSheet.actionsFor(access), actions, reason: access.name);
      }
    });

    test('satır adları — TR ve EN', () {
      for (final locale in [_tr, _en]) {
        final l10n = lookupAppLocalizations(locale);
        expect(
          [
            for (final action in ClubMenuAction.values)
              ClubMenuSheet.labelOf(l10n, action),
          ],
          [
            l10n.sht06Notifications,
            l10n.commonShare,
            l10n.membersTitle,
            l10n.sht06Report,
            l10n.clubSettingsTitle,
            l10n.clubLeave,
          ],
        );
      }
    });

    test('`/// Design: SHT-06` izi ClubMenuSheet sınıfındadır', () {
      final source = readText(
        'lib/features/clubs/view/widget/club_menu_sheet.dart',
      );
      expect(
        RegExp(r'///\s*Design:\s*SHT-06').allMatches(source),
        hasLength(1),
      );
      expect(
        source,
        contains(RegExp(r'/// Design: SHT-06\s*\nclass ClubMenuSheet\b')),
      );
    });
  });

  group('SHT-06 · Kulüp menüsü · içerik', () {
    testWidgets('üye: başlık kulüp adı, menü + flush çerçeve, beş satır; '
        '"Kulüpten ayrıl" yıkıcı — TR ve EN, açık + koyu', (tester) async {
      for (final theme in [ThemeMode.light, ThemeMode.dark]) {
        for (final locale in [_tr, _en]) {
          final h = _harness();
          await h.pump(tester, locale: locale, theme: theme);
          await h.open(tester);
          final l10n = tester.l10nFor(locale);
          final gu = tester.element(find.byType(GuSheetFrame)).gu;

          final frame = tester.widget<GuSheetFrame>(find.byType(GuSheetFrame));
          expect(frame.title, _clubName);
          expect(frame.closeSemanticLabel, l10n.a11yClose);
          expect(frame.menu, isTrue);
          expect(frame.flush, isTrue);
          expect(frame.footer, isNull);

          final tiles = _tiles(tester);
          expect(tiles.map((tile) => tile.title), [
            l10n.sht06Notifications,
            l10n.commonShare,
            l10n.membersTitle,
            l10n.sht06Report,
            l10n.clubLeave,
          ]);
          expect(tiles.map((tile) => tile.danger), [
            false,
            false,
            false,
            false,
            true,
          ]);
          final icons = [for (final tile in tiles) tile.leading! as GuIcon];
          expect(icons.map((icon) => icon.icon), [
            GuIcons.bell,
            GuIcons.share2,
            GuIcons.users,
            GuIcons.flag,
            GuIcons.logOut,
          ]);
          expect(icons.map((icon) => icon.size).toSet(), {GuSizes.icon22});
          expect(icons.map((icon) => icon.color), [
            gu.colors.textHeading,
            gu.colors.textHeading,
            gu.colors.textHeading,
            gu.colors.textHeading,
            gu.colors.stateDanger,
          ]);
          expect(tiles.map((tile) => tile.chevron).toSet(), {false});
        }
      }
    });

    testWidgets('satırlar erişim kipine göre süzülür; aksiyon anahtarları '
        'satırlar + kapat + scrim', (tester) async {
      for (final MapEntry(key: access, value: actions) in _expected.entries) {
        final h = _harness(access: access);
        await h.pump(tester);
        await h.open(tester);

        expect(
          ActionInventory.found(tester),
          {
            for (final action in actions) 'SHT-06.${action.name}',
            'SHT-06.close',
            'SHT-06.scrim',
          },
          reason: access.name,
        );
        expect(
          _tiles(tester).map((tile) => tile.key),
          [for (final action in actions) _key(action.name)],
          reason: access.name,
        );
      }
    });

    testWidgets('başkan da "Kulüpten ayrıl" satırını görür (DLG-09 kararı '
        'çağırandadır); süper admin üye olsa da yönetim satırlarını görür', (
      tester,
    ) async {
      final president = _harness(
        session: FakeSessionStates.activeManager(
          _clubId,
          role: ClubRole.president,
        ),
      );
      await president.pump(tester);
      await president.open(tester);
      expect(find.byKey(_key('leave')), findsOneWidget);
      expect(find.byKey(_key('settings')), findsOneWidget);

      final superMember = _harness(
        session: FakeSessionStates.withMembership(_clubId, isSuperAdmin: true),
      );
      await superMember.pump(tester);
      await superMember.open(tester);
      expect(
        _tiles(tester).map((tile) => tile.key),
        [_key('share'), _key('report'), _key('settings')],
      );
    });

    testWidgets('kulüp adı verilmezse genel başlık — TR ve EN', (tester) async {
      for (final locale in [_tr, _en]) {
        final h = _harness(withName: false);
        await h.pump(tester, locale: locale);
        await h.open(tester);
        expect(
          tester.widget<GuSheetFrame>(find.byType(GuSheetFrame)).title,
          tester.l10nFor(locale).sht06Title,
        );
      }
    });

    testWidgets('ölçüler: satırlar 56 dp, tam genişlik, ikon 16 dp içeride; '
        'sayfa alta yapışık', (tester) async {
      final h = _harness(access: ClubAccess.manager);
      await h.pump(tester);
      await h.open(tester);

      final frame = tester.getRect(find.byType(GuSheetFrame));
      expect(frame.bottom, 844);
      expect(frame.width, 390);

      final rects = [
        for (final action in ClubMenuAction.values)
          tester.getRect(find.byKey(_key(action.name))),
      ];
      for (final rect in rects) {
        expect(rect.height, GuSizes.tileMinHeight);
        expect(rect.left, 0);
        expect(rect.right, 390);
      }
      for (var i = 1; i < rects.length; i++) {
        expect(rects[i].top, rects[i - 1].bottom);
      }
      expect(
        tester.getRect(find.byType(GuIcon).at(1)).left,
        GuSizes.tilePaddingX,
      );
      // `.sheet-body.is-flush` alt dolgusu.
      expect(
        frame.bottom - rects.last.bottom,
        GuSizes.sheetBodyFlushPaddingBottom,
      );
    });
  });

  group('SHT-06 · Kulüp menüsü · sonuç', () {
    testWidgets('her satır sayfayı kendi öğesiyle kapatır; sayfa hiçbir şey '
        'yürütmez', (tester) async {
      final h = _harness(access: ClubAccess.manager);
      await h.pump(tester);
      for (final action in ClubMenuAction.values) {
        await h.open(tester);
        await tester.tap(find.byKey(_key(action.name)));
        await tester.pumpAndSettle();

        expect(find.byType(GuSheetFrame), findsNothing, reason: action.name);
        expect(h.result, action, reason: action.name);
      }
      expect(h.feedback.toasts, isEmpty);
      expect(h.feedback.dialogs, isEmpty);
      expect(h.feedback.sheets, isEmpty);
      expect(h.memberships.calls, isEmpty);
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
      expect(h.result, isNull);
    });
  });

  group('SHT-06 · Kulüp menüsü · yerleşim', () {
    testWidgets('cihaz matrisi: taşma yok (yönetici: altı satır; uzun kulüp '
        'adı; güvenli alan varyantları)', (tester) async {
      await DeviceMatrix.run(
        tester,
        (context) => Align(
          alignment: Alignment.bottomCenter,
          child: ClubMenuSheet(clubId: _clubId, clubName: _clubName),
        ),
        overrides: [
          sessionViewModelProvider.overrideWithBuild(
            (_, _) => FakeSessionStates.activeManager(_clubId),
          ),
        ],
        safeAreas: true,
      );
    });

    testWidgets('golden: üye menüsü (scrim dahil) — açık + koyu (TR)', (
      tester,
    ) async {
      for (final theme in kGoldenThemes) {
        final h = _harness();
        await h.pump(tester, theme: theme);
        await h.open(tester);
        await h.expectGolden(tester, 'SHT-06', theme);
      }
    });
  });
}
