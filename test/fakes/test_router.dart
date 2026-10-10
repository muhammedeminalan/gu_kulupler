// Router test düzeneği (PLAN §16.3 `TestRouter`): gerçek `GoRouter` + sahte
// oturum.
//
//   // Uygulamanın gerçek rota ağacı ve yönlendirmesi:
//   final app = await TestRouter.pump(tester, session: FakeSessionStates.active);
//   app.go('/admin');            // → yönlendirme `/clubs`
//   app.session = FakeSessionStates.signedOut;
//
//   // Gerçek `AppShellView` + derin test dalları (`/clubs/c01/deep` …):
//   final shell = await TestRouter.pumpShell(tester);
//
// Oturum `sessionViewModelProvider.overrideWithBuild` ile verilir (gerçek
// `SessionViewModel` sınıfı, sahte başlangıç state'i); `session=` state'i
// yerinde değiştirir ve router yeniden değerlendirir.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/app_redirect.dart';
import 'package:gu_kulupler/product/navigation/app_router.dart';
import 'package:gu_kulupler/product/navigation/navigator_keys.dart';
import 'package:gu_kulupler/product/navigation/session_refresh_listenable.dart';
import 'package:gu_kulupler/product/navigation/shell/app_shell_view.dart';

import '../helpers/pump_app.dart';
import 'fake_feedback_service.dart';
import 'fake_session_states.dart';

final class TestRouter {
  TestRouter._(this._tester, this.router, this.container, this.feedback) {
    router.routerDelegate.addListener(_log);
    addTearDown(() => router.routerDelegate.removeListener(_log));
    _log();
  }

  /// Uygulamanın **gerçek** rota ağacını ve yönlendirmesini [session] ile
  /// çizer; açılış yolu `/splash`'tir, [location] verilirse oraya gidilir.
  static Future<TestRouter> pump(
    WidgetTester tester, {
    SessionState session = FakeSessionStates.active,
    String? location,
    List<Override> overrides = const [],
    Size size = const Size(390, 844),
    TargetPlatform platform = TargetPlatform.android,
  }) async {
    final feedback = FakeFeedbackService();
    await _unmountPrevious(tester);
    await tester.pumpAppRouter(
      size: size,
      platform: platform,
      overrides: [
        sessionViewModelProvider.overrideWithBuild((ref, notifier) => session),
        feedbackServiceProvider.overrideWithValue(feedback),
        ...overrides,
      ],
    );
    final container = _containerOf(tester);
    final router = container.read(appRouterProvider);
    final harness = TestRouter._(tester, router, container, feedback);
    await tester.pumpAndSettle();
    if (location != null) await harness.go(location);
    return harness;
  }

  /// Gerçek `AppShellView`'ı derin test dallarıyla çizer: her sekmede kökün
  /// altında üç düzey (`/clubs/c01/manage/members` gibi her yol eşleşir) ve
  /// kabuk dışında `/outside`. [redirect] `true` ise uygulamanın
  /// yönlendirmesi (`AppRedirect`) ve oturum dinleyicisi de bağlanır.
  static Future<TestRouter> pumpShell(
    WidgetTester tester, {
    SessionState session = FakeSessionStates.active,
    String location = AppPaths.clubs,
    bool redirect = false,
    List<Override> overrides = const [],
    Size size = const Size(390, 844),
    TargetPlatform platform = TargetPlatform.android,
  }) async {
    final feedback = FakeFeedbackService();
    final allOverrides = [
      sessionViewModelProvider.overrideWithBuild((ref, notifier) => session),
      feedbackServiceProvider.overrideWithValue(feedback),
      ...overrides,
    ];
    GoRouter? created;
    await _unmountPrevious(tester);
    await tester.pumpAppRouter(
      // Yönlendirme dinleyicisi kapsayıcıya bağlıdır; router ilk kurulumda
      // bir kez üretilir.
      routerOf: (ref) => created ??= _shellRouter(
        location,
        redirect ? ref.read(sessionRefreshListenableProvider) : null,
      ),
      size: size,
      platform: platform,
      overrides: allOverrides,
    );
    final router = created!;
    addTearDown(router.dispose);
    final harness = TestRouter._(
      tester,
      router,
      _containerOf(tester),
      feedback,
    );
    await tester.pumpAndSettle();
    return harness;
  }

  static GoRouter _shellRouter(
    String location,
    SessionRefreshListenable? listenable,
  ) => GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: location,
    redirect: listenable == null ? null : AppRedirect.goRouterRedirect,
    refreshListenable: listenable,
    routes: [
      GoRoute(
        path: '/outside',
        builder: (context, state) => const TestPage('/outside'),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShellView(navigationShell: navigationShell),
        branches: [
          for (final tab in GuTab.values)
            StatefulShellBranch(
              navigatorKey: tab.navigatorKey,
              routes: [
                GoRoute(
                  path: tab.rootPath,
                  builder: (context, state) => TestPage(tab.rootPath),
                  routes: [
                    GoRoute(
                      path: ':a',
                      builder: _page,
                      routes: [
                        GoRoute(
                          path: ':b',
                          builder: _page,
                          routes: [GoRoute(path: ':c', builder: _page)],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    ],
  );

  /// Sayfa kendi yolunu gösterir (alt rotaların parçaları hariç).
  static Widget _page(BuildContext context, GoRouterState state) =>
      TestPage(state.matchedLocation);

  final WidgetTester _tester;

  /// Çizilen router.
  final GoRouter router;

  /// Ağacın `ProviderContainer`'ı.
  final ProviderContainer container;

  /// Yönlendirme toast'larının düştüğü sahte servis.
  final FakeFeedbackService feedback;

  /// Router her yapılandırma değiştirdiğinde eklenen konumlar (tekrarsız).
  final List<String> locationLog = <String>[];

  /// Geçerli konum (sorgusuyla).
  String get location =>
      router.routerDelegate.currentConfiguration.uri.toString();

  /// Etkin dalın sekmesi; kabuk dışındaysa `null`.
  GuTab? get currentTab => GuTab.ofLocation(Uri.parse(location));

  /// Geçerli oturum.
  SessionState get session => container.read(sessionViewModelProvider);

  /// Oturumu değiştirir; router yönlendirmeyi yeniden değerlendirir.
  set session(SessionState value) {
    // `state` test için görünürdür (riverpod `@visibleForTesting`).
    container.read(sessionViewModelProvider.notifier).state = value;
  }

  /// [location] yoluna `go` ile gider ve geçişi bitirir.
  Future<void> go(String location) async {
    router.go(location);
    await _tester.pumpAndSettle();
  }

  /// [tab] dalının gezginindeki sayfa sayısı (yığın derinliği); dal henüz
  /// kurulmadıysa `0`.
  int stackDepth(GuTab tab) =>
      tab.navigatorKey.currentState?.widget.pages.length ?? 0;

  /// Sistem geri tuşu; `true` → uygulama ele aldı, `false` → sisteme bırakıldı
  /// (uygulamadan çıkış).
  Future<bool> systemBack() async {
    final handled = await _tester.binding.handlePopRoute();
    await _tester.pumpAndSettle();
    return handled;
  }

  /// Alt çubuktaki [tab] sekmesine dokunur.
  Future<void> tapTab(GuTab tab) async {
    await _tester.tap(find.byKey(AppShellView.tabKeys[tab]!));
    await _tester.pumpAndSettle();
  }

  void _log() {
    final current = location;
    if (locationLog.isEmpty || locationLog.last != current) {
      locationLog.add(current);
    }
  }

  /// Aynı testte ikinci kez çizmeden önce önceki ağacı söker: router'lar
  /// uygulamanın küresel gezgin anahtarlarını paylaşır ve iki ağaç aynı
  /// karede aynı anahtarı taşıyamaz.
  static Future<void> _unmountPrevious(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox.shrink());

  static ProviderContainer _containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
}

/// Test dallarının sayfası: yolunu metin olarak gösterir
/// (`find.text('/clubs/c01')`).
class TestPage extends StatelessWidget {
  const TestPage(this.path, {super.key});

  /// Sayfanın yolu.
  final String path;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(path)));
}
