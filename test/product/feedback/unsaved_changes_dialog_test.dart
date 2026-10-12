// DLG-25 · Değişiklikler kaydedilmedi — `UnsavedChangesDialog`: çizim (ikon,
// başlık, gövde, üç eylem; "Kaydet" yalnızca `hasSave` ise), anahtarlar
// (`DLG-25.save` / `.discard` / `.keep` / `.scrim`), sonuçlar, dar ekran +
// büyük metin taşması ve golden.
// Referans: design/reference-shots/dialogs/DLG-25__{light,dark}.webp; prototip
// dialogs.js:43.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/dialog_spec.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/mixin/unsaved_changes_mixin.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../fakes/fake_feedback_service.dart';
import '../../helpers/test_l10n.dart';
import 'dialog_test_support.dart';

Key _key(String action) => DialogHarness.keyOf(DialogId.dlg25, action);

void main() {
  group('DLG-25 · Değişiklikler kaydedilmedi · açılış', () {
    test('katalog kaydı yoktur (üç eylem): kurucuyla açılır', () {
      expect(DialogCatalog.of(DialogId.dlg25), isNull);
      expect(DialogCatalog.ids, isNot(contains(DialogId.dlg25)));
    });

    test('showUnsavedChangesDialog: DLG-25 kimliğiyle, özel gövdeyle açar ve '
        'sonucu döndürür', () async {
      final feedback = FakeFeedbackService()
        ..nextDialogResult = UnsavedChangesResult.discard;

      final result = await showUnsavedChangesDialog(feedback);

      expect(result, UnsavedChangesResult.discard);
      expect(feedback.dialogs, [DialogId.dlg25]);
      expect(feedback.lastDialogBuilder, isNotNull);
      expect(await showUnsavedChangesDialog(feedback), isNull);
    });
  });

  group('DLG-25 · Değişiklikler kaydedilmedi · gösterim', () {
    Future<void> open(
      WidgetTester tester,
      DialogHarness harness, {
      required bool hasSave,
    }) => harness.open<UnsavedChangesResult>(
      tester,
      (s) => showUnsavedChangesDialog(s, hasSave: hasSave),
    );

    testWidgets('çizim (Kaydet ile): uyarı ikonu (brand kutu), başlık, gövde; '
        'Kaydet birincil → Kaydetmeden çık dangerOutline → Düzenlemeye devam '
        'et metin; yukarıdan aşağı — açık + koyu, TR + EN', (tester) async {
      final harness = DialogHarness();
      for (final theme in [ThemeMode.light, ThemeMode.dark]) {
        for (final locale in AppLocalizations.supportedLocales) {
          await harness.pump(tester, locale: locale, theme: theme);
          await open(tester, harness, hasSave: true);
          final l10n = tester.l10nFor(locale);

          final frame = tester.widget<GuDialogFrame>(
            find.byType(GuDialogFrame),
          );
          expect(frame.title, l10n.dlg25Title);
          expect(frame.body, l10n.dlg25Body);
          expect(frame.icon, GuIcons.triangleAlert);
          expect(frame.danger, isFalse);
          expect(frame.dismissable, isTrue);
          expect(frame.actionsLayout, GuDialogActionsLayout.column);
          expect(
            tester.widget<GuIconBox>(find.byType(GuIconBox)).tone,
            GuIconBoxTone.brand,
          );

          final save = tester.widget<GuButton>(find.byKey(_key('save')));
          expect(save.label, l10n.commonSave);
          expect(save.variant, GuButtonVariant.primary);
          final discard = tester.widget<GuButton>(find.byKey(_key('discard')));
          expect(discard.label, l10n.dlg25Discard);
          expect(discard.variant, GuButtonVariant.dangerOutline);
          final keep = tester.widget<GuButton>(find.byKey(_key('keep')));
          expect(keep.label, l10n.dlg25Keep);
          expect(keep.variant, GuButtonVariant.text);
          expect(find.byType(GuButton), findsNWidgets(3));

          final tops = [
            for (final action in ['save', 'discard', 'keep'])
              tester.getRect(find.byKey(_key(action))),
          ];
          expect(tops[0].bottom, lessThanOrEqualTo(tops[1].top));
          expect(tops[1].bottom, lessThanOrEqualTo(tops[2].top));
          // Üç düğme de tam genişlik (css:284 `.dialog-actions`).
          expect(tops.map((rect) => rect.width).toSet(), hasLength(1));
          expect(find.byKey(_key('scrim')), findsOneWidget);
        }
      }
    });

    testWidgets('Kaydet yokken (hasSave: false — AUT-05, ADM-03, kirli '
        'sheet) yalnızca iki eylem çizilir', (tester) async {
      final harness = DialogHarness();
      await harness.pump(tester);
      await open(tester, harness, hasSave: false);

      expect(find.byKey(_key('save')), findsNothing);
      expect(find.byKey(_key('discard')), findsOneWidget);
      expect(find.byKey(_key('keep')), findsOneWidget);
      expect(find.byType(GuButton), findsNWidgets(2));
      expect(
        tester.widget<GuButton>(find.byKey(_key('discard'))).variant,
        GuButtonVariant.dangerOutline,
      );
    });

    testWidgets('sonuçlar: save / discard / keep kendi değeriyle; scrim ve '
        'geri null (düzenlemeye devam)', (tester) async {
      final harness = DialogHarness();
      await harness.pump(tester);
      for (final result in UnsavedChangesResult.values) {
        await open(tester, harness, hasSave: true);
        expect(harness.isClosed, isFalse);

        await harness.tap(tester, _key(result.name));

        expect(harness.isClosed, isTrue, reason: result.name);
        expect(harness.result, result);
        expect(find.byType(GuDialogFrame), findsNothing);
      }

      await open(tester, harness, hasSave: true);
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      expect(harness.result, isNull);

      await open(tester, harness, hasSave: true);
      await harness.back(tester);
      expect(harness.result, isNull);
    });

    testWidgets('320 dp + metin ölçeği 1.6, TR + EN: taşma yok (taşma testi '
        'düşürür), üç düğme dokunulabilir boyutta ve ekran içinde', (
      tester,
    ) async {
      final harness = DialogHarness();
      const size = Size(320, 568);
      for (final locale in AppLocalizations.supportedLocales) {
        await harness.pump(
          tester,
          locale: locale,
          size: size,
          textScale: 1.6,
        );
        await open(tester, harness, hasSave: true);
        for (final action in ['save', 'discard', 'keep']) {
          await tester.ensureVisible(find.byKey(_key(action)));
          final rect = tester.getRect(find.byKey(_key(action)));
          expect(rect.height, greaterThanOrEqualTo(44), reason: action);
          expect(rect.left, greaterThanOrEqualTo(0), reason: action);
          expect(rect.right, lessThanOrEqualTo(size.width), reason: action);
        }
        await harness.back(tester);
      }
    });

    testWidgets('golden: Kaydet ile (açık + koyu, TR)', (tester) async {
      await DialogHarness().golden<UnsavedChangesResult>(
        tester,
        'DLG-25',
        (s) => showUnsavedChangesDialog(s, hasSave: true),
      );
    });

    testWidgets('golden: Kaydet olmadan (açık + koyu, TR)', (tester) async {
      await DialogHarness().golden<UnsavedChangesResult>(
        tester,
        'DLG-25__nosave',
        showUnsavedChangesDialog,
      );
    });
  });
}
