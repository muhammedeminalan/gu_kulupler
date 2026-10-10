import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/icons/gu_icon.dart';
import 'package:gu_ui/src/icons/gu_icons.dart';
import 'package:gu_ui/src/tokens/gu_motion.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/widgets/feedback/gu_spinner.dart';

/// Çek-yenile sarmalayıcısı — prototip `Scroll` (`ui.js:154–164`), CSS
/// `.screen-scroll` `.no-safe` (css:123–125). Özel 1:1 uygulama (CD-28):
/// Material `RefreshIndicator` ve `CupertinoSliverRefreshControl`
/// kullanılmaz.
///
/// [child] dikey kaydırılabilir olmalıdır. Liste en üstteyken aşağı sürükleme
/// içeriğin üstünde bir gösterge satırı açar (içerik aşağı itilir):
///
/// * **çekme**: yükseklik `min(90, dy × .6)` (ui.js:159); `arrow-up` 20
///   `text.muted`, 60'a kadar 180° (aşağı bakar), 60'ı geçince 0°
///   (`GuMotion.base`).
/// * **bırakma**: yükseklik 60'ı geçmişse (ui.js:160 `pull > 60`) [onRefresh]
///   bir kez çağrılır; `Future` bitene kadar satır 48 px + `GuSpinner`
///   (`text.primary`), yükseklik `GuMotion.base` ile oturur. Aksi halde satır
///   anında kapanır. Prototipteki 700 ms sahte gecikme yazılmaz (gerçek
///   `Future`).
/// * `dy`, listenin dikey sürüklemeyi kazandığı noktadan ölçülür (dokunma
///   payı sonrası); yatay kaydırma ve dokunmalar göstergeyi oynatmaz. Çekme
///   açıkken liste kaymaz, üst kenarda esnemez / parlamaz (alt kenar platform
///   davranışında kalır); içerik kısa olsa da çekilebilir. Yenileme sürerken
///   yeni çekme başlamaz.
/// * Gösterge dekoratiftir (`aria-hidden`).
/// * Kaydırma sonu dolgusu (`güvenli alt alan + 8`, css:123; [noSafe] → 0,
///   css:125) [child]'a `MediaQuery.padding.bottom` olarak verilir: dolgusuz
///   `ListView` / `GridView` bunu kendiliğinden uygular, `CustomScrollView`
///   `SliverSafeArea` ile alır.
/// * Aksiyon anahtarı çağırandan: [refreshActionKey]
///   (`GuKey.action('CLB-01.refresh')`, CD-111). Kaydırma belleği
///   (`PageStorageKey`) ve başa kaydırma kabuğa aittir.
class GuRefresh extends StatefulWidget {
  const GuRefresh({
    required this.onRefresh,
    required this.child,
    this.refreshActionKey,
    this.noSafe = false,
    super.key,
  });

  /// Yenileme; `Future` bitene kadar gösterge açık kalır.
  final Future<void> Function() onRefresh;

  /// Dikey kaydırılabilir içerik.
  final Widget child;

  /// Çekme alanının anahtarı (prototip `data-action=refreshAction`).
  final Key? refreshActionKey;

  /// Kaydırma sonu dolgusu 0 (`.no-safe`: CLB-03, EVT-02).
  final bool noSafe;

  @override
  State<GuRefresh> createState() => _GuRefreshState();
}

class _GuRefreshState extends State<GuRefresh> {
  /// Ok ikonunun "henüz yetmedi" dönüşü: 180° (ui.js:162).
  static const double _flippedTurns = 0.5;

  ScrollBehavior? _base;
  late ScrollBehavior _behavior;

  bool _atTop = true;
  int? _lastPointer;
  int? _dragPointer;
  double _startY = 0;
  double _pull = 0;
  bool _refreshing = false;

  bool _isPulling() => _pull > 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Davranış nesnesi sabit tutulur: her `build`'de yenisi verilirse
    // `Scrollable` konumunu baştan kurar.
    final base = ScrollConfiguration.of(context);
    if (identical(base, _base)) return;
    _base = base;
    _behavior = base.copyWith(
      physics: _GuRefreshPhysics(
        isPulling: _isPulling,
        parent: base.getScrollPhysics(context),
      ),
    );
  }

  /// Yalnızca doğrudan çocuğun dikey kaydırması izlenir (iç içe yatay
  /// şeritler `depth > 0` gelir).
  bool _trackMetrics(ScrollMetrics metrics, int depth) {
    if (depth == 0 && metrics.axis == Axis.vertical) {
      _atTop = metrics.pixels <= metrics.minScrollExtent;
    }
    return false;
  }

  bool _handleScroll(ScrollNotification notification) {
    _trackMetrics(notification.metrics, notification.depth);
    if (notification is ScrollStartNotification &&
        notification.depth == 0 &&
        notification.metrics.axis == Axis.vertical) {
      // ui.js:157: kaydırma üstte değilse çekme başlamaz.
      final details = notification.dragDetails;
      if (details != null && _atTop && !_refreshing && _dragPointer == null) {
        _dragPointer = _lastPointer;
        _startY = details.globalPosition.dy;
      }
    }
    return false;
  }

  void _handleMove(PointerMoveEvent event) {
    if (event.pointer != _dragPointer) return;
    final dy = event.position.dy - _startY;
    final pull = dy > 0 && _atTop
        ? math.min(GuSizes.refreshMaxPull, dy * GuSizes.refreshPullFactor)
        : 0.0;
    if (pull != _pull) setState(() => _pull = pull);
  }

  void _handleEnd(PointerEvent event, {required bool released}) {
    if (event.pointer != _dragPointer) return;
    _dragPointer = null;
    if (_pull == 0) return;
    final trigger = released && _pull > GuSizes.refreshTriggerDistance;
    setState(() {
      _pull = 0;
      _refreshing = trigger;
    });
    if (trigger) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  bool _handleIndicator(OverscrollIndicatorNotification notification) {
    if (notification.depth == 0 && notification.leading) {
      notification.disallowIndicator();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final media = MediaQuery.of(context);
    final safeBottom = math.max<double>(
      0,
      media.viewPadding.bottom - media.viewInsets.bottom,
    );
    final Widget? indicator;
    if (_refreshing) {
      indicator = GuSpinner(color: gu.colors.textPrimary);
    } else if (_pull > 0) {
      indicator = AnimatedRotation(
        turns: _pull > GuSizes.refreshTriggerDistance ? 0 : _flippedTurns,
        duration: gu.duration(GuMotion.base),
        curve: GuMotion.easeCss,
        child: GuIcon(
          GuIcons.arrowUp,
          size: GuSizes.refreshIcon,
          color: gu.colors.textMuted,
        ),
      );
    } else {
      indicator = null;
    }
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) =>
          _trackMetrics(notification.metrics, notification.depth),
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleScroll,
        child: Listener(
          key: widget.refreshActionKey,
          onPointerDown: (event) => _lastPointer = event.pointer,
          onPointerMove: _handleMove,
          onPointerUp: (event) => _handleEnd(event, released: true),
          onPointerCancel: (event) => _handleEnd(event, released: false),
          child: Column(
            children: [
              ExcludeSemantics(
                child: ClipRect(
                  // ui.js:162: yükseklik yalnızca yenilemeye geçerken
                  // canlanır (`transition: refreshing ? 'height .2s' : 'none'`).
                  child: AnimatedContainer(
                    duration: _refreshing
                        ? gu.duration(GuMotion.base)
                        : Duration.zero,
                    curve: GuMotion.easeCss,
                    height: _refreshing
                        ? GuSizes.refreshIndicatorHeight
                        : _pull,
                    child: OverflowBox(
                      minHeight: GuSizes.refreshIndicatorHeight,
                      maxHeight: GuSizes.refreshIndicatorHeight,
                      child: Center(child: indicator),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ScrollConfiguration(
                  behavior: _behavior,
                  child: NotificationListener<OverscrollIndicatorNotification>(
                    onNotification: _handleIndicator,
                    child: MediaQuery(
                      data: media.copyWith(
                        padding: media.padding.copyWith(
                          bottom: widget.noSafe
                              ? 0
                              : safeBottom + GuSizes.screenScrollBottomExtra,
                        ),
                      ),
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// [GuRefresh] çocuğunun dikey kaydırma fiziği: platform fiziğini sarar.
///
/// * içerik kısa olsa da sürükleme kabul edilir (çekme başlayabilsin);
/// * üst kenarda taşma yoktur (iOS esnemesi gösterge satırıyla çakışmasın);
/// * çekme açıkken ([isPulling]) kullanıcı sürüklemesi listeyi kaydırmaz —
///   parmak geri çıkarken önce gösterge kapanır.
///
/// Yatay (iç içe) kaydırıcılara dokunmaz.
class _GuRefreshPhysics extends ScrollPhysics {
  const _GuRefreshPhysics({required this.isPulling, super.parent});

  final ValueGetter<bool> isPulling;

  @override
  _GuRefreshPhysics applyTo(ScrollPhysics? ancestor) =>
      _GuRefreshPhysics(isPulling: isPulling, parent: buildParent(ancestor));

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) =>
      position.axis == Axis.vertical || super.shouldAcceptUserOffset(position);

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) =>
      position.axis == Axis.vertical && isPulling()
      ? 0
      : super.applyPhysicsToUserOffset(position, offset);

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (position.axis == Axis.vertical) {
      final top = position.minScrollExtent;
      // Üst kenarda dışarı doğru hareket: tamamı taşma sayılır.
      if (value < position.pixels && position.pixels <= top) {
        return value - position.pixels;
      }
      // Üst kenara çarpma.
      if (value < top && top < position.pixels) return value - top;
    }
    return super.applyBoundaryConditions(position, value);
  }
}
