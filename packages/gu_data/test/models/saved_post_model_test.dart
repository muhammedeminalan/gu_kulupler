// T-09 · SavedPostModel (PLAN §9.6.16, §9.10, §9.11): alan adları, JSON
// anahtarları ve varsayılanlar PLAN tablosundan OKUNARAK; türetilen belge
// kimliği, gidiş-dönüş (Timestamp ↔ UTC DateTime), eksik alan toleransı,
// copyWith + eşitlik.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:json_annotation/json_annotation.dart';

import '../helpers/plan_feed_schema.dart';

const String _table = '#### 9.6.16 ';

final DateTime _saved = DateTime.utc(2026, 10, 5, 18, 45, 0, 123);

/// Her alanı dolu (varsayılanından farklı) kayıt; belge kimliği açıkça verilir.
final SavedPostModel _full = SavedPostModel(
  id: 'eski-kimlik',
  userId: 'u_mehmet',
  postId: 'p21',
  clubId: 'c03',
  savedAt: _saved,
  createdAt: _saved.add(const Duration(seconds: 1)),
  updatedAt: _saved.add(const Duration(hours: 2)),
  isDeleted: true,
  deletedAt: _saved.add(const Duration(days: 1)),
  deletedBy: 'u_mehmet',
);

/// Yalnızca zorunlu alanları taşıyan belge verisi.
const Map<String, Object?> _minimalJson = {
  FirestoreFields.userId: 'u_mehmet',
  FirestoreFields.postId: 'p21',
  FirestoreFields.clubId: 'c03',
};

/// Modelin tüm alanları, PLAN tablosundaki sırayla (alan adı → değer).
Map<String, Object?> _fields(SavedPostModel m) => {
  'id': m.id,
  'userId': m.userId,
  'postId': m.postId,
  'clubId': m.clubId,
  'savedAt': m.savedAt,
  'createdAt': m.createdAt,
  'updatedAt': m.updatedAt,
  'isDeleted': m.isDeleted,
  'deletedAt': m.deletedAt,
  'deletedBy': m.deletedBy,
};

void _changes(SavedPostModel changed, String field, Object? value) =>
    expectSingleFieldChange(
      base: _full,
      changed: changed,
      fields: _fields,
      field: field,
      value: value,
    );

void main() {
  group('T-09 · SavedPostModel · şema', () {
    test(
      'alan adları PLAN §9.6.16 tablosuyla birebir, props hepsini taşır',
      () {
        expect(_fields(_full).keys, planFieldNames(_table));
        expect(_full.props, _fields(_full).values);
      },
    );

    test('toJson anahtarları PLAN tablosunun JSON sütunuyla aynı', () {
      // Tablo belge kimliğini JSON'a yazmaz: küme eşitliği `id` anahtarının
      // bulunmadığını da doğrular.
      expect(_full.toJson().keys.toSet(), planJsonKeys(_table));
    });
  });

  group('T-09 · SavedPostModel · belge kimliği', () {
    const derived = SavedPostModel(
      userId: 'u_mehmet',
      postId: 'p21',
      clubId: 'c03',
    );

    test('verilmezse PLAN tablosundaki üreticiyle türetilir', () {
      expect(
        planDefaults(_table)['id'],
        'FirestoreIds.savedPost(userId, postId)',
      );
      expect(derived.id, FirestoreIds.savedPost('u_mehmet', 'p21'));
    });

    test('türetilen kimlik copyWith ile alanları izler', () {
      expect(
        derived.copyWith(postId: 'p01').id,
        FirestoreIds.savedPost('u_mehmet', 'p01'),
      );
    });
  });

  group('T-09 · SavedPostModel · fromJson / toJson', () {
    test('gidiş-dönüş modeli korur; zamanlar Timestamp ↔ UTC DateTime', () {
      final json = _full.toJson();
      final back = SavedPostModel.fromJson(json, id: _full.id);

      expect(back, _full);
      for (final key in [
        FirestoreFields.savedAt,
        FirestoreFields.createdAt,
        FirestoreFields.updatedAt,
        FirestoreFields.deletedAt,
      ]) {
        expect(json[key], isA<Timestamp>(), reason: key);
      }
      expect(
        [
          back.savedAt,
          back.createdAt,
          back.updatedAt,
          back.deletedAt,
        ].map((at) => at!.isUtc),
        everyElement(isTrue),
      );
    });

    test('eksik anahtarlar PLAN tablosundaki varsayılanları alır', () {
      final model = SavedPostModel.fromJson(const {
        ..._minimalJson,
        'bilinmeyen': 1,
      }, id: 'u_mehmet_p21');
      final defaults = planDefaults(_table)..remove('id');
      final fields = _fields(model);

      expect({
        for (final field in defaults.keys) field: planLiteral(fields[field]),
      }, defaults);
      expect(
        model,
        const SavedPostModel(userId: 'u_mehmet', postId: 'p21', clubId: 'c03'),
        reason: 'eksik anahtar = kurucu varsayılanı',
      );
      expect(model.isLive, isTrue);
      expect(model.createdBy, isNull);
    });

    test('eksik zorunlu alan CheckedFromJsonException', () {
      for (final key in _minimalJson.keys) {
        expect(
          () => SavedPostModel.fromJson(
            {..._minimalJson}..remove(key),
            id: 'u_mehmet_p21',
          ),
          throwsA(
            isA<CheckedFromJsonException>().having((e) => e.key, 'key', key),
          ),
        );
      }
    });
  });

  group('T-09 · SavedPostModel · copyWith / eşitlik', () {
    final later = DateTime.utc(2027);

    test('parametresiz copyWith aynı modeli verir', () {
      expect(_full.copyWith(), _full);
    });

    test('her alan tek başına değişir ve eşitliği bozar', () {
      _changes(_full.copyWith(id: 'yeni-kimlik'), 'id', 'yeni-kimlik');
      _changes(_full.copyWith(userId: 'u99'), 'userId', 'u99');
      _changes(_full.copyWith(postId: 'p99'), 'postId', 'p99');
      _changes(_full.copyWith(clubId: 'c99'), 'clubId', 'c99');
      _changes(_full.copyWith(savedAt: later), 'savedAt', later);
      _changes(_full.copyWith(createdAt: later), 'createdAt', later);
      _changes(_full.copyWith(updatedAt: later), 'updatedAt', later);
      _changes(_full.copyWith(isDeleted: false), 'isDeleted', false);
      _changes(_full.copyWith(deletedAt: later), 'deletedAt', later);
      _changes(_full.copyWith(deletedBy: 'u99'), 'deletedBy', 'u99');
    });

    test('null olabilen her alan clear bayrağıyla null olur', () {
      _changes(_full.copyWith(clearSavedAt: true), 'savedAt', null);
      _changes(_full.copyWith(clearCreatedAt: true), 'createdAt', null);
      _changes(_full.copyWith(clearUpdatedAt: true), 'updatedAt', null);
      _changes(_full.copyWith(clearDeletedAt: true), 'deletedAt', null);
      _changes(_full.copyWith(clearDeletedBy: true), 'deletedBy', null);
    });
  });
}
