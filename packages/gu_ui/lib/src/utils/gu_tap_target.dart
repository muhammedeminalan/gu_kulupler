import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';

/// Dokunma hedefi sarmalayıcısı (D-22, K-03; widget-catalog ek-3).
///
/// Görsel ölçü ve yerleşim tasarımdaki gibi kalır (`btn-sm` 40, çip 38,
/// anahtar 44×26…); **etkin dokunma alanı** görünmez dolguyla ≥ 44 pt (iOS) /
/// 48 dp (Android) olur. CSS karşılığı `::after{inset:-N}`: `.hit` −6
/// (css:107), `.chip` −6 (css:179), `.switch` −11/−4 (css:232),
/// `.check,.radio` −13 (css:239) → `GuSizes.*HitInset`.
///
/// İki kullanım:
///
/// * **Hareketli** ([onTap] / [onLongPress] verilir): dokunmayı kendisi
///   yakalar, `Semantics(button, enabled, label, onTap)` ekler. Basılı
///   görünüm için [onPressedChanged]. [semanticLabel] verilirse çocukların
///   semantiği dışlanır (etiket onların yerine okunur). Rolü farklı olan
///   (anahtar, onay kutusu, seçili çip) çağıran [excludeFromSemantics] ile
///   kendi `Semantics`'ini **`container: false`** olarak çocuğa koyar; düğüm
///   bu widget'ın genişletilmiş kutusuna birleşir.
/// * **Yalnız genişletme** (ikisi de `null`): çocuğun kendi algılayıcısı
///   (`GestureDetector`, metin alanı) genişletilmiş alandan da vurulur.
///
/// Genişletilmiş alan: çocuk kutusu [inset] kadar şişirilir, hâlâ
/// [minSize]'dan küçükse her eksende simetrik olarak [minSize]'a
/// tamamlanır. Alan atalarının kutusunu ve kırpmasını aşamaz (kaydırılabilir
/// liste / `ClipRect` içinde çevredeki boşluk kadar etkindir); komşu hedefle
/// aradaki boşluk dolgudan dar ise sonra çizilen komşu önce vurulur — o
/// durumda [inset] ile daraltın.
///
/// `enabled: false` → genişletme ve geri çağrı yok (düz proxy).
class GuTapTarget extends StatelessWidget {
  const GuTapTarget({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onPressedChanged,
    this.semanticLabel,
    this.enabled = true,
    this.behavior = HitTestBehavior.opaque,
    this.minSize,
    this.inset,
    this.excludeFromSemantics = false,
    super.key,
  });

  /// Görsel içerik; boyutu ve yerleşimi değişmez.
  final Widget child;

  /// Dokunma; `null` ve [onLongPress] `null` → yalnız genişletme.
  final VoidCallback? onTap;

  /// Uzun basma.
  final VoidCallback? onLongPress;

  /// Basılı durum değişimi (`true` parmak indi, `false` kalktı / iptal).
  final ValueChanged<bool>? onPressedChanged;

  /// Erişilebilirlik etiketi; verilirse çocuk semantiğinin yerine geçer.
  final String? semanticLabel;

  /// `false` → geri çağrılar çağrılmaz, alan genişletilmez.
  final bool enabled;

  /// Algılayıcının vuruş davranışı (varsayılan tüm kutu).
  final HitTestBehavior behavior;

  /// En küçük etkin kenar; `null` → [minSizeFor] (`defaultTargetPlatform`).
  final double? minSize;

  /// CSS `::after{inset:-N}` eşdeğeri (pozitif değer dışa doğru).
  final EdgeInsets? inset;

  /// `true` → düğme semantiği eklenmez (çağıran kendi `Semantics`'ini verir).
  final bool excludeFromSemantics;

  /// Platform kılavuzundaki en küçük hedef: iOS / macOS
  /// `GuSizes.tapTargetIos` (44), diğerleri `GuSizes.tapTargetAndroid` (48).
  static double minSizeFor(TargetPlatform platform) =>
      (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS)
      ? GuSizes.tapTargetIos
      : GuSizes.tapTargetAndroid;

  @override
  Widget build(BuildContext context) {
    var content = child;
    if (onTap != null || onLongPress != null) {
      final pressed = enabled ? onPressedChanged : null;
      content = GestureDetector(
        behavior: behavior,
        excludeFromSemantics: true,
        onTap: enabled ? onTap : null,
        onLongPress: enabled ? onLongPress : null,
        onTapDown: pressed == null ? null : (_) => pressed(true),
        onTapUp: pressed == null ? null : (_) => pressed(false),
        onTapCancel: pressed == null ? null : () => pressed(false),
        child: content,
      );
      if (!excludeFromSemantics) {
        content = Semantics(
          button: true,
          enabled: enabled,
          label: semanticLabel,
          excludeSemantics: semanticLabel != null,
          onTap: enabled ? onTap : null,
          onLongPress: enabled ? onLongPress : null,
          child: content,
        );
      }
    }
    return _GuTapTargetBox(
      minSize: minSize ?? minSizeFor(defaultTargetPlatform),
      inset: inset,
      enabled: enabled,
      child: content,
    );
  }
}

class _GuTapTargetBox extends SingleChildRenderObjectWidget {
  const _GuTapTargetBox({
    required this.minSize,
    required this.inset,
    required this.enabled,
    required Widget super.child,
  });

  final double minSize;
  final EdgeInsets? inset;
  final bool enabled;

  @override
  RenderGuTapTarget createRenderObject(BuildContext context) =>
      RenderGuTapTarget(minSize: minSize, inset: inset, enabled: enabled);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderGuTapTarget renderObject,
  ) {
    renderObject
      ..minSize = minSize
      ..inset = inset
      ..enabled = enabled;
  }
}

/// [GuTapTarget]'ın kutusu: boyut ve boyama çocukla aynıdır; yalnızca vuruş
/// testi ve semantik sınır [hitRect]'e genişler (`meetsGuideline(
/// androidTapTargetGuideline)` düğüm kutusunu ölçer).
class RenderGuTapTarget extends RenderProxyBox {
  RenderGuTapTarget({
    required this._minSize,
    this._inset,
    this._enabled = true,
    RenderBox? child,
  }) : super(child);

  /// En küçük etkin kenar (dp).
  double get minSize => _minSize;
  double _minSize;
  set minSize(double value) {
    if (_minSize == value) return;
    _minSize = value;
    _markHitRectChanged();
  }

  /// Dışa doğru dolgu (`::after` inset eşdeğeri).
  EdgeInsets? get inset => _inset;
  EdgeInsets? _inset;
  set inset(EdgeInsets? value) {
    if (_inset == value) return;
    _inset = value;
    _markHitRectChanged();
  }

  /// `false` → genişletme yok.
  bool get enabled => _enabled;
  bool _enabled;
  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    _markHitRectChanged();
  }

  /// Semantik geometri yalnızca yerleşimle yeniden hesaplanır (düğüm kutusu
  /// `semanticBounds`'tan gelir); boyut değişmese de yerleşim istenir.
  void _markHitRectChanged() => markNeedsLayout();

  /// Yerel koordinatta etkin dokunma dikdörtgeni.
  Rect get hitRect {
    final bounds = Offset.zero & size;
    if (!_enabled) return bounds;
    final inflated = _inset?.inflateRect(bounds) ?? bounds;
    final dx = math.max<double>(0, (_minSize - inflated.width) / 2);
    final dy = math.max<double>(0, (_minSize - inflated.height) / 2);
    return Rect.fromLTRB(
      inflated.left - dx,
      inflated.top - dy,
      inflated.right + dx,
      inflated.bottom + dy,
    );
  }

  @override
  Rect get semanticBounds => hitRect;

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config.isSemanticBoundary = true;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (super.hitTest(result, position: position)) return true;
    final target = child;
    if (target == null || !_enabled || !hitRect.contains(position)) {
      return false;
    }
    // Görünmez dolgudaki dokunuş çocuğun merkezine yönlendirilir; böylece
    // içteki algılayıcı kendi kutusunun dışından da vurulur.
    final center = size.center(Offset.zero);
    return result.addWithRawTransform(
      transform: MatrixUtils.forceToPoint(center),
      position: center,
      hitTest: (result, _) => target.hitTest(result, position: center),
    );
  }
}
