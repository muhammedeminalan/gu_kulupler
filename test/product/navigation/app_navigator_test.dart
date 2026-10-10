// T-11 · GuTab, AppNavigator.openInTab (Q-20 = A) ve "başa kaydır" isteği
// (PLAN §13.2, §13.7; navigation.md §4).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/navigator_keys.dart';

import '../../fakes/test_router.dart';
import '../../helpers/design_ids.dart';
import '../../helpers/test_container.dart';

void main() {
  group('T-11 · GuTab', () {
    test('sıra ve kök yollar registry.json#tabs ile aynıdır', () {
      expect(
        GuTab.values.map((tab) => tab.name),
        DesignIds.tabRoots.keys,
      );
      expect(GuTab.values.map((tab) => tab.name), [
        'clubs',
        'events',
        'notifications',
        'admin',
        'profile',
      ]);
      expect(
        {for (final tab in GuTab.values) tab.name: tab.rootPath},
        {
          'clubs': '/clubs',
          'events': '/events',
          'notifications': '/notifications',
          'admin': '/admin',
          'profile': '/profile',
        },
      );
    });

    test('her sekmenin kendi dal gezgini vardır', () {
      expect(
        {for (final tab in GuTab.values) tab: tab.navigatorKey},
        {
          GuTab.clubs: clubsNavigatorKey,
          GuTab.events: eventsNavigatorKey,
          GuTab.notifications: notificationsNavigatorKey,
          GuTab.admin: adminNavigatorKey,
          GuTab.profile: profileNavigatorKey,
        },
      );
      final keys = {
        rootNavigatorKey,
        for (final tab in GuTab.values) tab.navigatorKey,
      };
      expect(keys, hasLength(6));
    });

    test('ofLocation: ilk yol parçası ev sekmesini verir', () {
      GuTab? of(String location) => GuTab.ofLocation(Uri.parse(location));
      expect(of('/clubs'), GuTab.clubs);
      expect(of('/clubs/c01/manage/members'), GuTab.clubs);
      expect(of('/events/e01?showCancelled=true'), GuTab.events);
      expect(of('/notifications/preferences'), GuTab.notifications);
      expect(of('/admin/users/u01'), GuTab.admin);
      expect(of('/profile/settings/about'), GuTab.profile);
      expect(of('/login'), isNull);
      expect(of('/splash'), isNull);
      expect(of('/clubsx'), isNull);
      expect(of('/'), isNull);
      expect(of(''), isNull);
    });

    test('isTabRoot: yalnızca beş sekme kökü (derinlik 1)', () {
      bool isRoot(String location) => GuTab.isTabRoot(Uri.parse(location));
      for (final tab in GuTab.values) {
        expect(isRoot(tab.rootPath), isTrue, reason: tab.name);
        expect(isRoot('${tab.rootPath}/'), isTrue, reason: tab.name);
        expect(isRoot('${tab.rootPath}/x'), isFalse, reason: tab.name);
      }
      expect(isRoot('/clubs?tab=x'), isTrue);
      expect(isRoot('/clubs/search'), isFalse);
      expect(isRoot('/events/e01/ticket'), isFalse);
      expect(isRoot('/profile/settings/about'), isFalse);
      // Kabuk dışı tek parçalı yollar sekme kökü değildir.
      expect(isRoot('/login'), isFalse);
      expect(isRoot('/splash'), isFalse);
      expect(isRoot('/not-found'), isFalse);
    });
  });

  group('T-11 · scrollTopRequestProvider', () {
    test('sekme başına bağımsız sayaç', () {
      final container = createContainer();
      for (final tab in GuTab.values) {
        expect(container.read(scrollTopRequestProvider(tab)), 0);
      }
      container.read(scrollTopRequestProvider(GuTab.clubs).notifier)
        ..request()
        ..request();
      container.read(scrollTopRequestProvider(GuTab.events).notifier).request();
      expect(container.read(scrollTopRequestProvider(GuTab.clubs)), 2);
      expect(container.read(scrollTopRequestProvider(GuTab.events)), 1);
      expect(container.read(scrollTopRequestProvider(GuTab.profile)), 0);
    });

    test('her istek dinleyiciye ulaşır', () {
      final container = createContainer();
      final seen = <int>[];
      container.listen(
        scrollTopRequestProvider(GuTab.clubs),
        (_, next) => seen.add(next),
      );
      container.read(scrollTopRequestProvider(GuTab.clubs).notifier)
        ..request()
        ..request()
        ..request();
      expect(seen, [1, 2, 3]);
    });
  });

  group('T-11 · AppNavigator.openInTab (Q-20 = A)', () {
    BuildContext contextOf(WidgetTester tester, String path) =>
        tester.element(find.text(path));

    testWidgets('başka sekmeden: hedefin ev sekmesine geçer, yığın '
        'kök → … → hedef olur', (tester) async {
      final app = await TestRouter.pumpShell(tester, location: '/profile');
      AppNavigator.openInTab(
        contextOf(tester, '/profile'),
        GuTab.clubs,
        '/clubs/c01/manage',
      );
      await tester.pumpAndSettle();

      expect(app.location, '/clubs/c01/manage');
      expect(app.currentTab, GuTab.clubs);
      // Yığın rota ağacından kurulur: [/clubs, /clubs/c01, /clubs/c01/manage].
      expect(app.stackDepth(GuTab.clubs), 3);
      expect(find.text('/clubs/c01/manage'), findsOneWidget);
      // Çağıran dalın yığını değişmez.
      expect(app.stackDepth(GuTab.profile), 1);

      // Geri, hedef sekmenin köküne iner (çağırana değil).
      expect(await app.systemBack(), isTrue);
      expect(app.location, '/clubs/c01');
      expect(await app.systemBack(), isTrue);
      expect(app.location, '/clubs');
    });

    testWidgets('çağıran sekme yığınını korur (alt çubuktan dönülür)', (
      tester,
    ) async {
      final app = await TestRouter.pumpShell(tester, location: '/events/e01');
      AppNavigator.openInTab(
        contextOf(tester, '/events/e01'),
        GuTab.clubs,
        '/clubs',
      );
      await tester.pumpAndSettle();
      expect(app.location, '/clubs');
      expect(app.stackDepth(GuTab.events), 2);

      await app.tapTab(GuTab.events);
      expect(app.location, '/events/e01');
    });

    testWidgets('aynı sekme içinde de çalışır', (tester) async {
      final app = await TestRouter.pumpShell(tester);
      AppNavigator.openInTab(
        contextOf(tester, '/clubs'),
        GuTab.clubs,
        '/clubs/c02',
      );
      await tester.pumpAndSettle();
      expect(app.location, '/clubs/c02');
      expect(app.stackDepth(GuTab.clubs), 2);
    });

    testWidgets('hedef sekmenin ağacında değilse assert', (tester) async {
      await TestRouter.pumpShell(tester);
      expect(
        () => AppNavigator.openInTab(
          contextOf(tester, '/clubs'),
          GuTab.events,
          '/clubs/c01',
        ),
        throwsAssertionError,
      );
      expect(
        () => AppNavigator.openInTab(
          contextOf(tester, '/clubs'),
          GuTab.clubs,
          '/login',
        ),
        throwsAssertionError,
      );
    });
  });
}
