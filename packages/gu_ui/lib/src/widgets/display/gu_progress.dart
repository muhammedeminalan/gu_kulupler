import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/tokens/gu_colors.dart';
import 'package:gu_ui/src/tokens/gu_motion.dart';
import 'package:gu_ui/src/tokens/gu_radius.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';

/// İlerleme çubuğu dolum türü — CSS `.prog.is-*` (css:261). `danger` yoktur
/// (CD-105: `.prog.is-danger` CSS'te tanımlı değil).
enum GuProgressKind {
  /// `brand.primary` (varsayılan, css:260).
  brand,

  /// `state.success` — MGT-06 yoklama oranı, `MemberRow`.
  success,

  /// `state.warning` — kapasite ≥ %80, günlük kota doldu.
  warning,

  /// `text.muted` — dolu / pasif (DS "60/60").
  muted;

  /// Dolum rengi.
  Color resolve(GuColors c) => switch (this) {
    brand => c.brandPrimary,
    success => c.stateSuccess,
    warning => c.stateWarning,
    muted => c.textMuted,
  };
}

/// İlerleme çubuğu — prototip `Progress` (`ui.js:92`), CSS `.prog`
/// (css:259–261): 6 px (ince 4), radius 3, iz `bg.surfaceMuted`, dolum
/// genişliği `GuMotion.slow` + `easeStandard` ile geçer.
///
/// * Sınırlı genişlikte tüm genişliği kaplar (`flex:1`; `Row` içinde çağıran
///   `Expanded` ile sarar), sınırsız genişlikte `GuSizes.progressMinWidth`.
/// * Yüzde metni basmaz; [semanticLabel] çağırandan gelir ("48/60", CD-101).
class GuProgress extends StatelessWidget {
  const GuProgress({
    required this.value,
    required this.semanticLabel,
    this.max = 100,
    this.kind = GuProgressKind.brand,
    this.thin = false,
    super.key,
  });

  /// Geçerli değer (0…[max]).
  final double value;

  /// En büyük değer; ≤ 0 → dolum yok.
  final double max;

  /// Dolum rengi türü.
  final GuProgressKind kind;

  /// `.is-thin` — 4 px yükseklik.
  final bool thin;

  /// Erişilebilirlik etiketi (`aria-label`).
  final String semanticLabel;

  /// Dolum oranı 0…1 — `min(100, round(value / max × 100))` yüzdesi
  /// (ui.js:92); geçersiz girişte 0.
  double get fraction {
    final ratio = max > 0 ? value / max : 0.0;
    if (!ratio.isFinite) return 0;
    return (ratio * 100).round().clamp(0, 100) / 100;
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    return Semantics(
      container: true,
      label: semanticLabel,
      child: LayoutBuilder(
        builder: (context, constraints) => SizedBox(
          width: constraints.hasBoundedWidth
              ? constraints.maxWidth
              : GuSizes.progressMinWidth,
          height: thin ? GuSizes.progressHeightThin : GuSizes.progressHeight,
          child: ClipRRect(
            borderRadius: GuRadius.borderProgress,
            child: ColoredBox(
              color: gu.colors.bgSurfaceMuted,
              child: AnimatedFractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: fraction,
                duration: gu.duration(GuMotion.slow),
                curve: GuMotion.easeStandard,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: kind.resolve(gu.colors),
                    borderRadius: GuRadius.borderProgress,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
