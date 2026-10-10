// `ConnectivityService` fake'i (PLAN §16.3, CD-08): durum [isOffline] ile
// doğrudan kurulur ya da [emit] ile akışa da yayınlanır.
//
//   final connectivity = FakeConnectivityService()..isOffline = true;
//   connectivity.emit(false); // çevrimiçine dönüş olayı
import 'dart:async';

import 'package:gu_kulupler/product/service/connectivity_service.dart';

import 'fake_base.dart';

final class FakeConnectivityService extends FakeBase
    implements ConnectivityService {
  /// Son bilinen durum; testte doğrudan yazılabilir (akışa olay düşmez).
  @override
  bool isOffline = false;

  /// [onOfflineChanged] akışının denetleyicisi.
  final StreamController<bool> controller = StreamController<bool>.broadcast();

  /// [refresh] çağrısının platformdan okuyacağı değer; `null` → [isOffline]
  /// değişmez.
  bool? nextRefresh;

  @override
  Stream<bool> get onOfflineChanged => controller.stream;

  /// Durumu [offline] yapar ve değiştiyse akışa yayınlar (gerçek servis
  /// gibi aynı değeri yinelemez).
  void emit(bool offline) {
    if (offline == isOffline) return;
    isOffline = offline;
    controller.add(offline);
  }

  @override
  Future<bool> refresh() async {
    record('refresh');
    if (nextRefresh case final next?) {
      nextRefresh = null;
      emit(next);
    }
    return isOffline;
  }
}
