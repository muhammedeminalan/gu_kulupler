import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';

/// Yatay şerit dolgusu — `.hscroll` + dolgu değiştiricileri (css:102, 105).
enum GuHorizontalListPadding {
  /// `.hscroll{padding:3px 16px}`.
  normal(GuSizes.hscrollPaddingY, GuSizes.hscrollPaddingY),

  /// `.hscroll.pb16`: alt dolgu 16 (CLB-01, CLB-06, MGT-03, EVT-01).
  bottom(GuSizes.hscrollPaddingY, GuSpacing.s16),

  /// `.hscroll.py8`: üst / alt dolgu 8 (NTF-01, MGT-06, MGT-10, ADM-04,
  /// AUT-06).
  vertical(GuSpacing.s8, GuSpacing.s8);

  const GuHorizontalListPadding(this.topInset, this.bottomInset);

  /// Üst dolgu (dp).
  final double topInset;

  /// Alt dolgu (dp).
  final double bottomInset;

  /// Yatay 16 + [topInset] / [bottomInset].
  EdgeInsets get insets => EdgeInsets.fromLTRB(
    GuSpacing.s16,
    topInset,
    GuSpacing.s16,
    bottomInset,
  );
}

/// Yatay kaydırılan şerit — CSS `.hscroll` (css:105; prototipte ayrı bileşen
/// yok: çip sıraları ve CLB-01 "Kulüplerim" mini kartları). CD-25.
///
/// Çocuklar 8 px aralıkla dizilir, en yüksek çocuğun boyuna gerilir
/// (`display:flex` varsayılanı), kaydırma çubuğu çizilmez; içerik dar olsa da
/// şerit sola yaslanır.
///
/// [snap] — `scroll-snap-type:x proximity`: kaydırma bir çocuğun başlangıcına
/// yakın (≤ [snapProximity]) duracaksa o çocuk sol içerik hizasına (16 px)
/// oturur. CSS'te hiza kabın sol kenarıdır; ilk öğe 0 konumunda kalsın diye
/// içerik hizası kullanılır.
///
/// Dokunma taşması (D-22): kaydırma görünümü dikeyde [tapBleed] kadar
/// yerleşim kutusunun dışına taşar; yerleşim ölçüsü değişmez. Böylece 38 px
/// çipin `GuTapTarget` dolgusu 3 px'lik şerit dolgusunda kırpılmaz: semantik
/// kutu ve gerçek dokunma alanı 48 dp kalır. Taşma bölgesinde yalnızca bir
/// öğenin dokunma alanına denk gelen vuruş alınır; gerisi komşu widget'a
/// geçer.
class GuHorizontalList extends StatefulWidget {
  const GuHorizontalList({
    required this.children,
    this.snap = true,
    this.padding = GuHorizontalListPadding.normal,
    super.key,
  });

  /// Yakalama eşiği (dp) — CSS `proximity` tarayıcıya bırakır; en yakın
  /// boşluk token'ı.
  static const double snapProximity = GuSpacing.s32;

  /// Dikey dokunma taşması (dp): (48 − öğe yüksekliği) / 2 − şerit dolgusu
  /// kadarı yeter; 18 px ve üstü öğeleri kapsar.
  static const double tapBleed = GuSpacing.s12;

  /// Şerit öğeleri.
  final List<Widget> children;

  /// Öğe başlangıcına yakın durunca yakala.
  final bool snap;

  /// Dolgu varyantı.
  final GuHorizontalListPadding padding;

  @override
  State<GuHorizontalList> createState() => _GuHorizontalListState();
}

class _GuHorizontalListState extends State<GuHorizontalList> {
  final GlobalKey _rowKey = GlobalKey();

  RenderObject? _row() => _rowKey.currentContext?.findRenderObject();

  /// Çocukların satır içi başlangıç konumları = yakalama kaydırma konumları.
  List<double> _snapOffsets() {
    final row = _row();
    if (row is! RenderFlex) return const [];
    final offsets = <double>[];
    var child = row.firstChild;
    while (child != null) {
      final data = child.parentData! as FlexParentData;
      offsets.add(data.offset.dx);
      child = data.nextSibling;
    }
    return offsets;
  }

  @override
  Widget build(BuildContext context) {
    // Dikey dolgu öğe başına verilir: satır kutusu şerit yüksekliğini
    // (+ taşma) kaplar; öğelerin dokunma dolgusu bu kutunun içinde gerçekten
    // vurulur.
    final itemPadding = EdgeInsets.only(
      top: widget.padding.topInset + GuHorizontalList.tapBleed,
      bottom: widget.padding.bottomInset + GuHorizontalList.tapBleed,
    );
    return _VerticalBleed(
      bleed: GuHorizontalList.tapBleed,
      row: _row,
      // Dar içerikte kaydırma görünümü içeriğe büzülür; satır soluna yaslanır.
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        heightFactor: 1,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: GuInsets.h16,
            physics: widget.snap ? _SnapPhysics(offsets: _snapOffsets) : null,
            child: IntrinsicHeight(
              child: Row(
                key: _rowKey,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: GuSizes.hscrollGap,
                children: [
                  for (final child in widget.children)
                    Padding(padding: itemPadding, child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Çocuğunu dikeyde [bleed] kadar kendi kutusunun dışına taşırır: çocuk
/// `2 × bleed` daha yüksek yerleşir, kutu o kadar kısa raporlanır. Taşma
/// bölgesindeki vuruş yalnızca [row] (öğe satırı) vuruluyorsa — yani bir
/// öğenin dokunma alanına denk geliyorsa — çocuğa iletilir; kaydırma
/// görünümünün boş alanı komşudan vuruş çalmaz.
class _VerticalBleed extends SingleChildRenderObjectWidget {
  const _VerticalBleed({
    required this.bleed,
    required this.row,
    required Widget super.child,
  });

  final double bleed;
  final RenderObject? Function() row;

  // İki alan da widget ömrünce sabittir (token + State yöntemi); güncelleme
  // gerekmez.
  @override
  _RenderVerticalBleed createRenderObject(BuildContext context) =>
      _RenderVerticalBleed(bleed, row);
}

class _RenderVerticalBleed extends RenderShiftedBox {
  _RenderVerticalBleed(this._bleed, this.row) : super(null);

  final RenderObject? Function() row;
  final double _bleed;

  BoxConstraints _childConstraints(BoxConstraints constraints) =>
      constraints.copyWith(
        minHeight: constraints.minHeight + 2 * _bleed,
        maxHeight: constraints.maxHeight + 2 * _bleed,
      );

  Size _sizeFor(BoxConstraints constraints, Size childSize) => constraints
      .constrain(Size(childSize.width, childSize.height - 2 * _bleed));

  @override
  double computeMinIntrinsicHeight(double width) =>
      math.max(0, super.computeMinIntrinsicHeight(width) - 2 * _bleed);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      math.max(0, super.computeMaxIntrinsicHeight(width) - 2 * _bleed);

  @override
  Size computeDryLayout(BoxConstraints constraints) => _sizeFor(
    constraints,
    child!.getDryLayout(_childConstraints(constraints)),
  );

  @override
  void performLayout() {
    final child = this.child!
      ..layout(_childConstraints(constraints), parentUsesSize: true);
    size = _sizeFor(constraints, child.size);
    (child.parentData! as BoxParentData).offset = Offset(0, -_bleed);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) {
      final bounds = Rect.fromLTRB(
        0,
        -_bleed,
        size.width,
        size.height + _bleed,
      );
      if (!bounds.contains(position)) return false;
      final probe = BoxHitTestResult();
      hitTestChildren(probe, position: position);
      final target = row();
      if (!probe.path.any((entry) => identical(entry.target, target))) {
        return false;
      }
    }
    return hitTestChildren(result, position: position);
  }
}

/// `scroll-snap-type:x proximity` — doğal duruş noktası bir öğe başlangıcına
/// yakınsa yay ile oraya oturur; değilse üst fizik aynen uygulanır.
class _SnapPhysics extends ScrollPhysics {
  const _SnapPhysics({required this.offsets, super.parent});

  final List<double> Function() offsets;

  @override
  _SnapPhysics applyTo(ScrollPhysics? ancestor) =>
      _SnapPhysics(offsets: offsets, parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final natural = super.createBallisticSimulation(position, velocity);
    if (position.outOfRange) return natural;
    final rest = natural?.x(double.infinity) ?? position.pixels;
    if (!rest.isFinite) return natural;

    final min = position.minScrollExtent;
    final max = position.maxScrollExtent;
    double? target;
    for (final offset in offsets()) {
      final candidate = offset.clamp(min, max);
      if (target == null || (candidate - rest).abs() < (target - rest).abs()) {
        target = candidate;
      }
    }
    final tolerance = toleranceFor(position);
    if (target == null ||
        (target - rest).abs() > GuHorizontalList.snapProximity ||
        (target - position.pixels).abs() < tolerance.distance) {
      return natural;
    }
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: tolerance,
    );
  }
}
