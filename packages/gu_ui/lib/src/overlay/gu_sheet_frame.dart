import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/icons/gu_icons.dart';
import 'package:gu_ui/src/overlay/gu_overlay_route.dart';
import 'package:gu_ui/src/tokens/gu_motion.dart';
import 'package:gu_ui/src/tokens/gu_radius.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';
import 'package:gu_ui/src/widgets/layout/gu_content_column.dart';
import 'package:gu_ui/src/widgets/primitives/gu_button.dart';
import 'package:gu_ui/src/widgets/primitives/gu_icon_button.dart';

/// Alt sayfa çerçevesi — prototip `SheetFrame` (`ui.js:167–181`), CSS
/// `.sheet` / `.sheet-handle` / `.sheet-head` / `.sheet-body` / `.sheet-foot`
/// (css:268–278). 33 sheet'in ortak kabuğu (SHT-34 `ImageViewer` ayrı).
///
/// Yerleşim: 36×4 tutamaç · başlık satırı ([title] titleM + [headerExtra] +
/// kapat X) · kaydırılabilir [body] · [footer].
///
/// * Varyantlar: varsayılan (en çok %90), [menu] (en çok %80), [full]
///   (yükseklik %90), [flush] (gövde dolgusu 0 / 0 / 8), [footer] (üst
///   çizgi, dolgu 12 / 16 + alt güvenli alan; `GuButton` çocuklar satırı
///   eşit paylaşır — css:277). Oranlar `ekran − üst inset` üzerindendir
///   (K-07); klavye açıkken çerçeve kalan alanı aşmaz, gövde kayar.
/// * Kapanma yolları — X, aşağı sürükleme (> `GuSizes.sheetDragCloseThreshold`;
///   gövde başa kaydırılmışken gövdeden de), geri tuşu ve scrim — tek kapıdan
///   geçer: [onWillClose] `false` dönerse açık kalır (kirli form → DLG-25
///   çağıranda), sonra [onClose] ya da verilmemişse çerçeve kendi rotasını
///   kapatır.
/// * Yüzey `bg.surfaceRaised`, üst köşeler `GuRadius.topXl`, gölge `e3`;
///   koyu temada 1 px `border.default` üst kenarlık (css:269).
/// * Alt güvenli alan gerçek `MediaQuery.padding.bottom`'dur: footer varsa
///   footer'a, yoksa gövde dolgusuna eklenir.
/// * `GuContentColumn` ile sarılıdır (CD-29). Yüksekliğini `MediaQuery`'den
///   kendisi sınırlar; [showGuSheet] ile açılır (CD-113: view'dan doğrudan
///   değil, `FeedbackService.showSheet`).
class GuSheetFrame extends StatefulWidget {
  const GuSheetFrame({
    required this.title,
    required this.closeSemanticLabel,
    required this.body,
    this.footer,
    this.headerExtra,
    this.full = false,
    this.menu = false,
    this.flush = false,
    this.onWillClose,
    this.onClose,
    this.closeKey,
    super.key,
  }) : assert(!(full && menu), 'full ve menu birlikte kullanılmaz.');

  /// Başlık (çağırandan; ARB). Rota adı olarak da okunur (`aria-label`).
  final String title;

  /// Kapat düğmesinin erişilebilirlik etiketi (`a11y.close`).
  final String closeSemanticLabel;

  /// Gövde; çerçeve kaydırılabilir alana alır.
  final Widget body;

  /// Alt eylem alanı (`.sheet-foot`); `null` / boş → çizilmez.
  final List<Widget>? footer;

  /// Başlık ile kapat düğmesi arasındaki ek öğe (SHT-09).
  final Widget? headerExtra;

  /// Sabit yükseklik %90 (`.sheet-full`).
  final bool full;

  /// En çok yükseklik %80 (`.sheet.is-menu`).
  final bool menu;

  /// Gövde yatay dolgusu yok, alt dolgu 8 (`.sheet-body.is-flush`).
  final bool flush;

  /// Kapanmadan önce sorulur; `false` → açık kalır (prototip `dirty`).
  final Future<bool> Function()? onWillClose;

  /// Kapatma eylemi; `null` → çerçeve kendi rotasını `pop` eder. Verilirse
  /// dört kapanma yolu da bunu çağırır (kapatmak çağıranın işidir).
  final VoidCallback? onClose;

  /// Kapat düğmesinin anahtarı (`<ID>.close`, CD-111).
  final Key? closeKey;

  @override
  State<GuSheetFrame> createState() => _GuSheetFrameState();
}

class _GuSheetFrameState extends State<GuSheetFrame> {
  /// Sürüklemeyle aşağı kayma (dp, ≥ 0) — `translateY(dy)` ui.js:172.
  double _dragOffset = 0;
  bool _dragging = false;
  bool _asking = false;

  Future<void> _requestClose() async {
    if (_asking) return;
    final guard = widget.onWillClose;
    if (guard != null) {
      _asking = true;
      final bool allowed;
      try {
        allowed = await guard();
      } finally {
        _asking = false;
      }
      if (!mounted) return;
      if (!allowed) {
        setState(() => _dragOffset = 0);
        return;
      }
    }
    final onClose = widget.onClose;
    if (onClose != null) {
      onClose();
    } else if (ModalRoute.of(context)?.isCurrent ?? false) {
      Navigator.of(context).pop();
    }
  }

  void _dragBy(double delta) {
    setState(() {
      _dragging = true;
      _dragOffset = math.max(0, _dragOffset + delta);
    });
  }

  void _dragEnd() {
    // İçteki bir dokunma (düğme) sürükleme adayını iptal eder; sayılmaz.
    if (!_dragging) return;
    final close = _dragOffset > GuSizes.sheetDragCloseThreshold;
    setState(() {
      _dragging = false;
      if (!close) _dragOffset = 0;
    });
    if (close) unawaited(_requestClose());
  }

  /// Gövde başa kaydırılmışken aşağı çekme çerçeveyi sürükler (ui.js:171
  /// `body.scrollTop > 0` değilse). İç içe kaydırıcılar (tekerlek, metin
  /// alanı) `depth > 0` ile dışarıda kalır.
  bool _onBodyScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    switch (notification) {
      case OverscrollNotification(:final overscroll, :final dragDetails):
        if (dragDetails != null && overscroll < 0) _dragBy(-overscroll);
      case ScrollUpdateNotification(:final scrollDelta, :final dragDetails):
        if (_dragOffset > 0 && dragDetails != null && scrollDelta != null) {
          _dragBy(-scrollDelta);
        }
      case ScrollEndNotification():
        _dragEnd();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final colors = gu.colors;
    final media = MediaQuery.of(context);
    // css:268/270/278 yüzdeleri `ekran − üst inset` üzerinden (K-07);
    // klavye açıkken kalan alan aşılmaz.
    final usable = math.max<double>(
      0,
      media.size.height - media.viewPadding.top,
    );
    final ratio = widget.full
        ? GuSizes.sheetFullHeightRatio
        : widget.menu
        ? GuSizes.sheetMenuMaxHeightRatio
        : GuSizes.sheetMaxHeightRatio;
    final maxHeight = math.max<double>(
      0,
      math.min(usable * ratio, usable - media.viewInsets.bottom),
    );
    final safeBottom = media.padding.bottom;
    final footer = widget.footer;
    final hasFooter = footer != null && footer.isNotEmpty;
    final enableDrag =
        context
            .dependOnInheritedWidgetOfExactType<_GuSheetScope>()
            ?.enableDrag ??
        true;
    final borderTop = gu.isDark ? GuSizes.sheetBorderDark : 0.0;

    final body = NotificationListener<ScrollNotification>(
      onNotification: enableDrag ? _onBodyScroll : null,
      child: ScrollConfiguration(
        // css:274 `scrollbar-width:none`; baştaki çekme çerçeveyi sürükler
        // (esneme / sıçrama yok).
        behavior: ScrollConfiguration.of(context).copyWith(
          scrollbars: false,
          overscroll: false,
          physics: const ClampingScrollPhysics(),
        ),
        child: SingleChildScrollView(
          padding: GuInsets.only(
            left: widget.flush ? 0 : GuSizes.sheetBodyPaddingX,
            right: widget.flush ? 0 : GuSizes.sheetBodyPaddingX,
            bottom:
                (widget.flush
                    ? GuSizes.sheetBodyFlushPaddingBottom
                    : GuSizes.sheetBodyPaddingBottom) +
                (hasFooter ? 0 : safeBottom),
          ),
          child: widget.body,
        ),
      ),
    );

    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: GuInsets.only(top: GuSizes.sheetHandleTop),
          child: Center(
            child: SizedBox(
              width: GuSizes.sheetHandleWidth,
              height: GuSizes.sheetHandleHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.borderDefault,
                  borderRadius: GuRadius.borderHandle,
                ),
              ),
            ),
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: GuSizes.sheetHeadMinHeight,
          ),
          child: Padding(
            padding: GuInsets.only(
              left: GuSizes.sheetHeadPaddingLeft,
              top: GuSizes.sheetHeadPaddingY,
              right: GuSizes.sheetHeadPaddingRight,
              bottom: GuSizes.sheetHeadPaddingY,
            ),
            child: Row(
              spacing: GuSizes.sheetHeadGap,
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    namesRoute: true,
                    child: Text(widget.title, style: gu.text.titleM),
                  ),
                ),
                ?widget.headerExtra,
                GuIconButton(
                  key: widget.closeKey,
                  icon: GuIcons.x,
                  semanticLabel: widget.closeSemanticLabel,
                  onPressed: _requestClose,
                ),
              ],
            ),
          ),
        ),
        if (widget.full) Expanded(child: body) else Flexible(child: body),
        if (hasFooter)
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: colors.borderSoft,
                  // Token değeri varsayılanla (1) aynı; kaynak token kalır.
                  // ignore: avoid_redundant_argument_values
                  width: GuSizes.sheetFootBorder,
                ),
              ),
            ),
            child: Padding(
              padding: GuInsets.only(
                left: GuSizes.sheetFootPaddingX,
                top: GuSizes.sheetFootBorder + GuSizes.sheetFootPaddingY,
                right: GuSizes.sheetFootPaddingX,
                bottom: GuSizes.sheetFootPaddingY + safeBottom,
              ),
              child: Row(
                spacing: GuSizes.sheetFootGap,
                children: [
                  for (final child in footer)
                    if (child is GuButton) Expanded(child: child) else child,
                ],
              ),
            ),
          ),
      ],
    );

    Widget sheet = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.bgSurfaceRaised,
        borderRadius: GuRadius.topXl,
        boxShadow: gu.shadows.e3,
        border: gu.isDark
            ? Border(
                top: BorderSide(
                  color: colors.borderDefault,
                  // Token değeri varsayılanla (1) aynı; kaynak token kalır.
                  // ignore: avoid_redundant_argument_values
                  width: GuSizes.sheetBorderDark,
                ),
              )
            : null,
      ),
      child: Padding(
        padding: GuInsets.only(top: borderTop),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: widget.full ? maxHeight : 0,
            maxHeight: maxHeight,
          ),
          child: column,
        ),
      ),
    );
    if (enableDrag) {
      sheet = GestureDetector(
        // Parmağın indiği noktadan ölçülür (`clientY − start`, ui.js:172).
        dragStartBehavior: DragStartBehavior.down,
        excludeFromSemantics: true,
        onVerticalDragUpdate: (details) => _dragBy(details.delta.dy),
        onVerticalDragEnd: (_) => _dragEnd(),
        onVerticalDragCancel: _dragEnd,
        child: sheet,
      );
    }

    return PopScope<Object?>(
      canPop: widget.onWillClose == null && widget.onClose == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_requestClose());
      },
      child: GuContentColumn(
        child: Semantics(
          scopesRoute: true,
          explicitChildNodes: true,
          // Sürüklenirken anlık (ui.js:172 `animation:none`), bırakınca yerine
          // döner.
          child: AnimatedContainer(
            duration: _dragging ? Duration.zero : gu.duration(GuMotion.base),
            curve: GuMotion.easeStandard,
            transform: Matrix4.translationValues(0, _dragOffset, 0),
            child: sheet,
          ),
        ),
      ),
    );
  }
}

/// [showGuSheet] ayarlarını çerçeveye taşır.
class _GuSheetScope extends InheritedWidget {
  const _GuSheetScope({required this.enableDrag, required super.child});

  final bool enableDrag;

  @override
  bool updateShouldNotify(_GuSheetScope oldWidget) =>
      oldWidget.enableDrag != enableDrag;
}

/// `@keyframes sheetIn` (css:414): `translateY(100%) → 0`, `--ease-emphasized`.
Widget _sheetTransition(Animation<double> animation, Widget child) {
  final slide = animation.drive(CurveTween(curve: GuMotion.easeEmphasized));
  return AnimatedBuilder(
    animation: slide,
    builder: (context, child) => FractionalTranslation(
      translation: Offset(0, 1 - slide.value),
      child: child,
    ),
    child: child,
  );
}

/// Alt sayfa primitifi: [builder] (bir [GuSheetFrame] döndürür) içeriğini
/// alttan açar; rota kapanınca `pop` sonucunu verir.
///
/// * Giriş `GuMotion.sheetEnter` + `easeEmphasized` (css:268); scrim
///   `overlay.scrim`, `GuMotion.base` içinde solar (css:267). Azaltılmış
///   harekette süre sıfırdır.
/// * [isDismissible] `false` → scrim dokunuşu kapatmaz; [enableDrag] `false`
///   → sürükleyerek kapanmaz. Geri tuşu ve X her durumda çerçevenin
///   `onWillClose` kapısından geçer.
/// * [scrimKey] scrim'in görünen bandına (`<ID>.scrim`), [barrierLabel]
///   scrim'in erişilebilirlik etiketine gider.
/// * Klavye açıkken sayfa `viewInsets.bottom` kadar yukarı kayar.
///
/// View'dan doğrudan çağrılmaz; tek giriş `FeedbackService.showSheet`
/// (CD-113).
Future<T?> showGuSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool useRootNavigator = true,
  bool isDismissible = true,
  bool enableDrag = true,
  String? barrierLabel,
  Key? scrimKey,
}) {
  final gu = context.gu;
  return showGuOverlay<T>(
    context,
    anchor: GuOverlayAnchor.bottom,
    transition: _sheetTransition,
    duration: gu.duration(GuMotion.sheetEnter),
    barrierCurve: Interval(
      0,
      GuMotion.base.inMicroseconds / GuMotion.sheetEnter.inMicroseconds,
      curve: GuMotion.easeCss,
    ),
    barrierDismissible: isDismissible,
    useRootNavigator: useRootNavigator,
    barrierColor: gu.colors.overlayScrim,
    barrierLabel: barrierLabel,
    scrimKey: scrimKey,
    builder: (context) => _GuSheetScope(
      enableDrag: enableDrag,
      child: Builder(builder: builder),
    ),
  );
}
