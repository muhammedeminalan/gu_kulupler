// T-11 · ConnectivityGate: çevrimdışı yazma kapısı (Q-12; PLAN §10.3).
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/connectivity/connectivity_gate.dart';

import '../../fakes/fake_connectivity_service.dart';

void main() {
  group('T-11 · ConnectivityGate', () {
    test('çevrimiçi → başarı', () {
      final gate = ConnectivityGate(FakeConnectivityService());
      expect(gate.isOffline, isFalse);
      expect(
        gate.requireOnline(),
        isA<FirebaseSuccess<void, FirestoreError>>(),
      );
    });

    test('çevrimdışı → FirestoreError.offline', () {
      final service = FakeConnectivityService()..isOffline = true;
      final gate = ConnectivityGate(service);
      expect(gate.isOffline, isTrue);
      expect(gate.requireOnline().errorOrNull, FirestoreError.offline);
    });

    test('durum her çağrıda servisten yeniden okunur', () {
      final service = FakeConnectivityService();
      final gate = ConnectivityGate(service);
      expect(gate.requireOnline().isSuccess, isTrue);
      service.isOffline = true;
      expect(gate.requireOnline().isSuccess, isFalse);
      service.isOffline = false;
      expect(gate.requireOnline().isSuccess, isTrue);
    });

    test('simülasyon gerçek durumdan bağımsız olarak kapıyı kapatır', () {
      final gate = ConnectivityGate(FakeConnectivityService())
        ..simulatedOffline = true;
      expect(gate.isOffline, isTrue);
      expect(gate.requireOnline().errorOrNull, FirestoreError.offline);
      gate.simulatedOffline = false;
      expect(gate.requireOnline().isSuccess, isTrue);
    });

    test('T-44 · A4-08 · ağ anahtarı verilirse simülasyon Firestore ağını '
        'kapatır / açar; aynı değer yeniden çağırmaz', () async {
      final calls = <bool>[];
      final gate =
          ConnectivityGate(
              FakeConnectivityService(),
              setFirestoreNetwork: ({required enabled}) async {
                calls.add(enabled);
                return const FirebaseSuccess(null);
              },
            )
            ..simulatedOffline = true
            ..simulatedOffline = true;
      await pumpEventQueue();
      expect(calls, [false]);

      gate
        ..simulatedOffline = false
        ..simulatedOffline = false;
      await pumpEventQueue();
      expect(calls, [false, true]);
    });

    test(
      'T-44 · A4-08 · anahtar hatası fırlatmaz; kapı yine kapanır',
      () async {
        final gate = ConnectivityGate(
          FakeConnectivityService(),
          setFirestoreNetwork: ({required enabled}) async =>
              const FirebaseFailure(FirestoreError.unknown),
        );
        final original = debugPrint;
        debugPrint = (message, {wrapWidth}) {};
        addTearDown(() => debugPrint = original);

        gate.simulatedOffline = true;
        await pumpEventQueue();

        expect(gate.requireOnline().errorOrNull, FirestoreError.offline);
      },
    );

    test('T-44 · A4-08 · anahtar verilmezse (release / test) yan etki yok', () {
      final gate = ConnectivityGate(FakeConnectivityService())
        ..simulatedOffline = true;
      expect(gate.simulatedOffline, isTrue);
      expect(gate.isOffline, isTrue);
    });
  });
}
