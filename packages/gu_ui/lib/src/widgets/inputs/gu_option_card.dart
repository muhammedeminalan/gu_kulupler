import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/tokens/gu_radius.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';
import 'package:gu_ui/src/widgets/primitives/gu_action_surface.dart';

/// Seçenek kartı — prototipte ham `.option-card` / `.is-selected`
/// (css:245–246; `sheets.js:86` SHT-17 tema kartları, `sheets.js:107` SHT-22
/// rol kartları). `GuCard`'a varyant değildir (G3: ayrı radius ve kenarlık).
///
/// Dolgu 14/16, radius `md`, 1 px `border.default`, zemin `bg.surface`; tam
/// genişlik, çocuklar üstten hizalı. İçerik çağırandadır: [child] (SHT-17:
/// önizleme + ad sütunu; SHT-22: rozet + açıklama) ve isteğe bağlı [leading]
/// (SHT-22 etkileşimsiz `GuRadio`) — arada 12 px.
///
/// * [selected]: kenarlık `brand.primary`, zemin `brand.primaryContainer`
///   (css:246).
/// * Basılı görünüm ve geçiş yok (CD-82: `:hover` / `:active` / `transition`
///   kuralı yok).
/// * `Semantics(button, selected, label)` (`aria-pressed`, sheets.js:86);
///   [semanticLabel] verilmezse etiket [child] metinlerinden gelir.
///   `key: GuKey.action('ID.aksiyon')` (CD-111).
class GuOptionCard extends StatelessWidget {
  const GuOptionCard({
    required this.selected,
    required this.onTap,
    required this.child,
    this.leading,
    this.semanticLabel,
    super.key,
  });

  /// Seçili mi.
  final bool selected;

  /// Dokunma.
  final VoidCallback onTap;

  /// Kart içeriği; kalan genişliği doldurur.
  final Widget child;

  /// Baştaki öğe (üstten hizalı).
  final Widget? leading;

  /// Erişilebilirlik etiketi; verilirse çocuk semantiğinin yerine geçer.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => GuActionSurface(
    onTap: onTap,
    selected: selected,
    semanticLabel: semanticLabel,
    borderRadius: GuRadius.borderMd,
    builder: _buildVisual,
  );

  Widget _buildVisual(BuildContext context, bool pressed) {
    final colors = context.gu.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? colors.brandPrimaryContainer : colors.bgSurface,
        borderRadius: GuRadius.borderMd,
        border: Border.all(
          color: selected ? colors.brandPrimary : colors.borderDefault,
          // Token değeri varsayılanla (1) aynı; kaynak token kalır.
          // ignore: avoid_redundant_argument_values
          width: GuSizes.optionCardBorder,
        ),
      ),
      child: Padding(
        // css:245 `box-sizing:border-box`: dolgu kenarlığın içinde başlar.
        padding: GuInsets.sym(
          h: GuSizes.optionCardPaddingX + GuSizes.optionCardBorder,
          v: GuSizes.optionCardPaddingY + GuSizes.optionCardBorder,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: GuSizes.optionCardGap,
          children: [
            ?leading,
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
