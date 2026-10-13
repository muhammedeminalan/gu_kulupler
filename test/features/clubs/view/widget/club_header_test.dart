// CLB-03 · ClubHeader — kapak + üst çubuk, bantlar, amblem taşması, rozetler
// (katılım türü, rol), avatar grubu ve "+N", dört aksiyonun geri çağrıları
// (widget-catalog F2; prototip `screens-clubs.js:86–92`). Ekran düzeyi
// davranış ve golden `club_detail_view_test.dart`'tadır.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/clubs/view/widget/club_header.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../../helpers/device_matrix.dart';
import '../../../../helpers/pump_app.dart';
import '../../../../helpers/test_l10n.dart';
import '../../club_detail_test_support.dart';

const Key _back = ValueKey<String>('back');
const Key _share = ValueKey<String>('share');
const Key _menu = ValueKey<String>('menu');
const Key _count = ValueKey<String>('count');

void main() {
  final taps = <String>[];
  final offset = ValueNotifier<double>(0);

  setUp(() {
    taps.clear();
    offset.value = 0;
  });

  Widget header({
    ClubModel? club,
    ClubRole? role,
    bool isAdvisor = false,
    List<MembershipModel> memberPreview = const [],
  }) => Scaffold(
    body: SingleChildScrollView(
      child: ClubHeader(
        club: club ?? kClub,
        scrollOffset: offset,
        role: role,
        isAdvisor: isAdvisor,
        memberPreview: memberPreview,
        onBack: () => taps.add('back'),
        onShare: () => taps.add('share'),
        onMenu: () => taps.add('menu'),
        onMemberCount: () => taps.add('count'),
        backKey: _back,
        shareKey: _share,
        menuKey: _menu,
        memberCountKey: _count,
      ),
    ),
  );

  group('CLB-03 · ClubHeader', () {
    testWidgets('yerleşim: kapak 220, amblem 72 (36 taşar), ad amblemin 8 '
        'altında, yatay 16', (tester) async {
      await tester.pumpApp(header());
      final cover = tester.getRect(find.byType(GuParallaxHeader));
      expect(cover, const Rect.fromLTWH(0, 0, 390, 220));
      expect(
        tester.widget<GuCover>(find.byType(GuCover)).ratio,
        GuCoverRatio.fill,
      );
      final emblem = tester.getRect(find.byType(GuEmblem));
      expect(emblem, const Rect.fromLTWH(16, 220 - 36, 72, 72));
      final title = tester.getRect(find.text(kClub.name));
      expect(title.top, emblem.bottom + 8);
      expect(title.left, 16);
    });

    testWidgets('dört aksiyon geri çağrılarını tetikler', (tester) async {
      await tester.pumpApp(header());
      for (final key in [_back, _share, _menu, _count]) {
        await tester.tap(find.byKey(key));
      }
      expect(taps, ['back', 'share', 'menu', 'count']);
      // Üye sayısı satırı tek etiketle okunur.
      expect(
        find.bySemanticsLabel(tester.l10n.clubsCardMembers(kClub.memberCount)),
        findsOneWidget,
      );
    });

    testWidgets('rol rozeti: her aktif rol kendi rozetini alır; rol yoksa '
        'rozet yok', (tester) async {
      await tester.pumpApp(header());
      expect(find.byType(GuRoleBadge), findsNothing);

      for (final (role, kind) in [
        (ClubRole.member, GuRoleBadgeKind.member),
        (ClubRole.board, GuRoleBadgeKind.board),
        (ClubRole.president, GuRoleBadgeKind.president),
        (ClubRole.advisor, GuRoleBadgeKind.advisor),
      ]) {
        await tester.pumpApp(header(role: role));
        final l10n = tester.l10n;
        final badge = tester.widget<GuRoleBadge>(find.byType(GuRoleBadge));
        expect(badge.kind, kind);
        expect(badge.label, switch (role) {
          ClubRole.member => l10n.roleMember,
          ClubRole.board => l10n.roleBoard,
          ClubRole.president => l10n.rolePresident,
          ClubRole.advisor => l10n.roleAdvisor,
        });
      }
    });

    testWidgets('avatar grubu: en çok dört avatar; "+N" kalan üye sayısı; '
        'kalan yoksa hap yok', (tester) async {
      await tester.pumpApp(header(memberPreview: kManagers));
      var group = tester.widget<GuAvatarGroup>(find.byType(GuAvatarGroup));
      expect(group.avatars, hasLength(4));
      expect(group.avatars.first.seed, kPresident.applicant.avatarSeed);
      expect(group.moreLabel, '+${kClub.memberCount - 4}');

      await tester.pumpApp(
        header(
          club: kClub.copyWith(memberCount: 2),
          memberPreview: kManagers.take(2).toList(),
        ),
      );
      group = tester.widget<GuAvatarGroup>(find.byType(GuAvatarGroup));
      expect(group.avatars, hasLength(2));
      expect(group.moreLabel, isNull);
    });

    testWidgets('bantlar: askı + danışman birlikte; amblem son bandın üstüne '
        'taşar', (tester) async {
      await tester.pumpApp(
        header(
          club: kClub.copyWith(status: ClubStatus.suspended),
          isAdvisor: true,
        ),
      );
      final banners = tester.widgetList<GuBanner>(find.byType(GuBanner));
      expect(banners.map((b) => b.kind), [
        GuBannerKind.warning,
        GuBannerKind.readonly,
      ]);
      final last = tester.getRect(find.byType(GuBanner).last);
      expect(tester.getRect(find.byType(GuEmblem)).top, last.bottom - 36);
    });

    testWidgets('üst güvenli alan: kapak yukarı taşar, düğmeler güvenli '
        'alanın 4 dp üstünden başlar', (tester) async {
      const inset = 59.0;
      await tester.pumpApp(
        Padding(
          padding: const EdgeInsets.only(top: inset),
          child: header(),
        ),
        viewPadding: const EdgeInsets.only(top: inset),
      );
      expect(tester.getRect(find.byType(GuParallaxHeader)).top, 0);
      expect(tester.getRect(find.byKey(_back)).top, inset - 4);
      expect(tester.getRect(find.byType(GuEmblem)).top, 220 - 36);
    });

    testWidgets('cihaz matrisi: uzun ad, üç rozet, avatar grubu', (
      tester,
    ) async {
      await DeviceMatrix.run(
        tester,
        (_) => header(
          club: kClub.copyWith(
            name: 'Uluslararası Öğrenciler Dayanışma ve Kültür Kulübü',
            memberCount: 12345,
          ),
          role: ClubRole.president,
          isAdvisor: true,
          memberPreview: kManagers,
        ),
      );
    });
  });
}
