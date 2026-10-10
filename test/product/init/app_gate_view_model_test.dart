// T-11 · AppGateViewModel: zorunlu güncelleme kapısı, oturum sona erdi
// bayrağı, bakım mesajı, Remote Config hata sessizliği (PLAN §12.2; CD-48).
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/init/app_gate_state.dart';
import 'package:gu_kulupler/product/init/app_gate_view_model.dart';
import 'package:gu_kulupler/product/service/app_info_service.dart';

import '../../fakes/fake_app_info_service.dart';
import '../../fakes/fake_remote_config_service.dart';
import '../../fakes/register_fakes.dart';
import '../../helpers/test_container.dart';

void main() {
  late FakeRemoteConfigService config;
  late FakeAppInfoService info;

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    config = GetIt.I<RemoteConfigService>() as FakeRemoteConfigService;
    info = GetIt.I<AppInfoService>() as FakeAppInfoService..buildNumber = '10';
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) {};
    addTearDown(() => debugPrint = original);
  });

  group('T-11 · AppGateViewModel · başlangıç', () {
    test('ilk state eşzamanlıdır: kurulu derleme + önbellekteki değerler; '
        'çekim arka planda başlar', () async {
      final container = createContainer();
      expect(
        container.read(appGateViewModelProvider),
        const AppGateState(currentBuild: 10),
      );
      expect(config.callsTo('fetchAndActivate'), isEmpty);

      await pumpEventQueue();
      expect(config.callsTo('fetchAndActivate'), hasLength(1));
      expect(
        container.read(appGateViewModelProvider),
        const AppGateState(currentBuild: 10),
      );
    });

    test('önbellekte güncelleme zorunluluğu varsa ilk karede bilinir', () {
      config.values[RemoteConfigKeys.minSupportedBuild] = 11;
      final container = createContainer();
      final state = container.read(appGateViewModelProvider);
      expect(state.minSupportedBuild, 11);
      expect(state.isUpdateRequired, isTrue);
    });

    test('Remote Config kurucudan verilebilir (GetIt kaydı okunmaz)', () async {
      final injected = FakeRemoteConfigService()
        ..values[RemoteConfigKeys.maintenanceMessage] = 'Bakım var';
      final container = createContainer(
        overrides: [
          appGateViewModelProvider.overrideWith(
            () => AppGateViewModel(remoteConfigService: injected),
          ),
        ],
      );
      expect(
        container.read(appGateViewModelProvider).maintenanceMessage,
        'Bakım var',
      );
      await pumpEventQueue();
      expect(injected.callsTo('fetchAndActivate'), hasLength(1));
      expect(config.calls, isEmpty);
    });
  });

  group('T-11 · AppGateViewModel · zorunlu güncelleme', () {
    Future<AppGateState> stateFor({
      required int min,
      required String build,
    }) async {
      config.values[RemoteConfigKeys.minSupportedBuild] = min;
      info.buildNumber = build;
      final container = createContainer();
      await container.read(appGateViewModelProvider.notifier).check();
      return container.read(appGateViewModelProvider);
    }

    test('minSupportedBuild > currentBuild → isUpdateRequired', () async {
      final state = await stateFor(min: 11, build: '10');
      expect(state.minSupportedBuild, 11);
      expect(state.currentBuild, 10);
      expect(state.isUpdateRequired, isTrue);
    });

    test('minSupportedBuild == currentBuild → gerekmez', () async {
      expect((await stateFor(min: 10, build: '10')).isUpdateRequired, isFalse);
    });

    test('minSupportedBuild < currentBuild → gerekmez', () async {
      expect((await stateFor(min: 9, build: '10')).isUpdateRequired, isFalse);
    });

    test('minSupportedBuild 0 (kapı kapalı) → gerekmez', () async {
      expect((await stateFor(min: 0, build: '10')).isUpdateRequired, isFalse);
    });

    test('derleme numarası okunamadıysa (0) kullanıcı kilitlenmez', () async {
      final state = await stateFor(min: 99, build: '');
      expect(state.currentBuild, 0);
      expect(state.minSupportedBuild, 99);
      expect(state.isUpdateRequired, isFalse);
    });

    test('çekimden sonra gelen değer kapıyı açar', () async {
      final container = createContainer();
      final notifier = container.read(appGateViewModelProvider.notifier);
      await pumpEventQueue();
      expect(
        container.read(appGateViewModelProvider).isUpdateRequired,
        isFalse,
      );

      config.values[RemoteConfigKeys.minSupportedBuild] = 42;
      await notifier.check();
      expect(container.read(appGateViewModelProvider).isUpdateRequired, isTrue);
    });

    test('canlı yapılandırma güncellemesi değerleri yeniden okur', () async {
      final container = createContainer()
        ..listen(appGateViewModelProvider, (_, _) {});
      await pumpEventQueue();

      config.values[RemoteConfigKeys.minSupportedBuild] = 11;
      config.values[RemoteConfigKeys.maintenanceMessage] = 'Kısa bakım';
      config.configUpdatedController.add(null);
      await pumpEventQueue();

      final state = container.read(appGateViewModelProvider);
      expect(state.isUpdateRequired, isTrue);
      expect(state.maintenanceMessage, 'Kısa bakım');

      // Kapı geri de kapanabilir (yanlış değer düzeltildi).
      config.values[RemoteConfigKeys.minSupportedBuild] = 1;
      config.configUpdatedController.add(null);
      await pumpEventQueue();
      expect(
        container.read(appGateViewModelProvider).isUpdateRequired,
        isFalse,
      );
    });
  });

  group('T-11 · AppGateViewModel · check', () {
    test('çekim sırasında isFetching; bitince kapanır', () async {
      final container = createContainer();
      final notifier = container.read(appGateViewModelProvider.notifier);
      await pumpEventQueue();

      final pending = notifier.check();
      expect(container.read(appGateViewModelProvider).isFetching, isTrue);
      await pending;
      expect(container.read(appGateViewModelProvider).isFetching, isFalse);
    });

    test('art arda iki çağrı tek çekim yapar', () async {
      final container = createContainer();
      final notifier = container.read(appGateViewModelProvider.notifier);
      await pumpEventQueue();
      config.calls.clear();

      await Future.wait([notifier.check(), notifier.check()]);
      expect(config.callsTo('fetchAndActivate'), hasLength(1));
    });

    test(
      'hata sessizdir: isError, değerler varsayılanlardan devam eder',
      () async {
        final container = createContainer();
        final notifier = container.read(appGateViewModelProvider.notifier);
        await pumpEventQueue();

        config.failNext(RemoteConfigError.network);
        await notifier.check();
        final state = container.read(appGateViewModelProvider);
        expect(state.isError, isTrue);
        expect(state.isFetching, isFalse);
        expect(state.isUpdateRequired, isFalse);
        expect(state.maintenanceMessage, isEmpty);
      },
    );

    test("sonraki başarılı çekim isError'ı temizler", () async {
      final container = createContainer();
      final notifier = container.read(appGateViewModelProvider.notifier);
      await pumpEventQueue();
      config.failNext(RemoteConfigError.timeout);
      await notifier.check();
      await notifier.check();
      expect(container.read(appGateViewModelProvider).isError, isFalse);
    });

    test("bakım mesajı state'e yansır; boşaltılınca bant kalkar", () async {
      config.values[RemoteConfigKeys.maintenanceMessage] = 'Bakım 02:00';
      final container = createContainer();
      final notifier = container.read(appGateViewModelProvider.notifier);
      await notifier.check();
      expect(
        container.read(appGateViewModelProvider).maintenanceMessage,
        'Bakım 02:00',
      );
      expect(
        container.read(appGateViewModelProvider).hasMaintenanceMessage,
        isTrue,
      );

      config.values.remove(RemoteConfigKeys.maintenanceMessage);
      await notifier.check();
      expect(
        container.read(appGateViewModelProvider).hasMaintenanceMessage,
        isFalse,
      );
    });

    test("kapsayıcı kapandıktan sonra biten çekim state'e yazmaz ve "
        'dinleyici kapanır', () async {
      final container = createContainer();
      final notifier = container.read(appGateViewModelProvider.notifier);
      await pumpEventQueue();
      expect(config.configUpdatedController.hasListener, isTrue);

      final pending = notifier.check();
      container.dispose();
      await pending;
      await pumpEventQueue();
      expect(config.configUpdatedController.hasListener, isFalse);
    });
  });

  group('T-11 · AppGateViewModel · oturum sona erdi', () {
    test('onSessionExpired bayrağı açar; acknowledge kapatır', () async {
      final container = createContainer();
      final notifier = container.read(appGateViewModelProvider.notifier);
      await pumpEventQueue();
      expect(
        container.read(appGateViewModelProvider).isSessionExpired,
        isFalse,
      );

      notifier.onSessionExpired();
      expect(container.read(appGateViewModelProvider).isSessionExpired, isTrue);

      notifier.acknowledgeSessionExpired();
      expect(
        container.read(appGateViewModelProvider).isSessionExpired,
        isFalse,
      );
    });

    test('bayrak diğer kapıları etkilemez ve çekimden etkilenmez', () async {
      config.values[RemoteConfigKeys.minSupportedBuild] = 11;
      final container = createContainer();
      final notifier = container.read(appGateViewModelProvider.notifier)
        ..onSessionExpired();
      await notifier.check();

      final state = container.read(appGateViewModelProvider);
      expect(state.isSessionExpired, isTrue);
      expect(state.isUpdateRequired, isTrue);
    });

    test('yinelenen bildirim tek bayraktır', () async {
      final container = createContainer();
      var changes = 0;
      container.listen(appGateViewModelProvider, (_, _) => changes++);
      await pumpEventQueue();
      changes = 0;
      container.read(appGateViewModelProvider.notifier)
        ..onSessionExpired()
        ..onSessionExpired();
      expect(changes, 1);
    });
  });
}
