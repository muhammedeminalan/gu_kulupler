// SHT-19 · Başvuru detayı (`ApplicationDetailSheet`): beklemede gövde
// (başvuran, gönderim zamanı, not kartı, önceki başvuru, ortak kulüpler,
// e-posta — D-29 / CD-137), eylem sonuçları (`pop(ApplicationDetailAction)`),
// salt okunur (TST-26), karar bandı + "Geri al", "başvuru artık yok" (silinmiş
// başvuran — W-92), cihaz matrisi, açık + koyu golden. Referans:
// design/reference-shots/sheets/SHT-19__light.webp, __dark.webp; prototip
// sheets.js:89–97.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/management/view/widget/application_detail_sheet.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../../fixtures/membership_model_fixtures.dart';
import '../../../../helpers/device_matrix.dart';
import '../../../../helpers/golden_helper.dart';
import '../../../../helpers/test_l10n.dart';
import '../../../clubs/view/widget/club_sheet_harness.dart';

const Locale _tr = Locale('tr');

final MembershipModel _cem = MembershipModelFixtures.byId('c03_u_cem');
final MembershipModel _rejected = MembershipModelFixtures.byId('c03_u082');
final MembershipModel _approved = _cem.copyWith(
  status: MembershipStatus.active,
  decidedAt: DateTime.utc(2026, 10, 8),
);

const String _note = 'Yürüyüş ve kamp deneyimim var; ekipmanım tam.';
const MembershipContactModel _contact = MembershipContactModel(
  email: 'cem.aydin@ogr.gumushane.edu.tr',
  emailLower: 'cem.aydin@ogr.gumushane.edu.tr',
  note: _note,
);

Key _key(String action) => GuKey.action('SHT-19.$action');

ClubSheetHarness<ApplicationDetailAction> _harness(
  ApplicationDetailSheet Function() build,
) => ClubSheetHarness<ApplicationDetailAction>(
  SheetId.sht19,
  (_) => build(),
);

GuButton _footerButton(WidgetTester tester, String action) =>
    tester.widget<GuButton>(find.byKey(_key(action)));

void main() {
  group('SHT-19 · Başvuru detayı · gövde', () {
    testWidgets('beklemede: başvuran, gönderim, not kartı, önceki başvuru, '
        'profili gör; alt çubuk Reddet + Onayla', (tester) async {
      final h = _harness(
        () => ApplicationDetailSheet(application: _cem, contact: _contact),
      );
      await h.pump(tester);
      await h.open(tester);
      final l10n = tester.l10nFor(_tr);
      expect(find.text(l10n.sht19Title), findsOneWidget);
      expect(find.text('Cem Aydın'), findsOneWidget);
      expect(find.textContaining('2. sınıf'), findsOneWidget);
      expect(find.textContaining(l10n.appliedSentAt('')), findsOneWidget);
      expect(find.text('BAŞVURU NOTU'), findsOneWidget);
      expect(find.text(_note), findsOneWidget);
      expect(find.text(l10n.sht19Prior), findsOneWidget);
      expect(find.text(l10n.commonNo), findsOneWidget);
      expect(find.byKey(_key('profile')), findsOneWidget);
      expect(find.byType(GuBanner), findsNothing);
      expect(
        _footerButton(tester, 'reject').variant,
        GuButtonVariant.outline,
      );
      expect(
        _footerButton(tester, 'approve').variant,
        GuButtonVariant.primary,
      );
      expect(find.byKey(_key('undo')), findsNothing);
      // E-posta yalnızca yönetici bağlamında (D-29); kopyala geri çağrısı yok.
      expect(find.text(_contact.email), findsOneWidget);
      expect(find.byKey(_key('copyEmail')), findsNothing);
    });

    testWidgets('iletişim kaydı yok → "Not yok", e-posta satırı yok; ortak '
        'kulüpler rozet', (tester) async {
      final h = _harness(
        () => ApplicationDetailSheet(
          application: _cem,
          commonClubNames: const ['Yazılım', 'Satranç'],
        ),
      );
      await h.pump(tester);
      await h.open(tester);
      final l10n = tester.l10nFor(_tr);
      expect(find.text(l10n.applicationsNoNote), findsOneWidget);
      expect(find.text(l10n.authEmail), findsNothing);
      expect(find.text(l10n.userprofileCommonClubs), findsOneWidget);
      expect(
        tester.widgetList<GuBadge>(find.byType(GuBadge)).map((b) => b.label),
        ['Yazılım', 'Satranç'],
      );
    });

    testWidgets('e-posta kopyala → geri çağrı; sayfa açık kalır', (
      tester,
    ) async {
      var copied = 0;
      final h = _harness(
        () => ApplicationDetailSheet(
          application: _cem,
          contact: _contact,
          onCopyEmail: () => copied++,
        ),
      );
      await h.pump(tester);
      await h.open(tester);
      await tester.tap(find.byKey(_key('copyEmail')));
      await tester.pumpAndSettle();
      expect(copied, 1);
      expect(h.isClosed, isFalse);
    });
  });

  group('SHT-19 · Başvuru detayı · eylemler', () {
    for (final (action, expected) in [
      ('approve', ApplicationDetailAction.approve),
      ('reject', ApplicationDetailAction.reject),
      ('profile', ApplicationDetailAction.profile),
    ]) {
      testWidgets('"$action" → pop($expected)', (tester) async {
        final h = _harness(() => ApplicationDetailSheet(application: _cem));
        await h.pump(tester);
        await h.open(tester);
        await tester.ensureVisible(find.byKey(_key(action)));
        await tester.tap(find.byKey(_key(action)));
        await tester.pumpAndSettle();
        expect(h.result, expected);
      });
    }

    testWidgets('X → null', (tester) async {
      final h = _harness(() => ApplicationDetailSheet(application: _cem));
      await h.pump(tester);
      await h.open(tester);
      await tester.tap(find.byKey(_key('close')));
      await tester.pumpAndSettle();
      expect(h.isClosed, isTrue);
      expect(h.result, isNull);
    });

    testWidgets('salt okunur (danışman): Onayla / Reddet devre dışı, dokunuş '
        'TST-26 geri çağrısına; sayfa açık kalır', (tester) async {
      var readOnlyTaps = 0;
      final h = _harness(
        () => ApplicationDetailSheet(
          application: _cem,
          readOnly: true,
          onReadOnlyTap: () => readOnlyTaps++,
        ),
      );
      await h.pump(tester);
      await h.open(tester);
      expect(_footerButton(tester, 'approve').disabled, isTrue);
      expect(_footerButton(tester, 'reject').disabled, isTrue);
      await tester.tap(find.byKey(_key('approve')));
      await tester.tap(find.byKey(_key('reject')));
      await tester.pumpAndSettle();
      expect(readOnlyTaps, 2);
      expect(h.isClosed, isFalse);
    });
  });

  group('SHT-19 · Başvuru detayı · karar verilmiş / yok', () {
    testWidgets('onaylanan: başarı bandı; canUndo → yalnızca "Geri al" → '
        'pop(undo)', (tester) async {
      final h = _harness(
        () => ApplicationDetailSheet(application: _approved, canUndo: true),
      );
      await h.pump(tester);
      await h.open(tester);
      final l10n = tester.l10nFor(_tr);
      final banner = tester.widget<GuBanner>(find.byType(GuBanner));
      expect(banner.kind, GuBannerKind.success);
      expect(banner.text, l10n.statusApproved);
      expect(find.byKey(_key('approve')), findsNothing);
      expect(find.byKey(_key('reject')), findsNothing);
      await tester.tap(find.byKey(_key('undo')));
      await tester.pumpAndSettle();
      expect(h.result, ApplicationDetailAction.undo);
    });

    testWidgets('reddedilen: tehlike bandı + neden; pencere dışı / salt '
        'okunur → alt çubuk yok', (tester) async {
      for (final (canUndo, readOnly) in [(false, false), (true, true)]) {
        final h = _harness(
          () => ApplicationDetailSheet(
            application: _rejected,
            canUndo: canUndo,
            readOnly: readOnly,
          ),
        );
        await h.pump(tester);
        await h.open(tester);
        final l10n = tester.l10nFor(_tr);
        final banner = tester.widget<GuBanner>(find.byType(GuBanner));
        expect(banner.kind, GuBannerKind.danger);
        expect(
          banner.text,
          '${l10n.statusRejected} · ${l10n.rejectReasonQuota}',
        );
        expect(find.byType(GuButton), findsOneWidget); // yalnızca "Profili gör"
        expect(find.byKey(_key('undo')), findsNothing);
      }
    });

    testWidgets('başvuru yok / başvuranın hesabı silinmiş (W-92) → "Bu '
        'başvuru artık yok."', (tester) async {
      final deleted = _cem.copyWith(
        applicant: const MembershipApplicantModel(
          name: Anonymization.deletedUserName,
          avatarSeed: 'deleted',
        ),
      );
      for (final application in [null, deleted]) {
        final h = _harness(
          () => ApplicationDetailSheet(application: application),
        );
        await h.pump(tester);
        await h.open(tester);
        final l10n = tester.l10nFor(_tr);
        expect(find.text(l10n.sht19Gone), findsOneWidget);
        expect(find.byType(GuButton), findsNothing);
        expect(find.byType(GuAvatar), findsNothing);
      }
    });
  });

  group('SHT-19 · Başvuru detayı · yerleşim', () {
    testWidgets('cihaz matrisi: taşma yok (not + e-posta + ortak kulüpler + '
        'karar bandı)', (tester) async {
      await DeviceMatrix.run(
        tester,
        (context) => Align(
          alignment: Alignment.bottomCenter,
          child: ApplicationDetailSheet(
            application: _rejected,
            contact: _contact,
            commonClubNames: const ['Yazılım', 'Satranç', 'Fotoğrafçılık'],
            canUndo: true,
            onCopyEmail: () {},
          ),
        ),
        safeAreas: true,
      );
    });

    testWidgets('golden: beklemede (scrim dahil) — açık + koyu (TR)', (
      tester,
    ) async {
      for (final theme in kGoldenThemes) {
        final h = _harness(
          () => ApplicationDetailSheet(application: _cem, contact: _contact),
        );
        await h.pump(tester, theme: theme);
        await h.open(tester);
        await h.expectGolden(tester, 'SHT-19', theme);
      }
    });
  });
}
