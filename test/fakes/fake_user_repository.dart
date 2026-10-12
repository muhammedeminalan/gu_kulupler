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
//
// `updateAvatar` (T-14) gerçek çağrı kısıtını uygular (W-57): profil
// tamamlanmadan tek başına çağrı `failedPrecondition`; ilgi alanlarını içeren
// `profile` yamasıyla birlikte tek yazım. Yükleme adımı hatası için
// `failNext(StorageError.…)`, belge adımı için `failNext(FirestoreError.…)`:
//
//   users.failNext(StorageError.unauthorized);
//   expect(users.avatarUploads.single.path, startsWith('users/u1/'));
import 'dart:async';
import 'dart:typed_data';

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

/// Başarılı `updateAvatar` çağrısı: yüklenen görsel, birlikte yazılan yama
/// (yoksa `null`) ve yazılan yol.
typedef FakeAvatarUpload = ({
  String uid,
  Uint8List bytes,
  String contentType,
  UserProfilePatch? profile,
  String path,
});

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

  /// Başarılı `updateAvatar` çağrıları, sırasıyla.
  final List<FakeAvatarUpload> avatarUploads = <FakeAvatarUpload>[];

  /// Verilirse [updateAvatar] yükleme "bittikten" sonra, belge yazımından
  /// önce bunu bekler (yükleme sürerken ekran durumu testte elle kurulur).
  Completer<void>? avatarUploadGate;

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
    users[uid] = _patched(user, patch);
    profilePatches.add((uid: uid, patch: patch));
    return const FirebaseSuccess(null);
  }

  /// Gerçek repository'nin sırasıyla: kimlik / yama → içerik türü → ön koşul
  /// (W-57) → yükleme → tek belge yazımı. `failNext(StorageError)` yükleme
  /// adımını, `failNext(FirestoreError)` belge yazımını başarısız kılar
  /// (dosya "yüklenmiş" sayılır ama `avatarPath` değişmez).
  @override
  Future<MediaUpdateResult<String>> updateAvatar(
    String uid, {
    required Uint8List bytes,
    required String contentType,
    UserProfilePatch? profile,
    void Function(double fraction)? onProgress,
  }) async {
    record('updateAvatar', [uid, bytes.length, contentType, profile]);
    final injected = takeFailure();
    if (!RepositoryHelpers.isValidId(uid) ||
        (profile != null &&
            (profile.avatarPath != null || profile.clearAvatarPath))) {
      return _documentFailure(FirestoreError.invalidArgument);
    }
    final extension = StoragePaths.extensionByContentType[contentType];
    if (extension == null) return _uploadFailure(StorageError.invalidType);

    final patchedInterests = profile?.interests;
    if (patchedInterests == null || patchedInterests.isEmpty) {
      final current = users[uid];
      if (current == null) return _documentFailure(FirestoreError.notFound);
      if (!current.staff && (patchedInterests ?? current.interests).isEmpty) {
        return _documentFailure(FirestoreError.failedPrecondition);
      }
    }

    if (bytes.isEmpty) return _uploadFailure(StorageError.noFile);
    if (bytes.length >= Limits.imageMaxBytes) {
      return _uploadFailure(StorageError.sizeLimit);
    }
    if (injected case final StorageError error) return _uploadFailure(error);
    onProgress?.call(1);
    if (avatarUploadGate case final gate?) await gate.future;

    if (injected != null) {
      return _documentFailure(
        injected is FirestoreError ? injected : FirestoreError.unknown,
      );
    }
    final user = users[uid];
    if (user == null) return _documentFailure(FirestoreError.notFound);
    final path = StoragePaths.userAvatar(uid, _nextFileName(extension));
    users[uid] = _patched(
      profile == null ? user : _patched(user, profile),
      UserProfilePatch(avatarPath: path),
    );
    avatarUploads.add((
      uid: uid,
      bytes: bytes,
      contentType: contentType,
      profile: profile,
      path: path,
    ));
    return FirebaseSuccess(path);
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

  /// [patch] alanları [user] üzerine uygulanmış kopya.
  static UserModel _patched(UserModel user, UserProfilePatch patch) =>
      user.copyWith(
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

  /// `StoragePaths.newFileName` şemasında, her çağrıda farklı dosya adı
  /// (sabit damga + artan sayaç).
  String _nextFileName(String extension) {
    final serial = (++_avatarSerial).toRadixString(16).padLeft(16, '0');
    return '20261012T163000Z_$serial.$extension';
  }

  int _avatarSerial = 0;

  static MediaUpdateResult<String> _uploadFailure(StorageError error) =>
      FirebaseFailure(MediaUploadError(error));

  static MediaUpdateResult<String> _documentFailure(FirestoreError error) =>
      FirebaseFailure(MediaDocumentError(error));

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
