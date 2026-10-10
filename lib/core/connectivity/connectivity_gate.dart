import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';

/// Çevrimdışı yazma kapısı (Q-12; PLAN §10.3, §12.1).
///
/// `FirestoreError.offline` değerini **yalnızca** bu sınıf üretir:
/// repository'ler çevrimdışılığı bilmez (SDK yazmayı kuyruğa alır), kullanıcıya
/// ise kuyruk vaat edilmez. ViewModel'ler kapıyı doğrudan değil
/// `WriteGuardMixin.ensureOnline()` üzerinden çağırır.
final class ConnectivityGate {
  /// Durumu [_service]'ten okuyan kapı.
  ConnectivityGate(this._service);

  final ConnectivityService _service;

  /// DebugMenu çevrimdışı simülasyonu; yalnızca `ConnectivityViewModel`
  /// yazar (`AppEnvironment.debugMenuEnabled`).
  bool simulatedOffline = false;

  /// Cihaz çevrimdışı mı (gerçek ya da simüle)?
  bool get isOffline => simulatedOffline || _service.isOffline;

  /// Çevrimiçiyse başarı; çevrimdışıysa `FirestoreError.offline`.
  FirestoreResult<void> requireOnline() => isOffline
      ? const FirebaseFailure(FirestoreError.offline)
      : const FirebaseSuccess(null);
}
