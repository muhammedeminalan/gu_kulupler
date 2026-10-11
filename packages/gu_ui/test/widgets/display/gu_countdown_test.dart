// T-13 · GuCountdown (widget-catalog ek-6; CD-96; core.js:658
// `useCountdown`): hedef ana kadar geri sayım, sahte saat, tek seferlik
// onDone.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

/// Testin saati: `tester.pump(süre)` ile birlikte elle ilerletilir.
final class _Clock {
  DateTime value = DateTime.utc(2026, 10, 12, 16, 30);

  DateTime now() => value;
}

void main() {
  late _Clock clock;
  late List<Duration> built;
  late int done;

  setUp(() {
    clock = _Clock();
    built = [];
    done = 0;
  });

  Widget countdown(
    DateTime until, {
    Duration tick = GuMotion.countdownTick,
    bool withOnDone = true,
  }) => Center(
    child: GuCountdown(
      until: until,
      now: clock.now,
      tick: tick,
      onDone: withOnDone ? () => done++ : null,
      builder: (context, remaining) {
        built.add(remaining);
        return Text('${GuCountdown.secondsLeft(remaining)}');
      },
    ),
  );

  /// Saati ve test zamanını birlikte [by] kadar ilerletir.
  Future<void> advance(WidgetTester tester, Duration by) async {
    clock.value = clock.value.add(by);
    await tester.pump(by);
  }

  group('T-13 · GuCountdown', () {
    testWidgets('T-13 · GuCountdown · her saniye kalan süreyi yeniden kurar; '
        'süre dolunca onDone bir kez çağrılır ve zamanlayıcı durur', (
      tester,
    ) async {
      await tester.pumpApp(
        countdown(clock.value.add(const Duration(seconds: 3))),
      );
      expect(find.text('3'), findsOneWidget);
      expect(done, 0);

      await advance(tester, const Duration(seconds: 1));
      expect(find.text('2'), findsOneWidget);
      await advance(tester, const Duration(seconds: 1));
      expect(find.text('1'), findsOneWidget);
      expect(done, 0);

      await advance(tester, const Duration(seconds: 1));
      expect(find.text('0'), findsOneWidget);
      expect(done, 1);

      // Zamanlayıcı durdu: ne yeni kurulum ne ikinci onDone.
      final builds = built.length;
      await advance(tester, const Duration(seconds: 5));
      expect(built, hasLength(builds));
      expect(done, 1);
      expect(built.last, Duration.zero);
    });

    testWidgets('T-13 · GuCountdown · kalan süre saatten okunur: saat '
        'sıçrarsa (arka plandan dönüş) sonraki adım doğru değeri gösterir', (
      tester,
    ) async {
      await tester.pumpApp(
        countdown(clock.value.add(const Duration(seconds: 30))),
      );
      expect(find.text('30'), findsOneWidget);

      // Saat 20 sn ilerledi ama yalnızca bir adım çalıştı.
      clock.value = clock.value.add(const Duration(seconds: 20));
      await tester.pump(GuMotion.countdownTick);
      expect(find.text('10'), findsOneWidget);

      // Hedef geçildi: tek adımda biter, kalan eksiye düşmez.
      clock.value = clock.value.add(const Duration(minutes: 5));
      await tester.pump(GuMotion.countdownTick);
      expect(find.text('0'), findsOneWidget);
      expect(built.last, Duration.zero);
      expect(done, 1);
    });

    testWidgets('T-13 · GuCountdown · süresi dolmuş hedefle kurulursa '
        'zamanlayıcı kurulmaz; onDone ilk kareden sonra bir kez çağrılır', (
      tester,
    ) async {
      await tester.pumpApp(
        countdown(clock.value.subtract(const Duration(seconds: 1))),
      );

      expect(find.text('0'), findsOneWidget);
      expect(done, 1);
      await advance(tester, const Duration(seconds: 3));
      expect(done, 1);
      expect(built.every((remaining) => remaining == Duration.zero), isTrue);
    });

    testWidgets('T-13 · GuCountdown · until değişince sayım yeni hedefle '
        'baştan başlar ve onDone yeniden kurulur', (tester) async {
      var until = clock.value.add(const Duration(seconds: 1));
      late StateSetter rebuild;
      await tester.pumpApp(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return countdown(until);
          },
        ),
      );
      await advance(tester, const Duration(seconds: 1));
      expect(done, 1);

      rebuild(() => until = clock.value.add(const Duration(seconds: 2)));
      await tester.pump();
      expect(find.text('2'), findsOneWidget);

      await advance(tester, const Duration(seconds: 1));
      expect(find.text('1'), findsOneWidget);
      expect(done, 1);
      await advance(tester, const Duration(seconds: 1));
      expect(done, 2);

      // Aynı hedefle yeniden kurulum sayımı sıfırlamaz.
      rebuild(() {});
      await tester.pump();
      expect(done, 2);
    });

    testWidgets('T-13 · GuCountdown · tick parametresi adım aralığını '
        'belirler (varsayılan GuMotion.countdownTick = 1 sn)', (tester) async {
      expect(GuMotion.countdownTick, const Duration(seconds: 1));
      await tester.pumpApp(
        countdown(
          clock.value.add(const Duration(seconds: 2)),
          tick: const Duration(milliseconds: 500),
        ),
      );
      final builds = built.length;

      await advance(tester, const Duration(milliseconds: 500));
      expect(built, hasLength(builds + 1));
      expect(built.last, const Duration(milliseconds: 1500));
      expect(find.text('2'), findsOneWidget, reason: 'yukarı yuvarlanır');
    });

    testWidgets('T-13 · GuCountdown · ağaçtan çıkınca zamanlayıcı kapanır; '
        'onDone verilmese de süre dolumu hata vermez', (tester) async {
      await tester.pumpApp(
        countdown(
          clock.value.add(const Duration(seconds: 1)),
          withOnDone: false,
        ),
      );
      await advance(tester, const Duration(seconds: 1));
      expect(find.text('0'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpApp(
        countdown(clock.value.add(const Duration(seconds: 10))),
      );
      await tester.pumpApp(const SizedBox.shrink());
      final builds = built.length;
      await advance(tester, const Duration(seconds: 3));

      expect(built, hasLength(builds));
      expect(done, 0);
      // Bekleyen zamanlayıcı kalsaydı test sonunda "Timer is still pending"
      // hatası verirdi.
    });

    test('T-13 · GuCountdown · secondsLeft yukarı yuvarlar, eksiye düşmez', () {
      expect(GuCountdown.secondsLeft(const Duration(seconds: 30)), 30);
      expect(GuCountdown.secondsLeft(const Duration(milliseconds: 29200)), 30);
      expect(GuCountdown.secondsLeft(const Duration(milliseconds: 1)), 1);
      expect(GuCountdown.secondsLeft(const Duration(microseconds: 1)), 1);
      expect(GuCountdown.secondsLeft(Duration.zero), 0);
      expect(GuCountdown.secondsLeft(const Duration(seconds: -5)), 0);
      expect(GuCountdown.secondsLeft(const Duration(minutes: 1)), 60);
    });
  });
}
