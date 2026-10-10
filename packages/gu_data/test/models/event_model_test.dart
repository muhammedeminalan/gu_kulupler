// T-09 · EventModel: `events/{eventId}` belgesi — alan/JSON paritesi,
// varsayılanlar, gidiş-dönüş, ayrıştırma hataları, copyWith, eşitlik ve
// türetilmiş üyeler (PLAN §9.6.9, §9.10, §9.11; K-F, K-G).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:json_annotation/json_annotation.dart';

import '../fakes/fake_app_clock.dart';
import '../helpers/plan_field_table.dart';

final DateTime _startsAt = DateTime.utc(2026, 11, 5, 15);
final DateTime _endsAt = DateTime.utc(2026, 11, 5, 17, 30);
const Duration _tick = Duration(milliseconds: 1);

/// Her alanı varsayılanından farklı, null olabilen her alanı dolu etkinlik.
final EventModel _full = EventModel(
  id: 'e03',
  clubId: 'c01',
  createdBy: 'u_ayse',
  title: 'Flutter Atölyesi',
  desc: 'Uygulamalı atölye.',
  type: EventType.training,
  startsAt: _startsAt,
  endsAt: _endsAt,
  placeId: 'pl03',
  placeText: 'B Blok 204',
  capacity: 40,
  visibility: EventVisibility.membersOnly,
  status: EventStatus.cancelled,
  cancelReason: 'Salon uygun değil',
  coverSeed: 'event-ozel',
  coverPalette: ClubPalette.slate,
  coverPattern: ClubPattern.waves,
  coverPath: 'events/e03/20261008T201501Z_3f9a1c2b7d4e5f60.jpg',
  registrationOpen: false,
  autoReminder: false,
  goingCount: 30,
  waitlistCount: 4,
  attendedCount: 10,
  lastRsvpRef: 'rsvps/e03_u_ayse',
  publishedAt: DateTime.utc(2026, 10, 1, 9, 0, 0, 123),
  createdAt: DateTime.utc(2026, 9, 30, 8),
  updatedAt: DateTime.utc(2026, 10, 2, 8),
  isDeleted: true,
  deletedAt: DateTime.utc(2026, 10, 3, 8),
  deletedBy: 'u_admin',
);

/// Dart alan adı → değer (PLAN tablosunun "Alan" sütunu).
Map<String, Object?> _fields(EventModel m) => {
  'id': m.id,
  'clubId': m.clubId,
  'createdBy': m.createdBy,
  'title': m.title,
  'desc': m.desc,
  'type': m.type,
  'startsAt': m.startsAt,
  'endsAt': m.endsAt,
  'placeId': m.placeId,
  'placeText': m.placeText,
  'capacity': m.capacity,
  'visibility': m.visibility,
  'status': m.status,
  'cancelReason': m.cancelReason,
  'coverSeed': m.coverSeed,
  'coverPalette': m.coverPalette,
  'coverPattern': m.coverPattern,
  'coverPath': m.coverPath,
  'registrationOpen': m.registrationOpen,
  'autoReminder': m.autoReminder,
  'goingCount': m.goingCount,
  'waitlistCount': m.waitlistCount,
  'attendedCount': m.attendedCount,
  'lastRsvpRef': m.lastRsvpRef,
  'publishedAt': m.publishedAt,
  'createdAt': m.createdAt,
  'updatedAt': m.updatedAt,
  'isDeleted': m.isDeleted,
  'deletedAt': m.deletedAt,
  'deletedBy': m.deletedBy,
};

final DateTime _other = DateTime.utc(2027, 1, 2, 3, 4, 5);

/// Alan adı → (yalnızca o alanı değişmiş kopya, beklenen yeni değer).
final Map<String, (EventModel, Object?)> _changed = {
  'id': (_full.copyWith(id: 'e04'), 'e04'),
  'clubId': (_full.copyWith(clubId: 'c02'), 'c02'),
  'createdBy': (_full.copyWith(createdBy: 'u_can'), 'u_can'),
  'title': (_full.copyWith(title: 'Yeni'), 'Yeni'),
  'desc': (_full.copyWith(desc: 'Başka'), 'Başka'),
  'type': (_full.copyWith(type: EventType.trip), EventType.trip),
  'startsAt': (_full.copyWith(startsAt: _other), _other),
  'endsAt': (_full.copyWith(endsAt: _other), _other),
  'placeId': (_full.copyWith(placeId: 'pl01'), 'pl01'),
  'placeText': (_full.copyWith(placeText: 'Bahçe'), 'Bahçe'),
  'capacity': (_full.copyWith(capacity: 99), 99),
  'visibility': (
    _full.copyWith(visibility: EventVisibility.public),
    EventVisibility.public,
  ),
  'status': (
    _full.copyWith(status: EventStatus.published),
    EventStatus.published,
  ),
  'cancelReason': (_full.copyWith(cancelReason: 'Hava'), 'Hava'),
  'coverSeed': (_full.copyWith(coverSeed: 'event-x'), 'event-x'),
  'coverPalette': (
    _full.copyWith(coverPalette: ClubPalette.red),
    ClubPalette.red,
  ),
  'coverPattern': (
    _full.copyWith(coverPattern: ClubPattern.dots),
    ClubPattern.dots,
  ),
  'coverPath': (
    _full.copyWith(coverPath: 'events/e03/x'),
    'events/e03/x',
  ),
  'registrationOpen': (_full.copyWith(registrationOpen: true), true),
  'autoReminder': (_full.copyWith(autoReminder: true), true),
  'goingCount': (_full.copyWith(goingCount: 31), 31),
  'waitlistCount': (_full.copyWith(waitlistCount: 5), 5),
  'attendedCount': (_full.copyWith(attendedCount: 11), 11),
  'lastRsvpRef': (_full.copyWith(lastRsvpRef: 'rsvps/x'), 'rsvps/x'),
  'publishedAt': (_full.copyWith(publishedAt: _other), _other),
  'createdAt': (_full.copyWith(createdAt: _other), _other),
  'updatedAt': (_full.copyWith(updatedAt: _other), _other),
  'isDeleted': (_full.copyWith(isDeleted: false), false),
  'deletedAt': (_full.copyWith(deletedAt: _other), _other),
  'deletedBy': (_full.copyWith(deletedBy: 'u_can'), 'u_can'),
};

/// Alan adı → yalnızca o alanı `null`'a çekilmiş kopya.
final Map<String, EventModel> _nulled = {
  'createdBy': _full.copyWith(clearCreatedBy: true),
  'placeId': _full.copyWith(clearPlaceId: true),
  'placeText': _full.copyWith(clearPlaceText: true),
  'capacity': _full.copyWith(clearCapacity: true),
  'cancelReason': _full.copyWith(clearCancelReason: true),
  'coverPath': _full.copyWith(clearCoverPath: true),
  'lastRsvpRef': _full.copyWith(clearLastRsvpRef: true),
  'publishedAt': _full.copyWith(clearPublishedAt: true),
  'createdAt': _full.copyWith(clearCreatedAt: true),
  'updatedAt': _full.copyWith(clearUpdatedAt: true),
  'deletedAt': _full.copyWith(clearDeletedAt: true),
  'deletedBy': _full.copyWith(clearDeletedBy: true),
};

Map<String, Object?> _without(Map<String, Object?> map, String key) =>
    {...map}..remove(key);

void main() {
  final table = PlanFieldTable.read('#### 9.6.9 ');

  group('T-09 · EventModel · PLAN §9.6.9 tablosu', () {
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
      final minimal = EventModel.fromJson({
        for (final key in table.requiredJsonKeys) key: json[key],
        'bilinmeyenAlan': 1,
      }, id: 'e03');

      final fields = _fields(minimal);
      for (final field in table.fields) {
        final code = field.defaultCode;
        if (code == null) continue;
        expect(
          fields[field.name],
          matchesPlanDefault(
            code,
            computed: {
              'FirestoreIds.eventCoverSeed(id)': FirestoreIds.eventCoverSeed(
                'e03',
              ),
            },
          ),
          reason: field.name,
        );
      }
      expect(minimal.toJson().values, isNot(contains(null)));
    });
  });

  group('T-09 · EventModel · JSON', () {
    test('toJson → fromJson eşit model verir; zamanlar Timestamp ↔ UTC '
        'DateTime, enum JSON değeriyle yazılır, FieldValue üretilmez', () {
      final json = _full.toJson();

      for (final key in table.jsonKeysOfType('DateTime')) {
        expect(json[key], isA<Timestamp>(), reason: key);
      }
      expect(json[FirestoreFields.type], 'egitim');
      expect(json[FirestoreFields.visibility], 'members');
      expect(json.values.whereType<FieldValue>(), isEmpty);

      final back = EventModel.fromJson(json, id: _full.id);
      expect(back, _full);
      expect(
        [
          back.startsAt,
          back.endsAt,
          back.publishedAt,
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
          () => EventModel.fromJson(_without(json, key), id: 'e03'),
          failsAt(key),
          reason: key,
        );
      }
      expect(
        () => EventModel.fromJson({
          ...json,
          FirestoreFields.status: 'archived',
        }, id: 'e03'),
        failsAt(FirestoreFields.status),
      );
    });
  });

  group('T-09 · EventModel · copyWith ve eşitlik', () {
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
      expect(_full.copyWith(capacity: 5, clearCapacity: true).capacity, isNull);
    });

    test('props tüm alanları içerir: tek alan farkı eşitliği bozar', () {
      for (final MapEntry(key: name, value: (copy, _)) in _changed.entries) {
        expect(copy, isNot(_full), reason: name);
      }
    });
  });

  group('T-09 · EventModel · türetilmiş üyeler', () {
    test('isPast: bitiş anından sonra geçmiştir (bitiş anı dahil değil)', () {
      expect(_full.isPast(FakeAppClock(_endsAt)), isFalse);
      expect(_full.isPast(FakeAppClock(_endsAt.add(_tick))), isTrue);
    });

    test('isFull: katılımcı kontenjana ulaşınca dolar; sınırsız etkinlik '
        'dolmaz', () {
      expect(_full.copyWith(goingCount: 39).isFull, isFalse);
      expect(_full.copyWith(goingCount: 40).isFull, isTrue);
      expect(
        _full.copyWith(goingCount: 40, clearCapacity: true).isFull,
        isFalse,
      );
    });

    test('attendanceRate: attendedCount / goingCount — goingCount yoklaması '
        'alınanları da içerir (CD-130); kayıtlı yoksa 0', () {
      // 40 kayıtlının 10'u okutuldu.
      expect(
        _full.copyWith(goingCount: 40, attendedCount: 10).attendanceRate,
        0.25,
      );
      // Kayıtlıların tümü katıldıysa oran tamdır (yarım değil).
      expect(
        _full.copyWith(goingCount: 10, attendedCount: 10).attendanceRate,
        1,
      );
      expect(_full.copyWith(goingCount: 0, attendedCount: 0).attendanceRate, 0);
    });

    test('attendanceWindow: başlangıçtan 2 sa önce açılır, bitişten 6 sa '
        'sonra kapanır; uçlar dahil (K-G)', () {
      final opensAt = _startsAt.subtract(Limits.attendanceWindowBefore);
      final closesAt = _endsAt.add(Limits.attendanceWindowAfter);
      bool inWindow(DateTime now) => _full.attendanceWindow(FakeAppClock(now));

      expect(inWindow(opensAt.subtract(_tick)), isFalse);
      expect(inWindow(opensAt), isTrue);
      expect(inWindow(closesAt), isTrue);
      expect(inWindow(closesAt.add(_tick)), isFalse);
    });

    test('canUnpublish: yalnızca kayıtlı katılımcı yokken (K-F)', () {
      expect(_full.copyWith(goingCount: 0).canUnpublish, isTrue);
      expect(_full.copyWith(goingCount: 1).canUnpublish, isFalse);
    });
  });
}
