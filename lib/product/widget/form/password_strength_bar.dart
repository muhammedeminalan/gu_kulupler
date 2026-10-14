import 'package:flutter/widgets.dart';
import 'package:gu_ui/gu_ui.dart';

/// Şifre gücü çubuğu — şifre alanının altındaki dilimli gösterge
/// (AUT-02 `screens-auth.js:98`, SHT-32 `sheets.js:152`).
///
/// [max] eşit dilim, yükseklik 4, radius 2, aralık 4. Dolu dilim rengi güce
/// göre: ≤ 1 `state.danger`, 2 `state.warning`, ≥ 3 `state.success`; boş dilim
/// `border.default`. Dekoratiftir (`aria-hidden`): semantik ağaca girmez.
class PasswordStrengthBar extends StatelessWidget {
  /// [strength] 0 – [max] arasındadır.
  const PasswordStrengthBar({
    required this.strength,
    required this.max,
    super.key,
  }) : assert(
         strength >= 0 && strength <= max,
         'strength 0 – max arasında olmalı.',
       );

  /// Karşılanan ölçüt sayısı (dolu dilim sayısı).
  final int strength;

  /// Dilim sayısı.
  final int max;

  /// Zayıf (kırmızı) sayılan en yüksek güç.
  static const int _weakMax = 1;

  /// Orta (sarı) sayılan güç.
  static const int _medium = 2;

  /// [strength] gücündeki dolu dilimin rengi.
  static Color fillColor(GuColors colors, int strength) {
    if (strength <= _weakMax) return colors.stateDanger;
    return strength == _medium ? colors.stateWarning : colors.stateSuccess;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.gu.colors;
    final fill = fillColor(colors, strength);
    return ExcludeSemantics(
      child: Row(
        spacing: GuSpacing.s4,
        children: [
          for (var index = 0; index < max; index++)
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: index < strength ? fill : colors.borderDefault,
                  borderRadius: GuRadius.borderHandle,
                ),
                child: const SizedBox(height: GuSizes.progressHeightThin),
              ),
            ),
        ],
      ),
    );
  }
}
