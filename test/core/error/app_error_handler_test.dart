// T-11 · AppErrorHandler: üç hata kaynağı → CrashService (D-23).

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/error/app_error_handler.dart';
import 'package:gu_kulupler/core/error/error_boundary.dart';

import '../../fakes/fake_crash_service.dart';

/// Raporlaması patlayan servis: işleyici bunu da yutmalıdır.
final class _ThrowingCrashService implements CrashService {
  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? reason,
  }) => throw StateError('rapor patladı');

  @override
  void log(String message) => throw StateError('günlük patladı');

  @override
  Future<void> setUserId(String? uid) async {}

  @override
  Future<void> setCollectionEnabled(bool enabled) async {}
}

void main() {
  late FakeCrashService crash;
  late List<String> console;

  setUp(() async {
    await GetIt.I.reset();
    addTearDown(GetIt.I.reset);
    crash = FakeCrashService();
    GetIt.I.registerSingleton<CrashService>(crash);
    console = <String>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) => console.add(message ?? '');
    addTearDown(() => debugPrint = original);
  });

  group('T-11 · AppErrorHandler · install', () {
    test('üç kancayı kurar: FlutterError.onError, PlatformDispatcher.onError, '
        'ErrorWidget.builder', () {
      final flutterOnError = FlutterError.onError;
      final platformOnError = PlatformDispatcher.instance.onError;
      final errorWidgetBuilder = ErrorWidget.builder;
      addTearDown(() {
        FlutterError.onError = flutterOnError;
        PlatformDispatcher.instance.onError = platformOnError;
        ErrorWidget.builder = errorWidgetBuilder;
      });

      AppErrorHandler.install();

      expect(FlutterError.onError, AppErrorHandler.onFlutterError);
      expect(
        PlatformDispatcher.instance.onError,
        AppErrorHandler.onPlatformError,
      );
      expect(ErrorWidget.builder, ErrorBoundary.builder);
    });
  });

  group('T-11 · AppErrorHandler · kayıt', () {
    test('çerçeve hatası raporlanır: ölümcül değil, bağlam notuyla', () async {
      final error = StateError('build patladı');
      final stack = StackTrace.current;
      AppErrorHandler.onFlutterError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'widgets library',
          context: ErrorDescription('building Foo'),
          silent: true,
        ),
      );
      await pumpEventQueue();

      expect(crash.recorded, [(error, stack)]);
      expect(crash.fatals, [false]);
      expect(crash.reasons, ['widgets library: building Foo']);
    });

    test('bağlamsız çerçeve hatasında not yalnızca kitaplık adıdır', () async {
      AppErrorHandler.onFlutterError(
        FlutterErrorDetails(exception: StateError('x'), silent: true),
      );
      AppErrorHandler.onFlutterError(
        FlutterErrorDetails(
          exception: StateError('y'),
          library: null,
          silent: true,
        ),
      );
      await pumpEventQueue();
      expect(crash.reasons, ['Flutter framework', 'flutter']);
    });

    test('bölge dışı zaman uyumsuz hata: ölümcül raporlanır ve işlendi '
        '(true) döner', () async {
      final error = StateError('async');
      final stack = StackTrace.current;
      expect(AppErrorHandler.onPlatformError(error, stack), isTrue);
      await pumpEventQueue();

      expect(crash.recorded, [(error, stack)]);
      expect(crash.fatals, [true]);
      expect(crash.reasons, ['PlatformDispatcher.onError']);
    });

    test('bölge hatası (runZonedGuarded): ölümcül raporlanır', () async {
      final error = StateError('zone');
      final stack = StackTrace.current;
      AppErrorHandler.onZoneError(error, stack);
      await pumpEventQueue();

      expect(crash.recorded, [(error, stack)]);
      expect(crash.fatals, [true]);
      expect(crash.reasons, ['runZonedGuarded']);
    });

    test("sessiz olmayan çerçeve hatası debug'da Flutter dökümüyle yazılır; "
        'aynı hata ikinci kez günlüğe düşmez ama raporlanır', () async {
      final error = StateError('görünür');
      AppErrorHandler.onFlutterError(FlutterErrorDetails(exception: error));
      await pumpEventQueue();

      expect(console, isNotEmpty);
      expect(console.where((line) => line.startsWith('[E]')), isEmpty);
      expect(console.join('\n'), contains('görünür'));
      expect(crash.recorded.single.$1, error);
      // Döküm sayacı sonraki testleri kısaltmasın.
      FlutterError.resetErrorCount();
    });

    test('sessiz çerçeve hatası dökülmez; tek satır günlüğe yazılır', () {
      AppErrorHandler.onFlutterError(
        FlutterErrorDetails(exception: StateError('sessiz'), silent: true),
      );
      expect(console.single, startsWith('[E] Flutter framework'));
    });

    test('her hata konsola da yazılır (debug derleme)', () {
      AppErrorHandler.onZoneError(StateError('zone'), StackTrace.empty);
      expect(console.single, startsWith('[E] runZonedGuarded'));
    });

    test('CrashService henüz kayıtlı değilken (DI öncesi) fırlatmaz', () async {
      await GetIt.I.reset();
      expect(
        () =>
            AppErrorHandler.onZoneError(StateError('erken'), StackTrace.empty),
        returnsNormally,
      );
      expect(
        AppErrorHandler.onPlatformError(StateError('erken'), StackTrace.empty),
        isTrue,
      );
      expect(crash.recorded, isEmpty);
    });

    test('raporlamanın kendisi patlarsa işleyici fırlatmaz', () async {
      await GetIt.I.reset();
      GetIt.I.registerSingleton<CrashService>(_ThrowingCrashService());
      expect(
        () => AppErrorHandler.onZoneError(StateError('x'), StackTrace.empty),
        returnsNormally,
      );
      expect(
        () => AppErrorHandler.onFlutterError(
          FlutterErrorDetails(exception: StateError('y'), silent: true),
        ),
        returnsNormally,
      );
    });

    test('kurulu kancalar üzerinden gelen hata da kayda düşer', () async {
      final flutterOnError = FlutterError.onError;
      final platformOnError = PlatformDispatcher.instance.onError;
      final errorWidgetBuilder = ErrorWidget.builder;
      addTearDown(() {
        FlutterError.onError = flutterOnError;
        PlatformDispatcher.instance.onError = platformOnError;
        ErrorWidget.builder = errorWidgetBuilder;
      });
      AppErrorHandler.install();

      final error = StateError('kanca');
      FlutterError.onError!(
        FlutterErrorDetails(exception: error, silent: true),
      );
      PlatformDispatcher.instance.onError!(error, StackTrace.empty);
      await pumpEventQueue();

      expect(crash.recorded.map((r) => r.$1), [error, error]);
      expect(crash.fatals, [false, true]);
    });
  });
}
