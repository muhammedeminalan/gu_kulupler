// T-09 · VoteModel (PLAN §9.6.7, §9.10, §9.11): alan adları, JSON
// anahtarları ve varsayılanlar PLAN tablosundan OKUNARAK; gidiş-dönüş
// (Timestamp ↔ UTC DateTime), eksik alan toleransı, copyWith + eşitlik.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:json_annotation/json_annotation.dart';

import '../helpers/plan_feed_schema.dart';

const String _table = '#### 9.6.7 ';

final DateTime _created = DateTime.utc(2026, 9, 30, 6, 0, 0, 123);

final VoteModel _full = VoteModel(
  uid: 'u_ayse',
  optionId: 'o2',
  createdAt: _created,
);

/// Modelin tüm alanları, PLAN tablosundaki sırayla (alan adı → değer).
Map<String, Object?> _fields(VoteModel m) => {
  'uid': m.uid,
  'optionId': m.optionId,
  'createdAt': m.createdAt,
};

void _changes(VoteModel changed, String field, Object? value) =>
    expectSingleFieldChange(
      base: _full,
      changed: changed,
      fields: _fields,
      field: field,
      value: value,
    );

void main() {
  group('T-09 · VoteModel · şema', () {
    test('alan adları PLAN §9.6.7 tablosuyla birebir, props hepsini taşır', () {
      expect(_fields(_full).keys, planFieldNames(_table));
      expect(_full.props, _fields(_full).values);
    });

    test('toJson anahtarları PLAN tablosunun JSON sütunuyla aynı', () {
      // Belge kimliği (uid) JSON'a yazılmaz; ortak alanlardan yalnızca
      // createdAt vardır (oy silinemez: isDeleted yok).
      expect(_full.toJson().keys.toSet(), planJsonKeys(_table));
      expect(_full, isNot(isA<BaseFields>()));
    });
  });

  group('T-09 · VoteModel · fromJson / toJson', () {
    test('gidiş-dönüş modeli korur; createdAt Timestamp ↔ UTC DateTime', () {
      final json = _full.toJson();
      final back = VoteModel.fromJson(json, id: _full.uid);

      expect(back, _full);
      expect(json[FirestoreFields.createdAt], Timestamp.fromDate(_created));
      expect(back.createdAt!.isUtc, isTrue);
    });

    test('eksik anahtarlar PLAN tablosundaki varsayılanları alır', () {
      final model = VoteModel.fromJson(const {
        FirestoreFields.optionId: 'o1',
        'bilinmeyen': 1,
      }, id: 'u_ayse');
      final defaults = planDefaults(_table);
      final fields = _fields(model);

      expect({
        for (final field in defaults.keys) field: planLiteral(fields[field]),
      }, defaults);
      expect(model, const VoteModel(uid: 'u_ayse', optionId: 'o1'));
    });

    test('optionId eksikse CheckedFromJsonException', () {
      expect(
        () => VoteModel.fromJson(const {}, id: 'u_ayse'),
        throwsA(
          isA<CheckedFromJsonException>().having(
            (e) => e.key,
            'key',
            FirestoreFields.optionId,
          ),
        ),
      );
    });
  });

  group('T-09 · VoteModel · copyWith / eşitlik', () {
    test('parametresiz copyWith aynı modeli verir', () {
      expect(_full.copyWith(), _full);
    });

    test('her alan tek başına değişir ve eşitliği bozar', () {
      final later = DateTime.utc(2027);

      _changes(_full.copyWith(uid: 'u99'), 'uid', 'u99');
      _changes(_full.copyWith(optionId: 'o4'), 'optionId', 'o4');
      _changes(_full.copyWith(createdAt: later), 'createdAt', later);
      _changes(_full.copyWith(clearCreatedAt: true), 'createdAt', null);
    });
  });
}
