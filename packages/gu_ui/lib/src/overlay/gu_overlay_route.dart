import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/tokens/gu_motion.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';

/// Overlay içeriğinin sayfadaki yeri ([GuOverlayPage]).
enum GuOverlayAnchor {
  /// Alt kenar — sheet (`.sheet{bottom:0}` css:268).
  bottom,

  /// Dikey orta — dialog (`.dialog{top:50%}` css:282).
  center,

  /// Üst kenar — açılır menü; konum dolgusu içeriğin kendisindedir
  /// (`.popmenu{top:…}` css:279).
  top,
}

/// Rota animasyonunu içeriğe uygulayan kurucu ([showGuOverlay]).
typedef GuOverlayTransition =
    Widget Function(Animation<double> animation, Widget child);

/// gu_ui overlay'lerinin (sheet / dialog / açılır menü) ortak rotası —
/// prototip `.overlay-root` + `.scrim` (css:266–267). Paket içi yardımcıdır;
/// barrel'dan dışa aktarılmaz, view'dan çağrılmaz (CD-113).
///
/// * Scrim rotanın bariyeridir (`ModalBarrier`): renk [barrierColor],
///   solma [barrierCurve]; dokunma `Navigator.maybePop` çağırır, böylece
///   çerçevedeki `PopScope` (kirli form, kapatılamaz dialog) devreye girer.
/// * Odak tuzağı: rota `FocusScope`'u + `TraversalEdgeBehavior.closedLoop`
///   (`useFocusTrap`, core.js:659–672); Esc yalnızca [barrierDismissible].
/// * Geçiş sayfanın tümüne değil yalnızca içeriğe uygulanır
///   ([GuOverlayPage]); `buildTransitions` çocuğu olduğu gibi döndürür.
class GuOverlayRoute<T> extends PopupRoute<T> {
  GuOverlayRoute({
    required this.pageBuilder,
    required this.transitionDuration,
    required this.barrierCurve,
    required this.barrierDismissible,
    this.barrierColor,
    this.barrierLabel,
    super.settings,
  }) : super(traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop);

  /// Sayfa içeriği (bir kez kurulur; animasyon nesneleri verilir).
  final RoutePageBuilder pageBuilder;

  @override
  final Duration transitionDuration;

  @override
  final Curve barrierCurve;

  @override
  final bool barrierDismissible;

  @override
  final Color? barrierColor;

  @override
  final String? barrierLabel;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => pageBuilder(context, animation, secondaryAnimation);
}

/// Overlay sayfa düzeni: içerik [anchor]'a göre yerleşir, kalan tam genişlik
/// bant [scrimKey] anahtarını taşır.
///
/// * İçerik sayfa genişliğinde, **sınırsız yükseklikte** ölçülür: çerçeveler
///   yüksekliklerini `MediaQuery`'den kendileri sınırlar; `GuContentColumn`
///   bu sayede dikeyde içeriğe sarılır.
/// * Klavye: sayfa `viewInsets.bottom` kadar yukarıda biter (K-07).
/// * Bant saydam bir işaretçidir (`MetaData`, translucent): dokunma alttaki
///   bariyere geçer; `find.byKey(scrimKey)` içerikle örtülmeyen bir nokta
///   verir (`<ID>.scrim`, D-18).
class GuOverlayPage extends StatelessWidget {
  const GuOverlayPage({
    required this.anchor,
    required this.child,
    this.scrimKey,
    super.key,
  });

  /// İçeriğin yeri.
  final GuOverlayAnchor anchor;

  /// Geçişi uygulanmış içerik.
  final Widget child;

  /// Scrim bandının anahtarı.
  final Key? scrimKey;

  @override
  Widget build(BuildContext context) => Padding(
    padding: GuInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: CustomMultiChildLayout(
      delegate: _GuOverlayLayout(anchor),
      children: [
        LayoutId(
          id: _GuOverlaySlot.scrim,
          child: MetaData(key: scrimKey, behavior: HitTestBehavior.translucent),
        ),
        LayoutId(id: _GuOverlaySlot.content, child: child),
      ],
    ),
  );
}

enum _GuOverlaySlot { scrim, content }

class _GuOverlayLayout extends MultiChildLayoutDelegate {
  _GuOverlayLayout(this.anchor);

  final GuOverlayAnchor anchor;

  @override
  void performLayout(Size size) {
    final content = layoutChild(
      _GuOverlaySlot.content,
      BoxConstraints.tightFor(width: size.width),
    );
    final free = math.max<double>(0, size.height - content.height);
    final top = switch (anchor) {
      GuOverlayAnchor.bottom => free,
      GuOverlayAnchor.center => free / 2,
      GuOverlayAnchor.top => 0.0,
    };
    positionChild(_GuOverlaySlot.content, Offset(0, top));
    // İçeriğin örtmediği bant: menüde altı, sheet / dialogda üstü.
    final band = anchor == GuOverlayAnchor.top
        ? Rect.fromLTRB(0, size.height - free, size.width, size.height)
        : Rect.fromLTRB(0, 0, size.width, top);
    layoutChild(_GuOverlaySlot.scrim, BoxConstraints.tight(band.size));
    positionChild(_GuOverlaySlot.scrim, band.topLeft);
  }

  @override
  bool shouldRelayout(_GuOverlayLayout oldDelegate) =>
      oldDelegate.anchor != anchor;
}

/// `@keyframes dialogIn` (css:415): solma + ölçek `.96 → 1`,
/// `--ease-standard` — dialog ve açılır menü (css:279, 282).
Widget guOverlayFadeScale(Animation<double> animation, Widget child) {
  final curve = CurveTween(curve: GuMotion.easeStandard);
  return FadeTransition(
    opacity: animation.drive(curve),
    child: ScaleTransition(
      scale: animation.drive(
        Tween<double>(begin: GuMotion.dialogEnterScale, end: 1).chain(curve),
      ),
      child: child,
    ),
  );
}

/// [builder] içeriğini [GuOverlayRoute] ile açar; rota kapanınca `pop`
/// sonucunu döndürür.
///
/// [duration] çağıranda `context.gu.duration(…)` ile çözülür (azaltılmış
/// harekette `Duration.zero`). [barrierColor] `null` → saydam scrim (menü).
Future<T?> showGuOverlay<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  required GuOverlayAnchor anchor,
  required GuOverlayTransition transition,
  required Duration duration,
  required Curve barrierCurve,
  required bool barrierDismissible,
  required bool useRootNavigator,
  Color? barrierColor,
  String? barrierLabel,
  Key? scrimKey,
}) => Navigator.of(context, rootNavigator: useRootNavigator).push<T>(
  GuOverlayRoute<T>(
    transitionDuration: duration,
    barrierCurve: barrierCurve,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    barrierLabel: barrierLabel,
    pageBuilder: (context, animation, _) => GuOverlayPage(
      anchor: anchor,
      scrimKey: scrimKey,
      child: transition(animation, Builder(builder: builder)),
    ),
  ),
);
