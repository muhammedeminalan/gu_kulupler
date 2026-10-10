import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/utils/gu_tap_target.dart';

/// Seçim denetiminin erişilebilirlik rolü (prototip `role=`, ui.js:44–49).
enum GuSelectionRole {
  /// `role="switch"` → `Semantics(toggled:)`.
  toggle,

  /// `role="checkbox"` → `Semantics(checked:)`.
  checkbox,

  /// `role="radio"` → `Semantics(checked:, inMutuallyExclusiveGroup: true)`.
  radio,
}

/// Basılı durumu alan görsel kurucu ([GuSelectionSurface.builder]).
typedef GuSelectionBuilder =
    Widget Function(BuildContext context, bool pressed);

/// Seçim denetimlerinin (`GuSwitch`, `GuCheckbox`, `GuRadio`, `GuOptionRow`)
/// ortak etkileşim kabuğu — paket içi yardımcı, barrel'da dışa aktarılmaz.
///
/// Prototipte dördü de `<button role="switch|checkbox|radio">`'dur
/// (`ui.js:44`, `:46`, `:47`, `:49`). `GuActionSurface` düğme rolü yazdığı
/// için burada kullanılmaz; davranış aynıdır:
///
/// * dokunma + görünmez dolgu → `GuTapTarget` (D-22, K-03; css:232, 239);
/// * basılı durum → [builder]'ın `pressed` değeri (yalnızca [enabled] iken);
/// * klavye odağı → `FocusableActionDetector` + 2 px `focus.ring` halkası,
///   2 px dışarıda (css:82 `:focus-visible`; K-19); Enter / Boşluk [onTap];
/// * `Semantics(toggled | checked, enabled, label)` — `container: false`,
///   düğüm `GuTapTarget`'ın genişletilmiş kutusuna birleşir.
///
/// [onTap] `null` → etkileşimsiz gösterge: dokunma hedefi ve odak yok,
/// yalnızca durum semantiği (kendi düğümü).
class GuSelectionSurface extends StatefulWidget {
  const GuSelectionSurface({
    required this.role,
    required this.value,
    required this.builder,
    required this.borderRadius,
    this.onTap,
    this.enabled = true,
    this.semanticLabel,
    this.inset,
    super.key,
  });

  /// Erişilebilirlik rolü.
  final GuSelectionRole role;

  /// Açık / işaretli / seçili.
  final bool value;

  /// Görsel; `pressed` yalnızca [enabled] iken `true` olur.
  final GuSelectionBuilder builder;

  /// Görselin köşe yarıçapı (odak halkası bunu izler).
  final BorderRadius borderRadius;

  /// Dokunma / klavye etkinleştirme; `null` → etkileşimsiz gösterge.
  final VoidCallback? onTap;

  /// `false` → basılı geri bildirimi yok, semantikte devre dışı. [onTap]
  /// yine çağrılır (çağıran devre dışı davranışını kendisi yönlendirir).
  final bool enabled;

  /// Erişilebilirlik etiketi; verilirse çocuk semantiğinin yerine geçer.
  final String? semanticLabel;

  /// CSS `::after{inset:-N}` eşdeğeri dokunma dolgusu.
  final EdgeInsets? inset;

  @override
  State<GuSelectionSurface> createState() => _GuSelectionSurfaceState();
}

class _GuSelectionSurfaceState extends State<GuSelectionSurface> {
  bool _pressed = false;
  bool _focusVisible = false;

  /// Kutudan halkanın dış kenarına uzaklık: offset + kalınlık (css:82).
  static const double _ringSpread =
      GuSizes.focusRingOffset + GuSizes.focusRingWidth;

  void _setPressed(bool value) {
    if (mounted && _pressed != value) setState(() => _pressed = value);
  }

  void _setFocusVisible(bool value) {
    if (mounted && _focusVisible != value) {
      setState(() => _focusVisible = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onTap = widget.onTap;
    final isToggle = widget.role == GuSelectionRole.toggle;
    final label = widget.semanticLabel;
    final content = widget.builder(context, _pressed && widget.enabled);

    Widget semantics({required Widget child, required bool interactive}) =>
        Semantics(
          container: !interactive,
          enabled: interactive ? widget.enabled : null,
          toggled: isToggle ? widget.value : null,
          checked: isToggle ? null : widget.value,
          inMutuallyExclusiveGroup: widget.role == GuSelectionRole.radio
              ? true
              : null,
          label: label,
          excludeSemantics: label != null,
          onTap: interactive && widget.enabled ? onTap : null,
          child: child,
        );

    if (onTap == null) return semantics(child: content, interactive: false);
    return GuTapTarget(
      onTap: onTap,
      onPressedChanged: _setPressed,
      inset: widget.inset,
      excludeFromSemantics: true,
      child: FocusableActionDetector(
        onShowFocusHighlight: _setFocusVisible,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              onTap();
              return null;
            },
          ),
        },
        child: semantics(
          interactive: true,
          // Halka yerleşimi etkilemez (CSS `outline`): kutunun dışına taşan
          // konumlu katman; içerik hep ilk çocuk kalır (durumu korunur).
          child: Stack(
            fit: StackFit.passthrough,
            clipBehavior: Clip.none,
            children: [
              content,
              if (_focusVisible)
                Positioned(
                  left: -_ringSpread,
                  top: -_ringSpread,
                  right: -_ringSpread,
                  bottom: -_ringSpread,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius:
                            widget.borderRadius +
                            const BorderRadius.all(
                              Radius.circular(_ringSpread),
                            ),
                        border: Border.all(
                          color: context.gu.colors.focusRing,
                          width: GuSizes.focusRingWidth,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
