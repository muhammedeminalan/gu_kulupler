// T-18 · MemberRow (widget-catalog P2) + üye satırları galerisi — `UserRow` +
// rol rozeti (+ katılım oranı çubuğu) + "⋮" menüsü: `applicant` anlık
// görüntüsü / güncel kullanıcı, dört rol, alt satır üst yazımı, menü ve
// sondaki öğe, oran satırı (TR / EN yüzde), kart içi biçim, çağıranın verdiği
// anahtarlar, erişilebilirlik, cihaz matrisi ve galeri golden'ı (açık + koyu;
// `UserRow` varyantları dahil). Kaynak: prototip `cards.js:165–169`.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/l10n/static_labels.dart';
import 'package:gu_kulupler/product/widget/member/member_row.dart';
import 'package:gu_kulupler/product/widget/member/user_row.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fixtures/membership_model_fixtures.dart';
import '../../../fixtures/user_model_fixtures.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';

const Locale _tr = Locale('tr');
const Locale _en = Locale('en');

/// Demo `c03` üyelikleri: başkan, yönetim kurulu, danışman, üye.
final MembershipModel _president = MembershipModelFixtures.byId('c03_u_burak');
final MembershipModel _board = MembershipModelFixtures.byId('c03_u032');
final MembershipModel _advisor = MembershipModelFixtures.byId('c03_u_a_c03');
final MembershipModel _member = MembershipModelFixtures.byId('c03_u086');

/// Uzun adlı üye (anlık görüntü üst yazımı).
final MembershipModel _longMember = _member.copyWith(
  applicant: MembershipApplicantModel(
    name: 'Abdurrahman Gazi Kahramanmaraşlıoğlu Yıldırımtürk',
    avatarSeed: 'uzun',
    department: _member.applicant.department,
    year: _member.applicant.year,
  ),
);

final Key _rowKey = GuKey.action('CLB-06.member.${_member.userId}');
final Key _menuKey = GuKey.action('CLB-06.menu.${_member.userId}');

Future<void> _pump(
  WidgetTester tester,
  Widget row, {
  Locale locale = _tr,
  Size size = const Size(390, 844),
  double textScale = 1,
}) => tester.pumpApp(
  Scaffold(
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [row],
    ),
  ),
  locale: locale,
  size: size,
  textScale: textScale,
);

UserRow _row(WidgetTester tester) =>
    tester.widget<UserRow>(find.byType(UserRow));

/// Galeri: `UserRow` (kullanıcı, silinmiş, kart içi danışman + yönetim
/// kurulu) ve `MemberRow` (dört rol, menü, oran, uzun ad).
Widget _gallery(BuildContext context) => Scaffold(
  backgroundColor: context.gu.colors.bgCanvas,
  body: SafeArea(
    child: SingleChildScrollView(
      padding: GuInsets.v16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UserRow(
            user: UserModelFixtures.byId('u_burak'),
            sub: MemberRow.departmentAndYear(
              context,
              department: _president.applicant.department,
              year: _president.applicant.year,
            ),
            onTap: () {},
          ),
          const UserRow(user: null),
          Padding(
            padding: GuInsets.all16,
            child: GuCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  UserRow.named(
                    name: 'Doç. Dr. Hakan Yalçın',
                    avatarSeed: 'u_a_c03',
                    sub: context.l10n.roleAdvisor,
                    inCard: true,
                    chevron: true,
                    onTap: () {},
                  ),
                  const GuDivider(),
                  MemberRow(
                    membership: _president,
                    inCard: true,
                    chevron: true,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
          MemberRow(membership: _president, onTap: () {}),
          MemberRow(membership: _board, onTap: () {}),
          MemberRow(membership: _advisor, onTap: () {}),
          MemberRow(membership: _member, onTap: () {}, onMenu: () {}),
          MemberRow(
            membership: _member,
            showRate: true,
            rate: 62,
            onTap: () {},
            onMenu: () {},
          ),
          MemberRow(membership: _longMember, onTap: () {}, onMenu: () {}),
        ],
      ),
    ),
  ),
);

void main() {
  group('T-18 · MemberRow · içerik', () {
    testWidgets('anlık görüntüden: ad, bölüm · sınıf, avatar; her rolün '
        'rozeti — TR ve EN', (tester) async {
      for (final locale in [_tr, _en]) {
        final l10n = tester.l10nFor(locale);
        for (final (membership, kind, label) in [
          (_president, GuRoleBadgeKind.president, l10n.rolePresident),
          (_board, GuRoleBadgeKind.board, l10n.roleBoard),
          (_advisor, GuRoleBadgeKind.advisor, l10n.roleAdvisor),
          (_member, GuRoleBadgeKind.member, l10n.roleMember),
        ]) {
          await _pump(
            tester,
            MemberRow(membership: membership),
            locale: locale,
          );
          final applicant = membership.applicant;
          final context = tester.element(find.byType(MemberRow));
          expect(find.text(applicant.name), findsOneWidget);
          expect(
            _row(tester).sub,
            [
              StaticLabels.department(context, applicant.department!),
              StaticLabels.year(context, applicant.year!),
            ].join(' · '),
          );
          final avatar = tester.widget<GuAvatar>(find.byType(GuAvatar));
          expect(avatar.seed, applicant.avatarSeed);
          expect(avatar.size, GuSizes.avatar);
          final badge = tester.widget<GuRoleBadge>(find.byType(GuRoleBadge));
          expect(badge.kind, kind);
          expect(badge.label, label);
          expect(_row(tester).inCard, isFalse);
          expect(_row(tester).chevron, isFalse);
          expect(find.byType(GuIconButton), findsNothing);
          expect(find.byType(GuProgress), findsNothing);
        }
      }
    });

    testWidgets('güncel kullanıcı belgesi anlık görüntünün yerini alır; '
        '`sub` alt satırı ezer; kart içi biçim aktarılır', (tester) async {
      final user = UserModelFixtures.byId('u_burak').copyWith(
        name: 'Burak Şahin Yeni',
        avatarSeed: 'yeni',
        department: _board.applicant.department,
      );
      await _pump(tester, MemberRow(membership: _president, user: user));
      final context = tester.element(find.byType(MemberRow));
      expect(find.text('Burak Şahin Yeni'), findsOneWidget);
      expect(tester.widget<GuAvatar>(find.byType(GuAvatar)).seed, 'yeni');
      expect(
        _row(tester).sub,
        startsWith(
          StaticLabels.department(context, _board.applicant.department!),
        ),
      );

      await _pump(
        tester,
        MemberRow(
          membership: _president,
          sub: 'Mayıs 2025’ten beri',
          inCard: true,
          chevron: true,
        ),
      );
      expect(_row(tester).sub, 'Mayıs 2025’ten beri');
      expect(_row(tester).inCard, isTrue);
      expect(_row(tester).chevron, isTrue);
    });

    testWidgets('katılım oranı: `showRate` ile ince başarı çubuğu + yüzde '
        '(TR `%62`, EN `62%`); `showRate` yoksa çizilmez', (tester) async {
      for (final (locale, percent) in [(_tr, '%62'), (_en, '62%')]) {
        await _pump(
          tester,
          MemberRow(membership: _member, showRate: true, rate: 62),
          locale: locale,
        );
        final l10n = tester.l10nFor(locale);
        final progress = tester.widget<GuProgress>(find.byType(GuProgress));
        expect(progress.value, 62);
        expect(progress.thin, isTrue);
        expect(progress.kind, GuProgressKind.success);
        expect(progress.semanticLabel, l10n.mgtMembersRate);
        expect(find.text(percent), findsOneWidget);
        // Çubuk kalan genişliği alır; yüzde 6 dp sağındadır.
        final bar = tester.getRect(find.byType(GuProgress));
        final text = tester.getRect(find.text(percent));
        expect(text.left - bar.right, GuSpacing.s6);
        expect(bar.width, greaterThan(GuSizes.progressMinWidth));
        // Oran satırı alt satırın (bölüm · sınıf) altındadır.
        final sub = tester.getRect(find.text(_row(tester).sub!));
        expect(text.top, greaterThanOrEqualTo(sub.bottom));
      }

      await _pump(tester, MemberRow(membership: _member, rate: 62));
      expect(find.byType(GuProgress), findsNothing);
      await _pump(tester, MemberRow(membership: _member, showRate: true));
      expect(find.byType(GuProgress), findsNothing);
    });
  });

  group('T-18 · MemberRow · menü, anahtarlar, erişilebilirlik', () {
    testWidgets('menü: `onMenu` varsa "⋮" (Daha fazla) çizilir; düğme yalnızca '
        'menüyü, satır yalnızca `onTap` çağırır; anahtarlar çağırandan', (
      tester,
    ) async {
      var taps = 0;
      var menus = 0;
      await _pump(
        tester,
        MemberRow(
          membership: _member,
          actionKey: _rowKey,
          menuActionKey: _menuKey,
          onTap: () => taps++,
          onMenu: () => menus++,
        ),
      );
      final button = tester.widget<GuIconButton>(find.byKey(_menuKey));
      expect(button.icon, GuIcons.moreVertical);
      expect(button.semanticLabel, tester.l10n.a11yMore);
      expect(tester.widget(find.byKey(_rowKey)), isA<GuTile>());

      await tester.tap(find.byKey(_menuKey));
      expect((taps, menus), (0, 1));
      await tester.tap(find.text(_member.applicant.name));
      expect((taps, menus), (1, 1));
    });

    testWidgets('`trailing` menü düğmesinin yerini alır', (tester) async {
      await _pump(
        tester,
        MemberRow(
          membership: _member,
          onMenu: () {},
          trailing: const Text('sonda'),
        ),
      );
      expect(find.text('sonda'), findsOneWidget);
      expect(find.byType(GuIconButton), findsNothing);
    });

    testWidgets('erişilebilirlik: satır ad + rol + alt satırla okunan '
        'düğmedir; oran satırı varken oran etiketi ve yüzde de okunur', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final l10n = tester.l10nFor(_tr);
      await _pump(
        tester,
        MemberRow(membership: _member, actionKey: _rowKey, onTap: () {}),
      );
      final data = tester.getSemantics(find.byKey(_rowKey)).getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(data.label, contains(_member.applicant.name));
      expect(data.label, contains(l10n.roleMember));
      expect(data.label, contains(_row(tester).sub));

      await _pump(
        tester,
        MemberRow(membership: _member, showRate: true, rate: 62),
      );
      expect(find.bySemanticsLabel(l10n.mgtMembersRate), findsOneWidget);
      expect(find.bySemanticsLabel('%62'), findsOneWidget);
      handle.dispose();
    });
  });

  group('T-18 · üye satırları · galeri', () {
    testWidgets('cihaz matrisi: galeri taşmaz (320 dp, ölçek 1.6, TR / EN)', (
      tester,
    ) async {
      await DeviceMatrix.run(tester, _gallery);
    });

    testWidgets('golden: galeri — açık + koyu (TR)', (tester) async {
      await goldenForThemes(
        tester,
        'member_rows',
        const Builder(builder: _gallery),
        size: const Size(390, 760),
      );
    });
  });
}
