import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// [AdaptivePair]'de kalan alanı alan çocuk.
enum AdaptivePairFill {
  /// `trailing` kendi genişliğinde, `leading` kalan alanda.
  leading,

  /// `leading` kendi genişliğinde, `trailing` kalan alanda.
  trailing,
}

/// [AdaptivePair] yuvaları.
enum AdaptivePairSlot {
  /// Baştaki çocuk.
  leading,

  /// Sondaki çocuk.
  trailing,
}

/// Taşmayan iki çocuklu satır — CSS esnek satırının (`.row`) kulüp
/// kartlarındaki karşılığı: `ClubCard` alt satırı (`row between gap8`,
/// `cards.js:38`) ve `ClubCta`'nın rozet + tam genişlik düğme satırı
/// (`row gap8`, `cards.js:26`).
///
/// * Bir çocuk kendi genişliğini alır, [fill] ile seçilen diğeri kalan alanı
///   doldurur ([gap] aralıkla, dikeyde ortalı).
/// * Kalan alan dolduran çocuğun en dar hâline (`minIntrinsicWidth`) yetmezse
///   — dar ekran × büyük metin ölçeği — çocuklar alt alta dizilir: dolduran
///   çocuk tam genişlikte, diğeri kendi genişliğinde (`leading` başta,
///   `trailing` sonda). Satır hiçbir durumda taşmaz.
///
/// Flutter `Row`'u bunu yapamaz: esnek olmayan çocuk sınırsız ölçülür,
/// esnek çocuklar boş alanı payına göre böler (kullanılmayan pay devredilmez).
///
/// Genişlik sınırsızsa çocuklar yan yana kendi genişliklerinde dizilir.
class AdaptivePair
    extends SlottedMultiChildRenderObjectWidget<AdaptivePairSlot, RenderBox> {
  /// [leading] ve [trailing] çocuklarını [gap] aralıkla dizer.
  const AdaptivePair({
    required this.leading,
    required this.trailing,
    required this.gap,
    this.fill = AdaptivePairFill.leading,
    super.key,
  });

  /// Baştaki çocuk.
  final Widget leading;

  /// Sondaki çocuk.
  final Widget trailing;

  /// Çocuklar arası boşluk (yan yana ve alt alta).
  final double gap;

  /// Kalan alanı alan çocuk.
  final AdaptivePairFill fill;

  @override
  Iterable<AdaptivePairSlot> get slots => AdaptivePairSlot.values;

  @override
  Widget childForSlot(AdaptivePairSlot slot) => switch (slot) {
    AdaptivePairSlot.leading => leading,
    AdaptivePairSlot.trailing => trailing,
  };

  @override
  RenderAdaptivePair createRenderObject(BuildContext context) =>
      RenderAdaptivePair(gap: gap, fill: fill);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderAdaptivePair renderObject,
  ) => renderObject
    ..gap = gap
    ..fill = fill;
}

/// [AdaptivePair] yerleşimi.
class RenderAdaptivePair extends RenderBox
    with SlottedContainerRenderObjectMixin<AdaptivePairSlot, RenderBox> {
  /// [gap] aralıklı, [fill] çocuğu kalan alanı alan yerleşim.
  RenderAdaptivePair({required this._gap, required this._fill});

  /// Çocuklar arası boşluk.
  double get gap => _gap;
  double _gap;
  set gap(double value) {
    if (_gap == value) return;
    _gap = value;
    markNeedsLayout();
  }

  /// Kalan alanı alan çocuk.
  AdaptivePairFill get fill => _fill;
  AdaptivePairFill _fill;
  set fill(AdaptivePairFill value) {
    if (_fill == value) return;
    _fill = value;
    markNeedsLayout();
  }

  RenderBox get _leading => childForSlot(AdaptivePairSlot.leading)!;
  RenderBox get _trailing => childForSlot(AdaptivePairSlot.trailing)!;
  bool get _fillsLeading => fill == AdaptivePairFill.leading;

  // Yuvalar sırayla bağlanır: ikisi de gelene kadar eksik olan atlanır.
  @override
  Iterable<RenderBox> get children => [
    ?childForSlot(AdaptivePairSlot.leading),
    ?childForSlot(AdaptivePairSlot.trailing),
  ];

  /// İki çocuğu [width] genişliğine yerleştirir; [layout] gerçek ya da kuru
  /// yerleşimdir. Dönen kayıt: çocuk boyutları + yan yana sığdı mı.
  ({Size leading, Size trailing, bool inline}) _measure(
    double width,
    Size Function(RenderBox child, BoxConstraints constraints) layout,
  ) {
    final fixed = _fillsLeading ? _trailing : _leading;
    final flexible = _fillsLeading ? _leading : _trailing;
    if (width.isInfinite) {
      final fixedSize = layout(fixed, const BoxConstraints());
      final flexibleSize = layout(flexible, const BoxConstraints());
      return (
        leading: _fillsLeading ? flexibleSize : fixedSize,
        trailing: _fillsLeading ? fixedSize : flexibleSize,
        inline: true,
      );
    }
    final fixedSize = layout(fixed, BoxConstraints(maxWidth: width));
    final room = width - gap - fixedSize.width;
    final inline = room >= flexible.getMinIntrinsicWidth(double.infinity);
    final flexibleSize = layout(
      flexible,
      BoxConstraints.tightFor(width: inline ? room : width),
    );
    return (
      leading: _fillsLeading ? flexibleSize : fixedSize,
      trailing: _fillsLeading ? fixedSize : flexibleSize,
      inline: inline,
    );
  }

  Size _sizeOf(
    double width,
    ({Size leading, Size trailing, bool inline}) sizes,
  ) => Size(
    width.isInfinite ? sizes.leading.width + gap + sizes.trailing.width : width,
    sizes.inline
        ? math.max(sizes.leading.height, sizes.trailing.height)
        : sizes.leading.height + gap + sizes.trailing.height,
  );

  static Size _dry(RenderBox child, BoxConstraints constraints) =>
      child.getDryLayout(constraints);

  @override
  double computeMinIntrinsicWidth(double height) => math.max(
    _leading.getMinIntrinsicWidth(height),
    _trailing.getMinIntrinsicWidth(height),
  );

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _leading.getMaxIntrinsicWidth(height) +
      gap +
      _trailing.getMaxIntrinsicWidth(height);

  /// [width] genişliğindeki yükseklik; çocuk yükseklikleri [heightOf] ile
  /// sorulur (yerleşimle aynı karar: yan yana ya da alt alta).
  double _intrinsicHeight(
    double width,
    double Function(RenderBox child, double width) heightOf,
  ) {
    final fixed = _fillsLeading ? _trailing : _leading;
    final flexible = _fillsLeading ? _leading : _trailing;
    if (width.isInfinite) {
      return math.max(heightOf(fixed, width), heightOf(flexible, width));
    }
    final fixedWidth = math.min(
      fixed.getMaxIntrinsicWidth(double.infinity),
      width,
    );
    final room = width - gap - fixedWidth;
    return room >= flexible.getMinIntrinsicWidth(double.infinity)
        ? math.max(heightOf(fixed, fixedWidth), heightOf(flexible, room))
        : heightOf(fixed, fixedWidth) + gap + heightOf(flexible, width);
  }

  @override
  double computeMinIntrinsicHeight(double width) => _intrinsicHeight(
    width,
    (child, childWidth) => child.getMinIntrinsicHeight(childWidth),
  );

  @override
  double computeMaxIntrinsicHeight(double width) => _intrinsicHeight(
    width,
    (child, childWidth) => child.getMaxIntrinsicHeight(childWidth),
  );

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    return constraints.constrain(_sizeOf(width, _measure(width, _dry)));
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final sizes = _measure(width, (child, childConstraints) {
      child.layout(childConstraints, parentUsesSize: true);
      return child.size;
    });
    final box = _sizeOf(width, sizes);
    final leadingData = _leading.parentData! as BoxParentData;
    final trailingData = _trailing.parentData! as BoxParentData;
    final trailingX = box.width - sizes.trailing.width;
    if (sizes.inline) {
      leadingData.offset = Offset(0, (box.height - sizes.leading.height) / 2);
      trailingData.offset = Offset(
        trailingX,
        (box.height - sizes.trailing.height) / 2,
      );
    } else {
      leadingData.offset = Offset.zero;
      trailingData.offset = Offset(trailingX, sizes.leading.height + gap);
    }
    size = constraints.constrain(box);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in children) {
      context.paintChild(
        child,
        offset + (child.parentData! as BoxParentData).offset,
      );
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in [_trailing, _leading]) {
      final isHit = result.addWithPaintOffset(
        offset: (child.parentData! as BoxParentData).offset,
        position: position,
        hitTest: (result, transformed) =>
            child.hitTest(result, position: transformed),
      );
      if (isHit) return true;
    }
    return false;
  }
}
