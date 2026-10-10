// `AppPreferencesStore` fake'i (PLAN §16.3): değerler bellekteki [values]
// haritasında, gerçek depoyla aynı anahtar ve aynı kodlamayla tutulur.
// Gerçek depo gibi hiçbir metodu fırlatmaz; `failNext()` bir sonraki yazımı
// "kalıcı yazılamadı" (`false`) yapar, `failNext()` + `load()` okumayı
// başarısız kılar.
//
//   final store = FakeAppPreferencesStore()
//     ..values[AppPreferenceKeys.themeMode] = 'dark';
import 'package:flutter/material.dart' show Locale, ThemeMode;
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_ui/gu_ui.dart';

import 'fake_base.dart';

final class FakeAppPreferencesStore extends FakeBase
    implements AppPreferencesStore {
  /// [loaded] `true` ise `load()` çağrılmış sayılır (varsayılan).
  FakeAppPreferencesStore({bool loaded = true}) : isLoaded = loaded;

  /// "Diskteki" ham değerler (`AppPreferenceKeys` → `String` / `bool`).
  final Map<String, Object?> values = <String, Object?>{};

  @override
  bool isLoaded;

  @override
  Future<void> load() async {
    record('load');
    if (takeFailure() != null) return;
    isLoaded = true;
  }

  @override
  ThemeMode get themeMode => ThemeMode.values.firstWhere(
    (mode) => mode.name == values[AppPreferenceKeys.themeMode],
    orElse: () => ThemeMode.system,
  );

  @override
  Locale? get locale {
    final code = values[AppPreferenceKeys.locale];
    for (final locale in AppLocalizations.supportedLocales) {
      if (locale.languageCode == code) return Locale(locale.languageCode);
    }
    return null;
  }

  @override
  GuTextScaleLevel get textScale => GuTextScaleLevel.values.firstWhere(
    (level) => level.name == values[AppPreferenceKeys.textScale],
    orElse: () => GuTextScaleLevel.s100,
  );

  @override
  bool get onboardingSeen => values[AppPreferenceKeys.onboardingSeen] == true;

  @override
  bool get notificationPermissionAsked =>
      values[AppPreferenceKeys.notificationPermissionAsked] == true;

  @override
  Future<bool> setThemeMode(ThemeMode mode) =>
      _write('setThemeMode', mode, AppPreferenceKeys.themeMode, mode.name);

  @override
  Future<bool> setLocale(Locale? locale) => _write(
    'setLocale',
    locale,
    AppPreferenceKeys.locale,
    locale?.languageCode ?? '',
  );

  @override
  Future<bool> setTextScale(GuTextScaleLevel level) =>
      _write('setTextScale', level, AppPreferenceKeys.textScale, level.name);

  @override
  Future<bool> setOnboardingSeen(bool value) => _write(
    'setOnboardingSeen',
    value,
    AppPreferenceKeys.onboardingSeen,
    value,
  );

  @override
  Future<bool> setNotificationPermissionAsked(bool value) => _write(
    'setNotificationPermissionAsked',
    value,
    AppPreferenceKeys.notificationPermissionAsked,
    value,
  );

  /// Gerçek depo gibi: bellekteki değer her durumda güncellenir; bekleyen
  /// hata yalnızca dönüş değerini `false` yapar.
  Future<bool> _write(
    String method,
    Object? argument,
    String key,
    Object value,
  ) async {
    record(method, [argument]);
    values[key] = value;
    return takeFailure() == null;
  }
}
