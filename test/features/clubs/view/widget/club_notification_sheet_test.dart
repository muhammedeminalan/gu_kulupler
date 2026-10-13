// SHT-07 · Kulüp bildirimleri (`ClubNotificationSheet` +
// `ClubNotificationPrefsViewModel`): içerik, anahtarlar
// (`SHT-07.toggle.announcements`, `.events`, `.posts`, `.muted`, `.close`,
// `.scrim`), dokunuş → iyimser yazım (TST-38), "Tümünü sessize al" kilidi
// (TST-X16), çevrimdışı / hata (TST-24, geri alma), yükleniyor ve hata
// durumları, cihaz matrisi, açık + koyu golden. Referans:
// design/reference-shots/sheets/SHT-07__light.webp, __dark.webp.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/clubs/provider/club_notification_prefs_state.dart';
import 'package:gu_kulupler/features/clubs/provider/club_notification_prefs_view_model.dart';
import 'package:gu_kulupler/features/clubs/view/widget/club_notification_sheet.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
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
const String _uid = FakeSessionStates.uid;
final String _clubName = ClubModelFixtures.c01.name;

const ClubNotificationPrefsModel _muted = ClubNotificationPrefsModel(
  announcements: false,
  events: false,
  posts: false,
  muted: true,
);

const List<ClubPrefKey> _kinds = [
  ClubPrefKey.announcements,
  ClubPrefKey.events,
  ClubPrefKey.posts,
];

Key _toggleKey(ClubPrefKey key) => GuKey.action('SHT-07.toggle.${key.name}');
Key _key(String action) => GuKey.action('SHT-07.$action');

ClubSheetHarness<void> _harness({bool withName = true}) =>
    ClubSheetHarness<void>(
      SheetId.sht07,
      (_) => ClubNotificationSheet(
        clubId: _clubId,
        clubName: withName ? _clubName : null,
      ),
      session: FakeSessionStates.activeMember(_clubId),
    );

/// Sayfayı [prefs] kaydıyla açar (`null` → kulüp kaydı yok).
Future<ClubSheetHarness<void>> _open(
  WidgetTester tester, {
  ClubNotificationPrefsModel? prefs,
  Locale locale = _tr,
  ThemeMode theme = ThemeMode.light,
  bool withName = true,
}) async {
  final h = _harness(withName: withName);
  await h.pump(tester, locale: locale, theme: theme);
  if (prefs != null) {
    h.settings.settings[_uid] = const UserSettingsModel.defaults(
      _uid,
    ).copyWith(clubs: {_clubId: prefs});
  }
  await h.open(tester);
  return h;
}

GuSwitch _switch(WidgetTester tester, ClubPrefKey key) =>
    tester.widget<GuSwitch>(find.byKey(_toggleKey(key)));

Map<ClubPrefKey, bool> _values(WidgetTester tester) => {
  for (final key in ClubPrefKey.values) key: _switch(tester, key).value,
};

Future<void> _tap(WidgetTester tester, ClubPrefKey key) async {
  await tester.tap(find.byKey(_toggleKey(key)));
  await tester.pumpAndSettle();
}

const Map<ClubPrefKey, bool> _allOnValues = {
  ClubPrefKey.announcements: true,
  ClubPrefKey.events: true,
  ClubPrefKey.posts: true,
  ClubPrefKey.muted: false,
};
const Map<ClubPrefKey, bool> _mutedValues = {
  ClubPrefKey.announcements: false,
  ClubPrefKey.events: false,
  ClubPrefKey.posts: false,
  ClubPrefKey.muted: true,
};

void main() {
  group('SHT-07 · Kulüp bildirimleri · sözleşme', () {
    test('satır adları ve ikonları — TR ve EN', () {
      for (final locale in [_tr, _en]) {
        final l10n = lookupAppLocalizations(locale);
        expect(
          [
            for (final key in ClubPrefKey.values)
              ClubNotificationSheet.labelOf(l10n, key),
          ],
          [
            l10n.sht07Announcements,
            l10n.sht07Events,
            l10n.sht07Posts,
            l10n.sht07MuteAll,
          ],
        );
      }
      expect(ClubPrefKey.values.map(ClubNotificationSheet.iconOf), [
        GuIcons.megaphone,
        GuIcons.calendarPlus,
        GuIcons.fileText,
        GuIcons.bellOff,
      ]);
    });

    test('`/// Design: SHT-07` izi ClubNotificationSheet sınıfındadır', () {
      final source = readText(
        'lib/features/clubs/view/widget/club_notification_sheet.dart',
      );
      expect(
        RegExp(r'///\s*Design:\s*SHT-07').allMatches(source),
        hasLength(1),
      );
      expect(
        source,
        contains(
          RegExp(r'/// Design: SHT-07\s*\nclass ClubNotificationSheet\b'),
        ),
      );
    });
  });

  group('SHT-07 · Kulüp bildirimleri · içerik', () {
    testWidgets('çerçeve, kulüp adı, üç tür + ayraç + "Tümünü sessize al"; '
        'kayıt yokken üçü açık — TR ve EN, açık + koyu', (tester) async {
      for (final theme in [ThemeMode.light, ThemeMode.dark]) {
        for (final locale in [_tr, _en]) {
          await _open(tester, locale: locale, theme: theme);
          final l10n = tester.l10nFor(locale);
          final gu = tester.element(find.byType(GuSheetFrame)).gu;

          final frame = tester.widget<GuSheetFrame>(find.byType(GuSheetFrame));
          expect(frame.title, l10n.sht07Title);
          expect(frame.closeSemanticLabel, l10n.a11yClose);
          expect(frame.menu, isFalse);
          expect(frame.footer, isNull);

          final caption = tester.widget<Text>(find.text(_clubName));
          expect(caption.style!.fontSize, gu.text.caption.fontSize);
          expect(caption.style!.color, gu.text.caption.color);

          final tiles = tester.widgetList<GuTile>(find.byType(GuTile)).toList();
          expect(tiles.map((tile) => tile.title), [
            l10n.sht07Announcements,
            l10n.sht07Events,
            l10n.sht07Posts,
            l10n.sht07MuteAll,
          ]);
          expect(tiles.map((tile) => tile.onTap).toSet(), {null});
          final icons = [for (final tile in tiles) tile.leading! as GuIcon];
          expect(icons.map((icon) => icon.icon), [
            GuIcons.megaphone,
            GuIcons.calendarPlus,
            GuIcons.fileText,
            GuIcons.bellOff,
          ]);
          expect(icons.map((icon) => icon.size).toSet(), {GuSizes.icon20});
          expect(icons.map((icon) => icon.color), [
            gu.colors.textMuted,
            gu.colors.textMuted,
            gu.colors.textMuted,
            gu.colors.stateDanger,
          ]);

          expect(_values(tester), _allOnValues);
          for (final key in ClubPrefKey.values) {
            final toggle = _switch(tester, key);
            expect(toggle.disabled, isFalse, reason: key.name);
            expect(
              toggle.semanticLabel,
              ClubNotificationSheet.labelOf(l10n, key),
            );
          }
          expect(find.byType(GuDivider), findsOneWidget);
          expect(find.byType(GuButton), findsNothing);
          expect(find.text(l10n.sysErrorTitle), findsNothing);
        }
      }
    });

    testWidgets('aksiyon anahtarları: dört anahtar + kapat + scrim', (
      tester,
    ) async {
      await _open(tester);
      expect(ActionInventory.found(tester), {
        'SHT-07.toggle.announcements',
        'SHT-07.toggle.events',
        'SHT-07.toggle.posts',
        'SHT-07.toggle.muted',
        'SHT-07.close',
        'SHT-07.scrim',
      });
    });

    testWidgets('ölçüler: ad ve satır içeriği 16 dp içeride, satırlar 56 dp, '
        'anahtar sağda, ayraç 16 dp içeride, alt dolgu 16', (tester) async {
      await _open(tester);
      final l10n = tester.l10nFor(_tr);
      const right = 390 - GuSizes.sheetBodyPaddingX;

      final frame = tester.getRect(find.byType(GuSheetFrame));
      expect(frame.bottom, 844);
      expect(frame.width, 390);

      final caption = tester.getRect(find.text(_clubName));
      expect(caption.left, GuSizes.sheetBodyPaddingX);

      final rows = tester.widgetList<GuTile>(find.byType(GuTile)).length;
      expect(rows, 4);
      final tiles = [
        for (var i = 0; i < rows; i++)
          tester.getRect(find.byType(GuTile).at(i)),
      ];
      expect(tiles.first.top - caption.bottom, GuSpacing.s16);
      for (final (index, rect) in tiles.indexed) {
        expect(rect.height, GuSizes.tileMinHeight);
        expect(
          tester.getRect(find.byType(GuIcon).at(index + 1)).left,
          GuSizes.sheetBodyPaddingX,
        );
      }
      for (final key in ClubPrefKey.values) {
        final toggle = tester.getRect(
          find.descendant(
            of: find.byKey(_toggleKey(key)),
            matching: find.byType(AnimatedContainer),
          ),
        );
        expect(toggle.right, right);
        expect(
          toggle.size,
          const Size(GuSizes.switchWidth, GuSizes.switchHeight),
        );
      }
      expect(
        tester.getRect(find.text(l10n.sht07Announcements)).left,
        GuSizes.sheetBodyPaddingX + GuSizes.icon20 + GuSizes.tileGap,
      );

      final divider = tester.getRect(find.byType(GuDivider));
      expect(divider.top, tiles[2].bottom);
      expect(tiles[3].top, divider.bottom);
      final line = tester.getRect(
        find.descendant(
          of: find.byType(GuDivider),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(line.left, GuSizes.sheetBodyPaddingX);
      expect(line.right, right);

      expect(frame.bottom - tiles.last.bottom, GuSizes.sheetBodyPaddingBottom);
    });

    testWidgets('kulüp adı verilmezse ad satırı çizilmez', (tester) async {
      await _open(tester, withName: false);
      expect(find.text(_clubName), findsNothing);
      expect(find.byType(GuTile), findsNWidgets(4));
    });

    testWidgets('kayıtlı tercihler gösterilir; sessizdeki kulüpte üç tür '
        'kapalı ve devre dışı', (tester) async {
      await _open(
        tester,
        prefs: const ClubNotificationPrefsModel(events: false),
      );
      expect(_values(tester), {..._allOnValues, ClubPrefKey.events: false});

      await _open(tester, prefs: _muted);
      expect(_values(tester), _mutedValues);
      for (final key in _kinds) {
        expect(_switch(tester, key).disabled, isTrue, reason: key.name);
      }
      expect(_switch(tester, ClubPrefKey.muted).disabled, isFalse);
    });
  });

  group('SHT-07 · Kulüp bildirimleri · dokunuş', () {
    testWidgets('TST-38: tür anahtarı kapanır / açılır, her dokunuş yazılır', (
      tester,
    ) async {
      final h = await _open(tester);

      await _tap(tester, ClubPrefKey.events);
      expect(_values(tester), {..._allOnValues, ClubPrefKey.events: false});
      expect(h.settings.clubSettingsWrites.single, (
        uid: _uid,
        clubId: _clubId,
        prefs: const ClubNotificationPrefsModel(events: false),
      ));
      expect(h.feedback.toasts, [ToastId.tst38]);

      await _tap(tester, ClubPrefKey.events);
      expect(_values(tester), _allOnValues);
      expect(
        h.settings.settings[_uid]!.clubs[_clubId],
        const ClubNotificationPrefsModel(),
      );
      expect(h.feedback.toasts, [ToastId.tst38, ToastId.tst38]);
      // Sayfa açık kalır (kaydet düğmesi yok).
      expect(find.byType(GuSheetFrame), findsOneWidget);
    });

    testWidgets('"Tümünü sessize al": üç tür kapanır ve kilitlenir (TST-38); '
        'kilitli anahtara dokunuş TST-X16; kapatınca üçü de açılır', (
      tester,
    ) async {
      final h = await _open(
        tester,
        prefs: const ClubNotificationPrefsModel(posts: false),
      );

      await _tap(tester, ClubPrefKey.muted);
      expect(_values(tester), _mutedValues);
      expect(h.settings.clubSettingsWrites.single.prefs, _muted);
      expect(h.feedback.toasts, [ToastId.tst38]);

      for (final key in _kinds) {
        expect(_switch(tester, key).disabled, isTrue, reason: key.name);
        await _tap(tester, key);
      }
      expect(h.feedback.toasts, [
        ToastId.tst38,
        ToastId.tstX16,
        ToastId.tstX16,
        ToastId.tstX16,
      ]);
      expect(_values(tester), _mutedValues);
      expect(h.settings.clubSettingsWrites, hasLength(1));

      await _tap(tester, ClubPrefKey.muted);
      expect(_values(tester), _allOnValues);
      for (final key in _kinds) {
        expect(_switch(tester, key).disabled, isFalse, reason: key.name);
      }
      expect(h.feedback.toasts.last, ToastId.tst38);
    });

    testWidgets('TST-24: çevrimdışıyken anahtar değişmez, yazılmaz', (
      tester,
    ) async {
      final h = await _open(tester);
      h.connectivity.isOffline = true;

      await _tap(tester, ClubPrefKey.announcements);
      expect(_values(tester), _allOnValues);
      expect(h.feedback.toasts, [ToastId.tst24]);
      expect(h.settings.clubSettingsWrites, isEmpty);
    });

    testWidgets('TST-24: ağ hatasında anahtar eski değerine döner', (
      tester,
    ) async {
      final h = await _open(tester);
      h.settings.failNext(FirestoreError.unavailable);

      await _tap(tester, ClubPrefKey.posts);
      expect(_values(tester), _allOnValues);
      expect(h.feedback.toasts, [ToastId.tst24]);
      expect(find.text(tester.l10nFor(_tr).sysErrorTitle), findsNothing);
    });

    testWidgets('sunucu reddi: anahtar geri döner, altta hata satırı; '
        'sonraki başarılı dokunuş satırı kaldırır — TR ve EN', (tester) async {
      for (final locale in [_tr, _en]) {
        final h = await _open(tester, locale: locale);
        final l10n = tester.l10nFor(locale);
        h.settings.failNext(FirestoreError.permissionDenied);

        await _tap(tester, ClubPrefKey.muted);
        expect(_values(tester), _allOnValues);
        expect(h.feedback.toasts, isEmpty);
        final error = find.text(l10n.sysErrorTitle);
        expect(error, findsOneWidget);
        expect(
          tester.widget<Text>(error).style!.color,
          tester.element(error).gu.colors.stateDanger,
        );
        expect(
          tester.getRect(error).left,
          greaterThan(GuSizes.sheetBodyPaddingX),
        );

        await _tap(tester, ClubPrefKey.muted);
        expect(_values(tester), _mutedValues);
        expect(find.text(l10n.sysErrorTitle), findsNothing);
        expect(h.feedback.toasts, [ToastId.tst38]);
      }
    });
  });

  group('SHT-07 · Kulüp bildirimleri · durumlar', () {
    testWidgets('yükleniyor: iskelet, anahtar yok', (tester) async {
      final h = ClubSheetHarness<void>(
        SheetId.sht07,
        (_) => ClubNotificationSheet(clubId: _clubId, clubName: _clubName),
        session: FakeSessionStates.activeMember(_clubId),
        overrides: [
          clubNotificationPrefsViewModelProvider(
            _clubId,
          ).overrideWithBuild((_, _) => const ClubNotificationPrefsState()),
        ],
      );
      await h.pump(tester);
      await h.open(tester);

      final skeleton = tester.widget<GuSkeletonList>(
        find.byType(GuSkeletonList),
      );
      expect(skeleton.semanticLabel, tester.l10nFor(_tr).commonLoading);
      expect(find.byType(GuSwitch), findsNothing);
      expect(find.byType(GuErrorState), findsNothing);
      expect(find.text(_clubName), findsOneWidget);
      expect(ActionInventory.found(tester), {'SHT-07.close', 'SHT-07.scrim'});
    });

    testWidgets('hata: tercihler okunamadı → hata + "Yeniden dene"; yeniden '
        'deneme anahtarları getirir — TR ve EN', (tester) async {
      for (final locale in [_tr, _en]) {
        final h = _harness();
        await h.pump(tester, locale: locale);
        h.settings.failNext(FirestoreError.unavailable);
        await h.open(tester);
        final l10n = tester.l10nFor(locale);

        final error = tester.widget<GuErrorState>(find.byType(GuErrorState));
        expect(error.title, l10n.sysErrorTitle);
        expect(error.description, l10n.sysErrorDesc);
        expect(error.retryLabel, l10n.commonRetry);
        expect(error.inline, isTrue);
        expect(find.byType(GuSwitch), findsNothing);
        expect(find.byType(GuSkeletonList), findsNothing);
        expect(ActionInventory.found(tester), {
          'SHT-07.retry',
          'SHT-07.close',
          'SHT-07.scrim',
        });

        await tester.tap(find.byKey(_key('retry')));
        await tester.pumpAndSettle();
        expect(find.byType(GuErrorState), findsNothing);
        expect(_values(tester), _allOnValues);
      }
    });

    testWidgets('kapat düğmesi, scrim ve geri tuşu sayfayı kapatır', (
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
      }
      await h.open(tester);
      await h.back(tester);
      expect(find.byType(GuSheetFrame), findsNothing);
      expect(h.feedback.dialogs, isEmpty);
    });
  });

  group('SHT-07 · Kulüp bildirimleri · yerleşim', () {
    for (final (name, state) in [
      ('açık', const ClubNotificationPrefsState(isLoaded: true)),
      (
        'sessiz + hata satırı',
        const ClubNotificationPrefsState(
          prefs: _muted,
          isLoaded: true,
          isError: true,
        ),
      ),
      ('yükleniyor', const ClubNotificationPrefsState()),
      ('hata', const ClubNotificationPrefsState(isError: true)),
    ]) {
      testWidgets('cihaz matrisi: taşma yok ($name; güvenli alan '
          'varyantları)', (tester) async {
        await DeviceMatrix.run(
          tester,
          (context) => Align(
            alignment: Alignment.bottomCenter,
            child: ClubNotificationSheet(clubId: _clubId, clubName: _clubName),
          ),
          overrides: [
            sessionViewModelProvider.overrideWithBuild(
              (_, _) => FakeSessionStates.activeMember(_clubId),
            ),
            clubNotificationPrefsViewModelProvider(
              _clubId,
            ).overrideWithBuild((_, _) => state),
          ],
          safeAreas: true,
        );
      });
    }

    testWidgets('golden: açık sayfa (scrim dahil) — açık + koyu (TR)', (
      tester,
    ) async {
      for (final theme in kGoldenThemes) {
        final h = await _open(tester, theme: theme);
        await h.expectGolden(tester, 'SHT-07', theme);
      }
    });

    testWidgets('golden: sessize alınmış kulüp — açık + koyu (TR)', (
      tester,
    ) async {
      for (final theme in kGoldenThemes) {
        final h = await _open(tester, prefs: _muted, theme: theme);
        await h.expectGolden(tester, 'SHT-07__muted', theme);
      }
    });
  });
}
