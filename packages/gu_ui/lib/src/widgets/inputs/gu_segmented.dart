import 'dart:ui' show SemanticsRole;

import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/icons/gu_icon.dart';
import 'package:gu_ui/src/icons/gu_icons.dart';
import 'package:gu_ui/src/tokens/gu_motion.dart';
import 'package:gu_ui/src/tokens/gu_radius.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';
import 'package:gu_ui/src/widgets/primitives/gu_action_surface.dart';

/// [GuSegmented] seçeneği — prototip `{id, label, icon}` (`ui.js:59`).
@immutable
class GuSegmentOption {
  const GuSegmentOption({required this.id, required this.label, this.icon});

  /// Seçenek kimliği ([GuSegmented.value] ile karşılaştırılır).
  final String id;

  /// Görünen metin (çağırandan; ARB).
  final String label;

  /// Baştaki 16 px ikon (EVT-01 liste / takvim, FED-03, MGT-05).
  final GuIcons? icon;
}

/// Bölmeli seçici — prototip `Segmented` (`ui.js:58`), CSS `.seg`
/// (css:220–223).
///
/// Kap `bg.surfaceMuted`, radius 12, dolgu 3, aralık 2; 2–4 seçenek eşit
/// genişlikte (`flex:1`), en az 40 px, radius 10, yatay dolgu 8, metin tek
/// satır + üç nokta. Dokunma alanı `GuTapTarget` ile 44 / 48'e tamamlanır
/// (K-03).
///
/// * Seçili: açık temada `bg.surface` + `e1` + `text.heading`; koyu temada
///   `bg.surfaceRaised` + 1 px `border.default` (css:222–223). Zemin ve
///   metin rengi `GuMotion.fast` ile geçer (css:221).
/// * Basılı görünüm yoktur (CD-82: `.seg>button:active` kuralı yok); klavye
///   odağı 2 px `focus.ring` halkası (css:82).
/// * Semantik: kap `tabBar`, seçenek `tab` + `selected` (`role="tablist"` /
///   `role="tab"`, ui.js:59).
/// * Seçenek anahtarı çağırandan ([optionKeyBuilder]:
///   `(i) => GuKey.action('EVT-01.view.<id>')`, CD-111).
/// * Sınırlı genişlik ister (seçenekler `Expanded`); sınırsız genişlikte
///   çağıran `IntrinsicWidth` ile sarar.
class GuSegmented extends StatelessWidget {
  const GuSegmented({
    required this.options,
    required this.value,
    required this.onChanged,
    this.optionKeyBuilder,
    super.key,
  });

  /// Seçenekler (2–4).
  final List<GuSegmentOption> options;

  /// Seçili seçeneğin [GuSegmentOption.id]'si.
  final String value;

  /// Seçeneğe dokunma; seçili olana dokunmada da çağrılır (ui.js:59).
  final ValueChanged<String> onChanged;

  /// Seçenek anahtarı üreticisi (`GuKey.action('<ID>.<aksiyon>.<id>')`).
  final Key Function(int index)? optionKeyBuilder;

  @override
  Widget build(BuildContext context) => Semantics(
    role: SemanticsRole.tabBar,
    container: true,
    explicitChildNodes: true,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: context.gu.colors.bgSurfaceMuted,
        borderRadius: GuRadius.borderSm,
      ),
      child: Padding(
        padding: GuInsets.sym(
          h: GuSizes.segmentPadding,
          v: GuSizes.segmentPadding,
        ),
        child: Row(
          spacing: GuSizes.segmentGap,
          children: [
            for (final (index, option) in options.indexed)
              Expanded(
                child: _GuSegment(
                  key: optionKeyBuilder?.call(index),
                  option: option,
                  selected: option.id == value,
                  onTap: () => onChanged(option.id),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Tek bölme — CSS `.seg>button` (css:221–223).
class _GuSegment extends StatelessWidget {
  const _GuSegment({
    required this.option,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final GuSegmentOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GuActionSurface(
    onTap: onTap,
    selected: selected,
    borderRadius: GuRadius.borderChip,
    builder: _buildVisual,
  );

  Widget _buildVisual(BuildContext context, bool _) {
    final gu = context.gu;
    final colors = gu.colors;
    final duration = gu.duration(GuMotion.fast);
    final darkSelected = selected && gu.isDark;
    final background = selected
        ? (gu.isDark ? colors.bgSurfaceRaised : colors.bgSurface)
        : null;
    final icon = option.icon;
    return Semantics(
      role: SemanticsRole.tab,
      child: AnimatedContainer(
        duration: duration,
        curve: GuMotion.easeCss,
        constraints: const BoxConstraints(minHeight: GuSizes.segmentHeight),
        padding: GuInsets.sym(h: GuSizes.segmentPaddingX),
        decoration: BoxDecoration(
          color: background,
          borderRadius: GuRadius.borderChip,
          // css:223 `border:1px` için ayrı ölçü token'ı yok; en yakın:
          // aynı radius ailesindeki `chipBorder` (1).
          border: darkSelected
              ? Border.all(
                  color: colors.borderDefault,
                  // Token değeri varsayılanla (1) aynı; kaynak token kalır.
                  // ignore: avoid_redundant_argument_values
                  width: GuSizes.chipBorder,
                )
              : null,
          boxShadow: selected ? gu.shadows.e1 : null,
        ),
        child: Center(
          heightFactor: 1,
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(
              end: selected ? colors.textHeading : colors.textSecondary,
            ),
            duration: duration,
            curve: GuMotion.easeCss,
            builder: (context, color, _) => Row(
              mainAxisSize: MainAxisSize.min,
              spacing: GuSizes.segmentItemGap,
              children: [
                if (icon != null)
                  GuIcon(icon, size: GuSizes.segmentIcon, color: color),
                Flexible(
                  child: Text(
                    option.label,
                    style: gu.text.segment.copyWith(color: color),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
