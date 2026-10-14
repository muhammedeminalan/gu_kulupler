// T-27 · MyClubRow (widget-catalog P8) — kulüp satırı: amblem, ad, aktifte
// rol rozeti / diğerlerinde durum rozeti + tarih, PRF-01 kart içi chevron,
// PRF-03 "Diğer" düğmesi, anahtarlar, dokunma ayrımı, dar ekran × büyük
// metin (rozet + tarih alt satıra iner), açık + koyu galeri golden'ı.
// Kaynak: prototip `screens-profile.js:14, 45`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/widget/club/my_club_row.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fixtures/club_model_fixtures.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/overflow_detector.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';

final ClubModel _club = ClubModelFixtures.c01;
final ClubModel _longName = _club.copyWith(
  name:
      'Uluslararası Öğrenci Değişim Programları ve Kültürlerarası '
      'İletişim Araştırmaları Topluluğu',
);

final Key _row = GuKey.action('PRF-03.row.${_club.id}');
final Key _menu = GuKey.action('PRF-03.menu.${_club.id}');

Future<void> _pump(
  WidgetTester tester,
  List<Widget> rows, {
  Locale locale = const Locale('tr'),
  Size size = const Size(390, 844),
  double textScale = 1,
}) => tester.pumpApp(
  Scaffold(
    body: SingleChildScrollView(child: Column(children: rows)),
  ),
  locale: locale,
  size: size,
  textScale: textScale,
);

List<Widget> _gallery() => [
  GuCard(
    child: Column(
      children: [
        MyClubRow(
          club: _club,
          inCard: true,
          actionKey: GuKey.action('PRF-01.club.c01'),
          onTap: () {},
        ),
        MyClubRow(
          club: ClubModelFixtures.byId('c07'),
          role: ClubRole.president,
          inCard: true,
          actionKey: GuKey.action('PRF-01.club.c07'),
          onTap: () {},
        ),
      ],
    ),
  ),
  for (final (i, status) in MembershipStatus.values.indexed)
    MyClubRow(
      club: _club,
      status: status,
      role: ClubRole.board,
      caption: '9 Ağustos 2026',
      actionKey: GuKey.action('PRF-03.row.g$i'),
      onTap: () {},
      menuKey: GuKey.action('PRF-03.menu.g$i'),
      onMenu: () {},
    ),
];

void main() {
  group('MyClubRow', () {
    testWidgets('PRF-03: rol rozeti + tarih + ⋮; satır ve menü ayrı dokunur', (
      tester,
    ) async {
      var rowTaps = 0;
      var menuTaps = 0;
      await _pump(tester, [
        MyClubRow(
          club: _club,
          caption: '21 Mayıs 2026',
          actionKey: _row,
          onTap: () => rowTaps++,
          menuKey: _menu,
          onMenu: () => menuTaps++,
        ),
      ]);
      final l10n = tester.l10n;
      expect(find.text(_club.name), findsOneWidget);
      expect(find.text(l10n.roleMember), findsOneWidget);
      expect(find.text('21 Mayıs 2026'), findsOneWidget);
      expect(find.byType(GuEmblem), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(_row), matching: find.byKey(_menu)),
        findsOneWidget,
      );
      // ⋮ varken chevron yok.
      expect(
        find.byWidgetPredicate(
          (w) => w is GuIcon && w.icon == GuIcons.chevronRight,
        ),
        findsNothing,
      );
      await tester.tap(find.byKey(_menu));
      expect((rowTaps, menuTaps), (0, 1));
      await tester.tap(find.text(_club.name));
      expect((rowTaps, menuTaps), (1, 1));
    });

    testWidgets('durum rozetleri: bekleyen, reddedildi, çıkarıldı, iptal, '
        'ayrıldı', (tester) async {
      await _pump(tester, _gallery());
      final l10n = tester.l10n;
      for (final label in [
        l10n.statusPending,
        l10n.statusRejected,
        l10n.statusRemoved,
        l10n.statusCancelled,
        l10n.statusLeft,
        l10n.roleBoard,
        l10n.rolePresident,
      ]) {
        expect(find.text(label), findsWidgets, reason: label);
      }
    });

    testWidgets('PRF-01 kart içi: chevron, ⋮ yok', (tester) async {
      await _pump(tester, [
        MyClubRow(club: _club, inCard: true, actionKey: _row, onTap: () {}),
      ]);
      expect(find.byType(GuIconButton), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is GuIcon && w.icon == GuIcons.chevronRight,
        ),
        findsOneWidget,
      );
    });

    testWidgets('EN 320 × 1.6: uzun ad + rozet + tarih taşmaz', (tester) async {
      OverflowDetector.install();
      addTearDown(OverflowDetector.reset);
      OverflowDetector.reset();
      await _pump(
        tester,
        [
          for (final status in MembershipStatus.values)
            MyClubRow(
              club: _longName,
              status: status,
              role: ClubRole.president,
              caption: '21 September 2026',
              actionKey: GuKey.action('PRF-03.row.${status.name}'),
              onTap: () {},
              menuKey: GuKey.action('PRF-03.menu.${status.name}'),
              onMenu: () {},
            ),
        ],
        locale: const Locale('en'),
        size: const Size(320, 844),
        textScale: 1.6,
      );
      OverflowDetector.assertNone('EN 320 × 1.6');
      expect(tester.takeException(), isNull);
    });

    testWidgets('galeri golden (açık + koyu)', (tester) async {
      await goldenForThemes(
        tester,
        'my_club_row',
        Scaffold(
          body: SingleChildScrollView(
            padding: GuInsets.all16,
            child: Column(children: _gallery()),
          ),
        ),
      );
    });
  });
}
