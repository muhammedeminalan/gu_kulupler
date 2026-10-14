// CLB-07 · Profil — içerik (başlık, bölüm · sınıf, ortak kulüpler; CD-99
// `pt24` yok), durumlar (gizli profil — D-29, engelli, rozetli + biyografili
// kendi profili, silinmiş kullanıcı, okunuyor, okunamadı, kullanıcı yok),
// 3 + 2 aksiyon ve sonuçları (CLB-01, CLB-03, SHT-27 → DLG-13 → TST-09,
// SHT-10), cihaz matrisi, aksiyon envanteri, açık + koyu golden.
// Referans: design/reference-shots/screens/CLB-07__*.webp.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/clubs/provider/user_profile_state.dart';
import 'package:gu_kulupler/features/clubs/view/user_profile_view.dart';
import 'package:gu_kulupler/features/clubs/view/widget/user_profile_header.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/user_menu_sheet.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';
import '../user_profile_test_support.dart';

final Key _back = GuKey.action('CLB-07.back');
final Key _menu = GuKey.action('CLB-07.menu');
final Key _club = GuKey.action('CLB-07.club.$kSharedClubId');
final Key _unblock = GuKey.action('CLB-07.unblock');
final Key _retry = GuKey.action('CLB-07.retry');

const UserProfileView _view = UserProfileView(
  userId: kUserId,
  clubId: kClubId,
);

Future<void> _pump(
  WidgetTester tester,
  UserProfileState state, {
  Locale locale = const Locale('tr'),
}) async {
  await tester.pumpApp(_view, locale: locale, overrides: stateOverride(state));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

void main() {
  group('CLB-07 · Profil · içerik', () {
    for (final locale in DeviceMatrix.locales) {
      testWidgets('görünür profil (${locale.languageCode}): çubuk, avatar 96, '
          'ad, bölüm · sınıf, ortak kulüp çipi', (tester) async {
        await _pump(tester, kVisibleState, locale: locale);
        final l10n = tester.l10n;
        final gu = tester.element(find.byType(UserProfileView)).gu;

        final bar = tester.widget<GuAppBar>(find.byType(GuAppBar));
        expect(bar.title, l10n.userprofileTitle);
        expect(find.byKey(_back), findsOneWidget);
        expect(find.bySemanticsLabel(l10n.a11yBack), findsOneWidget);
        final menu = tester.widget<GuIconButton>(find.byKey(_menu));
        expect(menu.icon, GuIcons.moreVertical);
        expect(menu.semanticLabel, l10n.a11yMore);

        final avatar = tester.widget<GuAvatar>(find.byType(GuAvatar));
        expect(avatar.size, 96);
        expect(avatar.initials, 'YK');
        expect(avatar.seed, kUser.avatarSeed);
        expect(
          tester.widget<Text>(find.text(kUser.name)).style,
          gu.text.titleL,
        );
        final departmentAndYear = '${l10n.deptD01} · ${l10n.year3}';
        final sub = tester.widget<Text>(find.text(departmentAndYear));
        expect(sub.style?.color, gu.colors.textSecondary);
        expect(sub.style?.fontSize, gu.text.bodyM.fontSize);
        expect(find.byType(GuRoleBadge), findsNothing);
        expect(find.byType(GuBanner), findsNothing);
        expect(find.byType(GuIllustration), findsNothing);

        expect(
          tester.widget<Text>(find.text(l10n.userprofileCommonClubs)).style,
          gu.text.titleS,
        );
        final chip = tester.widget<GuChip>(find.byKey(_club));
        expect(chip.label, kSharedClub.name);
        expect(chip.icon, GuIcons.codeXml);
      });
    }

    testWidgets('ölçüler: avatar çubuğun 16 altında ve ortalı; aralıklar 8; '
        '"Ortak kulüpler" bölüm · sınıfın hemen altında (CD-99: `pt24` '
        'yok); çip soldan 16', (tester) async {
      await _pump(tester, kVisibleState);
      final l10n = tester.l10n;

      final bar = tester.getRect(find.byType(GuAppBar));
      final avatar = tester.getRect(find.byType(GuAvatar));
      final name = tester.getRect(find.text(kUser.name));
      final sub = tester.getRect(
        find.text('${l10n.deptD01} · ${l10n.year3}'),
      );
      final title = tester.getRect(find.text(l10n.userprofileCommonClubs));
      final chip = tester.getRect(find.byKey(_club));

      expect(avatar.top, bar.bottom + 16);
      expect(avatar.center.dx, 195);
      expect(name.top, avatar.bottom + 8);
      expect(name.center.dx, 195);
      expect(sub.top, name.bottom + 8);
      expect(title.top, sub.bottom);
      expect(title.left, 16);
      expect(chip.top, title.bottom + 8);
      expect(chip.left, 16);
      expect(chip.height, GuSizes.chipHeight);
    });
  });

  group('CLB-07 · Profil · durumlar', () {
    testWidgets(
      'gizli profil (D-29): kilit illüstrasyonu 96 + açıklama; '
      'bölüm · sınıf, biyografi ve ortak kulüpler yok; menü durur — TR + EN',
      (
        tester,
      ) async {
        for (final locale in DeviceMatrix.locales) {
          await _pump(tester, kPrivateState, locale: locale);
          final l10n = tester.l10n;
          final gu = tester.element(find.byType(UserProfileView)).gu;

          expect(find.text(kUser.name), findsOneWidget);
          expect(find.text('${l10n.deptD01} · ${l10n.year3}'), findsNothing);
          final illustration = tester.widget<GuIllustration>(
            find.byType(GuIllustration),
          );
          expect(illustration.illustration, GuIllustrations.locked);
          expect(illustration.size, 96);
          final note = tester.widget<Text>(find.text(l10n.userprofilePrivate));
          expect(note.style?.color, gu.colors.textSecondary);
          expect(note.style?.fontSize, gu.text.bodyS.fontSize);
          expect(find.text(l10n.userprofileCommonClubs), findsNothing);
          expect(find.byType(GuChip), findsNothing);
          expect(find.byKey(_menu), findsOneWidget);
        }
      },
    );

    testWidgets('engelli kullanıcı: üstte uyarı bandı (`ban`) + "Engeli '
        'kaldır"', (tester) async {
      await _pump(tester, kBlockedState);
      final l10n = tester.l10n;

      final banner = tester.widget<GuBanner>(find.byType(GuBanner));
      expect(banner.kind, GuBannerKind.warning);
      expect(banner.icon, GuIcons.ban);
      expect(banner.text, l10n.userprofileBlockedBanner);
      expect(banner.actionLabel, l10n.userprofileUnblock);
      expect(find.byKey(_unblock), findsOneWidget);
      expect(
        tester.getRect(find.byType(GuBanner)).top,
        tester.getRect(find.byType(GuAppBar)).bottom,
      );
      expect(
        tester.getRect(find.byType(GuAvatar)).top,
        tester.getRect(find.byType(GuBanner)).bottom + 16,
      );
    });

    testWidgets('kendi profili: menü yok; süper admin + kulüp rolü rozetleri, '
        'biyografi', (tester) async {
      await _pump(tester, kRichState);
      final l10n = tester.l10n;

      expect(find.byKey(_menu), findsNothing);
      expect(
        tester
            .widgetList<GuRoleBadge>(find.byType(GuRoleBadge))
            .map((badge) => badge.kind),
        [
          GuRoleBadgeKind.superadmin,
          GuRoleBadgeKind.president,
          GuRoleBadgeKind.board,
          GuRoleBadgeKind.advisor,
        ],
      );
      expect(find.text(l10n.roleSuperadmin), findsOneWidget);
      expect(find.text(kViewer.bio), findsOneWidget);
      expect(
        tester.getSize(find.text(kViewer.bio)).width,
        lessThanOrEqualTo(280),
      );
      expect(find.byType(GuChip), findsNWidgets(2));
    });

    testWidgets('silinmiş kullanıcı: "Silinmiş kullanıcı" başlığı; ayrıntı ve '
        'menü yok', (tester) async {
      await _pump(tester, kDeletedState);
      final l10n = tester.l10n;

      expect(find.text(l10n.commonDeletedUser), findsOneWidget);
      expect(find.text(kUser.name), findsNothing);
      expect(find.text('${l10n.deptD01} · ${l10n.year3}'), findsNothing);
      expect(find.byKey(_menu), findsNothing);
      expect(find.byType(GuIllustration), findsNothing);
    });

    testWidgets('okunuyor: iskelet (erişilebilirlik etiketi), başlık yok; '
        'okunamadı: hata + "Yeniden dene"', (tester) async {
      await _pump(tester, kLoadingState);
      expect(find.byType(GuSkeleton), findsNWidgets(3));
      expect(find.bySemanticsLabel(tester.l10n.commonLoading), findsOneWidget);
      expect(find.byType(UserProfileHeader), findsNothing);
      expect(find.byKey(_menu), findsNothing);

      await _pump(tester, kErrorState);
      final l10n = tester.l10n;
      expect(find.text(l10n.sysErrorTitle), findsOneWidget);
      expect(find.byKey(_retry), findsOneWidget);
      expect(find.byType(UserProfileHeader), findsNothing);
    });
  });

  group('CLB-07 · Profil · envanter ve matris', () {
    testWidgets('aksiyon envanteri: 3 aksiyon (referans durumu)', (
      tester,
    ) async {
      await _pump(tester, kVisibleState);
      expectActionInventory(tester, 'CLB-07');
    });

    testWidgets('aksiyon envanteri: engelli (+ `unblock`), gizli (çip yok), '
        'okunuyor / okunamadı (çip ve menü yok)', (tester) async {
      await _pump(tester, kBlockedState);
      expectActionInventory(tester, 'CLB-07');
      expect(ActionInventory.found(tester), contains('CLB-07.unblock'));

      await _pump(tester, kPrivateState);
      expectActionInventory(
        tester,
        'CLB-07',
        extraExempt: const {'CLB-07.club.c01'},
      );

      for (final state in [kLoadingState, kErrorState]) {
        await _pump(tester, state);
        expectActionInventory(
          tester,
          'CLB-07',
          extraExempt: const {'CLB-07.club.c01', 'CLB-07.menu'},
        );
      }
    });

    testWidgets(
      'cihaz matrisi: taşma yok — görünür, engelli + rozetli, gizli',
      (
        tester,
      ) async {
        for (final state in [
          kVisibleState,
          kRichState.copyWith(isBlocked: true),
          kPrivateState,
        ]) {
          await DeviceMatrix.run(
            tester,
            (_) => _view,
            overrides: stateOverride(state),
            safeAreas: true,
          );
        }
      },
    );
  });

  group('CLB-07 · Profil · aksiyonlar', () {
    testWidgets('kullanıcı ve ortak kulüp gerçek okumadan gelir; çip → '
        'CLB-03; geri → CLB-01', (tester) async {
      final router = await pumpProfileRoute(tester);
      expect(find.text(kUser.name), findsOneWidget);
      expect(find.byKey(_club), findsOneWidget);

      await _tap(tester, _club);
      expect(locationOf(router), '/clubs/$kSharedClubId');

      router.go(kProfileLocation);
      await tester.pumpAndSettle();
      await _tap(tester, _back);
      // `pop` sorgu parametresini adreste bırakır; yol CLB-01'dir.
      expect(Uri.parse(locationOf(router)).path, '/clubs');
    });

    testWidgets('menü → SHT-27 (ad + engel durumu); "Engelle" → DLG-13 → '
        'TST-09 ve engel bandı; bant "Engeli kaldır" → TST-09', (tester) async {
      await pumpProfileRoute(tester);
      feedbackFake()
        ..nextSheetResult = UserMenuAction.block
        ..nextDialogResult = true;

      await _tap(tester, _menu);

      expect(feedbackFake().sheets, [SheetId.sht27]);
      final sheet =
          feedbackFake().lastSheetBuilder!(
                tester.element(find.byType(UserProfileView)),
              )
              as UserMenuSheet;
      expect(sheet.userId, kUserId);
      expect(sheet.userName, kUser.name);
      expect(sheet.isBlocked, isFalse);
      expect(feedbackFake().dialogs, [DialogId.dlg13]);
      expect(feedbackFake().toasts, [ToastId.tst09]);
      expect(blocksFake().callsTo('block'), hasLength(1));
      expect(find.byKey(_unblock), findsOneWidget);

      await _tap(tester, _unblock);

      expect(blocksFake().callsTo('softDeleteBlock'), hasLength(1));
      expect(feedbackFake().toasts, [ToastId.tst09, ToastId.tst09]);
      expect(feedbackFake().toastParams.last.unblocked, isTrue);
      expect(find.byKey(_unblock), findsNothing);
    });

    testWidgets('menü "Kullanıcıyı şikayet et" → SHT-10; "Profili gör" ve '
        'kapatma bir şey yapmaz', (tester) async {
      final router = await pumpProfileRoute(tester);

      feedbackFake().nextSheetResult = UserMenuAction.report;
      await _tap(tester, _menu);
      expect(feedbackFake().sheets, [SheetId.sht27, SheetId.sht10]);

      for (final result in [UserMenuAction.viewProfile, null]) {
        feedbackFake().nextSheetResult = result;
        await _tap(tester, _menu);
      }
      expect(feedbackFake().sheets, hasLength(4));
      expect(feedbackFake().dialogs, isEmpty);
      expect(blocksFake().calls, isEmpty);
      expect(reportsFake().calls, isEmpty);
      expect(locationOf(router), kProfileLocation);
    });

    testWidgets('kullanıcı belgesi yok → SYS-04; okunamadı → "Yeniden dene" '
        'içeriği getirir', (tester) async {
      final router = await pumpProfileRoute(tester, withUser: false);
      expect(locationOf(router), '/not-found');

      final failing = await pumpProfileRoute(
        tester,
        seed: () => usersFake().failNext(FirestoreError.unavailable),
      );
      expect(locationOf(failing), kProfileLocation);
      expect(find.byKey(_retry), findsOneWidget);

      await _tap(tester, _retry);
      expect(find.text(kUser.name), findsOneWidget);
      expect(find.byKey(_retry), findsNothing);
    });
  });

  group('CLB-07 · Profil · yönetici kartı (W-69)', () {
    final manager = kVisibleState.copyWith(
      contextMembership: kUserInShared.copyWith(
        id: 'c03_$kUserId',
        clubId: kClubId,
        role: ClubRole.member,
        status: MembershipStatus.active,
      ),
      contextClubName: 'Doğa Sporları',
      contactEmail: 'yigit@ogr.gumushane.edu.tr',
      canAssignRoles: true,
    );
    final copy = GuKey.action('CLB-07.copyEmail');
    final changeRole = GuKey.action('CLB-07.changeRole');
    final remove = GuKey.action('CLB-07.remove');

    testWidgets('başkan bakışı: e-posta + "Kopyala", rol, üyelik tarihi; '
        '"Rolü değiştir" + "Üyelikten çıkar"; envanter', (tester) async {
      await _pump(tester, manager);
      final l10n = tester.l10n;
      expect(find.text('yigit@ogr.gumushane.edu.tr'), findsOneWidget);
      expect(
        find.text(l10n.userprofileRoleIn('Doğa Sporları')),
        findsOneWidget,
      );
      expect(find.text(l10n.userprofileMemberSince), findsOneWidget);
      for (final key in [copy, changeRole, remove]) {
        expect(find.byKey(key), findsOneWidget);
      }
      expectActionInventory(tester, 'CLB-07');
    });

    testWidgets('yönetim kurulu bakışı "Rolü değiştir" çizmez; başkan hedefte '
        'düğme yok; bekleyen başvuruda kart yok', (tester) async {
      await _pump(tester, manager.copyWith(canAssignRoles: false));
      expect(find.byKey(changeRole), findsNothing);
      expect(find.byKey(remove), findsOneWidget);

      await _pump(
        tester,
        manager.copyWith(
          contextMembership: manager.contextMembership!.copyWith(
            role: ClubRole.president,
          ),
        ),
      );
      expect(find.byKey(copy), findsOneWidget);
      expect(find.byKey(remove), findsNothing);

      await _pump(
        tester,
        manager.copyWith(
          contextMembership: manager.contextMembership!.copyWith(
            status: MembershipStatus.pending,
          ),
        ),
      );
      expect(find.byKey(copy), findsNothing);
    });

    testWidgets('"Kopyala" → TST-08', (tester) async {
      await _pump(tester, manager);
      await tester.ensureVisible(find.byKey(copy));
      await _tap(tester, copy);
      expect(feedbackFake().toasts, [ToastId.tst08]);
    });

    testWidgets('cihaz matrisi: yönetici kartı taşmaz', (tester) async {
      await DeviceMatrix.run(
        tester,
        (_) => _view,
        overrides: stateOverride(manager),
        safeAreas: true,
      );
    });

    testWidgets('golden: yönetici kartı — açık + koyu (TR)', (tester) async {
      await goldenForThemes(
        tester,
        'CLB-07__manager',
        _view,
        overrides: stateOverride(manager),
      );
    });
  });

  group('CLB-07 · Profil · golden', () {
    testWidgets('golden: görünür profil — açık + koyu (TR)', (tester) async {
      await goldenForThemes(
        tester,
        'CLB-07',
        _view,
        overrides: stateOverride(kVisibleState),
      );
    });
  });
}
