// T-10 · AppLogger: debug/profile → konsol, release → CrashService.log
// (architecture §12, PLAN §4.4). `print`/`debugPrint` yalnızca bu sınıfta.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';

import '../../fakes/fake_crash_service.dart';

final class _ThrowingToString {
  @override
  String toString() => throw StateError('toString patladı');
}

void main() {
  late List<String> console;
  late FakeCrashService crash;

  setUp(() async {
    console = <String>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) => console.add(message ?? '');
    addTearDown(() => debugPrint = original);

    await GetIt.I.reset();
    crash = FakeCrashService();
    GetIt.I.registerSingleton<CrashService>(crash);
    addTearDown(GetIt.I.reset);
  });

  group('T-10 · AppLogger', () {
    test(
      'debug derlemede dört düzey konsola yazar; Crashlytics günlüğüne yazmaz',
      () {
        AppLogger.debug('a');
        AppLogger.info('b');
        AppLogger.warn('c');
        AppLogger.error('d');

        expect(console, ['[D] a', '[I] b', '[W] c', '[E] d']);
        expect(crash.calls, isEmpty);
      },
    );

    test('hata ve yığın konsol satırına eklenir', () {
      final stack = StackTrace.fromString('#0 kaynak');

      AppLogger.error(
        'yazılamadı',
        error: 'permission-denied',
        stackTrace: stack,
      );

      expect(console, ['[E] yazılamadı | permission-denied\n#0 kaynak']);
    });

    test('release: info/warn/error CrashService.log ile yazılır; debug düzeyi '
        've konsol yazılmaz; hata raporu üretilmez', () {
      for (final level in AppLogLevel.values) {
        AppLogger.write(level, level.name, error: 'e', release: true);
      }

      expect(crash.logs, ['[I] info | e', '[W] warn | e', '[E] error | e']);
      expect(crash.recorded, isEmpty);
      expect(console, isEmpty);
    });

    test(
      'release: CrashService kayıtlı değilken satır sessizce düşer',
      () async {
        await GetIt.I.reset();

        expect(
          () => AppLogger.write(AppLogLevel.error, 'x', release: true),
          returnsNormally,
        );
        expect(console, isEmpty);
      },
    );

    test('hiçbir koşulda fırlatmaz (biçimlenemeyen hata nesnesi)', () {
      expect(
        () => AppLogger.warn('x', error: _ThrowingToString()),
        returnsNormally,
      );
      expect(
        () => AppLogger.write(
          AppLogLevel.warn,
          'x',
          error: _ThrowingToString(),
          release: true,
        ),
        returnsNormally,
      );
      expect(console, isEmpty);
      expect(crash.logs, isEmpty);
    });
  });
}
