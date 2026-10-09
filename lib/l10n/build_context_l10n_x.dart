import 'package:gu_kulupler/core/constants/app_constants.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';

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
