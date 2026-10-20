// H-23 · Web düzeni (WebShell): telefon kartı + yan menü (referans proje
// düzeni). Mobil değişmez; web'de > 768 kart, ≥ 1024 kabuk sayfasında yan
// menü ve alt çubuk gizli; yan menü alt çubukla aynı sekme kuralını izler.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/shell/app_shell_view.dart';
import 'package:gu_kulupler/product/navigation/shell/web_shell.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../fakes/test_router.dart';
import '../../helpers/golden_helper.dart';
import '../../helpers/pump_app.dart';

/// `GuApp` gibi: yönlendiricinin konumunu dinleyip [WebShell]'e verir.
class _WebHarness extends StatefulWidget {
  const _WebHarness({
    required this.router,
    required this.isWeb,
    required this.child,
  });

  final GoRouter router;
  final bool isWeb;
  final Widget child;

  @override
  State<_WebHarness> createState() => _WebHarnessState();
}

class _WebHarnessState extends State<_WebHarness> {
  late Uri _location = widget.router.routerDelegate.currentConfiguration.uri;

  @override
  void initState() {
    super.initState();
    widget.router.routerDelegate.addListener(_onRoute);
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_onRoute);
    super.dispose();
  }

  void _onRoute() => scheduleMicrotask(() {
    if (!mounted) return;
    setState(
      () => _location = widget.router.routerDelegate.currentConfiguration.uri,
    );
  });

  @override
  Widget build(BuildContext context) => WebShell(
    location: _location,
    isWeb: widget.isWeb,
    child: widget.child,
  );
}

Future<TestRouter> _pump(
  WidgetTester tester, {
  required Size size,
  bool isWeb = true,
  String location = '/clubs',
  ThemeMode theme = ThemeMode.light,
}) async {
  final app = await TestRouter.pumpShell(
    tester,
    size: size,
    location: location,
    theme: theme,
    wrap: (router, navigator) =>
        _WebHarness(router: router, isWeb: isWeb, child: navigator),
  );
  await tester.pumpAndSettle();
  return app;
}

const Size _desktop = Size(1440, 900);
const Size _laptopNarrow = Size(900, 800);
const Size _tabletPortrait = Size(700, 900);

void main() {
  group('H-23 · WebShell · düzen', () {
    testWidgets('mobil (isWeb false): geniş ekranda da çerçeve ve yan menü '
        'yok, alt çubuk yerinde', (tester) async {
      await _pump(tester, size: _desktop, isWeb: false);
      expect(find.byType(GuWebFrame), findsNothing);
      expect(find.byType(GuSidebar), findsNothing);
      expect(find.byType(GuBottomNav), findsOneWidget);
    });

    testWidgets('web ≤ 768: çerçeve süssüz, alt çubuk yerinde', (tester) async {
      await _pump(tester, size: _tabletPortrait);
      expect(find.byType(GuSidebar), findsNothing);
      expect(find.byType(GuBottomNav), findsOneWidget);
      expect(tester.getSize(find.byType(AppShellView)).width, 700);
    });

    testWidgets('web 900: 768 kart, yan menü yok, alt çubuk kartta', (
      tester,
    ) async {
      await _pump(tester, size: _laptopNarrow);
      expect(find.byType(GuSidebar), findsNothing);
      expect(find.byType(GuBottomNav), findsOneWidget);
      final card = tester.getRect(find.byType(AppShellView));
      expect(card.width, GuWebLayout.cardMaxWidth);
      expect(card.center.dx, closeTo(_laptopNarrow.width / 2, 0.5));
      expect(card.top, GuWebLayout.framePadding);
    });

    testWidgets('web 1440: yan menü + kart, alt çubuk gizli', (tester) async {
      await _pump(tester, size: _desktop);
      expect(find.byType(GuSidebar), findsOneWidget);
      expect(find.byType(GuBottomNav), findsNothing);
      final card = tester.getRect(find.byType(AppShellView));
      final side = tester.getRect(find.byType(GuSidebar));
      expect(card.width, GuWebLayout.cardMaxWidth);
      expect(side.width, GuWebLayout.sidebarWidth);
      expect(card.left - side.right, closeTo(GuWebLayout.sidebarGap, 0.5));
      // Kart + yan menü ortada.
      expect(
        (side.left + card.right) / 2,
        closeTo(_desktop.width / 2, 0.5),
      );
    });

    testWidgets('kabuk dışı sayfada yan menü yok', (tester) async {
      await _pump(tester, size: _desktop, location: '/outside');
      expect(find.byType(GuSidebar), findsNothing);
      expect(find.text('/outside'), findsOneWidget);
    });

    testWidgets('pencere daralınca yan menü kapanır, alt çubuk döner', (
      tester,
    ) async {
      await _pump(tester, size: _desktop);
      expect(find.byType(GuSidebar), findsOneWidget);
      tester.view.physicalSize = _laptopNarrow * tester.view.devicePixelRatio;
      await tester.pumpAndSettle();
      expect(find.byType(GuSidebar), findsNothing);
      expect(find.byType(GuBottomNav), findsOneWidget);
    });
  });

  group('H-23 · WebShell · yan menü', () {
    testWidgets('sekme seçimi alt çubukla aynı: başka sekme açılır; derin '
        'ekranda etkin sekme köke döner; anahtarlar NAV.tab.*', (tester) async {
      final app = await _pump(tester, size: _desktop);
      final sidebar = find.byType(GuSidebar);
      await tester.tap(
        find.descendant(
          of: sidebar,
          matching: find.byKey(AppShellView.tabKeys[GuTab.events]!),
        ),
      );
      await tester.pumpAndSettle();
      expect(app.location, '/events');

      await app.go('/clubs/c01');
      expect(find.byType(GuSidebar), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: sidebar,
          matching: find.byKey(AppShellView.tabKeys[GuTab.clubs]!),
        ),
      );
      await tester.pumpAndSettle();
      expect(app.location, '/clubs');
    });

    testWidgets('seçili satır konumdan; admin sekmesi yalnızca süper adminde', (
      tester,
    ) async {
      await _pump(tester, size: _desktop, location: '/notifications');
      final sidebar = tester.widget<GuSidebar>(find.byType(GuSidebar));
      expect(sidebar.items, hasLength(4));
      expect(sidebar.currentIndex, GuTab.notifications.index);
    });
  });

  group('H-23 · WebShell · golden', () {
    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('1440 × 900 yan menü + kart (${theme.name})', (tester) async {
        await _pump(tester, size: _desktop, theme: theme);
        await expectLater(
          find.byKey(kPumpAppBoundaryKey),
          matchesGoldenFile(
            goldenUri(goldenPath('H-23_web_shell', theme, const Locale('tr'))),
          ),
        );
      });
    }
  });
}
