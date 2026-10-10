import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/tokens/gu_radius.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';

/// Tarih rozeti — prototip `DateBadge` (`ui.js:126`), CSS `.date-badge`
/// (css:318–319): 48×52, radius 12, `brand.primaryContainer` zemin; gün
/// Montserrat 700 18, ay Inter 600 11 (üst boşluk 3).
///
/// * [monthShort] çağırandan **büyük harfle** gelir
///   (`AppDateFormats.monthShort(dt).upperFor(locale)`, CD-11).
/// * Ay yazısı ölçeklenmez (K-57: css:319 sabit `11px`); gün ölçeklenir.
///   Kutu ölçüsü sabittir; içerik sığmazsa küçültülür (taşma yok).
/// * [semanticLabel] verilirse iki metnin yerine okunur; verilmezse gün + ay
///   tek düğümde birleşir.
class GuDateBadge extends StatelessWidget {
  const GuDateBadge({
    required this.day,
    required this.monthShort,
    this.semanticLabel,
    super.key,
  });

  /// Ayın günü (1–31).
  final int day;

  /// Kısa ay adı, büyük harf ("EKİ", "OCT").
  final String monthShort;

  /// Erişilebilirlik etiketi (tam tarih); `null` → gün + ay.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final badge = SizedBox(
      width: GuSizes.dateBadgeWidth,
      height: GuSizes.dateBadgeHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: gu.colors.brandPrimaryContainer,
          borderRadius: GuRadius.borderSm,
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$day',
                  style: gu.text.dateBadgeDay,
                  maxLines: 1,
                  softWrap: false,
                ),
                const SizedBox(height: GuSizes.dateBadgeMonthTop),
                Text(
                  monthShort,
                  style: gu.text.dateBadgeMonth,
                  textScaler: TextScaler.noScaling,
                  maxLines: 1,
                  softWrap: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final label = semanticLabel;
    if (label == null) return MergeSemantics(child: badge);
    return Semantics(
      container: true,
      label: label,
      child: ExcludeSemantics(child: badge),
    );
  }
}
