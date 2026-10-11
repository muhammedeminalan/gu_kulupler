// T-13 · appClockProvider: view katmanının AppClock köprüsü (CD-93 kalıbı).
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';

import '../../fakes/register_fakes.dart';
import '../../helpers/fake_app_clock.dart';
import '../../helpers/test_container.dart';

void main() {
  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
  });

  group('T-13 · appClockProvider', () {
    test("GetIt'teki kayıtlı saati verir (ViewModel ile aynı örnek)", () {
      final container = createContainer();

      expect(container.read(appClockProvider), same(GetIt.I<AppClock>()));
      expect(container.read(appClockProvider).nowUtc(), kDefaultFakeNowUtc);
    });

    test('saat ilerleyince aynı örnekten yeni an okunur', () {
      final container = createContainer();
      final clock = container.read(appClockProvider);

      (GetIt.I<AppClock>() as FakeAppClock).advance(
        const Duration(seconds: 30),
      );

      expect(
        clock.nowUtc(),
        kDefaultFakeNowUtc.add(const Duration(seconds: 30)),
      );
    });

    test('testte override edilebilir', () {
      final other = FakeAppClock(DateTime.utc(2027));
      final container = createContainer(
        overrides: [appClockProvider.overrideWithValue(other)],
      );

      expect(container.read(appClockProvider), same(other));
    });
  });
}
