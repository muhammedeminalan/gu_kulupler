// T-11 · FakeConnectivityService sözleşmesi (PLAN §16.3).
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/connectivity/connectivity_gate.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';

import 'fake_base.dart';
import 'fake_connectivity_service.dart';
import 'register_fakes.dart';

void main() {
  group('T-11 · FakeConnectivityService', () {
    test('ConnectivityService arayüzünü uygular; registerDefaultFakes '
        "servisi ve onu okuyan gerçek ConnectivityGate'i kaydeder", () {
      addTearDown(GetIt.I.reset);
      registerDefaultFakes();
      final fake = GetIt.I<ConnectivityService>();
      expect(fake, isA<FakeConnectivityService>());
      expect(fake, isA<FakeBase>());

      final gate = GetIt.I<ConnectivityGate>();
      expect(gate.requireOnline().isSuccess, isTrue);
      (fake as FakeConnectivityService).isOffline = true;
      expect(gate.requireOnline().errorOrNull, FirestoreError.offline);
    });

    test('varsayılan çevrimiçi; isOffline doğrudan yazılınca akışa olay '
        'düşmez', () async {
      final fake = FakeConnectivityService();
      final events = <bool>[];
      final sub = fake.onOfflineChanged.listen(events.add);
      addTearDown(sub.cancel);

      expect(fake.isOffline, isFalse);
      fake.isOffline = true;
      await pumpEventQueue();
      expect(events, isEmpty);
    });

    test('emit durumu değiştirir ve yalnızca değişimi yayınlar', () async {
      final fake = FakeConnectivityService();
      final events = <bool>[];
      final sub = fake.onOfflineChanged.listen(events.add);
      addTearDown(sub.cancel);

      fake
        ..emit(true)
        ..emit(true)
        ..emit(false);
      await pumpEventQueue();
      expect(events, [true, false]);
      expect(fake.isOffline, isFalse);
    });

    test(
      'refresh çağrıyı kaydeder; nextRefresh tek seferlik uygulanır',
      () async {
        final fake = FakeConnectivityService();
        expect(await fake.refresh(), isFalse);

        fake.nextRefresh = true;
        expect(await fake.refresh(), isTrue);
        expect(fake.nextRefresh, isNull);
        expect(await fake.refresh(), isTrue);
        expect(fake.callsTo('refresh'), hasLength(3));
      },
    );
  });
}
