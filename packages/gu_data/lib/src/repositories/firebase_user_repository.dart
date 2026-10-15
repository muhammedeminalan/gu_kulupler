import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:gu_data/src/constants/firestore_collections.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/constants/limits.dart';
import 'package:gu_data/src/constants/storage_paths.dart';
import 'package:gu_data/src/core/app_clock.dart';
import 'package:gu_data/src/core/base_fields.dart';
import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/core/media_update_error.dart';
import 'package:gu_data/src/core/storage_error.dart';
import 'package:gu_data/src/models/fcm_token_model.dart';
import 'package:gu_data/src/models/user_account_model.dart';
import 'package:gu_data/src/models/user_model.dart';
import 'package:gu_data/src/models/user_profile_patch.dart';
import 'package:gu_data/src/repositories/firebase_settings_repository.dart';
import 'package:gu_data/src/repositories/query_x.dart';
import 'package:gu_data/src/repositories/repository_helpers.dart';
import 'package:gu_data/src/repositories/user_repository.dart';
import 'package:gu_data/src/services/firestore_service.dart';
import 'package:gu_data/src/services/firestore_types.dart';
import 'package:gu_data/src/services/storage_service.dart';
import 'package:gu_data/src/utils/field_validators.dart';

/// [UserRepository] uygulaması: `users/{uid}` ve
/// `users/{uid}/private/account` (PLAN §10.4); profil fotoğrafı
/// `users/{uid}/{file}` Storage yolunda (PLAN §11.5).
final class FirebaseUserRepository implements UserRepository {
  /// [_firestore] üzerinden okur ve yazar; profil fotoğrafını [_storage] ile
  /// yükler. Dosya adı damgası [_clock] saatinden, rastgele kısmı [_random]
  /// kaynağından gelir: kompozisyon kökü kriptografik kaynak verir
  /// (`Random.secure()` — ad tahmin edilemez); `gu_data` rastgele kaynağı
  /// kendisi kurmaz.
  FirebaseUserRepository(
    this._firestore,
    this._storage,
    this._clock,
    this._random,
  );

  final FirestoreService _firestore;
  final StorageService _storage;
  final AppClock _clock;
  final Random _random;

  @override
  Future<FirestoreResult<UserModel?>> getUser(String uid) async {
    if (RepositoryHelpers.rejectInvalidIds<UserModel?>({'uid': uid})
        case final rejected?) {
      return rejected;
    }
    // Silinmiş (anonim) kullanıcı da döner: yazar gösterimi (PLAN §10.3).
    return RepositoryHelpers.parseOrNull(
      await _firestore.getDoc(_userRef(uid)),
      _userOf,
      includeDeleted: true,
    );
  }

  @override
  Future<FirestoreResult<List<UserModel>>> getUsers(List<String> uids) async {
    final unique = uids.toSet().toList();
    if (!unique.every(RepositoryHelpers.isValidId)) {
      return RepositoryHelpers.invalidArgument('geçersiz kimlik: uids');
    }
    final found = <String, UserModel>{};
    for (final chunk in unique.slices(RepositoryHelpers.whereInMax)) {
      final result = RepositoryHelpers.parseAll(
        await _firestore.getList(
          _firestore
              .collection(FirestoreCollections.users)
              .where(FieldPath.documentId, whereIn: chunk),
        ),
        _userOf,
      );
      switch (result) {
        case FirebaseFailure():
          return result;
        case FirebaseSuccess(data: final users):
          for (final user in users) {
            found[user.uid] = user;
          }
      }
    }
    return FirebaseSuccess([for (final uid in unique) ?found[uid]]);
  }

  @override
  Future<FirestoreResult<void>> createProfile({
    required String uid,
    required String email,
    required String name,
    required String nameLower,
    required String avatarSeed,
  }) async {
    final rejected =
        RepositoryHelpers.rejectInvalidIds<void>({'uid': uid}) ??
        RepositoryHelpers.rejectInvalidFields<void>({
          FirestoreFields.email: FieldValidators.universityEmail(email),
          FirestoreFields.name: FieldValidators.name(name),
          FirestoreFields.nameLower: FieldValidators.nameLower(nameLower),
          FirestoreFields.avatarSeed: FieldValidators.avatarSeed(avatarSeed),
        });
    if (rejected != null) return rejected;

    // Model varsayılanları: status active, profileComplete/staff false,
    // interests [], bio ''. `null` alanların anahtarı yazılmaz (W-51).
    final user = UserModel(
      name: name,
      nameLower: nameLower,
      avatarSeed: avatarSeed,
    );
    final account = UserAccountModel(
      email: email,
      emailLower: email.toLowerCase(),
    );
    final userRef = _userRef(uid);
    final accountRef = _accountRef(uid);
    final settingsRef = _firestore.doc(FirestoreCollections.settings, uid);
    final result = await _firestore.commitBatch((batch) {
      batch
        ..set(userRef, {...user.toJson(), ...BaseFieldsPayload.create()})
        ..set(accountRef, {
          ...account.toJson(),
          ...BaseFieldsPayload.create(),
        })
        ..set(settingsRef, FirebaseSettingsRepository.defaultsPayload(uid));
    });
    // Yeniden deneme güvenli olmalı: ilk çağrı istemcide zaman aşımına
    // düşüp SDK kuyruğundan sonradan işlenmişse belge vardır ve Rules ikinci
    // `set`'i reddeder (belge varken create yok). Profil zaten oluşmuşsa
    // sonuç başarıdır; aksi halde (doğrulanmamış oturum vb.) ret aynen döner.
    if (result.errorOrNull == FirestoreError.permissionDenied &&
        (await getUser(uid)).dataOrNull != null) {
      return const FirebaseSuccess(null);
    }
    return result;
  }

  @override
  Future<FirestoreResult<void>> updateProfile(
    String uid,
    UserProfilePatch patch,
  ) async {
    final rejected =
        RepositoryHelpers.rejectInvalidIds<void>({'uid': uid}) ??
        _rejectPatch(uid, patch);
    if (rejected != null) return rejected;
    return _firestore.update(_userRef(uid), patch.toJson());
  }

  @override
  Future<MediaUpdateResult<String>> updateAvatar(
    String uid, {
    required Uint8List bytes,
    required String contentType,
    UserProfilePatch? profile,
    void Function(double fraction)? onProgress,
  }) async {
    final rejected =
        RepositoryHelpers.rejectInvalidIds<void>({'uid': uid}) ??
        (profile == null ? null : _rejectAvatarCompanion(uid, profile));
    if (rejected case FirebaseFailure(:final error, :final message)) {
      return FirebaseFailure(MediaDocumentError(error), message: message);
    }
    final extension = StoragePaths.extensionByContentType[contentType];
    if (extension == null) {
      return const FirebaseFailure(MediaUploadError(StorageError.invalidType));
    }
    // W-57: Rules, sahibinin güncellemesinde birleşmiş belgede en az bir ilgi
    // alanı ister. Koşul tutmayacaksa dosya hiç yüklenmez (yetim dosya ve
    // anlamsız `permission-denied` yerine açık ön koşul hatası).
    if (await _avatarPreconditionError(uid, profile) case final error?) {
      return FirebaseFailure(MediaDocumentError(error));
    }

    final upload = await _storage.upload(
      path: StoragePaths.userAvatar(
        uid,
        StoragePaths.newFileName(_clock, _random, extension),
      ),
      bytes: bytes,
      contentType: contentType,
      onProgress: onProgress,
    );
    switch (upload) {
      case FirebaseFailure(:final error, :final message):
        return FirebaseFailure(MediaUploadError(error), message: message);
      case FirebaseSuccess(data: final path):
        final written = await _firestore.update(_userRef(uid), {
          ...?profile?.toJson(),
          FirestoreFields.avatarPath: path,
        });
        return switch (written) {
          FirebaseSuccess() => FirebaseSuccess(path),
          // Dosya yerinde kalır (D-10); `avatarPath` eski değerindedir.
          FirebaseFailure(:final error, :final message) => FirebaseFailure(
            MediaDocumentError(error),
            message: message,
          ),
        };
    }
  }

  @override
  Future<FirestoreResult<UserAccountModel?>> getPrivateAccount(
    String uid,
  ) async {
    if (RepositoryHelpers.rejectInvalidIds<UserAccountModel?>({'uid': uid})
        case final rejected?) {
      return rejected;
    }
    return RepositoryHelpers.parseOrNull(
      await _firestore.getDoc(_accountRef(uid)),
      (doc) => UserAccountModel.fromJson(doc.data),
    );
  }

  @override
  Future<FirestoreResult<void>> touchLastLogin(String uid) async {
    if (RepositoryHelpers.rejectInvalidIds<void>({'uid': uid})
        case final rejected?) {
      return rejected;
    }
    return _firestore.update(_accountRef(uid), {
      FirestoreFields.lastLoginAt: _firestore.serverTimestamp(),
    });
  }

  @override
  Future<FirestoreResult<void>> upsertFcmToken(
    String uid,
    FcmTokenModel token,
  ) async {
    if (RepositoryHelpers.rejectInvalidIds<void>({'uid': uid})
        case final rejected?) {
      return rejected;
    }
    if (FieldValidators.fcmToken(token.token) != null ||
        !Limits.platforms.contains(token.platform) ||
        !FcmTokenModel.locales.contains(token.locale)) {
      return RepositoryHelpers.invalidArgument(
        'upsertFcmToken: geçersiz jeton, platform ya da dil',
      );
    }
    return _changeTokens(
      uid,
      (current) => FcmTokenModel.upserted(current, token),
    );
  }

  @override
  Future<FirestoreResult<void>> removeFcmToken(String uid, String token) async {
    if (RepositoryHelpers.rejectInvalidIds<void>({'uid': uid})
        case final rejected?) {
      return rejected;
    }
    if (token.isEmpty) {
      return RepositoryHelpers.invalidArgument('removeFcmToken: boş jeton');
    }
    return _changeTokens(
      uid,
      (current) => [
        for (final item in current)
          if (item.token != token) item,
      ],
    );
  }

  @override
  Future<FirestoreResult<List<UserModel>>> listByInterests(
    List<String> interestIds, {
    int limit = Limits.eventNewInterestFanOutMax,
  }) async {
    final unique = interestIds.toSet().toList();
    if (unique.isEmpty) return const FirebaseSuccess([]);
    if (unique.length > RepositoryHelpers.whereInMax ||
        !unique.every(RepositoryHelpers.isValidId) ||
        limit <= 0) {
      return RepositoryHelpers.invalidArgument(
        'listByInterests: geçersiz ilgi listesi ya da sınır',
      );
    }
    return RepositoryHelpers.parseAll(
      await _firestore.getList(
        _firestore
            .collection(FirestoreCollections.users)
            .where(FirestoreFields.interests, arrayContainsAny: unique)
            .notDeleted()
            .limit(limit),
      ),
      _userOf,
    );
  }

  /// [updateAvatar] ile birlikte yazılacak [profile] yamasını doğrular:
  /// `avatarPath` alanını metot kendisi yazar, yama taşıyamaz.
  static FirestoreResult<void>? _rejectAvatarCompanion(
    String uid,
    UserProfilePatch profile,
  ) {
    if (profile.avatarPath != null || profile.clearAvatarPath) {
      return RepositoryHelpers.invalidArgument(
        'updateAvatar: profile yaması avatarPath / clearAvatarPath taşıyamaz',
      );
    }
    return _rejectPatch(uid, profile);
  }

  /// [updateAvatar] ön koşulu (W-57): yazım sonrasında belgede en az bir
  /// ilgi alanı olmalı (personel hariç). Koşul tutuyorsa `null`.
  ///
  /// [profile] dolu bir ilgi alanı listesi taşıyorsa belge okunmaz (AUT-05:
  /// tek güncelleme); aksi halde `users/{uid}` bir kez okunur.
  Future<FirestoreError?> _avatarPreconditionError(
    String uid,
    UserProfilePatch? profile,
  ) async {
    final patched = profile?.interests;
    if (patched != null && patched.isNotEmpty) return null;
    final current = await getUser(uid);
    switch (current) {
      case FirebaseFailure(:final error):
        return error;
      case FirebaseSuccess(data: null):
        return FirestoreError.notFound;
      case FirebaseSuccess(data: final user?):
        final interests = patched ?? user.interests;
        return user.staff || interests.isNotEmpty
            ? null
            : FirestoreError.failedPrecondition;
    }
  }

  /// [patch] alanlarını yazmadan önce doğrular; geçerliyse `null`.
  ///
  /// İlgi alanlarının alt sınırı burada aranmaz (personelde boş liste
  /// serbesttir ve repository `staff` bilgisini okumaz): form ve Security
  /// Rules uygular.
  static FirestoreResult<void>? _rejectPatch(
    String uid,
    UserProfilePatch patch,
  ) {
    if ((patch.name == null) != (patch.nameLower == null)) {
      return RepositoryHelpers.invalidArgument(
        'updateProfile: name ve nameLower birlikte verilmeli',
      );
    }
    return RepositoryHelpers.rejectInvalidFields<void>({
      if (patch.name case final value?)
        FirestoreFields.name: FieldValidators.name(value),
      if (patch.nameLower case final value?)
        FirestoreFields.nameLower: FieldValidators.nameLower(value),
      if (patch.avatarSeed case final value?)
        FirestoreFields.avatarSeed: FieldValidators.avatarSeed(value),
      if (patch.avatarPath case final value?)
        FirestoreFields.avatarPath: StoragePaths.isUserAvatar(value, uid)
            ? null
            : FieldError.invalidFormat,
      if (patch.department case final value?)
        FirestoreFields.department: FieldValidators.department(value),
      if (patch.interests case final value?)
        FirestoreFields.interests: FieldValidators.interests(
          value,
          staff: true,
        ),
      if (patch.bio case final value?)
        FirestoreFields.bio: FieldValidators.bio(value),
    });
  }

  static UserModel _userOf(FirestoreDoc doc) =>
      UserModel.fromJson(doc.data, id: doc.id);

  DocumentReference<Json> _userRef(String uid) =>
      _firestore.doc(FirestoreCollections.users, uid);

  /// [uid] hesabının `fcmTokens` listesini transaction içinde [change] ile
  /// değiştirir (`fcmTokens` + `updatedAt`; Rules `canUpdateOwnAccount`).
  /// Liste değişmezse yazılmaz; belge yoksa [FirestoreError.notFound].
  /// Ayrıştırılamayan eleman (Rules biçimi sabitler; olmamalı) atılır.
  Future<FirestoreResult<void>> _changeTokens(
    String uid,
    List<FcmTokenModel> Function(List<FcmTokenModel> current) change,
  ) async {
    final ref = _accountRef(uid);
    final result = await _firestore.runTransaction<FirestoreResult<void>>((
      tx,
    ) async {
      final data = (await tx.get(ref)).data();
      if (data == null) {
        return FirebaseFailure(
          FirestoreError.notFound,
          message: 'hesap belgesi yok: $uid',
        );
      }
      final current = _tokensOf(data[FirestoreFields.fcmTokens]);
      final next = change(current);
      if (const ListEquality<FcmTokenModel>().equals(current, next)) {
        return const FirebaseSuccess(null);
      }
      tx.update(ref, {
        FirestoreFields.fcmTokens: [for (final item in next) item.toJson()],
        ...BaseFieldsPayload.update(),
      });
      return const FirebaseSuccess(null);
    });
    return switch (result) {
      FirebaseSuccess(:final data) => data,
      FirebaseFailure(:final error, :final message, :final detail) =>
        FirebaseFailure(error, message: message, detail: detail),
    };
  }

  /// `fcmTokens` ham değerinin ayrıştırılabilen elemanları.
  static List<FcmTokenModel> _tokensOf(Object? raw) => [
    if (raw is List<Object?>)
      for (final item in raw)
        if (item is Map<Object?, Object?>) ?_tokenOrNull(item),
  ];

  static FcmTokenModel? _tokenOrNull(Map<Object?, Object?> raw) {
    try {
      return FcmTokenModel.fromJson(raw.cast<String, Object?>());
    } on Object {
      return null;
    }
  }

  DocumentReference<Json> _accountRef(String uid) => _firestore.doc(
    RepositoryHelpers.subcollectionPath(
      FirestoreCollections.users,
      uid,
      FirestoreCollections.privateSub,
    ),
    FirestoreCollections.accountDoc,
  );
}
