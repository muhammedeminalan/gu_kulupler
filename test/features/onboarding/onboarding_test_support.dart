// ONB-01 testlerinin ortak düzeneği: tanıtım bayrağı yazımını bekletebilen /
// fırlatabilen tercih deposu (çift dokunma ve hata yolları).
import 'dart:async';

import 'package:flutter/material.dart' show Locale, ThemeMode;
import 'package:get_it/get_it.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../fakes/fake_app_preferences_store.dart';

/// `setOnboardingSeen` yazımını [gate] ile bekleten ya da [error] ile
/// fırlatan depo; geri kalan her şey [inner]'a gider.
final class ControlledPreferencesStore implements AppPreferencesStore {
  ControlledPreferencesStore._();

  /// GetIt'teki depoyu denetimli olanla değiştirir (`registerDefaultFakes`
  /// / `pumpApp` sonrasında çağrılır).
  static Future<ControlledPreferencesStore> install() async {
    final controlled = ControlledPreferencesStore._();
    await GetIt.I.unregister<AppPreferencesStore>();
    GetIt.I.registerSingleton<AppPreferencesStore>(controlled);
    return controlled;
  }

  /// Değerlerin gerçekte tutulduğu fake.
  final FakeAppPreferencesStore inner = FakeAppPreferencesStore();

  /// Doluysa yazım bu tamamlanana kadar bekler.
  Completer<void>? gate;

  /// Doluysa yazım bu hatayı fırlatır (sözleşme dışı; savunma testi).
  Error? error;

  /// `setOnboardingSeen` çağrı sayısı (bekleyenler dahil).
  int onboardingWrites = 0;

  @override
  Future<bool> setOnboardingSeen(bool value) async {
    onboardingWrites++;
    await gate?.future;
    if (error case final failure?) throw failure;
    return inner.setOnboardingSeen(value);
  }

  @override
  bool get isLoaded => inner.isLoaded;

  @override
  Future<void> load() => inner.load();

  @override
  ThemeMode get themeMode => inner.themeMode;

  @override
  Locale? get locale => inner.locale;

  @override
  GuTextScaleLevel get textScale => inner.textScale;

  @override
  bool get onboardingSeen => inner.onboardingSeen;

  @override
  bool get notificationPermissionAsked => inner.notificationPermissionAsked;

  @override
  bool get photoAccessExplained => inner.photoAccessExplained;

  @override
  List<String> get recentSearches => inner.recentSearches;

  @override
  Future<bool> setThemeMode(ThemeMode mode) => inner.setThemeMode(mode);

  @override
  Future<bool> setLocale(Locale? locale) => inner.setLocale(locale);

  @override
  Future<bool> setTextScale(GuTextScaleLevel level) =>
      inner.setTextScale(level);

  @override
  Future<bool> setNotificationPermissionAsked(bool value) =>
      inner.setNotificationPermissionAsked(value);

  @override
  Future<bool> setPhotoAccessExplained(bool value) =>
      inner.setPhotoAccessExplained(value);

  @override
  Future<bool> setRecentSearches(List<String> terms) =>
      inner.setRecentSearches(terms);
}
