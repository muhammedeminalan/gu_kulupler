// T-17 · MyClubChip (widget-catalog P7; K-30) — "Kulüplerim" şeridindeki 132
// genişliğinde kulüp kartı: 16:9 kapak, yönetici / askıda rozeti, ad (2
// satır), okunmamış noktası, anahtar, dokunma, erişilebilirlik. Galeri
// golden'ı ve cihaz matrisi `club_card_test.dart` galerisindedir.
// Kaynak: prototip `cards.js:41–45`.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/widget/club/my_club_chip.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fixtures/club_model_fixtures.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/overflow_detector.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';

const Locale _tr = Locale('tr');
const Locale _en = Locale('en');

final ClubModel _club = ClubModelFixtures.c01;
final ClubModel _suspended = _club.copyWith(status: ClubStatus.suspended);
final ClubModel _longName = _club.copyWith(
  name:
      'Uluslararası Öğrenci Değişim Programları ve Kültürlerarası '
      'İletişim Araştırmaları Topluluğu',
);

final Key _key = GuKey.action('CLB-01.myClub.${_club.id}');

/// Okunmamış bildirim noktası (`.dot`): daire biçimli kutu.
final Finder _dot = find.byWidgetPredicate(
  (widget) =>
      widget is DecoratedBox &&
      widget.decoration is ShapeDecoration &&
      (widget.decoration as ShapeDecoration).shape is CircleBorder,
);

Future<void> _pump(
  WidgetTester tester,
  Widget chip, {
  Locale locale = _tr,
  Size size = const Size(390, 844),
  double textScale = 1,
}) => tester.pumpApp(
  Scaffold(
    body: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: GuInsets.all16,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [chip],
      ),
    ),
  ),
  locale: locale,
  size: size,
  textScale: textScale,
);

void main() {
  group('T-17 · MyClubChip', () {
    testWidgets('132 genişliğinde kart: 16:9 kapak, ad (labelM, başlık rengi, '
        '2 satır), gövde dolgusu 8 / 10 / 10; rozet ve nokta yok', (
      tester,
    ) async {
      await _pump(tester, MyClubChip(club: _club, onTap: () {}));
      final context = tester.element(find.byType(MyClubChip));
      final gu = context.gu;

      final card = tester.getRect(find.byType(GuCard));
      expect(card.width, GuSizes.myClubCardWidth);
      final cover = tester.widget<GuCover>(find.byType(GuCover));
      expect(cover.ratio, GuCoverRatio.r16x9);
      final coverRect = tester.getRect(find.byType(GuCover));
      expect(coverRect.width, GuSizes.myClubCardWidth - 2 * GuSizes.cardBorder);

      final name = tester.widget<Text>(find.text(_club.name));
      expect(name.maxLines, 2);
      expect(name.overflow, TextOverflow.ellipsis);
      expect(name.style, gu.text.labelM.copyWith(color: gu.colors.textHeading));
      final nameRect = tester.getRect(find.text(_club.name));
      expect(nameRect.left - card.left, GuSizes.cardBorder + 10);
      expect(nameRect.top - coverRect.bottom, GuSpacing.s8);
      expect(card.bottom - nameRect.bottom, GuSizes.cardBorder + 10);

      expect(find.byType(GuBadge), findsNothing);
      expect(_dot, findsNothing);
      expect(tester.widget<GuCard>(find.byType(GuCard)).pressScale, 0.99);
    });

    testWidgets('`manager`: kapağın sol üstünde (6 / 6) "Yönetici" rozeti — '
        'TR ve EN', (tester) async {
      for (final locale in [_tr, _en]) {
        await _pump(
          tester,
          MyClubChip(club: _club, onTap: () {}, manager: true),
          locale: locale,
        );
        final badge = tester.widget<GuBadge>(find.byType(GuBadge));
        expect(badge.label, tester.l10nFor(locale).clubsCardManager);
        expect(badge.kind, GuBadgeKind.president);
        expect(badge.icon, GuIcons.shieldCheck);
        final cover = tester.getRect(find.byType(GuCover));
        final rect = tester.getRect(find.byType(GuBadge));
        expect(rect.left - cover.left, GuSpacing.s6);
        expect(rect.top - cover.top, GuSpacing.s6);
        expect(rect.right, lessThanOrEqualTo(cover.right - GuSpacing.s6));
      }
    });

    testWidgets('askıdaki kulüp: "Askıda" rozeti; yönetici olsa da tek rozet '
        '(askı öncelikli)', (tester) async {
      for (final manager in [false, true]) {
        await _pump(
          tester,
          MyClubChip(club: _suspended, onTap: () {}, manager: manager),
        );
        final badge = tester.widget<GuBadge>(find.byType(GuBadge));
        expect(badge.label, tester.l10nFor(_tr).statusSuspended);
        expect(badge.kind, GuBadgeKind.danger);
        expect(badge.icon, GuIcons.ban);
      }
    });

    testWidgets('`unread`: ad satırının sonunda 8 dp marka rengi nokta, '
        'dikeyde ortalı; ad noktaya 6 dp bırakır', (tester) async {
      await _pump(
        tester,
        MyClubChip(club: _longName, onTap: () {}, unread: true),
      );
      final dot = tester.getRect(_dot);
      expect(dot.size, const Size.square(GuSizes.dot));
      final decoration =
          tester.widget<DecoratedBox>(_dot).decoration as ShapeDecoration;
      final context = tester.element(find.byType(MyClubChip));
      expect(decoration.color, context.gu.colors.brandPrimary);
      expect(decoration.shape, const CircleBorder());

      final card = tester.getRect(find.byType(GuCard));
      final name = tester.getRect(find.text(_longName.name));
      expect(card.right - dot.right, GuSizes.cardBorder + 10);
      expect(dot.left - name.right, GuSpacing.s6);
      expect(dot.center.dy, moreOrLessEquals(name.center.dy, epsilon: 0.5));
    });

    testWidgets('anahtar çağırandan (`CLB-01.myClub.<id>`), kartın kendisidir; '
        'dokunma onTap', (tester) async {
      var taps = 0;
      await _pump(tester, MyClubChip(club: _club, onTap: () => taps++));
      expect(ActionInventory.found(tester), isEmpty);

      await _pump(
        tester,
        MyClubChip(club: _club, actionKey: _key, onTap: () => taps++),
      );
      expect(ActionInventory.found(tester), {'CLB-01.myClub.c01'});
      expect(tester.widget(find.byKey(_key)), isA<GuCard>());
      await tester.tap(find.byKey(_key));
      expect(taps, 1);
    });

    testWidgets('erişilebilirlik: tek düğme; etiket rozet + ad + okunmamış '
        'bildirim', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        MyClubChip(
          club: _club,
          actionKey: _key,
          onTap: () {},
          manager: true,
          unread: true,
        ),
      );
      final l10n = tester.l10nFor(_tr);
      final data = tester.getSemantics(find.byKey(_key)).getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(data.label, contains(_club.name));
      expect(data.label, contains(l10n.clubsCardManager));
      expect(data.label, contains(l10n.clubsMyUnread));
      handle.dispose();
    });

    testWidgets('uzun ad 320 dp × 1.6 ölçekte iki satırda kesilir; kart 132 '
        'kalır, taşma yok', (tester) async {
      OverflowDetector.install();
      addTearDown(OverflowDetector.reset);
      OverflowDetector.reset();
      await _pump(
        tester,
        MyClubChip(club: _longName, onTap: () {}, manager: true, unread: true),
        size: const Size(320, 844),
        textScale: 1.6,
      );
      expect(tester.getSize(find.byType(GuCard)).width, 132);
      final name = tester.widget<Text>(find.text(_longName.name));
      final style = name.style!;
      expect(
        tester.getSize(find.text(_longName.name)).height,
        moreOrLessEquals(2 * style.fontSize! * style.height! * 1.6, epsilon: 1),
      );
      final cover = tester.getRect(find.byType(GuCover));
      final badge = tester.getRect(find.byType(GuBadge));
      expect(badge.right, lessThanOrEqualTo(cover.right - GuSpacing.s6));
      OverflowDetector.assertNone('320 × 1.6');
      expect(tester.takeException(), isNull);
    });
  });
}
