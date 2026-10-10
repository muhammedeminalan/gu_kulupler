import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';

/// Cihazın ağ bağlantısı durumu (Q-12, CD-08).
///
/// Tek soru yanıtlanır: cihaz **çevrimdışı mı**? Çevrimdışıyken yazma
/// işlemleri engellenir (`ConnectivityGate`) ve kökte kalıcı bant gösterilir
/// (SYS-03). "Çevrimiçi" yalnızca bir ağ arayüzünün açık olduğunu söyler;
/// sunucuya erişim garanti değildir (istek hatası ayrıca ele alınır).
abstract interface class ConnectivityService {
  /// Son bilinen durum; ilk okuma tamamlanana dek `false`.
  bool get isOffline;

  /// Durum her **değiştiğinde** yeni değeri yayınlar (aynı değer yinelenmez).
  Stream<bool> get onOfflineChanged;

  /// Durumu platformdan yeniden okur, [isOffline]'ı günceller ve döndürür.
  /// Hiçbir zaman fırlatmaz: okunamazsa son bilinen değer kalır.
  Future<bool> refresh();
}

/// [ConnectivityService] uygulaması: `connectivity_plus`.
///
/// Dinleme [start] ile açılır (kompozisyon kökü çağırır). Hiçbir ağ arayüzü
/// yoksa (`ConnectivityResult.none` ya da boş liste) çevrimdışı sayılır.
final class DeviceConnectivityService implements ConnectivityService {
  /// [check] ve `changes` verilmezse `Connectivity()` kullanılır; testte
  /// platform kanalı yerine sahte kaynak verilir.
  DeviceConnectivityService({
    Future<List<ConnectivityResult>> Function()? check,
    this._changes,
  }) : _check = check ?? Connectivity().checkConnectivity;

  final Future<List<ConnectivityResult>> Function() _check;
  final Stream<List<ConnectivityResult>>? _changes;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOffline = false;

  /// [results] hiçbir ağ arayüzü içermiyor mu?
  static bool isOfflineResult(List<ConnectivityResult> results) =>
      results.every((result) => result == ConnectivityResult.none);

  @override
  bool get isOffline => _isOffline;

  @override
  Stream<bool> get onOfflineChanged => _controller.stream;

  /// İlk durumu okur ve değişimleri dinlemeye başlar; ikinci çağrı etkisizdir.
  Future<void> start() async {
    if (_subscription != null) return;
    _subscription = (_changes ?? Connectivity().onConnectivityChanged).listen(
      (results) => _apply(isOfflineResult(results)),
      onError: (Object error, StackTrace stack) => AppLogger.warn(
        'Bağlantı akışı hata verdi',
        error: error,
        stackTrace: stack,
      ),
    );
    await refresh();
  }

  @override
  Future<bool> refresh() async {
    try {
      _apply(isOfflineResult(await _check()));
    } on Object catch (error, stack) {
      // Platform okunamadı: son bilinen değer geçerli kalır.
      AppLogger.warn(
        'Bağlantı durumu okunamadı',
        error: error,
        stackTrace: stack,
      );
    }
    return _isOffline;
  }

  /// Dinlemeyi ve akışı kapatır.
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _controller.close();
  }

  void _apply(bool offline) {
    if (offline == _isOffline || _controller.isClosed) return;
    _isOffline = offline;
    _controller.add(offline);
  }
}
