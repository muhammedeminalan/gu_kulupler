// T-09 · NotificationModel + NotificationRefsModel: `notifications/{id}`
// belgesi ve gömülü `refs` nesnesi — alan/JSON paritesi, varsayılanlar,
// gidiş-dönüş, ileri uyumluluk, copyWith, eşitlik, tür → zorunlu referans
// (PLAN §9.6.11, §9.10, §9.11; domain-model §2.9, §6).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:json_annotation/json_annotation.dart';

import '../helpers/plan_field_table.dart';
import '../helpers/repo_sources.dart';

/// Her alanı dolu referans nesnesi.
const NotificationRefsModel _refs = NotificationRefsModel(
  clubId: 'c01',
  eventId: 'e03',
  postId: 'p07',
  applicantId: 'u_can',
  reportId: 'u_can_post_p07',
  role: ClubRole.board,
  textKey: 'welcome',
);

/// Her alanı varsayılanından farklı, null olabilen her alanı dolu bildirim.
final NotificationModel _full = NotificationModel(
  id: 'event_new_e03_u_ayse',
  userId: 'u_ayse',
  type: NotificationType.eventNew,
  refs: _refs,
  read: true,
  createdAt: DateTime.utc(2026, 10, 1, 9, 0, 0, 123),
  updatedAt: DateTime.utc(2026, 10, 2, 8),
  isDeleted: true,
  deletedAt: DateTime.utc(2026, 10, 3, 8),
  deletedBy: 'u_ayse',
);

/// Dart alan adı → değer (PLAN tablosunun "Alan" sütunu).
Map<String, Object?> _fields(NotificationModel m) => {
  'id': m.id,
  'userId': m.userId,
  'type': m.type,
  'refs': m.refs,
  'read': m.read,
  'createdAt': m.createdAt,
  'updatedAt': m.updatedAt,
  'isDeleted': m.isDeleted,
  'deletedAt': m.deletedAt,
  'deletedBy': m.deletedBy,
};

/// Dart alan adı → değer (PLAN §9.6.11 `NotificationRefsModel` satırı).
Map<String, Object?> _refFields(NotificationRefsModel m) => {
  'clubId': m.clubId,
  'eventId': m.eventId,
  'postId': m.postId,
  'applicantId': m.applicantId,
  'reportId': m.reportId,
  'role': m.role,
  'textKey': m.textKey,
};

final DateTime _other = DateTime.utc(2027, 1, 2, 3, 4, 5);
const NotificationRefsModel _otherRefs = NotificationRefsModel(clubId: 'c02');

/// Alan adı → (yalnızca o alanı değişmiş kopya, beklenen yeni değer).
final Map<String, (NotificationModel, Object?)> _changed = {
  'id': (_full.copyWith(id: 'baska'), 'baska'),
  'userId': (_full.copyWith(userId: 'u_can'), 'u_can'),
  'type': (
    _full.copyWith(type: NotificationType.system),
    NotificationType.system,
  ),
  'refs': (_full.copyWith(refs: _otherRefs), _otherRefs),
  'read': (_full.copyWith(read: false), false),
  'createdAt': (_full.copyWith(createdAt: _other), _other),
  'updatedAt': (_full.copyWith(updatedAt: _other), _other),
  'isDeleted': (_full.copyWith(isDeleted: false), false),
  'deletedAt': (_full.copyWith(deletedAt: _other), _other),
  'deletedBy': (_full.copyWith(deletedBy: 'u_can'), 'u_can'),
};

/// Alan adı → yalnızca o alanı `null`'a çekilmiş kopya.
final Map<String, NotificationModel> _nulled = {
  'createdAt': _full.copyWith(clearCreatedAt: true),
  'updatedAt': _full.copyWith(clearUpdatedAt: true),
  'deletedAt': _full.copyWith(clearDeletedAt: true),
  'deletedBy': _full.copyWith(clearDeletedBy: true),
};

/// Referans alanı → (yalnızca o alanı değişmiş kopya, beklenen yeni değer).
final Map<String, (NotificationRefsModel, Object?)> _changedRefs = {
  'clubId': (_refs.copyWith(clubId: 'c02'), 'c02'),
  'eventId': (_refs.copyWith(eventId: 'e04'), 'e04'),
  'postId': (_refs.copyWith(postId: 'p08'), 'p08'),
  'applicantId': (_refs.copyWith(applicantId: 'u_ali'), 'u_ali'),
  'reportId': (_refs.copyWith(reportId: 'r2'), 'r2'),
  'role': (_refs.copyWith(role: ClubRole.president), ClubRole.president),
  'textKey': (_refs.copyWith(textKey: 'maintenance'), 'maintenance'),
};

/// Referans alanı → yalnızca o alanı `null`'a çekilmiş kopya.
final Map<String, NotificationRefsModel> _nulledRefs = {
  'clubId': _refs.copyWith(clearClubId: true),
  'eventId': _refs.copyWith(clearEventId: true),
  'postId': _refs.copyWith(clearPostId: true),
  'applicantId': _refs.copyWith(clearApplicantId: true),
  'reportId': _refs.copyWith(clearReportId: true),
  'role': _refs.copyWith(clearRole: true),
  'textKey': _refs.copyWith(clearTextKey: true),
};

Map<String, Object?> _without(Map<String, Object?> map, String key) =>
    {...map}..remove(key);

/// PLAN §9.6.11'deki `NotificationRefsModel` satırından alan adı → tip.
///
/// Satır biçimi: `` `NotificationRefsModel` (`dosya`): `ad` (`Tip`…) · … .
/// Tür → zorunlu ref … ``. Satır ya da alan listesi bulunamazsa [StateError].
Map<String, String> _planRefFields() {
  const lead =
      '`NotificationRefsModel` (`models/notification_refs_model.dart`): ';
  final line = readRepoFile(
    'docs/PLAN.md',
  ).split('\n').singleWhere((line) => line.startsWith(lead));
  final list = line.substring(lead.length).split('. Tür → zorunlu ref').first;
  return {
    for (final part in list.split(' · '))
      codeSpans(part)[0]: codeSpans(part)[1],
  };
}

void main() {
  final table = PlanFieldTable.read('#### 9.6.11 ');

  group('T-09 · NotificationModel · PLAN §9.6.11 tablosu', () {
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
      final minimal = NotificationModel.fromJson({
        for (final key in table.requiredJsonKeys) key: json[key],
        'bilinmeyenAlan': 1,
      }, id: _full.id);

      final fields = _fields(minimal);
      for (final field in table.fields) {
        final code = field.defaultCode;
        if (code == null) continue;
        expect(
          fields[field.name],
          matchesPlanDefault(
            code,
            computed: const {
              'const NotificationRefsModel()': NotificationRefsModel(),
            },
          ),
          reason: field.name,
        );
      }
      expect(minimal.toJson().values, isNot(contains(null)));
      expect(minimal.toJson()[FirestoreFields.refs], isEmpty);
    });

    test(
      'refs alanları ve tipleri NotificationRefsModel satırıyla birebir',
      () {
        final plan = _planRefFields();
        final fields = _refFields(_refs);

        expect(fields.keys.toSet(), plan.keys.toSet());
        for (final MapEntry(key: name, value: type) in plan.entries) {
          expect(
            '${fields[name].runtimeType}',
            type.replaceAll('?', ''),
            reason: name,
          );
        }
        expect(_refs.toJson().keys.toSet(), plan.keys.toSet());
      },
    );
  });

  group('T-09 · NotificationModel · JSON', () {
    test('toJson → fromJson eşit model verir; zamanlar Timestamp ↔ UTC '
        'DateTime, refs iç içe Map olarak yazılır, FieldValue üretilmez', () {
      final json = _full.toJson();

      for (final key in table.jsonKeysOfType('DateTime')) {
        expect(json[key], isA<Timestamp>(), reason: key);
      }
      expect(json[FirestoreFields.type], 'event_new');
      expect(
        json[FirestoreFields.refs],
        isA<Map<String, Object?>>().having(
          (refs) => refs[FirestoreFields.role],
          'role',
          'board',
        ),
      );
      expect(json.values.whereType<FieldValue>(), isEmpty);

      final back = NotificationModel.fromJson(json, id: _full.id);
      expect(back, _full);
      expect(
        [
          back.createdAt,
          back.updatedAt,
          back.deletedAt,
        ].every((time) => time!.isUtc),
        isTrue,
      );
    });

    test('eksik zorunlu alan CheckedFromJsonException verir (alan adıyla)', () {
      final json = _full.toJson();

      for (final key in table.requiredJsonKeys) {
        expect(
          () => NotificationModel.fromJson(_without(json, key), id: _full.id),
          throwsA(
            isA<CheckedFromJsonException>().having((e) => e.key, 'key', key),
          ),
          reason: key,
        );
      }
    });

    test('ileri uyumluluk: tanınmayan tür unknown, tanınmayan refs.role '
        'null okunur', () {
      final json = _full.toJson();
      final refs = json[FirestoreFields.refs]! as Map<String, Object?>;

      final parsed = NotificationModel.fromJson({
        ...json,
        FirestoreFields.type: 'club_anniversary',
        FirestoreFields.refs: {...refs, FirestoreFields.role: 'treasurer'},
      }, id: _full.id);

      expect(parsed.type, NotificationType.unknown);
      expect(parsed.refs, _refs.copyWith(clearRole: true));
    });
  });

  group('T-09 · NotificationModel · copyWith ve eşitlik', () {
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
        _full.copyWith(deletedBy: 'u_can', clearDeletedBy: true).deletedBy,
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

  group('T-09 · NotificationRefsModel · copyWith ve eşitlik', () {
    test("copyWith her alanı tek başına değiştirir; clear… bayrağıyla null'a "
        'çeker (bayrak verilen değerden önce gelir)', () {
      final all = _refFields(_refs);

      expect(_changedRefs.keys.toSet(), all.keys.toSet());
      for (final MapEntry(key: name, value: (copy, value))
          in _changedRefs.entries) {
        expect(_refFields(copy)[name], value, reason: name);
        expect(
          _without(_refFields(copy), name),
          _without(all, name),
          reason: name,
        );
      }
      expect(_nulledRefs.keys.toSet(), all.keys.toSet());
      for (final MapEntry(key: name, value: copy) in _nulledRefs.entries) {
        expect(_refFields(copy)[name], isNull, reason: name);
        expect(
          _without(_refFields(copy), name),
          _without(all, name),
          reason: name,
        );
      }
      expect(_refs.copyWith(), _refs);
      expect(
        _refs.copyWith(role: ClubRole.member, clearRole: true).role,
        isNull,
      );
    });

    test('props tüm alanları içerir: tek alan farkı eşitliği bozar', () {
      for (final MapEntry(key: name, value: (copy, _))
          in _changedRefs.entries) {
        expect(copy, isNot(_refs), reason: name);
      }
    });
  });

  group('T-09 · NotificationModel · türetilmiş üyeler', () {
    test('category türün kategorisidir; tanınmayan türde null', () {
      for (final type in NotificationType.values) {
        expect(
          _full.copyWith(type: type).category,
          type.category,
          reason: type.name,
        );
      }
      expect(_full.copyWith(type: NotificationType.unknown).category, isNull);
    });

    test('requiredFor: tür → zorunlu referans alanları (PLAN §9.6.11)', () {
      const club = FirestoreFields.clubId;
      const event = FirestoreFields.eventId;

      expect(
        {
          for (final type in NotificationType.values)
            type: NotificationRefsModel.requiredFor(type),
        },
        {
          NotificationType.applicationReceived: {
            club,
            FirestoreFields.applicantId,
          },
          NotificationType.applicationApproved: {club},
          NotificationType.applicationRejected: {club},
          NotificationType.removedFromClub: {club},
          NotificationType.roleChanged: {club, FirestoreFields.role},
          NotificationType.announcement: {club, FirestoreFields.postId},
          NotificationType.eventNew: {club, event},
          NotificationType.eventReminder: {club, event},
          NotificationType.eventCancelled: {club, event},
          NotificationType.waitlistPromoted: {club, event},
          NotificationType.reportResolved: {FirestoreFields.reportId},
          NotificationType.newReport: {FirestoreFields.reportId},
          NotificationType.system: {FirestoreFields.textKey},
          NotificationType.unknown: <String>{},
        },
      );
    });
  });
}
