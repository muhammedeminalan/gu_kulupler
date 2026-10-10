import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/icons/gu_icon.dart';
import 'package:gu_ui/src/icons/gu_icons.dart';
import 'package:gu_ui/src/tokens/gu_motion.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';
import 'package:gu_ui/src/widgets/display/gu_card.dart';

/// KPI kartı yerleşimi.
enum GuKpiLayout {
  /// Üstte etiket (+ ikon), altında değer ve alt metin; dolgu 14/16
  /// (MGT-01, ADM-01; `ui.js:127`).
  standard,

  /// Önce değer, sonra etiket; dolgu 12, ikon ve alt metin yok (PRF-01 ham
  /// `.card.kpi.pressable`, `screens-profile.js:12`).
  compact,
}

/// KPI kartı — prototip `KPI` (`ui.js:127`), CSS `.card.kpi.pressable` /
/// `.kpi-value` / `.is-accent` (css:302–304, 340). Gövde `GuCard`'dır (G3).
///
/// [label] caption, [value] `GuTypography.kpiValue` ([accent] →
/// `brand.primaryText`), [subtitle] bodyS `text.secondary`, [icon] 16
/// `text.muted`. Basılı ölçek `GuMotion.pressScale` (`.pressable`).
/// [semanticLabel] verilmezse metinler birleşik okunur.
///
/// Izgara sınıfı yoktur (G14, CD-112): MGT-01 / ADM-01 iki sütun, PRF-01 üç
/// sütun (`.grid2` / `.grid3`, aralık 12) ekran içinde kompoze edilir; aynı
/// satırdaki kartlar eşit boya gerilir (`IntrinsicHeight` + `Row(stretch)`).
/// `key` (`GuKey.action`) kartın kendisidir.
class GuKpi extends StatelessWidget {
  const GuKpi({
    required this.label,
    required this.value,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.accent = false,
    this.layout = GuKpiLayout.standard,
    this.semanticLabel,
    super.key,
  });

  /// Gösterge adı.
  final String label;

  /// Biçimlenmiş değer (çağıran `intl` ile biçimler).
  final String value;

  /// Dokunma (ilgili listeye gider).
  final VoidCallback onTap;

  /// Değerin altındaki açıklama (yalnızca `standard`).
  final String? subtitle;

  /// Etiketin sağındaki ikon (yalnızca `standard`).
  final GuIcons? icon;

  /// Değeri marka rengiyle vurgular.
  final bool accent;

  /// Yerleşim varyantı.
  final GuKpiLayout layout;

  /// Erişilebilirlik etiketi; `null` → içerik metinleri.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final colors = gu.colors;
    final text = gu.text;
    final icon = this.icon;
    final subtitle = this.subtitle;
    final compact = layout == GuKpiLayout.compact;

    final valueText = Text(
      value,
      style: accent
          ? text.kpiValue.copyWith(color: colors.brandPrimaryText)
          : text.kpiValue,
    );
    final labelText = Text(label, style: text.caption);

    return GuCard(
      onTap: onTap,
      semanticLabel: semanticLabel,
      pressScale: GuMotion.pressScale,
      padding: compact
          ? GuInsets.all12
          : const EdgeInsets.symmetric(
              horizontal: GuSizes.kpiPaddingX,
              vertical: GuSizes.kpiPaddingY,
            ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: GuSizes.kpiGap,
        children: compact
            ? [valueText, labelText]
            : [
                Row(
                  spacing: GuSpacing.s8,
                  children: [
                    Expanded(child: labelText),
                    if (icon != null)
                      GuIcon(
                        icon,
                        size: GuSizes.kpiIcon,
                        color: colors.textMuted,
                      ),
                  ],
                ),
                valueText,
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: text.bodyS.copyWith(color: colors.textSecondary),
                  ),
              ],
      ),
    );
  }
}
