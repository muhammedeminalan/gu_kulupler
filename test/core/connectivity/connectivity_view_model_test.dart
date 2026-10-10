// T-11 · ConnectivityViewModel: bağlantı akışı → state, çevrimiçine dönüş
// toastı, yeniden deneme, DebugMenu simülasyonu (PLAN §12.2; Q-12).
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_kulupler/core/connectivity/connectivity_gate.dart';
import 'package:gu_kulupler/core/connectivity/connectivity_state.dart';
import 'package:gu_kulupler/core/connectivity/connectivity_view_model.dart';
import 'package:gu_kulupler/core/env/app_environment.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';

import '../../fakes/fake_connectivity_service.dart';
import '../../fakes/fake_feedback_service.dart';
import '../../fakes/register_fakes.dart';
import '../../helpers/test_container.dart';

void main() {
  late FakeConnectivityService service;
  late FakeFeedbackService feedback;
  late ConnectivityGate gate;

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    service = GetIt.I<ConnectivityService>() as FakeConnectivityService;
    feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
    gate = GetIt.I<ConnectivityGate>();
  });

  group('T-11 · ConnectivityViewModel', () {
    test('başlangıç: çevrimiçi', () {
      final container = createContainer();
      expect(
        container.read(connectivityViewModelProvider),
        const ConnectivityState(),
      );
    });

    test('başlangıç: servis çevrimdışıysa state de çevrimdışı başlar', () {
      service.isOffline = true;
      final container = createContainer();
      expect(
        container.read(connectivityViewModelProvider),
        const ConnectivityState(isOffline: true, wasOffline: true),
      );
    });

    test('çevrimdışına düşünce isOffline + wasOffline; toast yok', () async {
      final container = createContainer()
        ..listen(connectivityViewModelProvider, (_, _) {});
      service.emit(true);
      await pumpEventQueue();

      expect(
        container.read(connectivityViewModelProvider),
        const ConnectivityState(isOffline: true, wasOffline: true),
      );
      expect(feedback.toasts, isEmpty);
    });

    test('çevrimiçine dönüşte "bağlantı geri geldi" toastı; wasOffline '
        'kalır', () async {
      final container = createContainer()
        ..listen(connectivityViewModelProvider, (_, _) {});
      service.emit(true);
      await pumpEventQueue();
      service.emit(false);
      await pumpEventQueue();

      expect(
        container.read(connectivityViewModelProvider),
        const ConnectivityState(wasOffline: true),
      );
      expect(feedback.toasts, [ToastId.tst25]);
    });

    test('her dönüşte bir toast; yinelenen olay toast üretmez', () async {
      createContainer().listen(connectivityViewModelProvider, (_, _) {});
      service.emit(true);
      await pumpEventQueue();
      service.emit(false);
      // Aynı değer akışa ham olarak yeniden düşse de yok sayılır.
      service.controller.add(false);
      await pumpEventQueue();
      service.emit(true);
      await pumpEventQueue();
      service.emit(false);
      await pumpEventQueue();

      expect(feedback.toasts, [ToastId.tst25, ToastId.tst25]);
    });

    test("recheck: platformdan yeniden okur ve state'i günceller", () async {
      service.isOffline = true;
      final container = createContainer();
      final notifier = container.read(connectivityViewModelProvider.notifier);

      // Hâlâ çevrimdışı: state değişmez, toast yok.
      await notifier.recheck();
      expect(container.read(connectivityViewModelProvider).isOffline, isTrue);
      expect(feedback.toasts, isEmpty);

      service.nextRefresh = false;
      await notifier.recheck();
      expect(container.read(connectivityViewModelProvider).isOffline, isFalse);
      expect(feedback.toasts, [ToastId.tst25]);
      expect(service.callsTo('refresh'), hasLength(2));
    });

    test('önbellek bayrağı: setFromCache yazar; çevrimiçine dönünce '
        'temizlenir', () async {
      final container = createContainer()
        ..listen(connectivityViewModelProvider, (_, _) {});
      final notifier = container.read(connectivityViewModelProvider.notifier);
      service.emit(true);
      await pumpEventQueue();

      notifier.setFromCache(true);
      expect(container.read(connectivityViewModelProvider).isFromCache, isTrue);

      service.emit(false);
      await pumpEventQueue();
      expect(
        container.read(connectivityViewModelProvider).isFromCache,
        isFalse,
      );
    });

    test('setFromCache aynı değerde state üretmez', () {
      final container = createContainer();
      var changes = 0;
      container.listen(connectivityViewModelProvider, (_, _) => changes++);
      container
          .read(connectivityViewModelProvider.notifier)
          .setFromCache(false);
      expect(changes, 0);
    });

    test('dispose sonrası akış dinlenmez', () async {
      final container = createContainer()..read(connectivityViewModelProvider);
      expect(service.controller.hasListener, isTrue);
      container.dispose();
      await pumpEventQueue();
      expect(service.controller.hasListener, isFalse);
    });
  });

  group('T-11 · ConnectivityViewModel · simülasyon (DebugMenu)', () {
    test('test koşusunda DebugMenu kapalıdır: setSimulatedOffline etkisiz', () {
      expect(AppEnvironment.debugMenuEnabled, isFalse);
      final container = createContainer();
      container
          .read(connectivityViewModelProvider.notifier)
          .setSimulatedOffline(true);

      expect(
        container.read(connectivityViewModelProvider),
        const ConnectivityState(),
      );
      expect(gate.simulatedOffline, isFalse);
    });

    test('DebugMenu açıkken: state çevrimdışı + simüle, yazma kapısı '
        'kapanır', () {
      final container = createContainer();
      container
          .read(connectivityViewModelProvider.notifier)
          .setSimulatedOffline(true, debugMenuEnabled: true);

      expect(
        container.read(connectivityViewModelProvider),
        const ConnectivityState(
          isOffline: true,
          wasOffline: true,
          isSimulated: true,
        ),
      );
      expect(gate.isOffline, isTrue);
    });

    test('simülasyon kapanınca çevrimiçine döner ve dönüş toastı '
        'gösterilir', () {
      final container = createContainer();
      container.read(connectivityViewModelProvider.notifier)
        ..setSimulatedOffline(true, debugMenuEnabled: true)
        ..setSimulatedOffline(false, debugMenuEnabled: true);

      expect(
        container.read(connectivityViewModelProvider),
        const ConnectivityState(wasOffline: true),
      );
      expect(gate.simulatedOffline, isFalse);
      expect(feedback.toasts, [ToastId.tst25]);
    });

    test(
      'gerçekten çevrimdışıyken simülasyonu kapatmak çevrimiçi yapmaz',
      () async {
        final container = createContainer()
          ..listen(connectivityViewModelProvider, (_, _) {});
        final notifier = container.read(connectivityViewModelProvider.notifier)
          ..setSimulatedOffline(true, debugMenuEnabled: true);
        service.emit(true);
        await pumpEventQueue();

        notifier.setSimulatedOffline(false, debugMenuEnabled: true);
        expect(
          container.read(connectivityViewModelProvider),
          const ConnectivityState(isOffline: true, wasOffline: true),
        );
        expect(feedback.toasts, isEmpty);
      },
    );

    test('simüle çevrimdışıyken gerçek bağlantının gelmesi çevrimiçi '
        'yapmaz', () async {
      service.isOffline = true;
      final container = createContainer()
        ..listen(connectivityViewModelProvider, (_, _) {});
      container
          .read(connectivityViewModelProvider.notifier)
          .setSimulatedOffline(true, debugMenuEnabled: true);
      service.emit(false);
      await pumpEventQueue();

      expect(container.read(connectivityViewModelProvider).isOffline, isTrue);
      expect(feedback.toasts, isEmpty);
    });

    test('aynı değerle ikinci çağrı state üretmez', () {
      final container = createContainer();
      var changes = 0;
      container.listen(connectivityViewModelProvider, (_, _) => changes++);
      container.read(connectivityViewModelProvider.notifier)
        ..setSimulatedOffline(true, debugMenuEnabled: true)
        ..setSimulatedOffline(true, debugMenuEnabled: true);
      expect(changes, 1);
    });
  });
}
