// T-09 · MembershipContactModel: JSON gidiş-dönüşü, PLAN §9.6.5 tablosuyla
// alan / anahtar / varsayılan paritesi (tablo docs/PLAN.md'den okunur),
// copyWith ve eşitlik.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../helpers/plan_model_table_club_group.dart';

final DateTime _createdAt = DateTime.utc(2026, 9, 20, 10, 0, 0, 111);
final DateTime _updatedAt = DateTime.utc(2026, 9, 21, 11, 0, 0, 222);
final DateTime _deletedAt = DateTime.utc(2026, 9, 22, 12, 0, 0, 333);
final DateTime _otherTime = DateTime.utc(2027, 1, 2, 3, 4, 5, 6);

/// Her alanı varsayılanından farklı ve dolu olan iletişim kaydı.
final MembershipContactModel _full = MembershipContactModel(
  email: 'Ayse.Demir@ogr.gumushane.edu.tr',
  emailLower: 'ayse.demir@ogr.gumushane.edu.tr',
  createdAt: _createdAt,
  updatedAt: _updatedAt,
  isDeleted: true,
  deletedAt: _deletedAt,
  deletedBy: 'u_admin',
);

void main() {
  final table = ClubGroupPlanTable.read('9.6.5');

  group('T-09 · MembershipContactModel', () {
    test('toJson → fromJson aynı modeli verir; zamanlar Timestamp olur', () {
      final json = _full.toJson();

      expect(MembershipContactModel.fromJson(json), _full);
      for (final key in table.jsonKeysOfType('DateTime')) {
        expect(json[key], isA<Timestamp>(), reason: key);
      }
      expect(json.values.whereType<FieldValue>(), isEmpty);
    });

    test('JSON anahtarları PLAN §9.6.5 tablosuyla aynıdır (createdBy '
        'yazılmaz)', () {
      expect(_full.toJson().keys.toSet(), table.jsonKeys);
      expect(_full.createdBy, isNull);
    });

    test('eksik alanlar tablo varsayılanını alır; fazla anahtar yok '
        'sayılır', () {
      const json = <String, Object?>{'email': 'a@b.co', 'emailLower': 'a@b.co'};
      final model = MembershipContactModel.fromJson(const {
        ...json,
        'phone': '555',
      });

      expect(json.keys.toSet(), table.requiredJsonKeys);
      expect(
        model,
        const MembershipContactModel(email: 'a@b.co', emailLower: 'a@b.co'),
      );
      table.expectDefaults({
        'createdAt': model.createdAt,
        'updatedAt': model.updatedAt,
        'isDeleted': model.isDeleted,
        'deletedAt': model.deletedAt,
        'deletedBy': model.deletedBy,
      });
    });

    test('anonimleştirme yükü modele ayrışır', () {
      expect(
        MembershipContactModel.fromJson(Anonymization.contactPayload()),
        const MembershipContactModel(email: '', emailLower: ''),
      );
    });

    test('copyWith her alanı değiştirir; her alan eşitliğe girer', () {
      expect(_full.copyWith(), _full);
      expectFieldCases<MembershipContactModel>(_full, [
        (
          field: 'email',
          copy: _full.copyWith(email: 'x@gumushane.edu.tr'),
          read: (m) => m.email,
          expected: 'x@gumushane.edu.tr',
        ),
        (
          field: 'emailLower',
          copy: _full.copyWith(emailLower: 'x@gumushane.edu.tr'),
          read: (m) => m.emailLower,
          expected: 'x@gumushane.edu.tr',
        ),
        (
          field: 'createdAt',
          copy: _full.copyWith(createdAt: _otherTime),
          read: (m) => m.createdAt,
          expected: _otherTime,
        ),
        (
          field: 'updatedAt',
          copy: _full.copyWith(updatedAt: _otherTime),
          read: (m) => m.updatedAt,
          expected: _otherTime,
        ),
        (
          field: 'isDeleted',
          copy: _full.copyWith(isDeleted: false),
          read: (m) => m.isDeleted,
          expected: false,
        ),
        (
          field: 'deletedAt',
          copy: _full.copyWith(deletedAt: _otherTime),
          read: (m) => m.deletedAt,
          expected: _otherTime,
        ),
        (
          field: 'deletedBy',
          copy: _full.copyWith(deletedBy: 'u_can'),
          read: (m) => m.deletedBy,
          expected: 'u_can',
        ),
      ], fields: table.fields);
    });

    test('copyWith clear* bayrakları null olabilen her alanı null yapar', () {
      expectFieldCases<MembershipContactModel>(_full, [
        (
          field: 'createdAt',
          copy: _full.copyWith(clearCreatedAt: true),
          read: (m) => m.createdAt,
          expected: null,
        ),
        (
          field: 'updatedAt',
          copy: _full.copyWith(clearUpdatedAt: true),
          read: (m) => m.updatedAt,
          expected: null,
        ),
        (
          field: 'deletedAt',
          copy: _full.copyWith(clearDeletedAt: true),
          read: (m) => m.deletedAt,
          expected: null,
        ),
        (
          field: 'deletedBy',
          copy: _full.copyWith(clearDeletedBy: true),
          read: (m) => m.deletedBy,
          expected: null,
        ),
      ], fields: table.nullableFields);
    });
  });
}
