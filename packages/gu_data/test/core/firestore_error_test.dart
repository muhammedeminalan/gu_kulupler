// T-08 · FirestoreError / FirestoreRuleCode: üye listeleri, hata kodu eşleme
// tablosu ve PLAN paritesi (PLAN §4.2, §10.1).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../helpers/plan_error_tables.dart';

/// PLAN §4.2 ağaç satırındaki sırayla 16 üye.
const List<String> _members = [
  'permissionDenied',
  'unauthenticated',
  'notFound',
  'alreadyExists',
  'aborted',
  'unavailable',
  'invalidArgument',
  'failedPrecondition',
  'resourceExhausted',
  'cancelled',
  'unknown',
  'timeout',
  'parse',
  'offline',
  'conflict',
  'ruleViolation',
];

/// `FirebaseException.code` → beklenen üye. Firestore'un (gRPC) 16 durum
/// kodunun tamamı; PLAN §10.1 tablosunun SDK satırları.
const Map<String, FirestoreError> _sdkCodes = {
  'permission-denied': FirestoreError.permissionDenied,
  'unauthenticated': FirestoreError.unauthenticated,
  'not-found': FirestoreError.notFound,
  'already-exists': FirestoreError.alreadyExists,
  'aborted': FirestoreError.aborted,
  'unavailable': FirestoreError.unavailable,
  'deadline-exceeded': FirestoreError.unavailable,
  'invalid-argument': FirestoreError.invalidArgument,
  'failed-precondition': FirestoreError.failedPrecondition,
  'resource-exhausted': FirestoreError.resourceExhausted,
  'cancelled': FirestoreError.cancelled,
  'data-loss': FirestoreError.unknown,
  'internal': FirestoreError.unknown,
  'unimplemented': FirestoreError.unknown,
  'out-of-range': FirestoreError.unknown,
  'unknown': FirestoreError.unknown,
};

/// SDK'nın üretmediği, yalnızca uygulama kodunun kurduğu üyeler.
const Set<FirestoreError> _appOnly = {
  FirestoreError.timeout,
  FirestoreError.parse,
  FirestoreError.offline,
  FirestoreError.conflict,
  FirestoreError.ruleViolation,
};

/// PLAN §10.1 `ruleViolation` satırındaki sırayla 12 üye.
const List<String> _ruleCodes = [
  'applicationsClosed',
  'retryCooldown',
  'reapplyNeedsReview',
  'capacityFull',
  'registrationClosed',
  'eventEnded',
  'announcementLimit',
  'presidentCannotLeave',
  'presidentCannotBeRemoved',
  'eventHasRegistrations',
  'attendanceWindowClosed',
  'notMember',
];

void main() {
  group('T-08 · FirestoreError · üyeler', () {
    test('16 üye, PLAN sırasıyla', () {
      expect([for (final e in FirestoreError.values) e.name], _members);
      expect(FirestoreError.values, hasLength(16));
    });

    test('her üye ya SDK eşlemesinde ya da uygulama kümesinde (ayrık)', () {
      final fromSdk = _sdkCodes.values.toSet();

      expect(fromSdk.intersection(_appOnly), isEmpty);
      expect({...fromSdk, ..._appOnly}, FirestoreError.values.toSet());
    });
  });

  group('T-08 · FirestoreError.fromCode · tablo', () {
    _sdkCodes.forEach((code, expected) {
      test('$code → ${expected.name}', () {
        expect(FirestoreError.fromCode(code), expected);
      });
    });

    test('deadline-exceeded ayrı üye değil, unavailable', () {
      expect(
        FirestoreError.fromCode('deadline-exceeded'),
        FirestoreError.fromCode('unavailable'),
      );
    });

    test('aborted unavailable ile birleştirilmez (ayrı üye)', () {
      expect(
        FirestoreError.fromCode('aborted'),
        isNot(FirestoreError.fromCode('unavailable')),
      );
    });

    test('failed-precondition invalid-argument ile birleştirilmez', () {
      expect(
        FirestoreError.fromCode('failed-precondition'),
        isNot(FirestoreError.fromCode('invalid-argument')),
      );
    });
  });

  group('T-08 · FirestoreError.fromCode · eşleşmeyen', () {
    for (final code in const [
      '',
      ' ',
      'x',
      'permission_denied',
      'permissionDenied',
      'PERMISSION-DENIED',
      'Permission-Denied',
      'PERMISSION_DENIED',
      ' permission-denied',
      'permission-denied ',
      'permission-denied\n',
      'cloud_firestore/permission-denied',
      '[cloud_firestore/permission-denied]',
      'notFound',
      'not found',
      'canceled',
      'object-not-found',
      'network-request-failed',
    ]) {
      test('"${code.replaceAll('\n', r'\n')}" → unknown', () {
        expect(FirestoreError.fromCode(code), FirestoreError.unknown);
      });
    }

    test('uygulama üyelerinin adları SDK kodu sayılmaz', () {
      for (final code in const [
        'timeout',
        'parse',
        'offline',
        'conflict',
        'ruleViolation',
        'rule-violation',
      ]) {
        expect(
          FirestoreError.fromCode(code),
          FirestoreError.unknown,
          reason: code,
        );
      }
    });

    test('fromCode hiçbir girdide uygulama üyesi döndürmez', () {
      final candidates = [
        ..._sdkCodes.keys,
        for (final error in FirestoreError.values) error.name,
        for (final code in _ruleCodes) code,
      ];

      for (final code in candidates) {
        expect(_appOnly, isNot(contains(FirestoreError.fromCode(code))));
      }
    });
  });

  group('T-08 · FirestoreError · PLAN paritesi', () {
    test('§10.1 tablosundaki her SDK kodu aynı üyeye eşlenir', () {
      final plan = readPlanErrorTable('FirestoreError');

      expect(plan.sdkCodes, isNotEmpty);
      plan.sdkCodes.forEach((code, member) {
        expect(FirestoreError.fromCode(code).name, member, reason: code);
      });
    });

    test('§10.1 tablosundaki SDK kodları = testteki tablo', () {
      final plan = readPlanErrorTable('FirestoreError');

      expect(plan.sdkCodes, {
        for (final entry in _sdkCodes.entries) entry.key: entry.value.name,
      });
    });

    test('§10.1 "eşleşmeyen" satırı unknown', () {
      expect(readPlanErrorTable('FirestoreError').fallbackMember, 'unknown');
    });

    test('§10.1 SDK dışı satırlar = uygulama üyeleri (sırayla)', () {
      expect(readPlanErrorTable('FirestoreError').appMembers, [
        'timeout',
        'parse',
        'offline',
        'conflict',
        'ruleViolation',
      ]);
    });

    test('§10.1 tablosunda adı geçen üyeler = enum üyeleri', () {
      expect(readPlanErrorTable('FirestoreError').members, {
        for (final error in FirestoreError.values) error.name,
      });
    });

    test('§4.2 ağaç satırı: 16 üye, aynı ad ve sıra', () {
      final tree = readPlanTreeEnum(
        file: 'firestore_error.dart',
        enumName: 'FirestoreError',
      );

      expect(tree.count, 16);
      expect(tree.members, [for (final e in FirestoreError.values) e.name]);
    });
  });

  group('T-08 · FirestoreRuleCode', () {
    test('12 üye, PLAN sırasıyla', () {
      expect([for (final c in FirestoreRuleCode.values) c.name], _ruleCodes);
      expect(FirestoreRuleCode.values, hasLength(12));
    });

    test('PLAN §10.1 ruleViolation satırındaki liste ile birebir', () {
      expect(readPlanRuleCodes(), [
        for (final code in FirestoreRuleCode.values) code.name,
      ]);
    });

    test('PLAN §4.2 ağaç satırı: 12 üye, aynı ad ve sıra', () {
      final tree = readPlanTreeEnum(
        file: 'firestore_error.dart',
        enumName: 'FirestoreRuleCode',
      );

      expect(tree.count, 12);
      expect(tree.members, [for (final c in FirestoreRuleCode.values) c.name]);
    });

    test('iş kuralı kodları FirestoreError üye adlarıyla çakışmaz', () {
      expect(
        {for (final c in FirestoreRuleCode.values) c.name}.intersection({
          for (final e in FirestoreError.values) e.name,
        }),
        isEmpty,
      );
    });
  });
}
