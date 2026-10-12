import 'package:flutter/widgets.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/auth/view/widget/setup_profile_error_line.dart';
import 'package:gu_kulupler/product/l10n/static_labels.dart';
import 'package:gu_ui/gu_ui.dart';

/// AUT-05 · 3. adım "İlgi alanların" (`screens-auth.js:145`).
///
/// Başlık satırı (başlık + sağda `seçili/en çok` sayacı), açıklama ve
/// `StaticTables.interests` çipleri (sarmalı, aralık 8; çok seçim,
/// `AUT-05.toggleInterest.<id>`). Seçim yapılmadan gönderim denenirse
/// çiplerin altında [errorText]; alana bağlanamayan gönderim hatası
/// [submitErrorText] ile en altta gösterilir.
class SetupProfileInterestsStep extends StatelessWidget {
  /// İlgi alanları adımı.
  const SetupProfileInterestsStep({
    required this.selected,
    required this.onToggle,
    this.errorText,
    this.submitErrorText,
    super.key,
  });

  /// Seçili ilgi alanı kimlikleri.
  final Set<String> selected;

  /// Çipe dokunma (ilgi alanı kimliğiyle).
  final ValueChanged<String> onToggle;

  /// İlgi alanı doğrulama hatası.
  final String? errorText;

  /// Gönderimin sunucu hatası.
  final String? submitErrorText;

  /// [interestId] çipinin anahtarı (`AUT-05.toggleInterest.<id>`).
  static Key keyOf(String interestId) =>
      GuKey.action('AUT-05.toggleInterest.$interestId');

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final counter = '${selected.length}/${Limits.interestsMax}';
    final error = errorText;
    final submitError = submitErrorText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: GuSpacing.s16,
      children: [
        Row(
          spacing: GuSpacing.s8,
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  l10n.authSetupInterestTitle,
                  style: gu.text.titleL,
                ),
              ),
            ),
            Text(
              counter,
              style: gu.text.labelL.copyWith(
                color: gu.colors.textMuted,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        Text(
          l10n.authSetupInterestDesc,
          style: gu.text.bodyM.copyWith(color: gu.colors.textSecondary),
        ),
        Wrap(
          spacing: GuSpacing.s8,
          runSpacing: GuSpacing.s8,
          children: [
            for (final interest in StaticTables.interests)
              GuChip(
                key: keyOf(interest.id),
                label: StaticLabels.interest(context, interest.id),
                selected: selected.contains(interest.id),
                onTap: () => onToggle(interest.id),
              ),
          ],
        ),
        if (error != null) SetupProfileErrorLine(error),
        if (submitError != null) SetupProfileErrorLine(submitError),
      ],
    );
  }
}
