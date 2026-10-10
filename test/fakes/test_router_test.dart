// T-11 · TestRouter düzeneği (PLAN §16.3): gerçek router + sahte oturum,
// konum günlüğü, yığın okuyucu.
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/shell/app_shell_view.dart';

import 'fake_session_states.dart';
import 'test_router.dart';

void main() {
  group('T-11 · TestRouter.pump (gerçek rota ağacı)', () {
    testWidgets('varsayılan: aktif oturum, /splash → /clubs', (tester) async {
      final app = await TestRouter.pump(tester);
      expect(app.session, FakeSessionStates.active);
      expect(app.location, '/clubs');
      expect(app.currentTab, GuTab.clubs);
      expect(app.locationLog.last, '/clubs');
      expect(app.feedback.toasts, isEmpty);
    });

    testWidgets('location: açılıştan sonra o yola gider', (tester) async {
      final app = await TestRouter.pump(tester, location: '/events');
      expect(app.location, '/events');
      expect(app.locationLog, containsAllInOrder(['/clubs', '/events']));
    });

    testWidgets('session=: state yerinde değişir, router yeniden '
        'değerlendirir', (tester) async {
      final app = await TestRouter.pump(tester);
      app.session = FakeSessionStates.unverified;
      await tester.pumpAndSettle();
      expect(app.session, FakeSessionStates.unverified);
      expect(app.location, '/verify');
      expect(app.currentTab, isNull);
    });

    testWidgets('aynı testte ikinci kez çizilebilir', (tester) async {
      final first = await TestRouter.pump(tester);
      final second = await TestRouter.pump(
        tester,
        session: FakeSessionStates.signedOut,
      );
      expect(second.router, isNot(same(first.router)));
      expect(second.location, '/login');
    });
  });

  group('T-11 · TestRouter.pumpShell (kabuk + test dalları)', () {
    testWidgets('her sekmede kökün altında üç düzey vardır; sayfa kendi '
        'yolunu gösterir', (tester) async {
      final app = await TestRouter.pumpShell(tester);
      expect(find.byType(AppShellView), findsOneWidget);
      for (final tab in GuTab.values) {
        final deep = '${tab.rootPath}/a/b/c';
        await app.go(deep);
        expect(app.location, deep, reason: tab.name);
        expect(app.stackDepth(tab), 4, reason: tab.name);
        expect(find.text(deep), findsOneWidget, reason: tab.name);
      }
    });

    testWidgets('yönlendirme varsayılan olarak bağlı değildir; redirect: '
        'true ile bağlanır', (tester) async {
      final free = await TestRouter.pumpShell(tester, location: '/admin');
      expect(free.location, '/admin');

      final guarded = await TestRouter.pumpShell(
        tester,
        location: '/admin',
        redirect: true,
      );
      expect(guarded.location, '/clubs');
    });

    testWidgets('tapTab ve systemBack', (tester) async {
      final app = await TestRouter.pumpShell(tester);
      await app.tapTab(GuTab.profile);
      expect(app.location, '/profile');
      expect(await app.systemBack(), isTrue);
      expect(app.location, '/clubs');
      expect(app.locationLog, ['/clubs', '/profile', '/clubs']);
    });

    testWidgets('kabuk dışı test yolu: /outside', (tester) async {
      final app = await TestRouter.pumpShell(tester, location: '/outside');
      expect(find.byType(AppShellView), findsNothing);
      expect(find.byType(TestPage), findsOneWidget);
      expect(app.stackDepth(GuTab.clubs), 0);
    });
  });
}
