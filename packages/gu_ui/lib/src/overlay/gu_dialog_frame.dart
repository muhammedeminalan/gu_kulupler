import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/icons/gu_icons.dart';
import 'package:gu_ui/src/overlay/gu_overlay_route.dart';
import 'package:gu_ui/src/tokens/gu_motion.dart';
import 'package:gu_ui/src/tokens/gu_radius.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';
import 'package:gu_ui/src/widgets/layout/gu_content_column.dart';
import 'package:gu_ui/src/widgets/primitives/gu_icon_box.dart';

/// Dialog eylemlerinin dizilimi — CSS `.dialog-actions` (css:284–286).
enum GuDialogActionsLayout {
  /// Alt alta, tam genişlik, aralık 6 (varsayılan; 32 dialogun tümü).
  column,

  /// Yan yana, eşit genişlik, ilk eylem sağda (`.is-row` `row-reverse`;
  /// K-35).
  row,
}

/// Dialog çerçevesi — prototip `DialogFrame` (`ui.js:182–190`), CSS
/// `.dialog` / `.dialog-actions` (css:282–286). 32 dialogun ortak kabuğu.
///
/// Yerleşim: [icon] (40 daire; [danger] → `ni-danger`, değilse `ni-brand`) ·
/// [title] titleM · [body] bodyS `text.secondary` · [child] (özel gövde:
/// girdi, geri sayım, adımlar) · [actions].
///
/// * Genişlik `min(GuSizes.dialogMaxWidth, ekran − 2 × dialogMarginX)`
///   (temadaki `DialogThemeData` ile aynı token'lar), en çok yükseklik %85
///   (klavye üstünde kalan alanın); taşarsa tümü kayar (css:282
///   `overflow:auto`).
/// * [actions] sırası çağırandan: birincil / danger → ikincil → metin
///   (`GuButton`). [actionsLayout] `column` düğmeleri tam genişlik dizer.
/// * Yüzey `bg.surfaceRaised`, `GuRadius.lg`, gölge `e2`; koyu temada 1 px
///   `border.default` (css:283).
/// * [dismissable] `false` (DLG-26, DLG-27) → geri tuşu ve scrim kapatmaz
///   (`PopScope`); scrim için ayrıca `showGuDialog(barrierDismissible:)`.
/// * Odak tuzağı rotadadır (Tab döngüsü dialogun dışına çıkmaz).
/// * `GuContentColumn` ile sarılıdır (CD-29); [showGuDialog] ile açılır
///   (CD-113: view'dan doğrudan değil, `FeedbackService.showDialog`).
class GuDialogFrame extends StatelessWidget {
  const GuDialogFrame({
    required this.title,
    required this.actions,
    this.body,
    this.child,
    this.icon,
    this.danger = false,
    this.actionsLayout = GuDialogActionsLayout.column,
    this.dismissable = true,
    super.key,
  });

  /// Başlık (çağırandan; ARB). Rota adı olarak da okunur.
  final String title;

  /// Gövde metni; satır sonları korunur (`prewrap`).
  final String? body;

  /// Özel gövde; [body]'den sonra gelir.
  final Widget? child;

  /// Eylem düğmeleri (`GuButton`; anahtarlar çağıranda).
  final List<Widget> actions;

  /// Üstteki ikon kutusu; `null` → yok (DLG-02).
  final GuIcons? icon;

  /// Yıkıcı işlem: ikon kutusu `state.dangerContainer` / `state.danger`.
  final bool danger;

  /// Eylem dizilimi.
  final GuDialogActionsLayout actionsLayout;

  /// `false` → geri tuşu / scrim kapatmaz.
  final bool dismissable;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final colors = gu.colors;
    final media = MediaQuery.of(context);
    final maxHeight =
        math.max<double>(0, media.size.height - media.viewInsets.bottom) *
        GuSizes.dialogMaxHeightRatio;
    // css:78 `box-sizing:border-box`: koyu kenarlık dolgudan yer.
    final border = gu.isDark ? GuSizes.sheetBorderDark : 0.0;
    final iconName = icon;
    final bodyText = body;

    final Widget actionsArea = switch (actionsLayout) {
      GuDialogActionsLayout.column => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: GuSizes.dialogActionsGap,
        children: actions,
      ),
      GuDialogActionsLayout.row => Row(
        spacing: GuSizes.dialogActionsGap,
        children: [
          for (final action in actions.reversed) Expanded(child: action),
        ],
      ),
    };

    return PopScope<Object?>(
      canPop: dismissable,
      child: GuContentColumn(
        child: Padding(
          padding: GuInsets.sym(h: GuSizes.dialogMarginX),
          child: Align(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: GuSizes.dialogMaxWidth,
                maxHeight: maxHeight,
              ),
              child: Semantics(
                scopesRoute: true,
                explicitChildNodes: true,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.bgSurfaceRaised,
                    borderRadius: GuRadius.borderLg,
                    boxShadow: gu.shadows.e2,
                    border: gu.isDark
                        ? Border.all(color: colors.borderDefault)
                        : null,
                  ),
                  child: SingleChildScrollView(
                    padding: GuInsets.only(
                      left: GuSizes.dialogPaddingX + border,
                      top: GuSizes.dialogPaddingTop + border,
                      right: GuSizes.dialogPaddingX + border,
                      bottom: GuSizes.dialogPaddingBottom + border,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: GuSizes.dialogGap,
                      children: [
                        if (iconName != null)
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: GuIconBox(
                              icon: iconName,
                              tone: danger
                                  ? GuIconBoxTone.danger
                                  : GuIconBoxTone.brand,
                              // Token değeri varsayılanla (40) aynı; kaynak
                              // token kalır.
                              // ignore: avoid_redundant_argument_values
                              size: GuSizes.dialogIconBox,
                              // Token değeri varsayılanla (20) aynı; kaynak
                              // token kalır.
                              // ignore: avoid_redundant_argument_values
                              iconSize: GuSizes.dialogIcon,
                            ),
                          ),
                        Semantics(
                          header: true,
                          namesRoute: true,
                          child: Text(title, style: gu.text.titleM),
                        ),
                        if (bodyText != null)
                          Text(
                            bodyText,
                            style: gu.text.bodyS.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ?child,
                        Padding(
                          padding: GuInsets.only(top: GuSizes.dialogActionsTop),
                          child: actionsArea,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dialog primitifi: [builder] (bir [GuDialogFrame] döndürür) içeriğini
/// ekran ortasında açar; rota kapanınca `pop` sonucunu verir.
///
/// * Giriş solma + ölçek `GuMotion.dialogEnterScale → 1`, `GuMotion.base` +
///   `easeStandard` (css:282, 415); scrim `overlay.scrim` (css:267).
///   Azaltılmış harekette süre sıfırdır.
/// * [barrierDismissible] `false` → scrim dokunuşu ve Esc kapatmaz (geri
///   tuşu için çerçevede `dismissable: false`).
/// * [scrimKey] scrim'in görünen bandına (`<ID>.scrim`), [barrierLabel]
///   scrim'in erişilebilirlik etiketine gider.
/// * Klavye açıkken dialog kalan alanda ortalanır.
///
/// View'dan doğrudan çağrılmaz; tek giriş `FeedbackService.showDialog`
/// (CD-113).
Future<T?> showGuDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  bool useRootNavigator = true,
  String? barrierLabel,
  Key? scrimKey,
}) {
  final gu = context.gu;
  return showGuOverlay<T>(
    context,
    anchor: GuOverlayAnchor.center,
    transition: guOverlayFadeScale,
    duration: gu.duration(GuMotion.base),
    barrierCurve: GuMotion.easeCss,
    barrierDismissible: barrierDismissible,
    useRootNavigator: useRootNavigator,
    barrierColor: gu.colors.overlayScrim,
    barrierLabel: barrierLabel,
    scrimKey: scrimKey,
    builder: builder,
  );
}
