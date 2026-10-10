// T-09 · CounterModel: JSON gidiş-dönüşü, PLAN §9.6.18 tablosuyla alan /
// anahtar / varsayılan paritesi (tablo docs/PLAN.md'den okunur), copyWith ve
// eşitlik, türetilmiş kimlik ve kalan hak.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../helpers/plan_model_table_club_group.dart';

final DateTime _updatedAt = DateTime.utc(2026, 10, 8, 20, 15, 1, 123);
final DateTime _otherTime = DateTime.utc(2027, 1, 2, 3, 4, 5, 6);

/// Her alanı varsayılanından farklı ve dolu olan sayaç.
final CounterModel _full = CounterModel(
  id: 'c01_20261008',
  clubId: 'c01',
  day: '2026-10-08',
  count: 1,
  lastPostRef: 'posts/p07',
  updatedAt: _updatedAt,
);

/// Yalnızca zorunlu alanları taşıyan belge verisi.
const Map<String, Object?> _minimalJson = {
  'clubId': 'c01',
  'day': '2026-10-08',
};

void main() {
  final table = ClubGroupPlanTable.read('9.6.18');

  group('T-09 · CounterModel', () {
    test('toJson → fromJson aynı modeli verir; updatedAt Timestamp olur', () {
      final json = _full.toJson();

      expect(CounterModel.fromJson(json, id: _full.id), _full);
      expect(table.jsonKeysOfType('DateTime'), {'updatedAt'});
      expect(json['updatedAt'], isA<Timestamp>());
      expect(json.values.whereType<FieldValue>(), isEmpty);
    });

    test('JSON anahtarları PLAN §9.6.18 tablosuyla aynıdır: id ve BaseFields '
        'alanları yoktur', () {
      final keys = _full.toJson().keys.toSet();

      expect(keys, table.jsonKeys);
      expect(keys, isNot(contains('isDeleted')));
    });

    test('eksik alanlar tablo varsayılanını alır; fazla anahtar ve verideki '
        'id yok sayılır', () {
      const clock = SystemAppClock();
      final now = DateTime.utc(2026, 10, 8, 21, 30);
      final built = CounterModel(clubId: 'c01', day: clock.istanbulDay(now));
      final model = CounterModel.fromJson(const {
        ..._minimalJson,
        'id': 'veri-icindeki-id',
        'createdAt': null,
      }, id: 'c01_20261009');

      expect(_minimalJson.keys.toSet(), table.requiredJsonKeys);
      expect(
        model,
        const CounterModel(
          id: 'c01_20261009',
          clubId: 'c01',
          day: '2026-10-08',
        ),
      );
      table.expectDefaults(
        {
          'id': built.id,
          'count': model.count,
          'lastPostRef': model.lastPostRef,
          'updatedAt': model.updatedAt,
        },
        codes: {
          'FirestoreIds.announcementCounter(clubId, dayKey)':
              FirestoreIds.announcementCounter(
                'c01',
                clock.istanbulDayKey(now),
              ),
        },
      );
    });

    test('belge kimliği verilmezse clubId ve day alanlarını izler', () {
      expect(
        const CounterModel(
          clubId: 'c01',
          day: '2026-10-08',
        ).copyWith(clubId: 'c02', day: '2026-12-31').id,
        FirestoreIds.announcementCounter('c02', '20261231'),
      );
      expect(_full.copyWith(day: '2026-12-31').id, 'c01_20261008');
    });

    test('remaining günlük limitten kullanılanı düşer', () {
      expect(
        CounterModel.fromJson(_minimalJson, id: 'c').remaining,
        Limits.announcementDailyLimit,
      );
      expect(_full.remaining, Limits.announcementDailyLimit - 1);
    });

    test('copyWith her alanı değiştirir; her alan eşitliğe girer', () {
      expect(_full.copyWith(), _full);
      expectFieldCases<CounterModel>(_full, [
        (
          field: 'id',
          copy: _full.copyWith(id: 'c02_20261008'),
          read: (m) => m.id,
          expected: 'c02_20261008',
        ),
        (
          field: 'clubId',
          copy: _full.copyWith(clubId: 'c02'),
          read: (m) => m.clubId,
          expected: 'c02',
        ),
        (
          field: 'day',
          copy: _full.copyWith(day: '2026-10-09'),
          read: (m) => m.day,
          expected: '2026-10-09',
        ),
        (
          field: 'count',
          copy: _full.copyWith(count: 2),
          read: (m) => m.count,
          expected: 2,
        ),
        (
          field: 'lastPostRef',
          copy: _full.copyWith(lastPostRef: 'posts/p09'),
          read: (m) => m.lastPostRef,
          expected: 'posts/p09',
        ),
        (
          field: 'updatedAt',
          copy: _full.copyWith(updatedAt: _otherTime),
          read: (m) => m.updatedAt,
          expected: _otherTime,
        ),
      ], fields: table.fields);
    });

    test('copyWith clear* bayrakları null olabilen her alanı null yapar', () {
      expectFieldCases<CounterModel>(_full, [
        (
          field: 'lastPostRef',
          copy: _full.copyWith(clearLastPostRef: true),
          read: (m) => m.lastPostRef,
          expected: null,
        ),
        (
          field: 'updatedAt',
          copy: _full.copyWith(clearUpdatedAt: true),
          read: (m) => m.updatedAt,
          expected: null,
        ),
      ], fields: table.nullableFields);
    });
  });
}
