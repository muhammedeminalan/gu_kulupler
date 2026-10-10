// T-09 · BlockModel (PLAN §9.6.15): belge kimliği varsayılanı, JSON anahtar
// kümesi ↔ PLAN tablosu, Timestamp ↔ UTC DateTime gidiş-dönüşü, tablo
// varsayılanları, ayrıştırma toleransı, copyWith + eşitlik (alan başına).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:json_annotation/json_annotation.dart';

import '../helpers/plan_model_keys_user_group.dart';

void main() {
  final createdAt = DateTime.utc(2026, 9, 1, 8, 30, 15, 123);
  final updatedAt = DateTime.utc(2026, 10, 8, 20, 15, 1, 456);
  final deletedAt = DateTime.utc(2026, 10, 9, 6, 0, 0, 789);
  final later = DateTime.utc(2027, 1, 2, 3, 4, 5, 6);

  // Her alan varsayılanından farklı, null olabilen her alan dolu.
  final full = BlockModel(
    id: 'blk-1',
    blockerId: 'u_mehmet',
    blockedId: 'u042',
    createdAt: createdAt,
    updatedAt: updatedAt,
    isDeleted: true,
    deletedAt: deletedAt,
    deletedBy: 'u_mehmet',
  );

  // Yalnızca zorunlu alanlar.
  const minimal = BlockModel(blockerId: 'u_mehmet', blockedId: 'u042');
  const requiredJson = <String, Object?>{
    FirestoreFields.blockerId: 'u_mehmet',
    FirestoreFields.blockedId: 'u042',
  };

  group('T-09 · BlockModel · belge kimliği', () {
    test('verilmezse FirestoreIds.block(blockerId, blockedId) olur', () {
      expect(minimal.id, FirestoreIds.block('u_mehmet', 'u042'));
    });

    test('fromJson verilen kimliği kullanır', () {
      expect(BlockModel.fromJson(requiredJson, id: 'blk-9').id, 'blk-9');
    });
  });

  group('T-09 · BlockModel · JSON', () {
    test('toJson anahtarları PLAN §9.6.15 tablosuyla aynıdır; belge kimliği '
        've FieldValue yazılmaz', () {
      final json = full.toJson();

      expect(json.keys.toSet(), planJsonKeys('9.6.15'));
      expect(json.values, isNot(contains(full.id)));
      expect(json.values.whereType<FieldValue>(), isEmpty);
    });

    test('null alanlar toJson çıktısına girmez', () {
      expect(minimal.toJson().keys.toSet(), {
        FirestoreFields.blockerId,
        FirestoreFields.blockedId,
        FirestoreFields.isDeleted,
      });
    });

    test('gidiş-dönüş: zaman alanları Timestamp olarak yazılır ve aynı model '
        'okunur', () {
      final json = full.toJson();

      expect(json[FirestoreFields.createdAt], Timestamp.fromDate(createdAt));
      expect(json[FirestoreFields.updatedAt], Timestamp.fromDate(updatedAt));
      expect(json[FirestoreFields.deletedAt], Timestamp.fromDate(deletedAt));
      // DateTime eşitliği anı ve isUtc'yi birlikte karşılaştırır: okunan
      // zamanlar UTC'dir.
      expect(BlockModel.fromJson(json, id: full.id), full);
    });

    test('eksik alanlar tablo varsayılanlarını alır; tanınmayan anahtar yok '
        'sayılır', () {
      final model = BlockModel.fromJson(const {
        ...requiredJson,
        'bilinmeyenAlan': 1,
      }, id: minimal.id);

      expect(model.createdAt, isNull);
      expect(model.updatedAt, isNull);
      expect(model.isDeleted, isFalse);
      expect(model.deletedAt, isNull);
      expect(model.deletedBy, isNull);
      expect(model, minimal);
    });

    test('zorunlu alan eksikse CheckedFromJsonException alan adını taşır', () {
      for (final key in requiredJson.keys) {
        expect(
          () => BlockModel.fromJson(
            Map.of(requiredJson)..remove(key),
            id: 'blk-1',
          ),
          throwsA(
            isA<CheckedFromJsonException>().having((e) => e.key, 'key', key),
          ),
          reason: key,
        );
      }
    });
  });

  group('T-09 · BlockModel · copyWith ve eşitlik', () {
    test('parametresiz copyWith aynı modeli verir; props 8 alan taşır', () {
      expect(full.copyWith(), full);
      expect(full.props, hasLength(8));
    });

    test('her alan copyWith ile değişir ve eşitliğe girer', () {
      void check<V>(BlockModel changed, V Function(BlockModel) read, V value) =>
          expectFieldChange(full, changed, read, value);

      check(full.copyWith(id: 'blk-2'), (m) => m.id, 'blk-2');
      check(full.copyWith(blockerId: 'u1'), (m) => m.blockerId, 'u1');
      check(full.copyWith(blockedId: 'u2'), (m) => m.blockedId, 'u2');
      check(full.copyWith(createdAt: later), (m) => m.createdAt, later);
      check(full.copyWith(updatedAt: later), (m) => m.updatedAt, later);
      check(full.copyWith(isDeleted: false), (m) => m.isDeleted, false);
      check(full.copyWith(deletedAt: later), (m) => m.deletedAt, later);
      check(full.copyWith(deletedBy: 'u9'), (m) => m.deletedBy, 'u9');
    });

    test('türetilen kimlik kopyada alanları izler; açıkça verilen kimlik '
        'korunur', () {
      expect(
        minimal.copyWith(blockedId: 'u2').id,
        FirestoreIds.block('u_mehmet', 'u2'),
      );
      expect(full.copyWith(blockedId: 'u2').id, 'blk-1');
    });

    test('clear bayrakları null olabilen alanları boşaltır ve verilen '
        'değerden önce gelir', () {
      void check(BlockModel changed, Object? Function(BlockModel) read) =>
          expectFieldChange(full, changed, read, null);

      check(full.copyWith(clearCreatedAt: true), (m) => m.createdAt);
      check(full.copyWith(clearUpdatedAt: true), (m) => m.updatedAt);
      check(full.copyWith(clearDeletedAt: true), (m) => m.deletedAt);
      check(full.copyWith(clearDeletedBy: true), (m) => m.deletedBy);
      check(
        full.copyWith(deletedBy: 'u9', clearDeletedBy: true),
        (m) => m.deletedBy,
      );
    });

    test('BaseFields sözleşmesini uygular; createdBy taşımaz', () {
      expect(full, isA<BaseFields>());
      expect(full.createdBy, isNull);
    });
  });
}
