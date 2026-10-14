// DLG-17 · Toplu işlem onayı · DLG-18 · Başvuru zaten sonuçlandırıldı (iki
// yönetici çakışması) — katalog kayıtları (ikon, tür / karar değişkenleri,
// birincil düğme metni ve tonu) ve gerçek `FeedbackService` üzerinden
// gösterim (anahtarlar, sonuçlar). Referans:
// design/reference-shots/dialogs/DLG-1{7,8}__{light,dark}.webp; prototip
// dialogs.js:33–34.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/dialog_spec.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_ui/gu_ui.dart';

import 'dialog_test_support.dart';

void main() {
  final tr = lookupAppLocalizations(const Locale('tr'));
  final en = lookupAppLocalizations(const Locale('en'));

  group('DLG-17 / DLG-18 · katalog', () {
    test('DLG-17: list-checks; tür → gövde + birincil düğme (ret danger)', () {
      final spec = DialogCatalog.of(DialogId.dlg17)!;
      expect(spec.icon, GuIcons.listChecks);
      expect(spec.destructive, isFalse);
      expect(spec.title(tr, const {}), tr.dlg17Title);
      expect(spec.secondaryLabel(tr, const {}), tr.commonGiveUp);
      for (final (kind, body, label, danger) in [
        (BulkActionKind.approve, tr.dlg17Approve(3), tr.commonConfirm, false),
        (BulkActionKind.reject, tr.dlg17Reject(3), tr.applicationsReject, true),
        (
          BulkActionKind.attendance,
          tr.dlg17Attendance(3),
          tr.commonConfirm,
          false,
        ),
      ]) {
        final params = {DialogParamKeys.kind: kind, DialogParamKeys.count: 3};
        expect(spec.body!(tr, params), body, reason: kind.name);
        expect(spec.primaryLabel(tr, params), label, reason: kind.name);
        expect(spec.isPrimaryDangerFor(params), danger, reason: kind.name);
      }
      // Tür verilmezse onay (`p.kind || 'approve'`), sayı verilmezse 0.
      expect(spec.body!(tr, const {}), tr.dlg17Approve(0));
      expect(spec.primaryLabel(tr, const {}), tr.commonConfirm);
      expect(spec.isPrimaryDangerFor(const {}), isFalse);
    });

    test('DLG-18: refresh-cw; gövde diğer yöneticinin kararını küçük harfle '
        'taşır (TR / EN); tek "Tamam"', () {
      final spec = DialogCatalog.of(DialogId.dlg18)!;
      expect(spec.icon, GuIcons.refreshCw);
      expect(spec.title(tr, const {}), tr.dlg18Title);
      expect(
        spec.body!(tr, const {
          DialogParamKeys.result: MembershipStatus.rejected,
        }),
        tr.dlg18Body('reddedildi'),
      );
      expect(
        spec.body!(tr, const {DialogParamKeys.result: MembershipStatus.active}),
        tr.dlg18Body('onaylandı'),
      );
      expect(
        spec.body!(en, const {DialogParamKeys.result: MembershipStatus.active}),
        en.dlg18Body('approved'),
      );
      expect(spec.body!(tr, const {}), tr.dlg18Body('reddedildi'));
      expect(spec.primaryLabel(tr, const {}), tr.commonOk);
      expect(spec.secondaryLabel(tr, const {}), isNull);
      expect(spec.primaryAction, 'ok');
      expect(spec.isPrimaryDangerFor(const {}), isFalse);
    });
  });

  group('DLG-17 / DLG-18 · gösterim (FeedbackService)', () {
    testWidgets('DLG-17 ret: "Reddet" danger → true; "Vazgeç" → false', (
      tester,
    ) async {
      final harness = DialogHarness();
      await harness.pump(tester);
      const params = {
        DialogParamKeys.kind: BulkActionKind.reject,
        DialogParamKeys.count: 2,
      };
      await harness.open<bool>(
        tester,
        (s) => s.showDialog<bool>(DialogId.dlg17, params: params),
      );
      expect(find.text(tr.dlg17Reject(2)), findsOneWidget);
      final confirm = tester.widget<GuButton>(
        find.byKey(DialogHarness.keyOf(DialogId.dlg17, 'confirm')),
      );
      expect(confirm.label, tr.applicationsReject);
      expect(confirm.variant, GuButtonVariant.danger);
      await harness.tap(tester, DialogHarness.keyOf(DialogId.dlg17, 'confirm'));
      expect(harness.result, isTrue);

      await harness.open<bool>(
        tester,
        (s) => s.showDialog<bool>(
          DialogId.dlg17,
          params: const {DialogParamKeys.count: 3},
        ),
      );
      expect(find.text(tr.dlg17Approve(3)), findsOneWidget);
      expect(
        tester
            .widget<GuButton>(
              find.byKey(DialogHarness.keyOf(DialogId.dlg17, 'confirm')),
            )
            .variant,
        GuButtonVariant.primary,
      );
      await harness.tap(tester, DialogHarness.keyOf(DialogId.dlg17, 'cancel'));
      expect(harness.result, isFalse);
    });

    testWidgets('DLG-18 "Tamam" → true', (tester) async {
      final harness = DialogHarness();
      await harness.pump(tester);
      await harness.open<bool>(
        tester,
        (s) => s.showDialog<bool>(
          DialogId.dlg18,
          params: const {DialogParamKeys.result: MembershipStatus.rejected},
        ),
      );
      expect(find.text(tr.dlg18Title), findsOneWidget);
      expect(find.text(tr.dlg18Body('reddedildi')), findsOneWidget);
      await harness.tap(tester, DialogHarness.keyOf(DialogId.dlg18, 'ok'));
      expect(harness.result, isTrue);
    });
  });
}
