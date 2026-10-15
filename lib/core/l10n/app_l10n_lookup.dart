import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:gu_kulupler/l10n/app_localizations.dart';

/// `BuildContext` olmadan ARB metinleri (bildirim metinleri, cihazdan
/// sunucuya yazılan varsayılan değerler): [preferred] uygulama dil tercihi,
/// yoksa cihaz dili; desteklenmeyen dil Türkçeye düşer (PLAN §14.10).
AppLocalizations appL10nOf(Locale? preferred) {
  final code = (preferred ?? PlatformDispatcher.instance.locale).languageCode;
  final supported = AppLocalizations.supportedLocales.any(
    (locale) => locale.languageCode == code,
  );
  return lookupAppLocalizations(Locale(supported ? code : _fallbackLanguage));
}

const String _fallbackLanguage = 'tr';
