// T-12 · SettingsRepository: ayarları okuma (belge yoksa varsayılanı yazar),
// genel tercih yaması (yalnızca izinli alanlar), kulübe özgü tercih (tek
// anahtar), geçersiz kimlik (W-54), ayrıştırma hatası ve hata eşlemesi
// (PLAN §9.6.14, §10.4; rules-spec §3.12; CD-34).
//
// Mutlu yollar `fake_cloud_firestore` ile (Q-06); hata yolları el yazımı SDK
// çiftleriyle (`test/fakes/sdk_firestore_stubs.dart`).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../fakes/sdk_firestore_stubs.dart';
import '../helpers/plan_repository_table.dart';
import '../helpers/plan_service_table.dart';

const String _interface =
    'packages/gu_data/lib/src/repositories/settings_repository.dart';
const String _implementation =
    'packages/gu_data/lib/src/repositories/firebase_settings_repository.dart';
const String _uid = 'u_ayse';

/// `settings/{uid}` belgesinin tüm anahtarları (PLAN §9.6.14).
const Set<String> _settingsKeys = {
  'announcements',
  'eventReminders',
  'newEvents',
  'applicationResults',
  'management',
  'system',
  'reminderTime',
  'quiet',
  'quietFrom',
  'quietTo',
  'clubs',
  'updatedAt',
};

/// İki belge hali arasında değeri değişen, eklenen ya da kalkan anahtarlar
/// (`updatedAt` hariç).
Set<String> _changedKeys(Json before, Json after) => {
  for (final key in {...before.keys, ...after.keys})
    if (key != 'updatedAt' &&
        !const DeepCollectionEquality().equals(before[key], after[key]))
      key,
};

void main() {
  late FakeFirebaseFirestore db;
  late SettingsRepository repository;

  DocumentReference<Json> ref([String uid = _uid]) =>
      db.collection('settings').doc(uid);

  Future<Json?> read([String uid = _uid]) async =>
      (await ref(uid).get()).data();

  /// Her çağrısı [code] hatasıyla biten veritabanına bağlı repository.
  SettingsRepository failing(String code) => FirebaseSettingsRepository(
    FirebaseFirestoreService(StubFirestore(error: firestoreException(code))),
  );

  setUp(() {
    db = FakeFirebaseFirestore();
    repository = FirebaseSettingsRepository(FirebaseFirestoreService(db));
  });

  group('T-12 · SettingsRepository · sözleşme', () {
    test('PLAN §10.4 tablosundaki her üye arayüzde aynı imzayla var; başka '
        'üye yok', () {
      final plan = readPlanRepositoryMembers('$SettingsRepository');

      expect(plan, hasLength(3));
      expect(interfaceMembers(_interface, '$SettingsRepository').toSet(), {
        for (final row in plan) normalizeDartSource(row.signature),
      });
    });

    test('arayüzde ve uygulamada silme üyesi yok (D-10)', () {
      expect(deleteIdentifiersIn(_interface), isEmpty);
      expect(deleteIdentifiersIn(_implementation), isEmpty);
    });
  });

  group('T-12 · SettingsRepository · getSettings', () {
    test('belge yoksa varsayılanları yazar ve döndürür', () async {
      final result = await repository.getSettings(_uid);

      expect(result.dataOrNull, const UserSettingsModel.defaults(_uid));
      final data = (await read())!;
      expect(data.keys.toSet(), _settingsKeys);
      expect(data['updatedAt'], isA<Timestamp>());
      expect(data, containsPair('reminderTime', '1h'));
      expect(data, containsPair('quiet', false));
      expect(data, containsPair('quietFrom', '22:00'));
      expect(data, containsPair('quietTo', '08:00'));
      expect(data, containsPair('clubs', isEmpty));
      for (final key in _settingsKeys.take(6)) {
        expect(data, containsPair(key, true));
      }
    });

    test('var olan belgeyi kimliğiyle döndürür ve üzerine yazmaz', () async {
      await ref().set({
        'announcements': false,
        'reminderTime': '1d',
        'quiet': true,
        'quietFrom': '23:30',
        'clubs': {
          'c01': {'muted': true},
        },
      });
      final before = await read();

      final settings = (await repository.getSettings(_uid)).dataOrNull!;

      expect(settings.uid, _uid);
      expect(settings.announcements, isFalse);
      expect(settings.eventReminders, isTrue, reason: 'eksik alan varsayılan');
      expect(settings.reminderTime, ReminderOption.oneDay);
      expect(settings.quietFrom, '23:30');
      expect(
        settings.clubs['c01'],
        const ClubNotificationPrefsModel(muted: true),
      );
      expect(await read(), before);
    });

    test(
      'modele çevrilemeyen belge parse hatasıdır; üzerine yazılmaz',
      () async {
        await ref().set({'reminderTime': 'yarın'});

        final result = await repository.getSettings(_uid);

        expect(result.errorOrNull, FirestoreError.parse);
        expect(await read(), {'reminderTime': 'yarın'});
      },
    );

    test('okuma hatası aynen eşlenir', () async {
      final result = await failing('permission-denied').getSettings(_uid);

      expect(result.errorOrNull, FirestoreError.permissionDenied);
    });

    test('varsayılan yazılamazsa o hata döner (başarı = belge var)', () async {
      final service = _ReadOnlyService(FirebaseFirestoreService(db));

      final result = await FirebaseSettingsRepository(service).getSettings(
        _uid,
      );

      expect(result.errorOrNull, FirestoreError.permissionDenied);
      expect(await read(), isNull);
    });
  });

  group('T-12 · SettingsRepository · updateSettings', () {
    setUp(() => repository.getSettings(_uid));

    test('yalnızca yamadaki alanlar ve updatedAt değişir', () async {
      final before = (await read())!;

      final result = await repository.updateSettings(
        _uid,
        const UserSettingsPatch(
          announcements: false,
          reminderTime: ReminderOption.oneDay,
          quiet: true,
          quietFrom: '23:00',
          quietTo: '07:30',
        ),
      );

      final after = (await read())!;
      expect(result.isSuccess, isTrue);
      expect(_changedKeys(before, after), {
        'announcements',
        'reminderTime',
        'quiet',
        'quietFrom',
        'quietTo',
      });
      expect(after.keys.toSet(), _settingsKeys);
      expect(after, containsPair('reminderTime', '1d'));
      expect(after, containsPair('quietTo', '07:30'));
      expect(after['updatedAt'], isA<Timestamp>());
    });

    test('on genel tercihin hepsi yazılabilir', () async {
      await repository.updateSettings(
        _uid,
        const UserSettingsPatch(
          announcements: false,
          eventReminders: false,
          newEvents: false,
          applicationResults: false,
          management: false,
          system: false,
          reminderTime: ReminderOption.oneDay,
          quiet: true,
          quietFrom: '00:00',
          quietTo: '23:59',
        ),
      );

      expect(
        (await repository.getSettings(_uid)).dataOrNull!.copyWith(
          clearUpdatedAt: true,
        ),
        const UserSettingsModel(
          uid: _uid,
          announcements: false,
          eventReminders: false,
          newEvents: false,
          applicationResults: false,
          management: false,
          system: false,
          reminderTime: ReminderOption.oneDay,
          quiet: true,
          quietFrom: '00:00',
          quietTo: '23:59',
        ),
      );
    });

    for (final (label, patch) in <(String, UserSettingsPatch)>[
      ('boş yama', const UserSettingsPatch()),
      (
        'reminderTime 15m',
        const UserSettingsPatch(reminderTime: ReminderOption.fifteenMinutes),
      ),
      (
        'reminderTime none',
        const UserSettingsPatch(reminderTime: ReminderOption.none),
      ),
      ('quietFrom 24:00', const UserSettingsPatch(quietFrom: '24:00')),
      ('quietTo 8:00', const UserSettingsPatch(quietTo: '8:00')),
    ]) {
      test('geçersiz yama yazmadan invalidArgument: $label', () async {
        final before = await read();

        final result = await repository.updateSettings(_uid, patch);

        expect(result.errorOrNull, FirestoreError.invalidArgument);
        expect(await read(), before);
      });
    }

    test('belge yoksa notFound; yazma hatası aynen eşlenir', () async {
      expect(
        (await repository.updateSettings(
          'u_yok',
          const UserSettingsPatch(quiet: true),
        )).errorOrNull,
        FirestoreError.notFound,
      );
      expect(
        (await failing('permission-denied').updateSettings(
          _uid,
          const UserSettingsPatch(quiet: true),
        )).errorOrNull,
        FirestoreError.permissionDenied,
      );
    });
  });

  group('T-12 · SettingsRepository · updateClubSettings', () {
    setUp(() => repository.getSettings(_uid));

    test('yalnızca o kulübün kaydı ve updatedAt değişir; üst düzeyde '
        'yalnızca clubs alanı etkilenir', () async {
      await repository.updateClubSettings(
        _uid,
        'c02',
        const ClubNotificationPrefsModel(),
      );
      final before = (await read())!;

      final result = await repository.updateClubSettings(
        _uid,
        'c01',
        const ClubNotificationPrefsModel(posts: false, muted: true),
      );

      final after = (await read())!;
      expect(result.isSuccess, isTrue);
      expect(_changedKeys(before, after), {'clubs'});
      expect(after['clubs'], {
        'c02': {
          'announcements': true,
          'events': true,
          'posts': true,
          'muted': false,
        },
        'c01': {
          'announcements': true,
          'events': true,
          'posts': false,
          'muted': true,
        },
      });
      expect(
        (await repository.getSettings(_uid)).dataOrNull!.clubs['c01'],
        const ClubNotificationPrefsModel(posts: false, muted: true),
      );
    });

    test('aynı kulübün kaydı bütünüyle değişir', () async {
      await repository.updateClubSettings(
        _uid,
        'c01',
        const ClubNotificationPrefsModel(muted: true),
      );

      await repository.updateClubSettings(
        _uid,
        'c01',
        const ClubNotificationPrefsModel(events: false),
      );

      expect(
        (await repository.getSettings(_uid)).dataOrNull!.clubs,
        {'c01': const ClubNotificationPrefsModel(events: false)},
      );
    });

    for (final clubId in ['', 'c/01', 'c.01', 'quiet.x', 'c*', 'c~1', 'c[0]']) {
      test('alan yolunu bozabilecek kulüp kimliği yazmadan invalidArgument: '
          '"$clubId"', () async {
        final before = await read();

        final result = await repository.updateClubSettings(
          _uid,
          clubId,
          const ClubNotificationPrefsModel(muted: true),
        );

        expect(result.errorOrNull, FirestoreError.invalidArgument);
        expect(await read(), before);
      });
    }

    test('belge yoksa notFound', () async {
      final result = await repository.updateClubSettings(
        'u_yok',
        'c01',
        const ClubNotificationPrefsModel(),
      );

      expect(result.errorOrNull, FirestoreError.notFound);
    });
  });

  group('T-12 · SettingsRepository · geçersiz kimlik (W-54)', () {
    for (final id in ['', 'u/1', '..', '__uid__']) {
      test('"$id": her metot invalidArgument döner, istisna sızmaz', () async {
        final results = <FirestoreResult<Object?>>[
          await repository.getSettings(id),
          await repository.updateSettings(
            id,
            const UserSettingsPatch(quiet: true),
          ),
          await repository.updateClubSettings(
            id,
            'c01',
            const ClubNotificationPrefsModel(),
          ),
        ];

        expect(
          results.map((result) => result.errorOrNull),
          everyElement(FirestoreError.invalidArgument),
        );
        expect(await db.collection('settings').get().then((s) => s.size), 0);
      });
    }
  });
}

/// Okumaları gerçek servise ileten, `set` yazımını `permission-denied` ile
/// reddeden servis (varsayılan ayar yazımının hatası).
final class _ReadOnlyService implements FirestoreService {
  _ReadOnlyService(this._inner);

  final FirestoreService _inner;

  @override
  DocumentReference<Json> doc(String collectionPath, String id) =>
      _inner.doc(collectionPath, id);

  @override
  Future<FirestoreResult<FirestoreDoc?>> getDoc(DocumentReference<Json> ref) =>
      _inner.getDoc(ref);

  @override
  Future<FirestoreResult<void>> set(
    DocumentReference<Json> ref,
    Json data, {
    bool merge = false,
  }) async => const FirebaseFailure(FirestoreError.permissionDenied);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
