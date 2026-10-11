import 'package:flutter/widgets.dart';
import 'package:gu_ui/gu_ui.dart';

/// Şifre kuralı satırı: karşılandı mı + metni (çağırandan; ARB).
typedef RegisterPasswordRule = ({bool met, String label});

/// AUT-02 şifre gücü göstergesi — şifre alanının altındaki dilimli çubuk ve
/// kural listesi (`screens-auth.js:98–99`).
///
/// * Çubuk: [max] eşit dilim, yükseklik 4, radius 2, aralık 4. Dolu dilim
///   rengi güce göre: ≤ 1 `state.danger`, 2 `state.warning`, ≥ 3
///   `state.success`; boş dilim `border.default`. Dekoratiftir
///   (`aria-hidden`).
/// * Kurallar: satır başına 14 px ikon (`circle-check` / `circle-x`) + `bodyS`
///   metin, aralık 6, satırlar arası 4; karşılanan `state.success`, diğeri
///   `text.muted`.
class RegisterPasswordStrength extends StatelessWidget {
  /// [strength] 0 – [max] arasındadır.
  const RegisterPasswordStrength({
    required this.strength,
    required this.max,
    required this.rules,
    super.key,
  }) : assert(
         strength >= 0 && strength <= max,
         'strength 0 – max arasında olmalı.',
       );

  /// Karşılanan ölçüt sayısı (dolu dilim sayısı).
  final int strength;

  /// Dilim sayısı.
  final int max;

  /// Kural satırları, gösterim sırasıyla.
  final List<RegisterPasswordRule> rules;

  /// Zayıf (kırmızı) sayılan en yüksek güç.
  static const int _weakMax = 1;

  /// Orta (sarı) sayılan güç.
  static const int _medium = 2;

  Color _fillColor(GuColors colors) {
    if (strength <= _weakMax) return colors.stateDanger;
    return strength == _medium ? colors.stateWarning : colors.stateSuccess;
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final colors = gu.colors;
    final fill = _fillColor(colors);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: GuSpacing.s8,
      children: [
        ExcludeSemantics(
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
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: GuSpacing.s4,
          children: [
            for (final rule in rules)
              _RuleRow(
                rule: rule,
                color: rule.met ? colors.stateSuccess : colors.textMuted,
              ),
          ],
        ),
      ],
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.rule, required this.color});

  final RegisterPasswordRule rule;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    spacing: GuSpacing.s6,
    children: [
      GuIcon(
        rule.met ? GuIcons.circleCheck : GuIcons.circleX,
        size: GuSizes.icon14,
        color: color,
      ),
      Expanded(
        child: Text(
          rule.label,
          style: context.gu.text.bodyS.copyWith(color: color),
        ),
      ),
    ],
  );
}
