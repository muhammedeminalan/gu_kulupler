import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/language_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/feedback/menu_id.dart';
import 'package:gu_ui/gu_ui.dart';

/// Dil düğmesi — oturum öncesi ekranların sağ / sol üstündeki `languages`
/// ikonlu, etkin dil kodunu ("TR" / "EN") gösteren hayalet düğme
/// (`screens-auth.js:47`, `:67`, `:93`; `Button variant="ghost" size="sm"`).
///
/// Dokununca SHT-01'i **açılır menü** biçiminde açar (`MenuId.sht01`,
/// CD-113): `FeedbackService.showMenu` + [LanguageOptions] (menü biçimi).
/// Seçim tercihi yazar ve menüyü kapatır; düğme yeni dil koduyla yeniden
/// çizilir.
///
/// Anahtar çağıran ekrandan gelir (CD-111; literal ekran dosyasında kalır):
///
/// ```dart
/// LanguageMenuButton(key: GuKey.action('ONB-01.lang'))
/// LanguageMenuButton(key: GuKey.action('AUT-01.lang'), chevron: true)
/// ```
class LanguageMenuButton extends ConsumerWidget {
  /// [key] ekranın `.lang` aksiyon anahtarıdır. [chevron] `true` → sonda
  /// `chevron-down` (yalnızca AUT-01, `screens-auth.js:67`).
  const LanguageMenuButton({required Key super.key, this.chevron = false});

  /// Sonda açılır menü oku çizilsin mi.
  final bool chevron;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    return GuButton(
      label: LanguageOptions.codeOf(locale),
      semanticLabel: l10n.a11yLanguage(LanguageOptions.nameOf(l10n, locale)),
      variant: GuButtonVariant.ghost,
      size: GuButtonSize.sm,
      icon: GuIcons.languages,
      iconTrailing: chevron ? GuIcons.chevronDown : null,
      onPressed: () => unawaited(
        ref
            .read(feedbackServiceProvider)
            .showMenu<void>(
              id: MenuId.sht01,
              scrimKey: FeedbackKeys.of(MenuId.sht01.designId, 'scrim'),
              items: const [
                LanguageOptions(variant: LanguageOptionsVariant.menu),
              ],
            ),
      ),
    );
  }
}
