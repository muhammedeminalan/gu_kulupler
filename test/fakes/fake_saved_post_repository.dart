// `SavedPostRepository` fake'i (PLAN §16.3): kaydedilen gönderileri bellekte
// tutar.
//
//   final posts = FakePostRepository(clock)..put(PostModelFixtures.p01);
//   final saved = FakeSavedPostRepository(clock, posts: posts);
//   await saved.save(userId: 'u1', postId: 'p01', clubId: 'c01');
//   expect(saved.saved['u1_p01']!.isDeleted, isFalse);
//
// Gerçek repository + Security Rules'un birlikte verdiği sonuçları izler
// (docs/plans/T-19.md §6): kaydı kaldırmak belgeyi silmez, silinmiş olarak
// işaretler (D-10); yeniden kaydetme aynı belgeyi geri yükler ve `savedAt`'i
// yeniler; Geri al (`restoreSaved`) `savedAt`'e dokunmaz; yürürlükteki kaydın
// yeniden kaydedilmesi yazımsız başarıdır. Rules'un reddettiği yazımlar
// `permissionDenied` döner: olmayan / silinmiş / gizli ya da başka kulübün
// gönderisini kaydetme, olmayan ya da zaten kaldırılmış kaydı kaldırma,
// kaldırılmamış kaydı geri alma.
import 'package:gu_data/gu_data.dart';

import 'fake_base.dart';
import 'fake_pager.dart';
import 'fake_post_repository.dart';

final class FakeSavedPostRepository extends FakeBase
    implements SavedPostRepository {
  /// "Şu an" [_clock] saatidir (`savedAt`). Kaydedilecek gönderi [posts]
  /// üzerinden denetlenir; verilmezse fake kendi boş gönderi fake'ini kurar.
  FakeSavedPostRepository(this._clock, {FakePostRepository? posts})
    : postRepository = posts ?? FakePostRepository(_clock);

  final AppClock _clock;

  /// Kaydedilecek gönderinin okunduğu gönderi fake'i.
  final FakePostRepository postRepository;

  /// `savedPosts/{userId}_{postId}` belgeleri (anahtar = belge kimliği;
  /// kaldırılmış kayıtlar `isDeleted` ile durur). Test ön veriyi [put] ile
  /// yazar.
  final Map<String, SavedPostModel> saved = <String, SavedPostModel>{};

  final FakePager _pager = FakePager();

  /// [record] kaydını yazar (varsa üzerine).
  void put(SavedPostModel record) =>
      saved[_key(record.userId, record.postId)] = record;

  @override
  Future<FirestoreResult<void>> save({
    required String userId,
    required String postId,
    required String clubId,
  }) async {
    record('save', [userId, postId, clubId]);
    if (_rejected<void>([userId, postId, clubId]) case final failure?) {
      return failure;
    }
    final key = _key(userId, postId);
    final existing = saved[key];
    final now = _clock.nowUtc();
    if (existing != null) {
      // Kaldırılmışsa geri yüklenir ve `savedAt` yenilenir; yürürlükteyse
      // yazım yok.
      if (existing.isDeleted) {
        saved[key] = existing.copyWith(
          isDeleted: false,
          clearDeletedAt: true,
          clearDeletedBy: true,
          savedAt: now,
          updatedAt: now,
        );
      }
      return const FirebaseSuccess(null);
    }
    final post = postRepository.posts[postId];
    if (post == null ||
        post.clubId != clubId ||
        post.isDeleted ||
        post.isHidden) {
      return _denied();
    }
    saved[key] = SavedPostModel(
      userId: userId,
      postId: postId,
      clubId: clubId,
      savedAt: now,
      createdAt: now,
      updatedAt: now,
    );
    return const FirebaseSuccess(null);
  }

  @override
  Future<FirestoreResult<void>> softDeleteSaved({
    required String userId,
    required String postId,
  }) async {
    record('softDeleteSaved', [userId, postId]);
    if (_rejected<void>([userId, postId]) case final failure?) return failure;
    final key = _key(userId, postId);
    final existing = saved[key];
    if (existing == null || existing.isDeleted) return _denied();
    final now = _clock.nowUtc();
    saved[key] = existing.copyWith(
      isDeleted: true,
      deletedAt: now,
      deletedBy: userId,
      updatedAt: now,
    );
    return const FirebaseSuccess(null);
  }

  @override
  Future<FirestoreResult<void>> restoreSaved({
    required String userId,
    required String postId,
  }) async {
    record('restoreSaved', [userId, postId]);
    if (_rejected<void>([userId, postId]) case final failure?) return failure;
    final key = _key(userId, postId);
    final existing = saved[key];
    if (existing == null || !existing.isDeleted) return _denied();
    // Saf geri alma: `savedAt` değişmez (kayıt listedeki yerine döner).
    saved[key] = existing.copyWith(
      isDeleted: false,
      clearDeletedAt: true,
      clearDeletedBy: true,
      updatedAt: _clock.nowUtc(),
    );
    return const FirebaseSuccess(null);
  }

  @override
  Future<FirestoreResult<PageResult<SavedPostModel>>> listSaved(
    String userId,
    PageRequest page,
  ) async {
    record('listSaved', [userId, page]);
    if (_rejected<PageResult<SavedPostModel>>([userId]) case final failure?) {
      return failure;
    }
    final mine = [
      for (final record in saved.values)
        if (record.userId == userId && !record.isDeleted) record,
    ]..sort(_latestFirst);
    return FirebaseSuccess(_pager.slice(mine, page));
  }

  @override
  Future<FirestoreResult<bool>> isSaved({
    required String userId,
    required String postId,
  }) async {
    record('isSaved', [userId, postId]);
    if (_rejected<bool>([userId, postId]) case final failure?) return failure;
    final existing = saved[_key(userId, postId)];
    return FirebaseSuccess(existing != null && !existing.isDeleted);
  }

  /// `savedAt` azalan; zamanı olmayan kayıt sonda.
  static int _latestFirst(SavedPostModel a, SavedPostModel b) {
    final left = a.savedAt;
    final right = b.savedAt;
    if (left == null || right == null) {
      return left == right ? 0 : (left == null ? 1 : -1);
    }
    return right.compareTo(left);
  }

  static String _key(String userId, String postId) =>
      FirestoreIds.savedPost(userId, postId);

  static FirestoreResult<T> _denied<T>() =>
      const FirebaseFailure(FirestoreError.permissionDenied);

  /// Bekleyen hata ya da geçersiz kimlik varsa başarısızlık; yoksa `null`.
  FirestoreResult<T>? _rejected<T>(List<String> ids) {
    final failure = switch (takeFailure()) {
      null => null,
      final FirestoreError error => error,
      _ => FirestoreError.unknown,
    };
    if (failure != null) return FirebaseFailure(failure);
    if (!ids.every(RepositoryHelpers.isValidId)) {
      return const FirebaseFailure(FirestoreError.invalidArgument);
    }
    return null;
  }
}
