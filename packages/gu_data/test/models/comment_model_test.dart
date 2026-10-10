// T-09 · CommentModel (PLAN §9.6.8, §9.10, §9.11): alan adları, JSON
// anahtarları ve varsayılanlar PLAN tablosundan OKUNARAK; gidiş-dönüş
// (Timestamp ↔ UTC DateTime), eksik alan toleransı, copyWith + eşitlik.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:json_annotation/json_annotation.dart';

import '../helpers/plan_feed_schema.dart';

const String _table = '#### 9.6.8 ';

final DateTime _created = DateTime.utc(2026, 10, 1, 9, 30, 0, 123);

/// Her alanı dolu (varsayılanından farklı) yorum.
final CommentModel _full = CommentModel(
  id: 'cm07',
  postId: 'p18',
  clubId: 'c06',
  authorId: 'u_mehmet',
  text: 'Rock olsun!',
  isHidden: true,
  hiddenBy: 'u_admin',
  hiddenAt: _created.add(const Duration(days: 1)),
  createdAt: _created,
  updatedAt: _created.add(const Duration(hours: 2)),
  isDeleted: true,
  deletedAt: _created.add(const Duration(days: 2)),
  deletedBy: 'u_zeynep',
);

/// Yalnızca zorunlu alanları taşıyan belge verisi.
const Map<String, Object?> _minimalJson = {
  FirestoreFields.postId: 'p18',
  FirestoreFields.clubId: 'c06',
  FirestoreFields.authorId: 'u_mehmet',
  FirestoreFields.text: 'Rock olsun!',
};

/// Modelin tüm alanları, PLAN tablosundaki sırayla (alan adı → değer).
Map<String, Object?> _fields(CommentModel m) => {
  'id': m.id,
  'postId': m.postId,
  'clubId': m.clubId,
  'authorId': m.authorId,
  'text': m.text,
  'isHidden': m.isHidden,
  'hiddenBy': m.hiddenBy,
  'hiddenAt': m.hiddenAt,
  'createdAt': m.createdAt,
  'updatedAt': m.updatedAt,
  'isDeleted': m.isDeleted,
  'deletedAt': m.deletedAt,
  'deletedBy': m.deletedBy,
};

void _changes(CommentModel changed, String field, Object? value) =>
    expectSingleFieldChange(
      base: _full,
      changed: changed,
      fields: _fields,
      field: field,
      value: value,
    );

void main() {
  group('T-09 · CommentModel · şema', () {
    test('alan adları PLAN §9.6.8 tablosuyla birebir, props hepsini taşır', () {
      expect(_fields(_full).keys, planFieldNames(_table));
      expect(_full.props, _fields(_full).values);
    });

    test('toJson anahtarları PLAN tablosunun JSON sütunuyla aynı', () {
      // Tablo belge kimliğini JSON'a yazmaz: küme eşitliği `id` anahtarının
      // bulunmadığını da doğrular.
      expect(_full.toJson().keys.toSet(), planJsonKeys(_table));
    });
  });

  group('T-09 · CommentModel · fromJson / toJson', () {
    test('gidiş-dönüş modeli korur; zamanlar Timestamp ↔ UTC DateTime', () {
      final json = _full.toJson();
      final back = CommentModel.fromJson(json, id: _full.id);

      expect(back, _full);
      for (final key in [
        FirestoreFields.hiddenAt,
        FirestoreFields.createdAt,
        FirestoreFields.updatedAt,
        FirestoreFields.deletedAt,
      ]) {
        expect(json[key], isA<Timestamp>(), reason: key);
      }
      expect(
        [
          back.hiddenAt,
          back.createdAt,
          back.updatedAt,
          back.deletedAt,
        ].map((at) => at!.isUtc),
        everyElement(isTrue),
      );
    });

    test('eksik anahtarlar PLAN tablosundaki varsayılanları alır', () {
      final model = CommentModel.fromJson(const {
        ..._minimalJson,
        'bilinmeyen': 1,
      }, id: 'cm07');
      final defaults = planDefaults(_table);
      final fields = _fields(model);

      expect({
        for (final field in defaults.keys) field: planLiteral(fields[field]),
      }, defaults);
      expect(
        model,
        const CommentModel(
          id: 'cm07',
          postId: 'p18',
          clubId: 'c06',
          authorId: 'u_mehmet',
          text: 'Rock olsun!',
        ),
        reason: 'eksik anahtar = kurucu varsayılanı',
      );
      expect(model.isLive, isTrue);
      expect(model.createdBy, isNull);
    });

    test('eksik zorunlu alan CheckedFromJsonException', () {
      for (final key in _minimalJson.keys) {
        expect(
          () => CommentModel.fromJson(
            {..._minimalJson}..remove(key),
            id: 'cm07',
          ),
          throwsA(
            isA<CheckedFromJsonException>().having((e) => e.key, 'key', key),
          ),
        );
      }
    });
  });

  group('T-09 · CommentModel · copyWith / eşitlik', () {
    final later = DateTime.utc(2027);

    test('parametresiz copyWith aynı modeli verir', () {
      expect(_full.copyWith(), _full);
    });

    test('her alan tek başına değişir ve eşitliği bozar', () {
      _changes(_full.copyWith(id: 'cm99'), 'id', 'cm99');
      _changes(_full.copyWith(postId: 'p99'), 'postId', 'p99');
      _changes(_full.copyWith(clubId: 'c99'), 'clubId', 'c99');
      _changes(_full.copyWith(authorId: 'u99'), 'authorId', 'u99');
      _changes(_full.copyWith(text: 'Yeni'), 'text', 'Yeni');
      _changes(_full.copyWith(isHidden: false), 'isHidden', false);
      _changes(_full.copyWith(hiddenBy: 'u99'), 'hiddenBy', 'u99');
      _changes(_full.copyWith(hiddenAt: later), 'hiddenAt', later);
      _changes(_full.copyWith(createdAt: later), 'createdAt', later);
      _changes(_full.copyWith(updatedAt: later), 'updatedAt', later);
      _changes(_full.copyWith(isDeleted: false), 'isDeleted', false);
      _changes(_full.copyWith(deletedAt: later), 'deletedAt', later);
      _changes(_full.copyWith(deletedBy: 'u99'), 'deletedBy', 'u99');
    });

    test('null olabilen her alan clear bayrağıyla null olur', () {
      _changes(_full.copyWith(clearHiddenBy: true), 'hiddenBy', null);
      _changes(_full.copyWith(clearHiddenAt: true), 'hiddenAt', null);
      _changes(_full.copyWith(clearCreatedAt: true), 'createdAt', null);
      _changes(_full.copyWith(clearUpdatedAt: true), 'updatedAt', null);
      _changes(_full.copyWith(clearDeletedAt: true), 'deletedAt', null);
      _changes(_full.copyWith(clearDeletedBy: true), 'deletedBy', null);
    });
  });
}
