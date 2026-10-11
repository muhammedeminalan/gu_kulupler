import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/init/app_preferences_view_model.dart';
import 'package:gu_ui/gu_ui.dart';

/// [LanguageOptions] seçeneklerinin çizim biçimi.
enum LanguageOptionsVariant {
  /// Alt sayfa gövdesi: `GuOptionRow` (ad + dil kodu, radyo göstergesi) —
  /// `SHEETS['SHT-01']` (`sheets.js:10`).
  sheet,

  /// Açılır menü öğeleri: `GuPopMenuItem` ("Türkçe — TR", seçilide onay
  /// işareti) — `MENUS['SHT-01']` (`sheets.js:11`).
  menu,
}

/// Dil seçenekleri — SHT-01'in **tek** gövdesi (CD-113): hem alt sayfada
/// ([LanguageSheet]; SET-01) hem sağ üstteki açılır menüde (ONB-01 / AUT-01 /
/// AUT-02 dil düğmesi, `LanguageMenuButton`) aynı widget çizilir.
///
/// * Seçenekler [locales] sırasıyla (Türkçe, English); seçili olan etkin
///   yerel ayardır (`Localizations.localeOf` — tercih yoksa cihaz dili).
/// * Dokunma tercihi yazar (`AppPreferencesViewModel.setLocale`) ve overlay'i
///   kapatır (prototip `setLocale(id); close()`): alt sayfada bu widget kendi
///   rotasını kapatır, menüde öğe (`GuPopMenuItem`) menüyü kapatır.
/// * Anahtarlar `SHT-01.select.tr` / `SHT-01.select.en`.
///
/// Design: SHT-01
class LanguageOptions extends ConsumerWidget {
  /// Dil seçenekleri; [variant] alt sayfa ya da menü biçimi.
  const LanguageOptions({
    this.variant = LanguageOptionsVariant.sheet,
    super.key,
  });

  /// Çizim biçimi.
  final LanguageOptionsVariant variant;

  /// Seçilebilir diller, ekrandaki sırayla (`sheets.js:10`). Uygulamanın
  /// desteklediği dillerle (`AppLocalizations.supportedLocales`) aynı kümedir.
  static const List<Locale> locales = <Locale>[Locale('tr'), Locale('en')];

  /// [locale] seçeneğinin aksiyon anahtarı (`SHT-01.select.<kod>`).
  static Key keyOf(Locale locale) =>
      FeedbackKeys.of(SheetId.sht01.designId, 'select.${locale.languageCode}');

  /// [locale] dilinin kendi dilindeki adı ("Türkçe", "English").
  static String nameOf(AppLocalizations l10n, Locale locale) =>
      switch (locale.languageCode) {
        'tr' => l10n.sht01Tr,
        'en' => l10n.sht01En,
        _ => codeOf(locale),
      };

  /// [locale] dilinin kısa kodu ("TR", "EN").
  static String codeOf(Locale locale) => locale.languageCode.toUpperCase();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final current = Localizations.localeOf(context).languageCode;

    void select(Locale locale) => unawaited(
      ref.read(appPreferencesViewModelProvider.notifier).setLocale(locale),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final locale in locales)
          switch (variant) {
            LanguageOptionsVariant.sheet => GuOptionRow(
              key: keyOf(locale),
              label: nameOf(l10n, locale),
              sub: codeOf(locale),
              selected: locale.languageCode == current,
              onTap: () {
                select(locale);
                Navigator.of(context).pop();
              },
            ),
            LanguageOptionsVariant.menu => GuPopMenuItem(
              key: keyOf(locale),
              label: l10n.sht01MenuItem(
                nameOf(l10n, locale),
                codeOf(locale),
              ),
              selected: locale.languageCode == current,
              onTap: () => select(locale),
            ),
          },
      ],
    );
  }
}

/// SHT-01 Dil — alt sayfa biçimi (SET-01 "Dil" satırı; `sheets.js:10`).
/// Gövde [LanguageOptions]'tır.
///
/// ```dart
/// feedback.showSheet<void>(
///   SheetId.sht01,
///   builder: (_) => const LanguageSheet(),
/// );
/// ```
class LanguageSheet extends StatelessWidget {
  /// Dil alt sayfası.
  const LanguageSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GuSheetFrame(
      title: l10n.sht01Title,
      closeSemanticLabel: l10n.a11yClose,
      closeKey: FeedbackKeys.of(SheetId.sht01.designId, 'close'),
      body: const LanguageOptions(),
    );
  }
}
