import 'package:flutter/material.dart' show Locale, ThemeMode;
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/env/app_environment.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/system/debug_menu/provider/debug_demo_accounts.dart';
import 'package:gu_kulupler/features/system/debug_menu/provider/debug_menu_state.dart';
import 'package:gu_kulupler/product/init/app_preferences_view_model.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'debug_menu_view_model.g.dart';

/// DebugMenu panelinin ViewModel'i (K-E, CD-69; PLAN §12.3) — prototipteki
/// kontrol panelinin (mock, K-02) yalnızca emülatör derlemesindeki karşılığı.
///
/// * Görünüm: tema, dil ve metin ölçeği `AppPreferencesViewModel`'den
///   yansıtılır ve ona yazılır.
/// * Demo hesap geçişi (CD-132 (23)): [signInDemo] seed'deki hesapla
///   emülatörde oturum açar, [signOut] oturumu kapatır.
// TODO(T-43): çevrimdışı simülasyonu ve boş / hata zorlama (`DebugFlags`).
@riverpod
final class DebugMenuViewModel extends _$DebugMenuViewModel
    with ProjectDependencyMixin {
  @override
  DebugMenuState build() {
    final preferences = ref.watch(appPreferencesViewModelProvider);
    // Tercih değişince yeniden kurulur; demo giriş alanları korunur.
    return (stateOrNull ?? const DebugMenuState()).copyWith(
      themeMode: preferences.themeMode,
      locale: preferences.locale,
      clearLocale: preferences.locale == null,
      textScale: preferences.textScale,
    );
  }

  AppPreferencesViewModel get _preferences =>
      ref.read(appPreferencesViewModelProvider.notifier);

  /// Temayı değiştirir.
  Future<void> setThemeMode(ThemeMode mode) => _preferences.setThemeMode(mode);

  /// Dili değiştirir; `null` = sistem dili.
  Future<void> setLocale(Locale? locale) => _preferences.setLocale(locale);

  /// Metin ölçeğini değiştirir.
  Future<void> setTextScale(GuTextScaleLevel level) =>
      _preferences.setTextScale(level);

  /// [account] demo hesabıyla oturum açar ve açılıp açılmadığını döndürür.
  ///
  /// Yalnızca emülatörde etkilidir: demo parolası gerçek projeye
  /// **gönderilmez** ([isEmulator] yalnızca testte verilir; bayrak derleme
  /// sabitidir). Süren bir giriş varken yeni giriş başlatılmaz.
  ///
  /// Başarıda oturum yeniden çözülür (`SessionViewModel.resolve`); çağıran
  /// uygulama rotasına `go` ile gider, nereye varılacağına router karar
  /// verir. Hatada [DebugMenuState.isError] ve [DebugMenuState.errorCode]
  /// yazılır (emülatör ya da seed kapalı olabilir).
  Future<bool> signInDemo(
    DebugDemoAccount account, {
    bool isEmulator = AppEnvironment.isEmulator,
  }) async {
    if (!isEmulator || state.signingInId != null) return false;
    state = state.copyWith(
      signingInId: account.id,
      isError: false,
      clearErrorCode: true,
    );
    // TODO(T-12): `authRepository.signIn(...)`.
    final result = await authService.signIn(
      email: account.email,
      password: DebugDemoAccounts.password,
    );
    if (!ref.mounted) return false;
    switch (result) {
      case FirebaseSuccess():
        await ref.read(sessionViewModelProvider.notifier).resolve();
        if (!ref.mounted) return false;
        state = state.copyWith(clearSigningInId: true);
        return true;
      case FirebaseFailure(:final error):
        AppLogger.warn('Demo hesap girişi başarısız: ${error.name}');
        state = state.copyWith(
          clearSigningInId: true,
          isError: true,
          errorCode: error.name,
        );
        return false;
    }
  }

  /// Oturumu kapatır (`SessionViewModel.signOut`) ve kapanıp kapanmadığını
  /// döndürür.
  Future<bool> signOut() =>
      ref.read(sessionViewModelProvider.notifier).signOut();
}
