import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/tokens/gu_opacity.dart';
import 'package:gu_ui/src/tokens/gu_radius.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';
import 'package:gu_ui/src/widgets/inputs/gu_checkbox.dart';
import 'package:gu_ui/src/widgets/inputs/gu_radio.dart';
import 'package:gu_ui/src/widgets/inputs/gu_selection_surface.dart';

/// [GuOptionRow] sonundaki gösterge (prototip `type`, ui.js:48).
enum GuOptionControl {
  /// Tek seçim — `GuRadio` (varsayılan; 11 çağrının tümü).
  radio,

  /// Çok seçim — `GuCheckbox`.
  checkbox,
}

/// Seçenek satırı — prototip `OptionRow` (`ui.js:48`), CSS `.option-row`
/// (css:243–244). `GuTile` ile birleştirilmez (G1: ayrı ölçü ve rol).
///
/// Yerleşim: [leading] · metin sütunu ([label] bodyM `text.heading`, [sub]
/// bodyS `text.muted`) · [trailing] · gösterge (`GuRadio` / `GuCheckbox`,
/// etkileşimsiz ve semantikten gizli — `aria-hidden`). En az yükseklik 52,
/// dolgu 6/16, aralık 12, tam genişlik; metinler sarar.
///
/// * [selected]: gösterge seçili (css:240–241).
/// * Basılı: zemin `bg.surfaceMuted` (css:244 `:hover` → basılı, K-53).
/// * [disabled]: opaklık .5 (ui.js:49), [onTap] çağrılmaz.
/// * [onTap] `null` → statik satır.
/// * `Semantics(checked, inMutuallyExclusiveGroup (radyo), enabled)`; etiket
///   satır metinlerinden gelir. `key: GuKey.action('ID.aksiyon')` satırın
///   kendisidir (CD-111).
class GuOptionRow extends StatelessWidget {
  const GuOptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.sub,
    this.control = GuOptionControl.radio,
    this.leading,
    this.trailing,
    this.disabled = false,
    super.key,
  });

  /// Seçenek metni (çağırandan; ARB).
  final String label;

  /// Seçili / işaretli mi (`aria-checked`).
  final bool selected;

  /// Dokunma; `null` → statik satır.
  final VoidCallback? onTap;

  /// İkinci satır (bodyS, `text.muted`; SHT-01 dil kodu).
  final String? sub;

  /// Sondaki gösterge türü.
  final GuOptionControl control;

  /// Baştaki öğe (SHT-30 `map-pin` 18, SHT-33 amblem xs).
  final Widget? leading;

  /// Göstergeden önceki öğe.
  final Widget? trailing;

  /// Devre dışı: soluk, dokunma çağrılmaz.
  final bool disabled;

  void _handleTap() {
    if (!disabled) onTap?.call();
  }

  @override
  Widget build(BuildContext context) => GuSelectionSurface(
    role: switch (control) {
      GuOptionControl.radio => GuSelectionRole.radio,
      GuOptionControl.checkbox => GuSelectionRole.checkbox,
    },
    value: selected,
    enabled: !disabled,
    onTap: onTap == null ? null : _handleTap,
    // css:82 `:focus-visible{border-radius:6px}` — değer `GuRadius.checkbox`
    // ile aynı (ayrı odak yarıçapı token'ı yok).
    borderRadius: GuRadius.borderCheckbox,
    builder: _buildVisual,
  );

  Widget _buildVisual(BuildContext context, bool pressed) {
    final gu = context.gu;
    final colors = gu.colors;
    final text = gu.text;
    final sub = this.sub;
    final leading = this.leading;
    final trailing = this.trailing;
    return Opacity(
      opacity: disabled ? GuOpacity.disabled : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: pressed ? colors.bgSurfaceMuted : null,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: GuSizes.optionRowMinHeight,
          ),
          child: Padding(
            padding: GuInsets.sym(
              h: GuSizes.optionRowPaddingX,
              v: GuSizes.optionRowPaddingY,
            ),
            child: Row(
              spacing: GuSizes.optionRowGap,
              children: [
                ?leading,
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: text.bodyM.copyWith(color: colors.textHeading),
                      ),
                      if (sub != null)
                        Text(
                          sub,
                          style: text.bodyS.copyWith(color: colors.textMuted),
                        ),
                    ],
                  ),
                ),
                ?trailing,
                ExcludeSemantics(
                  child: switch (control) {
                    GuOptionControl.radio => GuRadio(
                      selected: selected,
                      onSelected: null,
                      semanticLabel: label,
                    ),
                    GuOptionControl.checkbox => GuCheckbox(
                      value: selected,
                      onChanged: null,
                      semanticLabel: label,
                    ),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
