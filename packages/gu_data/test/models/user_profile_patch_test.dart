// T-12 · UserProfilePatch: yalnızca verilen alanların yazılması, izinli alan
// kümesi (rules-spec §3.1 U sahibi + nameLower — CD-11), avatarPath'in
// kaldırılması ve eşitlik (PLAN §10.4).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

void main() {
  // Her alan dolu.
  const full = UserProfilePatch(
    name: 'Ayşe Işık',
    nameLower: 'ayşe ışık',
    avatarSeed: 'u_ayse',
    avatarPath: 'users/u_ayse/20261008T201501Z_3f9a1c2b7d4e5f60.jpg',
    department: 'd01',
    year: YearLevel.fivePlus,
    interests: ['i01', 'i02'],
    bio: 'Merhaba',
    profileComplete: true,
  );

  group('T-12 · UserProfilePatch · toJson', () {
    test('boş yama hiçbir alan yazmaz', () {
      expect(const UserProfilePatch().toJson(), isEmpty);
      expect(const UserProfilePatch().isEmpty, isTrue);
      expect(full.isEmpty, isFalse);
    });

    test('dolu yama tam olarak sahibinin değiştirebildiği 9 alanı yazar; '
        'yıl JSON değeriyle', () {
      expect(full.toJson(), {
        'name': 'Ayşe Işık',
        'nameLower': 'ayşe ışık',
        'avatarSeed': 'u_ayse',
        'avatarPath': 'users/u_ayse/20261008T201501Z_3f9a1c2b7d4e5f60.jpg',
        'department': 'd01',
        'year': '5plus',
        'interests': ['i01', 'i02'],
        'bio': 'Merhaba',
        'profileComplete': true,
      });
    });

    test('yetki ve silme alanları hiçbir yamada yazılamaz', () {
      const forbidden = {
        'status',
        'staff',
        'suspendReason',
        'email',
        'isDeleted',
        'deletedAt',
        'deletedBy',
        'createdAt',
        'updatedAt',
      };

      expect(full.toJson().keys.toSet().intersection(forbidden), isEmpty);
    });

    test('yalnızca verilen alanlar yazılır (false ve boş değerler dahil)', () {
      expect(const UserProfilePatch(bio: '').toJson(), {'bio': ''});
      expect(const UserProfilePatch(profileComplete: false).toJson(), {
        'profileComplete': false,
      });
      expect(const UserProfilePatch(interests: []).toJson(), {
        'interests': <String>[],
      });
    });

    test('clearAvatarPath avatarPath alanını null yazar', () {
      const patch = UserProfilePatch(bio: 'x', clearAvatarPath: true);

      expect(patch.toJson(), {'bio': 'x', 'avatarPath': null});
      expect(patch.toJson().containsKey('avatarPath'), isTrue);
      expect(patch.isEmpty, isFalse);
    });

    test('clearAvatarPath ile avatarPath birlikte verilemez', () {
      expect(
        () => UserProfilePatch(
          avatarPath: 'users/u/x.jpg',
          clearAvatarPath: true,
        ),
        throwsAssertionError,
      );
    });
  });

  group('T-12 · UserProfilePatch · eşitlik', () {
    test('her alan eşitliğe girer; props 10 alan taşır', () {
      expect(full.props, hasLength(10));
      expect(
        full,
        const UserProfilePatch(
          name: 'Ayşe Işık',
          nameLower: 'ayşe ışık',
          avatarSeed: 'u_ayse',
          avatarPath: 'users/u_ayse/20261008T201501Z_3f9a1c2b7d4e5f60.jpg',
          department: 'd01',
          year: YearLevel.fivePlus,
          interests: ['i01', 'i02'],
          bio: 'Merhaba',
          profileComplete: true,
        ),
      );
      for (final other in const [
        UserProfilePatch(name: 'x'),
        UserProfilePatch(nameLower: 'x'),
        UserProfilePatch(avatarSeed: 'x'),
        UserProfilePatch(avatarPath: 'x'),
        UserProfilePatch(department: 'x'),
        UserProfilePatch(year: YearLevel.prep),
        UserProfilePatch(interests: ['x']),
        UserProfilePatch(bio: 'x'),
        UserProfilePatch(profileComplete: true),
        UserProfilePatch(clearAvatarPath: true),
      ]) {
        expect(other, isNot(const UserProfilePatch()), reason: '$other');
      }
    });
  });
}
