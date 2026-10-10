import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/features/system/provider/splash_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'splash_view_model.g.dart';

/// Açılış ekranının ViewModel'i (SYS-01; PLAN §12.3).
///
/// Oturumu **çözmez** — o iş `SessionViewModel`'indir ve açılıştan çıkışı
/// router yönlendirmesi yapar (R1–R7). Burada yalnızca açılışın kendi durumu
/// tutulur: logo animasyonu bitti mi, oturum beklenen sürede çözülemedi mi.
/// Süre sayacı view'dadır (`GuMotion.splash`, `Limits.splashTimeout`;
/// zamanlayıcı yok); burası olayları kaydeder.
@riverpod
final class SplashViewModel extends _$SplashViewModel
    with ProjectDependencyMixin {
  @override
  SplashState build() => SplashState(version: appInfoService.version);

  /// Açılışı başlatır: başlangıç anını kaydeder. Yinelenen çağrı etkisizdir.
  void start() {
    if (state.startedAt != null) return;
    state = state.copyWith(startedAt: appClock.nowUtc());
  }

  /// Logo animasyonu tamamlandı.
  void onAnimationDone() {
    if (state.isAnimationDone) return;
    state = state.copyWith(isAnimationDone: true);
  }

  /// Oturum `Limits.splashTimeout` içinde çözülemedi → SYS-02.
  void onTimeout() {
    if (state.isTimedOut) return;
    final startedAt = state.startedAt;
    final waited = startedAt == null
        ? null
        : appClock.nowUtc().difference(startedAt);
    AppLogger.warn('Açılış zaman aşımına uğradı (bekleme: $waited)');
    state = state.copyWith(isTimedOut: true);
  }
}
