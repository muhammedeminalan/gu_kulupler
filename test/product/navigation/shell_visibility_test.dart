// T-11 · Alt sekme çubuğu yalnızca sekme kökünde görünür (navigation.md §1;
// PLAN §13.10) — derinlik yoldan türetilir, ekran ekran bayrak yoktur.
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../fakes/fake_session_states.dart';
import '../../fakes/test_router.dart';

void main() {
  group('T-11 · kabuk görünürlüğü', () {
    testWidgets('sekme kökünde görünür, derin ekranda gizlenir', (
      tester,
    ) async {
      final app = await TestRouter.pumpShell(tester);
      const cases = <String, bool>{
        '/clubs': true,
        '/clubs/search': false,
        '/clubs/c01': false,
        '/clubs/c01/members': false,
        '/events': true,
        '/events/e01': false,
        '/events/e01/ticket': false,
        '/notifications': true,
        '/notifications/preferences': false,
        '/profile': true,
        '/profile/settings': false,
        '/profile/settings/about': false,
      };
      for (final MapEntry(key: location, value: visible) in cases.entries) {
        await app.go(location);
        expect(app.location, location);
        expect(
          find.byType(GuBottomNav),
          visible ? findsOneWidget : findsNothing,
          reason: location,
        );
      }
    });

    testWidgets('/admin kökünde de görünür (süper admin)', (tester) async {
      final app = await TestRouter.pumpShell(
        tester,
        session: FakeSessionStates.activeSuper,
        location: '/admin',
      );
      expect(find.byType(GuBottomNav), findsOneWidget);
      await app.go('/admin/users');
      expect(find.byType(GuBottomNav), findsNothing);
    });

    testWidgets('geri dönünce çubuk yeniden görünür', (tester) async {
      final app = await TestRouter.pumpShell(tester);
      await app.go('/clubs/c01');
      expect(find.byType(GuBottomNav), findsNothing);
      expect(await app.systemBack(), isTrue);
      expect(app.location, '/clubs');
      expect(find.byType(GuBottomNav), findsOneWidget);
    });

    testWidgets('kabuk dışı ekranda kabuk yoktur', (tester) async {
      final app = await TestRouter.pumpShell(tester);
      await app.go('/outside');
      expect(find.byType(GuBottomNav), findsNothing);
      expect(find.text('/outside'), findsOneWidget);
      expect(app.currentTab, isNull);
    });

    testWidgets('çubuk yalnızca sekme kökünde yer kaplar: derin ekran tam '
        'yüksekliği kullanır', (tester) async {
      final app = await TestRouter.pumpShell(tester);
      final rootHeight = tester.getSize(find.text('/clubs')).height;
      final rootBottom = tester.getRect(find.byType(TestPage)).bottom;
      expect(rootHeight, greaterThan(0));
      expect(
        rootBottom,
        tester.getRect(find.byType(GuBottomNav)).top,
      );

      await app.go('/clubs/c01');
      expect(tester.getRect(find.byType(TestPage).last).bottom, 844);
    });

    test('kural tek yerde: GuTab.isTabRoot', () {
      expect(GuTab.isTabRoot(Uri.parse('/clubs')), isTrue);
      expect(GuTab.isTabRoot(Uri.parse('/clubs/search')), isFalse);
    });
  });
}
