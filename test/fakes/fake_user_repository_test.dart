// T-12 · FakeUserRepository sözleşmesi (PLAN §16.3): `users`,
// `createdProfiles`, `profilePatches`; gerçek repository'nin okuma / yazma
// sonuçlarını izler.
// T-14 · `updateAvatar`: çağrı kısıtı (W-57), ön denetimler, adım bazlı hata.
import 'dart:async';
import 'dart:typed_data';

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
  group('T-14 · FakeUserRepository · updateAvatar', () {
    final bytes = Uint8List.fromList(const [0xFF, 0xD8, 0xFF, 0xE0]);
    const setupPatch = UserProfilePatch(
      department: 'd02',
      year: YearLevel.second,
      interests: ['i01', 'i05'],
      profileComplete: true,
    );

    Future<MediaUpdateResult<String>> update({
      String uid = _uid,
      Uint8List? data,
      String contentType = 'image/jpeg',
      UserProfilePatch? profile,
      void Function(double fraction)? onProgress,
    }) => fake.updateAvatar(
      uid,
      bytes: data ?? bytes,
      contentType: contentType,
      profile: profile,
      onProgress: onProgress,
    );

    test(
      'tamamlanmış profil: yeni yol users/{uid}/ altında, avatarPath '
      'güncellenir, çağrı `avatarUploads`e yazılır; her çağrı yeni ad',
      () async {
        fake.putActive(_uid);
        final fractions = <double>[];

        final first = (await update(onProgress: fractions.add)).dataOrNull!;
        final second = (await update(contentType: 'image/png')).dataOrNull!;

        expect(StoragePaths.isUserAvatar(first, _uid), isTrue);
        expect(StoragePaths.isUserAvatar(second, _uid), isTrue);
        expect(first, endsWith('.jpg'));
        expect(second, endsWith('.png'));
        expect(first, isNot(second));
        expect(fake.users[_uid]!.avatarPath, second);
        expect(fractions, [1.0]);
        expect(fake.avatarUploads.map((upload) => upload.path), [
          first,
          second,
        ]);
        expect(fake.avatarUploads.first.bytes, bytes);
        expect(fake.avatarUploads.first.contentType, 'image/jpeg');
        expect(fake.avatarUploads.first.profile, isNull);
        expect(fake.callsTo('updateAvatar'), hasLength(2));
        expect(fake.profilePatches, isEmpty);
      },
    );

    test('AUT-05: ilgi alanlarını içeren yama avatarPath ile birlikte '
        'uygulanır (W-57)', () async {
      await create();

      final path = (await update(profile: setupPatch)).dataOrNull!;

      final user = fake.users[_uid]!;
      expect(user.avatarPath, path);
      expect(user.interests, ['i01', 'i05']);
      expect(user.department, 'd02');
      expect(user.year, YearLevel.second);
      expect(user.profileComplete, isTrue);
      expect(fake.avatarUploads.single.profile, setupPatch);
    });

    test(
      'profil tamamlanmadan tek başına (ya da ilgi alansız yamayla) çağrı '
      'failedPrecondition; belge yoksa notFound; hiçbir şey yazılmaz',
      () async {
        expect(
          (await update()).errorOrNull,
          const MediaDocumentError(FirestoreError.notFound),
        );
        await create();

        for (final profile in [
          null,
          const UserProfilePatch(bio: 'Merhaba.'),
          const UserProfilePatch(interests: []),
        ]) {
          expect(
            (await update(profile: profile)).errorOrNull,
            const MediaDocumentError(FirestoreError.failedPrecondition),
          );
        }
        expect(fake.users[_uid]!.avatarPath, isNull);
        expect(fake.avatarUploads, isEmpty);
      },
    );

    test('personel ilgi alanı olmadan da yükleyebilir', () async {
      fake.users[_uid] = const UserModel(
        uid: _uid,
        name: 'Dr. Ayşe',
        nameLower: 'dr. ayşe',
        avatarSeed: _uid,
        staff: true,
      );

      expect((await update()).isSuccess, isTrue);
    });

    test('gerçek servisin ön denetimleri: tür, boş dosya, boyut sınırı; '
        'geçersiz kimlik ve avatarPath taşıyan yama invalidArgument', () async {
      fake.putActive(_uid);

      expect(
        (await update(contentType: 'image/gif')).errorOrNull,
        const MediaUploadError(StorageError.invalidType),
      );
      expect(
        (await update(data: Uint8List(0))).errorOrNull,
        const MediaUploadError(StorageError.noFile),
      );
      expect(
        (await update(data: Uint8List(Limits.imageMaxBytes))).errorOrNull,
        const MediaUploadError(StorageError.sizeLimit),
      );
      expect(
        (await update(uid: 'u/1')).errorOrNull,
        const MediaDocumentError(FirestoreError.invalidArgument),
      );
      for (final profile in [
        const UserProfilePatch(avatarPath: 'users/$_uid/x.jpg'),
        const UserProfilePatch(clearAvatarPath: true),
      ]) {
        expect(
          (await update(profile: profile)).errorOrNull,
          const MediaDocumentError(FirestoreError.invalidArgument),
        );
      }
      expect(fake.avatarUploads, isEmpty);
      expect(fake.users[_uid]!.avatarPath, isNull);
    });

    test('failNext(StorageError) yükleme adımını, failNext(FirestoreError) '
        'belge adımını düşürür (tek seferlik); avatarPath değişmez', () async {
      fake
        ..putActive(_uid)
        ..failNext(StorageError.unauthorized);
      expect(
        (await update()).errorOrNull,
        const MediaUploadError(StorageError.unauthorized),
      );
      fake.failNext(FirestoreError.permissionDenied);
      expect(
        (await update()).errorOrNull,
        const MediaDocumentError(FirestoreError.permissionDenied),
      );
      fake.failNext();
      expect(
        (await update()).errorOrNull,
        const MediaDocumentError(FirestoreError.unknown),
      );
      expect(fake.users[_uid]!.avatarPath, isNull);
      expect(fake.avatarUploads, isEmpty);

      expect((await update()).isSuccess, isTrue);
    });

    test(
      'avatarUploadGate: yükleme bitti, belge yazımı kapıda bekler',
      () async {
        fake.putActive(_uid);
        final gate = fake.avatarUploadGate = Completer<void>();
        final fractions = <double>[];

        final pending = update(onProgress: fractions.add);
        await Future<void>.delayed(Duration.zero);

        expect(fractions, [1.0]);
        expect(fake.users[_uid]!.avatarPath, isNull);

        gate.complete();
        final path = (await pending).dataOrNull;
        expect(fake.users[_uid]!.avatarPath, path);
      },
    );
  });
}
