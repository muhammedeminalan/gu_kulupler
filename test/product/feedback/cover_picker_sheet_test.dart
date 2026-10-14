// T-34 · SHT-31 · Kapak seç (`CoverPickerContent`): 16:9 önizleme + palet
// başına 4 şablon (palet adı görünür, "palet · desen" Semantics — CD-35),
// seçim halkası, "Kullan" → `CoverTemplatePicked`, "Deseni karıştır" tohumu
// değiştirir, "Galeriden seç" → SHT-16 → `CoverUploadPicked(kaynak)`, X →
// null, cihaz matrisi, açık + koyu golden. Referans:
// design/reference-shots/sheets/SHT-31__{light,dark}.webp; prototip
// sheets.js:144–148.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/cover_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/photo_source_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/service/image_picker_service.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../fakes/fake_feedback_service.dart';
import '../../helpers/device_matrix.dart';
import 'sheet_test_support.dart';

const String _seed = 'event-e01';

CoverPickerContent _content() => const CoverPickerContent(
  palette: ClubPalette.red,
  pattern: ClubPattern.mountain,
  seed: _seed,
  icon: GuIcons.mountain,
);

SheetHarness<CoverPickerResult> _harness() =>
    SheetHarness<CoverPickerResult>(SheetId.sht31, (_) => _content());

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

void main() {
  final tr = lookupAppLocalizations(const Locale('tr'));

  group('T-34 · SHT-31 · Kapak seç', () {
    test('anahtarlar prototipteki aksiyon adlarıdır', () {
      expect(
        CoverPickerContent.templateKeyOf(ClubPalette.slate, ClubPattern.dots),
        GuKey.action('SHT-31.template.slate.dots'),
      );
      expect(CoverPickerContent.keyOf('use'), GuKey.action('SHT-31.use'));
      expect(CoverPickerContent.palettes.toSet(), ClubPalette.values.toSet());
      expect(CoverPickerContent.patterns.toSet(), ClubPattern.values.toSet());
    });

    testWidgets('3 palet × 4 desen; açılış seçimi işaretli; palet adları', (
      tester,
    ) async {
      final h = _harness();
      await h.pump(tester);
      await h.open(tester);
      expect(find.text(tr.sht31Title), findsOneWidget);
      for (final name in [
        tr.coverPaletteRed,
        tr.coverPaletteSlate,
        tr.coverPaletteBordeaux,
      ]) {
        expect(find.text(name), findsOneWidget);
      }
      for (final palette in CoverPickerContent.palettes) {
        for (final pattern in CoverPickerContent.patterns) {
          final key = CoverPickerContent.templateKeyOf(palette, pattern);
          expect(find.byKey(key), findsOneWidget);
          final surface = tester.widget<GuActionSurface>(find.byKey(key));
          expect(
            surface.selected,
            palette == ClubPalette.red && pattern == ClubPattern.mountain,
          );
        }
      }
      expect(
        tester
            .widget<GuActionSurface>(
              find.byKey(
                CoverPickerContent.templateKeyOf(
                  ClubPalette.bordeaux,
                  ClubPattern.waves,
                ),
              ),
            )
            .semanticLabel,
        '${tr.coverPaletteBordeaux} · ${tr.coverPatternWaves}',
      );
    });

    testWidgets('şablon seç → Kullan → CoverTemplatePicked (tohum aynı)', (
      tester,
    ) async {
      final h = _harness();
      await h.pump(tester);
      await h.open(tester);
      await _tap(
        tester,
        CoverPickerContent.templateKeyOf(ClubPalette.slate, ClubPattern.dots),
      );
      await _tap(tester, CoverPickerContent.keyOf('use'));
      expect(
        h.result,
        const CoverTemplatePicked(
          palette: ClubPalette.slate,
          pattern: ClubPattern.dots,
          seed: _seed,
        ),
      );
    });

    testWidgets('Deseni karıştır tohumu değiştirir', (tester) async {
      final h = _harness();
      await h.pump(tester);
      await h.open(tester);
      await _tap(tester, CoverPickerContent.keyOf('shuffle'));
      await _tap(tester, CoverPickerContent.keyOf('use'));
      final result = h.result! as CoverTemplatePicked;
      expect(result.palette, ClubPalette.red);
      expect(result.seed, isNot(_seed));
      expect(result.seed, startsWith('cover-'));
    });

    testWidgets('Galeriden seç → SHT-16 galeri → CoverUploadPicked(gallery); '
        'SHT-16 kapanırsa açık kalır', (tester) async {
      final h = _harness();
      await h.pump(tester);
      await h.open(tester);
      final feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;

      await _tap(tester, CoverPickerContent.keyOf('gallery'));
      expect(feedback.sheets, [SheetId.sht16]);
      expect(h.isClosed, isFalse);

      feedback.nextSheetResult = PhotoSourceChoice.gallery;
      await _tap(tester, CoverPickerContent.keyOf('gallery'));
      expect(h.result, const CoverUploadPicked(MediaSource.gallery));
    });

    testWidgets('X → null', (tester) async {
      final h = _harness();
      await h.pump(tester);
      await h.open(tester);
      await tester.tap(find.byKey(CoverPickerContent.keyOf('close')));
      await tester.pumpAndSettle();
      expect(h.result, isNull);
    });

    testWidgets('cihaz matrisi: taşma yok (güvenli alan)', (tester) async {
      await DeviceMatrix.run(
        tester,
        (_) => Align(alignment: Alignment.bottomCenter, child: _content()),
        safeAreas: true,
      );
    });

    testWidgets('golden: Kırmızı · Dağ seçili (scrim dahil) — açık + koyu', (
      tester,
    ) async {
      await _harness().golden(tester, 'SHT-31');
    });
  });
}
