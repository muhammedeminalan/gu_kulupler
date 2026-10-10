// SYS-04 · İçerik yok — metinler, 2 aksiyon (`SYS-04.back` çubukta ve
// düğmede, `SYS-04.home`) ve sonuçları, bilinmeyen yol, cihaz matrisi, aksiyon
// envanteri, açık + koyu golden. Referans:
// design/reference-shots/screens/SYS-04__*.webp.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/features/system/view/not_found_view.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fakes/fake_session_states.dart';
import '../../../fakes/test_router.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';

final Key _back = GuKey.action('SYS-04.back');
final Key _home = GuKey.action('SYS-04.home');

void main() {
  group('SYS-04 · İçerik yok', () {
    testWidgets('illüstrasyon, başlık, açıklama ve iki düğme çizilir', (
      tester,
    ) async {
      await tester.pumpApp(const NotFoundView());
      final l10n = tester.l10n;
      expect(
        tester.widget<GuIllustration>(find.byType(GuIllustration)).illustration,
        GuIllustrations.locked,
      );
      expect(find.text(l10n.sysNotFoundTitle), findsOneWidget);
      expect(find.text(l10n.sysNotFoundDesc), findsOneWidget);

      // `SYS-04.back` iki yerdedir: çubuktaki geri ve "Geri" düğmesi.
      expect(find.byKey(_back), findsNWidgets(2));
      final backButton = tester.widget<GuButton>(
        find.byWidgetPredicate((w) => w is GuButton && w.key == _back),
      );
      expect(backButton.label, l10n.commonBack);
      expect(backButton.variant, GuButtonVariant.outline);
      final homeButton = tester.widget<GuButton>(find.byKey(_home));
      expect(homeButton.label, l10n.sysErrorHome);
      expect(homeButton.variant, GuButtonVariant.primary);
      // Düğmeler yan yana: "Geri" solda.
      expect(
        tester.getCenter(find.byWidget(backButton)).dx,
        lessThan(tester.getCenter(find.byKey(_home)).dx),
      );
    });

    testWidgets('aksiyon envanteri: SYS-04.back / .home', (tester) async {
      await tester.pumpApp(const NotFoundView());
      expectActionInventory(tester, 'SYS-04');
    });

    testWidgets('cihaz matrisi: taşma yok', (tester) async {
      await DeviceMatrix.run(
        tester,
        (_) => const NotFoundView(),
        safeAreas: true,
      );
    });

    testWidgets('golden: açık + koyu', (tester) async {
      await goldenForThemes(tester, 'SYS-04', const NotFoundView());
    });
  });

  group('SYS-04 · İçerik yok · aksiyonlar', () {
    testWidgets('bilinmeyen yol SYS-04 gösterir', (tester) async {
      final app = await TestRouter.pump(tester, location: '/boyle-bir-yol-yok');
      expect(find.byType(NotFoundView), findsOneWidget);
      expect(app.location, '/boyle-bir-yol-yok');
    });

    testWidgets('SYS-04.home: ana sayfa', (tester) async {
      final app = await TestRouter.pump(tester, location: '/not-found');
      await tester.tap(find.byKey(_home));
      await tester.pumpAndSettle();
      expect(app.location, '/clubs');
      expect(find.byType(NotFoundView), findsNothing);
    });

    testWidgets('SYS-04.back (çubuk ve düğme): dönülecek sayfa yoksa ana '
        'sayfa', (tester) async {
      for (final finder in [find.byKey(_back).first, find.byKey(_back).last]) {
        final app = await TestRouter.pump(tester, location: '/not-found');
        await tester.tap(finder);
        await tester.pumpAndSettle();
        expect(app.location, '/clubs');
      }
    });

    testWidgets('SYS-04.back: oturum yokken router karar verir (giriş)', (
      tester,
    ) async {
      final app = await TestRouter.pump(
        tester,
        session: FakeSessionStates.signedOut,
        location: '/not-found',
      );
      await tester.tap(find.byKey(_back).last);
      await tester.pumpAndSettle();
      expect(app.location, startsWith('/login'));
    });

    testWidgets('SYS-04.back: yığında sayfa varsa geri döner', (tester) async {
      GoRouter? router;
      await tester.pumpAppRouter(
        routerOf: (_) => router ??= GoRouter(
          initialLocation: '/liste/yok',
          routes: [
            GoRoute(
              path: '/liste',
              builder: (context, state) => const TestPage('/liste'),
              routes: [
                GoRoute(
                  path: 'yok',
                  builder: (context, state) => const NotFoundView(),
                ),
              ],
            ),
          ],
        ),
      );
      addTearDown(() => router?.dispose());
      await tester.pumpAndSettle();
      expect(find.byType(NotFoundView), findsOneWidget);

      await tester.tap(find.byKey(_back).last);
      await tester.pumpAndSettle();
      expect(find.byType(NotFoundView), findsNothing);
      expect(
        router!.routerDelegate.currentConfiguration.uri.toString(),
        '/liste',
      );
    });
  });
}
