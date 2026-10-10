import 'package:flutter/material.dart' show Locale, ThemeMode;
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cihazda saklanan kullanıcı tercihleri ve ilk açılış bayrakları (D-24,
/// Q-14, CD-52). Tek ad: `AppPreferencesService` / `AppInitFlags` yoktur.
///
/// - Okuyucular eşzamanlıdır; [load] tamamlanmadan varsayılanları döndürür.
/// - Yazıcılar **hiçbir zaman fırlatmaz**: kalıcılık hatası `false` döner
///   (çağıran günlüğe yazar; kullanıcıya gösterilmez).
/// - Son aramalar (T-17) ve yazı taslakları (T-21) kendi task'larında eklenir.
abstract interface class AppPreferencesStore {
  /// Değerler diskten okundu mu?
  bool get isLoaded;

  /// Değerleri diskten okur. Fırlatmaz: okunamazsa
  /// varsayılanlar geçerli kalır ve [isLoaded] `false` kalır.
  Future<void> load();

  /// Tema tercihi; varsayılan [ThemeMode.system].
  ThemeMode get themeMode;

  /// Dil tercihi; `null` = sistem dili.
  Locale? get locale;

  /// Uygulama içi metin ölçeği; varsayılan [GuTextScaleLevel.s100].
  GuTextScaleLevel get textScale;

  /// Tanıtım (ONB-01) görüldü mü? (`pref.onboardingSeen`)
  bool get onboardingSeen;

  /// Bildirim izni ön açıklaması (DLG-03) bir kez gösterildi mi?
  bool get notificationPermissionAsked;

  /// Tema tercihini yazar.
  Future<bool> setThemeMode(ThemeMode mode);

  /// Dil tercihini yazar; `null` sistem diline döner.
  Future<bool> setLocale(Locale? locale);

  /// Metin ölçeğini yazar.
  Future<bool> setTextScale(GuTextScaleLevel level);

  /// Tanıtım bayrağını yazar.
  Future<bool> setOnboardingSeen(bool value);

  /// Bildirim izni bayrağını yazar.
  Future<bool> setNotificationPermissionAsked(bool value);
}

/// `shared_preferences` anahtarları — tek liste (PLAN §4.4, §12.2).
abstract final class AppPreferenceKeys {
  /// Tema: `system` / `light` / `dark`.
  static const String themeMode = 'pref.themeMode';

  /// Dil kodu (`tr` / `en`); boş = sistem dili.
  static const String locale = 'pref.locale';

  /// Metin ölçeği: `s100` / `s130` / `s160`.
  static const String textScale = 'pref.textScale';

  /// Tanıtım görüldü mü.
  static const String onboardingSeen = 'pref.onboardingSeen';

  /// Bildirim izni ön açıklaması gösterildi mi.
  static const String notificationPermissionAsked =
      'pref.notificationPermissionAsked';
}

/// [AppPreferencesStore] uygulaması: `shared_preferences`.
///
/// Bozuk ya da tanınmayan değer (elle değiştirilmiş, eski sürümden kalma)
/// varsayılana düşer; desteklenmeyen dil kodu sistem dili sayılır.
final class SharedAppPreferencesStore implements AppPreferencesStore {
  /// `open` verilmezse `SharedPreferences.getInstance` kullanılır.
  SharedAppPreferencesStore({
    this._open = SharedPreferences.getInstance,
  });

  final Future<SharedPreferences> Function() _open;
  SharedPreferences? _prefs;

  ThemeMode _themeMode = ThemeMode.system;
  Locale? _locale;
  GuTextScaleLevel _textScale = GuTextScaleLevel.s100;
  bool _onboardingSeen = false;
  bool _notificationPermissionAsked = false;

  @override
  bool get isLoaded => _prefs != null;

  @override
  ThemeMode get themeMode => _themeMode;

  @override
  Locale? get locale => _locale;

  @override
  GuTextScaleLevel get textScale => _textScale;

  @override
  bool get onboardingSeen => _onboardingSeen;

  @override
  bool get notificationPermissionAsked => _notificationPermissionAsked;

  @override
  Future<void> load() async {
    try {
      final prefs = await _open();
      _themeMode = _enumOf(
        ThemeMode.values,
        _string(prefs, AppPreferenceKeys.themeMode),
        ThemeMode.system,
      );
      _locale = _localeOf(_string(prefs, AppPreferenceKeys.locale));
      _textScale = _enumOf(
        GuTextScaleLevel.values,
        _string(prefs, AppPreferenceKeys.textScale),
        GuTextScaleLevel.s100,
      );
      _onboardingSeen = _bool(prefs, AppPreferenceKeys.onboardingSeen);
      _notificationPermissionAsked = _bool(
        prefs,
        AppPreferenceKeys.notificationPermissionAsked,
      );
      _prefs = prefs;
    } on Object catch (error, stack) {
      AppLogger.warn('Tercihler okunamadı', error: error, stackTrace: stack);
    }
  }

  @override
  Future<bool> setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    return _write(
      (prefs) => prefs.setString(AppPreferenceKeys.themeMode, mode.name),
    );
  }

  @override
  Future<bool> setLocale(Locale? locale) {
    _locale = locale;
    return _write(
      (prefs) => prefs.setString(
        AppPreferenceKeys.locale,
        locale?.languageCode ?? '',
      ),
    );
  }

  @override
  Future<bool> setTextScale(GuTextScaleLevel level) {
    _textScale = level;
    return _write(
      (prefs) => prefs.setString(AppPreferenceKeys.textScale, level.name),
    );
  }

  @override
  Future<bool> setOnboardingSeen(bool value) {
    _onboardingSeen = value;
    return _write(
      (prefs) => prefs.setBool(AppPreferenceKeys.onboardingSeen, value),
    );
  }

  @override
  Future<bool> setNotificationPermissionAsked(bool value) {
    _notificationPermissionAsked = value;
    return _write(
      (prefs) =>
          prefs.setBool(AppPreferenceKeys.notificationPermissionAsked, value),
    );
  }

  /// [write] yazımını çalıştırır; depo açılamadıysa ya da yazım başarısızsa
  /// `false` (bellekteki değer oturum boyunca geçerli kalır).
  Future<bool> _write(
    Future<bool> Function(SharedPreferences prefs) write,
  ) async {
    try {
      final prefs = _prefs ??= await _open();
      return await write(prefs);
    } on Object catch (error, stack) {
      AppLogger.warn('Tercih yazılamadı', error: error, stackTrace: stack);
      return false;
    }
  }

  /// [key] metin değilse (tip uyuşmazlığı) `null`.
  static String? _string(SharedPreferences prefs, String key) =>
      switch (prefs.get(key)) {
        final String value => value,
        _ => null,
      };

  static bool _bool(SharedPreferences prefs, String key) =>
      switch (prefs.get(key)) {
        final bool value => value,
        _ => false,
      };

  static T _enumOf<T extends Enum>(List<T> values, String? name, T fallback) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }

  /// Yalnızca desteklenen dil kodları tercih sayılır.
  static Locale? _localeOf(String? code) {
    for (final locale in AppLocalizations.supportedLocales) {
      if (locale.languageCode == code) return Locale(locale.languageCode);
    }
    return null;
  }
}
