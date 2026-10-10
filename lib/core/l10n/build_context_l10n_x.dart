import 'package:flutter/widgets.dart';
import 'package:gu_kulupler/core/constants/app_constants.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';

/// `context.l10n` — ARB metinlerine tek köprü (CLAUDE.md §8, PLAN §14.6).
/// `gu_ui` ARB bilmez; metin oraya parametre olarak verilir.
extension L10nX on BuildContext {
  /// Etkin dilin metinleri.
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Üretilen `AppLocalizations` üzerine ürün adı yardımcıları (D-01, CD-75).
extension AppLocalizationsX on AppLocalizations {
  /// `{appNameDative}` yer tutucusunun değeri: Türkçede yönelme hâli
  /// ("GÜ Kulüpler’e"), diğer dillerde düz ad.
  String get appNameWelcomeArg => localeName == _turkishLocale
      ? AppConstants.appNameDative
      : AppConstants.appName;

  /// `notifTypeSystemWelcomeTitle` için hazır metin.
  String get systemWelcomeTitle =>
      notifTypeSystemWelcomeTitle(appNameWelcomeArg);
}

const String _turkishLocale = 'tr';
