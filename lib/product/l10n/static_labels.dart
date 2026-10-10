import 'package:flutter/widgets.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';

/// Statik tablo kimliği → yerelleştirilmiş görünen ad (PLAN §9.9).
///
/// `gu_data` ARB bilmez: `StaticTables` yalnızca kimlik taşır, metin burada
/// çözülür. Anahtarlar `switch` ile **statik** getter çağrısıdır (gen-l10n
/// dinamik anahtar birleştirmeyi desteklemez; `tool/check_arb_parity.js`
/// ARB14 taraması da bunları böyle görür).
///
/// Tabloda olmayan kimlik için kimliğin kendisi döner (istisna fırlatılmaz):
/// daha yeni bir sürümün yazdığı kimlik eski istemcide ekranı düşürmemelidir
/// (prototipteki `t()` de eksik anahtarda anahtarı döndürür).
abstract final class StaticLabels {
  /// Kulüp kategorisi adı (`k01`–`k08` → `catK01`–`catK08`).
  static String category(BuildContext context, String id) {
    final l10n = AppLocalizations.of(context);
    return switch (id) {
      'k01' => l10n.catK01,
      'k02' => l10n.catK02,
      'k03' => l10n.catK03,
      'k04' => l10n.catK04,
      'k05' => l10n.catK05,
      'k06' => l10n.catK06,
      'k07' => l10n.catK07,
      'k08' => l10n.catK08,
      _ => id,
    };
  }

  /// İlgi alanı adı (`i01`–`i16` → `interestI01`–`interestI16`).
  static String interest(BuildContext context, String id) {
    final l10n = AppLocalizations.of(context);
    return switch (id) {
      'i01' => l10n.interestI01,
      'i02' => l10n.interestI02,
      'i03' => l10n.interestI03,
      'i04' => l10n.interestI04,
      'i05' => l10n.interestI05,
      'i06' => l10n.interestI06,
      'i07' => l10n.interestI07,
      'i08' => l10n.interestI08,
      'i09' => l10n.interestI09,
      'i10' => l10n.interestI10,
      'i11' => l10n.interestI11,
      'i12' => l10n.interestI12,
      'i13' => l10n.interestI13,
      'i14' => l10n.interestI14,
      'i15' => l10n.interestI15,
      'i16' => l10n.interestI16,
      _ => id,
    };
  }

  /// Fakülte adı (`f1`–`f6` → `facultyF1`–`facultyF6`).
  static String faculty(BuildContext context, String id) {
    final l10n = AppLocalizations.of(context);
    return switch (id) {
      'f1' => l10n.facultyF1,
      'f2' => l10n.facultyF2,
      'f3' => l10n.facultyF3,
      'f4' => l10n.facultyF4,
      'f5' => l10n.facultyF5,
      'f6' => l10n.facultyF6,
      _ => id,
    };
  }

  /// Bölüm adı (`d01`–`d24` → `deptD01`–`deptD24`).
  static String department(BuildContext context, String id) {
    final l10n = AppLocalizations.of(context);
    return switch (id) {
      'd01' => l10n.deptD01,
      'd02' => l10n.deptD02,
      'd03' => l10n.deptD03,
      'd04' => l10n.deptD04,
      'd05' => l10n.deptD05,
      'd06' => l10n.deptD06,
      'd07' => l10n.deptD07,
      'd08' => l10n.deptD08,
      'd09' => l10n.deptD09,
      'd10' => l10n.deptD10,
      'd11' => l10n.deptD11,
      'd12' => l10n.deptD12,
      'd13' => l10n.deptD13,
      'd14' => l10n.deptD14,
      'd15' => l10n.deptD15,
      'd16' => l10n.deptD16,
      'd17' => l10n.deptD17,
      'd18' => l10n.deptD18,
      'd19' => l10n.deptD19,
      'd20' => l10n.deptD20,
      'd21' => l10n.deptD21,
      'd22' => l10n.deptD22,
      'd23' => l10n.deptD23,
      'd24' => l10n.deptD24,
      _ => id,
    };
  }

  /// Kampüs mekânı adı (`pl01`–`pl10` → `placePl01`–`placePl10`).
  static String place(BuildContext context, String id) {
    final l10n = AppLocalizations.of(context);
    return switch (id) {
      'pl01' => l10n.placePl01,
      'pl02' => l10n.placePl02,
      'pl03' => l10n.placePl03,
      'pl04' => l10n.placePl04,
      'pl05' => l10n.placePl05,
      'pl06' => l10n.placePl06,
      'pl07' => l10n.placePl07,
      'pl08' => l10n.placePl08,
      'pl09' => l10n.placePl09,
      'pl10' => l10n.placePl10,
      _ => id,
    };
  }

  /// Sınıf / öğrenim düzeyi adı (`yearPrep`, `year1`–`year4`, `year5plus`,
  /// `yearMaster`, `yearPhd`). `switch` tüketicidir: yeni bir [YearLevel]
  /// değeri etiketsiz derlenmez.
  static String year(BuildContext context, YearLevel year) {
    final l10n = AppLocalizations.of(context);
    return switch (year) {
      YearLevel.prep => l10n.yearPrep,
      YearLevel.first => l10n.year1,
      YearLevel.second => l10n.year2,
      YearLevel.third => l10n.year3,
      YearLevel.fourth => l10n.year4,
      YearLevel.fivePlus => l10n.year5plus,
      YearLevel.master => l10n.yearMaster,
      YearLevel.phd => l10n.yearPhd,
    };
  }

  /// Etkinlik türü adı (`eventTypeEgitim` … `eventTypeKonferans`). `switch`
  /// tüketicidir: yeni bir [EventType] değeri etiketsiz derlenmez.
  static String eventType(BuildContext context, EventType type) {
    final l10n = AppLocalizations.of(context);
    return switch (type) {
      EventType.training => l10n.eventTypeEgitim,
      EventType.social => l10n.eventTypeSosyal,
      EventType.trip => l10n.eventTypeGezi,
      EventType.competition => l10n.eventTypeYarisma,
      EventType.conference => l10n.eventTypeKonferans,
    };
  }
}
