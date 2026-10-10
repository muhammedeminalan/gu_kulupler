// T-09 · UserAccountModel + gömülü FcmTokenModel (PLAN §9.6.2): JSON anahtar
// kümeleri ↔ PLAN, iç içe nesne (explicit_to_json), Timestamp ↔ UTC DateTime
// gidiş-dönüşü, tablo varsayılanları, ayrıştırma toleransı, copyWith +
// eşitlik (alan başına).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:json_annotation/json_annotation.dart';

import '../helpers/plan_model_keys_user_group.dart';

void main() {
  final tokenAt = DateTime.utc(2026, 10, 7, 12, 0, 0, 250);
  final lastLoginAt = DateTime.utc(2026, 10, 8, 19, 45, 30, 500);
  final createdAt = DateTime.utc(2026, 9, 1, 8, 30, 15, 123);
  final updatedAt = DateTime.utc(2026, 10, 8, 20, 15, 1, 456);
  final deletedAt = DateTime.utc(2026, 10, 9, 6, 0, 0, 789);
  final later = DateTime.utc(2027, 1, 2, 3, 4, 5, 6);

  final token = FcmTokenModel(
    token: 'fcm-token-1',
    platform: 'ios',
    updatedAt: tokenAt,
  );

  // Her alan varsayılanından farklı, null olabilen her alan dolu.
  final full = UserAccountModel(
    email: 'Ayse.Yilmaz@ogr.gumushane.edu.tr',
    emailLower: 'ayse.yilmaz@ogr.gumushane.edu.tr',
    fcmTokens: [token],
    lastLoginAt: lastLoginAt,
    createdAt: createdAt,
    updatedAt: updatedAt,
    isDeleted: true,
    deletedAt: deletedAt,
    deletedBy: 'u_ayse',
  );

  // Yalnızca zorunlu alanlar.
  const minimal = UserAccountModel(
    email: 'ali@gumushane.edu.tr',
    emailLower: 'ali@gumushane.edu.tr',
  );
  const requiredJson = <String, Object?>{
    FirestoreFields.email: 'ali@gumushane.edu.tr',
    FirestoreFields.emailLower: 'ali@gumushane.edu.tr',
  };

  group('T-09 · UserAccountModel · JSON', () {
    test('toJson anahtarları PLAN §9.6.2 tablosuyla aynıdır; FieldValue '
        'yazılmaz', () {
      final json = full.toJson();

      expect(json.keys.toSet(), planJsonKeys('9.6.2'));
      expect(json.values.whereType<FieldValue>(), isEmpty);
    });

    test('fcmTokens elemanları map olarak yazılır; anahtarları PLAN '
        'FcmTokenModel tanımıyla aynıdır', () {
      final tokens = full.toJson()[FirestoreFields.fcmTokens]! as List<Object?>;

      expect(tokens, hasLength(1));
      expect(
        (tokens.single! as Map<String, Object?>).keys.toSet(),
        planEmbeddedKeys('FcmTokenModel'),
      );
    });

    test('null alanlar toJson çıktısına girmez', () {
      expect(minimal.toJson().keys.toSet(), {
        FirestoreFields.email,
        FirestoreFields.emailLower,
        FirestoreFields.fcmTokens,
        FirestoreFields.isDeleted,
      });
    });

    test('gidiş-dönüş: zaman alanları Timestamp olarak yazılır ve aynı model '
        'okunur', () {
      final json = full.toJson();

      expect(
        json[FirestoreFields.lastLoginAt],
        Timestamp.fromDate(lastLoginAt),
      );
      expect(json[FirestoreFields.createdAt], Timestamp.fromDate(createdAt));
      expect(json[FirestoreFields.updatedAt], Timestamp.fromDate(updatedAt));
      expect(json[FirestoreFields.deletedAt], Timestamp.fromDate(deletedAt));
      // DateTime eşitliği anı ve isUtc'yi birlikte karşılaştırır: okunan
      // zamanlar (gömülü belirteçteki dahil) UTC'dir.
      expect(UserAccountModel.fromJson(json), full);
    });

    test('eksik alanlar tablo varsayılanlarını alır; tanınmayan anahtar yok '
        'sayılır', () {
      final model = UserAccountModel.fromJson(const {
        ...requiredJson,
        'bilinmeyenAlan': 1,
      });

      expect(model.fcmTokens, isEmpty);
      expect(model.lastLoginAt, isNull);
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
          () => UserAccountModel.fromJson(Map.of(requiredJson)..remove(key)),
          throwsA(
            isA<CheckedFromJsonException>().having((e) => e.key, 'key', key),
          ),
          reason: key,
        );
      }
    });
  });

  group('T-09 · UserAccountModel · copyWith ve eşitlik', () {
    test('parametresiz copyWith aynı modeli verir; props 9 alan taşır', () {
      expect(full.copyWith(), full);
      expect(full.props, hasLength(9));
    });

    test('her alan copyWith ile değişir ve eşitliğe girer', () {
      void check<V>(
        UserAccountModel changed,
        V Function(UserAccountModel) read,
        V value,
      ) => expectFieldChange(full, changed, read, value);

      check(full.copyWith(email: 'x@y.tr'), (m) => m.email, 'x@y.tr');
      check(
        full.copyWith(emailLower: 'x@y.tr'),
        (m) => m.emailLower,
        'x@y.tr',
      );
      check(
        full.copyWith(fcmTokens: const []),
        (m) => m.fcmTokens,
        const <FcmTokenModel>[],
      );
      check(full.copyWith(lastLoginAt: later), (m) => m.lastLoginAt, later);
      check(full.copyWith(createdAt: later), (m) => m.createdAt, later);
      check(full.copyWith(updatedAt: later), (m) => m.updatedAt, later);
      check(full.copyWith(isDeleted: false), (m) => m.isDeleted, false);
      check(full.copyWith(deletedAt: later), (m) => m.deletedAt, later);
      check(full.copyWith(deletedBy: 'u9'), (m) => m.deletedBy, 'u9');
    });

    test('clear bayrakları null olabilen alanları boşaltır ve verilen '
        'değerden önce gelir', () {
      void check(
        UserAccountModel changed,
        Object? Function(UserAccountModel) read,
      ) => expectFieldChange(full, changed, read, null);

      check(full.copyWith(clearLastLoginAt: true), (m) => m.lastLoginAt);
      check(full.copyWith(clearCreatedAt: true), (m) => m.createdAt);
      check(full.copyWith(clearUpdatedAt: true), (m) => m.updatedAt);
      check(full.copyWith(clearDeletedAt: true), (m) => m.deletedAt);
      check(full.copyWith(clearDeletedBy: true), (m) => m.deletedBy);
      check(
        full.copyWith(lastLoginAt: later, clearLastLoginAt: true),
        (m) => m.lastLoginAt,
      );
    });

    test('BaseFields sözleşmesini uygular; createdBy taşımaz', () {
      expect(full, isA<BaseFields>());
      expect(full.createdBy, isNull);
    });
  });

  group('T-09 · FcmTokenModel', () {
    test('gidiş-dönüş: updatedAt Timestamp olarak yazılır ve aynı model '
        'okunur', () {
      final json = token.toJson();

      expect(json[FirestoreFields.updatedAt], Timestamp.fromDate(tokenAt));
      expect(FcmTokenModel.fromJson(json), token);
    });

    test('eksik updatedAt CheckedFromJsonException fırlatır', () {
      expect(
        () => FcmTokenModel.fromJson(const {
          FirestoreFields.token: 'fcm-token-1',
          FirestoreFields.platform: 'ios',
        }),
        throwsA(
          isA<CheckedFromJsonException>().having(
            (e) => e.key,
            'key',
            FirestoreFields.updatedAt,
          ),
        ),
      );
    });

    test('her alan copyWith ile değişir ve eşitliğe girer; props 3 alan '
        'taşır', () {
      void check<V>(
        FcmTokenModel changed,
        V Function(FcmTokenModel) read,
        V value,
      ) => expectFieldChange(token, changed, read, value);

      expect(token.copyWith(), token);
      expect(token.props, hasLength(3));
      check(token.copyWith(token: 't2'), (m) => m.token, 't2');
      check(token.copyWith(platform: 'android'), (m) => m.platform, 'android');
      check(token.copyWith(updatedAt: later), (m) => m.updatedAt, later);
    });
  });
}
