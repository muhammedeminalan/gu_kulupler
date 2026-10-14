// T-34 · DLG-22 Etkinlik yayınlansın mı? (`PublishEventDialog`: "{n} üyeye
// bildirim gönder" kutusu, sonuç bildirim seçimi / `null`) · DLG-23 Etkinlik
// iptal edilsin mi? (`CancelEventDialog`: dört neden, neden zorunlu, sonuç
// neden kimliği / `null`) · DLG-31 Taslak silinsin mi? (katalog: trash-2,
// danger, Sil / Vazgeç). Referans:
// design/reference-shots/dialogs/DLG-{22,23,31}__{light,dark}.webp; prototip
// dialogs.js:39–41, 51.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/dialog_spec.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/dialogs/cancel_event_dialog.dart';
import 'package:gu_kulupler/product/feedback/dialogs/publish_event_dialog.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_ui/gu_ui.dart';

import 'dialog_test_support.dart';

void main() {
  final tr = lookupAppLocalizations(const Locale('tr'));

  group('DLG-22 · Etkinlik yayınlansın mı?', () {
    testWidgets('çizim: calendar-check, gövde, "24 üyeye bildirim gönder" '
        'işaretli; Yayınla → true, kutu kaldırılınca false; geri dön → null', (
      tester,
    ) async {
      final harness = DialogHarness();
      await harness.pump(tester);
      Future<bool?> open(FeedbackService s) =>
          PublishEventDialog.show(s, count: 24);

      await harness.open<bool>(tester, open);
      expect(find.text(tr.dlg22Title), findsOneWidget);
      expect(find.text(tr.dlg22Body), findsOneWidget);
      expect(find.text(tr.dlg22Notify(24)), findsOneWidget);
      final frame = tester.widget<GuDialogFrame>(find.byType(GuDialogFrame));
      expect(frame.icon, GuIcons.calendarCheck);
      expect(frame.danger, isFalse);
      expect(
        tester
            .widget<GuCheckbox>(find.byKey(PublishEventDialog.notifyKey))
            .value,
        isTrue,
      );
      await harness.tap(tester, PublishEventDialog.confirmKey);
      expect(harness.result, isTrue);

      await harness.open<bool>(tester, open);
      await tester.tap(find.text(tr.dlg22Notify(24)));
      await tester.pump();
      await harness.tap(tester, PublishEventDialog.confirmKey);
      expect(harness.result, isFalse);

      await harness.open<bool>(tester, open);
      await harness.tap(tester, PublishEventDialog.cancelKey);
      expect(harness.result, isNull);
    });

    testWidgets('golden (açık + koyu, TR)', (tester) async {
      await DialogHarness().golden<bool>(
        tester,
        'DLG-22',
        (s) => PublishEventDialog.show(s, count: 24),
      );
    });
  });

  group('DLG-23 · Etkinlik iptal edilsin mi?', () {
    testWidgets('dört neden; neden seçilmeden onay → "Bu alan zorunlu"; seçim '
        '→ neden kimliği; Vazgeç → null', (tester) async {
      final harness = DialogHarness();
      await harness.pump(tester);
      Future<String?> open(FeedbackService s) =>
          CancelEventDialog.show(s, count: 30);

      await harness.open<String>(tester, open);
      expect(find.text(tr.dlg23Body(30)), findsOneWidget);
      expect(find.byType(GuOptionRow), findsNWidgets(4));
      final frame = tester.widget<GuDialogFrame>(find.byType(GuDialogFrame));
      expect(frame.icon, GuIcons.calendarX);
      expect(frame.danger, isTrue);
      await harness.tap(tester, CancelEventDialog.confirmKey);
      expect(harness.isClosed, isFalse);
      expect(find.text(tr.authErrRequired), findsOneWidget);

      await harness.tap(tester, CancelEventDialog.reasonKey('speaker'));
      expect(find.text(tr.authErrRequired), findsNothing);
      await harness.tap(tester, CancelEventDialog.confirmKey);
      expect(harness.result, 'speaker');

      await harness.open<String>(tester, open);
      await harness.tap(tester, CancelEventDialog.cancelKey);
      expect(harness.result, isNull);
    });

    testWidgets('golden (açık + koyu, TR)', (tester) async {
      await DialogHarness().golden<String>(
        tester,
        'DLG-23',
        (s) => CancelEventDialog.show(s, count: 30),
      );
    });
  });

  group('DLG-31 · Taslak silinsin mi? (katalog)', () {
    test('trash-2, danger; Sil / Vazgeç', () {
      final spec = DialogCatalog.of(DialogId.dlg31)!;
      expect(spec.icon, GuIcons.trash2);
      expect(spec.destructive, isTrue);
      expect(spec.isPrimaryDangerFor(const {}), isTrue);
      expect(spec.title(tr, const {}), tr.dlg31Title);
      expect(spec.body!(tr, const {}), tr.dlg31Body);
      expect(spec.primaryLabel(tr, const {}), tr.commonDelete);
      expect(spec.secondaryLabel(tr, const {}), tr.commonGiveUp);
    });

    testWidgets('Sil → true, Vazgeç → false', (tester) async {
      final harness = DialogHarness();
      await harness.pump(tester);
      await harness.open<bool>(
        tester,
        (s) => s.showDialog<bool>(DialogId.dlg31),
      );
      await harness.tap(tester, GuKey.action('DLG-31.confirm'));
      expect(harness.result, isTrue);
      await harness.open<bool>(
        tester,
        (s) => s.showDialog<bool>(DialogId.dlg31),
      );
      await harness.tap(tester, GuKey.action('DLG-31.cancel'));
      expect(harness.result, isFalse);
    });

    testWidgets('golden (açık + koyu, TR)', (tester) async {
      await DialogHarness().golden<bool>(
        tester,
        'DLG-31',
        (s) => s.showDialog<bool>(DialogId.dlg31),
      );
    });
  });
}
