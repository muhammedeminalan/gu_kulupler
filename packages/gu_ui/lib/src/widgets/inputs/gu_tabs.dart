import 'dart:async';
import 'dart:math' as math;
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
import 'package:gu_ui/src/widgets/primitives/gu_count_badge.dart';

/// [GuTabs] öğesi — prototip `{id, label, count, icon}` (`ui.js:62`).
/// (`enum GuTab` alt sekme çubuğuna aittir; çakışmaz.)
@immutable
class GuTabItem {
  const GuTabItem({
    required this.id,
    required this.label,
    this.count,
    this.icon,
  });

  /// Sekme kimliği ([GuTabs.value] ile karşılaştırılır).
  final String id;

  /// Görünen metin (çağırandan; ARB).
  final String label;

  /// Sayaç; `null` → rozet yok. Ham sayı basılır (ui.js:62 `count != null`;
  /// 0'ı gizlemek çağıranın işi: `count || undefined`, MGT-02 / ADM-04).
  final int? count;

  /// Sondaki 16 px ikon (ui.js:62; prototipte kullanımı yok).
  final GuIcons? icon;
}

/// Sekme çubuğu — prototip `Tabs` (`ui.js:61`), CSS `.tabs` (css:224–229).
///
/// Zemin `bg.canvas`, altta 1 px `border.soft`; sekme en az 48 px, metin
/// 600 14 `text.muted`, aralık 6. Seçili: metin `brand.primaryText` + altta
/// 2 px `brand.primary` gösterge (sol / sağ 16, üst köşeler 2; kenarlığın
/// üstüne biner, css:228). Metin rengi `GuMotion.fast` ile geçer.
///
/// Genişlik kuralı (K-37, K-05) — `LayoutBuilder` ile otomatik:
///
/// 1. her sekme eşit payına sığıyorsa **eşit bölüşüm** (css:226 `flex:1`,
///    tasarım 1:1);
/// 2. sığmıyor ama doğal genişlik toplamı sığıyorsa içerik genişliği + artan
///    boşluğun eşit payı (metin kesilmez, kaydırma yok);
/// 3. toplam taşıyorsa **kaydırılabilir** + içerik genişliği, yatay dolgu 16
///    (css:229 `.is-scroll`); etiket tek satır + üç nokta; seçilen sekme
///    görünür alana kayar.
///
/// * [GuTabItem.count] → `GuCountBadge(md)` (CD-81; ölçeklenmez, K-57).
/// * Basılı görünüm yoktur (CD-82); klavye odağı 2 px `focus.ring` (css:82).
/// * Semantik: kap `tabBar`, sekme `tab` + `selected` (ui.js:62).
/// * Sekme anahtarı çağırandan ([tabKeyBuilder]:
///   `(i) => GuKey.action('CLB-03.tab.<id>')`, CD-111).
/// * [sticky] `true` → `PinnedHeaderSliver` döner (yalnızca sliver
///   bağlamında; css:225 `position:sticky; top:0`, CLB-03).
class GuTabs extends StatelessWidget {
  const GuTabs({
    required this.tabs,
    required this.value,
    required this.onChanged,
    this.sticky = false,
    this.tabKeyBuilder,
    super.key,
  });

  /// Sekmeler (2–4).
  final List<GuTabItem> tabs;

  /// Seçili sekmenin [GuTabItem.id]'si.
  final String value;

  /// Sekmeye dokunma; seçili olana dokunmada da çağrılır (ui.js:62).
  final ValueChanged<String> onChanged;

  /// `true` → yapışkan sliver.
  final bool sticky;

  /// Sekme anahtarı üreticisi (`GuKey.action('<ID>.tab.<id>')`).
  final Key Function(int index)? tabKeyBuilder;

  @override
  Widget build(BuildContext context) {
    final colors = context.gu.colors;
    final bar = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.bgCanvas,
        border: Border(
          bottom: BorderSide(
            color: colors.borderSoft,
            // Token değeri varsayılanla (1) aynı; kaynak token kalır.
            // ignore: avoid_redundant_argument_values
            width: GuSizes.tabBorder,
          ),
        ),
      ),
      child: LayoutBuilder(builder: _buildBar),
    );
    return sticky ? PinnedHeaderSliver(child: bar) : bar;
  }

  Widget _buildBar(BuildContext context, BoxConstraints constraints) {
    final available = constraints.maxWidth;
    final natural = [for (final tab in tabs) _naturalWidth(context, tab)];
    final total = natural.fold<double>(0, (sum, width) => sum + width);
    final scrollable = !available.isFinite || total > available;
    final share = available / tabs.length;
    final equal = natural.every((width) => width <= share);
    final slack = (available - total) / tabs.length;

    Widget tabAt(int index) {
      final tab = tabs[index];
      return _GuTab(
        key: tabKeyBuilder?.call(index),
        tab: tab,
        selected: tab.id == value,
        scrollable: scrollable,
        maxWidth: available,
        onTap: () => onChanged(tab.id),
      );
    }

    final row = Semantics(
      role: SemanticsRole.tabBar,
      container: true,
      explicitChildNodes: true,
      // Alt kenarlık payı içeride: gösterge kenarlığın üstüne çizilir ve
      // kaydırma kırpmasının içinde kalır.
      child: Padding(
        padding: GuInsets.only(bottom: GuSizes.tabBorder),
        child: Row(
          mainAxisSize: scrollable ? MainAxisSize.min : MainAxisSize.max,
          children: [
            for (var index = 0; index < tabs.length; index++)
              if (scrollable)
                tabAt(index)
              else if (equal)
                Expanded(child: tabAt(index))
              else
                SizedBox(width: natural[index] + slack, child: tabAt(index)),
          ],
        ),
      ),
    );
    if (!scrollable) return row;
    // css:229 `scrollbar-width:none`.
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: row,
      ),
    );
  }

  /// Sekmenin kesilmeden sığdığı genişlik: etiket (+ sayaç, + ikon) + iki
  /// yanda `tabPaddingX` (css:226).
  double _naturalWidth(BuildContext context, GuTabItem tab) {
    final gu = context.gu;
    var width =
        _textWidth(context, tab.label, gu.text.tab, gu.textScaler) +
        GuSizes.tabPaddingX * 2;
    final count = tab.count;
    if (count != null) {
      const badge = GuCountBadgeSize.md;
      final label = _textWidth(
        context,
        '$count',
        gu.text.countBadgeLg,
        TextScaler.noScaling,
      );
      width +=
          GuSizes.tabGap + math.max(badge.minWidth, label + badge.paddingX * 2);
    }
    if (tab.icon != null) width += GuSizes.tabGap + GuSizes.tabIcon;
    return width;
  }

  /// `Text` ile aynı çözümlemeyle tek satır metin genişliği (yukarı
  /// yuvarlanır).
  static double _textWidth(
    BuildContext context,
    String text,
    TextStyle style,
    TextScaler scaler,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: style.inherit
            ? DefaultTextStyle.of(context).style.merge(style)
            : style,
      ),
      textDirection: Directionality.of(context),
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final width = painter.width.ceilToDouble();
    painter.dispose();
    return width;
  }
}

/// Tek sekme — CSS `.tabs>button` (css:226–229).
class _GuTab extends StatefulWidget {
  const _GuTab({
    required this.tab,
    required this.selected,
    required this.scrollable,
    required this.maxWidth,
    required this.onTap,
    super.key,
  });

  final GuTabItem tab;
  final bool selected;

  /// Kaydırılabilir kip: içerik genişliği, yatay dolgu 16.
  final bool scrollable;

  /// Çubuğun kullanılabilir genişliği (kaydırılabilir kipte sekme üst sınırı).
  final double maxWidth;

  final VoidCallback onTap;

  @override
  State<_GuTab> createState() => _GuTabState();
}

class _GuTabState extends State<_GuTab> {
  /// `ensureVisible` hizası: sekme görünür alanın ortasına gelir.
  static const double _revealAlignment = 0.5;

  @override
  void initState() {
    super.initState();
    _reveal(animate: false);
  }

  @override
  void didUpdateWidget(_GuTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected) _reveal(animate: true);
  }

  /// Kaydırılabilir kipte seçili sekmeyi çubuğun görünür alanına getirir
  /// (yalnızca çubuğun kendi yatay kaydırması; sayfa kaydırmasına dokunmaz).
  void _reveal({required bool animate}) {
    if (!widget.selected || !widget.scrollable) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final position = Scrollable.maybeOf(
        context,
        axis: Axis.horizontal,
      )?.position;
      final box = context.findRenderObject();
      if (position == null || box == null) return;
      unawaited(
        position.ensureVisible(
          box,
          alignment: _revealAlignment,
          duration: animate
              ? context.gu.duration(GuMotion.fast)
              : Duration.zero,
          // Token değeri varsayılanla (`Curves.ease`) aynı; kaynak token kalır.
          // ignore: avoid_redundant_argument_values
          curve: GuMotion.easeCss,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => GuActionSurface(
    onTap: widget.onTap,
    selected: widget.selected,
    // css:82 `:focus-visible{border-radius:6px}`.
    borderRadius: GuRadius.borderCheckbox,
    builder: _buildVisual,
  );

  Widget _buildVisual(BuildContext context, bool _) {
    final gu = context.gu;
    final colors = gu.colors;
    final tab = widget.tab;
    final count = tab.count;
    final icon = tab.icon;
    final scrollable = widget.scrollable;
    return Semantics(
      role: SemanticsRole.tab,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: GuSizes.tabHeight,
              maxWidth: scrollable ? widget.maxWidth : double.infinity,
            ),
            child: Padding(
              padding: GuInsets.sym(
                h: scrollable ? GuSizes.tabPaddingXScroll : GuSizes.tabPaddingX,
              ),
              child: Center(
                widthFactor: scrollable ? 1 : null,
                heightFactor: 1,
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(
                    end: widget.selected
                        ? colors.brandPrimaryText
                        : colors.textMuted,
                  ),
                  duration: gu.duration(GuMotion.fast),
                  curve: GuMotion.easeCss,
                  builder: (context, color, _) => Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: GuSizes.tabGap,
                    children: [
                      Flexible(
                        child: Text(
                          tab.label,
                          style: gu.text.tab.copyWith(color: color),
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (count != null)
                        GuCountBadge(
                          label: '$count',
                          size: GuCountBadgeSize.md,
                        ),
                      if (icon != null)
                        GuIcon(icon, size: GuSizes.tabIcon, color: color),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (widget.selected)
            Positioned(
              left: 0,
              right: 0,
              bottom: -GuSizes.tabIndicatorBottomOverlap,
              child: Padding(
                padding: GuInsets.sym(h: GuSizes.tabIndicatorInset),
                child: SizedBox(
                  height: GuSizes.tabIndicatorHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.brandPrimary,
                      borderRadius: GuRadius.tabIndicator,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
