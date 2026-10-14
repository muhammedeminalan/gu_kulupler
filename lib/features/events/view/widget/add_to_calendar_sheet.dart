import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_ui/gu_ui.dart';

/// SHT-14'te seçilen takvim yolu — sayfanın `pop` değeri (sıra
/// `sheets.js:73`).
enum CalendarChoice {
  /// "Cihaz takvimi" (`.ics`, `SHT-14.device`): çağıran
  /// `IcsBuilder.build` → `FileService.writeTemp` →
  /// `ShareService.shareFile(text/calendar)` → TST-36.
  device('device'),

  /// "Google Takvim" (`SHT-14.google`): çağıran şablon adresini harici
  /// bağlantı onayıyla (DLG-32) açar.
  google('google'),

  /// "Bağlantıyı kopyala" (`SHT-14.copyLink`): çağıran etkinlik bağlantısını
  /// panoya kopyalar → TST-35.
  copyLink('copyLink');

  const CalendarChoice(this.action);

  /// Aksiyon adı (`SHT-14.<action>`).
  final String action;
}

/// SHT-14 "Takvime ekle" — üç yol (prototip `SHEETS['SHT-14']`,
/// `sheets.js:71–73`; menü biçimi `menu` + `flush`). EVT-02 (kart satırı ve
/// EVT-MENU) ve EVT-03 açar.
///
/// * Satırlar sayfa `Row`'u (`sheets.js:5`): `GuTile` + 22 dp `text.heading`
///   ikon — "Cihaz takvimi" (`smartphone`, alt satır `.ics`), "Google Takvim"
///   (`globe`), "Bağlantıyı kopyala" (`link`).
/// * Sayfa hiçbir şey yürütmez: dokunulan satır [CalendarChoice] olarak
///   döner; X / scrim / geri → `null`. Yürütme `EventCalendarMixin`'dedir.
/// * Anahtarlar `SHT-14.device`, `SHT-14.google`, `SHT-14.copyLink`,
///   `SHT-14.close`.
///
/// ```dart
/// final choice = await feedback.showSheet<CalendarChoice>(
///   SheetId.sht14,
///   builder: (_) => const AddToCalendarSheet(),
/// );
/// ```
///
/// Design: SHT-14
class AddToCalendarSheet extends StatelessWidget {
  /// Takvime ekleme menüsü.
  const AddToCalendarSheet({super.key});

  /// "Cihaz takvimi" alt satırı — dosya uzantısı, çevrilmez
  /// (`sheets.js:73` `sub=".ics"`).
  static const String deviceSubtitle = '.ics';

  /// [choice] satırının anahtarı (`SHT-14.<action>`).
  static Key keyOf(CalendarChoice choice) =>
      FeedbackKeys.of(SheetId.sht14.designId, choice.action);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final heading = context.gu.colors.textHeading;

    Widget row(
      CalendarChoice choice, {
      required GuIcons icon,
      required String label,
      String? subtitle,
    }) => GuTile(
      key: keyOf(choice),
      title: label,
      subtitle: subtitle,
      leading: GuIcon(icon, size: GuSizes.icon22, color: heading),
      onTap: () => context.pop(choice),
    );

    return GuSheetFrame(
      title: l10n.sht14Title,
      closeSemanticLabel: l10n.a11yClose,
      closeKey: FeedbackKeys.of(SheetId.sht14.designId, 'close'),
      menu: true,
      flush: true,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row(
            CalendarChoice.device,
            icon: GuIcons.smartphone,
            label: l10n.sht14Device,
            subtitle: deviceSubtitle,
          ),
          row(
            CalendarChoice.google,
            icon: GuIcons.globe,
            label: l10n.sht14Google,
          ),
          row(
            CalendarChoice.copyLink,
            icon: GuIcons.link,
            label: l10n.sht08CopyLink,
          ),
        ],
      ),
    );
  }
}
