// T-11 · DeviceConnectivityService: connectivity_plus sonuçları → çevrimdışı
// bayrağı (Q-12, CD-08). Platform kanalı yerine sahte kaynak verilir.
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';

void main() {
  late StreamController<List<ConnectivityResult>> changes;
  late List<ConnectivityResult> current;
  late bool checkThrows;
  late int checks;

  DeviceConnectivityService build() {
    final service = DeviceConnectivityService(
      check: () async {
        checks++;
        if (checkThrows) throw StateError('platform yok');
        return current;
      },
      changes: changes.stream,
    );
    addTearDown(service.dispose);
    return service;
  }

  setUp(() {
    changes = StreamController<List<ConnectivityResult>>.broadcast();
    current = [ConnectivityResult.wifi];
    checkThrows = false;
    checks = 0;
    // AppLogger uyarıları test çıktısını kirletmesin.
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) {};
    addTearDown(() => debugPrint = original);
  });

  group('T-11 · DeviceConnectivityService', () {
    test('isOfflineResult: yalnızca none ya da boş liste çevrimdışıdır', () {
      expect(DeviceConnectivityService.isOfflineResult([]), isTrue);
      expect(
        DeviceConnectivityService.isOfflineResult([ConnectivityResult.none]),
        isTrue,
      );
      for (final result in ConnectivityResult.values) {
        if (result == ConnectivityResult.none) continue;
        expect(
          DeviceConnectivityService.isOfflineResult([result]),
          isFalse,
          reason: '$result',
        );
      }
      expect(
        DeviceConnectivityService.isOfflineResult([
          ConnectivityResult.none,
          ConnectivityResult.mobile,
        ]),
        isFalse,
      );
    });

    test('start öncesi çevrimiçi sayılır; start ilk durumu okur', () async {
      current = [ConnectivityResult.none];
      final service = build();
      expect(service.isOffline, isFalse);

      await service.start();
      expect(service.isOffline, isTrue);
      expect(checks, 1);
    });

    test('değişimler yayınlanır; aynı durum yinelenmez', () async {
      final service = build();
      await service.start();
      final events = <bool>[];
      final sub = service.onOfflineChanged.listen(events.add);
      addTearDown(sub.cancel);

      changes
        ..add([ConnectivityResult.none])
        ..add([ConnectivityResult.none])
        ..add([ConnectivityResult.mobile])
        ..add([ConnectivityResult.wifi]);
      await pumpEventQueue();

      expect(events, [true, false]);
      expect(service.isOffline, isFalse);
    });

    test('start ikinci kez çağrılınca yeniden dinlemez / okumaz', () async {
      final service = build();
      await service.start();
      await service.start();
      expect(checks, 1);

      final events = <bool>[];
      final sub = service.onOfflineChanged.listen(events.add);
      addTearDown(sub.cancel);
      changes.add([ConnectivityResult.none]);
      await pumpEventQueue();
      expect(events, [true]);
    });

    test('refresh durumu yeniden okur ve değişimi yayınlar', () async {
      final service = build();
      await service.start();
      final events = <bool>[];
      final sub = service.onOfflineChanged.listen(events.add);
      addTearDown(sub.cancel);

      current = [ConnectivityResult.none];
      expect(await service.refresh(), isTrue);
      current = [ConnectivityResult.ethernet];
      expect(await service.refresh(), isFalse);
      await pumpEventQueue();
      expect(events, [true, false]);
    });

    test('platform okunamazsa fırlatmaz; son bilinen değer kalır', () async {
      current = [ConnectivityResult.none];
      final service = build();
      await service.start();

      checkThrows = true;
      expect(await service.refresh(), isTrue);
      expect(service.isOffline, isTrue);
    });

    test('akış hatası yutulur; sonraki olay işlenir', () async {
      final service = build();
      await service.start();
      changes
        ..addError(StateError('akış'))
        ..add([ConnectivityResult.none]);
      await pumpEventQueue();
      expect(service.isOffline, isTrue);
    });

    test('dispose sonrası olay işlenmez ve akış kapanır', () async {
      final service = DeviceConnectivityService(
        check: () async => current,
        changes: changes.stream,
      );
      await service.start();
      var done = false;
      service.onOfflineChanged.listen((_) {}, onDone: () => done = true);

      await service.dispose();
      changes.add([ConnectivityResult.none]);
      await pumpEventQueue();
      expect(done, isTrue);
      expect(service.isOffline, isFalse);
    });
  });
}
