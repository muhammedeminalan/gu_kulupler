// `UserRepository` fake'i (PLAN §16.3): profilleri ve gizli hesap belgelerini
// bellekte tutar.
//
//   final users = FakeUserRepository()..putActive('u1');
//   users.failNext(FirestoreError.unavailable);
//   expect(users.profilePatches.single.patch.profileComplete, isTrue);
//
// Gerçek repository gibi: geçersiz kimlik `invalidArgument`, belgesi olmayan
// profilin güncellenmesi `notFound`, var olan profilin yeniden oluşturulması
// `permissionDenied` (Rules create yalnızca belge yokken geçer), silinmiş
// kullanıcı okumada döner. Silme metodu yoktur (D-10).
import 'dart:async';

import 'package:gu_data/gu_data.dart';

import 'fake_base.dart';

/// `createProfile` çağrısının argümanları.
typedef FakeCreatedProfile = ({
  String uid,
  String email,
  String name,
  String nameLower,
  String avatarSeed,
});

/// `updateProfile` çağrısının argümanları.
typedef FakeProfilePatch = ({String uid, UserProfilePatch patch});

final class FakeUserRepository extends FakeBase implements UserRepository {
  /// `users/{uid}` belgeleri; test ön veriyi buraya yazar.
  final Map<String, UserModel> users = <String, UserModel>{};

  /// `users/{uid}/private/account` belgeleri.
  final Map<String, UserAccountModel> accounts = <String, UserAccountModel>{};

  /// Başarılı `createProfile` çağrıları, sırasıyla.
  final List<FakeCreatedProfile> createdProfiles = <FakeCreatedProfile>[];

  /// Başarılı `updateProfile` çağrıları, sırasıyla.
  final List<FakeProfilePatch> profilePatches = <FakeProfilePatch>[];

  /// Başarılı `touchLastLogin` çağrılarının uid'leri, sırasıyla.
  final List<String> lastLoginTouches = <String>[];

  /// Verilirse [getUser] sonuç dönmeden önce bunu bekler: okuma sürerken
  /// araya giren olayların (yarış) sırası testte elle kurulur.
  Completer<void>? getUserGate;

  /// [uid] için profili tamamlanmış, aktif bir kullanıcı (ve hesap belgesi)
  /// kurar ve döndürür: doğrulanmış oturum `AuthStatus.active` çözülür.
  UserModel putActive(
    String uid, {
    String name = 'Test Kullanıcı',
    String email = 'test@ogr.gumushane.edu.tr',
  }) {
    final user = UserModel(
      uid: uid,
      name: name,
      nameLower: name.toLowerCase(),
      avatarSeed: uid,
      department: 'd01',
      year: YearLevel.first,
      interests: const ['i01'],
      profileComplete: true,
    );
    users[uid] = user;
    accounts[uid] = UserAccountModel(
      email: email,
      emailLower: email.toLowerCase(),
    );
    return user;
  }

  @override
  Future<FirestoreResult<UserModel?>> getUser(String uid) async {
    record('getUser', [uid]);
    // Bekleyen hata çağrı anında alınır: kapıda beklerken kurulan hata bir
    // sonraki çağrıya kalır.
    final rejected = _rejected<UserModel?>(uid);
    if (getUserGate case final gate?) await gate.future;
    if (rejected != null) return rejected;
    return FirebaseSuccess(users[uid]);
  }

  @override
  Future<FirestoreResult<List<UserModel>>> getUsers(List<String> uids) async {
    record('getUsers', [uids]);
    if (_failure() case final error?) return FirebaseFailure(error);
    if (!uids.every(RepositoryHelpers.isValidId)) {
      return const FirebaseFailure(FirestoreError.invalidArgument);
    }
    return FirebaseSuccess([for (final uid in uids.toSet()) ?users[uid]]);
  }

  @override
  Future<FirestoreResult<void>> createProfile({
    required String uid,
    required String email,
    required String name,
    required String nameLower,
    required String avatarSeed,
  }) async {
    record('createProfile', [uid, email, name, nameLower, avatarSeed]);
    if (_rejected<void>(uid) case final failure?) return failure;
    // Gerçek repository gibi: profil zaten varsa hiçbir şey değişmez, sonuç
    // başarıdır (yeniden deneme güvenli); `createdProfiles`'e yazılmaz.
    if (users.containsKey(uid)) return const FirebaseSuccess(null);
    users[uid] = UserModel(
      uid: uid,
      name: name,
      nameLower: nameLower,
      avatarSeed: avatarSeed,
    );
    accounts[uid] = UserAccountModel(
      email: email,
      emailLower: email.toLowerCase(),
    );
    createdProfiles.add((
      uid: uid,
      email: email,
      name: name,
      nameLower: nameLower,
      avatarSeed: avatarSeed,
    ));
    return const FirebaseSuccess(null);
  }

  @override
  Future<FirestoreResult<void>> updateProfile(
    String uid,
    UserProfilePatch patch,
  ) async {
    record('updateProfile', [uid, patch]);
    if (_rejected<void>(uid) case final failure?) return failure;
    if (patch.isEmpty) {
      return const FirebaseFailure(FirestoreError.invalidArgument);
    }
    final user = users[uid];
    if (user == null) return const FirebaseFailure(FirestoreError.notFound);
    users[uid] = user.copyWith(
      name: patch.name,
      nameLower: patch.nameLower,
      avatarSeed: patch.avatarSeed,
      avatarPath: patch.avatarPath,
      clearAvatarPath: patch.clearAvatarPath,
      department: patch.department,
      year: patch.year,
      interests: patch.interests,
      bio: patch.bio,
      profileComplete: patch.profileComplete,
    );
    profilePatches.add((uid: uid, patch: patch));
    return const FirebaseSuccess(null);
  }

  @override
  Future<FirestoreResult<UserAccountModel?>> getPrivateAccount(
    String uid,
  ) async {
    record('getPrivateAccount', [uid]);
    if (_rejected<UserAccountModel?>(uid) case final failure?) return failure;
    return FirebaseSuccess(accounts[uid]);
  }

  @override
  Future<FirestoreResult<void>> touchLastLogin(String uid) async {
    record('touchLastLogin', [uid]);
    if (_rejected<void>(uid) case final failure?) return failure;
    if (!accounts.containsKey(uid)) {
      return const FirebaseFailure(FirestoreError.notFound);
    }
    lastLoginTouches.add(uid);
    return const FirebaseSuccess(null);
  }

  /// Bekleyen hata ya da geçersiz [uid] varsa başarısızlık; yoksa `null`.
  FirestoreResult<T>? _rejected<T>(String uid) {
    if (_failure() case final error?) return FirebaseFailure(error);
    if (!RepositoryHelpers.isValidId(uid)) {
      return const FirebaseFailure(FirestoreError.invalidArgument);
    }
    return null;
  }

  FirestoreError? _failure() => switch (takeFailure()) {
    null => null,
    final FirestoreError error => error,
    _ => FirestoreError.unknown,
  };
}
