// T-40 · DLG-29 İçerik kaldırılsın mı? (katalog: trash-2, danger; Kaldır →
// true, Vazgeç → false) · DLG-30 Kullanıcı askısı (`SuspendUserDialog`: neden
// zorunlu, sınır `Limits.adminReasonMax`, sayaç; askıdan çıkarmada girdi yok).
// Referans: design/reference-shots/dialogs/DLG-{29,30}__{light,dark}.webp;
// prototip dialogs.js:48–50.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/dialog_spec.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/dialogs/suspend_user_dialog.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/device_matrix.dart';
import 'dialog_test_support.dart';

const String _name = 'Nisa Yıldırım';
const String _longName =
    'Muhammed Abdurrahman Çağlayan Karaosmanoğlu Büyükçekmeceli';

void main() {
  final tr = lookupAppLocalizations(const Locale('tr'));

  group('DLG-29 · İçerik kaldırılsın mı? (katalog)', () {
    test('trash-2, yıkıcı; başlık / gövde; Kaldır / Vazgeç', () {
      final spec = DialogCatalog.of(DialogId.dlg29)!;
      expect(spec.icon, GuIcons.trash2);
      expect(spec.destructive, isTrue);
      expect(spec.title(tr, const {}), tr.dlg29Title);
      expect(spec.body!(tr, const {}), tr.dlg29Body);
      expect(spec.primaryLabel(tr, const {}), tr.dlg29Confirm);
    });

    testWidgets('Kaldır → true, Vazgeç → false, geri → null', (tester) async {
      final harness = DialogHarness();
      await harness.pump(tester);
      Future<bool?> open(FeedbackService s) =>
          s.showDialog<bool>(DialogId.dlg29);

      await harness.open<bool>(tester, open);
      expect(find.text('İçerik kaldırılsın mı?'), findsOneWidget);
      expect(find.text(tr.dlg29Body), findsOneWidget);
      await harness.tap(
        tester,
        DialogHarness.keyOf(DialogId.dlg29, 'confirm'),
      );
      expect(harness.result, isTrue);

      await harness.open<bool>(tester, open);
      await harness.tap(tester, DialogHarness.keyOf(DialogId.dlg29, 'cancel'));
      expect(harness.result, isFalse);

      await harness.open<bool>(tester, open);
      await harness.back(tester);
      expect(harness.result, isNull);
    });

    testWidgets('DLG-29 · golden (açık + koyu, TR)', (tester) async {
      await DialogHarness().golden<bool>(
        tester,
        'DLG-29',
        (s) => s.showDialog<bool>(DialogId.dlg29),
      );
    });
  });

  group('DLG-30 · Kullanıcı askısı', () {
    testWidgets('askıya alma: ban, danger; "Neden" çok satırlı, sınır '
        'adminReasonMax + sayaç; birincil "Askıya al"', (tester) async {
      final harness = DialogHarness();
      await harness.pump(tester);
      await harness.open<String>(
        tester,
        (s) => SuspendUserDialog.show(s, userName: _name, suspending: true),
      );
      expect(find.text(tr.dlg30Title(_name)), findsOneWidget);
      expect(find.text(tr.dlg30Body), findsOneWidget);
      final frame = tester.widget<GuDialogFrame>(find.byType(GuDialogFrame));
      expect(frame.icon, GuIcons.ban);
      expect(frame.danger, isTrue);
      final confirm = tester.widget<GuButton>(
        find.byKey(SuspendUserDialog.confirmKey),
      );
      expect(confirm.label, tr.adminUsersSuspend);
      expect(confirm.variant, GuButtonVariant.danger);
      final input = tester.widget<GuInput>(
        find.ancestor(
          of: find.byKey(SuspendUserDialog.reasonKey),
          matching: find.byType(GuInput),
        ),
      );
      expect(input.maxLength, Limits.adminReasonMax);
      expect(input.showCounter, isTrue);
      expect(input.multiline, isTrue);
    });

    testWidgets('neden zorunlu: boşken kapanmaz, "Bu alan zorunlu"; yazınca '
        'kırpılmış neden döner; Vazgeç / geri → null', (tester) async {
      final harness = DialogHarness();
      await harness.pump(tester);
      Future<String?> open(FeedbackService s) =>
          SuspendUserDialog.show(s, userName: _name, suspending: true);

      await harness.open<String>(tester, open);
      await tester.enterText(find.byKey(SuspendUserDialog.reasonKey), '   ');
      await harness.tap(tester, SuspendUserDialog.confirmKey);
      expect(harness.isClosed, isFalse);
      expect(find.text(tr.authErrRequired), findsOneWidget);

      await tester.enterText(
        find.byKey(SuspendUserDialog.reasonKey),
        '  sahte hesap  ',
      );
      await tester.pump();
      expect(find.text(tr.authErrRequired), findsNothing);
      await harness.tap(tester, SuspendUserDialog.confirmKey);
      expect(harness.result, 'sahte hesap');

      await harness.open<String>(tester, open);
      await harness.tap(tester, SuspendUserDialog.cancelKey);
      expect(harness.result, isNull);

      await harness.open<String>(tester, open);
      await harness.back(tester);
      expect(harness.result, isNull);
    });

    testWidgets('askıdan çıkarma: circle-check, girdi yok; "Askıyı kaldır" '
        '→ boş metin', (tester) async {
      final harness = DialogHarness();
      await harness.pump(tester);
      await harness.open<String>(
        tester,
        (s) => SuspendUserDialog.show(s, userName: _name, suspending: false),
      );
      expect(find.text(tr.dlg30TitleUnsuspend(_name)), findsOneWidget);
      expect(find.text(tr.dlg30BodyUnsuspend), findsOneWidget);
      expect(
        tester.widget<GuDialogFrame>(find.byType(GuDialogFrame)).icon,
        GuIcons.circleCheck,
      );
      expect(find.byKey(SuspendUserDialog.reasonKey), findsNothing);
      final confirm = tester.widget<GuButton>(
        find.byKey(SuspendUserDialog.confirmKey),
      );
      expect(confirm.label, tr.adminUsersUnsuspend);
      expect(confirm.variant, GuButtonVariant.primary);
      await harness.tap(tester, SuspendUserDialog.confirmKey);
      expect(harness.result, '');
    });

    testWidgets('cihaz matrisi: uzun ad, klavye açık — taşma yok', (
      tester,
    ) async {
      await DeviceMatrix.run(
        tester,
        (_) => const Center(
          child: SuspendUserDialog(userName: _longName, suspending: true),
        ),
        keyboard: true,
      );
    });

    testWidgets('DLG-30 · golden (açık + koyu, TR)', (tester) async {
      await DialogHarness().golden<String>(
        tester,
        'DLG-30',
        (s) => SuspendUserDialog.show(s, userName: _name, suspending: true),
      );
    });
  });
}
