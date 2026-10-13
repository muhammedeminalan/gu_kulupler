// T-20 · CommentRow (widget-catalog P15) — yorum satırı: avatar 32 + ad
// (+ üye dışı rol rozeti) + göreli zaman + metin (+ "…" menüsü); silinmiş
// yazar, sunucu zamanı gelmemiş yorum, SHT-09 biçimi (düğmesiz), çağıranın
// verdiği anahtarlar, erişilebilirlik, dar ekran + büyük metin. Kaynak:
// prototip `screens-clubs.js:176`, `sheets.js:48`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/widget/post/comment_row.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fixtures/comment_model_fixtures.dart';
import '../../../fixtures/user_model_fixtures.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/test_l10n.dart';
import 'post_test_support.dart';

/// `cm01` — Hilal Özdemir'in `p01` yorumu.
final CommentModel _comment = CommentModelFixtures.cm01;
final UserModel _author = UserModelFixtures.byId(_comment.authorId);

final Key _authorKey = GuKey.action('FED-02.author.${_comment.id}');
final Key _menuKey = GuKey.action('FED-02.commentMenu.${_comment.id}');

void main() {
  group('T-20 · CommentRow · içerik', () {
    testWidgets('avatar 32 + ad + göreli zaman + metin; üye rolünde rozet '
        'yok, diğer rollerde var — TR ve EN', (tester) async {
      for (final locale in [kTr, kEn]) {
        await pumpPost(
          tester,
          CommentRow(comment: _comment, author: _author, role: ClubRole.member),
          locale: locale,
        );
        final l10n = tester.l10nFor(locale);
        final gu = tester.element(find.byType(CommentRow)).gu;

        final avatar = tester.widget<GuAvatar>(find.byType(GuAvatar));
        expect(avatar.size, GuSizes.commentAvatar);
        expect(avatar.seed, _author.avatarSeed);
        expect(avatar.initials, _author.name.initials);
        final name = tester.widget<Text>(find.text(_author.name));
        expect(
          name.style,
          gu.text.labelL.copyWith(color: gu.colors.textHeading),
        );
        // `cm01` 26 Eyl 20:30, saat 7 Eki 21:00 → 11 gün → 1 hafta.
        expect(find.text(l10n.timeWeeksAgo(1)), findsOneWidget);
        expect(
          tester.widget<Text>(find.text(_comment.text)).style,
          gu.text.bodyM,
        );
        expect(find.byType(GuRoleBadge), findsNothing);
        expect(find.byType(GuIconButton), findsNothing);

        // Yerleşim: dikey dolgu 8; avatar → metin 8; ad → metin 2.
        final row = tester.getRect(find.byType(CommentRow));
        final avatarRect = tester.getRect(find.byType(GuAvatar));
        expect(avatarRect.top - row.top, GuSpacing.s8);
        expect(
          tester.getRect(find.text(_author.name)).left - avatarRect.right,
          GuSpacing.s8,
        );
        expect(
          tester.getRect(find.text(_comment.text)).top -
              tester.getRect(find.text(_author.name)).bottom,
          GuSpacing.s2,
        );

        await pumpPost(
          tester,
          CommentRow(comment: _comment, author: _author, role: ClubRole.board),
          locale: locale,
        );
        final badge = tester.widget<GuRoleBadge>(find.byType(GuRoleBadge));
        expect(badge.kind, GuRoleBadgeKind.board);
        expect(badge.label, l10n.roleBoard);
      }
    });

    testWidgets('silinmiş yazar: "Silinmiş kullanıcı", avatar `?`, rozet yok; '
        'sunucu zamanı gelmemiş yorum "Az önce"', (tester) async {
      await pumpPost(
        tester,
        CommentRow(
          comment: CommentModel(
            id: 'yeni',
            postId: _comment.postId,
            clubId: _comment.clubId,
            authorId: 'silinmis',
            text: 'Merhaba',
          ),
          role: ClubRole.president,
        ),
      );
      final l10n = tester.l10n;
      expect(find.text(l10n.commonDeletedUser), findsOneWidget);
      final avatar = tester.widget<GuAvatar>(find.byType(GuAvatar));
      expect((avatar.initials, avatar.seed), ('?', '?'));
      expect(find.byType(GuRoleBadge), findsNothing);
      expect(find.text(l10n.timeJustNow), findsOneWidget);
    });
  });

  group('T-20 · CommentRow · eylemler, erişilebilirlik', () {
    testWidgets('avatar → `onAuthor`, "…" (40, Daha fazla) → `onMenu`; '
        'anahtarlar çağırandan; avatar düğmesi yazar adıyla okunur', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var authors = 0;
      var menus = 0;
      await pumpPost(
        tester,
        CommentRow(
          comment: _comment,
          author: _author,
          onAuthor: () => authors++,
          authorKey: _authorKey,
          onMenu: () => menus++,
          menuKey: _menuKey,
        ),
      );
      final l10n = tester.l10n;

      final menu = tester.widget<GuIconButton>(find.byKey(_menuKey));
      expect(menu.icon, GuIcons.moreHorizontal);
      expect(menu.size, GuIconButtonSize.sm);
      expect(menu.semanticLabel, l10n.a11yMore);
      expect(
        tester.getSemantics(find.byKey(_authorKey)),
        isSemantics(
          label: _author.name,
          isButton: true,
          hasTapAction: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );
      // Menü sağ kenarda, satırın üstüne hizalı.
      final row = tester.getRect(find.byType(CommentRow));
      final menuRect = tester.getRect(find.byKey(_menuKey));
      expect(menuRect.right, row.right);
      expect(menuRect.top - row.top, GuSpacing.s8);

      await tester.tap(find.byKey(_authorKey));
      expect((authors, menus), (1, 0));
      await tester.tap(find.byKey(_menuKey));
      expect((authors, menus), (1, 1));
      // Metne dokunma hiçbir şey yapmaz.
      await tester.tap(find.text(_comment.text));
      expect((authors, menus), (1, 1));
      handle.dispose();
    });

    testWidgets('cihaz matrisi: uzun ad + rozet + uzun metin taşmaz (320 dp, '
        'ölçek 1.6, TR / EN)', (tester) async {
      await DeviceMatrix.run(
        tester,
        (_) => Scaffold(
          body: SingleChildScrollView(
            padding: GuInsets.all16,
            child: CommentRow(
              comment: _comment.copyWith(
                text:
                    'Perşembe buluşmasında ekipsiz gelenleri eşleştireceğiz, '
                    'merak etmeyin; mentorlarımız da orada olacak.',
              ),
              author: _author.copyWith(
                name: 'Abdurrahman Gazi Kahramanmaraşlıoğlu Yıldırımtürk',
              ),
              role: ClubRole.board,
              onAuthor: () {},
              onMenu: () {},
            ),
          ),
        ),
        overrides: [clockAt(kPostNow)],
      );
    });
  });
}
