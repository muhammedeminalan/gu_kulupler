// T-12 · UserRepository: profil oluşturma (üç belge, tek batch, yazılan
// alanlar), okuma (silinmiş kullanıcı dahil, toplu okuma), profil güncelleme
// (yalnızca izinli alanlar), gizli hesap belgesi, son giriş damgası, geçersiz
// kimlik (W-54), ayrıştırma hatası ve hata eşlemesi (PLAN §10.3, §10.4;
// rules-spec §3.1, §3.2; D-10, D-29, CD-11, CD-130, CD-133).
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
    'packages/gu_data/lib/src/repositories/user_repository.dart';
const String _implementation =
    'packages/gu_data/lib/src/repositories/firebase_user_repository.dart';
const String _uid = 'u_ayse';
const String _email = 'ayse@ogr.gumushane.edu.tr';
const String _avatarPath = 'users/u_ayse/20261008T201501Z_3f9a1c2b7d4e5f60.jpg';

/// `BaseFieldsPayload.create()` anahtarları.
const Set<String> _baseKeys = {
  'createdAt',
  'updatedAt',
  'isDeleted',
  'deletedAt',
  'deletedBy',
};

/// İki belge hali arasında değeri değişen, eklenen ya da kalkan anahtarlar
/// (`updatedAt` hariç).
Set<String> _changedKeys(Json before, Json after) => {
  for (final key in {...before.keys, ...after.keys})
    if (key != 'updatedAt' &&
        !const DeepCollectionEquality().equals(before[key], after[key]))
      key,
};

/// Geçersiz belge kimlikleri (W-54).
const List<String> _invalidIds = ['', 'u/1', '/', '.', '..', '__uid__'];

void main() {
  late FakeFirebaseFirestore db;
  late UserRepository repository;

  DocumentReference<Json> userRef([String uid = _uid]) =>
      db.collection('users').doc(uid);
  DocumentReference<Json> accountRef([String uid = _uid]) =>
      db.collection('users').doc(uid).collection('private').doc('account');
  DocumentReference<Json> settingsRef([String uid = _uid]) =>
      db.collection('settings').doc(uid);

  Future<Json?> read(DocumentReference<Json> ref) async =>
      (await ref.get()).data();

  Future<FirestoreResult<void>> create({
    String uid = _uid,
    String email = _email,
    String name = 'Ayşe Işık',
    String nameLower = 'ayşe ışık',
    String avatarSeed = _uid,
  }) => repository.createProfile(
    uid: uid,
    email: email,
    name: name,
    nameLower: nameLower,
    avatarSeed: avatarSeed,
  );

  /// Her çağrısı [code] hatasıyla biten veritabanına bağlı repository.
  UserRepository failing(String code) => FirebaseUserRepository(
    FirebaseFirestoreService(StubFirestore(error: firestoreException(code))),
  );

  setUp(() {
    db = FakeFirebaseFirestore();
    repository = FirebaseUserRepository(FirebaseFirestoreService(db));
  });

  group('T-12 · UserRepository · sözleşme', () {
    test('PLAN §10.4 tablosundaki T-12 üyeleri arayüzde aynı imzayla var; '
        'başka üye yok (listByInterests T-25)', () {
      final members = interfaceMembers(_interface, '$UserRepository');
      final plan = readPlanRepositoryMembers('$UserRepository');
      final later = plan.where((row) => row.note.isNotEmpty);
      final now = plan.where((row) => row.note.isEmpty);

      expect(later.map((row) => row.member), ['listByInterests']);
      expect(now, hasLength(6));
      expect(members.toSet(), {
        for (final row in now) normalizeDartSource(row.signature),
      });
    });

    test('arayüzde ve uygulamada silme üyesi yok (D-10)', () {
      expect(deleteIdentifiersIn(_interface), isEmpty);
      expect(deleteIdentifiersIn(_implementation), isEmpty);
    });
  });

  group('T-12 · UserRepository · createProfile', () {
    test('users/{uid}: yalnızca profil alanları + ortak alanlar yazılır; '
        'null alanların anahtarı yoktur (W-51)', () async {
      expect((await create()).isSuccess, isTrue);

      final data = (await read(userRef()))!;
      expect(data.keys.toSet(), {
        'name',
        'nameLower',
        'avatarSeed',
        'interests',
        'bio',
        'status',
        'staff',
        'profileComplete',
        ..._baseKeys,
      });
      expect(data, containsPair('name', 'Ayşe Işık'));
      expect(data, containsPair('nameLower', 'ayşe ışık'));
      expect(data, containsPair('avatarSeed', _uid));
      expect(data, containsPair('interests', isEmpty));
      expect(data, containsPair('bio', ''));
      expect(data, containsPair('status', 'active'));
      expect(data, containsPair('staff', false));
      expect(data, containsPair('profileComplete', false));
      expect(data, containsPair('isDeleted', false));
      expect(data, containsPair('deletedAt', isNull));
      expect(data, containsPair('deletedBy', isNull));
      expect(data['createdAt'], isA<Timestamp>());
      expect(data['updatedAt'], isA<Timestamp>());
    });

    test('users/{uid}/private/account: e-posta, küçük harfli e-posta, boş '
        'jeton listesi + ortak alanlar; suspendReason / lastLoginAt '
        'yazılmaz (CD-133)', () async {
      await create(email: 'Ayse@OGR.gumushane.edu.tr');

      final data = (await read(accountRef()))!;
      expect(data.keys.toSet(), {
        'email',
        'emailLower',
        'fcmTokens',
        ..._baseKeys,
      });
      expect(data, containsPair('email', 'Ayse@OGR.gumushane.edu.tr'));
      expect(data, containsPair('emailLower', 'ayse@ogr.gumushane.edu.tr'));
      expect(data, containsPair('fcmTokens', isEmpty));
      expect(data, containsPair('isDeleted', false));
      expect(data['createdAt'], isA<Timestamp>());
    });

    test('settings/{uid}: UserSettingsModel.defaults alanları + updatedAt '
        '(ortak silme alanları yok)', () async {
      await create();

      final data = (await read(settingsRef()))!;
      expect(data.keys.toSet(), {
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
      });
      expect(data['updatedAt'], isA<Timestamp>());
      expect(
        UserSettingsModel.fromJson(data, id: _uid).copyWith(
          clearUpdatedAt: true,
        ),
        const UserSettingsModel.defaults(_uid),
      );
      expect(data, containsPair('reminderTime', '1h'));
      expect(data, containsPair('clubs', isEmpty));
    });

    test('yazılan belgeler modellere geri okunur', () async {
      await create();

      final user = (await repository.getUser(_uid)).dataOrNull!;
      final account = (await repository.getPrivateAccount(_uid)).dataOrNull!;

      expect(user.uid, _uid);
      expect(user.isActive, isTrue);
      expect(user.profileComplete, isFalse);
      expect(user.avatarPath, isNull);
      expect(account.email, _email);
      expect(account.suspendReason, isNull);
      expect(account.lastLoginAt, isNull);
    });

    for (final (label, call)
        in <
          (
            String,
            Future<FirestoreResult<void>> Function(
              UserRepository,
            ),
          )
        >[
          (
            'alan adı dışı e-posta',
            (r) => r.createProfile(
              uid: _uid,
              email: 'ayse@gmail.com',
              name: 'Ayşe',
              nameLower: 'ayşe',
              avatarSeed: _uid,
            ),
          ),
          (
            'bozuk e-posta',
            (r) => r.createProfile(
              uid: _uid,
              email: 'ayse',
              name: 'Ayşe',
              nameLower: 'ayşe',
              avatarSeed: _uid,
            ),
          ),
          (
            'tek harfli ad',
            (r) => r.createProfile(
              uid: _uid,
              email: _email,
              name: 'A',
              nameLower: 'a',
              avatarSeed: _uid,
            ),
          ),
          (
            '61 harfli ad',
            (r) => r.createProfile(
              uid: _uid,
              email: _email,
              name: 'a' * 61,
              nameLower: 'a' * 60,
              avatarSeed: _uid,
            ),
          ),
          (
            'boş nameLower',
            (r) => r.createProfile(
              uid: _uid,
              email: _email,
              name: 'Ayşe',
              nameLower: '',
              avatarSeed: _uid,
            ),
          ),
          (
            'boş avatarSeed',
            (r) => r.createProfile(
              uid: _uid,
              email: _email,
              name: 'Ayşe',
              nameLower: 'ayşe',
              avatarSeed: '',
            ),
          ),
          (
            'avatarSeedMax + 1 karakterli avatarSeed',
            (r) => r.createProfile(
              uid: _uid,
              email: _email,
              name: 'Ayşe',
              nameLower: 'ayşe',
              avatarSeed: 'a' * (Limits.avatarSeedMax + 1),
            ),
          ),
          (
            'kırpılınca tek harf kalan ad',
            (r) => r.createProfile(
              uid: _uid,
              email: _email,
              name: ' A ',
              nameLower: ' a ',
              avatarSeed: _uid,
            ),
          ),
        ]) {
      test('geçersiz alan yazmadan invalidArgument: $label', () async {
        final result = await call(repository);

        expect(result.errorOrNull, FirestoreError.invalidArgument);
        expect(await read(userRef()), isNull);
        expect(await read(accountRef()), isNull);
        expect(await read(settingsRef()), isNull);
      });
    }

    test('batch reddedilirse hata döner (permission-denied → '
        'permissionDenied)', () async {
      final result = await failing('permission-denied').createProfile(
        uid: _uid,
        email: _email,
        name: 'Ayşe',
        nameLower: 'ayşe',
        avatarSeed: _uid,
      );

      expect(result.errorOrNull, FirestoreError.permissionDenied);
    });

    /// Batch'i Rules'un "belge varken create yok" reddiyle biten repository
    /// (okumalar [db]'ye gider).
    UserRepository deniedBatch() => FirebaseUserRepository(
      FirebaseFirestoreService(
        FailingBatchFirestore(
          db,
          error: firestoreException('permission-denied'),
        ),
      ),
    );

    test('yeniden deneme güvenli: profil zaten varken gelen ret başarıya '
        'çevrilir ve belgeler değişmez (zaman aşımına düşen ilk çağrı '
        'sonradan işlenmiş)', () async {
      expect((await create()).isSuccess, isTrue);
      final userBefore = await read(userRef());
      final accountBefore = await read(accountRef());

      final retry = await deniedBatch().createProfile(
        uid: _uid,
        email: _email,
        name: 'Başka Ad',
        nameLower: 'başka ad',
        avatarSeed: 'baska',
      );

      expect(retry.isSuccess, isTrue);
      expect(await read(userRef()), userBefore);
      expect(await read(accountRef()), accountBefore);
    });

    test('profil yokken gelen ret aynen döner (doğrulanmamış oturum — '
        'W-56)', () async {
      final result = await deniedBatch().createProfile(
        uid: _uid,
        email: _email,
        name: 'Ayşe',
        nameLower: 'ayşe',
        avatarSeed: _uid,
      );

      expect(result.errorOrNull, FirestoreError.permissionDenied);
      expect(await read(userRef()), isNull);
    });
  });

  group('T-12 · UserRepository · getUser', () {
    test('belge yoksa başarı null', () async {
      final result = await repository.getUser(_uid);

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, isNull);
    });

    test('silinmiş (anonim) kullanıcı da döner — yazar gösterimi', () async {
      await userRef().set({
        'name': Anonymization.deletedUserName,
        'nameLower': 'silinmiş kullanıcı',
        'avatarSeed': _uid,
        'status': 'deleted',
        ...SoftDelete.payload(actorId: _uid),
      });

      final user = (await repository.getUser(_uid)).dataOrNull!;

      expect(user.isDeleted, isTrue);
      expect(user.isAnonymized, isTrue);
      expect(user.name, Anonymization.deletedUserName);
    });

    test('seed biçimi (açık null alanlar) da ayrışır (CD-130)', () async {
      await userRef().set({
        'name': 'Ayşe',
        'nameLower': 'ayşe',
        'avatarSeed': _uid,
        'avatarPath': null,
        'department': null,
        'year': null,
        ...BaseFieldsPayload.create(),
      });

      final user = (await repository.getUser(_uid)).dataOrNull!;

      expect(user.avatarPath, isNull);
      expect(user.year, isNull);
    });

    test(
      'modele çevrilemeyen belge parse hatasıdır (istisna sızmaz)',
      () async {
        await userRef().set({'name': 'Ayşe', 'status': 'banned'});

        final result = await repository.getUser(_uid);

        expect(result.errorOrNull, FirestoreError.parse);
        expect((result as FirebaseFailure).message, contains('users/$_uid'));
      },
    );

    test('okuma hatası aynen eşlenir', () async {
      final result = await failing('unavailable').getUser(_uid);

      expect(result.errorOrNull, FirestoreError.unavailable);
    });
  });

  group('T-12 · UserRepository · getUsers', () {
    Future<void> seed(Iterable<String> uids) async {
      for (final uid in uids) {
        await userRef(uid).set({
          'name': 'Ad $uid',
          'nameLower': 'ad $uid',
          'avatarSeed': uid,
          ...BaseFieldsPayload.create(),
        });
      }
    }

    test('istenen sırada döner; tekrarlar tekilleşir, belgesi olmayan '
        'atlanır, silinmiş kullanıcı dahildir', () async {
      await seed(['u1', 'u2', 'u3']);
      await userRef('u2').update(SoftDelete.payload(actorId: 'u2'));

      final users = (await repository.getUsers([
        'u3',
        'yok',
        'u1',
        'u3',
        'u2',
      ])).dataOrNull!;

      expect(users.map((user) => user.uid), ['u3', 'u1', 'u2']);
      expect(users.last.isDeleted, isTrue);
    });

    test('30 kimlikten fazlası parçalanarak sorgulanır', () async {
      final uids = [
        for (var i = 0; i < 65; i++) 'u${i.toString().padLeft(2, '0')}',
      ];
      await seed(uids);

      final users = (await repository.getUsers(
        uids.reversed.toList(),
      )).dataOrNull!;

      expect(users.map((user) => user.uid), uids.reversed);
    });

    test('boş liste sorgu yapmadan boş döner', () async {
      final result = await failing('unavailable').getUsers(const []);

      expect(result.dataOrNull, isEmpty);
    });

    test('tek belge bile ayrıştırılamazsa sonuç parse hatasıdır', () async {
      await seed(['u1']);
      await userRef('u2').set({'name': 'Eksik'});

      final result = await repository.getUsers(['u1', 'u2']);

      expect(result.errorOrNull, FirestoreError.parse);
    });

    test('sorgu hatası aynen eşlenir', () async {
      final result = await failing('permission-denied').getUsers(['u1']);

      expect(result.errorOrNull, FirestoreError.permissionDenied);
    });
  });

  group('T-12 · UserRepository · updateProfile', () {
    setUp(create);

    test('yalnızca yamadaki alanlar ve updatedAt değişir', () async {
      final before = (await read(userRef()))!;

      final result = await repository.updateProfile(
        _uid,
        const UserProfilePatch(
          name: 'Ayşe Demir',
          nameLower: 'ayşe demir',
          avatarPath: _avatarPath,
          department: 'd01',
          year: YearLevel.second,
          interests: ['i01', 'i02'],
          bio: 'Merhaba',
          profileComplete: true,
        ),
      );

      final after = (await read(userRef()))!;
      expect(result.isSuccess, isTrue);
      expect(
        _changedKeys(before, after),
        {
          'name',
          'nameLower',
          'avatarPath',
          'department',
          'year',
          'interests',
          'bio',
          'profileComplete',
        },
      );
      expect(after, containsPair('year', '2'));
      expect(after, containsPair('profileComplete', true));
      expect(after, containsPair('status', 'active'));
      expect(after, containsPair('staff', false));
      expect(after['createdAt'], before['createdAt']);
      expect(after['updatedAt'], isA<Timestamp>());
      expect(
        (await repository.getUser(_uid)).dataOrNull?.interests,
        ['i01', 'i02'],
      );
    });

    test('clearAvatarPath fotoğrafı kaldırır (avatarPath: null)', () async {
      await repository.updateProfile(
        _uid,
        const UserProfilePatch(avatarPath: _avatarPath),
      );

      final result = await repository.updateProfile(
        _uid,
        const UserProfilePatch(clearAvatarPath: true),
      );

      expect(result.isSuccess, isTrue);
      expect((await read(userRef()))!['avatarPath'], isNull);
      expect((await repository.getUser(_uid)).dataOrNull?.avatarPath, isNull);
    });

    for (final (label, patch) in <(String, UserProfilePatch)>[
      ('boş yama', const UserProfilePatch()),
      ('nameLower olmadan name', const UserProfilePatch(name: 'Ayşe Demir')),
      ('name olmadan nameLower', const UserProfilePatch(nameLower: 'ayşe')),
      ('tek harfli ad', const UserProfilePatch(name: 'A', nameLower: 'a')),
      ('boş avatarSeed', const UserProfilePatch(avatarSeed: '')),
      (
        'başkasının avatar yolu',
        const UserProfilePatch(
          avatarPath: 'users/u_baska/20261008T201501Z_3f9a1c2b7d4e5f60.jpg',
        ),
      ),
      (
        'sabit adlı avatar',
        const UserProfilePatch(avatarPath: 'users/u_ayse/avatar.jpg'),
      ),
      ('bilinmeyen bölüm', const UserProfilePatch(department: 'd99')),
      (
        '6 ilgi alanı',
        const UserProfilePatch(
          interests: ['i01', 'i02', 'i03', 'i04', 'i05', 'i06'],
        ),
      ),
      ('bilinmeyen ilgi alanı', const UserProfilePatch(interests: ['i99'])),
      (
        'tekrarlı ilgi alanı',
        const UserProfilePatch(interests: ['i01', 'i01']),
      ),
      ('141 karakter biyografi', UserProfilePatch(bio: 'a' * 141)),
    ]) {
      test('geçersiz yama yazmadan invalidArgument: $label', () async {
        final before = await read(userRef());

        final result = await repository.updateProfile(_uid, patch);

        expect(result.errorOrNull, FirestoreError.invalidArgument);
        expect(await read(userRef()), before);
      });
    }

    test('boş ilgi listesi repository katmanından geçer (personel; alt sınır '
        'Security Rules içinde)', () async {
      final result = await repository.updateProfile(
        _uid,
        const UserProfilePatch(interests: []),
      );

      expect(result.isSuccess, isTrue);
    });

    test('belge yoksa notFound', () async {
      final result = await repository.updateProfile(
        'u_yok',
        const UserProfilePatch(bio: 'Merhaba'),
      );

      expect(result.errorOrNull, FirestoreError.notFound);
    });

    test('yazma hatası aynen eşlenir', () async {
      final result = await failing('permission-denied').updateProfile(
        _uid,
        const UserProfilePatch(bio: 'Merhaba'),
      );

      expect(result.errorOrNull, FirestoreError.permissionDenied);
    });
  });

  group('T-12 · UserRepository · private/account', () {
    test('getPrivateAccount: belge yoksa başarı null', () async {
      final result = await repository.getPrivateAccount(_uid);

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, isNull);
    });

    test('getPrivateAccount: askı gerekçesi buradan okunur (CD-133)', () async {
      await create();
      await accountRef().update({'suspendReason': 'Kural ihlali'});

      final account = (await repository.getPrivateAccount(_uid)).dataOrNull!;

      expect(account.suspendReason, 'Kural ihlali');
      expect(account.emailLower, _email);
    });

    test(
      'getPrivateAccount: silinmiş belge notFound; bozuk belge parse',
      () async {
        await create();
        await accountRef().update(SoftDelete.payload(actorId: _uid));
        expect(
          (await repository.getPrivateAccount(_uid)).errorOrNull,
          FirestoreError.notFound,
        );

        await accountRef('u2').set({'emailLower': _email});
        expect(
          (await repository.getPrivateAccount('u2')).errorOrNull,
          FirestoreError.parse,
        );
      },
    );

    test('getPrivateAccount: başkasının hesabı permissionDenied olarak '
        'eşlenir', () async {
      final result = await failing('permission-denied').getPrivateAccount(_uid);

      expect(result.errorOrNull, FirestoreError.permissionDenied);
    });

    test('touchLastLogin: yalnızca lastLoginAt ve updatedAt değişir', () async {
      await create();
      await accountRef().update({'suspendReason': 'Kural ihlali'});
      final before = (await read(accountRef()))!;

      final result = await repository.touchLastLogin(_uid);

      final after = (await read(accountRef()))!;
      expect(result.isSuccess, isTrue);
      expect(after['lastLoginAt'], isA<Timestamp>());
      expect(
        _changedKeys(before, after),
        {'lastLoginAt'},
      );
      expect(after, containsPair('suspendReason', 'Kural ihlali'));
    });

    test('touchLastLogin: belge yoksa notFound', () async {
      final result = await repository.touchLastLogin(_uid);

      expect(result.errorOrNull, FirestoreError.notFound);
    });
  });

  group('T-12 · UserRepository · geçersiz kimlik (W-54)', () {
    for (final id in _invalidIds) {
      test('"$id": her metot invalidArgument döner, istisna sızmaz', () async {
        final results = <FirestoreResult<Object?>>[
          await repository.getUser(id),
          await repository.getUsers(['u1', id]),
          await repository.getUsers([id, 'u1', 'u2']),
          await create(uid: id),
          await repository.updateProfile(
            id,
            const UserProfilePatch(bio: 'Merhaba'),
          ),
          await repository.getPrivateAccount(id),
          await repository.touchLastLogin(id),
        ];

        expect(
          results.map((result) => result.errorOrNull),
          everyElement(FirestoreError.invalidArgument),
        );
      });
    }
  });
}
