// SHT-17 · Tema (`ThemeSheet`): üç seçenek kartı (Sistem / Açık / Koyu),
// seçili kart = tercih, anahtarlar (`SHT-17.select.system|light|dark`,
// `.close`), seçim → `AppPreferencesViewModel.setThemeMode` + kapanma.
// SET-01 · tercih kalıcılığı (roadmap T-28): tema (SHT-17) ve dil (SHT-01)
// seçimi depoya yazılır ve yeniden açılışta (yeni kapsayıcı) korunur.
// Cihaz matrisi, açık + koyu golden. Referans:
// design/reference-shots/sheets/SHT-17__light.webp, __dark.webp;
// prototip sheets.js:84–86.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_kulupler/features/settings/view/widget/theme_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/language_sheet.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/init/app_preferences_view_model.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../../fakes/fake_app_preferences_store.dart';
import '../../../../helpers/device_matrix.dart';
import '../../../../helpers/golden_helper.dart';
import '../../../../helpers/test_container.dart';
import '../../../../helpers/test_l10n.dart';
import '../../../clubs/view/widget/club_sheet_harness.dart';

FakeAppPreferencesStore _store() =>
    GetIt.I<AppPreferencesStore>() as FakeAppPreferencesStore;

Future<ClubSheetHarness<void>> _open(
  WidgetTester tester, {
  ThemeMode theme = ThemeMode.light,
  String? stored,
}) async {
  final h = ClubSheetHarness<void>(SheetId.sht17, (_) => const ThemeSheet());
  await h.pump(tester, theme: theme);
  if (stored != null) {
    _store().values[AppPreferenceKeys.themeMode] = stored;
    await ProviderScope.containerOf(
      h.navigatorKey.currentContext!,
    ).read(appPreferencesViewModelProvider.notifier).load();
  }
  await h.open(tester);
  return h;
}

void main() {
  group('SHT-17 · Tema · içerik', () {
    testWidgets('başlık, kapat, üç kart ekran sırasıyla; tercih yoksa '
        '"Sistem" seçili', (tester) async {
      await _open(tester);
      final l10n = tester.l10n;
      final frame = tester.widget<GuSheetFrame>(find.byType(GuSheetFrame));
      expect(frame.title, l10n.sht17Title);
      expect(frame.footer, isNull);
      expect(find.byKey(GuKey.action('SHT-17.close')), findsOneWidget);
      final cards = tester
          .widgetList<GuOptionCard>(find.byType(GuOptionCard))
          .toList();
      expect(cards.map((card) => card.key), [
        GuKey.action('SHT-17.select.system'),
        GuKey.action('SHT-17.select.light'),
        GuKey.action('SHT-17.select.dark'),
      ]);
      expect(cards.map((card) => card.semanticLabel), [
        l10n.themeSystem,
        l10n.themeLight,
        l10n.themeDark,
      ]);
      expect(cards.map((card) => card.selected), [true, false, false]);
    });

    testWidgets('kayıtlı tercih seçili kart olarak çizilir (koyu)', (
      tester,
    ) async {
      await _open(tester, stored: 'dark');
      final cards = tester.widgetList<GuOptionCard>(find.byType(GuOptionCard));
      expect(cards.map((card) => card.selected), [false, false, true]);
    });
  });

  group('SHT-17 · Tema · seçim', () {
    for (final mode in ThemeSheet.modes) {
      testWidgets('${mode.name} → tercih yazılır, sayfa kapanır', (
        tester,
      ) async {
        final h = await _open(tester);
        await tester.tap(find.byKey(ThemeSheet.keyOf(mode)));
        await tester.pumpAndSettle();
        expect(_store().values[AppPreferenceKeys.themeMode], mode.name);
        expect(h.isClosed, isTrue);
      });
    }
  });

  group('SET-01 · tercih kalıcılığı (yeniden açılış)', () {
    testWidgets('tema: SHT-17 "Koyu" → yeni oturumda koyu', (tester) async {
      await _open(tester);
      await tester.tap(find.byKey(ThemeSheet.keyOf(ThemeMode.dark)));
      await tester.pumpAndSettle();
      final reopened = createContainer();
      expect(
        reopened.read(appPreferencesViewModelProvider).themeMode,
        ThemeMode.dark,
      );
    });

    testWidgets('dil: SHT-01 "English" → yeni oturumda İngilizce', (
      tester,
    ) async {
      final h = ClubSheetHarness<void>(
        SheetId.sht01,
        (_) => const LanguageSheet(),
      );
      await h.pump(tester);
      await h.open(tester);
      await tester.tap(find.byKey(LanguageOptions.keyOf(const Locale('en'))));
      await tester.pumpAndSettle();
      expect(_store().values[AppPreferenceKeys.locale], 'en');
      final reopened = createContainer();
      expect(
        reopened.read(appPreferencesViewModelProvider).locale,
        const Locale('en'),
      );
    });
  });

  group('SHT-17 · Tema · cihaz matrisi ve golden', () {
    testWidgets('cihaz matrisi: taşma yok', (tester) async {
      await DeviceMatrix.run(
        tester,
        (context) => const Align(
          alignment: Alignment.bottomCenter,
          child: ThemeSheet(),
        ),
        safeAreas: true,
      );
    });

    testWidgets('golden: "Açık" seçili (scrim dahil) — açık + koyu (TR)', (
      tester,
    ) async {
      for (final theme in kGoldenThemes) {
        final h = await _open(tester, theme: theme, stored: 'light');
        await h.expectGolden(tester, 'SHT-17', theme);
      }
    });
  });
}
