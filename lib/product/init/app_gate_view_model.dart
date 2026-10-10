import 'dart:async';

import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/product/init/app_gate_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_gate_view_model.g.dart';

/// Kök kapılar (PLAN §12.2): zorunlu güncelleme (DLG-26), oturum sona erdi
/// (DLG-27) ve bakım bandı (CD-48).
///
/// `RemoteConfigService` **kurucudan** gelir (`ProjectDependencyMixin`'de
/// getter'ı yoktur — PLAN §6.1): verilmezse `ProjectDependency.setup()`'ın
/// GetIt'e kaydettiği örnek okunur. Remote Config hatası kullanıcıya
/// gösterilmez; değerler kod içi varsayılanlardan devam eder.
@Riverpod(keepAlive: true)
final class AppGateViewModel extends _$AppGateViewModel
    with ProjectDependencyMixin {
  /// [remoteConfigService] yalnızca testte verilir.
  AppGateViewModel({RemoteConfigService? remoteConfigService})
    : _injectedRemoteConfig = remoteConfigService;

  final RemoteConfigService? _injectedRemoteConfig;

  RemoteConfigService get _remoteConfig =>
      _injectedRemoteConfig ?? GetIt.I<RemoteConfigService>();

  @override
  AppGateState build() {
    final subscription = _remoteConfig.onConfigUpdated.listen((_) => _read());
    ref.onDispose(subscription.cancel);
    // İlk çekim kendiliğinden başlar; kök ağaç bu sağlayıcıyı izlediği anda
    // (GuApp.builder) arka planda çalışır.
    unawaited(Future<void>.microtask(check));
    return _withConfig(
      AppGateState(currentBuild: appInfoService.buildCode),
    );
  }

  /// Remote Config'i çeker ve değerleri yeniden okur. Açılışta **beklenmez**
  /// (arka planda çalışır — architecture §13).
  Future<void> check() async {
    if (!ref.mounted || state.isFetching) return;
    state = state.copyWith(isFetching: true, isError: false);
    final result = await _remoteConfig.fetchAndActivate();
    if (!ref.mounted) return;
    switch (result) {
      case FirebaseSuccess():
        state = _withConfig(state.copyWith(isFetching: false));
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn(
          'Remote Config çekilemedi: ${error.name}',
          error: message,
        );
        state = _withConfig(state.copyWith(isFetching: false, isError: true));
    }
  }

  /// Oturum sunucu tarafında sona erdi (`SessionViewModel.onTokenExpired()`
  /// çağırır) → DLG-27.
  void onSessionExpired() {
    state = state.copyWith(isSessionExpired: true);
  }

  /// DLG-27 kapatıldı.
  void acknowledgeSessionExpired() {
    state = state.copyWith(isSessionExpired: false);
  }

  /// DLG-26 "Güncelle": uygulamanın mağaza sayfasını açar. Kapı kapanmaz —
  /// güncelleme kurulana kadar `isUpdateRequired` açık kalır.
  // TODO(T-13): `urlLauncherService.open(…)` ile mağaza sayfasını aç
  // (`UrlLauncherService` T-13'te doğar; bağlama borcu W-55).
  Future<void> openStore() async {
    AppLogger.info('Mağaza bağlantısı henüz bağlı değil (W-55)');
  }

  void _read() {
    if (!ref.mounted) return;
    state = _withConfig(state);
  }

  /// [base] üzerine güncel Remote Config değerlerini ve türetilen güncelleme
  /// kararını yazar. Derleme numarası okunamadıysa (`0`) kapı açılmaz:
  /// okuma hatası kullanıcıyı uygulamadan kilitlememelidir.
  AppGateState _withConfig(AppGateState base) {
    final minBuild = _remoteConfig.minSupportedBuild;
    return base.copyWith(
      minSupportedBuild: minBuild,
      maintenanceMessage: _remoteConfig.maintenanceMessage,
      isUpdateRequired: base.currentBuild > 0 && minBuild > base.currentBuild,
    );
  }
}
