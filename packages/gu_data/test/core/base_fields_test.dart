// T-08 · BaseFields / BaseFieldsPayload: ortak alan sözleşmesi ve yazma
// yükleri — anahtarlar, değerler, sunucu zaman damgası (PLAN §9.2, §10.3;
// soft-delete.md §2; D-26).
//
// Bu dosyada FakeFirebaseFirestore KURULMAZ: sahte veritabanı FieldValue
// fabrikasını değiştirir ve nöbetçi değerlerin eşitliği anlamını yitirir.
// Yüklerin gerçekten yazılabildiği `payload_write_test.dart` içinde sınanır.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../helpers/repo_sources.dart';

/// Mixin'i uygulayan en küçük belge.
final class _Doc with BaseFields {
  const _Doc({
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.isDeleted = false,
    this.deletedAt,
    this.deletedBy,
  });

  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;
  @override
  final String? createdBy;
  @override
  final bool isDeleted;
  @override
  final DateTime? deletedAt;
  @override
  final String? deletedBy;
}

/// `createdBy` taşımayan model biçimi (PLAN §9.2: yalnızca kulüp ve etkinlik
/// bildirir): getter `null` döner.
final class _DocWithoutCreator with BaseFields {
  const _DocWithoutCreator();

  @override
  DateTime? get createdAt => null;
  @override
  DateTime? get updatedAt => null;
  @override
  String? get createdBy => null;
  @override
  bool get isDeleted => false;
  @override
  DateTime? get deletedAt => null;
  @override
  String? get deletedBy => null;
}

final Matcher _isServerTimestamp = equals(FieldValue.serverTimestamp());

void main() {
  group('T-08 · BaseFields · mixin', () {
    test('altı ortak alanı getter olarak sunar', () {
      final created = DateTime.utc(2026, 10, 1, 8);
      final updated = DateTime.utc(2026, 10, 2, 9);
      final deleted = DateTime.utc(2026, 10, 3, 10);
      final BaseFields doc = _Doc(
        createdAt: created,
        updatedAt: updated,
        createdBy: 'u_admin',
        isDeleted: true,
        deletedAt: deleted,
        deletedBy: 'u_mod',
      );

      expect(doc.createdAt, created);
      expect(doc.updatedAt, updated);
      expect(doc.createdBy, 'u_admin');
      expect(doc.isDeleted, isTrue);
      expect(doc.deletedAt, deleted);
      expect(doc.deletedBy, 'u_mod');
    });

    test('isLive: silinmemiş belge canlıdır', () {
      expect(const _Doc().isLive, isTrue);
    });

    test('isLive: silinmiş belge canlı değildir', () {
      expect(const _Doc(isDeleted: true).isLive, isFalse);
    });

    test('isLive yalnızca isDeleted bayrağına bakar (deletedAt tek başına '
        'silinmiş saymaz)', () {
      expect(
        _Doc(deletedAt: DateTime.utc(2026), deletedBy: 'u1').isLive,
        isTrue,
      );
    });

    test('bekleyen yazım: zaman alanları null olabilir, belge yine canlı', () {
      const BaseFields doc = _Doc();

      expect(doc.createdAt, isNull);
      expect(doc.updatedAt, isNull);
      expect(doc.deletedAt, isNull);
      expect(doc.isLive, isTrue);
    });

    test("createdBy taşımayan model getter'ı null döner", () {
      const BaseFields doc = _DocWithoutCreator();

      expect(doc.createdBy, isNull);
      expect(doc.isLive, isTrue);
    });
  });

  group('T-08 · BaseFieldsPayload.create', () {
    test('beş anahtar, sırayla: createdAt, updatedAt, isDeleted, deletedAt, '
        'deletedBy', () {
      expect(BaseFieldsPayload.create().keys.toList(), [
        'createdAt',
        'updatedAt',
        'isDeleted',
        'deletedAt',
        'deletedBy',
      ]);
    });

    test('createdAt ve updatedAt sunucu zaman damgası nöbetçisidir', () {
      final payload = BaseFieldsPayload.create();

      expect(payload['createdAt'], isA<FieldValue>());
      expect(payload['createdAt'], _isServerTimestamp);
      expect(payload['updatedAt'], isA<FieldValue>());
      expect(payload['updatedAt'], _isServerTimestamp);
    });

    test('zaman damgası istemci saati (DateTime / Timestamp) değildir', () {
      final payload = BaseFieldsPayload.create();

      for (final key in ['createdAt', 'updatedAt']) {
        expect(payload[key], isNot(isA<DateTime>()), reason: key);
        expect(payload[key], isNot(isA<Timestamp>()), reason: key);
        expect(payload[key], isNot(FieldValue.increment(1)), reason: key);
      }
    });

    test('isDeleted false; deletedAt ve deletedBy açıkça null', () {
      final payload = BaseFieldsPayload.create();

      expect(payload['isDeleted'], isFalse);
      expect(payload.containsKey('deletedAt'), isTrue);
      expect(payload['deletedAt'], isNull);
      expect(payload.containsKey('deletedBy'), isTrue);
      expect(payload['deletedBy'], isNull);
    });

    test('createdBy verilmezse anahtar yüke girmez', () {
      expect(BaseFieldsPayload.create().containsKey('createdBy'), isFalse);
      // Açık null da "verilmedi" demektir.
      // ignore: avoid_redundant_argument_values
      expect(BaseFieldsPayload.create(createdBy: null).keys, hasLength(5));
    });

    test('createdBy verilirse altıncı anahtar olarak eklenir', () {
      final payload = BaseFieldsPayload.create(createdBy: 'u_admin');

      expect(payload.keys.toList(), [
        'createdAt',
        'updatedAt',
        'isDeleted',
        'deletedAt',
        'deletedBy',
        'createdBy',
      ]);
      expect(payload['createdBy'], 'u_admin');
    });

    test('createdBy diğer alanları değiştirmez', () {
      final withCreator = BaseFieldsPayload.create(createdBy: 'u_admin')
        ..remove('createdBy');

      expect(withCreator, BaseFieldsPayload.create());
    });

    test('boş createdBy reddedilir', () {
      expect(
        () => BaseFieldsPayload.create(createdBy: ''),
        throwsA(
          isA<ArgumentError>().having((e) => e.name, 'name', 'createdBy'),
        ),
      );
    });

    test('her çağrı yeni, değiştirilebilir bir map döner', () {
      final first = BaseFieldsPayload.create();
      final second = BaseFieldsPayload.create();

      expect(identical(first, second), isFalse);
      first['isDeleted'] = true;
      expect(second['isDeleted'], isFalse);
      expect(BaseFieldsPayload.create()['isDeleted'], isFalse);
    });

    test("model JSON'ı ile birleşince ortak alanları ezer", () {
      final modelJson = <String, Object?>{
        'name': 'Fotoğrafçılık Kulübü',
        'createdAt': Timestamp(1, 0),
        'updatedAt': Timestamp(2, 0),
        'isDeleted': true,
        'deletedAt': Timestamp(3, 0),
        'deletedBy': 'u_eski',
      };

      final merged = {...modelJson, ...BaseFieldsPayload.create()};

      expect(merged['name'], 'Fotoğrafçılık Kulübü');
      expect(merged['createdAt'], _isServerTimestamp);
      expect(merged['updatedAt'], _isServerTimestamp);
      expect(merged['isDeleted'], isFalse);
      expect(merged['deletedAt'], isNull);
      expect(merged['deletedBy'], isNull);
    });
  });

  group('T-08 · BaseFieldsPayload.update', () {
    test('yalnızca updatedAt: sunucu zaman damgası', () {
      final payload = BaseFieldsPayload.update();

      expect(payload.keys.toList(), ['updatedAt']);
      expect(payload['updatedAt'], _isServerTimestamp);
    });

    test('createdAt, isDeleted ve silme alanlarına dokunmaz', () {
      final payload = BaseFieldsPayload.update();

      for (final key in [
        'createdAt',
        'createdBy',
        'isDeleted',
        'deletedAt',
        'deletedBy',
      ]) {
        expect(payload.containsKey(key), isFalse, reason: key);
      }
    });

    test('her çağrı yeni bir map döner', () {
      expect(
        identical(BaseFieldsPayload.update(), BaseFieldsPayload.update()),
        isFalse,
      );
    });

    test('yama ile birleşince yalnızca updatedAt eklenir', () {
      final merged = {
        'bio': 'yeni',
        ...BaseFieldsPayload.update(),
      };

      expect(merged.keys.toList(), ['bio', 'updatedAt']);
      expect(merged['bio'], 'yeni');
    });
  });

  group('T-08 · BaseFieldsPayload · alan adı paritesi', () {
    test('anahtarlar FirestoreFields sabitleridir', () {
      expect(BaseFieldsPayload.create(createdBy: 'u1').keys.toSet(), {
        FirestoreFields.createdAt,
        FirestoreFields.updatedAt,
        FirestoreFields.isDeleted,
        FirestoreFields.deletedAt,
        FirestoreFields.deletedBy,
        FirestoreFields.createdBy,
      });
      expect(BaseFieldsPayload.update().keys.single, FirestoreFields.updatedAt);
    });

    test('PLAN §9.2 tablosundaki altı JSON anahtarı ile birebir', () {
      final table = markdownTable(
        readRepoFile('docs/PLAN.md'),
        heading: '### 9.2 ',
      );
      final jsonKeys = [
        for (final row in table.rows) codeSpans(row[1]).single,
      ];

      expect(jsonKeys, [
        'createdAt',
        'updatedAt',
        'createdBy',
        'isDeleted',
        'deletedAt',
        'deletedBy',
      ]);
      expect(
        BaseFieldsPayload.create(createdBy: 'u1').keys.toSet(),
        jsonKeys.toSet(),
      );
    });

    test('Rules baseCreate() create yükünün beş alanını denetler', () {
      final lines = readRepoFile('docs/firestore-rules-spec.md').split('\n');
      final start = lines.indexWhere(
        (line) => line.trimLeft().startsWith('function baseCreate()'),
      );
      final end = lines.indexWhere(
        (line) => line.trimLeft().startsWith('function '),
        start + 1,
      );
      final body = lines.sublist(start, end).join('\n');
      final checked = {
        for (final match in RegExp(
          r"request\.resource\.data\.(?:get\('(\w+)'|(\w+))",
        ).allMatches(body))
          match.group(1) ?? match.group(2)!,
      };

      expect(checked, BaseFieldsPayload.create().keys.toSet());
      expect(body, contains('createdAt == request.time'));
      expect(body, contains('updatedAt == request.time'));
      expect(body, contains('isDeleted == false'));
    });
  });

  test("T-08 · base_fields.dart FieldValue'yu yalnızca sunucu zamanı için "
      'kullanır', () {
    final source = readRepoFile(
      'packages/gu_data/lib/src/core/base_fields.dart',
    );
    final uses = RegExp(
      r'FieldValue\.(\w+)\(',
    ).allMatches(source).map((match) => match.group(1)).toSet();

    expect(uses, {'serverTimestamp'});
  });
}
