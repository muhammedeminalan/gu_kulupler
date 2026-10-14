import 'package:flutter/widgets.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/l10n/static_labels.dart';
import 'package:gu_kulupler/product/widget/form/form_error_line.dart';
import 'package:gu_ui/gu_ui.dart';

/// PRF-02 ilgi alanları bölümü (`screens-profile.js:31`): `.col.gap8` —
/// `.field-label` satırı ("İlgi alanları" + sağda `seçili/en çok`
/// `.field-counter`), `StaticTables.interests` çipleri (sarmalı, aralık 8;
/// çok seçim, `PRF-02.toggleInterest.<id>`) ve doğrulama hatasında
/// `.field-help.is-error` satırı.
class EditProfileInterests extends StatelessWidget {
  /// İlgi alanı seçimi.
  const EditProfileInterests({
    required this.selected,
    required this.onToggle,
    this.errorText,
    super.key,
  });

  /// Seçili ilgi alanı kimlikleri.
  final Set<String> selected;

  /// Çipe dokunma (ilgi alanı kimliğiyle).
  final ValueChanged<String> onToggle;

  /// Doğrulama hatası.
  final String? errorText;

  /// [interestId] çipinin anahtarı (`PRF-02.toggleInterest.<id>`).
  static Key keyOf(String interestId) =>
      GuKey.action('PRF-02.toggleInterest.$interestId');

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final error = errorText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: GuSpacing.s8,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: GuSpacing.s8,
          children: [
            Expanded(
              child: Text(l10n.profileInterests, style: gu.text.fieldLabel),
            ),
            Text(
              '${selected.length}/${Limits.interestsMax}',
              style: gu.text.fieldHelp.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
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
        if (error != null) FormErrorLine(error),
      ],
    );
  }
}
