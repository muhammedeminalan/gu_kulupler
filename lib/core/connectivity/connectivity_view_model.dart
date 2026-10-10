import 'dart:async';

import 'package:gu_kulupler/core/connectivity/connectivity_state.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/env/app_environment.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connectivity_view_model.g.dart';

/// Bağlantı durumunun kök ViewModel'i (PLAN §12.2; Q-12).
///
/// `ConnectivityService` akışını dinler: çevrimdışına düşünce kök bant
/// (SYS-03) görünür, çevrimiçine **dönüşte** TST-25 gösterilir. Yazma engeli
/// bu state'ten değil `ConnectivityGate`'ten okunur (`WriteGuardMixin`).
@Riverpod(keepAlive: true)
final class ConnectivityViewModel extends _$ConnectivityViewModel
    with ProjectDependencyMixin {
  bool _realOffline = false;

  @override
  ConnectivityState build() {
    final subscription = connectivityService.onOfflineChanged.listen(
      _onRealChanged,
    );
    ref.onDispose(subscription.cancel);
    _realOffline = connectivityService.isOffline;
    return ConnectivityState(
      isOffline: _realOffline,
      wasOffline: _realOffline,
    );
  }

  /// Durumu platformdan yeniden okur (SYS-03 "Yeniden dene").
  Future<void> recheck() async {
    _onRealChanged(await connectivityService.refresh());
  }

  /// Çevrimdışılığı simüle eder (DebugMenu). Yalnızca
  /// `AppEnvironment.debugMenuEnabled` iken etkilidir; [debugMenuEnabled]
  /// yalnızca testte verilir.
  void setSimulatedOffline(
    bool value, {
    bool debugMenuEnabled = AppEnvironment.debugMenuEnabled,
  }) {
    if (!debugMenuEnabled || value == state.isSimulated) return;
    connectivityGate.simulatedOffline = value;
    _apply(isSimulated: value);
  }

  /// Ekrandaki verinin önbellekten geldiğini bildirir (liste ViewModel'leri).
  void setFromCache(bool value) {
    if (value == state.isFromCache) return;
    state = state.copyWith(isFromCache: value);
  }

  void _onRealChanged(bool offline) {
    if (offline == _realOffline) return;
    _realOffline = offline;
    _apply(isSimulated: state.isSimulated);
  }

  /// Etkin durumu (`gerçek || simüle`) yeniden hesaplar; çevrimdışından
  /// çevrimiçine geçişte TST-25 gösterir.
  void _apply({required bool isSimulated}) {
    final offline = _realOffline || isSimulated;
    final cameBack = state.isOffline && !offline;
    state = state.copyWith(
      isOffline: offline,
      isSimulated: isSimulated,
      wasOffline: state.wasOffline || offline,
      isFromCache: offline && state.isFromCache,
    );
    if (cameBack) feedback.showToast(ToastId.tst25);
  }
}
