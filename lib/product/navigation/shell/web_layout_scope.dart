import 'package:flutter/widgets.dart';

/// Web yan menüsünün açık olup olmadığını kart içindeki sayfalara bildirir
/// (H-23; `WebShell` kurar). Yan menü açıkken alt sekme çubuğu çizilmez ve
/// toast alt çubuk boşluğu bırakmaz. Mobilde ve dar web penceresinde yoktur:
/// [hasSidebar] `false` döner.
final class WebLayoutScope extends InheritedWidget {
  const WebLayoutScope({
    required this.isSidebarVisible,
    required super.child,
    super.key,
  });

  /// Yan menü açık mı?
  final bool isSidebarVisible;

  /// [context] üstünde yan menü açık mı? (Kapsam yoksa `false`.)
  static bool hasSidebar(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<WebLayoutScope>()
          ?.isSidebarVisible ??
      false;

  @override
  bool updateShouldNotify(WebLayoutScope oldWidget) =>
      isSidebarVisible != oldWidget.isSidebarVisible;
}
