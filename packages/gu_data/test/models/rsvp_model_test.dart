// T-09 · RsvpModel: `rsvps/{eventId}_{userId}` belgesi — alan/JSON paritesi,
// varsayılanlar, gidiş-dönüş, ayrıştırma hataları, copyWith, eşitlik ve
// türetilmiş üyeler (PLAN §9.6.10, §9.10, §9.11; domain-model §8; D-30).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:json_annotation/json_annotation.dart';

import '../fakes/fake_app_clock.dart';
import '../helpers/plan_field_table.dart';

const String _ticketCode = 'GU-7K3Q-9XAB';
final DateTime _eventEndsAt = DateTime.utc(2026, 11, 5, 17);

/// Her alanı varsayılanından farklı, null olabilen her alanı dolu kayıt.
final RsvpModel _full = RsvpModel(
  id: 'e03_u_ayse',
  eventId: 'e03',
  clubId: 'c01',
  userId: 'u_ayse',
  status: RsvpStatus.attended,
  reminder: ReminderOption.fifteenMinutes,
  ticketCode: _ticketCode,
  waitlistAt: DateTime.utc(2026, 10, 20, 9, 0, 0, 123),
  scannedAt: DateTime.utc(2026, 11, 5, 15, 2),
  scannedBy: 'u_baskan',
  createdAt: DateTime.utc(2026, 10, 19, 8),
  updatedAt: DateTime.utc(2026, 11, 5, 15, 2),
  isDeleted: true,
  deletedAt: DateTime.utc(2026, 11, 6, 8),
  deletedBy: 'u_admin',
);

/// Dart alan adı → değer (PLAN tablosunun "Alan" sütunu).
Map<String, Object?> _fields(RsvpModel m) => {
  'id': m.id,
  'eventId': m.eventId,
  'clubId': m.clubId,
  'userId': m.userId,
  'status': m.status,
  'reminder': m.reminder,
  'ticketCode': m.ticketCode,
  'waitlistAt': m.waitlistAt,
  'scannedAt': m.scannedAt,
  'scannedBy': m.scannedBy,
  'createdAt': m.createdAt,
  'updatedAt': m.updatedAt,
  'isDeleted': m.isDeleted,
  'deletedAt': m.deletedAt,
  'deletedBy': m.deletedBy,
};

final DateTime _other = DateTime.utc(2027, 1, 2, 3, 4, 5);

/// Alan adı → (yalnızca o alanı değişmiş kopya, beklenen yeni değer).
final Map<String, (RsvpModel, Object?)> _changed = {
  'id': (_full.copyWith(id: 'baska'), 'baska'),
  'eventId': (_full.copyWith(eventId: 'e04'), 'e04'),
  'clubId': (_full.copyWith(clubId: 'c02'), 'c02'),
  'userId': (_full.copyWith(userId: 'u_can'), 'u_can'),
  'status': (_full.copyWith(status: RsvpStatus.waitlist), RsvpStatus.waitlist),
  'reminder': (
    _full.copyWith(reminder: ReminderOption.oneDay),
    ReminderOption.oneDay,
  ),
  'ticketCode': (_full.copyWith(ticketCode: 'GU-AAAA-BBBB'), 'GU-AAAA-BBBB'),
  'waitlistAt': (_full.copyWith(waitlistAt: _other), _other),
  'scannedAt': (_full.copyWith(scannedAt: _other), _other),
  'scannedBy': (_full.copyWith(scannedBy: 'u_can'), 'u_can'),
  'createdAt': (_full.copyWith(createdAt: _other), _other),
  'updatedAt': (_full.copyWith(updatedAt: _other), _other),
  'isDeleted': (_full.copyWith(isDeleted: false), false),
  'deletedAt': (_full.copyWith(deletedAt: _other), _other),
  'deletedBy': (_full.copyWith(deletedBy: 'u_can'), 'u_can'),
};

/// Alan adı → yalnızca o alanı `null`'a çekilmiş kopya.
final Map<String, RsvpModel> _nulled = {
  'waitlistAt': _full.copyWith(clearWaitlistAt: true),
  'scannedAt': _full.copyWith(clearScannedAt: true),
  'scannedBy': _full.copyWith(clearScannedBy: true),
  'createdAt': _full.copyWith(clearCreatedAt: true),
  'updatedAt': _full.copyWith(clearUpdatedAt: true),
  'deletedAt': _full.copyWith(clearDeletedAt: true),
  'deletedBy': _full.copyWith(clearDeletedBy: true),
};

Map<String, Object?> _without(Map<String, Object?> map, String key) =>
    {...map}..remove(key);

/// [_full] kaydının etkinliği.
EventModel _event({EventStatus status = EventStatus.published}) => EventModel(
  id: 'e03',
  clubId: 'c01',
  title: 'Flutter Atölyesi',
  type: EventType.training,
  startsAt: DateTime.utc(2026, 11, 5, 15),
  endsAt: _eventEndsAt,
  coverPalette: ClubPalette.red,
  coverPattern: ClubPattern.dots,
  status: status,
);

void main() {
  final table = PlanFieldTable.read('#### 9.6.10 ');
  const computed = {
    'FirestoreIds.rsvp(eventId, userId)': 'e03_u_ayse',
  };

  group('T-09 · RsvpModel · PLAN §9.6.10 tablosu', () {
    test('alan kümesi, tipler ve JSON anahtarları tabloyla birebir; kimlik '
        "JSON'a girmez", () {
      final fields = _fields(_full);

      expect(fields.keys.toSet(), table.names);
      for (final field in table.fields) {
        expect(
          '${fields[field.name].runtimeType}',
          field.type.replaceAll('?', ''),
          reason: field.name,
        );
      }
      expect(_full.toJson().keys.toSet(), table.jsonKeys);
    });

    test('yalnızca zorunlu alanlarla fromJson tablo varsayılanlarını verir; '
        'tanınmayan anahtar yok sayılır, null alan yazılmaz', () {
      final json = _full.toJson();
      final minimal = RsvpModel.fromJson({
        for (final key in table.requiredJsonKeys) key: json[key],
        'bilinmeyenAlan': 1,
      }, id: 'e03_u_ayse');

      final fields = _fields(minimal);
      for (final field in table.fields) {
        final code = field.defaultCode;
        if (code == null) continue;
        expect(
          fields[field.name],
          matchesPlanDefault(code, computed: computed),
          reason: field.name,
        );
      }
      expect(minimal.toJson().values, isNot(contains(null)));
    });

    test('kimlik verilmezse FirestoreIds.rsvp(eventId, userId) olur', () {
      const rsvp = RsvpModel(
        eventId: 'e03',
        clubId: 'c01',
        userId: 'u_ayse',
        ticketCode: _ticketCode,
      );

      expect(rsvp.id, FirestoreIds.rsvp('e03', 'u_ayse'));
      expect(rsvp.id, computed.values.single);
    });
  });

  group('T-09 · RsvpModel · JSON', () {
    test('toJson → fromJson eşit model verir; zamanlar Timestamp ↔ UTC '
        'DateTime, enum JSON değeriyle yazılır, FieldValue üretilmez', () {
      final json = _full.toJson();

      for (final key in table.jsonKeysOfType('DateTime')) {
        expect(json[key], isA<Timestamp>(), reason: key);
      }
      expect(json[FirestoreFields.status], 'attended');
      expect(json[FirestoreFields.reminder], '15m');
      expect(json.values.whereType<FieldValue>(), isEmpty);

      final back = RsvpModel.fromJson(json, id: _full.id);
      expect(back, _full);
      expect(
        [
          back.waitlistAt,
          back.scannedAt,
          back.createdAt,
          back.updatedAt,
          back.deletedAt,
        ].every((time) => time!.isUtc),
        isTrue,
      );
    });

    test('eksik zorunlu alan ve bilinmeyen enum değeri '
        'CheckedFromJsonException verir (alan adıyla)', () {
      final json = _full.toJson();
      Matcher failsAt(String key) => throwsA(
        isA<CheckedFromJsonException>().having((e) => e.key, 'key', key),
      );

      for (final key in table.requiredJsonKeys) {
        expect(
          () => RsvpModel.fromJson(_without(json, key), id: _full.id),
          failsAt(key),
          reason: key,
        );
      }
      expect(
        () => RsvpModel.fromJson({
          ...json,
          FirestoreFields.reminder: '2h',
        }, id: _full.id),
        failsAt(FirestoreFields.reminder),
      );
    });
  });

  group('T-09 · RsvpModel · copyWith ve eşitlik', () {
    test('copyWith her alanı tek başına değiştirir, diğerlerine dokunmaz', () {
      expect(_changed.keys.toSet(), table.names);
      for (final MapEntry(key: name, value: (copy, value))
          in _changed.entries) {
        expect(_fields(copy)[name], value, reason: name);
        expect(
          _without(_fields(copy), name),
          _without(_fields(_full), name),
          reason: name,
        );
      }
      expect(_full.copyWith(), _full);
    });

    test("copyWith clear… bayrağıyla null olabilen her alanı null'a çeker "
        '(tablonun Null sütunu); bayrak verilen değerden önce gelir', () {
      expect(_nulled.keys.toSet(), table.nullableNames);
      for (final MapEntry(key: name, value: copy) in _nulled.entries) {
        expect(_fields(copy)[name], isNull, reason: name);
        expect(
          _without(_fields(copy), name),
          _without(_fields(_full), name),
          reason: name,
        );
      }
      expect(
        _full.copyWith(scannedBy: 'u_can', clearScannedBy: true).scannedBy,
        isNull,
      );
    });

    test('props tüm alanları içerir: tek alan farkı eşitliği bozar', () {
      for (final MapEntry(key: name, value: (copy, _)) in _changed.entries) {
        expect(copy, isNot(_full), reason: name);
      }
    });

    test('createdBy taşımaz', () {
      expect(_full.createdBy, isNull);
    });
  });

  group('T-09 · RsvpModel · türetilmiş üyeler', () {
    test('ticketState: going geçerli, attended kullanılmış; vazgeçilmiş, '
        'bekleyen ya da iptal edilmiş etkinliğin bileti geçersiz', () {
      TicketState state(RsvpStatus rsvp, EventStatus event) =>
          _full.copyWith(status: rsvp).ticketState(_event(status: event));

      expect(
        {
          for (final status in RsvpStatus.values)
            status: state(status, EventStatus.published),
        },
        {
          RsvpStatus.going: TicketState.valid,
          RsvpStatus.waitlist: TicketState.voided,
          RsvpStatus.attended: TicketState.used,
          RsvpStatus.cancelled: TicketState.voided,
        },
      );
      for (final status in RsvpStatus.values) {
        expect(
          state(status, EventStatus.cancelled),
          TicketState.voided,
          reason: status.name,
        );
      }
    });

    test('isAbsent: etkinlik bitti ve kayıt hâlâ going', () {
      final ended = FakeAppClock(_eventEndsAt.add(const Duration(minutes: 1)));
      final ongoing = FakeAppClock(_eventEndsAt);
      final going = _full.copyWith(status: RsvpStatus.going);

      expect(going.isAbsent(_event(), ended), isTrue);
      expect(going.isAbsent(_event(), ongoing), isFalse);
      expect(_full.isAbsent(_event(), ended), isFalse);
    });

    test('qrPayload: gu:ticket:v1:{eventId}:{ticketCode} (D-30)', () {
      expect(_full.qrPayload, 'gu:ticket:v1:e03:GU-7K3Q-9XAB');
    });
  });
}
