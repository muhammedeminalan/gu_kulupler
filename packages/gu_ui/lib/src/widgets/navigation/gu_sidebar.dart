import 'dart:ui' show SemanticsRole;

import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/icons/gu_icon.dart';
import 'package:gu_ui/src/icons/gu_icons.dart';
import 'package:gu_ui/src/tokens/gu_motion.dart';
import 'package:gu_ui/src/tokens/gu_radius.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';
import 'package:gu_ui/src/tokens/gu_web_layout.dart';
import 'package:gu_ui/src/widgets/primitives/gu_action_surface.dart';
import 'package:gu_ui/src/widgets/primitives/gu_count_badge.dart';

/// [GuSidebar] satırı (`GuBottomNavItem` ile aynı içerik).
@immutable
class GuSidebarItem {
  const GuSidebarItem({required this.icon, required this.label, this.badge});

  /// Satır ikonu (24).
  final GuIcons icon;

  /// Satır etiketi (çağırandan; ARB `nav.*`).
  final String label;

  /// Sayaç rozeti metni; `null` → rozet yok ("9+" sınırı çağırandadır).
  final String? badge;
}

/// Web yan menüsü (H-23) — tasarımda karşılığı yoktur; geniş web
/// penceresinde alt sekme çubuğunun (`GuBottomNav`) yerini alır
/// (`GuWebFrame.sidebar`). Kurallar alt çubukla aynıdır: [onTap] seçili
/// satırda da çağrılır (köke dön / başa kaydır kabuğun işi).
///
/// * Kart: `bg.surface`, `GuRadius.xl`, 1 px `border.soft`, gölge `e2`
///   (telefon kartıyla aynı dil).
/// * Üstte [header] (amblem + ad), altında satırlar: ikon 24 + etiket
///   (`labelL`), yükseklik `GuWebLayout.sidebarItemHeight`. Seçili satır
///   `brand.primaryContainer` zemin + `brand.primaryText`; fare üstündeyken
///   `bg.surfaceMuted`. Rozet sağda `GuCountBadge(sm)`.
/// * Semantik: kap `navigation` + [semanticLabel]; satır düğme + `selected`.
/// * Satır anahtarı çağırandan ([itemKeyBuilder]).
class GuSidebar extends StatelessWidget {
  const GuSidebar({
    required this.items,
    required this.currentIndex,
    required this.onTap,
    required this.semanticLabel,
    this.header,
    this.itemKeyBuilder,
    super.key,
  });

  /// Satırlar.
  final List<GuSidebarItem> items;

  /// Seçili satırın sırası; aralık dışı → seçili yok.
  final int currentIndex;

  /// Satıra dokunma.
  final ValueChanged<int> onTap;

  /// Menünün erişilebilirlik etiketi.
  final String semanticLabel;

  /// Üst bilgi (ör. amblem + uygulama adı); `null` → yok.
  final Widget? header;

  /// Satır anahtarı üreticisi.
  final Key Function(int index)? itemKeyBuilder;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final colors = gu.colors;
    final top = header;
    return Semantics(
      role: SemanticsRole.navigation,
      container: true,
      explicitChildNodes: true,
      label: semanticLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.bgSurface,
          borderRadius: GuRadius.borderXl,
          border: Border.all(
            color: colors.borderSoft,
            // Token değeri varsayılanla (1) aynı; kaynak token kalır.
            // ignore: avoid_redundant_argument_values
            width: GuWebLayout.outline,
          ),
          boxShadow: gu.shadows.e2,
        ),
        child: ClipRRect(
          borderRadius: GuRadius.borderXl,
          // Yönlendiricinin üstünde çizilir (`Material` yok): kök metin stili
          // burada verilir, Flutter'ın uyarı stili (sarı alt çizgi) görünmez.
          child: DefaultTextStyle(
            style: gu.text.bodyM,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (top != null) Padding(padding: GuInsets.all20, child: top),
                Expanded(
                  child: ListView(
                    padding: GuInsets.all12,
                    children: [
                      for (var index = 0; index < items.length; index++)
                        Padding(
                          padding: GuInsets.only(bottom: GuSpacing.s4),
                          child: _GuSidebarTile(
                            key: itemKeyBuilder?.call(index),
                            item: items[index],
                            selected: index == currentIndex,
                            onTap: () => onTap(index),
                          ),
                        ),
                    ],
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

/// Tek satır: dokunma, klavye odağı ve fare üstü.
class _GuSidebarTile extends StatefulWidget {
  const _GuSidebarTile({
    required this.item,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final GuSidebarItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_GuSidebarTile> createState() => _GuSidebarTileState();
}

class _GuSidebarTileState extends State<_GuSidebarTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: GuActionSurface(
      onTap: widget.onTap,
      selected: widget.selected,
      borderRadius: GuRadius.borderMd,
      builder: _buildVisual,
    ),
  );

  Widget _buildVisual(BuildContext context, bool pressed) {
    final gu = context.gu;
    final colors = gu.colors;
    final item = widget.item;
    final selected = widget.selected;
    final foreground = selected ? colors.brandPrimaryText : colors.textPrimary;
    final background = selected
        ? colors.brandPrimaryContainer
        : (_hovered || pressed)
        ? colors.bgSurfaceMuted
        : colors.bgSurface;
    final badge = item.badge;
    return AnimatedContainer(
      duration: gu.duration(GuMotion.fast),
      curve: GuMotion.easeCss,
      constraints: const BoxConstraints(
        minHeight: GuWebLayout.sidebarItemHeight,
      ),
      padding: GuInsets.h12,
      decoration: BoxDecoration(
        color: background,
        borderRadius: GuRadius.borderMd,
      ),
      child: Row(
        spacing: GuSpacing.s12,
        children: [
          GuIcon(
            item.icon,
            // Token değeri varsayılanla (24) aynı; kaynak token kalır.
            // ignore: avoid_redundant_argument_values
            size: GuSizes.bottomNavIcon,
            color: selected ? colors.brandPrimaryText : colors.textSecondary,
          ),
          Expanded(
            child: Text(
              item.label,
              style: gu.text.labelL.copyWith(color: foreground),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (badge != null) GuCountBadge(label: badge),
        ],
      ),
    );
  }
}
