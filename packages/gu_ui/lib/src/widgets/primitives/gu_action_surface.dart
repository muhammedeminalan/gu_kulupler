import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/utils/gu_tap_target.dart';

/// Basılı durumu alan görsel kurucu ([GuActionSurface.builder]).
typedef GuActionSurfaceBuilder =
    Widget Function(BuildContext context, bool pressed);

/// Eylem bileşenlerinin (`GuButton`, `GuIconButton`, `GuFab`, `GuChip`)
/// ortak etkileşim kabuğu — paket içi yardımcı, barrel'da dışa aktarılmaz.
///
/// Prototipte hepsi `<button>`'dur (`ui.js:13`, `:18`, `:54`; `.fab`
/// `screens-admin.js:34`); ortak davranış tek yerde toplanır (D-16):
///
/// * dokunma + görünmez dolgu → `GuTapTarget` (D-22, K-03);
/// * basılı durum → [builder]'ın `pressed` değeri (K-53: CSS `:hover` rengi
///   dokunmada basılı rengi);
/// * klavye odağı → `FocusableActionDetector` + 2 px `focus.ring` halkası,
///   2 px dışarıda (css:82 `:focus-visible`, css:150 `.btn.is-focus`; K-19);
///   Enter / Boşluk [onTap]'i çağırır;
/// * `Semantics(button, enabled, selected, label)` — `container: false`,
///   düğüm `GuTapTarget`'ın genişletilmiş kutusuna birleşir.
///
/// [onTap] `null` → etkileşimsiz: yalnızca [builder] çıktısı çizilir.
class GuActionSurface extends StatefulWidget {
  const GuActionSurface({
    required this.builder,
    required this.borderRadius,
    this.onTap,
    this.enabled = true,
    this.semanticLabel,
    this.selected,
    this.inset,
    this.autofocus = false,
    super.key,
  });

  /// Görsel; `pressed` yalnızca [enabled] iken `true` olur.
  final GuActionSurfaceBuilder builder;

  /// Görselin köşe yarıçapı (odak halkası bunu izler).
  final BorderRadius borderRadius;

  /// Dokunma / klavye etkinleştirme; `null` → etkileşimsiz.
  final VoidCallback? onTap;

  /// `false` → basılı geri bildirimi yok, semantikte devre dışı. [onTap]
  /// yine çağrılır (çağıran `onDisabledPressed`'e yönlendirir, ui.js:11).
  final bool enabled;

  /// Erişilebilirlik etiketi; verilirse çocuk semantiğinin yerine geçer.
  final String? semanticLabel;

  /// `Semantics(selected:)` (çip, `aria-pressed` ui.js:54); `null` → yok.
  final bool? selected;

  /// CSS `::after{inset:-N}` eşdeğeri dokunma dolgusu.
  final EdgeInsets? inset;

  /// İlk karede odağı alır (`data-autofocus`, ui.js:13).
  final bool autofocus;

  @override
  State<GuActionSurface> createState() => _GuActionSurfaceState();
}

class _GuActionSurfaceState extends State<GuActionSurface> {
  bool _pressed = false;
  bool _focusVisible = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  void _setFocusVisible(bool value) {
    if (_focusVisible != value) setState(() => _focusVisible = value);
  }

  @override
  Widget build(BuildContext context) {
    final onTap = widget.onTap;
    final content = widget.builder(context, _pressed && widget.enabled);
    if (onTap == null) return content;
    return GuTapTarget(
      onTap: onTap,
      onPressedChanged: _setPressed,
      inset: widget.inset,
      excludeFromSemantics: true,
      child: FocusableActionDetector(
        autofocus: widget.autofocus,
        onShowFocusHighlight: _setFocusVisible,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              onTap();
              return null;
            },
          ),
        },
        child: Semantics(
          button: true,
          enabled: widget.enabled,
          selected: widget.selected,
          label: widget.semanticLabel,
          excludeSemantics: widget.semanticLabel != null,
          onTap: widget.enabled ? onTap : null,
          child: CustomPaint(
            foregroundPainter: _focusVisible
                ? _FocusRingPainter(
                    color: context.gu.colors.focusRing,
                    borderRadius: widget.borderRadius,
                  )
                : null,
            child: content,
          ),
        ),
      ),
    );
  }
}

/// CSS `outline:2px solid var(--focus-ring);outline-offset:2px` (css:82,
/// 150): halka kutunun dışına çizilir, yerleşimi etkilemez.
class _FocusRingPainter extends CustomPainter {
  const _FocusRingPainter({required this.color, required this.borderRadius});

  final Color color;
  final BorderRadius borderRadius;

  /// Kutudan çizgi eksenine uzaklık: offset + kalınlığın yarısı.
  static const double _spread =
      GuSizes.focusRingOffset + GuSizes.focusRingWidth / 2;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      borderRadius.toRRect(Offset.zero & size).inflate(_spread),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = GuSizes.focusRingWidth
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_FocusRingPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.borderRadius != borderRadius;
}
