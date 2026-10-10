import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/core/env/app_environment.dart';
import 'package:gu_kulupler/features/system/debug_menu/view/debug_menu_view.dart';
import 'package:gu_kulupler/features/system/view/error_view.dart';
import 'package:gu_kulupler/features/system/view/not_found_view.dart';
import 'package:gu_kulupler/features/system/view/offline_view.dart';
import 'package:gu_kulupler/features/system/view/splash_view.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/gu_page_transitions.dart';

part 'system_routes.g.dart';

/// SYS-01 Açılış — `/splash`. Oturum çözülünce yönlendirme buradan çıkarır;
/// ilk ekrana geçiş solmadır (navigation.md §5).
@TypedGoRoute<SplashRoute>(path: AppPaths.splash)
final class SplashRoute extends GoRouteData with $SplashRoute, FadePageMixin {
  /// Açılış rotası.
  const SplashRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const SplashView();
}

/// SYS-02 Hata — `/error?from=`.
@TypedGoRoute<ErrorRoute>(path: AppPaths.error)
final class ErrorRoute extends GoRouteData with $ErrorRoute, PlatformPageMixin {
  /// [from]: "Yeniden dene" ile dönülecek yol.
  const ErrorRoute({this.from});

  /// Yeniden denenecek yol; yoksa `null`.
  final String? from;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      ErrorView(from: from);
}

/// SYS-03 Çevrimdışı (tam ekran) — `/offline`.
@TypedGoRoute<OfflineRoute>(path: AppPaths.offline)
final class OfflineRoute extends GoRouteData
    with $OfflineRoute, PlatformPageMixin {
  /// Çevrimdışı rotası.
  const OfflineRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const OfflineView();
}

/// SYS-04 İçerik yok — `/not-found`. Router'ın `errorBuilder`'ı da (bilinmeyen
/// yol) bu rotanın gövdesini kurar.
@TypedGoRoute<NotFoundRoute>(path: AppPaths.notFound)
final class NotFoundRoute extends GoRouteData
    with $NotFoundRoute, PlatformPageMixin {
  /// "İçerik yok" rotası.
  const NotFoundRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const NotFoundView();
}

/// DebugMenu — `/debug` (tasarım kimliği yok; K-E, CD-69).
///
/// Her derlemede rota ağacındadır; gövde derleme sabitiyle seçilir, böylece
/// release'te `DebugMenuView` dalı ağaçtan düşer. Guard: R14.
@TypedGoRoute<DebugMenuRoute>(path: AppPaths.debug)
final class DebugMenuRoute extends GoRouteData
    with $DebugMenuRoute, PlatformPageMixin {
  /// DebugMenu rotası.
  const DebugMenuRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      AppEnvironment.debugMenuEnabled
      ? const DebugMenuView()
      : const NotFoundView();
}
