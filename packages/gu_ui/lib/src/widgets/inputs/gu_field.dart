import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/icons/gu_icon.dart';
import 'package:gu_ui/src/icons/gu_icons.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';

/// Alan çerçevesi — CSS `.field` (css:161): etiket satırı (`.field-label`
/// css:162 + `.field-counter` css:172), kontrol ve altında yardım / hata
/// satırı (`.field-help` css:171). `GuInput` (ui.js:22) ile `GuPickerField`
/// (ui.js:36) aynı çerçeveyi paylaşır (D-16).
///
/// * [counter] yalnızca [label] varken çizilir (ui.js:26: sayaç etiket
///   satırının içindedir); [counterOver] → `state.danger` (`.is-over`).
/// * [errorText] varsa [help] gizlenir; hata satırı `triangle-alert` 14 +
///   `state.danger`, `role="alert"` → `Semantics(liveRegion)` (ui.js:33).
/// * [excludeLabelSemantics] → etiketi kontrolün kendi `Semantics`'i
///   taşıyorsa görünür etiket ikinci kez okunmaz.
class GuField extends StatelessWidget {
  const GuField({
    required this.child,
    this.label,
    this.counter,
    this.counterOver = false,
    this.help,
    this.errorText,
    this.excludeLabelSemantics = false,
    super.key,
  });

  /// Kontrol (`.input`, `.picker`).
  final Widget child;

  /// Etiket metni (`.field-label`).
  final String? label;

  /// Sayaç metni ("240/300"); `null` → çizilmez.
  final String? counter;

  /// Sayaç sınırı aştı (`.field-counter.is-over`).
  final bool counterOver;

  /// Yardım metni (`.field-help`).
  final String? help;

  /// Hata metni (`.field-help.is-error`).
  final String? errorText;

  /// Görünür etiketi semantikten çıkarır.
  final bool excludeLabelSemantics;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final danger = gu.colors.stateDanger;
    final label = this.label;
    final counter = this.counter;
    final error = errorText;
    final help = this.help;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: GuSizes.fieldGap,
      children: [
        if (label != null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: GuSpacing.s8,
            children: [
              Expanded(
                child: ExcludeSemantics(
                  excluding: excludeLabelSemantics,
                  child: Text(label, style: gu.text.fieldLabel),
                ),
              ),
              if (counter != null)
                Text(
                  counter,
                  style: gu.text.fieldHelp.copyWith(
                    color: counterOver ? danger : null,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
        child,
        if (error != null)
          Semantics(
            liveRegion: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: GuSizes.fieldHelpGap,
              children: [
                GuIcon(
                  GuIcons.triangleAlert,
                  size: GuSizes.fieldHelpIcon,
                  color: danger,
                ),
                Expanded(
                  child: Text(
                    error,
                    style: gu.text.fieldHelp.copyWith(color: danger),
                  ),
                ),
              ],
            ),
          )
        else if (help != null)
          Text(help, style: gu.text.fieldHelp),
      ],
    );
  }
}
