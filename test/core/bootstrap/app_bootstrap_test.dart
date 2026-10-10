// T-11 · AppBootstrap: açılış sırası (PLAN §4.4) ve Crashlytics toplama
// anahtarı (W-53). `run` platform başlatması yaptığından sıra kaynak
// üzerinden doğrulanır.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/core/bootstrap/app_bootstrap.dart';

import '../../helpers/design_files.dart';

void main() {
  group('T-11 · AppBootstrap · açılış sırası', () {
    test('adımlar PLAN §4.4 sırasıyla çağrılır', () {
      final source = readText('lib/core/bootstrap/app_bootstrap.dart');
      final body = source.substring(source.indexOf('static Future<void> run('));
      const steps = [
        'WidgetsFlutterBinding.ensureInitialized();',
        'AppErrorHandler.install();',
        // Dikey yön kilidi (Q-13) — platform dosyalarının çalışma zamanı eşi.
        'await SystemChrome.setPreferredOrientations(const [',
        'await Firebase.initializeApp(',
        'await AppEnvironment.configure();',
        "await initializeDateFormatting('tr_TR');",
        "await initializeDateFormatting('en_GB');",
        'await configureCrashlytics();',
        'await ProjectDependency.setup(',
        'await GetIt.I<AppPreferencesStore>().load();',
        'runApp(ProviderScope(',
      ];
      var cursor = -1;
      for (final step in steps) {
        final index = body.indexOf(step);
        expect(index, isNot(-1), reason: 'adım yok: $step');
        expect(index, greaterThan(cursor), reason: 'sıra bozuk: $step');
        cursor = index;
      }
    });

    test('ortam kurulumunun hatası yakalanmaz (yarım kurulumla devam '
        'edilmez — W-53)', () {
      final source = readText('lib/core/bootstrap/app_bootstrap.dart');
      final start = source.indexOf('static Future<void> run(');
      final run = source.substring(
        start,
        source.indexOf('runApp(ProviderScope(', start),
      );
      expect(run, isNot(contains('try')));
      expect(run, isNot(contains('catch')));
    });

    test('main: bağlama ve runApp aynı bölgede, bölge hataları '
        "AppErrorHandler'a", () {
      final source = readText('lib/main.dart');
      expect(source, contains('runZonedGuarded('));
      expect(source, contains('AppBootstrap.run('));
      expect(source, contains('AppErrorHandler.onZoneError'));
      expect(source, isNot(contains('WidgetsFlutterBinding')));
    });
  });

  group('T-11 · AppBootstrap · Crashlytics toplama', () {
    setUp(() {
      final original = debugPrint;
      debugPrint = (message, {wrapWidth}) {};
      addTearDown(() => debugPrint = original);
    });

    test('debug derlemede (test koşusu) toplama kapalıdır', () {
      expect(AppBootstrap.crashCollectionEnabled, isFalse);
    });

    test('toplama anahtarı emülatör ortamını ve debug derlemeyi dışlar', () {
      final source = readText('lib/core/bootstrap/app_bootstrap.dart');
      expect(
        source.replaceAll(RegExp(r'\s+'), ' '),
        contains(
          'static const bool crashCollectionEnabled = '
          '!kDebugMode && !AppEnvironment.isEmulator;',
        ),
      );
    });

    test('configureCrashlytics anahtarı uygular', () async {
      final applied = <bool>[];
      await AppBootstrap.configureCrashlytics(
        apply: ({required enabled}) async => applied.add(enabled),
      );
      await AppBootstrap.configureCrashlytics(
        apply: ({required enabled}) async => applied.add(enabled),
        enabled: true,
      );
      expect(applied, [false, true]);
    });

    test('ayar yazılamazsa açılış durmaz', () async {
      await expectLater(
        AppBootstrap.configureCrashlytics(
          apply: ({required enabled}) async => throw StateError('SDK yok'),
        ),
        completes,
      );
    });

    test('varsayılan uygulayıcı SDK yokken (test) fırlatmaz', () async {
      await expectLater(AppBootstrap.configureCrashlytics(), completes);
    });
  });
}
