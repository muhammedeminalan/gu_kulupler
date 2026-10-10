import 'package:flutter/material.dart' show Colors;
import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/icons/gu_icon.dart';
import 'package:gu_ui/src/icons/gu_icons.dart';
import 'package:gu_ui/src/tokens/gu_opacity.dart';
import 'package:gu_ui/src/tokens/gu_radius.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';
import 'package:gu_ui/src/widgets/inputs/gu_field.dart';
import 'package:gu_ui/src/widgets/primitives/gu_action_surface.dart';

/// Seçici alan — prototip `Picker` (`ui.js:36`), CSS `.picker` (css:173–174);
/// salt okunur, dokununca çağıran sheet / dialog açar (`aria-haspopup`).
///
/// * Kutu: min 48, dolgu 0/14, radius `sm`, zemin `bg.surfaceMuted`, 1 px
///   saydam kenarlık; [errorText] → kenarlık `state.danger` + hata satırı.
/// * [icon] 20 `text.muted`, sonda `chevron-down` 20 `text.muted` (ui.js:39).
/// * [value] boşsa [placeholder] `text.muted` (`.ph`); metin tek satır,
///   taşarsa üç nokta (`.ellipsis`).
/// * Durumlar D E X (K-38): pressed görseli yok; [disabled] → opaklık .6
///   (`.input.is-disabled` ile aynı, css:165), [onTap] çağrılmaz.
/// * `Semantics(button, enabled)`: etiket [semanticLabel] (yoksa [label]),
///   değer görünen metin, ipucu [semanticHint] (çağırandan; "açılır seçici").
/// * Anahtar çağırandan: `actionKey: GuKey.action('ID.aksiyon')` (CD-111).
class GuPickerField extends StatelessWidget {
  const GuPickerField({
    required this.onTap,
    this.label,
    this.value,
    this.placeholder,
    this.icon,
    this.help,
    this.errorText,
    this.disabled = false,
    this.semanticLabel,
    this.semanticHint,
    this.actionKey,
    super.key,
  });

  /// Dokunma; [disabled] iken çağrılmaz.
  final VoidCallback onTap;

  /// Etiket (`.field-label`).
  final String? label;

  /// Seçili değer metni.
  final String? value;

  /// Değer yokken gösterilen metin.
  final String? placeholder;

  /// Baştaki ikon.
  final GuIcons? icon;

  /// Yardım metni.
  final String? help;

  /// Hata metni.
  final String? errorText;

  /// Devre dışı (`aria-disabled`, ui.js:38).
  final bool disabled;

  /// Erişilebilirlik etiketi; `null` → [label].
  final String? semanticLabel;

  /// Erişilebilirlik ipucu.
  final String? semanticHint;

  /// Düğmenin anahtarı.
  final Key? actionKey;

  static void _ignoreTap() {}

  @override
  Widget build(BuildContext context) => GuField(
    label: label,
    help: help,
    errorText: errorText,
    excludeLabelSemantics: true,
    child: GuActionSurface(
      key: actionKey,
      onTap: disabled ? _ignoreTap : onTap,
      enabled: !disabled,
      borderRadius: GuRadius.borderSm,
      builder: _buildBox,
    ),
  );

  Widget _buildBox(BuildContext context, bool pressed) {
    final gu = context.gu;
    final colors = gu.colors;
    final value = this.value;
    final hasValue = value != null && value.isNotEmpty;
    final text = hasValue ? value : placeholder ?? '';
    final icon = this.icon;
    return Semantics(
      label: semanticLabel ?? label,
      value: text,
      hint: semanticHint,
      child: ExcludeSemantics(
        child: Opacity(
          opacity: disabled ? GuOpacity.inputDisabled : 1,
          child: Container(
            constraints: const BoxConstraints(minHeight: GuSizes.pickerHeight),
            padding: GuInsets.sym(h: GuSizes.pickerPaddingX),
            decoration: BoxDecoration(
              color: colors.bgSurfaceMuted,
              borderRadius: GuRadius.borderSm,
              border: Border.all(
                color: errorText != null
                    ? colors.stateDanger
                    : Colors.transparent,
                // Token değeri varsayılanla (1) aynı; kaynak token kalır.
                // ignore: avoid_redundant_argument_values
                width: GuSizes.inputBorder,
              ),
            ),
            child: Row(
              spacing: GuSizes.inputGap,
              children: [
                if (icon != null)
                  GuIcon(
                    icon,
                    size: GuSizes.inputIcon,
                    color: colors.textMuted,
                  ),
                Expanded(
                  child: Text(
                    text,
                    style: gu.text.input.copyWith(
                      color: hasValue ? null : colors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GuIcon(
                  GuIcons.chevronDown,
                  size: GuSizes.pickerChevron,
                  color: colors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
