// T-11 · Sistem geri tuşunun kabuk kuralı (navigation.md §6; PLAN §13.8):
// derin ekranda pop · sekme kökünde ilk sekmeye · ilk sekmenin kökünde
// uygulamadan çıkış. Kural kabukta tek `PopScope`'tadır.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/navigator_keys.dart';
import 'package:gu_kulupler/product/navigation/shell/app_shell_view.dart';

import '../../fakes/fake_session_states.dart';
import '../../fakes/test_router.dart';

void main() {
  /// `SystemNavigator.pop` çağrılarını sayar (uygulamadan çıkış).
  List<String> watchSystemPops(WidgetTester tester) {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemNavigator.pop') calls.add(call.method);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    return calls;
  }

  group('T-11 · geri davranışı (kabuk)', () {
    testWidgets('derin ekranda geri bir önceki ekrana iner', (tester) async {
      final exits = watchSystemPops(tester);
      final app = await TestRouter.pumpShell(tester);
      await app.go('/clubs/c01/members');

      expect(await app.systemBack(), isTrue);
      expect(app.location, '/clubs/c01');
      expect(await app.systemBack(), isTrue);
      expect(app.location, '/clubs');
      expect(exits, isEmpty);
    });

    testWidgets('ilk sekme dışındaki sekme kökünde geri → Kulüpler', (
      tester,
    ) async {
      final exits = watchSystemPops(tester);
      for (final tab in [GuTab.events, GuTab.notifications, GuTab.profile]) {
        final app = await TestRouter.pumpShell(tester, location: tab.rootPath);
        expect(await app.systemBack(), isTrue, reason: tab.name);
        expect(app.location, '/clubs', reason: tab.name);
        expect(app.currentTab, GuTab.clubs, reason: tab.name);
      }
      expect(exits, isEmpty);
    });

    testWidgets('Admin kökünde geri → Kulüpler (süper admin)', (tester) async {
      final app = await TestRouter.pumpShell(
        tester,
        session: FakeSessionStates.activeSuper,
        location: '/admin',
      );
      expect(await app.systemBack(), isTrue);
      expect(app.location, '/clubs');
    });

    testWidgets('diğer sekmede derin → kök → Kulüpler → çıkış', (tester) async {
      final exits = watchSystemPops(tester);
      final app = await TestRouter.pumpShell(tester, location: '/events/e01');

      expect(await app.systemBack(), isTrue);
      expect(app.location, '/events');
      expect(await app.systemBack(), isTrue);
      expect(app.location, '/clubs');
      expect(exits, isEmpty);

      expect(await app.systemBack(), isFalse);
      expect(exits, ['SystemNavigator.pop']);
      expect(app.location, '/clubs');
    });

    testWidgets('ilk sekmenin kökünde geri uygulamadan çıkarır', (
      tester,
    ) async {
      final exits = watchSystemPops(tester);
      final app = await TestRouter.pumpShell(tester);
      expect(await app.systemBack(), isFalse);
      expect(exits, ['SystemNavigator.pop']);
      expect(app.location, '/clubs');
    });

    testWidgets('ilk sekmeye dönüş diğer sekmenin yığınını silmez', (
      tester,
    ) async {
      final app = await TestRouter.pumpShell(tester, location: '/clubs/c01');
      await app.go('/events');
      expect(await app.systemBack(), isTrue);
      // Kulüpler kaldığı yerden açılır.
      expect(app.location, '/clubs/c01');
      expect(app.stackDepth(GuTab.events), 1);
    });

    testWidgets('geri isteği kök gezgine düşerse de derin dalın sayfası '
        'kapanır (sekme değişmez)', (tester) async {
      final app = await TestRouter.pumpShell(tester, location: '/events/e01');
      // Kök gezgindeki tek sayfa kabuktur; isteği kabuğun PopScope'u karşılar.
      expect(await rootNavigatorKey.currentState!.maybePop(), isTrue);
      await tester.pumpAndSettle();
      expect(app.location, '/events');
      expect(app.currentTab, GuTab.events);
    });

    testWidgets('kural kabukta tek PopScope’tadır; yalnızca ilk sekmenin '
        'kökünde pop serbesttir', (tester) async {
      final app = await TestRouter.pumpShell(tester);
      // go_router dal kabı kendi `PopScope<dynamic>`'ini taşır; kabuğun
      // kuralı `PopScope<Object?>`'tir.
      Finder scope() => find.descendant(
        of: find.byType(AppShellView),
        matching: find.byType(PopScope<Object?>),
      );
      bool canPop() => tester.widget<PopScope<Object?>>(scope()).canPop;

      expect(scope(), findsOneWidget);
      expect(canPop(), isTrue);
      await app.go('/clubs/c01');
      expect(scope(), findsOneWidget);
      expect(canPop(), isFalse);
      await app.go('/events');
      expect(canPop(), isFalse);
      await app.go('/clubs');
      expect(canPop(), isTrue);
    });
  });
}
