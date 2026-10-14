// SHT-20 · Red nedeni (`RejectReasonSheet`): başvuranın adı, dört neden çipi
// (`RejectReason` sırası, varsayılan kontenjan), isteğe bağlı açıklama
// (`Limits.rejectNoteMax` = 200, fazlası kesilir), sonuç
// (`pop(RejectDecision)` — açıklama kırpılır, boş → null), kapanma (null),
// anahtarlar, cihaz matrisi, açık + koyu golden. Referans:
// design/reference-shots/sheets/SHT-20__light.webp, __dark.webp; prototip
// sheets.js:98–101.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/management/view/widget/reject_reason_sheet.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../../helpers/device_matrix.dart';
import '../../../../helpers/golden_helper.dart';
import '../../../../helpers/test_l10n.dart';
import '../../../clubs/view/widget/club_sheet_harness.dart';

const Locale _tr = Locale('tr');
const String _name = 'Cem Aydın';

ClubSheetHarness<RejectDecision> _harness() => ClubSheetHarness<RejectDecision>(
  SheetId.sht20,
  (_) => const RejectReasonSheet(applicantName: _name),
);

List<GuChip> _chips(WidgetTester tester) =>
    tester.widgetList<GuChip>(find.byType(GuChip)).toList();

Future<void> _submit(WidgetTester tester) async {
  await tester.tap(find.byKey(RejectReasonSheet.submitKey));
  await tester.pumpAndSettle();
}

String _noteText(WidgetTester tester) => tester
    .widget<TextField>(find.byKey(RejectReasonSheet.noteKey))
    .controller!
    .text;

void main() {
  group('SHT-20 · Red nedeni', () {
    test('anahtarlar prototipteki aksiyon adlarıdır', () {
      expect(
        [for (final r in RejectReason.values) RejectReasonSheet.reasonKey(r)],
        [
          GuKey.action('SHT-20.reason.quota'),
          GuKey.action('SHT-20.reason.criteria'),
          GuKey.action('SHT-20.reason.missing'),
          GuKey.action('SHT-20.reason.other'),
        ],
      );
      expect(RejectReasonSheet.noteKey, GuKey.action('SHT-20.note'));
      expect(RejectReasonSheet.submitKey, GuKey.action('SHT-20.submit'));
    });

    testWidgets('gövde: ad, dört çip (kontenjan seçili), açıklama + yardım; '
        '"Reddet" danger; açıklamasız gönderim → (quota, null)', (
      tester,
    ) async {
      final h = _harness();
      await h.pump(tester);
      await h.open(tester);
      final l10n = tester.l10nFor(_tr);
      expect(find.text(l10n.sht20Title), findsOneWidget);
      expect(find.text(_name), findsOneWidget);
      expect(_chips(tester).map((c) => c.label), [
        l10n.rejectReasonQuota,
        l10n.rejectReasonCriteria,
        l10n.rejectReasonMissing,
        l10n.rejectReasonOther,
      ]);
      expect(_chips(tester).map((c) => c.selected), [
        true,
        false,
        false,
        false,
      ]);
      expect(find.text(l10n.sht20Note), findsOneWidget);
      expect(find.text(l10n.sht20Visible), findsOneWidget);
      final submit = tester.widget<GuButton>(
        find.byKey(RejectReasonSheet.submitKey),
      );
      expect(submit.variant, GuButtonVariant.danger);
      expect(submit.label, l10n.applicationsReject);
      await _submit(tester);
      expect(h.result, (RejectReason.quota, null));
    });

    testWidgets('neden seçimi + kırpılmış açıklama sonuca taşınır', (
      tester,
    ) async {
      final h = _harness();
      await h.pump(tester);
      await h.open(tester);
      await tester.tap(
        find.byKey(RejectReasonSheet.reasonKey(RejectReason.other)),
      );
      await tester.pumpAndSettle();
      expect(_chips(tester).map((c) => c.selected), [
        false,
        false,
        false,
        true,
      ]);
      await tester.enterText(
        find.byKey(RejectReasonSheet.noteKey),
        '  Lütfen dönem başında tekrar dene.  ',
      );
      await tester.pumpAndSettle();
      await _submit(tester);
      expect(h.result, (
        RejectReason.other,
        'Lütfen dönem başında tekrar dene.',
      ));
    });

    testWidgets('açıklama sınırı: 200 karakterden fazlası kesilir', (
      tester,
    ) async {
      final h = _harness();
      await h.pump(tester);
      await h.open(tester);
      await tester.enterText(
        find.byKey(RejectReasonSheet.noteKey),
        'a' * (Limits.rejectNoteMax + 25),
      );
      await tester.pumpAndSettle();
      expect(_noteText(tester).length, Limits.rejectNoteMax);
    });

    testWidgets('X → null (yazım yok)', (tester) async {
      final h = _harness();
      await h.pump(tester);
      await h.open(tester);
      await tester.tap(find.byKey(GuKey.action('SHT-20.close')));
      await tester.pumpAndSettle();
      expect(h.isClosed, isTrue);
      expect(h.result, isNull);
    });

    testWidgets('cihaz matrisi: taşma yok (klavye + güvenli alan)', (
      tester,
    ) async {
      await DeviceMatrix.run(
        tester,
        (context) => const Align(
          alignment: Alignment.bottomCenter,
          child: RejectReasonSheet(
            applicantName: 'Muhammed Burak Yıldırım Arslanoğlu',
          ),
        ),
        keyboard: true,
        safeAreas: true,
      );
    });

    testWidgets('golden: varsayılan (scrim dahil) — açık + koyu (TR)', (
      tester,
    ) async {
      for (final theme in kGoldenThemes) {
        final h = _harness();
        await h.pump(tester, theme: theme);
        await h.open(tester);
        await h.expectGolden(tester, 'SHT-20', theme);
      }
    });
  });
}
