import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:gu_data/src/constants/firestore_collections.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/constants/firestore_ids.dart';
import 'package:gu_data/src/core/base_fields.dart';
import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/core/page_request.dart';
import 'package:gu_data/src/core/page_result.dart';
import 'package:gu_data/src/core/soft_delete.dart';
import 'package:gu_data/src/models/saved_post_model.dart';
import 'package:gu_data/src/repositories/query_x.dart';
import 'package:gu_data/src/repositories/repository_helpers.dart';
import 'package:gu_data/src/repositories/saved_post_repository.dart';
import 'package:gu_data/src/services/firestore_service.dart';
import 'package:gu_data/src/services/firestore_types.dart';

/// [SavedPostRepository] uygulaması: `savedPosts/{userId}_{postId}`
/// (PLAN §10.4).
///
/// Belge kimliği sahibinden ve gönderiden türer; bir çift için tek belge
/// vardır. Kaldır → yeniden kaydet döngüsü aynı belgeyi işaretler ve geri
/// yükler (belge yeniden oluşturulmaz: var olan belgeye `set` Security
/// Rules'ta güncellemedir).
final class FirebaseSavedPostRepository implements SavedPostRepository {
  /// [_firestore] servisi üzerinden okur ve yazar.
  FirebaseSavedPostRepository(this._firestore);

  final FirestoreService _firestore;

  @override
  Future<FirestoreResult<void>> save({
    required String userId,
    required String postId,
    required String clubId,
  }) async {
    if (RepositoryHelpers.rejectInvalidIds<void>({
          'userId': userId,
          'postId': postId,
          'clubId': clubId,
        })
        case final rejected?) {
      return rejected;
    }
    final ref = _ref(userId, postId);
    switch (await _firestore.getDoc(ref)) {
      case FirebaseSuccess(data: final doc?):
        // Kayıt var: kaldırılmışsa geri yüklenir ve `savedAt` yenilenir
        // (liste en son kaydedileni üstte gösterir); yürürlükteyse yazım yok.
        return RepositoryHelpers.isSoftDeleted(doc)
            ? _firestore.update(ref, {
                ...SoftDelete.restorePayload(),
                FirestoreFields.savedAt: _firestore.serverTimestamp(),
              })
            : const FirebaseSuccess(null);
      // Okuma reddi "kayıt yok" anlamına da gelebilir: Security Rules var
      // olmayan belgede sahibi alanını göremez. Oluşturma denenir; yetkiye
      // yine kural karar verir (yetkisiz çağrıda yazım da reddedilir).
      case FirebaseSuccess() ||
          FirebaseFailure(error: FirestoreError.permissionDenied):
        final saved = SavedPostModel(
          userId: userId,
          postId: postId,
          clubId: clubId,
        );
        return _firestore.set(ref, {
          ...saved.toJson(),
          FirestoreFields.savedAt: _firestore.serverTimestamp(),
          ...BaseFieldsPayload.create(),
        });
      case FirebaseFailure(:final error, :final message, :final detail):
        return FirebaseFailure(error, message: message, detail: detail);
    }
  }

  @override
  Future<FirestoreResult<void>> softDeleteSaved({
    required String userId,
    required String postId,
  }) async {
    if (_rejectPair<void>(userId, postId) case final rejected?) {
      return rejected;
    }
    return _firestore.softDelete(_ref(userId, postId), actorId: userId);
  }

  @override
  Future<FirestoreResult<void>> restoreSaved({
    required String userId,
    required String postId,
  }) async {
    if (_rejectPair<void>(userId, postId) case final rejected?) {
      return rejected;
    }
    return _firestore.restore(_ref(userId, postId));
  }

  @override
  Future<FirestoreResult<PageResult<SavedPostModel>>> listSaved(
    String userId,
    PageRequest page,
  ) async {
    if (RepositoryHelpers.rejectInvalidIds<PageResult<SavedPostModel>>({
          'userId': userId,
        })
        case final rejected?) {
      return rejected;
    }
    // Sorgu sözleşmesi (rules-spec §6, PRF-04): sahibi + silinmemiş, en son
    // kaydedilen üstte.
    return RepositoryHelpers.parsePage(
      await _firestore.getPage(
        _firestore
            .collection(FirestoreCollections.savedPosts)
            .where(FirestoreFields.userId, isEqualTo: userId)
            .notDeleted()
            .orderBy(FirestoreFields.savedAt, descending: true),
        page,
      ),
      (doc) => SavedPostModel.fromJson(doc.data, id: doc.id),
    );
  }

  @override
  Future<FirestoreResult<bool>> isSaved({
    required String userId,
    required String postId,
  }) async {
    if (_rejectPair<bool>(userId, postId) case final rejected?) {
      return rejected;
    }
    final read = await _firestore.getDoc(_ref(userId, postId));
    return read.map(
      (doc) => doc != null && !RepositoryHelpers.isSoftDeleted(doc),
    );
  }

  @override
  Future<FirestoreResult<Set<String>>> savedAmong({
    required String userId,
    required List<String> postIds,
  }) async {
    if (RepositoryHelpers.rejectInvalidIds<Set<String>>({'userId': userId})
        case final rejected?) {
      return rejected;
    }
    final unique = postIds.toSet().toList();
    if (!unique.every(RepositoryHelpers.isValidId)) {
      return RepositoryHelpers.invalidArgument('geçersiz kimlik: postIds');
    }
    final saved = <String>{};
    // Boş `whereIn` geçersiz bir sorgudur: boş liste = parça yok.
    for (final chunk in unique.slices(RepositoryHelpers.whereInMax)) {
      // Sahip + silinmemiş süzgeci Rules'un kanıtıdır (rules-spec §6); indeks
      // `userId, isDeleted, postId` (§8).
      final read = await _firestore.getList(
        _firestore
            .collection(FirestoreCollections.savedPosts)
            .where(FirestoreFields.userId, isEqualTo: userId)
            .where(FirestoreFields.postId, whereIn: chunk)
            .notDeleted(),
      );
      switch (read) {
        case FirebaseFailure(:final error, :final message, :final detail):
          return FirebaseFailure(error, message: message, detail: detail);
        case FirebaseSuccess(data: final docs):
          for (final doc in docs) {
            if (doc.data[FirestoreFields.postId] case final String postId) {
              saved.add(postId);
            }
          }
      }
    }
    return FirebaseSuccess(saved);
  }

  /// Kayıt çiftinin kimliklerini doğrular; geçerliyse `null`.
  static FirestoreResult<T>? _rejectPair<T>(String userId, String postId) =>
      RepositoryHelpers.rejectInvalidIds<T>({
        'userId': userId,
        'postId': postId,
      });

  DocumentReference<Json> _ref(String userId, String postId) => _firestore.doc(
    FirestoreCollections.savedPosts,
    FirestoreIds.savedPost(userId, postId),
  );
}
