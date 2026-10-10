// T-10 · AppEnvironment: ENV ayrıştırma (release'te emülatör yasağı), emülatör
// adresi/portları ↔ firebase.json, emülatör proje kimliği + sahte API anahtarı,
// SDK bağlaması ve "kurulmadan örnek yok" kuralı (architecture §5, PLAN §10.2;
// Q-01, Q-03, CD-131).
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/core/env/app_environment.dart';
import 'package:gu_kulupler/firebase_options.dart';

import '../../helpers/design_files.dart';

final class _AuthStub implements FirebaseAuth {
  _AuthStub(this.log);

  final List<String> log;

  @override
  Future<void> useAuthEmulator(
    String host,
    int port, {
    bool automaticHostMapping = true,
  }) async => log.add('auth $host:$port');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FirestoreStub implements FirebaseFirestore {
  _FirestoreStub(this.log);

  final List<String> log;
  Settings? applied;

  @override
  set settings(Settings value) {
    applied = value;
    log.add('settings');
  }

  @override
  void useFirestoreEmulator(
    String host,
    int port, {
    bool sslEnabled = false,
    bool automaticHostMapping = true,
  }) => log.add('firestore $host:$port');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _StorageStub implements FirebaseStorage {
  _StorageStub(this.log);

  final List<String> log;

  @override
  Future<void> useStorageEmulator(
    String host,
    int port, {
    bool automaticHostMapping = true,
  }) async => log.add('storage $host:$port');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AppEnv _parse(String rawEnv) =>
    AppEnvironment.parse(rawEnv, rawEmulatorHost: '');

/// Yorum satırları atılmış Dart kaynağı.
String _code(File file) => file
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  group('T-10 · AppEnvironment · ENV ayrıştırma', () {
    test('boş → production (açık seçim yok); tanımlı iki değer', () {
      expect(_parse(''), AppEnv.production);
      expect(_parse('production'), AppEnv.production);
      expect(_parse('emulator'), AppEnv.emulator);
    });

    test('tanınmayan değer hatadır: yazım hatası sessizce gerçek projeye '
        'düşmez', () {
      for (final raw in ['emulatr', 'Emulator', 'prod', ' emulator', 'dev']) {
        expect(() => _parse(raw), throwsArgumentError, reason: raw);
      }
    });

    test('EMULATOR_HOST yalnızca ENV=emulator ile verilir', () {
      const host = '192.168.1.20';
      expect(
        AppEnvironment.parse('emulator', rawEmulatorHost: host),
        AppEnv.emulator,
      );
      expect(
        () => AppEnvironment.parse('', rawEmulatorHost: host),
        throwsArgumentError,
      );
      expect(
        () => AppEnvironment.parse('production', rawEmulatorHost: host),
        throwsArgumentError,
      );
    });

    test('release derlemesi emülatöre bağlanamaz: ENV=emulator StateError '
        "(sessizce production'a düşmez); production etkilenmez", () {
      AppEnv parseRelease(String rawEnv, {String host = ''}) =>
          AppEnvironment.parse(rawEnv, rawEmulatorHost: host, release: true);

      expect(() => parseRelease('emulator'), throwsStateError);
      expect(
        () => parseRelease('emulator', host: '192.168.1.20'),
        throwsStateError,
      );
      expect(parseRelease(''), AppEnv.production);
      expect(parseRelease('production'), AppEnv.production);
      // Release dışı derlemede (test koşusu) emülatör serbesttir.
      expect(_parse('emulator'), AppEnv.emulator);
    });

    test('test koşusunda ENV tanımsız: production, emülatör ve DebugMenu '
        'kapalı', () {
      expect(AppEnvironment.rawEnv, isEmpty);
      expect(AppEnvironment.current, AppEnv.production);
      expect(AppEnvironment.isEmulator, isFalse);
      expect(AppEnvironment.debugMenuEnabled, isFalse);
    });
  });

  group('T-10 · AppEnvironment · emülatör adresi', () {
    test('Android 10.0.2.2, diğer platformlar localhost', () {
      String hostOn(TargetPlatform platform, {bool isWeb = false}) =>
          AppEnvironment.resolveHost(
            override: '',
            platform: platform,
            isWeb: isWeb,
          );

      expect(hostOn(TargetPlatform.android), '10.0.2.2');
      expect(hostOn(TargetPlatform.android, isWeb: true), 'localhost');
      for (final platform in TargetPlatform.values) {
        if (platform == TargetPlatform.android) continue;
        expect(hostOn(platform), 'localhost', reason: platform.name);
      }
    });

    test('EMULATOR_HOST her platformda önceliklidir', () {
      for (final platform in TargetPlatform.values) {
        expect(
          AppEnvironment.resolveHost(
            override: '192.168.1.20',
            platform: platform,
          ),
          '192.168.1.20',
        );
      }
    });

    test('EMULATOR_HOST yalnızca geliştirme ağı adresidir: localhost, .local '
        'adı, özel IPv4 aralıkları', () {
      for (final host in [
        'localhost',
        '127.0.0.1',
        '10.0.2.2',
        '10.200.3.4',
        '172.16.0.5',
        '172.31.255.254',
        '192.168.1.20',
        'macbook-pro.local',
      ]) {
        expect(AppEnvironment.isLocalNetworkHost(host), isTrue, reason: host);
        expect(
          AppEnvironment.resolveHost(
            override: host,
            platform: TargetPlatform.iOS,
          ),
          host,
        );
      }
    });

    test('EMULATOR_HOST genel alan adı / genel IP olamaz; port, şema ya da '
        'boşluk taşıyamaz', () {
      for (final raw in [
        'example.com',
        'emu.example.com',
        '8.8.8.8',
        '172.15.0.1',
        '172.32.0.1',
        '192.169.1.1',
        '11.0.0.1',
        '256.0.0.1',
        '10.evil.com',
        '192.168.1.20.evil.com',
        '127.0.0.1.nip.io',
        'localhost.evil.com',
        'evil.local.com',
        '.local',
        '192.168.1.20:8080',
        'http://192.168.1.20',
        'host name',
        'a/b',
      ]) {
        expect(AppEnvironment.isLocalNetworkHost(raw), isFalse, reason: raw);
        expect(
          () => AppEnvironment.resolveHost(
            override: raw,
            platform: TargetPlatform.iOS,
          ),
          throwsArgumentError,
          reason: raw,
        );
      }
    });
  });

  group('T-10 · AppEnvironment ↔ firebase.json', () {
    test('portlar firebase.json emulators bloğuyla aynı', () {
      final emulators =
          readJsonMap('firebase.json')['emulators'] as Map<String, dynamic>;
      int portOf(String name) =>
          (emulators[name] as Map<String, dynamic>)['port'] as int;

      expect(AppEnvironment.authPort, portOf('auth'));
      expect(AppEnvironment.firestorePort, portOf('firestore'));
      expect(AppEnvironment.storagePort, portOf('storage'));
    });

    test('emülatör proje kimliği demo- önekli, gerçek projeden farklı ve '
        'Rules testleri + seed ile aynı', () {
      final projects =
          readJsonMap('.firebaserc')['projects'] as Map<String, dynamic>;
      final scripts =
          readJsonMap('firebase/package.json')['scripts']
              as Map<String, dynamic>;
      const id = AppEnvironment.emulatorProjectId;

      expect(id, startsWith('demo-'));
      expect(id, isNot(projects['default']));
      expect(scripts['test'], contains('--project $id '));
      expect(readText('firebase/test/setup/env.js'), contains("'$id'"));
      expect(readText('tool/seed/README.md'), contains('--project $id'));
    });

    test('emülatör kovası seed betiğinin varsayılanıyla aynı kalıp', () {
      expect(
        AppEnvironment.emulatorStorageBucket,
        '${AppEnvironment.emulatorProjectId}.firebasestorage.app',
      );
      expect(
        readText('tool/seed/seed_emulator.js'),
        contains(r'`${target.projectId}.firebasestorage.app`'),
      );
    });
  });

  group('T-10 · AppEnvironment · emülatör uygulaması', () {
    test(
      'emulatorOptions proje kimliğini, kovayı ve API anahtarını değiştirir: '
      'gerçek projenin anahtarı emülatör uygulamasına taşınmaz',
      () {
        for (final base in [
          DefaultFirebaseOptions.android,
          DefaultFirebaseOptions.ios,
        ]) {
          final options = AppEnvironment.emulatorOptions(base);

          expect(base.projectId, isNot(AppEnvironment.emulatorProjectId));
          expect(options.projectId, AppEnvironment.emulatorProjectId);
          expect(options.storageBucket, AppEnvironment.emulatorStorageBucket);
          expect(options.apiKey, AppEnvironment.emulatorApiKey);
          expect(options.apiKey, isNot(base.apiKey));
          expect(
            options,
            base.copyWith(
              apiKey: options.apiKey,
              projectId: options.projectId,
              storageBucket: options.storageBucket,
            ),
          );
        }
      },
    );

    test(
      "sahte API anahtarı SDK'ların biçim denetimini geçer (A + 38 karakter, "
      '[A-Za-z0-9_-]) ama gerçek anahtar önekini (AIza) taşımaz',
      () {
        const key = AppEnvironment.emulatorApiKey;

        expect(key, matches(RegExp(r'^A[A-Za-z0-9_-]{38}$')));
        expect(key, isNot(startsWith('AIza')));
        expect(DefaultFirebaseOptions.android.apiKey, startsWith('AIza'));
        expect(DefaultFirebaseOptions.ios.apiKey, startsWith('AIza'));
      },
    );

    test('configure tamamlanmadan servis örneği istenemez: StateError '
        '(varsayılan — gerçek — uygulamaya düşmez)', () {
      expect(() => AppEnvironment.configured, throwsStateError);
      expect(() => AppEnvironment.app, throwsStateError);
      expect(() => AppEnvironment.auth, throwsStateError);
      expect(() => AppEnvironment.firestore, throwsStateError);
      expect(() => AppEnvironment.storage, throwsStateError);
    });

    test(
      'bindEmulators üç SDK örneğini verilen adrese ve sabit portlara bağlar',
      () async {
        final log = <String>[];

        await AppEnvironment.bindEmulators(
          host: 'emu.test',
          auth: _AuthStub(log),
          firestore: _FirestoreStub(log),
          storage: _StorageStub(log),
        );

        expect(log, [
          'auth emu.test:${AppEnvironment.authPort}',
          'firestore emu.test:${AppEnvironment.firestorePort}',
          'storage emu.test:${AppEnvironment.storagePort}',
        ]);
      },
    );

    test('applyFirestoreSettings kalıcı önbelleği 100 MB ile açar (Q-12)', () {
      final firestore = _FirestoreStub(<String>[]);

      AppEnvironment.applyFirestoreSettings(firestore);

      expect(firestore.applied?.persistenceEnabled, isTrue);
      expect(firestore.applied?.cacheSizeBytes, 100 * 1024 * 1024);
      expect(firestore.applied?.host, isNull);
    });

    test('lib/ altında varsayılan uygulamanın Auth/Firestore/Storage örneği '
        'kullanılmaz (yalnızca AppEnvironment.auth/firestore/storage)', () {
      final defaultInstance = RegExp(
        r'\bFirebase(?:Auth|Firestore|Storage)\.instance\b',
      );
      final roots = [
        Directory('$repoRoot/lib'),
        for (final package in Directory('$repoRoot/packages').listSync())
          if (package is Directory) Directory('${package.path}/lib'),
      ];
      final offenders = [
        for (final root in roots)
          if (root.existsSync())
            for (final file in root.listSync(recursive: true))
              if (file is File &&
                  file.path.endsWith('.dart') &&
                  defaultInstance.hasMatch(_code(file)))
                file.path.substring(repoRoot.length + 1),
      ];

      expect(offenders, isEmpty);
      // Tarama kör değil: AppEnvironment örnekleri instanceFor ile kurar.
      expect(
        _code(File('$repoRoot/lib/core/env/app_environment.dart')),
        contains('FirebaseFirestore.instanceFor(app: app)'),
      );
    });
  });
}
