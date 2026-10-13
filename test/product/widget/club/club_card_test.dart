// T-17 · ClubCard + MyClubChip galerisi (widget-catalog P6, P7) — kulüp
// kartının liste / ızgara varyantı: kapak, amblem, rozetler, metinler, avatar
// grubu, `ClubCta` bağlantısı, çağıranın verdiği anahtarlar, dokunmalar, alt
// satırın dar genişlik davranışı, erişilebilirlik, cihaz matrisi ve galeri
// golden'ı (açık + koyu). Kaynak: prototip `cards.js:28–45`.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/widget/club/club_card.dart';
import 'package:gu_kulupler/product/widget/club/club_cta.dart';
import 'package:gu_kulupler/product/widget/club/my_club_chip.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fixtures/club_model_fixtures.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/overflow_detector.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';

const Locale _tr = Locale('tr');
const Locale _en = Locale('en');

/// Onay gerekli, başvurular açık (demo `c01`: Teknoloji, 186 üye).
final ClubModel _club = ClubModelFixtures.c01.copyWith(
  applicationsOpen: true,
  approvalRequired: true,
);
final ClubModel _instant = _club.copyWith(approvalRequired: false);
final ClubModel _closed = _club.copyWith(applicationsOpen: false);
final ClubModel _suspended = _club.copyWith(status: ClubStatus.suspended);
final ClubModel _longName = _club.copyWith(
  name:
      'Uluslararası Öğrenci Değişim Programları ve Kültürlerarası '
      'İletişim Araştırmaları Topluluğu',
);

const List<GuAvatarData> _preview = [
  GuAvatarData(initials: 'BÇ', seed: 'u_baran'),
  GuAvatarData(initials: 'ZY', seed: 'u_zeynep'),
  GuAvatarData(initials: 'FY', seed: 'u_furkan'),
  GuAvatarData(initials: 'EY', seed: 'u_ebru'),
];

final Key _cardKey = GuKey.action('CLB-01.card.${_club.id}');
final Key _joinKey = GuKey.action('CLB-01.join.${_club.id}');
final Key _statusKey = GuKey.action('CLB-01.status.${_club.id}');
final Key _openKey = GuKey.action('CLB-01.open.${_club.id}');

/// Dokunma sayaçları.
final class _Taps {
  int open = 0;
  int join = 0;
  int closed = 0;
  int status = 0;

  List<int> get all => [open, join, closed, status];
}

ClubCard _card({
  ClubModel? club,
  ClubAccess access = ClubAccess.visitor,
  MembershipStatus? status,
  List<GuAvatarData> preview = _preview,
  bool grid = false,
  bool highlight = false,
  bool keyed = true,
  _Taps? taps,
}) => ClubCard(
  club: club ?? _club,
  access: access,
  membershipStatus: status,
  memberPreview: preview,
  grid: grid,
  highlight: highlight,
  actionKey: keyed ? _cardKey : null,
  joinKey: keyed ? _joinKey : null,
  statusKey: keyed ? _statusKey : null,
  openKey: keyed ? _openKey : null,
  onOpen: () => taps?.open++,
  onJoin: () => taps?.join++,
  onClosedTap: () => taps?.closed++,
  onStatus: () => taps?.status++,
);

/// Kartı ekran dolgusuyla (16) çizer; [gridWidth] verilirse o genişlikte
/// (ızgara sütunu).
Future<void> _pump(
  WidgetTester tester,
  Widget card, {
  Locale locale = _tr,
  Size size = const Size(390, 844),
  double textScale = 1,
  double? gridWidth,
}) => tester.pumpApp(
  Scaffold(
    body: SingleChildScrollView(
      padding: GuInsets.all16,
      child: gridWidth == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [card],
            )
          : Align(
              alignment: AlignmentDirectional.topStart,
              child: SizedBox(width: gridWidth, child: card),
            ),
    ),
  ),
  locale: locale,
  size: size,
  textScale: textScale,
);

/// Izgara sütunu genişliği: (ekran − 2 × 16 − 12) / 2.
double _columnWidth(double screen) =>
    (screen - 2 * GuSpacing.s16 - GuSpacing.s12) / 2;

/// Galeri: liste kartları (ziyaretçi, bekleyen + uzun ad, askıda), iki ızgara
/// satırı ve "Kulüplerim" şeridi.
Widget _gallery(BuildContext context) {
  Widget pair(Widget a, Widget b) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: GuSpacing.s12,
    children: [
      Expanded(child: a),
      Expanded(child: b),
    ],
  );
  return Scaffold(
    backgroundColor: context.gu.colors.bgCanvas,
    body: SafeArea(
      child: SingleChildScrollView(
        padding: GuInsets.v16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: GuSpacing.s12,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: GuInsets.h16,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: GuSpacing.s8,
                children: [
                  MyClubChip(club: _club, onTap: () {}, manager: true),
                  MyClubChip(club: _longName, onTap: () {}, unread: true),
                  MyClubChip(club: _suspended, onTap: () {}),
                ],
              ),
            ),
            Padding(
              padding: GuInsets.h16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: GuSpacing.s12,
                children: [
                  pair(
                    _card(grid: true, keyed: false),
                    _card(
                      club: _longName,
                      access: ClubAccess.pending,
                      status: MembershipStatus.pending,
                      grid: true,
                      keyed: false,
                    ),
                  ),
                  pair(
                    _card(
                      access: ClubAccess.manager,
                      status: MembershipStatus.active,
                      grid: true,
                      keyed: false,
                    ),
                    _card(club: _suspended, grid: true, keyed: false),
                  ),
                  _card(keyed: false),
                  _card(
                    club: _longName.copyWith(approvalRequired: false),
                    access: ClubAccess.pending,
                    status: MembershipStatus.pending,
                    keyed: false,
                  ),
                  _card(
                    club: _suspended,
                    access: ClubAccess.member,
                    status: MembershipStatus.active,
                    keyed: false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  group('T-17 · ClubCard · liste', () {
    testWidgets('kapak 16:9, sm amblem (ikon 22), ad, kategori rozeti, üye '
        'sayısı, özet, katılım türü ve sm düğme — TR ve EN', (tester) async {
      for (final locale in [_tr, _en]) {
        await _pump(tester, _card(), locale: locale);
        final l10n = tester.l10nFor(locale);

        final cover = tester.widget<GuCover>(find.byType(GuCover));
        expect(cover.ratio, GuCoverRatio.r16x9);
        final emblem = tester.widget<GuEmblem>(find.byType(GuEmblem));
        expect(emblem.size, GuEmblemSize.sm);
        expect(emblem.iconSize, GuSizes.icon22);
        expect(emblem.background, isNull);

        expect(find.text(_club.name), findsOneWidget);
        expect(tester.widget<GuBadge>(find.byType(GuBadge)).label, l10n.catK01);
        expect(
          find.text(l10n.clubsCardMembers(_club.memberCount)),
          findsOneWidget,
        );
        expect(find.text('${_club.summary} ${_club.about}'), findsOneWidget);
        expect(find.text(l10n.clubTypeApproval), findsOneWidget);
        expect(find.text(l10n.clubTypeInstant), findsNothing);

        final cta = tester.widget<ClubCta>(find.byType(ClubCta));
        expect(cta.size, GuButtonSize.sm);
        expect(cta.full, isFalse);
        expect(cta.kind, ClubCtaKind.join);
      }
    });

    testWidgets('anında katılım kulübü "Anında katılım" yazar; özet boşsa '
        'paragraf çizilmez', (tester) async {
      await _pump(
        tester,
        _card(
          club: _instant.copyWith(summary: '', about: ''),
        ),
      );
      final l10n = tester.l10nFor(_tr);
      expect(find.text(l10n.clubTypeInstant), findsOneWidget);
      expect(find.text(l10n.clubTypeApproval), findsNothing);
      expect(find.textContaining(_club.summary), findsNothing);
    });

    testWidgets('avatar grubu: en çok 3 kişi (24 dp) + "+N" üye sayısından; '
        'önizleme yoksa yalnızca "+N", üye de yoksa grup çizilmez', (
      tester,
    ) async {
      await _pump(tester, _card());
      var group = tester.widget<GuAvatarGroup>(find.byType(GuAvatarGroup));
      expect(group.size, 24);
      expect(find.byType(GuAvatar), findsNWidgets(ClubCard.previewMax));
      expect(group.moreLabel, '+${_club.memberCount - 3}');

      await _pump(tester, _card(preview: const []));
      group = tester.widget<GuAvatarGroup>(find.byType(GuAvatarGroup));
      expect(find.byType(GuAvatar), findsNothing);
      expect(group.moreLabel, '+${_club.memberCount}');

      await _pump(
        tester,
        _card(
          club: _club.copyWith(memberCount: 2),
          preview: _preview.take(2).toList(),
        ),
      );
      group = tester.widget<GuAvatarGroup>(find.byType(GuAvatarGroup));
      expect(find.byType(GuAvatar), findsNWidgets(2));
      expect(group.moreLabel, isNull);

      await _pump(
        tester,
        _card(club: _club.copyWith(memberCount: 0), preview: const []),
      );
      expect(find.byType(GuAvatarGroup), findsNothing);
    });

    testWidgets('askıdaki kulüp: kapağın sol üstünde (12 / 12) "Askıda" '
        'rozeti; düğme yerine de rozet', (tester) async {
      await _pump(tester, _card(club: _suspended));
      final l10n = tester.l10nFor(_tr);
      final badges = find.widgetWithText(GuBadge, l10n.statusSuspended);
      expect(badges, findsNWidgets(2));
      final cover = tester.getRect(find.byType(GuCover));
      final onCover = tester.getRect(badges.first);
      expect(onCover.left - cover.left, GuSpacing.s12);
      expect(onCover.top - cover.top, GuSpacing.s12);
      expect(find.byType(GuButton), findsNothing);
    });

    testWidgets(
      'alt satır: 390 dp genişlikte avatar grubu + tür solda, düğme sağda '
      'aynı satırda (dikeyde ortalı)',
      (tester) async {
        await _pump(tester, _card());
        final l10n = tester.l10nFor(_tr);
        final card = tester.getRect(find.byType(ClubCard));
        final group = tester.getRect(find.byType(GuAvatarGroup));
        final type = tester.getRect(find.text(l10n.clubTypeApproval));
        final button = tester.getRect(find.byType(GuButton));
        const edge = GuSizes.cardBorder + GuSizes.cardBodyPadding;
        expect(group.left, card.left + edge);
        expect(type.left - group.right, GuSpacing.s6);
        expect(button.right, card.right - edge);
        expect(
          group.center.dy,
          moreOrLessEquals(button.center.dy, epsilon: 0.5),
        );
        expect(
          type.center.dy,
          moreOrLessEquals(button.center.dy, epsilon: 0.5),
        );
        expect(card.bottom - button.bottom, edge);
      },
    );

    testWidgets('alt satır: sığmayınca önce tür metni sarar, yine sığmazsa '
        'düğme sağa yaslı alt satıra iner — taşma yok', (tester) async {
      OverflowDetector.install();
      addTearDown(OverflowDetector.reset);
      final l10n = tester.l10nFor(_tr);
      final pending = _card(
        club: _instant,
        access: ClubAccess.pending,
        status: MembershipStatus.pending,
      );

      // 360 dp: metin iki satıra sarar, düğme aynı satırda kalır.
      OverflowDetector.reset();
      await _pump(tester, pending, size: const Size(360, 844));
      var type = tester.getRect(find.text(l10n.clubTypeInstant));
      var button = tester.getRect(find.byType(GuButton));
      expect(type.height, greaterThan(GuSizes.icon16));
      expect(button.left, greaterThan(type.right));
      expect(type.center.dy, moreOrLessEquals(button.center.dy, epsilon: 0.5));
      OverflowDetector.assertNone('360');

      // 320 dp × 1.6: düğme alt satırda, sağa yaslı.
      OverflowDetector.reset();
      await _pump(
        tester,
        pending,
        size: const Size(320, 844),
        textScale: 1.6,
      );
      final card = tester.getRect(find.byType(ClubCard));
      type = tester.getRect(find.text(l10n.clubTypeInstant));
      button = tester.getRect(find.byType(GuButton));
      expect(button.top - type.bottom, greaterThanOrEqualTo(GuSpacing.s8));
      expect(
        button.right,
        card.right - GuSizes.cardBorder - GuSizes.cardBodyPadding,
      );
      OverflowDetector.assertNone('320 × 1.6');
      expect(tester.takeException(), isNull);
    });
  });

  group('T-17 · ClubCard · ızgara', () {
    testWidgets('kapak 3:2, sol altta (10 / 10) xs amblem (`bg.surface`), ad, '
        '"kategori · N üye", tam genişlik sm düğme; özet ve avatar grubu yok '
        '— TR ve EN', (tester) async {
      for (final locale in [_tr, _en]) {
        await _pump(
          tester,
          _card(grid: true),
          locale: locale,
          gridWidth: _columnWidth(390),
        );
        final l10n = tester.l10nFor(locale);
        final context = tester.element(find.byType(ClubCard));

        final cover = tester.widget<GuCover>(find.byType(GuCover));
        expect(cover.ratio, GuCoverRatio.r3x2);
        final emblem = tester.widget<GuEmblem>(find.byType(GuEmblem));
        expect(emblem.size, GuEmblemSize.xs);
        expect(emblem.background, context.gu.colors.bgSurface);
        final coverRect = tester.getRect(find.byType(GuCover));
        final emblemRect = tester.getRect(find.byType(GuEmblem));
        expect(emblemRect.left - coverRect.left, GuSizes.clubCardEmblemOffset);
        expect(
          coverRect.bottom - emblemRect.bottom,
          GuSizes.clubCardEmblemOffset,
        );

        expect(find.text(_club.name), findsOneWidget);
        expect(
          find.text(
            '${l10n.catK01} · ${l10n.clubsCardMembers(_club.memberCount)}',
          ),
          findsOneWidget,
        );
        expect(find.byType(GuAvatarGroup), findsNothing);
        expect(find.textContaining(_club.summary), findsNothing);
        expect(find.byType(GuBadge), findsNothing);

        final cta = tester.widget<ClubCta>(find.byType(ClubCta));
        expect(cta.size, GuButtonSize.sm);
        expect(cta.full, isTrue);
        final card = tester.getRect(find.byType(ClubCard));
        final button = tester.getRect(find.byType(GuButton));
        const edge = GuSizes.cardBorder + GuSizes.clubCardBodyPaddingX;
        expect(button.left, card.left + edge);
        expect(button.right, card.right - edge);
        expect(
          card.bottom - button.bottom,
          GuSizes.cardBorder + GuSizes.clubCardBodyPaddingBottom,
        );
      }
    });

    test('üyelik rozeti eşlemesi (gridStatusOf): bekleyen / reddedilen / '
        'etkin üye; ziyaretçi ve çıkarılmış üye rozetsiz; süper admin yalnızca '
        'etkin üyelikte', () {
      GuStatusBadgeKind? of(ClubAccess access, [MembershipStatus? status]) =>
          ClubCard.gridStatusOf(access: access, membershipStatus: status);
      expect(of(ClubAccess.visitor), isNull);
      expect(of(ClubAccess.visitor, MembershipStatus.removed), isNull);
      expect(of(ClubAccess.visitor, MembershipStatus.left), isNull);
      expect(
        of(ClubAccess.pending, MembershipStatus.pending),
        GuStatusBadgeKind.pending,
      );
      expect(
        of(ClubAccess.rejected, MembershipStatus.rejected),
        GuStatusBadgeKind.rejected,
      );
      for (final access in [
        ClubAccess.member,
        ClubAccess.manager,
        ClubAccess.advisor,
      ]) {
        expect(
          of(access, MembershipStatus.active),
          GuStatusBadgeKind.active,
          reason: access.name,
        );
      }
      expect(of(ClubAccess.superAdmin), isNull);
      expect(of(ClubAccess.superAdmin, MembershipStatus.pending), isNull);
      expect(
        of(ClubAccess.superAdmin, MembershipStatus.active),
        GuStatusBadgeKind.active,
      );
    });

    testWidgets('üyelik rozeti kapağın sağ üstünde (8 / 8): "Beklemede" / '
        '"Reddedildi" / "Üye"', (tester) async {
      final l10n = tester.l10nFor(_tr);
      final cases = <(ClubAccess, MembershipStatus, GuStatusBadgeKind, String)>[
        (
          ClubAccess.pending,
          MembershipStatus.pending,
          GuStatusBadgeKind.pending,
          l10n.statusPending,
        ),
        (
          ClubAccess.rejected,
          MembershipStatus.rejected,
          GuStatusBadgeKind.rejected,
          l10n.statusRejected,
        ),
        (
          ClubAccess.member,
          MembershipStatus.active,
          GuStatusBadgeKind.active,
          l10n.clubsCardMemberShort,
        ),
      ];
      for (final (access, status, kind, label) in cases) {
        await _pump(
          tester,
          _card(access: access, status: status, grid: true),
          gridWidth: _columnWidth(390),
        );
        final badge = tester.widget<GuStatusBadge>(find.byType(GuStatusBadge));
        expect(badge.kind, kind, reason: access.name);
        expect(badge.label, label, reason: access.name);
        final cover = tester.getRect(find.byType(GuCover));
        final rect = tester.getRect(find.byType(GuStatusBadge));
        expect(cover.right - rect.right, GuSpacing.s8);
        expect(rect.top - cover.top, GuSpacing.s8);
      }

      await _pump(tester, _card(grid: true), gridWidth: _columnWidth(390));
      expect(find.byType(GuStatusBadge), findsNothing);
    });
  });

  group('T-17 · ClubCard · anahtar, dokunma, erişilebilirlik', () {
    testWidgets('anahtarlar çağırandan: kart + çıktıya göre join / status / '
        'open; verilmezse anahtar çizilmez (liste ve ızgara)', (tester) async {
      for (final grid in [false, true]) {
        final width = grid ? _columnWidth(390) : null;
        await _pump(tester, _card(grid: grid, keyed: false), gridWidth: width);
        expect(ActionInventory.found(tester), isEmpty);

        final expected = <ClubCard, Set<String>>{
          _card(grid: grid): {'CLB-01.card.c01', 'CLB-01.join.c01'},
          _card(club: _closed, grid: grid): {
            'CLB-01.card.c01',
            'CLB-01.join.c01',
          },
          _card(
            access: ClubAccess.pending,
            status: MembershipStatus.pending,
            grid: grid,
          ): {
            'CLB-01.card.c01',
            'CLB-01.status.c01',
          },
          _card(
            access: ClubAccess.member,
            status: MembershipStatus.active,
            grid: grid,
          ): {
            'CLB-01.card.c01',
            'CLB-01.open.c01',
          },
          _card(club: _suspended, grid: grid): {'CLB-01.card.c01'},
        };
        for (final MapEntry(key: card, value: actions) in expected.entries) {
          await _pump(tester, card, gridWidth: width);
          expect(ActionInventory.found(tester), actions);
        }
      }
    });

    testWidgets('karta dokunma onOpen; düğmeye dokunma yalnızca kendi geri '
        'çağrısı (kart açılmaz)', (tester) async {
      for (final grid in [false, true]) {
        final width = grid ? _columnWidth(390) : null;

        var taps = _Taps();
        await _pump(
          tester,
          _card(grid: grid, taps: taps),
          gridWidth: width,
        );
        await tester.tap(find.text(_club.name));
        expect(taps.all, [1, 0, 0, 0]);
        await tester.tap(find.byKey(_joinKey));
        expect(taps.all, [1, 1, 0, 0]);

        taps = _Taps();
        await _pump(
          tester,
          _card(club: _closed, grid: grid, taps: taps),
          gridWidth: width,
        );
        await tester.tap(find.byKey(_joinKey));
        expect(taps.all, [0, 0, 1, 0]);

        taps = _Taps();
        await _pump(
          tester,
          _card(
            access: ClubAccess.rejected,
            status: MembershipStatus.rejected,
            grid: grid,
            taps: taps,
          ),
          gridWidth: width,
        );
        await tester.tap(find.byKey(_statusKey));
        expect(taps.all, [0, 0, 0, 1]);

        taps = _Taps();
        await _pump(
          tester,
          _card(
            access: ClubAccess.member,
            status: MembershipStatus.active,
            grid: grid,
            taps: taps,
          ),
          gridWidth: width,
        );
        await tester.tap(find.byKey(_openKey));
        expect(taps.all, [1, 0, 0, 0]);
      }
    });

    testWidgets('`highlight` karta aktarılır; kart `GuCard` anahtarını taşır', (
      tester,
    ) async {
      await _pump(tester, _card(highlight: true));
      final card = tester.widget<GuCard>(find.byKey(_cardKey));
      expect(card.highlight, isTrue);
      expect(card.onTap, isNotNull);
      await tester.pump(GuMotion.highlight);

      await _pump(tester, _card());
      expect(tester.widget<GuCard>(find.byKey(_cardKey)).highlight, isFalse);
    });

    testWidgets('erişilebilirlik: kart ad + kategori + üye sayısı + tür okunan '
        'tek düğmedir (özet ve avatarlar okunmaz); "Katıl" ayrı düğmedir', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _card());
      final l10n = tester.l10nFor(_tr);

      final card = tester.getSemantics(find.byKey(_cardKey));
      final data = card.getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(data.label, contains(_club.name));
      expect(data.label, contains(l10n.catK01));
      expect(data.label, contains(l10n.clubsCardMembers(_club.memberCount)));
      expect(data.label, contains(l10n.clubTypeApproval));
      expect(data.label, isNot(contains(_club.summary)));
      expect(data.label, isNot(contains('+')));
      expect(data.label, isNot(contains(l10n.clubsCardJoin)));

      expect(
        tester.getSemantics(find.byKey(_joinKey)),
        isSemantics(
          label: l10n.clubsCardJoin,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });
  });

  group('T-17 · ClubCard · yerleşim', () {
    testWidgets('uzun ad iki satırda kesilir; 320 dp × 1.6 ölçekte liste, '
        'ızgara ve "Kulüplerim" kartı taşmaz', (tester) async {
      OverflowDetector.install();
      addTearDown(OverflowDetector.reset);
      for (final grid in [false, true]) {
        OverflowDetector.reset();
        await _pump(
          tester,
          _card(
            club: _longName,
            access: ClubAccess.manager,
            status: MembershipStatus.active,
            grid: grid,
          ),
          size: const Size(320, 844),
          textScale: 1.6,
          gridWidth: grid ? _columnWidth(320) : null,
        );
        final name = tester.widget<Text>(find.text(_longName.name));
        expect(name.maxLines, 2);
        expect(name.overflow, TextOverflow.ellipsis);
        final style = name.style!;
        expect(
          tester.getSize(find.text(_longName.name)).height,
          moreOrLessEquals(
            2 * style.fontSize! * style.height! * 1.6,
            epsilon: 1,
          ),
        );
        OverflowDetector.assertNone(grid ? 'ızgara' : 'liste');
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('ızgara + rozet ("Yönetici" + "Aç"): 390 dp genişlikte yan '
        'yana, düğme kalan alanı doldurur; 320 dp × 1.6 ölçekte rozet üstte, '
        'düğme tam genişlikte altta', (tester) async {
      final manager = _card(
        access: ClubAccess.manager,
        status: MembershipStatus.active,
        grid: true,
      );
      const edge = GuSizes.cardBorder + GuSizes.clubCardBodyPaddingX;
      final l10n = tester.l10nFor(_tr);
      final badgeFinder = find.widgetWithText(GuBadge, l10n.clubsCardManager);

      await _pump(tester, manager, gridWidth: _columnWidth(390));
      var card = tester.getRect(find.byType(ClubCard));
      var badge = tester.getRect(badgeFinder);
      var button = tester.getRect(find.byType(GuButton));
      expect(badge.left, card.left + edge);
      expect(button.left - badge.right, GuSpacing.s8);
      expect(button.right, card.right - edge);
      expect(badge.center.dy, moreOrLessEquals(button.center.dy, epsilon: 0.5));

      await _pump(
        tester,
        manager,
        size: const Size(320, 844),
        textScale: 1.6,
        gridWidth: _columnWidth(320),
      );
      card = tester.getRect(find.byType(ClubCard));
      badge = tester.getRect(badgeFinder);
      button = tester.getRect(find.byType(GuButton));
      expect(badge.left, card.left + edge);
      expect(badge.right, lessThanOrEqualTo(card.right - edge));
      expect(button.top - badge.bottom, GuSpacing.s8);
      expect(button.left, card.left + edge);
      expect(button.right, card.right - edge);
      expect(tester.takeException(), isNull);
    });

    testWidgets('eş yükseklikli ızgara satırında (IntrinsicHeight) ve liste '
        'kartında iç ölçü sorgusu çalışır', (tester) async {
      await _pump(
        tester,
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: GuSpacing.s12,
            children: [
              Expanded(
                child: _card(
                  club: _longName,
                  access: ClubAccess.manager,
                  status: MembershipStatus.active,
                  grid: true,
                  keyed: false,
                ),
              ),
              Expanded(child: _card(grid: true, keyed: false)),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final cards = find.byType(ClubCard);
      expect(
        tester.getSize(cards.first).height,
        tester.getSize(cards.last).height,
      );

      await _pump(tester, IntrinsicHeight(child: _card()));
      expect(tester.takeException(), isNull);
    });

    testWidgets('cihaz matrisi: galeri taşmaz (320 dp, ölçek 1.6, TR / EN)', (
      tester,
    ) async {
      await DeviceMatrix.run(tester, _gallery);
    });

    testWidgets('golden: galeri — açık + koyu (TR)', (tester) async {
      await goldenForThemes(
        tester,
        'club_card',
        const Builder(builder: _gallery),
        size: const Size(390, 1500),
      );
    });
  });
}
