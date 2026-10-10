// T-09 · ReportModel: JSON gidiş-dönüşü, PLAN §9.6.12 tablosuyla alan /
// anahtar / varsayılan paritesi (tablo docs/PLAN.md'den okunur), enum
// toleransı, copyWith ve eşitlik, türetilmiş kimlik.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../helpers/plan_model_table_club_group.dart';

final DateTime _resolvedAt = DateTime.utc(2026, 10, 5, 9, 0, 0, 111);
final DateTime _createdAt = DateTime.utc(2026, 10, 4, 18, 45, 0, 222);
final DateTime _updatedAt = DateTime.utc(2026, 10, 5, 9, 0, 0, 333);
final DateTime _deletedAt = DateTime.utc(2026, 10, 6, 7, 0, 0, 444);
final DateTime _otherTime = DateTime.utc(2027, 1, 2, 3, 4, 5, 6);

/// Her alanı varsayılanından farklı ve dolu olan şikayet.
final ReportModel _full = ReportModel(
  id: 'u_ayse_post_p07',
  targetType: ReportTargetType.post,
  targetId: 'p07',
  targetClubId: 'c01',
  reporterId: 'u_ayse',
  reason: ReportReason.harassment,
  note: 'Hakaret içeriyor',
  status: ReportStatus.resolved,
  action: ReportAction.removed,
  resolvedAt: _resolvedAt,
  resolvedBy: 'u_admin',
  createdAt: _createdAt,
  updatedAt: _updatedAt,
  isDeleted: true,
  deletedAt: _deletedAt,
  deletedBy: 'u_admin',
);

/// Yalnızca zorunlu alanları taşıyan belge verisi.
const Map<String, Object?> _minimalJson = {
  'targetType': 'user',
  'targetId': 'u042',
  'reporterId': 'u_mehmet',
  'reason': 'spam',
};

void main() {
  final table = ClubGroupPlanTable.read('9.6.12');

  group('T-09 · ReportModel', () {
    test('toJson → fromJson aynı modeli verir; zamanlar Timestamp olur', () {
      final json = _full.toJson();

      expect(ReportModel.fromJson(json, id: _full.id), _full);
      for (final key in table.jsonKeysOfType('DateTime')) {
        expect(json[key], isA<Timestamp>(), reason: key);
      }
      expect(json.values.whereType<FieldValue>(), isEmpty);
    });

    test('JSON anahtarları PLAN §9.6.12 tablosuyla aynıdır (id ve createdBy '
        'yazılmaz)', () {
      expect(_full.toJson().keys.toSet(), table.jsonKeys);
      expect(_full.createdBy, isNull);
    });

    test('eksik alanlar tablo varsayılanını alır; fazla anahtar ve verideki '
        'id yok sayılır', () {
      const built = ReportModel(
        targetType: ReportTargetType.user,
        targetId: 'u042',
        reporterId: 'u_mehmet',
        reason: ReportReason.spam,
      );
      final model = ReportModel.fromJson(const {
        ..._minimalJson,
        'id': 'r01',
        'reasons': <Object?>[],
      }, id: 'u_mehmet_user_u042');

      expect(_minimalJson.keys.toSet(), table.requiredJsonKeys);
      expect(model, built);
      table.expectDefaults(
        {
          'id': built.id,
          'targetClubId': model.targetClubId,
          'note': model.note,
          'status': model.status,
          'action': model.action,
          'resolvedAt': model.resolvedAt,
          'resolvedBy': model.resolvedBy,
          'createdAt': model.createdAt,
          'updatedAt': model.updatedAt,
          'isDeleted': model.isDeleted,
          'deletedAt': model.deletedAt,
          'deletedBy': model.deletedBy,
        },
        codes: {
          'FirestoreIds.report(reporterId, targetType, targetId)':
              FirestoreIds.report('u_mehmet', 'user', 'u042'),
          'ReportStatus.open': ReportStatus.open,
        },
      );
    });

    test('belge kimliği verilen id olur; verilmezse alanları izler', () {
      final read = ReportModel.fromJson(_minimalJson, id: 'r01');

      expect(read.id, 'r01');
      expect(
        const ReportModel(
          targetType: ReportTargetType.event,
          targetId: 'e03',
          reporterId: 'u_p_c01',
          reason: ReportReason.offtopic,
        ).copyWith(targetType: ReportTargetType.club, targetId: 'c02').id,
        FirestoreIds.report('u_p_c01', 'club', 'c02'),
      );
    });

    test('bilinmeyen action null okunur; bilinmeyen status hata verir', () {
      final model = ReportModel.fromJson(const {
        ..._minimalJson,
        'action': 'gelecek-islem',
      }, id: 'r');

      expect(model.action, isNull);
      expect(
        () => ReportModel.fromJson(const {
          ..._minimalJson,
          'status': 'x',
        }, id: 'r'),
        throwsParseError,
      );
    });

    test('copyWith her alanı değiştirir; her alan eşitliğe girer', () {
      expect(_full.copyWith(), _full);
      expectFieldCases<ReportModel>(_full, [
        (
          field: 'id',
          copy: _full.copyWith(id: 'r99'),
          read: (m) => m.id,
          expected: 'r99',
        ),
        (
          field: 'targetType',
          copy: _full.copyWith(targetType: ReportTargetType.comment),
          read: (m) => m.targetType,
          expected: ReportTargetType.comment,
        ),
        (
          field: 'targetId',
          copy: _full.copyWith(targetId: 'cm12'),
          read: (m) => m.targetId,
          expected: 'cm12',
        ),
        (
          field: 'targetClubId',
          copy: _full.copyWith(targetClubId: 'c02'),
          read: (m) => m.targetClubId,
          expected: 'c02',
        ),
        (
          field: 'reporterId',
          copy: _full.copyWith(reporterId: 'u_can'),
          read: (m) => m.reporterId,
          expected: 'u_can',
        ),
        (
          field: 'reason',
          copy: _full.copyWith(reason: ReportReason.misinformation),
          read: (m) => m.reason,
          expected: ReportReason.misinformation,
        ),
        (
          field: 'note',
          copy: _full.copyWith(note: 'Yeni not'),
          read: (m) => m.note,
          expected: 'Yeni not',
        ),
        (
          field: 'status',
          copy: _full.copyWith(status: ReportStatus.open),
          read: (m) => m.status,
          expected: ReportStatus.open,
        ),
        (
          field: 'action',
          copy: _full.copyWith(action: ReportAction.dismissed),
          read: (m) => m.action,
          expected: ReportAction.dismissed,
        ),
        (
          field: 'resolvedAt',
          copy: _full.copyWith(resolvedAt: _otherTime),
          read: (m) => m.resolvedAt,
          expected: _otherTime,
        ),
        (
          field: 'resolvedBy',
          copy: _full.copyWith(resolvedBy: 'u_admin2'),
          read: (m) => m.resolvedBy,
          expected: 'u_admin2',
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
          copy: _full.copyWith(deletedBy: 'u_admin2'),
          read: (m) => m.deletedBy,
          expected: 'u_admin2',
        ),
      ], fields: table.fields);
    });

    test('copyWith clear* bayrakları null olabilen her alanı null yapar', () {
      expectFieldCases<ReportModel>(_full, [
        (
          field: 'targetClubId',
          copy: _full.copyWith(clearTargetClubId: true),
          read: (m) => m.targetClubId,
          expected: null,
        ),
        (
          field: 'action',
          copy: _full.copyWith(clearAction: true),
          read: (m) => m.action,
          expected: null,
        ),
        (
          field: 'resolvedAt',
          copy: _full.copyWith(clearResolvedAt: true),
          read: (m) => m.resolvedAt,
          expected: null,
        ),
        (
          field: 'resolvedBy',
          copy: _full.copyWith(clearResolvedBy: true),
          read: (m) => m.resolvedBy,
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
  });
}
