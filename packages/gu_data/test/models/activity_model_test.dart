// T-09 · ActivityModel (+ gömülü ActivityRefsModel): JSON gidiş-dönüşü,
// PLAN §9.6.13 tablosuyla alan / anahtar / varsayılan paritesi (tablo
// docs/PLAN.md'den okunur), bilinmeyen tür toleransı, copyWith ve eşitlik,
// türetilmiş kategori.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../helpers/plan_model_table_club_group.dart';

final DateTime _createdAt = DateTime.utc(2026, 10, 1, 12, 0, 0, 111);
final DateTime _otherTime = DateTime.utc(2027, 1, 2, 3, 4, 5, 6);

const ActivityRefsModel _refs = ActivityRefsModel(
  userId: 'u_ayse',
  eventId: 'e03',
  postId: 'p07',
  role: ClubRole.board,
);

/// Her alanı varsayılanından farklı ve dolu olan günlük kaydı.
final ActivityModel _full = ActivityModel(
  id: 'a_muzqv60t_o',
  clubId: 'c01',
  actorId: 'u_mehmet',
  kind: ActivityKind.roleChanged,
  refs: _refs,
  createdAt: _createdAt,
);

/// Yalnızca zorunlu alanları taşıyan belge verisi.
const Map<String, Object?> _minimalJson = {
  'clubId': 'c01',
  'actorId': 'u_mehmet',
  'kind': 'settings_changed',
};

void main() {
  final table = ClubGroupPlanTable.read('9.6.13');

  group('T-09 · ActivityModel', () {
    test('toJson → fromJson aynı modeli verir; createdAt Timestamp olur', () {
      final json = _full.toJson();

      expect(ActivityModel.fromJson(json, id: _full.id), _full);
      expect(table.jsonKeysOfType('DateTime'), {'createdAt'});
      expect(json['createdAt'], isA<Timestamp>());
      expect(json.values.whereType<FieldValue>(), isEmpty);
    });

    test('JSON anahtarları PLAN §9.6.13 tablosuyla aynıdır: id ve BaseFields '
        'alanları yoktur', () {
      final keys = _full.toJson().keys.toSet();

      expect(keys, table.jsonKeys);
      expect(keys, isNot(contains('isDeleted')));
    });

    test('refs Map olarak yazılır', () {
      expect(_full.toJson()['refs'], {
        'userId': 'u_ayse',
        'eventId': 'e03',
        'postId': 'p07',
        'role': 'board',
      });
    });

    test('eksik alanlar tablo varsayılanını alır; fazla anahtar ve verideki '
        'id yok sayılır', () {
      final model = ActivityModel.fromJson(const {
        ..._minimalJson,
        'id': 'veri-icindeki-id',
        'isDeleted': false,
      }, id: 'a1');

      expect(_minimalJson.keys.toSet(), table.requiredJsonKeys);
      expect(
        model,
        const ActivityModel(
          id: 'a1',
          clubId: 'c01',
          actorId: 'u_mehmet',
          kind: ActivityKind.settingsChanged,
        ),
      );
      table.expectDefaults(
        {'refs': model.refs, 'createdAt': model.createdAt},
        codes: {'const ActivityRefsModel()': const ActivityRefsModel()},
      );
    });

    test('bilinmeyen kind unknown okunur; eksik kind hata verir', () {
      final json = Map.of(_minimalJson)..['kind'] = 'club_renamed';
      final model = ActivityModel.fromJson(json, id: 'a1');

      expect(model.kind, ActivityKind.unknown);
      expect(model.category, isNull);
      expect(
        () => ActivityModel.fromJson(
          Map.of(_minimalJson)..remove('kind'),
          id: 'a',
        ),
        throwsParseError,
      );
    });

    test('category türden türer', () {
      expect(_full.category, ActivityCategory.membership);
      expect(
        ActivityModel.fromJson(_minimalJson, id: 'a1').category,
        ActivityCategory.settings,
      );
    });

    test('copyWith her alanı değiştirir; her alan eşitliğe girer', () {
      const refs = ActivityRefsModel(postId: 'p09');

      expect(_full.copyWith(), _full);
      expectFieldCases<ActivityModel>(_full, [
        (
          field: 'id',
          copy: _full.copyWith(id: 'a2'),
          read: (m) => m.id,
          expected: 'a2',
        ),
        (
          field: 'clubId',
          copy: _full.copyWith(clubId: 'c02'),
          read: (m) => m.clubId,
          expected: 'c02',
        ),
        (
          field: 'actorId',
          copy: _full.copyWith(actorId: 'u_can'),
          read: (m) => m.actorId,
          expected: 'u_can',
        ),
        (
          field: 'kind',
          copy: _full.copyWith(kind: ActivityKind.poll),
          read: (m) => m.kind,
          expected: ActivityKind.poll,
        ),
        (
          field: 'refs',
          copy: _full.copyWith(refs: refs),
          read: (m) => m.refs,
          expected: refs,
        ),
        (
          field: 'createdAt',
          copy: _full.copyWith(createdAt: _otherTime),
          read: (m) => m.createdAt,
          expected: _otherTime,
        ),
      ], fields: table.fields);
      expect(table.nullableFields, {'createdAt'});
      expect(_full.copyWith(clearCreatedAt: true).createdAt, isNull);
    });
  });

  group('T-09 · ActivityRefsModel', () {
    final fields = ClubGroupPlanTable.embeddedKeys('ActivityRefsModel');

    test('anahtarları PLAN tanımıyla aynıdır; alanlar varsayılan null', () {
      expect(_refs.toJson().keys.toSet(), fields);
      expect(ActivityRefsModel.fromJson(const {}), const ActivityRefsModel());
      expect(const ActivityRefsModel().props, [null, null, null, null]);
    });

    test('bilinmeyen role null okunur', () {
      expect(
        ActivityRefsModel.fromJson(const {'userId': 'u1', 'role': 'owner'}),
        const ActivityRefsModel(userId: 'u1'),
      );
    });

    test('copyWith her alanı değiştirir ve null yapar', () {
      expect(_refs.copyWith(), _refs);
      expectFieldCases<ActivityRefsModel>(_refs, [
        (
          field: 'userId',
          copy: _refs.copyWith(userId: 'u_can'),
          read: (m) => m.userId,
          expected: 'u_can',
        ),
        (
          field: 'eventId',
          copy: _refs.copyWith(eventId: 'e09'),
          read: (m) => m.eventId,
          expected: 'e09',
        ),
        (
          field: 'postId',
          copy: _refs.copyWith(postId: 'p01'),
          read: (m) => m.postId,
          expected: 'p01',
        ),
        (
          field: 'role',
          copy: _refs.copyWith(role: ClubRole.president),
          read: (m) => m.role,
          expected: ClubRole.president,
        ),
      ], fields: fields);
      expectFieldCases<ActivityRefsModel>(_refs, [
        (
          field: 'userId',
          copy: _refs.copyWith(clearUserId: true),
          read: (m) => m.userId,
          expected: null,
        ),
        (
          field: 'eventId',
          copy: _refs.copyWith(clearEventId: true),
          read: (m) => m.eventId,
          expected: null,
        ),
        (
          field: 'postId',
          copy: _refs.copyWith(clearPostId: true),
          read: (m) => m.postId,
          expected: null,
        ),
        (
          field: 'role',
          copy: _refs.copyWith(clearRole: true),
          read: (m) => m.role,
          expected: null,
        ),
      ], fields: fields);
    });
  });
}
