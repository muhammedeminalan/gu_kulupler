// SHT-01 · Dil — tek gövde `LanguageOptions` (CD-113): alt sayfa biçimi
// (`LanguageSheet`; SET-01) ve açılır menü biçimi (ONB-01 / AUT-01 / AUT-02).
// Seçenekler, seçili işareti, anahtarlar (`SHT-01.select.tr|en`, `.close`,
// `.scrim`), seçim → `AppPreferencesViewModel.setLocale` + kapanma.
// Referans: design/reference-shots/sheets/SHT-01__light.webp, __dark.webp;
// prototip sheets.js:10–11.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/language_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/menu_id.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/init/app_preferences_view_model.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../fakes/fake_app_preferences_store.dart';
import '../../helpers/design_files.dart';
import '../../helpers/device_matrix.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/test_l10n.dart';

const Locale _tr = Locale('tr');
const Locale _en = Locale('en');

Key _key(String action) => FeedbackKeys.of(SheetId.sht01.designId, action);

/// Gerçek `AppFeedbackService` + kendi gezgini: overlay gerçekten çizilir.
class _Harness {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final GuToastController controller = GuToastController();
  late final AppFeedbackService service = AppFeedbackService(
    navigatorKey: navigatorKey,
    toastController: controller,
  );

  Future<void> pump(
    WidgetTester tester, {
    Locale locale = _tr,
    ThemeMode theme = ThemeMode.light,
  }) async {
    addTearDown(controller.dispose);
    await tester.pumpApp(
      Navigator(
        key: navigatorKey,
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: SizedBox.expand()),
        ),
      ),
      locale: locale,
      theme: theme,
    );
  }

  Future<void> openSheet(WidgetTester tester) async {
    unawaited(
      service.showSheet<void>(
        SheetId.sht01,
        builder: (_) => const LanguageSheet(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester) async {
    unawaited(
      service.showMenu<void>(
        id: MenuId.sht01,
        scrimKey: _key('scrim'),
        items: const [LanguageOptions(variant: LanguageOptionsVariant.menu)],
      ),
    );
    await tester.pumpAndSettle();
  }

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(navigatorKey.currentContext!);
}

FakeAppPreferencesStore _store() =>
    GetIt.I<AppPreferencesStore>() as FakeAppPreferencesStore;

void main() {
  group('SHT-01 · Dil · seçenekler', () {
    test('diller ekran sırasıyla TR, EN ve uygulamanın desteklediği '
        'dillerle aynı küme', () {
      expect(LanguageOptions.locales, [_tr, _en]);
      expect(
        LanguageOptions.locales.toSet(),
        AppLocalizations.supportedLocales.toSet(),
      );
    });

    test('ad dilin kendi dilinde, kod büyük harf; iki ARB’de aynı', () {
      for (final locale in AppLocalizations.supportedLocales) {
        final l10n = lookupAppLocalizations(locale);
        expect(LanguageOptions.nameOf(l10n, _tr), 'Türkçe');
        expect(LanguageOptions.nameOf(l10n, _en), 'English');
        expect(l10n.sht01MenuItem('Türkçe', 'TR'), 'Türkçe — TR');
      }
      expect(LanguageOptions.codeOf(_tr), 'TR');
      expect(LanguageOptions.codeOf(_en), 'EN');
      // Tanınmayan dil: kod gösterilir (istisna yok).
      expect(
        LanguageOptions.nameOf(lookupAppLocalizations(_tr), const Locale('de')),
        'DE',
      );
    });

    test('anahtarlar prototipteki aksiyon adlarıdır', () {
      expect(LanguageOptions.keyOf(_tr), GuKey.action('SHT-01.select.tr'));
      expect(LanguageOptions.keyOf(_en), GuKey.action('SHT-01.select.en'));
      expect(MenuId.sht01.designId, SheetId.sht01.designId);
    });

    test('tek gövde: `/// Design: SHT-01` izi yalnızca LanguageOptions’ta', () {
      final source = readText(
        'lib/product/feedback/catalogs/sheets/language_sheet.dart',
      );
      expect(
        RegExp(r'///\s*Design:\s*SHT-01').allMatches(source),
        hasLength(1),
      );
      expect(
        source,
        contains(
          RegExp(r'/// Design: SHT-01\s*\nclass LanguageOptions\b'),
        ),
      );
    });
  });

  group('SHT-01 · Dil · alt sayfa (SET-01)', () {
    testWidgets('çizim: başlık, kapat düğmesi, iki seçenek satırı (ad + kod); '
        'etkin dil seçili — TR ve EN', (tester) async {
      for (final locale in [_tr, _en]) {
        final h = _Harness();
        await h.pump(tester, locale: locale);
        await h.openSheet(tester);
        final l10n = tester.l10nFor(locale);

        final frame = tester.widget<GuSheetFrame>(find.byType(GuSheetFrame));
        expect(frame.title, l10n.sht01Title);
        expect(frame.closeSemanticLabel, l10n.a11yClose);
        expect(frame.flush, isFalse);
        expect(frame.footer, isNull);
        expect(find.byKey(_key('close')), findsOneWidget);
        expect(find.byKey(_key('scrim')), findsOneWidget);

        final rows = tester
            .widgetList<GuOptionRow>(find.byType(GuOptionRow))
            .toList();
        expect(rows.map((row) => row.label), ['Türkçe', 'English']);
        expect(rows.map((row) => row.sub), ['TR', 'EN']);
        expect(rows.map((row) => row.control).toSet(), {GuOptionControl.radio});
        expect(rows.map((row) => row.selected), [
          locale == _tr,
          locale == _en,
        ], reason: '$locale');
        expect(
          tester.widget<GuOptionRow>(find.byKey(_key('select.tr'))).label,
          'Türkçe',
        );
        expect(
          tester.widget<GuOptionRow>(find.byKey(_key('select.en'))).label,
          'English',
        );
      }
    });

    testWidgets('seçim tercihi yazar ve sayfayı kapatır', (tester) async {
      final h = _Harness();
      await h.pump(tester);
      await h.openSheet(tester);

      await tester.tap(find.byKey(_key('select.en')));
      await tester.pumpAndSettle();

      expect(find.byType(GuSheetFrame), findsNothing);
      expect(
        h.container(tester).read(appPreferencesViewModelProvider).locale,
        _en,
      );
      expect(_store().locale, _en);
      expect(_store().callsTo('setLocale'), hasLength(1));
    });

    testWidgets('zaten seçili dile dokunma da kapatır (tercih aynı kalır)', (
      tester,
    ) async {
      final h = _Harness();
      await h.pump(tester);
      await h.openSheet(tester);

      await tester.tap(find.byKey(_key('select.tr')));
      await tester.pumpAndSettle();

      expect(find.byType(GuSheetFrame), findsNothing);
      expect(_store().locale, _tr);
    });

    testWidgets('kapat düğmesi ve scrim tercihe dokunmadan kapatır', (
      tester,
    ) async {
      final h = _Harness();
      await h.pump(tester);
      for (final action in ['close', 'scrim']) {
        await h.openSheet(tester);
        await tester.tap(find.byKey(_key(action)));
        await tester.pumpAndSettle();
        expect(find.byType(GuSheetFrame), findsNothing, reason: action);
      }
      expect(_store().callsTo('setLocale'), isEmpty);
      expect(_store().locale, isNull);
    });

    testWidgets('cihaz matrisi: taşma yok', (tester) async {
      await DeviceMatrix.run(
        tester,
        (context) => const Align(
          alignment: Alignment.bottomCenter,
          child: LanguageSheet(),
        ),
        safeAreas: true,
      );
    });
  });

  group('SHT-01 · Dil · açılır menü (ONB-01 / AUT-01 / AUT-02)', () {
    testWidgets('çizim: iki menü öğesi "Ad — KOD"; etkin dilde onay işareti — '
        'açık + koyu, TR + EN', (tester) async {
      for (final theme in [ThemeMode.light, ThemeMode.dark]) {
        for (final locale in [_tr, _en]) {
          final h = _Harness();
          await h.pump(tester, locale: locale, theme: theme);
          await h.openMenu(tester);

          expect(find.byType(GuPopMenu), findsOneWidget);
          expect(find.byType(GuSheetFrame), findsNothing);
          final items = tester
              .widgetList<GuPopMenuItem>(find.byType(GuPopMenuItem))
              .toList();
          expect(items.map((item) => item.label), [
            'Türkçe — TR',
            'English — EN',
          ]);
          expect(items.map((item) => item.selected), [
            locale == _tr,
            locale == _en,
          ], reason: '$theme $locale');
          expect(items.map((item) => item.icon).toSet(), {null});
          // Seçili öğede tek onay işareti (sheets.js:11 `check` 18).
          expect(
            find.descendant(
              of: find.byKey(_key(locale == _tr ? 'select.tr' : 'select.en')),
              matching: find.byWidgetPredicate(
                (w) => w is GuIcon && w.icon == GuIcons.check,
              ),
            ),
            findsOneWidget,
          );
          expect(
            find.byWidgetPredicate(
              (w) => w is GuIcon && w.icon == GuIcons.check,
            ),
            findsOneWidget,
          );
        }
      }
    });

    testWidgets('seçim menüyü kapatır ve tercihi yazar', (tester) async {
      final h = _Harness();
      await h.pump(tester);
      await h.openMenu(tester);

      await tester.tap(find.byKey(_key('select.en')));
      await tester.pumpAndSettle();

      expect(find.byType(GuPopMenu), findsNothing);
      expect(
        h.container(tester).read(appPreferencesViewModelProvider).locale,
        _en,
      );
      expect(_store().locale, _en);
    });

    testWidgets('scrim tercihe dokunmadan kapatır', (tester) async {
      final h = _Harness();
      await h.pump(tester);
      await h.openMenu(tester);

      await tester.tap(find.byKey(_key('scrim')));
      await tester.pumpAndSettle();

      expect(find.byType(GuPopMenu), findsNothing);
      expect(_store().callsTo('setLocale'), isEmpty);
    });

    testWidgets('tercih kalıcı yazılamasa da seçim oturumda geçerlidir', (
      tester,
    ) async {
      final original = debugPrint;
      debugPrint = (message, {wrapWidth}) {};
      addTearDown(() => debugPrint = original);
      final h = _Harness();
      await h.pump(tester);
      _store().failNext();
      await h.openMenu(tester);

      await tester.tap(find.byKey(_key('select.en')));
      await tester.pumpAndSettle();
      debugPrint = original;

      expect(
        h.container(tester).read(appPreferencesViewModelProvider).locale,
        _en,
      );
      expect(find.byType(GuPopMenu), findsNothing);
    });
  });
}
