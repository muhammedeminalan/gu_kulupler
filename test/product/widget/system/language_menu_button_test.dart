// T-13 · LanguageMenuButton — oturum öncesi ekranların dil düğmesi
// (screens-auth.js:47, :67, :93): hayalet / küçük düğme, `languages` ikonu,
// etkin dil kodu; dokununca SHT-01 açılır menü biçiminde açılır
// (`MenuId.sht01`, CD-113). Ekran anahtarları (`<ID>.lang`) ekran
// testlerindedir; burada tarafsız bir anahtar kullanılır.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/language_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/feedback/menu_id.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/widget/system/language_menu_button.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fakes/fake_app_preferences_store.dart';
import '../../../fakes/fake_base.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';

const Key _buttonKey = ValueKey<String>('host.lang');
const Locale _tr = Locale('tr');
const Locale _en = Locale('en');

Key _menuKey(String action) => FeedbackKeys.of(MenuId.sht01.designId, action);

GuButton _button(WidgetTester tester) =>
    tester.widget<GuButton>(find.byType(GuButton));

void main() {
  group('T-13 · LanguageMenuButton · çizim', () {
    testWidgets('hayalet + küçük düğme, `languages` ikonu, etkin dil kodu; '
        'ok yalnızca chevron: true iken — TR ve EN', (tester) async {
      for (final (locale, code, name) in [
        (_tr, 'TR', 'Türkçe'),
        (_en, 'EN', 'English'),
      ]) {
        await tester.pumpApp(
          const Center(child: LanguageMenuButton(key: _buttonKey)),
          locale: locale,
        );
        final button = _button(tester);
        expect(button.label, code);
        expect(button.variant, GuButtonVariant.ghost);
        expect(button.size, GuButtonSize.sm);
        expect(button.icon, GuIcons.languages);
        expect(button.iconTrailing, isNull);
        expect(button.semanticLabel, tester.l10n.a11yLanguage(name));
        expect(find.text(code), findsOneWidget);
        // Anahtar düğmeyi bulur (ekran `<ID>.lang` verir).
        expect(
          find.descendant(
            of: find.byKey(_buttonKey),
            matching: find.byType(GuButton),
          ),
          findsOneWidget,
        );

        await tester.pumpApp(
          const Center(
            child: LanguageMenuButton(key: _buttonKey, chevron: true),
          ),
          locale: locale,
        );
        expect(_button(tester).iconTrailing, GuIcons.chevronDown);
      }
    });

    testWidgets('erişilebilirlik: tek düğme düğümü, etiket "Dil: <ad>"', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpApp(
        const Center(child: LanguageMenuButton(key: _buttonKey)),
      );
      expect(
        tester.getSemantics(find.byType(GuButton)),
        isSemantics(
          label: tester.l10n.a11yLanguage('Türkçe'),
          isButton: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('cihaz matrisi: taşma yok (dar ekran + büyük yazı)', (
      tester,
    ) async {
      await DeviceMatrix.run(
        tester,
        (context) => const Align(
          alignment: Alignment.topRight,
          child: LanguageMenuButton(key: _buttonKey, chevron: true),
        ),
        safeAreas: true,
      );
    });
  });

  group('T-13 · LanguageMenuButton · menü', () {
    testWidgets('dokunma SHT-01’i menü olarak ister: MenuId.sht01, scrim '
        'anahtarı, tek içerik LanguageOptions (menü biçimi)', (tester) async {
      final feedback = FakeFeedbackService();
      await tester.pumpApp(
        const Center(child: LanguageMenuButton(key: _buttonKey)),
        overrides: [feedbackServiceProvider.overrideWithValue(feedback)],
      );

      await tester.tap(find.byKey(_buttonKey));
      await tester.pump();

      expect(feedback.menus, [MenuId.sht01]);
      expect(feedback.sheets, isEmpty);
      expect(feedback.callsTo('showMenu'), [
        FakeCall('showMenu', [MenuId.sht01, _menuKey('scrim')]),
      ]);
      expect(
        feedback.lastMenuItems.single,
        isA<LanguageOptions>().having(
          (options) => options.variant,
          'variant',
          LanguageOptionsVariant.menu,
        ),
      );
    });

    testWidgets('uçtan uca: düğme → menü → "English" → tercih yazılır, menü '
        'kapanır; scrim seçim yapmadan kapatır', (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      final controller = GuToastController();
      addTearDown(controller.dispose);
      await tester.pumpApp(
        Navigator(
          key: navigatorKey,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => const Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: LanguageMenuButton(key: _buttonKey),
              ),
            ),
          ),
        ),
        overrides: [
          feedbackServiceProvider.overrideWithValue(
            AppFeedbackService(
              navigatorKey: navigatorKey,
              toastController: controller,
            ),
          ),
        ],
      );
      final store = GetIt.I<AppPreferencesStore>() as FakeAppPreferencesStore;

      await tester.tap(find.byKey(_buttonKey));
      await tester.pumpAndSettle();
      expect(find.byType(GuPopMenu), findsOneWidget);
      expect(find.byType(GuPopMenuItem), findsNWidgets(2));
      // Menü sabit sağ üsttedir (CD-83); tetikleyiciye hizalanmaz.
      expect(
        tester.getRect(find.byType(GuPopMenu)).right,
        390 - GuSizes.popMenuRight,
      );

      await tester.tap(find.byKey(_menuKey('scrim')));
      await tester.pumpAndSettle();
      expect(find.byType(GuPopMenu), findsNothing);
      expect(store.locale, isNull);

      await tester.tap(find.byKey(_buttonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(LanguageOptions.keyOf(_en)));
      await tester.pumpAndSettle();
      expect(find.byType(GuPopMenu), findsNothing);
      expect(store.locale, _en);
    });
  });
}
