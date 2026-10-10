import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Uygulama içi metin ölçeği tercihi (Q-14; `typography.json#textScales`,
/// prototip `--ts`, K-08). Planın tek metin ölçeği enum'u (PLAN §7.13).
enum GuTextScaleLevel {
  /// %100.
  s100(1),

  /// %130.
  s130(1.3),

  /// %160.
  s160(1.6);

  const GuTextScaleLevel(this.factor);

  /// Çarpan (1.0 / 1.3 / 1.6).
  final double factor;
}

/// Metin ölçeği sarmalayıcısı — widget değil, `MediaQuery` yeniden yazımı
/// (PLAN §7.13, Q-14, K-08).
///
/// `etkin = min(sistem ölçeği × uygulama ölçeği, 1.6)`; alt ağaç
/// `MediaQuery.textScaler`'ı `TextScaler.linear(etkin)` olarak görür
/// (`context.gu.textScaler`). Yalnızca yazı ölçeklenir; ikon, boşluk ve
/// radius ölçeklenmez. `GuApp.builder` kökünde, `GuSystemUi`'nin içinde
/// durur (T-11).
class GuTextScale extends StatelessWidget {
  const GuTextScale({required this.level, required this.child, super.key});

  /// Etkin ölçeğin üst sınırı (Q-14).
  static const double maxScale = 1.6;

  /// Uygulama ölçeği (kullanıcı tercihi, SET-01).
  final GuTextScaleLevel level;

  /// Ölçeğin uygulanacağı alt ağaç.
  final Widget child;

  /// `min(systemScale × level.factor, maxScale)`.
  static double effectiveScale(double systemScale, GuTextScaleLevel level) =>
      math.min(systemScale * level.factor, maxScale);

  /// [system] ölçekleyicisinden (1 dp'lik yazının ölçeği) etkin doğrusal
  /// ölçekleyici.
  static TextScaler resolve(TextScaler system, GuTextScaleLevel level) =>
      TextScaler.linear(effectiveScale(system.scale(1), level));

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(textScaler: resolve(media.textScaler, level)),
      child: child,
    );
  }
}
