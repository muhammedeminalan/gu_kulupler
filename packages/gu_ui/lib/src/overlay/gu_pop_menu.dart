import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/icons/gu_icon.dart';
import 'package:gu_ui/src/icons/gu_icons.dart';
import 'package:gu_ui/src/overlay/gu_overlay_route.dart';
import 'package:gu_ui/src/tokens/gu_motion.dart';
import 'package:gu_ui/src/tokens/gu_opacity.dart';
import 'package:gu_ui/src/tokens/gu_radius.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';
import 'package:gu_ui/src/widgets/layout/gu_content_column.dart';
import 'package:gu_ui/src/widgets/primitives/gu_action_surface.dart';

/// Açılır menü kutusu — prototip `PopMenu` (`ui.js:191`), CSS `.popmenu`
/// (css:279).
///
/// Yüzey `bg.surfaceRaised`, `GuRadius.md`, gölge `e2`, 1 px `border.soft`,
/// dolgu 6; en az genişlik `GuSizes.popMenuMinWidth`, daha uzun etiketle
/// içeriğe göre genişler. [items] alt alta dizilir ([GuPopMenuItem]).
///
/// Konum kutunun değil [showGuPopMenu]'nün işidir (CD-83: sabit sağ üst;
/// tetikleyiciye hizalama ve anchor parametresi yok). Açılış view'dan
/// doğrudan değil, `FeedbackService.showMenu` üzerinden (CD-113).
class GuPopMenu extends StatelessWidget {
  const GuPopMenu({required this.items, this.semanticLabel, super.key});

  /// Menü öğeleri ([GuPopMenuItem]).
  final List<Widget> items;

  /// Menünün rota adı (ekran okuyucu); `null` → adsız.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final colors = gu.colors;
    // css:78 `box-sizing:border-box`: kenarlık en az genişliğe ve dolguya
    // dahildir.
    const inset = GuSizes.popMenuBorder + GuSizes.popMenuPadding;
    return Semantics(
      scopesRoute: true,
      namesRoute: semanticLabel != null,
      label: semanticLabel,
      explicitChildNodes: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: GuSizes.popMenuMinWidth),
        child: IntrinsicWidth(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.bgSurfaceRaised,
              borderRadius: GuRadius.borderMd,
              boxShadow: gu.shadows.e2,
              border: Border.all(
                color: colors.borderSoft,
                // Token değeri varsayılanla (1) aynı; kaynak token kalır.
                // ignore: avoid_redundant_argument_values
                width: GuSizes.popMenuBorder,
              ),
            ),
            child: Padding(
              padding: GuInsets.sym(h: inset, v: inset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: items,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Açılır menü öğesi — `.popmenu .tile` (css:280): en az yükseklik 48,
/// dolgu 6 / 12, radius 10; `Tile`'ın menüye özgü ölçüleri.
///
/// * [icon] 20 px, [label] bodyM `text.heading`; [danger] ikisini de
///   `state.danger` yapar (css:213).
/// * [selected] → sonda `check` 18 px `brand.primaryText` (SHT-01 dil
///   menüsü, `sheets.js:11`).
/// * Basılı zemin `bg.surfaceMuted` (css:212 `:hover` → basılı, K-53).
/// * [disabled] → opaklık `GuOpacity.disabled`, dokunma yok sayılır
///   (css:213; MGT-08 salt okunur).
/// * Dokunma önce menüyü kapatır ([showGuPopMenu] sonucu [value] olur),
///   sonra [onTap]'i çağırır (prototip `close(); …`).
/// * `key: GuKey.action('ID.menu.aksiyon')` (CD-111).
class GuPopMenuItem extends StatelessWidget {
  const GuPopMenuItem({
    required this.label,
    this.icon,
    this.onTap,
    this.value,
    this.danger = false,
    this.disabled = false,
    this.selected = false,
    super.key,
  });

  /// Öğe metni (çağırandan; ARB).
  final String label;

  /// Baştaki ikon.
  final GuIcons? icon;

  /// Menü kapandıktan sonra çağrılır.
  final VoidCallback? onTap;

  /// [showGuPopMenu]'nün döndüreceği değer.
  final Object? value;

  /// Yıkıcı eylem görünümü.
  final bool danger;

  /// Devre dışı: soluk, dokunma yok sayılır.
  final bool disabled;

  /// Seçili: sonda onay işareti.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<_GuPopMenuScope>();
    return GuActionSurface(
      onTap: () {
        if (disabled) return;
        scope?.close(value);
        onTap?.call();
      },
      enabled: !disabled,
      selected: selected ? true : null,
      borderRadius: GuRadius.borderChip,
      builder: _buildVisual,
    );
  }

  Widget _buildVisual(BuildContext context, bool pressed) {
    final gu = context.gu;
    final colors = gu.colors;
    final foreground = danger ? colors.stateDanger : colors.textHeading;
    final leading = icon;
    return Opacity(
      opacity: disabled ? GuOpacity.disabled : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: pressed ? colors.bgSurfaceMuted : null,
          borderRadius: GuRadius.borderChip,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: GuSizes.popMenuTileMinHeight,
          ),
          child: Padding(
            padding: GuInsets.sym(
              h: GuSizes.popMenuTilePaddingX,
              v: GuSizes.popMenuTilePaddingY,
            ),
            child: Row(
              spacing: GuSizes.tileGap,
              children: [
                if (leading != null)
                  GuIcon(leading, size: GuSizes.icon20, color: foreground),
                Expanded(
                  child: Text(
                    label,
                    style: gu.text.bodyM.copyWith(color: foreground),
                  ),
                ),
                if (selected)
                  GuIcon(
                    GuIcons.check,
                    size: GuSizes.icon18,
                    color: colors.brandPrimaryText,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// [showGuPopMenu] rotasını öğelere bağlar (dokununca kapat).
class _GuPopMenuScope extends InheritedWidget {
  const _GuPopMenuScope({required this.close, required super.child});

  final ValueChanged<Object?> close;

  @override
  bool updateShouldNotify(_GuPopMenuScope oldWidget) => false;
}

/// Açılır menü primitifi: [items] ile bir [GuPopMenu]'yü sabit konumda açar
/// (CD-83) — uygulama çubuğunun altı, sağ üst: `top: viewPadding.top +
/// GuSizes.popMenuTop`, `right: GuSizes.popMenuRight` (css:279; `--safe-top`
/// yerine gerçek inset, K-07), geniş ekranda 480 sütununun sağ kenarına göre
/// (CD-29).
///
/// * Scrim saydamdır (ui.js:191); dokunuşu, geri tuşu ve Esc menüyü kapatır
///   (sonuç `null`). Öğeye dokunma menüyü öğenin `value`'su ile kapatır.
/// * Giriş `dialogIn` (css:279): solma + ölçek, `GuMotion.base` +
///   `easeStandard`; azaltılmış harekette süre sıfırdır.
/// * [scrimKey] scrim'in görünen bandına (`<ID>.scrim`), [barrierLabel]
///   scrim'in, [semanticLabel] menünün erişilebilirlik etiketine gider.
///
/// View'dan doğrudan çağrılmaz; tek giriş `FeedbackService.showMenu`
/// (CD-113).
Future<T?> showGuPopMenu<T>(
  BuildContext context, {
  required List<Widget> items,
  Key? scrimKey,
  String? barrierLabel,
  String? semanticLabel,
  bool useRootNavigator = true,
}) => showGuOverlay<T>(
  context,
  anchor: GuOverlayAnchor.top,
  transition: guOverlayFadeScale,
  duration: context.gu.duration(GuMotion.base),
  barrierCurve: GuMotion.easeCss,
  barrierDismissible: true,
  useRootNavigator: useRootNavigator,
  barrierLabel: barrierLabel,
  scrimKey: scrimKey,
  builder: (context) => GuContentColumn(
    child: Padding(
      padding: GuInsets.only(
        left: GuSizes.popMenuRight,
        top: MediaQuery.viewPaddingOf(context).top + GuSizes.popMenuTop,
        right: GuSizes.popMenuRight,
      ),
      child: Align(
        alignment: Alignment.topRight,
        heightFactor: 1,
        child: _GuPopMenuScope(
          close: (value) =>
              Navigator.of(context).pop<T>(value is T ? value : null),
          child: GuPopMenu(items: items, semanticLabel: semanticLabel),
        ),
      ),
    ),
  ),
);
