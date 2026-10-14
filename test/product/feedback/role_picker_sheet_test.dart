// T-33 · SHT-22 · Rol seç (`RolePickerSheet`): iki seçenek (member / board;
// başkan ve danışman seçilemez), mevcut rol işaretli, değişmemişken "Kaydet"
// devre dışı → TST-X9, seçilen rol ile `pop`, X → null, anahtarlar, cihaz
// matrisi, açık + koyu golden. Referans:
// design/reference-shots/sheets/SHT-22__{light,dark}.webp; prototip
// sheets.js:105–107.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/role_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../fakes/fake_feedback_service.dart';
import '../../helpers/device_matrix.dart';
import 'sheet_test_support.dart';

SheetHarness<ClubRole> _harness(ClubRole current) => SheetHarness<ClubRole>(
  SheetId.sht22,
  (_) => RolePickerSheet(currentRole: current),
);

GuButton _save(WidgetTester tester) =>
    tester.widget<GuButton>(find.byKey(RolePickerSheet.saveKey));

void main() {
  final tr = lookupAppLocalizations(const Locale('tr'));

  group('SHT-22 · Rol seç', () {
    test(
      'anahtarlar prototipteki aksiyon adlarıdır; yalnız member / board',
      () {
        expect(RolePickerSheet.options, [ClubRole.member, ClubRole.board]);
        expect(
          RolePickerSheet.roleKey(ClubRole.member),
          GuKey.action('SHT-22.role.member'),
        );
        expect(
          RolePickerSheet.roleKey(ClubRole.board),
          GuKey.action('SHT-22.role.board'),
        );
        expect(RolePickerSheet.saveKey, GuKey.action('SHT-22.save'));
      },
    );

    testWidgets('mevcut rol seçili, açıklamalar + not; değişmemişken Kaydet '
        'devre dışı → TST-X9, kapanmaz', (tester) async {
      final h = _harness(ClubRole.member);
      await h.pump(tester);
      await h.open(tester);
      expect(find.text(tr.sht22Title), findsOneWidget);
      expect(find.text(tr.sht22Member), findsOneWidget);
      expect(find.text(tr.sht22Board), findsOneWidget);
      expect(find.text(tr.sht22TransferNote), findsOneWidget);
      final cards = tester.widgetList<GuOptionCard>(find.byType(GuOptionCard));
      expect(cards.map((c) => c.selected), [true, false]);
      expect(_save(tester).disabled, isTrue);

      await tester.tap(find.byKey(RolePickerSheet.saveKey));
      await tester.pumpAndSettle();
      expect(h.isClosed, isFalse);
      expect(
        (GetIt.I<FeedbackService>() as FakeFeedbackService).toasts,
        [ToastId.tstX9],
      );
    });

    testWidgets(
      'board seç → Kaydet → pop(board); geri seçince yine devre dışı',
      (tester) async {
        final h = _harness(ClubRole.member);
        await h.pump(tester);
        await h.open(tester);
        await tester.tap(find.byKey(RolePickerSheet.roleKey(ClubRole.board)));
        await tester.pump();
        expect(_save(tester).disabled, isFalse);
        await tester.tap(find.byKey(RolePickerSheet.roleKey(ClubRole.member)));
        await tester.pump();
        expect(_save(tester).disabled, isTrue);
        await tester.tap(find.byKey(RolePickerSheet.roleKey(ClubRole.board)));
        await tester.pump();
        await tester.tap(find.byKey(RolePickerSheet.saveKey));
        await tester.pumpAndSettle();
        expect(h.result, ClubRole.board);
      },
    );

    testWidgets('X → null', (tester) async {
      final h = _harness(ClubRole.board);
      await h.pump(tester);
      await h.open(tester);
      await tester.tap(find.byKey(GuKey.action('SHT-22.close')));
      await tester.pumpAndSettle();
      expect(h.result, isNull);
    });

    testWidgets('cihaz matrisi: taşma yok (güvenli alan)', (tester) async {
      await DeviceMatrix.run(
        tester,
        (_) => const Align(
          alignment: Alignment.bottomCenter,
          child: RolePickerSheet(currentRole: ClubRole.member),
        ),
        safeAreas: true,
      );
    });

    testWidgets('golden: üye seçili (scrim dahil) — açık + koyu (TR)', (
      tester,
    ) async {
      await _harness(ClubRole.member).golden(tester, 'SHT-22');
    });
  });
}
