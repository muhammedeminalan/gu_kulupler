// SYS-01 · SplashViewModel: başlangıç anı, animasyon bitişi, zaman aşımı
// (PLAN §12.3). Oturumu çözmez; yalnızca açılışın kendi durumunu tutar.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/system/provider/splash_state.dart';
import 'package:gu_kulupler/features/system/provider/splash_view_model.dart';
import 'package:gu_kulupler/product/service/app_info_service.dart';

import '../../../fakes/fake_app_info_service.dart';
import '../../../fakes/register_fakes.dart';
import '../../../helpers/fake_app_clock.dart';
import '../../../helpers/test_container.dart';

void main() {
  late FakeAppClock clock;
  late List<String> logs;

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    clock = GetIt.I<AppClock>() as FakeAppClock;
    logs = <String>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
    addTearDown(() => debugPrint = original);
  });

  SplashViewModel notifierOf(ProviderContainer container) =>
      container.read(splashViewModelProvider.notifier);

  group('SYS-01 · SplashViewModel', () {
    test('ilk state: sürüm AppInfoService’ten; bayraklar kapalı', () {
      (GetIt.I<AppInfoService>() as FakeAppInfoService).version = '2.4.1';
      final container = createContainer();
      addTearDown(container.listen(splashViewModelProvider, (_, _) {}).close);
      expect(
        container.read(splashViewModelProvider),
        const SplashState(version: '2.4.1'),
      );
    });

    test('start başlangıç anını saatten alır; yinelenen çağrı etkisiz', () {
      final container = createContainer();
      addTearDown(container.listen(splashViewModelProvider, (_, _) {}).close);
      notifierOf(container).start();
      expect(
        container.read(splashViewModelProvider).startedAt,
        kDefaultFakeNowUtc,
      );

      clock.advance(const Duration(seconds: 5));
      notifierOf(container).start();
      expect(
        container.read(splashViewModelProvider).startedAt,
        kDefaultFakeNowUtc,
      );
    });

    test('onAnimationDone bayrağı bir kez kaldırır', () {
      final container = createContainer();
      final states = <SplashState>[];
      addTearDown(
        container
            .listen(splashViewModelProvider, (_, next) => states.add(next))
            .close,
      );
      notifierOf(container)
        ..onAnimationDone()
        ..onAnimationDone();
      expect(states, hasLength(1));
      expect(states.single.isAnimationDone, isTrue);
      expect(states.single.isTimedOut, isFalse);
    });

    test('onTimeout bayrağı bir kez kaldırır ve beklenen süreyi günlüğe '
        'yazar', () {
      final container = createContainer();
      final states = <SplashState>[];
      addTearDown(
        container
            .listen(splashViewModelProvider, (_, next) => states.add(next))
            .close,
      );
      notifierOf(container).start();
      clock.advance(Limits.splashTimeout);
      notifierOf(container)
        ..onTimeout()
        ..onTimeout();
      expect(states.where((s) => s.isTimedOut), hasLength(1));
      expect(states.last.isTimedOut, isTrue);
      expect(states.last.isAnimationDone, isFalse);
      expect(logs.join('\n'), contains('${Limits.splashTimeout}'));
    });

    test('start çağrılmadan gelen zaman aşımı da işlenir', () {
      final container = createContainer();
      addTearDown(container.listen(splashViewModelProvider, (_, _) {}).close);
      notifierOf(container).onTimeout();
      expect(container.read(splashViewModelProvider).isTimedOut, isTrue);
      expect(container.read(splashViewModelProvider).startedAt, isNull);
    });
  });
}
