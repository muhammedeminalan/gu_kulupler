import 'package:flutter/material.dart' show Locale, ThemeMode;
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/product/init/app_preferences_state.dart';
import 'package:gu_kulupler/product/mixin/permission_prompt_mixin.dart';
import 'package:gu_kulupler/product/service/permission_service.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_preferences_view_model.g.dart';

/// Tema / dil / metin ölçeği tercihleri ve ilk açılış bayrakları (PLAN §12.2;
/// SET-01, SHT-01, SHT-17, DLG-03).
///
/// Her yazıcı **önce** state'i günceller, sonra diske yazar; kalıcılık hatası
/// yalnızca günlüğe düşer (geri alma yok — tercih oturum boyunca geçerlidir).
@Riverpod(keepAlive: true)
final class AppPreferencesViewModel extends _$AppPreferencesViewModel
    with ProjectDependencyMixin, PermissionPromptMixin {
  @override
  AppPreferencesState build() => _fromStore();

  /// Tercihleri diskten okur (açılışta `AppBootstrap` depoyu zaten okumuşsa
  /// [build] aynı değerlerle başlar).
  Future<void> load() async {
    await appPreferencesStore.load();
    state = _fromStore();
  }

  /// Tema tercihini değiştirir.
  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    _report(await appPreferencesStore.setThemeMode(mode));
  }

  /// Dil tercihini değiştirir; `null` sistem diline döner.
  Future<void> setLocale(Locale? locale) async {
    state = state.copyWith(locale: locale, clearLocale: locale == null);
    _report(await appPreferencesStore.setLocale(locale));
  }

  /// Metin ölçeğini değiştirir.
  Future<void> setTextScale(GuTextScaleLevel scale) async {
    state = state.copyWith(textScale: scale);
    _report(await appPreferencesStore.setTextScale(scale));
  }

  /// DLG-03 "bir kez" bayrağını işaretler.
  Future<void> markNotificationPermissionAsked() async {
    state = state.copyWith(notificationPermissionAsked: true);
    _report(await appPreferencesStore.setNotificationPermissionAsked(true));
  }

  /// İlk aktif girişte bildirim ön izni (DLG-03) — cihazda **bir kez**
  /// (architecture §6; PLAN §15.6). Uygulama kabuğu ilk kurulduğunda çağırır.
  ///
  /// Bayrak sorudan **önce** işaretlenir: sonuç ne olursa olsun (izin, ret,
  /// "Şimdi değil", scrim) bir daha sorulmaz ve eşzamanlı ikinci çağrı
  /// pencereyi yeniden açmaz. İzin zaten verilmişse pencere açılmaz.
  /// Dönüş: bu çağrıda izin verildi mi (TST-19 gösterildi).
  Future<bool> askNotificationPermissionOnce() async {
    if (state.notificationPermissionAsked) return false;
    await markNotificationPermissionAsked();
    if (await permissionService.isGranted(Permission.notification)) {
      return false;
    }
    return askNotificationPermission();
  }

  /// Depodaki `onboardingSeen` değerini state'e yansıtır. Bayrağı
  /// `SessionViewModel.markOnboardingSeen()` yazar (CD-52); o çağrıdan sonra
  /// bu state'in de güncel kalması için çağrılır.
  void syncOnboardingSeen() {
    state = state.copyWith(onboardingSeen: appPreferencesStore.onboardingSeen);
  }

  AppPreferencesState _fromStore() {
    final store = appPreferencesStore;
    return AppPreferencesState(
      themeMode: store.themeMode,
      locale: store.locale,
      textScale: store.textScale,
      onboardingSeen: store.onboardingSeen,
      notificationPermissionAsked: store.notificationPermissionAsked,
      isLoaded: store.isLoaded,
    );
  }

  void _report(bool saved) {
    if (!saved) AppLogger.warn('Tercih kalıcı yazılamadı');
  }
}
