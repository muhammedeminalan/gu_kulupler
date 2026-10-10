import 'package:equatable/equatable.dart';

/// Açılış ekranının durumu (SYS-01; PLAN §12.3).
final class SplashState extends Equatable {
  /// Varsayılan: animasyon sürüyor, zaman aşımı yok.
  const SplashState({
    this.isAnimationDone = false,
    this.isTimedOut = false,
    this.startedAt,
    this.version = '',
  });

  /// Logo animasyonu (`GuMotion.splash`) tamamlandı mı?
  final bool isAnimationDone;

  /// Oturum `Limits.splashTimeout` içinde çözülemedi mi? (→ SYS-02)
  final bool isTimedOut;

  /// Açılışın başladığı an (UTC); `start()` çağrılmadıysa `null`.
  final DateTime? startedAt;

  /// Kurulu uygulamanın sürüm adı (`1.0.0`); okunamadıysa boş (satır
  /// çizilmez).
  final String version;

  @override
  List<Object?> get props => [isAnimationDone, isTimedOut, startedAt, version];

  /// Verilen alanları değiştirilmiş kopya.
  SplashState copyWith({
    bool? isAnimationDone,
    bool? isTimedOut,
    DateTime? startedAt,
    String? version,
  }) => SplashState(
    isAnimationDone: isAnimationDone ?? this.isAnimationDone,
    isTimedOut: isTimedOut ?? this.isTimedOut,
    startedAt: startedAt ?? this.startedAt,
    version: version ?? this.version,
  );
}
