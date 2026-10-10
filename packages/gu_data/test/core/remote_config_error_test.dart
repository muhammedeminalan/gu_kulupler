// T-10 · RemoteConfigError: üye listesi, hata kodu eşlemesi ve PLAN paritesi
// (PLAN §4.2, §10.1).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../helpers/repo_sources.dart';

void main() {
  group('T-10 · RemoteConfigError', () {
    test('4 üye, PLAN §4.2 ağaç satırındaki sırayla', () {
      final line = readRepoFile('docs/PLAN.md')
          .split('\n')
          .singleWhere((line) => line.contains('── remote_config_error.dart'));
      final planned = RegExp(
        r'enum RemoteConfigError \(([^)]+)\)',
      ).firstMatch(line)!.group(1)!.split(',').map((name) => name.trim());

      expect([for (final e in RemoteConfigError.values) e.name], planned);
      expect(RemoteConfigError.values, hasLength(4));
    });

    test('fromCode: SDK kodları (yerel + web) sözlüğe çevrilir', () {
      const codes = {
        'throttled': RemoteConfigError.fetchThrottled,
        'fetch-throttle': RemoteConfigError.fetchThrottled,
        'network-error': RemoteConfigError.network,
        'fetch-client-network': RemoteConfigError.network,
        'fetch-timeout': RemoteConfigError.timeout,
        'cancelled': RemoteConfigError.unknown,
        'forbidden': RemoteConfigError.unknown,
        'remote-config-server-error': RemoteConfigError.unknown,
        'internal': RemoteConfigError.unknown,
        'unknown': RemoteConfigError.unknown,
      };

      for (final MapEntry(key: code, value: expected) in codes.entries) {
        expect(RemoteConfigError.fromCode(code), expected, reason: code);
      }
      expect(codes.values.toSet(), RemoteConfigError.values.toSet());
    });

    test('fromCode: eşleşme birebirdir; tanınmayan her değer unknown', () {
      for (final code in ['', 'THROTTLED', ' throttled', 'throttled ', 'x']) {
        expect(
          RemoteConfigError.fromCode(code),
          RemoteConfigError.unknown,
          reason: '"$code"',
        );
      }
    });

    test('RemoteConfigResult<T> = FirebaseResult<T, RemoteConfigError>', () {
      const RemoteConfigResult<bool> result = FirebaseFailure(
        RemoteConfigError.network,
      );

      expect(result, isA<FirebaseResult<bool, RemoteConfigError>>());
      expect(result, isNot(isA<FirebaseResult<bool, FirestoreError>>()));
      expect(result.errorOrNull, RemoteConfigError.network);
    });
  });
}
