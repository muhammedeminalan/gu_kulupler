// SHT-18 · Yönetilen kulüp seç (`ManagedClubPickerSheet`): satırlar (amblem,
// ad, rol rozeti, danışmanda "Salt okunur", ok), rol süzme (`managedOf`:
// yalnızca aktif yönetim kurulu / başkan / danışman), seçili satır, durumlar
// (iskelet, hata + "Yeniden dene", boş), anahtarlar (`SHT-18.select.<clubId>`,
// `.close`, `.scrim`, `.retry`), seçim sonucu (`pop(clubId)` + `onSelect`),
// kapanma yolları, dar ekran + büyük metin + uzun ad, açık + koyu golden.
// Referans: design/reference-shots/sheets/SHT-18__light.webp, __dark.webp;
// prototip sheets.js:87–88, actions.js:32.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/managed_club_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../fakes/fake_club_repository.dart';
import '../../fakes/fake_session_states.dart';
import '../../fixtures/club_model_fixtures.dart';
import '../../fixtures/membership_model_fixtures.dart';
import '../../helpers/action_inventory.dart';
import '../../helpers/design_files.dart';
import '../../helpers/golden_helper.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/test_l10n.dart';
import 'sheet_test_support.dart';

const Locale _tr = Locale('tr');
const Locale _en = Locale('en');

const String _uid = FakeSessionStates.uid;

/// Referans görüntüdeki kulüp ("Doğa Sporları ve Dağcılık Kulübü", başkan).
const String _referenceClubId = 'c03';

Key _key(String action) => GuKey.action('SHT-18.$action');

FakeClubRepository _clubs() => GetIt.I<ClubRepository>() as FakeClubRepository;

MembershipModel _membership(
  String clubId, {
  ClubRole role = ClubRole.member,
  MembershipStatus status = MembershipStatus.active,
}) => MembershipModelFixtures.c01Mehmet.copyWith(
  id: FirestoreIds.membership(clubId, _uid),
  clubId: clubId,
  userId: _uid,
  status: status,
  role: role,
);

/// Aktif oturum + verilen üyelikler (sırayla).
SessionState _session(List<MembershipModel> memberships) => SessionState(
  status: AuthStatus.active,
  uid: _uid,
  onboardingSeen: true,
  memberships: {
    for (final membership in memberships) membership.clubId: membership,
  },
);

/// Referans: tek kulüp, başkan.
final SessionState _president = _session([
  _membership(_referenceClubId, role: ClubRole.president),
]);

/// Üç yönetilen kulüp (başkan · yönetim kurulu · danışman) + yönetilmeyenler
/// (üye, bekleyen başvuru, ayrılmış yönetici).
final SessionState _mixed = _session([
  _membership('c02'),
  _membership('c03', role: ClubRole.president),
  _membership('c04', role: ClubRole.board, status: MembershipStatus.pending),
  _membership('c01', role: ClubRole.board),
  _membership('c06', role: ClubRole.president, status: MembershipStatus.left),
  _membership('c05', role: ClubRole.advisor),
]);

const List<String> _mixedManaged = ['c03', 'c01', 'c05'];

SheetHarness<String> _harness({
  String? selectedClubId,
  ManagedClubSelect? onSelect,
}) => SheetHarness<String>(
  SheetId.sht18,
  (_) => ManagedClubPickerSheet(
    selectedClubId: selectedClubId,
    onSelect: onSelect,
  ),
);

/// Sayfanın arkasındaki gezgini [session] oturumuyla çizer ve demo kulüpleri
/// depoya yazar ([seed] ek değişiklik içindir).
Future<void> _pump(
  WidgetTester tester,
  SheetHarness<String> harness, {
  required SessionState session,
  void Function(FakeClubRepository clubs)? seed,
  Locale locale = _tr,
  ThemeMode theme = ThemeMode.light,
  Size size = const Size(390, 844),
  double textScale = 1.0,
}) async {
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
    theme: theme,
    size: size,
    textScale: textScale,
    overrides: [sessionViewModelProvider.overrideWithBuild((_, _) => session)],
  );
  final clubs = _clubs();
  for (final id in ['c01', 'c02', 'c03', 'c04', 'c05', 'c06']) {
    clubs.clubs[id] = ClubModelFixtures.byId(id);
  }
  seed?.call(clubs);
}

/// [harness] sayfasını [session] oturumuyla açar (kulüpler okunmuş).
Future<SheetHarness<String>> _open(
  WidgetTester tester,
  SheetHarness<String> harness, {
  required SessionState session,
  void Function(FakeClubRepository clubs)? seed,
  Locale locale = _tr,
  ThemeMode theme = ThemeMode.light,
}) async {
  addTearDown(harness.controller.dispose);
  await _pump(
    tester,
    harness,
    session: session,
    seed: seed,
    locale: locale,
    theme: theme,
  );
  await harness.open(tester);
  return harness;
}

List<GuTile> _tiles(WidgetTester tester) =>
    tester.widgetList<GuTile>(find.byType(GuTile)).toList();

/// [clubId] satırındaki rozetlerin metinleri, sırayla.
List<String> _badges(WidgetTester tester, String clubId) => [
  for (final badge in tester.widgetList<GuBadge>(
    find.descendant(
      of: find.byKey(ManagedClubPickerSheet.keyOf(clubId)),
      matching: find.byType(GuBadge),
    ),
  ))
    badge.label,
];

void main() {
  group('SHT-18 · Yönetilen kulüp seç · sözleşme', () {
    test('`managedOf`: yalnızca aktif yönetim kurulu / başkan / danışman, '
        'oturum sırasıyla', () {
      expect(
        ManagedClubPickerSheet.managedOf(
          _mixed,
        ).map((membership) => membership.clubId),
        _mixedManaged,
      );
      // Üyeliği olmayan kullanıcı.
      expect(
        ManagedClubPickerSheet.managedOf(FakeSessionStates.active),
        isEmpty,
      );
      expect(
        ManagedClubPickerSheet.managedOf(FakeSessionStates.activeMember('c01')),
        isEmpty,
      );
      // Süper admin üyeliksiz kulüp yönetmez (liste üyeliklerden kurulur).
      expect(
        ManagedClubPickerSheet.managedOf(FakeSessionStates.activeSuper),
        isEmpty,
      );
    });

    test('satır anahtarı `SHT-18.select.<clubId>`', () {
      expect(ManagedClubPickerSheet.keyOf('c03'), _key('select.c03'));
    });

    test('`/// Design: SHT-18` izi ManagedClubPickerSheet sınıfındadır', () {
      final source = readText(
        'lib/product/feedback/catalogs/sheets/managed_club_picker_sheet.dart',
      );
      expect(
        source,
        contains(
          RegExp(r'/// Design: SHT-18\s*\nclass ManagedClubPickerSheet\b'),
        ),
      );
    });
  });

  group('SHT-18 · Yönetilen kulüp seç · içerik', () {
    testWidgets('tek kulüp (referans): menü + flush çerçeve; amblem 44 / ikon '
        '20, ad, "Başkan" rozeti, ok — TR ve EN, açık + koyu', (tester) async {
      for (final theme in [ThemeMode.light, ThemeMode.dark]) {
        for (final locale in [_tr, _en]) {
          await _open(
            tester,
            _harness(),
            session: _president,
            locale: locale,
            theme: theme,
          );
          final l10n = tester.l10nFor(locale);

          final frame = tester.widget<GuSheetFrame>(find.byType(GuSheetFrame));
          expect(frame.title, l10n.sht18Title);
          expect(frame.closeSemanticLabel, l10n.a11yClose);
          expect(frame.menu, isTrue);
          expect(frame.flush, isTrue);
          expect(frame.footer, isNull);

          final tile = _tiles(tester).single;
          final club = ClubModelFixtures.byId(_referenceClubId);
          expect(tile.key, _key('select.$_referenceClubId'));
          expect(tile.title, club.name);
          expect(tile.chevron, isTrue);
          expect(tile.trailing, isNull);
          final emblem = tile.leading! as GuEmblem;
          expect(emblem.icon, GuIcons.mountain);
          expect(emblem.size, GuEmblemSize.sm);
          expect(GuEmblemSize.sm.dimension, GuSizes.emblemSm);
          expect(emblem.iconSize ?? emblem.size.iconSize, GuSizes.icon20);
          expect(_badges(tester, _referenceClubId), [l10n.rolePresident]);
          expect(
            tester
                .widget<GuRoleBadge>(
                  find.descendant(
                    of: find.byKey(_key('select.$_referenceClubId')),
                    matching: find.byType(GuRoleBadge),
                  ),
                )
                .kind,
            GuRoleBadgeKind.president,
          );

          expect(ActionInventory.found(tester), {
            'SHT-18.select.$_referenceClubId',
            'SHT-18.close',
            'SHT-18.scrim',
          });
        }
      }
    });

    testWidgets('rol süzme: yalnızca yönetilen kulüpler, oturum sırasıyla; '
        'rozetler başkan / yönetim kurulu / danışman + "Salt okunur"', (
      tester,
    ) async {
      await _open(tester, _harness(), session: _mixed);
      final l10n = tester.l10n;

      expect(_tiles(tester).map((tile) => tile.key), [
        for (final id in _mixedManaged) _key('select.$id'),
      ]);
      expect(_tiles(tester).map((tile) => tile.title), [
        for (final id in _mixedManaged) ClubModelFixtures.byId(id).name,
      ]);
      expect(_badges(tester, 'c03'), [l10n.rolePresident]);
      expect(_badges(tester, 'c01'), [l10n.roleBoard]);
      expect(_badges(tester, 'c05'), [l10n.roleAdvisor, l10n.commonReadOnly]);
      final readOnly = tester
          .widgetList<GuBadge>(
            find.descendant(
              of: find.byKey(_key('select.c05')),
              matching: find.byType(GuBadge),
            ),
          )
          .last;
      expect(readOnly.kind, GuBadgeKind.neutral);
      expect(readOnly.icon, GuIcons.eye);
      expect(_clubs().callsTo('getClubs').single.args, [_mixedManaged]);
    });

    testWidgets('seçili kulüp: ok yerine `check` (marka rengi) + seçili '
        'semantiği; ötekiler oklu', (tester) async {
      await _open(tester, _harness(selectedClubId: 'c01'), session: _mixed);
      final gu = tester.element(find.byType(GuSheetFrame)).gu;

      final selected = tester.widget<GuTile>(find.byKey(_key('select.c01')));
      expect(selected.chevron, isFalse);
      final check = (selected.trailing! as Semantics).child! as GuIcon;
      expect(check.icon, GuIcons.check);
      expect(check.size, GuSizes.icon18);
      expect(check.color, gu.colors.brandPrimary);
      expect(
        tester.getSemantics(find.byKey(_key('select.c01'))),
        isSemantics(
          label: '${ClubModelFixtures.c01.name}\n${tester.l10n.roleBoard}',
          hasSelectedState: true,
          isSelected: true,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      for (final id in ['c03', 'c05']) {
        final tile = tester.widget<GuTile>(find.byKey(_key('select.$id')));
        expect(tile.chevron, isTrue, reason: id);
        expect(tile.trailing, isNull, reason: id);
      }
    });

    testWidgets('belgesi olmayan / silinmiş kulübün satırı çizilmez; kayıtta '
        'olmayan ikon adı yedek ikona düşer', (tester) async {
      await _open(
        tester,
        _harness(),
        session: _mixed,
        seed: (clubs) {
          clubs.clubs.remove('c01');
          clubs.clubs['c05'] = clubs.clubs['c05']!.copyWith(
            iconName: 'yeni-ikon',
          );
        },
      );
      expect(_tiles(tester).map((tile) => tile.key), [
        _key('select.c03'),
        _key('select.c05'),
      ]);
      final emblem =
          tester.widget<GuTile>(find.byKey(_key('select.c05'))).leading!
              as GuEmblem;
      expect(emblem.icon, GuIcons.users);
    });
  });

  group('SHT-18 · Yönetilen kulüp seç · durumlar', () {
    testWidgets('boş: yönetilen kulüp yokken "Yönettiğin kulüp yok." — okuma '
        'yapılmaz (TR + EN)', (tester) async {
      for (final locale in [_tr, _en]) {
        await _open(
          tester,
          _harness(),
          session: FakeSessionStates.activeMember('c01'),
          locale: locale,
        );
        expect(find.byType(GuTile), findsNothing);
        expect(find.text(tester.l10nFor(locale).sht18Empty), findsOneWidget);
        expect(_clubs().callsTo('getClubs'), isEmpty);
      }
    });

    testWidgets('boş: yönetilen kulüplerin hiçbiri okunamıyorsa (silinmiş) '
        'aynı metin', (tester) async {
      await _open(
        tester,
        _harness(),
        session: _president,
        seed: (clubs) => clubs.clubs.clear(),
      );
      expect(find.byType(GuTile), findsNothing);
      expect(find.text(tester.l10n.sht18Empty), findsOneWidget);
    });

    testWidgets('yükleniyor: yönetilen kulüp sayısı kadar satır iskeleti', (
      tester,
    ) async {
      final harness = _harness();
      addTearDown(harness.controller.dispose);
      await _pump(tester, harness, session: _mixed);
      // Sayfa açılır; kulüp okuması henüz dönmemiştir (ilk kare).
      harness.service
          .showSheet<String>(
            SheetId.sht18,
            builder: harness.builder,
          )
          .ignore();
      await tester.pump();
      final skeleton = tester.widget<GuSkeletonList>(
        find.byType(GuSkeletonList),
      );
      expect(skeleton.count, _mixedManaged.length);
      expect(skeleton.semanticLabel, tester.l10n.commonLoading);
      expect(find.byType(GuTile), findsNothing);

      await tester.pumpAndSettle();
      expect(find.byType(GuSkeletonList), findsNothing);
      expect(find.byType(GuTile), findsNWidgets(_mixedManaged.length));
    });

    testWidgets('hata: "Yeniden dene" (`SHT-18.retry`) kulüpleri yeniden '
        'okur', (tester) async {
      await _open(
        tester,
        _harness(),
        session: _mixed,
        seed: (clubs) => clubs.failNext(FirestoreError.unavailable),
      );
      final l10n = tester.l10n;
      final error = tester.widget<GuErrorState>(find.byType(GuErrorState));
      expect(error.title, l10n.sysErrorTitle);
      expect(error.retryLabel, l10n.commonRetry);
      expect(error.inline, isTrue);
      expect(find.byType(GuTile), findsNothing);
      expect(ActionInventory.found(tester), {
        'SHT-18.retry',
        'SHT-18.close',
        'SHT-18.scrim',
      });

      await tester.tap(find.byKey(_key('retry')));
      await tester.pumpAndSettle();
      expect(find.byType(GuErrorState), findsNothing);
      expect(find.byType(GuTile), findsNWidgets(_mixedManaged.length));
      expect(_clubs().callsTo('getClubs'), hasLength(2));
    });

    testWidgets('320 dp + metin ölçeği 1.6, uzun ad, danışman rozetleri — '
        'TR + EN: taşma yok (taşma testi düşürür)', (tester) async {
      for (final locale in [_tr, _en]) {
        final harness = _harness(selectedClubId: 'c03');
        addTearDown(harness.controller.dispose);
        await _pump(
          tester,
          harness,
          session: _mixed,
          seed: (clubs) => clubs.clubs['c05'] = clubs.clubs['c05']!.copyWith(
            name:
                'Gümüşhane Üniversitesi Uluslararası Öğrenciler Kültür, '
                'Dayanışma ve Sürdürülebilir Kalkınma Araştırmaları Topluluğu',
          ),
          locale: locale,
          size: const Size(320, 568),
          textScale: 1.6,
        );
        await harness.open(tester);
        expect(find.byType(GuTile), findsNWidgets(_mixedManaged.length));
        await harness.back(tester);
      }
    });
  });

  group('SHT-18 · Yönetilen kulüp seç · sonuç', () {
    testWidgets('satır sayfayı kulübün kimliğiyle kapatır; `onSelect` '
        'verildiyse aynı kimlikle çağrılır', (tester) async {
      final selected = <String>[];
      final harness = await _open(
        tester,
        _harness(onSelect: selected.add),
        session: _mixed,
      );
      for (final id in _mixedManaged) {
        if (harness.isClosed) await harness.open(tester);
        await tester.tap(find.byKey(ManagedClubPickerSheet.keyOf(id)));
        await tester.pumpAndSettle();
        expect(find.byType(GuSheetFrame), findsNothing, reason: id);
        expect(harness.result, id, reason: id);
      }
      expect(selected, _mixedManaged);
    });

    testWidgets('`onSelect` verilmezse sayfa yalnızca kimliği döner (MGT-01 '
        'yönlendirmesi T-31 — W-26); kapat, scrim ve geri `null`', (
      tester,
    ) async {
      final harness = await _open(tester, _harness(), session: _president);
      await tester.tap(find.byKey(_key('select.$_referenceClubId')));
      await tester.pumpAndSettle();
      expect(harness.result, _referenceClubId);

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

  group('SHT-18 · Yönetilen kulüp seç · golden', () {
    testWidgets('golden: açık sayfa (scrim dahil), referans içerik — açık + '
        'koyu (TR)', (tester) async {
      for (final theme in kGoldenThemes) {
        await _open(tester, _harness(), session: _president, theme: theme);
        await expectLater(
          find.byKey(kPumpAppBoundaryKey),
          matchesGoldenFile(goldenUri(goldenPath('SHT-18', theme, _tr))),
        );
      }
    });
  });
}
