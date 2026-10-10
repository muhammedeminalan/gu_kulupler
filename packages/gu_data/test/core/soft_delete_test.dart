// T-08 · SoftDelete: silme ve geri alma yükleri, affectedKeys ve belge
// paritesi (PLAN §9.2, §10.3; soft-delete.md §3; D-10).
//
// Bu dosyada FakeFirebaseFirestore KURULMAZ (bkz. base_fields_test.dart);
// yüklerin belgeye yazımı `payload_write_test.dart` içinde sınanır.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../helpers/repo_sources.dart';

final Matcher _isServerTimestamp = equals(FieldValue.serverTimestamp());

/// Rules taslağında `function <name>(…) { … }` gövdesi (bir sonraki
/// `function` satırına kadar).
String _rulesFunction(String name) {
  final lines = readRepoFile('docs/firestore-rules-spec.md').split('\n');
  final start = lines.indexWhere(
    (line) => line.trimLeft().startsWith('function $name('),
  );
  if (start < 0) throw StateError('Rules fonksiyonu yok: $name');
  final next = lines.indexWhere(
    (line) =>
        line.trimLeft().startsWith('function ') ||
        line.trimLeft().startsWith('//'),
    start + 1,
  );
  return lines.sublist(start, next).join('\n');
}

/// Metindeki tek tırnaklı dizgiler.
Set<String> _quoted(String text) => {
  for (final match in RegExp("'([^']*)'").allMatches(text)) match.group(1)!,
};

void main() {
  group('T-08 · SoftDelete.payload', () {
    test(
      'dört anahtar, sırayla: isDeleted, deletedAt, deletedBy, updatedAt',
      () {
        expect(SoftDelete.payload(actorId: 'u_ayse').keys.toList(), [
          'isDeleted',
          'deletedAt',
          'deletedBy',
          'updatedAt',
        ]);
      },
    );

    test('isDeleted true', () {
      expect(SoftDelete.payload(actorId: 'u_ayse')['isDeleted'], isTrue);
    });

    test("deletedBy silen kullanıcının uid'idir", () {
      expect(SoftDelete.payload(actorId: 'u_ayse')['deletedBy'], 'u_ayse');
      expect(SoftDelete.payload(actorId: 'u_p_c01')['deletedBy'], 'u_p_c01');
    });

    test('deletedAt ve updatedAt sunucu zaman damgası nöbetçisidir', () {
      final payload = SoftDelete.payload(actorId: 'u_ayse');

      expect(payload['deletedAt'], isA<FieldValue>());
      expect(payload['deletedAt'], _isServerTimestamp);
      expect(payload['updatedAt'], isA<FieldValue>());
      expect(payload['updatedAt'], _isServerTimestamp);
    });

    test('zaman damgası istemci saati (DateTime / Timestamp) değildir', () {
      final payload = SoftDelete.payload(actorId: 'u_ayse');

      for (final key in ['deletedAt', 'updatedAt']) {
        expect(payload[key], isNot(isA<DateTime>()), reason: key);
        expect(payload[key], isNot(isA<Timestamp>()), reason: key);
      }
    });

    test('createdAt ve createdBy alanlarına dokunmaz', () {
      final payload = SoftDelete.payload(actorId: 'u_ayse');

      expect(payload.containsKey('createdAt'), isFalse);
      expect(payload.containsKey('createdBy'), isFalse);
    });

    test('boş actorId reddedilir', () {
      expect(
        () => SoftDelete.payload(actorId: ''),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'actorId')),
      );
    });

    test('her çağrı yeni bir map döner; bir yük diğerini etkilemez', () {
      final first = SoftDelete.payload(actorId: 'u1');
      final second = SoftDelete.payload(actorId: 'u2');

      expect(identical(first, second), isFalse);
      first['deletedBy'] = 'değişti';
      expect(second['deletedBy'], 'u2');
      expect(SoftDelete.payload(actorId: 'u1')['deletedBy'], 'u1');
    });
  });

  group('T-08 · SoftDelete.restorePayload', () {
    test(
      'dört anahtar, sırayla: isDeleted, deletedAt, deletedBy, updatedAt',
      () {
        expect(SoftDelete.restorePayload().keys.toList(), [
          'isDeleted',
          'deletedAt',
          'deletedBy',
          'updatedAt',
        ]);
      },
    );

    test('isDeleted false', () {
      expect(SoftDelete.restorePayload()['isDeleted'], isFalse);
    });

    test('deletedAt ve deletedBy açıkça null yazılır (alan kaldırılmaz)', () {
      final payload = SoftDelete.restorePayload();

      expect(payload.containsKey('deletedAt'), isTrue);
      expect(payload['deletedAt'], isNull);
      expect(payload.containsKey('deletedBy'), isTrue);
      expect(payload['deletedBy'], isNull);
    });

    test('yükteki tek FieldValue updatedAt sunucu zaman damgasıdır', () {
      final payload = SoftDelete.restorePayload();
      final sentinels = {
        for (final entry in payload.entries)
          if (entry.value is FieldValue) entry.key,
      };

      expect(sentinels, {'updatedAt'});
      expect(payload['updatedAt'], _isServerTimestamp);
    });

    test('her çağrı yeni bir map döner', () {
      expect(
        identical(SoftDelete.restorePayload(), SoftDelete.restorePayload()),
        isFalse,
      );
    });
  });

  group('T-08 · SoftDelete · silme ↔ geri alma', () {
    test('iki yük aynı anahtar kümesine dokunur', () {
      expect(
        SoftDelete.payload(actorId: 'u1').keys.toSet(),
        SoftDelete.restorePayload().keys.toSet(),
      );
    });

    test('geri alma, silmenin yazdığı her alanı tersine çevirir', () {
      final document = <String, Object?>{
        'text': 'gönderi',
        ...BaseFieldsPayload.create(),
      };

      final deleted = {...document, ...SoftDelete.payload(actorId: 'u1')};
      expect(deleted['isDeleted'], isTrue);
      expect(deleted['deletedBy'], 'u1');
      expect(deleted['deletedAt'], _isServerTimestamp);

      final restored = {...deleted, ...SoftDelete.restorePayload()};
      expect(restored['isDeleted'], isFalse);
      expect(restored['deletedBy'], isNull);
      expect(restored['deletedAt'], isNull);
      expect(restored['text'], 'gönderi');
      expect(restored.keys.toSet(), document.keys.toSet());
    });

    test('geri alınan belge, yeni oluşturulan belgeyle aynı ortak alanlara '
        'sahiptir', () {
      final created = BaseFieldsPayload.create();
      final restored = {
        ...created,
        ...SoftDelete.payload(actorId: 'u1'),
        ...SoftDelete.restorePayload(),
      };

      expect(restored, created);
    });
  });

  group('T-08 · SoftDelete.affectedKeys', () {
    test('dört anahtar: isDeleted, deletedAt, deletedBy, updatedAt', () {
      expect(SoftDelete.affectedKeys, {
        'isDeleted',
        'deletedAt',
        'deletedBy',
        'updatedAt',
      });
      expect(SoftDelete.affectedKeys, hasLength(4));
    });

    test('derleme zamanı sabiti ve değiştirilemez', () {
      const keys = SoftDelete.affectedKeys;

      expect(identical(keys, SoftDelete.affectedKeys), isTrue);
      expect(() => keys.add('status'), throwsUnsupportedError);
    });

    test('silme yükünün anahtarlarıyla birebir', () {
      expect(
        SoftDelete.payload(actorId: 'u1').keys.toSet(),
        SoftDelete.affectedKeys,
      );
    });

    test('geri alma yükünün anahtarlarıyla birebir', () {
      expect(
        SoftDelete.restorePayload().keys.toSet(),
        SoftDelete.affectedKeys,
      );
    });

    test('anahtarlar FirestoreFields sabitleridir', () {
      expect(SoftDelete.affectedKeys, {
        FirestoreFields.isDeleted,
        FirestoreFields.deletedAt,
        FirestoreFields.deletedBy,
        FirestoreFields.updatedAt,
      });
    });

    test('iş alanı içermez (status, createdAt, createdBy)', () {
      for (final key in ['status', 'createdAt', 'createdBy', 'text']) {
        expect(SoftDelete.affectedKeys, isNot(contains(key)));
      }
    });
  });

  group('T-08 · SoftDelete · belge paritesi', () {
    test("soft-delete.md §3 affectedKeys literal'i ile birebir", () {
      final line = readRepoFile('docs/soft-delete.md')
          .split('\n')
          .singleWhere(
            (line) => line.contains('static const Set<String> affectedKeys'),
          );

      expect(_quoted(line), SoftDelete.affectedKeys);
    });

    test('PLAN §9.2 ve §10.3 affectedKeys listeleri ile birebir', () {
      final matches = RegExp(
        r'`affectedKeys = \{([^}]*)\}`',
      ).allMatches(readRepoFile('docs/PLAN.md')).toList();

      expect(matches, hasLength(2), reason: '§9.2 ve §10.3');
      for (final match in matches) {
        final names = {
          for (final word in RegExp(r'\w+').allMatches(match.group(1)!))
            word.group(0)!,
        };
        expect(names, SoftDelete.affectedKeys);
      }
    });

    test('Rules isSoftDelete izinli alanları = affectedKeys', () {
      final softDelete = _rulesFunction('isSoftDelete');
      final touches = _rulesFunction('touches');
      final allowed = {
        ..._quoted(
          RegExp(r'touches\(\[([^\]]*)\]').firstMatch(softDelete)!.group(1)!,
        ),
        ..._quoted(
          RegExp(r'keys\.concat\(\[([^\]]*)\]').firstMatch(touches)!.group(1)!,
        ),
      };

      expect(allowed, SoftDelete.affectedKeys);
    });

    test('Rules isRestore izinli alanları = affectedKeys', () {
      final restore = _rulesFunction('isRestore');
      final touches = _rulesFunction('touches');
      final allowed = {
        ..._quoted(
          RegExp(r'touches\(\[([^\]]*)\]').firstMatch(restore)!.group(1)!,
        ),
        ..._quoted(
          RegExp(r'keys\.concat\(\[([^\]]*)\]').firstMatch(touches)!.group(1)!,
        ),
      };

      expect(allowed, SoftDelete.affectedKeys);
    });

    test(
      'Rules isSoftDelete: deletedBy istek sahibi, deletedAt sunucu zamanı',
      () {
        final rule = _rulesFunction('isSoftDelete');

        expect(rule, contains('request.resource.data.isDeleted == true'));
        expect(rule, contains('request.resource.data.deletedBy == uid()'));
        expect(
          rule,
          contains('request.resource.data.deletedAt == request.time'),
        );
      },
    );

    test('Rules isRestore: deletedAt ve deletedBy null bekler', () {
      final rule = _rulesFunction('isRestore');

      expect(rule, contains('request.resource.data.isDeleted == false'));
      expect(rule, contains('request.resource.data.deletedAt == null'));
      expect(rule, contains('request.resource.data.deletedBy == null'));
    });
  });

  group('T-08 · SoftDelete · hard delete yok (D-10)', () {
    final source = readRepoFile(
      'packages/gu_data/lib/src/core/soft_delete.dart',
    );

    test('FieldValue yalnızca sunucu zamanı için kullanılır', () {
      final uses = RegExp(
        r'FieldValue\.(\w+)\(',
      ).allMatches(source).map((match) => match.group(1)).toSet();

      expect(uses, {'serverTimestamp'});
    });

    test('delete adlı üye ya da çağrı yok', () {
      expect(RegExp(r'\bdelete\w*\s*\(').hasMatch(source), isFalse);
    });

    test('public üyeler yalnızca payload, restorePayload, affectedKeys', () {
      final members = [
        for (final match in RegExp(
          r'^ {2}static (?:const )?[\w<>?, ]+ (\w+)[ (=]',
          multiLine: true,
        ).allMatches(source))
          match.group(1),
      ];

      expect(members, ['payload', 'restorePayload', 'affectedKeys']);
    });
  });
}
