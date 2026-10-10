// T-11 · RoutePlaceholderView: sahibi task gerçek ekranı yazana kadar rotanın
// gösterdiği geçici gövde (PLAN §13.2, §13.11). Tasarım kimliği ve aksiyon
// anahtarı taşımaz.
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/navigation/routes/route_placeholder_view.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/action_inventory.dart';
import '../../helpers/design_files.dart';
import '../../helpers/device_matrix.dart';
import '../../helpers/pump_app.dart';

void main() {
  group('T-11 · RoutePlaceholderView', () {
    testWidgets('başlık etkin dilden okunur (TR / EN)', (tester) async {
      for (final locale in AppLocalizations.supportedLocales) {
        await tester.pumpApp(
          RoutePlaceholderView(title: (l10n) => l10n.authLoginTitle),
          locale: locale,
        );
        expect(
          tester.widget<GuAppBar>(find.byType(GuAppBar)).title,
          lookupAppLocalizations(locale).authLoginTitle,
        );
      }
    });

    testWidgets('aksiyon anahtarı ve geri düğmesi yoktur', (tester) async {
      await tester.pumpApp(
        RoutePlaceholderView(title: (l10n) => l10n.navClubs),
      );
      expect(ActionInventory.found(tester), isEmpty);
      expect(tester.widget<GuAppBar>(find.byType(GuAppBar)).onBack, isNull);
    });

    testWidgets('cihaz matrisi: taşma yok', (tester) async {
      await DeviceMatrix.run(
        tester,
        (context) => RoutePlaceholderView(title: (l10n) => l10n.authSetupTitle),
        safeAreas: true,
      );
    });

    test('tasarım kimliği izi taşımaz; kullanan her rota sahipli not '
        'taşır', () {
      final design = RegExp(r'///\s*Design:');
      expect(
        readText('lib/product/navigation/routes/route_placeholder_view.dart'),
        isNot(contains(design)),
      );
      const owners = {
        'lib/product/navigation/routes/auth_routes.dart': 4,
        'lib/product/navigation/routes/clubs_routes.dart': 1,
        'lib/product/navigation/routes/events_routes.dart': 1,
        'lib/product/navigation/routes/notifications_routes.dart': 1,
        'lib/product/navigation/routes/admin_routes.dart': 1,
        'lib/product/navigation/routes/profile_routes.dart': 1,
      };
      final usage = RegExp(
        r'// TODO\(T-\d\d\): [^\n]*\n\s*RoutePlaceholderView\(',
      );
      for (final MapEntry(key: file, value: count) in owners.entries) {
        final source = readText(file);
        expect(source, isNot(contains(design)), reason: file);
        expect(
          'RoutePlaceholderView('.allMatches(source),
          hasLength(count),
          reason: file,
        );
        expect(usage.allMatches(source), hasLength(count), reason: file);
      }
    });
  });
}
