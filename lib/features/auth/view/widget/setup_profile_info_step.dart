import 'package:flutter/widgets.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/l10n/static_labels.dart';
import 'package:gu_ui/gu_ui.dart';

/// AUT-05 · 2. adım "Eğitim bilgin" (`screens-auth.js:144`).
///
/// Başlık + açıklama + iki seçici alan: bölüm (`AUT-05.department` → SHT-02,
/// `graduation-cap`) ve sınıf (`AUT-05.year` → SHT-03, `calendar-days`).
/// Değer yokken "Seç" yer tutucusu; zorunlu alan boş bırakılırsa altında
/// hata satırı. Personel hesabında ([showYear] `false`) sınıf sorulmaz.
class SetupProfileInfoStep extends StatelessWidget {
  /// Eğitim bilgisi adımı.
  const SetupProfileInfoStep({
    required this.onPickDepartment,
    required this.onPickYear,
    this.departmentId,
    this.year,
    this.departmentError,
    this.yearError,
    this.showYear = true,
    super.key,
  });

  /// Bölüm alanına dokunma.
  final VoidCallback onPickDepartment;

  /// Sınıf alanına dokunma.
  final VoidCallback onPickYear;

  /// Seçili bölüm kimliği.
  final String? departmentId;

  /// Seçili sınıf.
  final YearLevel? year;

  /// Bölüm alanının hata metni.
  final String? departmentError;

  /// Sınıf alanının hata metni.
  final String? yearError;

  /// Sınıf alanı çizilsin mi (personelde `false`).
  final bool showYear;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final departmentId = this.departmentId;
    final year = this.year;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: GuSpacing.s16,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.authSetupEduTitle, style: gu.text.titleL),
        ),
        Text(
          l10n.authSetupEduDesc,
          style: gu.text.bodyM.copyWith(color: gu.colors.textSecondary),
        ),
        GuPickerField(
          actionKey: GuKey.action('AUT-05.department'),
          label: l10n.profileDepartment,
          icon: GuIcons.graduationCap,
          value: departmentId == null
              ? null
              : StaticLabels.department(context, departmentId),
          placeholder: l10n.commonSelect,
          errorText: departmentError,
          onTap: onPickDepartment,
        ),
        if (showYear)
          GuPickerField(
            actionKey: GuKey.action('AUT-05.year'),
            label: l10n.profileYear,
            icon: GuIcons.calendarDays,
            value: year == null ? null : StaticLabels.year(context, year),
            placeholder: l10n.commonSelect,
            errorText: yearError,
            onTap: onPickYear,
          ),
      ],
    );
  }
}
