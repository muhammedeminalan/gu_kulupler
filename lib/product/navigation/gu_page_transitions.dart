import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_ui/gu_ui.dart';

/// Rota sayfa geçişleri (D-06, PLAN §13.6, navigation.md §5).
///
/// Varsayılan [platform]'dur (`GuTheme.pageTransitionsTheme`: iOS / macOS
/// Cupertino, Android predictive back). [fade] yalnızca §5 istisnalarında:
/// splash → ilk ekran, giriş sonrası kabuğa geçiş, çıkış / hesap silme.
/// `CustomTransitionPage` yalnızca bu dosyada kurulur (`push_scan_test` P04).
abstract final class GuPageTransitions {
  /// Solma — `GuMotion.base` + `easeStandard`; azaltılmış harekette
  /// (`MediaQuery.disableAnimations`) süre sıfır.
  static Page<T> fade<T>({
    required BuildContext context,
    required LocalKey key,
    required Widget child,
  }) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : GuMotion.base;
    return CustomTransitionPage<T>(
      key: key,
      child: child,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(
            opacity: animation.drive(CurveTween(curve: GuMotion.easeStandard)),
            child: child,
          ),
    );
  }

  /// Platform varsayılanı (`ThemeData.pageTransitionsTheme`).
  static Page<T> platform<T>({required LocalKey key, required Widget child}) =>
      MaterialPage<T>(key: key, child: child);
}

/// Rotanın sayfasını **platform geçişiyle** kurar (D-06): gövde `build`'den
/// gelir, sayfa `MaterialPage`'dir (`GuTheme.pageTransitionsTheme` — iOS
/// kenardan geri kaydırma, Android predictive back).
///
/// Solma istisnası ([FadePageMixin]) dışındaki **her** rota sınıfı bunu
/// kullanır. Sayfa go_router'ın varsayılanına bırakılmaz: go_router uygulama
/// türünü `package:material_ui`'nin `MaterialApp`'ına bakarak seçer; bu
/// uygulama `package:flutter/material.dart` kullandığından varsayılan sayfa
/// geçişsiz (`NoTransitionPage`) olurdu.
mixin PlatformPageMixin on GoRouteData {
  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      GuPageTransitions.platform<void>(
        key: state.pageKey,
        child: build(context, state),
      );
}

/// Rotanın sayfasını **solmayla** kurar (navigation.md §5 istisnaları: açılış,
/// oturum öncesi rotalar); gövde `build`'den gelir.
mixin FadePageMixin on GoRouteData {
  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      GuPageTransitions.fade<void>(
        context: context,
        key: state.pageKey,
        child: build(context, state),
      );
}
