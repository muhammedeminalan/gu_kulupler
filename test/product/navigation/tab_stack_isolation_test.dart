// T-11 · Sekme yığınları bağımsızdır; etkin sekmeye yeniden dokunma köke
// döndürür / başa kaydırır (navigation.md §1, §7.3; PLAN §13.2, §13.5).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/shell/app_shell_view.dart';

import '../../fakes/test_router.dart';

void main() {
  group('T-11 · sekme yığını bağımsızlığı', () {
    testWidgets('Kulüpler’de derinleş → Etkinlikler → Kulüpler: yığın '
        'korunur', (tester) async {
      final app = await TestRouter.pumpShell(tester);
      await app.go('/clubs/c01');
      expect(app.stackDepth(GuTab.clubs), 2);

      // Başka sekmenin köküne geçiş (sekmeler arası bağlantı).
      await app.go('/events');
      expect(app.currentTab, GuTab.events);
      expect(app.stackDepth(GuTab.events), 1);
      // Kulüpler dalı görünmez ama yığını yerinde.
      expect(app.stackDepth(GuTab.clubs), 2);
      expect(find.text('/clubs/c01'), findsNothing);
      expect(find.text('/clubs/c01', skipOffstage: false), findsOneWidget);

      // Alt çubuktan dönüş: dal kaldığı yerden açılır.
      await app.tapTab(GuTab.clubs);
      expect(app.location, '/clubs/c01');
      expect(find.text('/clubs/c01'), findsOneWidget);
      expect(app.stackDepth(GuTab.clubs), 2);
      expect(app.stackDepth(GuTab.events), 1);
    });

    testWidgets('iki sekme aynı anda derin olabilir; biri diğerini '
        'değiştirmez', (tester) async {
      final app = await TestRouter.pumpShell(tester);
      await app.go('/clubs/c01/members');
      await app.go('/events/e01');
      expect(app.stackDepth(GuTab.clubs), 3);
      expect(app.stackDepth(GuTab.events), 2);

      // Etkinlikler'de geri: yalnızca o dal kısalır.
      expect(await app.systemBack(), isTrue);
      expect(app.location, '/events');
      expect(app.stackDepth(GuTab.events), 1);
      expect(app.stackDepth(GuTab.clubs), 3);

      await app.tapTab(GuTab.clubs);
      expect(app.location, '/clubs/c01/members');
    });

    testWidgets('sekme değişimi diğer dalların ekranlarını yeniden kurmaz '
        '(durum korunur)', (tester) async {
      final app = await TestRouter.pumpShell(tester);
      await app.go('/clubs/c01');
      final before = tester.element(
        find.text('/clubs/c01', skipOffstage: false),
      );
      await app.go('/events');
      await app.tapTab(GuTab.clubs);
      expect(
        identical(
          tester.element(find.text('/clubs/c01', skipOffstage: false)),
          before,
        ),
        isTrue,
      );
    });

    testWidgets('dallar tembel kurulur: ziyaret edilmeyen sekmenin yığını '
        'yoktur', (tester) async {
      final app = await TestRouter.pumpShell(tester);
      expect(app.stackDepth(GuTab.clubs), 1);
      expect(app.stackDepth(GuTab.events), 0);
      expect(app.stackDepth(GuTab.profile), 0);
      await app.tapTab(GuTab.profile);
      expect(app.stackDepth(GuTab.profile), 1);
      expect(app.stackDepth(GuTab.events), 0);
    });
  });

  group('T-11 · etkin sekmeye yeniden dokunma', () {
    int scrollTop(TestRouter app, GuTab tab) =>
        app.container.read(scrollTopRequestProvider(tab));

    testWidgets('kökteyken: liste başa kaydırılır (sayaç artar), konum '
        'değişmez', (tester) async {
      final app = await TestRouter.pumpShell(tester);
      expect(scrollTop(app, GuTab.clubs), 0);

      await app.tapTab(GuTab.clubs);
      expect(scrollTop(app, GuTab.clubs), 1);
      await app.tapTab(GuTab.clubs);
      expect(scrollTop(app, GuTab.clubs), 2);
      expect(app.location, '/clubs');
      expect(app.locationLog, ['/clubs']);
      // Diğer sekmelerin sayacı oynamaz.
      for (final tab in GuTab.values.where((tab) => tab != GuTab.clubs)) {
        expect(scrollTop(app, tab), 0, reason: tab.name);
      }
    });

    testWidgets('başka sekmeye dokunmak başa kaydırma istemez', (tester) async {
      final app = await TestRouter.pumpShell(tester);
      await app.tapTab(GuTab.events);
      expect(app.location, '/events');
      for (final tab in GuTab.values) {
        expect(scrollTop(app, tab), 0, reason: tab.name);
      }
      // Artık etkin olan sekmeye dokunuş onun sayacını artırır.
      await app.tapTab(GuTab.events);
      expect(scrollTop(app, GuTab.events), 1);
      expect(scrollTop(app, GuTab.clubs), 0);
    });

    testWidgets('yığın derinken: dalın köküne döner (başa kaydırma '
        'istenmez)', (tester) async {
      final app = await TestRouter.pumpShell(tester);
      await app.go('/clubs/c01/members');
      expect(app.stackDepth(GuTab.clubs), 3);

      // Alt çubuk derin ekranda çizilmez; kural doğrudan uygulanır.
      final shell = tester.widget<AppShellView>(find.byType(AppShellView));
      AppShellView.selectTab(
        shell: shell.navigationShell,
        tab: GuTab.clubs,
        isTabRoot: false,
        onScrollTop: (_) => fail('derin yığında başa kaydırma istenmez'),
      );
      await tester.pumpAndSettle();

      expect(app.location, '/clubs');
      expect(app.stackDepth(GuTab.clubs), 1);
    });

    testWidgets('selectTab: başka sekme kaldığı yerden açılır, köke '
        'dönmez', (tester) async {
      final app = await TestRouter.pumpShell(tester);
      await app.go('/events/e01');
      await app.go('/clubs');

      final shell = tester.widget<AppShellView>(find.byType(AppShellView));
      AppShellView.selectTab(
        shell: shell.navigationShell,
        tab: GuTab.events,
        isTabRoot: true,
        onScrollTop: (_) => fail('başka sekmede başa kaydırma istenmez'),
      );
      await tester.pumpAndSettle();
      expect(app.location, '/events/e01');
    });
  });
}
