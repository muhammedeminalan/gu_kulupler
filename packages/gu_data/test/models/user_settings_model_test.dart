// T-09 · UserSettingsModel + gömülü ClubNotificationPrefsModel (PLAN §9.6.14):
// JSON anahtar kümeleri ↔ PLAN, iç içe map (explicit_to_json), Timestamp ↔
// UTC DateTime gidiş-dönüşü, tablo varsayılanları ve `defaults` fabrikası,
// ayrıştırma toleransı, copyWith + eşitlik (alan başına).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:json_annotation/json_annotation.dart';

import '../helpers/plan_model_keys_user_group.dart';

void main() {
  final updatedAt = DateTime.utc(2026, 10, 8, 20, 15, 1, 456);
  final later = DateTime.utc(2027, 1, 2, 3, 4, 5, 6);

  // Her alanı varsayılanından farklı.
  const prefs = ClubNotificationPrefsModel(
    announcements: false,
    events: false,
    posts: false,
    muted: true,
  );

  // Her alan varsayılanından farklı, null olabilen alan dolu.
  final full = UserSettingsModel(
    uid: 'u_zeynep',
    announcements: false,
    eventReminders: false,
    newEvents: false,
    applicationResults: false,
    management: false,
    system: false,
    reminderTime: ReminderOption.oneDay,
    quiet: true,
    quietFrom: '23:30',
    quietTo: '07:15',
    clubs: const {'c07': prefs},
    updatedAt: updatedAt,
  );

  const defaults = UserSettingsModel.defaults('u1');

  group('T-09 · UserSettingsModel · JSON', () {
    test('toJson anahtarları PLAN §9.6.14 tablosuyla aynıdır; belge kimliği '
        've FieldValue yazılmaz', () {
      final json = full.toJson();

      expect(json.keys.toSet(), planJsonKeys('9.6.14'));
      expect(json.values, isNot(contains(full.uid)));
      expect(json.values.whereType<FieldValue>(), isEmpty);
    });

    test('clubs değerleri map olarak yazılır; anahtarları PLAN '
        'ClubNotificationPrefsModel tanımıyla aynıdır', () {
      final clubs =
          full.toJson()[FirestoreFields.clubs]! as Map<String, Object?>;

      expect(clubs.keys, ['c07']);
      expect(
        (clubs['c07']! as Map<String, Object?>).keys.toSet(),
        planEmbeddedKeys('ClubNotificationPrefsModel'),
      );
    });

    test('gidiş-dönüş: updatedAt Timestamp, reminderTime JSON değeri olarak '
        'yazılır ve aynı model okunur', () {
      final json = full.toJson();

      expect(json[FirestoreFields.updatedAt], Timestamp.fromDate(updatedAt));
      expect(json[FirestoreFields.reminderTime], '1d');
      // DateTime eşitliği anı ve isUtc'yi birlikte karşılaştırır.
      expect(UserSettingsModel.fromJson(json, id: full.uid), full);
    });

    test('defaults tablo varsayılanlarını taşır', () {
      expect(defaults.uid, 'u1');
      expect(defaults.announcements, isTrue);
      expect(defaults.eventReminders, isTrue);
      expect(defaults.newEvents, isTrue);
      expect(defaults.applicationResults, isTrue);
      expect(defaults.management, isTrue);
      expect(defaults.system, isTrue);
      expect(defaults.reminderTime, ReminderOption.oneHour);
      expect(defaults.quiet, isFalse);
      expect(defaults.quietFrom, Limits.quietFromDefault);
      expect(defaults.quietTo, Limits.quietToDefault);
      expect(defaults.clubs, isEmpty);
      expect(defaults.updatedAt, isNull);
    });

    test('defaults.toJson null updatedAt dışındaki tüm tablo anahtarlarını '
        'yazar', () {
      expect(
        defaults.toJson().keys.toSet(),
        planJsonKeys('9.6.14').difference({FirestoreFields.updatedAt}),
      );
    });

    test('boş belge defaults ile aynı modeli verir; tanınmayan anahtar yok '
        'sayılır', () {
      expect(
        UserSettingsModel.fromJson(const {'bilinmeyenAlan': 1}, id: 'u1'),
        defaults,
      );
    });

    test('bilinmeyen reminderTime CheckedFromJsonException fırlatır', () {
      expect(
        () => UserSettingsModel.fromJson(const {
          FirestoreFields.reminderTime: '2h',
        }, id: 'u1'),
        throwsA(
          isA<CheckedFromJsonException>().having(
            (e) => e.key,
            'key',
            FirestoreFields.reminderTime,
          ),
        ),
      );
    });
  });

  group('T-09 · UserSettingsModel · copyWith ve eşitlik', () {
    test('parametresiz copyWith aynı modeli verir; props 13 alan taşır', () {
      expect(full.copyWith(), full);
      expect(full.props, hasLength(13));
    });

    test('her alan copyWith ile değişir ve eşitliğe girer', () {
      void check<V>(
        UserSettingsModel changed,
        V Function(UserSettingsModel) read,
        V value,
      ) => expectFieldChange(full, changed, read, value);

      check(full.copyWith(uid: 'u2'), (m) => m.uid, 'u2');
      check(
        full.copyWith(announcements: true),
        (m) => m.announcements,
        true,
      );
      check(
        full.copyWith(eventReminders: true),
        (m) => m.eventReminders,
        true,
      );
      check(full.copyWith(newEvents: true), (m) => m.newEvents, true);
      check(
        full.copyWith(applicationResults: true),
        (m) => m.applicationResults,
        true,
      );
      check(full.copyWith(management: true), (m) => m.management, true);
      check(full.copyWith(system: true), (m) => m.system, true);
      check(
        full.copyWith(reminderTime: ReminderOption.oneHour),
        (m) => m.reminderTime,
        ReminderOption.oneHour,
      );
      check(full.copyWith(quiet: false), (m) => m.quiet, false);
      check(full.copyWith(quietFrom: '21:00'), (m) => m.quietFrom, '21:00');
      check(full.copyWith(quietTo: '09:00'), (m) => m.quietTo, '09:00');
      check(
        full.copyWith(clubs: const {}),
        (m) => m.clubs,
        const <String, ClubNotificationPrefsModel>{},
      );
      check(full.copyWith(updatedAt: later), (m) => m.updatedAt, later);
    });

    test('clearUpdatedAt alanı boşaltır ve verilen değerden önce gelir', () {
      void check(UserSettingsModel changed) =>
          expectFieldChange<UserSettingsModel, DateTime?>(
            full,
            changed,
            (m) => m.updatedAt,
            null,
          );

      check(full.copyWith(clearUpdatedAt: true));
      check(full.copyWith(updatedAt: later, clearUpdatedAt: true));
    });

    test('BaseFields taşımaz', () {
      expect(full, isNot(isA<BaseFields>()));
    });
  });

  group('T-09 · ClubNotificationPrefsModel', () {
    test('boş map tablo varsayılanlarını verir', () {
      final model = ClubNotificationPrefsModel.fromJson(const {});

      expect(model.announcements, isTrue);
      expect(model.events, isTrue);
      expect(model.posts, isTrue);
      expect(model.muted, isFalse);
      expect(model, const ClubNotificationPrefsModel());
    });

    test('gidiş-dönüş aynı modeli verir', () {
      expect(ClubNotificationPrefsModel.fromJson(prefs.toJson()), prefs);
    });

    test('her alan copyWith ile değişir ve eşitliğe girer; props 4 alan '
        'taşır', () {
      void check(
        ClubNotificationPrefsModel changed,
        bool Function(ClubNotificationPrefsModel) read,
        bool value,
      ) => expectFieldChange(prefs, changed, read, value);

      expect(prefs.copyWith(), prefs);
      expect(prefs.props, hasLength(4));
      check(prefs.copyWith(announcements: true), (m) => m.announcements, true);
      check(prefs.copyWith(events: true), (m) => m.events, true);
      check(prefs.copyWith(posts: true), (m) => m.posts, true);
      check(prefs.copyWith(muted: false), (m) => m.muted, false);
    });
  });
}
