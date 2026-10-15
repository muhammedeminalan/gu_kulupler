// `CommentRepository` fake'i (PLAN §16.3): yorumları bellekte tutar ve
// gönderinin yorum sayacını paylaşılan `FakePostRepository` üzerinde işler.
//
//   final posts = FakePostRepository(clock)..put(PostModelFixtures.p01);
//   final comments = FakeCommentRepository(clock, posts: posts);
//   await comments.add(postId: 'p01', clubId: 'c01', authorId: 'u1', text: '…');
//   expect(posts.posts['p01']!.commentCount, 4);
//   comments.watchCommentsController('p01').add(const FirebaseFailure(…));
//
// Gerçek repository + Security Rules'un birlikte verdiği sonuçları izler
// (docs/plans/T-19.md §6): yorum yazımı, kaldırma ve geri alma gönderinin
// `commentCount` ±1 ve `lastCommentRef` yazımıyla **birliktedir**; gizleme
// sayacı değiştirmez. Rules'un reddettiği **kör** yazımlar `permissionDenied`
// döner ve hiçbir şey değişmez: olmayan / silinmiş / gizli gönderiye yorum,
// çift kaldırma, silinmemiş yorumu geri alma, olmayan yorum, çift gizleme.
// `getComment` süper admin okumasını izler (W-103): gizli yorum döner,
// silinmiş `notFound`, olmayan `permissionDenied`.
// Çağıranın rolü burada bilinmez: yetki reddini test
// `failNext(FirestoreError.permissionDenied)` ile kurar. Engellenen yazarlar
// süzülmez (ViewModel süzer).
import 'dart:async';

import 'package:gu_data/gu_data.dart';

import 'fake_base.dart';
import 'fake_post_repository.dart';

/// `watchComments` akışının tek olayı.
typedef FakeCommentsEvent = FirestoreResult<List<CommentModel>>;

final class FakeCommentRepository extends FakeBase
    implements CommentRepository {
  /// "Şu an" [_clock] saatidir. Gönderinin varlığı ve yorum sayacı [posts]
  /// üzerinden okunur / işlenir; verilmezse fake kendi boş gönderi fake'ini
  /// kurar.
  FakeCommentRepository(this._clock, {FakePostRepository? posts})
    : postRepository = posts ?? FakePostRepository(_clock);

  final AppClock _clock;

  /// Yorum sayacının tutulduğu gönderi fake'i (`commentCount`,
  /// `lastCommentRef`).
  final FakePostRepository postRepository;

  /// `comments/{commentId}` belgeleri (silinmiş ve gizlenmişler dahil). Test
  /// ön veriyi [put] ile yazar.
  final Map<String, CommentModel> comments = <String, CommentModel>{};

  /// Başarılı [add] çağrılarının yazdığı yorumlar, sırasıyla.
  final List<CommentModel> added = <CommentModel>[];

  /// Açık `watchComments` dinleyicisi sayısı.
  int activeListeners = 0;

  final Map<String, StreamController<FakeCommentsEvent>> _controllers =
      <String, StreamController<FakeCommentsEvent>>{};
  int _generated = 0;

  /// [postId] akışının denetleyicisi: test elle olay yazar (hata dahil).
  StreamController<FakeCommentsEvent> watchCommentsController(String postId) =>
      _controllers.putIfAbsent(
        postId,
        StreamController<FakeCommentsEvent>.broadcast,
      );

  /// [comment] belgesini yazar (varsa üzerine) ve gönderisinin akışını
  /// günceller. Gönderinin `commentCount` değerine **dokunmaz**: ön veride
  /// sayaç gönderi belgesiyle birlikte kurulur.
  void put(CommentModel comment) {
    comments[comment.id] = comment;
    _emit(comment.postId);
  }

  @override
  Future<FirestoreResult<CommentModel>> add({
    required String postId,
    required String clubId,
    required String authorId,
    required String text,
  }) async {
    record('add', [postId, clubId, authorId, text]);
    if (_rejected<CommentModel>([postId, clubId, authorId])
        case final failure?) {
      return failure;
    }
    if (FieldValidators.comment(text) != null) {
      return const FirebaseFailure(FirestoreError.invalidArgument);
    }
    final post = postRepository.posts[postId];
    if (post == null ||
        post.clubId != clubId ||
        post.isDeleted ||
        post.isHidden) {
      return _denied();
    }
    final now = _clock.nowUtc();
    final comment = CommentModel(
      id: 'cm_fake_${++_generated}',
      postId: postId,
      clubId: clubId,
      authorId: authorId,
      text: text,
      createdAt: now,
      updatedAt: now,
    );
    comments[comment.id] = comment;
    added.add(comment);
    postRepository.bumpComments(postId, 1, comment.id);
    _emit(postId);
    return FirebaseSuccess(comment);
  }

  @override
  Future<FirestoreResult<void>> softDeleteComment(
    String commentId, {
    required String postId,
    required String actorId,
  }) async {
    record('softDeleteComment', [commentId, postId, actorId]);
    if (_rejected<void>([commentId, postId, actorId]) case final failure?) {
      return failure;
    }
    final comment = comments[commentId];
    if (comment == null || comment.postId != postId || comment.isDeleted) {
      return _denied();
    }
    final now = _clock.nowUtc();
    comments[commentId] = comment.copyWith(
      isDeleted: true,
      deletedAt: now,
      deletedBy: actorId,
      updatedAt: now,
    );
    postRepository.bumpComments(postId, -1, commentId);
    _emit(postId);
    return const FirebaseSuccess(null);
  }

  @override
  Future<FirestoreResult<void>> restoreComment(
    String commentId, {
    required String postId,
  }) async {
    record('restoreComment', [commentId, postId]);
    if (_rejected<void>([commentId, postId]) case final failure?) {
      return failure;
    }
    final comment = comments[commentId];
    if (comment == null || comment.postId != postId || !comment.isDeleted) {
      return _denied();
    }
    comments[commentId] = comment.copyWith(
      isDeleted: false,
      clearDeletedAt: true,
      clearDeletedBy: true,
      updatedAt: _clock.nowUtc(),
    );
    postRepository.bumpComments(postId, 1, commentId);
    _emit(postId);
    return const FirebaseSuccess(null);
  }

  @override
  Stream<FirestoreResult<List<CommentModel>>> watchComments(
    String postId, {
    required String clubId,
  }) {
    record('watchComments', [postId, clubId]);
    if (![postId, clubId].every(RepositoryHelpers.isValidId)) {
      return Stream.value(
        const FirebaseFailure(FirestoreError.invalidArgument),
      );
    }
    final source = watchCommentsController(postId);
    late final StreamController<FakeCommentsEvent> output;
    StreamSubscription<FakeCommentsEvent>? subscription;
    output = StreamController<FakeCommentsEvent>(
      onListen: () {
        activeListeners++;
        // İlk anlık görüntü (Firestore dinleyicisi gibi), sonra değişiklikler.
        output.add(FirebaseSuccess(_visible(postId, clubId)));
        subscription = source.stream.listen(output.add);
      },
      onCancel: () {
        activeListeners--;
        return subscription?.cancel();
      },
    );
    return output.stream;
  }

  /// Süper admin okuması gibi (W-103): gizlenmiş yorum döner; silinmiş
  /// yorum `notFound`; olmayan yorum `permissionDenied` (Rules açıkken).
  @override
  Future<FirestoreResult<CommentModel>> getComment(String commentId) async {
    record('getComment', [commentId]);
    if (_rejected<CommentModel>([commentId]) case final failure?) {
      return failure;
    }
    final comment = comments[commentId];
    if (comment == null) return _denied();
    if (comment.isDeleted) {
      return const FirebaseFailure(FirestoreError.notFound);
    }
    return FirebaseSuccess(comment);
  }

  @override
  Future<FirestoreResult<void>> hide(
    String commentId, {
    required String actorId,
  }) async {
    record('hide', [commentId, actorId]);
    if (_rejected<void>([commentId, actorId]) case final failure?) {
      return failure;
    }
    final comment = comments[commentId];
    if (comment == null || comment.isHidden) return _denied();
    final now = _clock.nowUtc();
    // Sayaç ve işaretçi değişmez: `commentCount` silinmemiş yorumları sayar.
    comments[commentId] = comment.copyWith(
      isHidden: true,
      hiddenBy: actorId,
      hiddenAt: now,
      updatedAt: now,
    );
    _emit(comment.postId);
    return const FirebaseSuccess(null);
  }

  /// [postId] gönderisinin silinmemiş ve gizlenmemiş yorumları, eskiden
  /// yeniye; [clubId] verilirse yalnızca o kulübün yorumları (sorgu
  /// sözleşmesindeki `clubId` süzgeci).
  List<CommentModel> _visible(String postId, String? clubId) => [
    for (final comment in comments.values)
      if (comment.postId == postId &&
          (clubId == null || comment.clubId == clubId) &&
          !comment.isDeleted &&
          !comment.isHidden)
        comment,
  ]..sort(_oldestFirst);

  void _emit(String postId) {
    final controller = _controllers[postId];
    if (controller == null || !controller.hasListener) return;
    controller.add(
      FirebaseSuccess(_visible(postId, postRepository.posts[postId]?.clubId)),
    );
  }

  /// `createdAt` artan; zamanı olmayan yorum sonda.
  static int _oldestFirst(CommentModel a, CommentModel b) {
    final left = a.createdAt;
    final right = b.createdAt;
    if (left == null || right == null) {
      return left == right ? 0 : (left == null ? 1 : -1);
    }
    return left.compareTo(right);
  }

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
