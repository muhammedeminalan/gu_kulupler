import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/icons/gu_icons.dart';
import 'package:gu_ui/src/tokens/gu_opacity.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';
import 'package:gu_ui/src/widgets/primitives/gu_icon_button.dart';

/// Sayaç adımlayıcı − / değer / + — MGT-05 kontenjan satırı
/// (`screens-manage.js:112`); ayrı CSS yok, kompozisyon:
/// `row gap12 justify-content:center` içinde `IconButton minus` + değer +
/// `IconButton plus`.
///
/// * Düğmeler `GuIconButton` (48) + `bg.surfaceMuted` daire zemin
///   (satır içi `background:var(--bg-surface-muted)`).
/// * Değer: `min-width:64px;text-align:center` + `.tnum`. `kpi-value` sınıfı
///   `.kpi` kapsayıcısı dışında kural taşımaz (css:303 `.kpi .kpi-value`) →
///   metin kökten gövde yazısını alır (`bodyM` 15 / 1.47, `text.primary`).
/// * Durumlar D X: [value] ≤ [min] → eksi, ≥ [max] → artı devre dışı
///   (`GuIconButton` opaklık .45); [disabled] ikisini de kapatır.
/// * Dokunma `onChanged(value ∓ step)`'i [min] / [max] aralığına kırparak
///   çağırır (`Math.max(1, v − 5)` / `Math.min(1000, v + 5)`; adım ve sınırlar
///   çağırandan).
/// * Anahtarlar çağırandan: [minusKey] / [plusKey]
///   (`MGT-05.capacity.minus` / `.plus`; CD-111).
class GuStepper extends StatelessWidget {
  const GuStepper({
    required this.value,
    required this.onChanged,
    required this.decreaseSemanticLabel,
    required this.increaseSemanticLabel,
    this.min,
    this.max,
    this.step = 1,
    this.disabled = false,
    this.semanticLabel,
    this.minusKey,
    this.plusKey,
    super.key,
  }) : assert(step > 0, 'step pozitif olmalı.'),
       assert(
         min == null || max == null || min <= max,
         'min, max değerinden büyük olamaz.',
       );

  /// Geçerli değer.
  final int value;

  /// Yeni değer (sınırlara kırpılmış).
  final ValueChanged<int> onChanged;

  /// Eksi düğmesinin etiketi (`eventForm.decrease`).
  final String decreaseSemanticLabel;

  /// Artı düğmesinin etiketi (`eventForm.increase`).
  final String increaseSemanticLabel;

  /// Alt sınır; `null` → sınırsız.
  final int? min;

  /// Üst sınır; `null` → sınırsız.
  final int? max;

  /// Adım.
  final int step;

  /// İki düğme de devre dışı.
  final bool disabled;

  /// Değerin erişilebilirlik etiketi (ör. "Kontenjan").
  final String? semanticLabel;

  /// Eksi düğmesinin anahtarı.
  final Key? minusKey;

  /// Artı düğmesinin anahtarı.
  final Key? plusKey;

  // ignore-hardcode: eksik token — screens-manage.js:112 `min-width:64px`
  static const double _valueMinWidth = 64;

  bool get _canDecrease => !disabled && (min == null || value > min!);

  bool get _canIncrease => !disabled && (max == null || value < max!);

  void _decrease() => onChanged(math.max(min ?? value - step, value - step));

  void _increase() => onChanged(math.min(max ?? value + step, value + step));

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    return Center(
      heightFactor: 1,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: GuSpacing.s12,
        children: [
          _button(
            context,
            key: minusKey,
            icon: GuIcons.minus,
            label: decreaseSemanticLabel,
            onPressed: _canDecrease ? _decrease : null,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: _valueMinWidth),
            child: Semantics(
              label: semanticLabel,
              liveRegion: true,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: gu.text.bodyM.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          _button(
            context,
            key: plusKey,
            icon: GuIcons.plus,
            label: increaseSemanticLabel,
            onPressed: _canIncrease ? _increase : null,
          ),
        ],
      ),
    );
  }

  /// `IconButton` + satır içi `bg.surfaceMuted` zemin; devre dışıyken zemin
  /// de düğmeyle birlikte solar (`.iconbtn[aria-disabled]{opacity:.45}`
  /// css:156 tüm düğmeye uygulanır).
  Widget _button(
    BuildContext context, {
    required Key? key,
    required GuIcons icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    final background = context.gu.colors.bgSurfaceMuted;
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: const CircleBorder(),
        color: onPressed == null
            ? background.withValues(
                alpha: background.a * GuOpacity.iconButtonDisabled,
              )
            : background,
      ),
      child: GuIconButton(
        key: key,
        icon: icon,
        semanticLabel: label,
        onPressed: onPressed,
      ),
    );
  }
}
