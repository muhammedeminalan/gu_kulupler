// T-11 · ConnectivityGate: çevrimdışı yazma kapısı (Q-12; PLAN §10.3).
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
  });
}
