// T-12 · FakeUserRepository sözleşmesi (PLAN §16.3): `users`,
// `createdProfiles`, `profilePatches`; gerçek repository'nin okuma / yazma
// sonuçlarını izler.
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';

import 'fake_user_repository.dart';
import 'register_fakes.dart';

const String _uid = 'u_ayse';
const String _email = 'Ayse@ogr.gumushane.edu.tr';

void main() {
  late FakeUserRepository fake;

  Future<FirestoreResult<void>> create() => fake.createProfile(
    uid: _uid,
    email: _email,
    name: 'Ayşe Işık',
    nameLower: 'ayşe ışık',
    avatarSeed: _uid,
  );

  setUp(() => fake = FakeUserRepository());

  group('T-12 · FakeUserRepository', () {
    test('UserRepository arayüzünü uygular; registerDefaultFakes '
        'kaydeder', () {
      addTearDown(GetIt.I.reset);
      registerDefaultFakes();
      expect(GetIt.I<UserRepository>(), isA<FakeUserRepository>());
    });

    test('createProfile: profil (aktif, eksik) + hesap belgesi kurar ve '
        '`createdProfiles`e yazar; ikinci çağrı hiçbir şeyi değiştirmeden '
        'başarı döner', () async {
      expect((await create()).isSuccess, isTrue);

      expect(
        fake.users[_uid],
        const UserModel(
          uid: _uid,
          name: 'Ayşe Işık',
          nameLower: 'ayşe ışık',
          avatarSeed: _uid,
        ),
      );
      expect(fake.users[_uid]!.profileComplete, isFalse);
      expect(fake.users[_uid]!.status, UserStatus.active);
      expect(fake.accounts[_uid]!.email, _email);
      expect(fake.accounts[_uid]!.emailLower, _email.toLowerCase());
      expect(fake.createdProfiles.single, (
        uid: _uid,
        email: _email,
        name: 'Ayşe Işık',
        nameLower: 'ayşe ışık',
        avatarSeed: _uid,
      ));

      final existing = fake.users[_uid];
      expect((await create()).isSuccess, isTrue);
      expect(fake.createdProfiles, hasLength(1));
      expect(fake.users[_uid], same(existing));
    });

    test('getUser: belge yoksa başarı null; silinmiş kullanıcı da '
        'döner', () async {
      expect((await fake.getUser(_uid)).isSuccess, isTrue);
      expect((await fake.getUser(_uid)).dataOrNull, isNull);

      final deleted = fake
          .putActive(_uid)
          .copyWith(status: UserStatus.deleted, isDeleted: true);
      fake.users[_uid] = deleted;
      expect((await fake.getUser(_uid)).dataOrNull, deleted);
    });

    test('getUsers: verilen sırada, tekilleştirilmiş, belgesi olmayan '
        'atlanır', () async {
      final b = fake.putActive('b');
      final a = fake.putActive('a');
      final result = await fake.getUsers(['b', 'yok', 'a', 'b']);
      expect(result.dataOrNull, [b, a]);
    });

    test('updateProfile: yamayı uygular (fotoğrafı kaldırma dahil) ve '
        '`profilePatches`e yazar', () async {
      await create();
      const patch = UserProfilePatch(
        department: 'd02',
        year: YearLevel.second,
        interests: ['i01'],
        avatarPath: 'users/u_ayse/a.jpg',
        profileComplete: true,
      );
      expect((await fake.updateProfile(_uid, patch)).isSuccess, isTrue);

      final updated = fake.users[_uid]!;
      expect(updated.department, 'd02');
      expect(updated.year, YearLevel.second);
      expect(updated.interests, ['i01']);
      expect(updated.avatarPath, 'users/u_ayse/a.jpg');
      expect(updated.profileComplete, isTrue);
      expect(updated.name, 'Ayşe Işık');
      expect(fake.profilePatches.single, (uid: _uid, patch: patch));

      await fake.updateProfile(
        _uid,
        const UserProfilePatch(clearAvatarPath: true),
      );
      expect(fake.users[_uid]!.avatarPath, isNull);
    });

    test('updateProfile: boş yama invalidArgument, belge yoksa '
        'notFound', () async {
      expect(
        (await fake.updateProfile(_uid, const UserProfilePatch())).errorOrNull,
        FirestoreError.invalidArgument,
      );
      expect(
        (await fake.updateProfile(
          _uid,
          const UserProfilePatch(bio: 'x'),
        )).errorOrNull,
        FirestoreError.notFound,
      );
      expect(fake.profilePatches, isEmpty);
    });

    test('getPrivateAccount hesabı döndürür; touchLastLogin '
        '`lastLoginTouches`e yazar (hesap yoksa notFound)', () async {
      expect((await fake.getPrivateAccount(_uid)).dataOrNull, isNull);
      expect(
        (await fake.touchLastLogin(_uid)).errorOrNull,
        FirestoreError.notFound,
      );

      await create();
      expect((await fake.getPrivateAccount(_uid)).dataOrNull?.email, _email);
      expect((await fake.touchLastLogin(_uid)).isSuccess, isTrue);
      expect(fake.lastLoginTouches, [_uid]);
    });

    test('geçersiz kimlik invalidArgument (W-54)', () async {
      expect(
        (await fake.getUser('u/1')).errorOrNull,
        FirestoreError.invalidArgument,
      );
      expect(
        (await fake.getUsers(['a', ''])).errorOrNull,
        FirestoreError.invalidArgument,
      );
    });

    test('failNext sıradaki çağrıyı düşürür (tek seferlik) ve veri '
        'değişmez', () async {
      fake.failNext(FirestoreError.unavailable);
      expect((await create()).errorOrNull, FirestoreError.unavailable);
      expect(fake.users, isEmpty);
      expect((await create()).isSuccess, isTrue);
      expect(fake.callsTo('createProfile'), hasLength(2));
    });
  });
}
