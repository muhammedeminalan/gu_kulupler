// SHT-24 · Tarama sonucu — üç sonuç (Geçerli bilet: başarı ikonu, sahibi,
// "Katıldı olarak işaretlendi.", sayaç; Zaten okutulmuş: uyarı ikonu,
// önceki okutma saati; Geçersiz bilet: tehlike ikonu, sahibi yok), "Sonraki
// bilet" → next, geçerli sonuç 2 sn sonra kendiliğinden kapanır
// (`AppDurations.qrSuccessAutoClose`), "Geri al" yalnızca istenirse;
// geçersiz nedenleri (okunamadı / pencere dışı) + "Okutan"; golden (üç sonuç,
// açık + koyu). Kaynak: sheets.js:113–116;
// design/reference-shots/sheets/SHT-24__*.webp.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/constants/app_durations.dart';
import 'package:gu_kulupler/features/management/view/widget/scan_result_sheet.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../fixtures/user_model_fixtures.dart';
import '../../../../helpers/golden_helper.dart';
import '../../../../helpers/test_l10n.dart';
import '../../../clubs/view/widget/club_sheet_harness.dart';

const Locale _tr = Locale('tr');

final UserModel _mehmet = UserModelFixtures.byId('u_mehmet');

ClubSheetHarness<ScanResultSheetAction> _harness(ScanResultSheet sheet) =>
    ClubSheetHarness<ScanResultSheetAction>(SheetId.sht24, (_) => sheet);

GuIconBox _icon(WidgetTester tester) =>
    tester.widget<GuIconBox>(find.byType(GuIconBox));

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  group('SHT-24 · Tarama sonucu', () {
    test('anahtarlar prototipteki aksiyon adlarıdır', () {
      expect(ScanResultSheet.nextKey, GuKey.action('SHT-24.next'));
      expect(ScanResultSheet.undoKey, GuKey.action('SHT-24.undo'));
      expect(ScanResultSheet.closeKey, GuKey.action('SHT-24.close'));
    });

    testWidgets('Geçerli bilet: başarı ikonu, sahibi, açıklama, sayaç; '
        '"Geri al" yok; 2 sn sonra kendiliğinden kapanır (next)', (
      tester,
    ) async {
      final h = _harness(
        ScanResultSheet(
          outcome: ScanOutcome.valid,
          user: _mehmet,
          counter: (attended: 0, registered: 36),
        ),
      );
      await h.pump(tester);
      await h.open(tester);
      final l10n = tester.l10nFor(_tr);
      expect(find.text(l10n.sht24Valid), findsOneWidget);
      expect(_icon(tester).icon, GuIcons.circleCheck);
      expect(_icon(tester).tone, GuIconBoxTone.success);
      expect(_icon(tester).size, GuSizes.notifIconLg);
      expect(find.byType(GuAvatar), findsOneWidget);
      expect(find.text(_mehmet.name), findsOneWidget);
      expect(find.text(l10n.sht24ValidDesc), findsOneWidget);
      expect(find.text(l10n.scanCounter('0', '36')), findsOneWidget);
      expect(find.byKey(ScanResultSheet.undoKey), findsNothing);
      expect(h.isClosed, isFalse);

      await tester.pump(AppDurations.qrSuccessAutoClose);
      await tester.pumpAndSettle();
      expect(h.result, ScanResultSheetAction.next);
    });

    testWidgets('Zaten okutulmuş: uyarı ikonu + önceki okutma saati '
        '(İstanbul); kendiliğinden kapanmaz; "Sonraki bilet" → next', (
      tester,
    ) async {
      final h = _harness(
        ScanResultSheet(
          outcome: ScanOutcome.alreadyScanned,
          user: _mehmet,
          scannedAt: DateTime.utc(2026, 10, 8, 16, 44),
        ),
      );
      await h.pump(tester);
      await h.open(tester);
      final l10n = tester.l10nFor(_tr);
      expect(find.text(l10n.sht24Used), findsOneWidget);
      expect(_icon(tester).icon, GuIcons.checkCheck);
      expect(_icon(tester).tone, GuIconBoxTone.warning);
      expect(find.text(l10n.sht24UsedDesc('19:44')), findsOneWidget);
      expect(find.text(l10n.scanCounter('0', '36')), findsNothing);

      await tester.pump(AppDurations.qrSuccessAutoClose);
      await tester.pumpAndSettle();
      expect(h.isClosed, isFalse);
      await tester.tap(find.byKey(ScanResultSheet.nextKey));
      await tester.pumpAndSettle();
      expect(h.result, ScanResultSheetAction.next);
    });

    testWidgets('Geçersiz bilet: tehlike ikonu, sahibi yok, "Bu bilet bu '
        'etkinliğe ait değil."; X → null', (tester) async {
      final h = _harness(const ScanResultSheet(outcome: ScanOutcome.invalid));
      await h.pump(tester);
      await h.open(tester);
      final l10n = tester.l10nFor(_tr);
      expect(find.text(l10n.sht24Invalid), findsOneWidget);
      expect(_icon(tester).icon, GuIcons.circleX);
      expect(_icon(tester).tone, GuIconBoxTone.danger);
      expect(find.byType(GuAvatar), findsNothing);
      expect(find.text(l10n.sht24InvalidDesc), findsOneWidget);
      await tester.tap(find.byKey(ScanResultSheet.closeKey));
      await tester.pumpAndSettle();
      expect(h.result, isNull);
    });

    testWidgets('"Geri al" yalnızca showUndo + geçerli sonuçta → undo', (
      tester,
    ) async {
      final h = _harness(
        const ScanResultSheet(outcome: ScanOutcome.valid, showUndo: true),
      );
      await h.pump(tester);
      await h.open(tester);
      await tester.tap(find.byKey(ScanResultSheet.undoKey));
      await tester.pumpAndSettle();
      expect(h.result, ScanResultSheetAction.undo);
    });

    testWidgets('geçersiz nedenleri: okunamadı / pencere dışı metni; zaten '
        'okutulmuşta "Okutan: …"', (tester) async {
      final l10n = tester.l10nFor(_tr);
      for (final (sheet, text) in [
        (
          const ScanResultSheet(
            outcome: ScanOutcome.invalid,
            invalidReason: ScanInvalidReason.unreadable,
          ),
          l10n.sht24Unreadable,
        ),
        (
          const ScanResultSheet(
            outcome: ScanOutcome.invalid,
            invalidReason: ScanInvalidReason.windowClosed,
          ),
          l10n.sht24WindowClosed(2, 6),
        ),
        (
          ScanResultSheet(
            outcome: ScanOutcome.alreadyScanned,
            user: _mehmet,
            scannedAt: DateTime.utc(2026, 10, 8, 16, 44),
            scannedByName: 'Elif Kaya',
          ),
          l10n.sht24ScannedBy('Elif Kaya'),
        ),
      ]) {
        final h = _harness(sheet);
        await h.pump(tester);
        await h.open(tester);
        expect(find.text(text), findsOneWidget);
        await tester.tap(find.byKey(ScanResultSheet.closeKey));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('golden: Zaten okutulmuş + Geçersiz — açık + koyu (TR)', (
      tester,
    ) async {
      for (final theme in kGoldenThemes) {
        for (final (name, sheet) in [
          (
            'SHT-24_used',
            ScanResultSheet(
              outcome: ScanOutcome.alreadyScanned,
              user: _mehmet,
              scannedAt: DateTime.utc(2026, 10, 8, 16, 44),
            ),
          ),
          (
            'SHT-24_invalid',
            const ScanResultSheet(outcome: ScanOutcome.invalid),
          ),
        ]) {
          final h = _harness(sheet);
          await h.pump(tester, theme: theme);
          await h.open(tester);
          await h.expectGolden(tester, name, theme);
        }
      }
    });

    testWidgets('golden: Geçerli bilet — açık + koyu (TR)', (tester) async {
      for (final theme in kGoldenThemes) {
        final h = _harness(
          ScanResultSheet(
            outcome: ScanOutcome.valid,
            user: _mehmet,
            counter: (attended: 0, registered: 36),
          ),
        );
        await h.pump(tester, theme: theme);
        await h.open(tester);
        await h.expectGolden(tester, 'SHT-24', theme);
        await tester.pump(AppDurations.qrSuccessAutoClose);
        await tester.pumpAndSettle();
      }
    });
  });
}
