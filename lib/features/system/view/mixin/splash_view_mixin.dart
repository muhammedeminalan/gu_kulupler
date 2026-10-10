import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/system/provider/splash_view_model.dart';
import 'package:gu_kulupler/features/system/view/splash_view.dart';
import 'package:gu_kulupler/product/navigation/routes/system_routes.dart';
import 'package:gu_kulupler/product/navigation/splash_hold.dart';
import 'package:gu_ui/gu_ui.dart';

/// SYS-01 davranışı: logo animasyonu, zaman aşımı ve hata yönlendirmesi.
///
/// * Logo: `@keyframes splash` (css:423) — `GuMotion.splash` süresince
///   ölçek .7 → 1.05 (%60) → 1, opaklık 0 → 1 (%60); her kare aralığı
///   `easeEmphasized`. Azaltılmış harekette anında biter.
/// * Açılıştan **çıkışı router yapar** (oturum çözülünce R2–R7) — ama logo
///   animasyonu bitmeden değil: açılış beklemesi (`SplashHold`) animasyon
///   tamamlanınca kaldırılır (architecture §4: en az animasyon süresi).
/// * Buradaki tek gezinme başarısızlıktır: oturum hata verdiyse ya da
///   `Limits.splashTimeout` içinde çözülemediyse — logo animasyonu bittikten
///   sonra — SYS-02'ye gidilir.
mixin SplashViewMixin
    on ConsumerState<SplashView>, SingleTickerProviderStateMixin<SplashView> {
  /// Logo animasyonunun denetleyicisi.
  late final AnimationController logoController = AnimationController(
    vsync: this,
  );

  /// Logo ölçeği: .7 → 1.05 → 1.
  late final Animation<double> logoScale = logoController.drive(
    TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: GuMotion.splashStartScale,
          end: GuMotion.splashPeakScale,
        ).chain(CurveTween(curve: GuMotion.easeEmphasized)),
        weight: GuMotion.splashPeakAt,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: GuMotion.splashPeakScale,
          end: 1,
        ).chain(CurveTween(curve: GuMotion.easeEmphasized)),
        weight: 1 - GuMotion.splashPeakAt,
      ),
    ]),
  );

  /// Logo opaklığı: tepe karesine kadar 0 → 1, sonra 1.
  late final Animation<double> logoOpacity = logoController.drive(
    TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0,
          end: 1,
        ).chain(CurveTween(curve: GuMotion.easeEmphasized)),
        weight: GuMotion.splashPeakAt,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1),
        weight: 1 - GuMotion.splashPeakAt,
      ),
    ]),
  );

  Timer? _timeout;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    logoController.addStatusListener(_onLogoStatus);
    ref
      ..listenManual(splashViewModelProvider, (_, _) => _routeIfFailed())
      ..listenManual(
        sessionViewModelProvider.select((session) => session.isError),
        (_, _) => _routeIfFailed(),
      );
    // Sağlayıcı ilk kare kurulurken değiştirilemez; açılış ilk karenin
    // ardından başlar.
    WidgetsBinding.instance.addPostFrameCallback((_) => _begin());
  }

  @override
  void dispose() {
    _timeout?.cancel();
    logoController.dispose();
    super.dispose();
  }

  void _begin() {
    if (!mounted) return;
    ref.read(splashViewModelProvider.notifier).start();
    _timeout = Timer(Limits.splashTimeout, _onTimeout);
    logoController.duration = context.gu.duration(GuMotion.splash);
    unawaited(logoController.forward());
  }

  void _onTimeout() {
    if (!mounted) return;
    ref.read(splashViewModelProvider.notifier).onTimeout();
  }

  void _onLogoStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    ref.read(splashViewModelProvider.notifier).onAnimationDone();
    // Açılış en az animasyon kadar görünür; bundan sonra router çıkarabilir.
    ref.read(splashHoldProvider.notifier).release();
  }

  /// Oturum hata verdiyse ya da zaman aşımı olduysa SYS-02'ye geçer.
  void _routeIfFailed() {
    if (!mounted || _leaving) return;
    final splash = ref.read(splashViewModelProvider);
    if (!splash.isAnimationDone) return;
    final failed =
        splash.isTimedOut || ref.read(sessionViewModelProvider).isError;
    if (!failed) return;
    _leaving = true;
    const ErrorRoute().go(context);
  }
}
