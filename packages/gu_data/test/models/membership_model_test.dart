// T-09 · MembershipModel (+ gömülü MembershipApplicantModel): JSON
// gidiş-dönüşü, PLAN §9.6.4 tablosuyla alan / anahtar / varsayılan paritesi
// (tablo docs/PLAN.md'den okunur), enum toleransı, copyWith ve eşitlik,
// türetilmiş kimlik ve üyelik kuralları.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../fakes/fake_app_clock.dart';
import '../helpers/plan_model_table_club_group.dart';

final DateTime _appliedAt = DateTime.utc(2026, 9, 20, 10, 0, 0, 111);
final DateTime _decidedAt = DateTime.utc(2026, 9, 22, 14, 30, 0, 222);
final DateTime _retryAfter = DateTime.utc(2026, 9, 29, 14, 30, 0, 222);
final DateTime _createdAt = DateTime.utc(2026, 9, 20, 10, 0, 0, 333);
final DateTime _updatedAt = DateTime.utc(2026, 9, 22, 14, 30, 0, 444);
final DateTime _deletedAt = DateTime.utc(2026, 9, 23, 9, 0, 0, 555);
final DateTime _otherTime = DateTime.utc(2027, 1, 2, 3, 4, 5, 6);

const MembershipApplicantModel _applicant = MembershipApplicantModel(
  name: 'Ayşe Demir',
  department: 'b04',
  year: YearLevel.third,
  avatarSeed: 'u_ayse',
);

/// Her alanı varsayılanından farklı ve dolu olan üyelik.
final MembershipModel _full = MembershipModel(
  id: 'c01_u_ayse',
  clubId: 'c01',
  userId: 'u_ayse',
  status: MembershipStatus.rejected,
  role: ClubRole.board,
  note: 'Katılmak istiyorum',
  applicant: _applicant,
  appliedAt: _appliedAt,
  decidedAt: _decidedAt,
  decidedBy: 'u_mehmet',
  retryAfter: _retryAfter,
  rejectReason: RejectReason.quota,
  rejectNote: 'Kontenjan doldu',
  priorCount: 2,
  createdAt: _createdAt,
  updatedAt: _updatedAt,
  isDeleted: true,
  deletedAt: _deletedAt,
  deletedBy: 'u_admin',
);

/// Yalnızca zorunlu alanları taşıyan belge verisi.
const Map<String, Object?> _minimalJson = {
  'clubId': 'c01',
  'userId': 'u_ayse',
  'applicant': {'name': 'Ayşe Demir', 'avatarSeed': 'u_ayse'},
};

MembershipModel _membership({
  MembershipStatus status = MembershipStatus.active,
  ClubRole role = ClubRole.member,
  DateTime? retryAfter,
}) => MembershipModel(
  clubId: 'c01',
  userId: 'u_ayse',
  applicant: _applicant,
  status: status,
  role: role,
  retryAfter: retryAfter,
);

void main() {
  final table = ClubGroupPlanTable.read('9.6.4');

  group('T-09 · MembershipModel', () {
    test('toJson → fromJson aynı modeli verir; zamanlar Timestamp olur', () {
      final json = _full.toJson();

      expect(MembershipModel.fromJson(json, id: _full.id), _full);
      for (final key in table.jsonKeysOfType('DateTime')) {
        expect(json[key], isA<Timestamp>(), reason: key);
      }
      expect(json.values.whereType<FieldValue>(), isEmpty);
    });

    test('JSON anahtarları PLAN §9.6.4 tablosuyla aynıdır (id ve createdBy '
        'yazılmaz)', () {
      expect(_full.toJson().keys.toSet(), table.jsonKeys);
      expect(_full.createdBy, isNull);
    });

    test('applicant Map olarak yazılır', () {
      expect(_full.toJson()['applicant'], {
        'name': 'Ayşe Demir',
        'department': 'b04',
        'year': '3',
        'avatarSeed': 'u_ayse',
      });
    });

    test('eksik alanlar tablo varsayılanını alır; fazla anahtar ve verideki '
        'id yok sayılır', () {
      const built = MembershipModel(
        clubId: 'c01',
        userId: 'u_ayse',
        applicant: MembershipApplicantModel(
          name: 'Ayşe Demir',
          avatarSeed: 'u_ayse',
        ),
      );
      final model = MembershipModel.fromJson(const {
        ..._minimalJson,
        'id': 'veri-icindeki-id',
        'stale': true,
      }, id: 'c01_u_ayse');

      expect(_minimalJson.keys.toSet(), table.requiredJsonKeys);
      expect(model, built);
      table.expectDefaults(
        {
          'id': built.id,
          'status': model.status,
          'role': model.role,
          'note': model.note,
          'appliedAt': model.appliedAt,
          'decidedAt': model.decidedAt,
          'decidedBy': model.decidedBy,
          'retryAfter': model.retryAfter,
          'rejectReason': model.rejectReason,
          'rejectNote': model.rejectNote,
          'priorCount': model.priorCount,
          'createdAt': model.createdAt,
          'updatedAt': model.updatedAt,
          'isDeleted': model.isDeleted,
          'deletedAt': model.deletedAt,
          'deletedBy': model.deletedBy,
        },
        codes: {
          'FirestoreIds.membership(clubId, userId)': FirestoreIds.membership(
            'c01',
            'u_ayse',
          ),
          'MembershipStatus.pending': MembershipStatus.pending,
          'ClubRole.member': ClubRole.member,
        },
      );
    });

    test('belge kimliği verilen id olur; verilmezse alanları izler', () {
      final read = MembershipModel.fromJson(_minimalJson, id: 'eski-kimlik');

      expect(read.id, 'eski-kimlik');
      expect(read.copyWith(userId: 'u_can').id, 'eski-kimlik');
      expect(
        _membership().copyWith(clubId: 'c02', userId: 'u_p_c01').id,
        FirestoreIds.membership('c02', 'u_p_c01'),
      );
    });

    test('bilinmeyen rejectReason null okunur; bilinmeyen status hata '
        'verir', () {
      final model = MembershipModel.fromJson(const {
        ..._minimalJson,
        'rejectReason': 'gelecek-neden',
      }, id: 'c01_u_ayse');

      expect(model.rejectReason, isNull);
      expect(
        () => MembershipModel.fromJson(const {
          ..._minimalJson,
          'status': 'banned',
        }, id: 'c01_u_ayse'),
        throwsParseError,
      );
    });

    test('copyWith her alanı değiştirir; her alan eşitliğe girer', () {
      const applicant = MembershipApplicantModel(
        name: 'Can Öz',
        avatarSeed: 'u_can',
      );

      expect(_full.copyWith(), _full);
      expectFieldCases<MembershipModel>(_full, [
        (
          field: 'id',
          copy: _full.copyWith(id: 'c09_u_x'),
          read: (m) => m.id,
          expected: 'c09_u_x',
        ),
        (
          field: 'clubId',
          copy: _full.copyWith(clubId: 'c02'),
          read: (m) => m.clubId,
          expected: 'c02',
        ),
        (
          field: 'userId',
          copy: _full.copyWith(userId: 'u_can'),
          read: (m) => m.userId,
          expected: 'u_can',
        ),
        (
          field: 'status',
          copy: _full.copyWith(status: MembershipStatus.removed),
          read: (m) => m.status,
          expected: MembershipStatus.removed,
        ),
        (
          field: 'role',
          copy: _full.copyWith(role: ClubRole.president),
          read: (m) => m.role,
          expected: ClubRole.president,
        ),
        (
          field: 'note',
          copy: _full.copyWith(note: 'Yeni not'),
          read: (m) => m.note,
          expected: 'Yeni not',
        ),
        (
          field: 'applicant',
          copy: _full.copyWith(applicant: applicant),
          read: (m) => m.applicant,
          expected: applicant,
        ),
        (
          field: 'appliedAt',
          copy: _full.copyWith(appliedAt: _otherTime),
          read: (m) => m.appliedAt,
          expected: _otherTime,
        ),
        (
          field: 'decidedAt',
          copy: _full.copyWith(decidedAt: _otherTime),
          read: (m) => m.decidedAt,
          expected: _otherTime,
        ),
        (
          field: 'decidedBy',
          copy: _full.copyWith(decidedBy: 'u_can'),
          read: (m) => m.decidedBy,
          expected: 'u_can',
        ),
        (
          field: 'retryAfter',
          copy: _full.copyWith(retryAfter: _otherTime),
          read: (m) => m.retryAfter,
          expected: _otherTime,
        ),
        (
          field: 'rejectReason',
          copy: _full.copyWith(rejectReason: RejectReason.other),
          read: (m) => m.rejectReason,
          expected: RejectReason.other,
        ),
        (
          field: 'rejectNote',
          copy: _full.copyWith(rejectNote: 'Başka açıklama'),
          read: (m) => m.rejectNote,
          expected: 'Başka açıklama',
        ),
        (
          field: 'priorCount',
          copy: _full.copyWith(priorCount: 3),
          read: (m) => m.priorCount,
          expected: 3,
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
      expectFieldCases<MembershipModel>(_full, [
        (
          field: 'appliedAt',
          copy: _full.copyWith(clearAppliedAt: true),
          read: (m) => m.appliedAt,
          expected: null,
        ),
        (
          field: 'decidedAt',
          copy: _full.copyWith(clearDecidedAt: true),
          read: (m) => m.decidedAt,
          expected: null,
        ),
        (
          field: 'decidedBy',
          copy: _full.copyWith(clearDecidedBy: true),
          read: (m) => m.decidedBy,
          expected: null,
        ),
        (
          field: 'retryAfter',
          copy: _full.copyWith(clearRetryAfter: true),
          read: (m) => m.retryAfter,
          expected: null,
        ),
        (
          field: 'rejectReason',
          copy: _full.copyWith(clearRejectReason: true),
          read: (m) => m.rejectReason,
          expected: null,
        ),
        (
          field: 'rejectNote',
          copy: _full.copyWith(clearRejectNote: true),
          read: (m) => m.rejectNote,
          expected: null,
        ),
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

    test('isActiveMember yalnızca active durumunda doğrudur', () {
      expect(
        {
          for (final status in MembershipStatus.values)
            if (_membership(status: status).isActiveMember) status,
        },
        {MembershipStatus.active},
      );
    });

    test('countsTowardMemberCount: aktif ve danışman olmayan üyelik', () {
      expect(
        {
          for (final role in ClubRole.values)
            if (_membership(role: role).countsTowardMemberCount) role,
        },
        {ClubRole.member, ClubRole.board, ClubRole.president},
      );
      expect(
        _membership(status: MembershipStatus.pending).countsTowardMemberCount,
        isFalse,
      );
    });

    test('canReapplyAt: kapanmış üyelikte bekleme süresi dolunca', () {
      final clock = FakeAppClock(_retryAfter);
      MembershipModel closed(MembershipStatus status) =>
          _membership(status: status, retryAfter: _retryAfter);

      expect(
        {
          for (final status in MembershipStatus.values)
            if (closed(status).canReapplyAt(clock)) status,
        },
        {
          MembershipStatus.rejected,
          MembershipStatus.removed,
          MembershipStatus.left,
          MembershipStatus.cancelled,
        },
        reason: 'süre tam dolduğunda (now == retryAfter) başvurulabilir',
      );

      clock.advance(const Duration(milliseconds: -1));
      expect(
        closed(MembershipStatus.rejected).canReapplyAt(clock),
        isFalse,
        reason: 'süre dolmadan başvurulamaz',
      );
      expect(
        _membership(status: MembershipStatus.left).canReapplyAt(clock),
        isTrue,
        reason: 'retryAfter yoksa bekleme yoktur',
      );
    });
  });

  group('T-09 · MembershipApplicantModel', () {
    final fields = ClubGroupPlanTable.embeddedKeys('MembershipApplicantModel');

    test('anahtarları PLAN tanımıyla aynıdır; e-posta taşımaz', () {
      expect(_applicant.toJson().keys.toSet(), fields);
      expect(fields, isNot(contains('email')));
    });

    test('department ve year varsayılan null; bilinmeyen year null '
        'okunur', () {
      expect(
        MembershipApplicantModel.fromJson(const {
          'name': 'Ayşe Demir',
          'avatarSeed': 'u_ayse',
          'year': '9',
        }),
        const MembershipApplicantModel(
          name: 'Ayşe Demir',
          avatarSeed: 'u_ayse',
        ),
      );
    });

    test('anonimleştirme yükü modele ayrışır', () {
      final payload = Anonymization.applicantPayload();

      expect(
        MembershipApplicantModel.fromJson(
          payload['applicant']! as Map<String, Object?>,
        ),
        const MembershipApplicantModel(
          name: Anonymization.deletedUserName,
          avatarSeed: 'deleted',
        ),
      );
    });

    test('copyWith her alanı değiştirir; clear* null yapar', () {
      expect(_applicant.copyWith(), _applicant);
      expectFieldCases<MembershipApplicantModel>(_applicant, [
        (
          field: 'name',
          copy: _applicant.copyWith(name: 'Can Öz'),
          read: (m) => m.name,
          expected: 'Can Öz',
        ),
        (
          field: 'department',
          copy: _applicant.copyWith(department: 'b11'),
          read: (m) => m.department,
          expected: 'b11',
        ),
        (
          field: 'year',
          copy: _applicant.copyWith(year: YearLevel.master),
          read: (m) => m.year,
          expected: YearLevel.master,
        ),
        (
          field: 'avatarSeed',
          copy: _applicant.copyWith(avatarSeed: 'u_can'),
          read: (m) => m.avatarSeed,
          expected: 'u_can',
        ),
      ], fields: fields);
      expect(_applicant.copyWith(clearDepartment: true).department, isNull);
      expect(_applicant.copyWith(clearYear: true).year, isNull);
    });
  });
}
