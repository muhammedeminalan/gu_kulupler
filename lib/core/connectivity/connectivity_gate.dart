import 'dart:async';

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';

/// Firestore SDK ağ anahtarı (`FirestoreService.setNetworkEnabled`).
typedef FirestoreNetworkSwitch =
    Future<FirestoreResult<void>> Function({required bool enabled});

/// Çevrimdışı yazma kapısı (Q-12; PLAN §10.3, §12.1).
///
/// `FirestoreError.offline` değerini **yalnızca** bu sınıf üretir:
/// repository'ler çevrimdışılığı bilmez (SDK yazmayı kuyruğa alır), kullanıcıya
/// ise kuyruk vaat edilmez. ViewModel'ler kapıyı doğrudan değil
/// `WriteGuardMixin.ensureOnline()` üzerinden çağırır.
final class ConnectivityGate {
  /// Durumu [_service]'ten okuyan kapı. `setFirestoreNetwork` verilirse
  /// (yalnızca `AppEnvironment.debugMenuEnabled` — kompozisyon kökü)
  /// [simulatedOffline] Firestore ağını da kapatır / açar (T-44 · A4-08):
  /// simülasyonda okumalar gerçekten önbellekten gelir.
  ConnectivityGate(this._service, {this._setFirestoreNetwork});

  final ConnectivityService _service;
  final FirestoreNetworkSwitch? _setFirestoreNetwork;
  bool _simulatedOffline = false;

  /// DebugMenu çevrimdışı simülasyonu; yalnızca `ConnectivityViewModel`
  /// yazar (`AppEnvironment.debugMenuEnabled`).
  bool get simulatedOffline => _simulatedOffline;

  /// Değer değişince Firestore ağı simülasyona göre kapatılır / açılır
  /// (anahtar verildiyse; hata yalnızca günlüğe düşer).
  set simulatedOffline(bool value) {
    if (value == _simulatedOffline) return;
    _simulatedOffline = value;
    final toggle = _setFirestoreNetwork;
    if (toggle == null) return;
    unawaited(
      toggle(enabled: !value).then((result) {
        if (result case FirebaseFailure(:final error)) {
          AppLogger.warn(
            'Firestore ağ anahtarı değiştirilemedi: ${error.name}',
          );
        }
      }),
    );
  }

  /// Cihaz çevrimdışı mı (gerçek ya da simüle)?
  bool get isOffline => _simulatedOffline || _service.isOffline;

  /// Çevrimiçiyse başarı; çevrimdışıysa `FirestoreError.offline`.
  FirestoreResult<void> requireOnline() => isOffline
      ? const FirebaseFailure(FirestoreError.offline)
      : const FirebaseSuccess(null);
}
