// T-09 · SupportTicketModel (PLAN §9.6.17): JSON anahtar kümesi ↔ PLAN
// tablosu, Timestamp ↔ UTC DateTime gidiş-dönüşü, tablo varsayılanları,
// ayrıştırma toleransı, copyWith + eşitlik (alan başına).
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
  final full = SupportTicketModel(
    id: 'ticket-1',
    ticketNo: 'GU-7K3Q9X',
    userId: 'u_ayse',
    subject: SupportSubject.account,
    message: 'E-postamı değiştiremiyorum.',
    attachmentPaths: const [
      'support/GU-7K3Q9X/20261008T201501Z_3f9a1c2b7d4e5f60.jpg',
    ],
    status: TicketStatus.closed,
    createdAt: createdAt,
    updatedAt: updatedAt,
    isDeleted: true,
    deletedAt: deletedAt,
    deletedBy: 'u_admin',
  );

  // Yalnızca zorunlu alanlar.
  const minimal = SupportTicketModel(
    id: 'ticket-2',
    ticketNo: 'GU-ABCDEF',
    userId: 'u1',
    subject: SupportSubject.bug,
    message: 'Uygulama açılmıyor.',
  );
  const requiredJson = <String, Object?>{
    FirestoreFields.ticketNo: 'GU-ABCDEF',
    FirestoreFields.userId: 'u1',
    FirestoreFields.subject: 'bug',
    FirestoreFields.message: 'Uygulama açılmıyor.',
  };

  Matcher throwsCheckedFor(String key) => throwsA(
    isA<CheckedFromJsonException>().having((e) => e.key, 'key', key),
  );

  group('T-09 · SupportTicketModel · JSON', () {
    test('toJson anahtarları PLAN §9.6.17 tablosuyla aynıdır; belge kimliği '
        've FieldValue yazılmaz', () {
      final json = full.toJson();

      expect(json.keys.toSet(), planJsonKeys('9.6.17'));
      expect(json.values, isNot(contains(full.id)));
      expect(json.values.whereType<FieldValue>(), isEmpty);
    });

    test('null alanlar toJson çıktısına girmez', () {
      expect(minimal.toJson().keys.toSet(), {
        FirestoreFields.ticketNo,
        FirestoreFields.userId,
        FirestoreFields.subject,
        FirestoreFields.message,
        FirestoreFields.attachmentPaths,
        FirestoreFields.status,
        FirestoreFields.isDeleted,
      });
    });

    test('gidiş-dönüş: zaman alanları Timestamp, enum alanları JSON değeri '
        'olarak yazılır ve aynı model okunur', () {
      final json = full.toJson();

      expect(json[FirestoreFields.createdAt], Timestamp.fromDate(createdAt));
      expect(json[FirestoreFields.updatedAt], Timestamp.fromDate(updatedAt));
      expect(json[FirestoreFields.deletedAt], Timestamp.fromDate(deletedAt));
      expect(json[FirestoreFields.subject], 'account');
      expect(json[FirestoreFields.status], 'closed');
      // DateTime eşitliği anı ve isUtc'yi birlikte karşılaştırır: okunan
      // zamanlar UTC'dir.
      expect(SupportTicketModel.fromJson(json, id: full.id), full);
    });

    test('eksik alanlar tablo varsayılanlarını alır; tanınmayan anahtar yok '
        'sayılır', () {
      final model = SupportTicketModel.fromJson(const {
        ...requiredJson,
        'bilinmeyenAlan': 1,
      }, id: 'ticket-2');

      expect(model.id, 'ticket-2');
      expect(model.attachmentPaths, isEmpty);
      expect(model.status, TicketStatus.open);
      expect(model.createdAt, isNull);
      expect(model.updatedAt, isNull);
      expect(model.isDeleted, isFalse);
      expect(model.deletedAt, isNull);
      expect(model.deletedBy, isNull);
      // Adsız yapıcının varsayılanları JSON yapıcısınınkilerle aynıdır.
      expect(model, minimal);
    });

    test('bilinmeyen subject ve status CheckedFromJsonException fırlatır', () {
      for (final key in [FirestoreFields.subject, FirestoreFields.status]) {
        expect(
          () => SupportTicketModel.fromJson({
            ...requiredJson,
            key: 'bilinmeyen',
          }, id: 'ticket-2'),
          throwsCheckedFor(key),
          reason: key,
        );
      }
    });

    test('zorunlu alan eksikse CheckedFromJsonException alan adını taşır', () {
      for (final key in requiredJson.keys) {
        expect(
          () => SupportTicketModel.fromJson(
            Map.of(requiredJson)..remove(key),
            id: 'ticket-2',
          ),
          throwsCheckedFor(key),
          reason: key,
        );
      }
    });
  });

  group('T-09 · SupportTicketModel · copyWith ve eşitlik', () {
    test('parametresiz copyWith aynı modeli verir; props 12 alan taşır', () {
      expect(full.copyWith(), full);
      expect(full.props, hasLength(12));
    });

    test('her alan copyWith ile değişir ve eşitliğe girer', () {
      void check<V>(
        SupportTicketModel changed,
        V Function(SupportTicketModel) read,
        V value,
      ) => expectFieldChange(full, changed, read, value);

      check(full.copyWith(id: 'ticket-9'), (m) => m.id, 'ticket-9');
      check(
        full.copyWith(ticketNo: 'GU-222222'),
        (m) => m.ticketNo,
        'GU-222222',
      );
      check(full.copyWith(userId: 'u9'), (m) => m.userId, 'u9');
      check(
        full.copyWith(subject: SupportSubject.other),
        (m) => m.subject,
        SupportSubject.other,
      );
      check(full.copyWith(message: 'Yeni'), (m) => m.message, 'Yeni');
      check(
        full.copyWith(attachmentPaths: const []),
        (m) => m.attachmentPaths,
        const <String>[],
      );
      check(
        full.copyWith(status: TicketStatus.open),
        (m) => m.status,
        TicketStatus.open,
      );
      check(full.copyWith(createdAt: later), (m) => m.createdAt, later);
      check(full.copyWith(updatedAt: later), (m) => m.updatedAt, later);
      check(full.copyWith(isDeleted: false), (m) => m.isDeleted, false);
      check(full.copyWith(deletedAt: later), (m) => m.deletedAt, later);
      check(full.copyWith(deletedBy: 'u9'), (m) => m.deletedBy, 'u9');
    });

    test('clear bayrakları null olabilen alanları boşaltır ve verilen '
        'değerden önce gelir', () {
      void check(
        SupportTicketModel changed,
        Object? Function(SupportTicketModel) read,
      ) => expectFieldChange(full, changed, read, null);

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
