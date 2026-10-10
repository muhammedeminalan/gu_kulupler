import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/icons/gu_icon.dart';
import 'package:gu_ui/src/icons/gu_icons.dart';
import 'package:gu_ui/src/tokens/gu_radius.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';
import 'package:gu_ui/src/widgets/primitives/gu_action_surface.dart';

/// Uzatılmış FAB — CSS `.fab` (css:158–159; prototipte ayrı bileşen yok:
/// `screens-admin.js:34`, `screens-manage.js:83`, `:166`).
///
/// 56 px yükseklik, dolgu 16 / 20, radius 16, `brand.primary` zemin, 22 px
/// ikon + etiket, `GuShadows.fab` (açık `e2`, koyu özel gölge).
///
/// **Bir `Stack`'in doğrudan çocuğu olmalıdır:** kendini sağ alt köşeye
/// yerleştirir (`position:absolute`): sağ 16, alt `viewPadding.bottom + 16`;
/// [aboveNav] (sekme kökü, ADM-02) → buna `GuSizes.bottomNavHeight` eklenir
/// (K-34). Genişlik ekran genişliği − 2 × 16 ile sınırlıdır; etiket sığmazsa
/// `…` ile kesilir.
///
/// Basılı ve devre dışı durumu tasarımda yoktur (CD-82); salt okunur ekranda
/// çağıran widget'ı hiç çizmez. [semanticLabel] zorunludur (K-34).
/// `key: GuKey.action('ID.aksiyon')` (CD-111).
class GuFab extends StatelessWidget {
  const GuFab({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.aboveNav = false,
    super.key,
  });

  /// Görünen etiket (çağırandan; ARB).
  final String label;

  /// Baştaki ikon (22 px; tasarımda hep `plus`).
  final GuIcons icon;

  /// Dokunma.
  final VoidCallback onPressed;

  /// Erişilebilirlik etiketi (ör. MGT-08 `compose.title`).
  final String semanticLabel;

  /// Alt sekme çubuğunun üstünde konumlanır (sekme kökü).
  final bool aboveNav;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final foreground = gu.colors.brandOnPrimary;
    return Positioned(
      right: GuSizes.fabMargin,
      bottom:
          MediaQuery.viewPaddingOf(context).bottom +
          GuSizes.fabMargin +
          (aboveNav ? GuSizes.bottomNavHeight : 0),
      // Yalnız sağ + alt verilen `Positioned` çocuğu sınırsız bırakır; uzun
      // etiket sol kenardan taşmasın.
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width - GuSizes.fabMargin * 2,
        ),
        child: GuActionSurface(
          onTap: onPressed,
          semanticLabel: semanticLabel,
          borderRadius: GuRadius.borderMd,
          builder: (context, _) => Container(
            height: GuSizes.fabHeight,
            padding: GuInsets.only(
              left: GuSizes.fabPaddingLeft,
              right: GuSizes.fabPaddingRight,
            ),
            decoration: BoxDecoration(
              color: gu.colors.brandPrimary,
              borderRadius: GuRadius.borderMd,
              boxShadow: gu.shadows.fab,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: GuSizes.fabGap,
              children: [
                GuIcon(icon, size: GuSizes.icon22, color: foreground),
                Flexible(
                  child: Text(
                    label,
                    style: gu.text.button.copyWith(color: foreground),
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
