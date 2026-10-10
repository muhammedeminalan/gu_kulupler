// T-09 · UserModel (PLAN §9.6.1): JSON anahtar kümesi ↔ PLAN tablosu,
// Timestamp ↔ UTC DateTime gidiş-dönüşü, tablo varsayılanları, ayrıştırma
// toleransı, copyWith + eşitlik (alan başına) ve türetilmiş getter'lar.
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
  final full = UserModel(
    uid: 'u_ayse',
    name: 'Ayşe Yılmaz',
    nameLower: 'ayşe yılmaz',
    avatarSeed: 'seed-ayse',
    avatarPath: 'users/u_ayse/20261008T201501Z_3f9a1c2b7d4e5f60.jpg',
    department: 'd03',
    year: YearLevel.third,
    interests: const ['i01', 'i05'],
    bio: 'Dağcılık ve fotoğraf.',
    status: UserStatus.suspended,
    suspendReason: 'Topluluk kuralları ihlali',
    staff: true,
    profileComplete: true,
    createdAt: createdAt,
    updatedAt: updatedAt,
    isDeleted: true,
    deletedAt: deletedAt,
    deletedBy: 'u_admin',
  );

  // Yalnızca zorunlu alanlar.
  const minimal = UserModel(
    uid: 'u1',
    name: 'Ali Kaya',
    nameLower: 'ali kaya',
    avatarSeed: 'seed-ali',
  );
  const requiredJson = <String, Object?>{
    FirestoreFields.name: 'Ali Kaya',
    FirestoreFields.nameLower: 'ali kaya',
    FirestoreFields.avatarSeed: 'seed-ali',
  };

  group('T-09 · UserModel · JSON', () {
    test('toJson anahtarları PLAN §9.6.1 tablosuyla aynıdır; belge kimliği '
        've FieldValue yazılmaz', () {
      final json = full.toJson();

      expect(json.keys.toSet(), planJsonKeys('9.6.1'));
      expect(json.values, isNot(contains(full.uid)));
      expect(json.values.whereType<FieldValue>(), isEmpty);
    });

    test('null alanlar toJson çıktısına girmez', () {
      expect(minimal.toJson().keys.toSet(), {
        FirestoreFields.name,
        FirestoreFields.nameLower,
        FirestoreFields.avatarSeed,
        FirestoreFields.interests,
        FirestoreFields.bio,
        FirestoreFields.status,
        FirestoreFields.staff,
        FirestoreFields.profileComplete,
        FirestoreFields.isDeleted,
      });
    });

    test('gidiş-dönüş: zaman alanları Timestamp, enum alanları JSON değeri '
        'olarak yazılır ve aynı model okunur', () {
      final json = full.toJson();

      expect(json[FirestoreFields.createdAt], Timestamp.fromDate(createdAt));
      expect(json[FirestoreFields.updatedAt], Timestamp.fromDate(updatedAt));
      expect(json[FirestoreFields.deletedAt], Timestamp.fromDate(deletedAt));
      expect(json[FirestoreFields.status], 'suspended');
      expect(json[FirestoreFields.year], '3');
      // DateTime eşitliği anı ve isUtc'yi birlikte karşılaştırır: okunan
      // zamanlar UTC'dir.
      expect(UserModel.fromJson(json, id: full.uid), full);
    });

    test('eksik alanlar tablo varsayılanlarını alır; tanınmayan anahtar yok '
        'sayılır', () {
      final model = UserModel.fromJson(const {
        ...requiredJson,
        'bilinmeyenAlan': 1,
      }, id: 'u1');

      expect(model.uid, 'u1');
      expect(model.avatarPath, isNull);
      expect(model.department, isNull);
      expect(model.year, isNull);
      expect(model.interests, isEmpty);
      expect(model.bio, '');
      expect(model.status, UserStatus.active);
      expect(model.suspendReason, isNull);
      expect(model.staff, isFalse);
      expect(model.profileComplete, isFalse);
      expect(model.createdAt, isNull);
      expect(model.updatedAt, isNull);
      expect(model.isDeleted, isFalse);
      expect(model.deletedAt, isNull);
      expect(model.deletedBy, isNull);
      // Adsız yapıcının varsayılanları JSON yapıcısınınkilerle aynıdır.
      expect(model, minimal);
    });

    test('bilinmeyen year null okunur', () {
      final model = UserModel.fromJson(const {
        ...requiredJson,
        FirestoreFields.year: 'mezun',
      }, id: 'u1');

      expect(model.year, isNull);
    });

    test('bilinmeyen status CheckedFromJsonException fırlatır', () {
      expect(
        () => UserModel.fromJson(const {
          ...requiredJson,
          FirestoreFields.status: 'banned',
        }, id: 'u1'),
        throwsA(
          isA<CheckedFromJsonException>().having(
            (e) => e.key,
            'key',
            FirestoreFields.status,
          ),
        ),
      );
    });

    test('zorunlu alan eksikse CheckedFromJsonException alan adını taşır', () {
      for (final key in requiredJson.keys) {
        expect(
          () => UserModel.fromJson(Map.of(requiredJson)..remove(key), id: 'u1'),
          throwsA(
            isA<CheckedFromJsonException>().having((e) => e.key, 'key', key),
          ),
          reason: key,
        );
      }
    });
  });

  group('T-09 · UserModel · copyWith ve eşitlik', () {
    test('parametresiz copyWith aynı modeli verir; props 18 alan taşır', () {
      expect(full.copyWith(), full);
      expect(full.props, hasLength(18));
    });

    test('her alan copyWith ile değişir ve eşitliğe girer', () {
      void check<V>(UserModel changed, V Function(UserModel) read, V value) =>
          expectFieldChange(full, changed, read, value);

      check(full.copyWith(uid: 'u2'), (m) => m.uid, 'u2');
      check(full.copyWith(name: 'Veli'), (m) => m.name, 'Veli');
      check(full.copyWith(nameLower: 'veli'), (m) => m.nameLower, 'veli');
      check(full.copyWith(avatarSeed: 's2'), (m) => m.avatarSeed, 's2');
      check(full.copyWith(avatarPath: 'p2'), (m) => m.avatarPath, 'p2');
      check(full.copyWith(department: 'd24'), (m) => m.department, 'd24');
      check(
        full.copyWith(year: YearLevel.phd),
        (m) => m.year,
        YearLevel.phd,
      );
      check(full.copyWith(interests: ['i16']), (m) => m.interests, ['i16']);
      check(full.copyWith(bio: 'Yeni'), (m) => m.bio, 'Yeni');
      check(
        full.copyWith(status: UserStatus.deleted),
        (m) => m.status,
        UserStatus.deleted,
      );
      check(
        full.copyWith(suspendReason: 'Spam'),
        (m) => m.suspendReason,
        'Spam',
      );
      check(full.copyWith(staff: false), (m) => m.staff, false);
      check(
        full.copyWith(profileComplete: false),
        (m) => m.profileComplete,
        false,
      );
      check(full.copyWith(createdAt: later), (m) => m.createdAt, later);
      check(full.copyWith(updatedAt: later), (m) => m.updatedAt, later);
      check(full.copyWith(isDeleted: false), (m) => m.isDeleted, false);
      check(full.copyWith(deletedAt: later), (m) => m.deletedAt, later);
      check(full.copyWith(deletedBy: 'u9'), (m) => m.deletedBy, 'u9');
    });

    test('clear bayrakları null olabilen alanları boşaltır ve verilen '
        'değerden önce gelir', () {
      void check(UserModel changed, Object? Function(UserModel) read) =>
          expectFieldChange(full, changed, read, null);

      check(full.copyWith(clearAvatarPath: true), (m) => m.avatarPath);
      check(full.copyWith(clearDepartment: true), (m) => m.department);
      check(full.copyWith(clearYear: true), (m) => m.year);
      check(full.copyWith(clearSuspendReason: true), (m) => m.suspendReason);
      check(full.copyWith(clearCreatedAt: true), (m) => m.createdAt);
      check(full.copyWith(clearUpdatedAt: true), (m) => m.updatedAt);
      check(full.copyWith(clearDeletedAt: true), (m) => m.deletedAt);
      check(full.copyWith(clearDeletedBy: true), (m) => m.deletedBy);
      check(
        full.copyWith(avatarPath: 'p2', clearAvatarPath: true),
        (m) => m.avatarPath,
      );
    });
  });

  group('T-09 · UserModel · türetilmiş', () {
    test('isActive: durum active ve belge silinmemiş', () {
      expect(minimal.isActive, isTrue);
      expect(minimal.copyWith(isDeleted: true).isActive, isFalse);
      expect(
        minimal.copyWith(status: UserStatus.suspended).isActive,
        isFalse,
      );
    });

    test('isAnonymized: yalnızca durum deleted iken', () {
      expect(minimal.isAnonymized, isFalse);
      expect(minimal.copyWith(status: UserStatus.deleted).isAnonymized, isTrue);
    });

    test('BaseFields sözleşmesini uygular; createdBy taşımaz', () {
      expect(full, isA<BaseFields>());
      expect(full.createdBy, isNull);
    });
  });
}
