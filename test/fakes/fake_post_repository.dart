// `PostRepository` fake'i (PLAN §16.3): gönderileri, beğenileri, oyları ve
// sabit gönderi işaretçilerini bellekte tutar.
//
//   final posts = FakePostRepository(clock)..put(PostModelFixtures.p01);
//   await posts.like('p01', uid: 'u1');
//   expect(posts.posts['p01']!.likeCount, 1);
//   posts.watchPostController('p01').add(const FirebaseFailure(…));
//
// Gerçek repository + Security Rules'un birlikte verdiği sonuçları izler
// (docs/plans/T-19.md §6):
// - alan doğrulaması gerçek `FieldValidators` ile yapılır (`invalidArgument`);
// - sayaçlar tek yazımda tutarlıdır: `likeCount == likes.length`, kulüp
//   başına en çok bir sabit gönderi ([pinnedByClub] ↔ `pinned`), bildirimli
//   duyuru paylaşılan `FakeAnnouncementCounterRepository` sayacını artırır
//   (günün hakkı dolmuşsa `ruleViolation(announcementLimit)`, yazım yok);
// - Rules'un reddettiği **kör** yazımlar `permissionDenied` döner: çift
//   beğeni, beğenmeden geri alma, silinmiş / gizli gönderiyi beğenme, kapalı
//   ankete ya da olmayan seçeneğe oy, yazar olmayanın düzenlemesi, anket
//   sorusunu (ankette `text`) değiştiren düzenleme, silinmemiş gönderiyi geri
//   yükleme, çift gizleme;
// - **olmayan** gönderinin okuması ve yazımı `permissionDenied`'dır (kulübü
//   bilinemez — üretimde kural böyle döner; ekran bunu `notFound` ile
//   birlikte "içerik yok" sayar); silinmiş gönderi `getPost`, `pin`, `unpin`,
//   `softDeletePost` için `notFound`'dur;
// - ikinci oy `alreadyExists` (oy değiştirilemez).
// Çağıranın rolü (yönetici, üye, süper admin) burada bilinmez: yetki reddini
// test `failNext(FirestoreError.permissionDenied)` ile kurar.
import 'dart:async';

import 'package:gu_data/gu_data.dart';

import 'fake_announcement_counter_repository.dart';
import 'fake_base.dart';
import 'fake_pager.dart';

/// `watchPost` akışının tek olayı.
typedef FakePostEvent = FirestoreResult<PostModel?>;

final class FakePostRepository extends FakeBase implements PostRepository {
  /// "Şu an" [_clock] saatidir (zaman alanları, anket bitişi). Bildirimli
  /// duyuru sayacı [counters] üzerinden tutulur; verilmezse fake kendi
  /// sayacını kurar.
  FakePostRepository(
    this._clock, {
    FakeAnnouncementCounterRepository? counters,
  }) : counterRepository =
           counters ?? FakeAnnouncementCounterRepository(_clock);

  final AppClock _clock;

  /// Bildirimli duyuruların günlük sayacı (yayınla aynı işlemde artar).
  final FakeAnnouncementCounterRepository counterRepository;

  /// `posts/{postId}` belgeleri (silinmiş ve gizlenmişler dahil). Test ön
  /// veriyi [put] ile yazar.
  final Map<String, PostModel> posts = <String, PostModel>{};

  /// `posts/{postId}/votes/{uid}`: gönderi → (uid → seçenek kimliği).
  final Map<String, Map<String, String>> votes =
      <String, Map<String, String>>{};

  /// `clubs.pinnedPostId`: kulüp → sabit gönderi (sabit yoksa anahtar yok).
  final Map<String, String> pinnedByClub = <String, String>{};

  /// [newPostId] sıradaki kimliği buradan alır; boşsa `p_fake_N` üretir.
  final List<String> newPostIdQueue = <String>[];

  /// Açık `watchPost` dinleyicisi sayısı.
  int activeListeners = 0;

  final Map<String, StreamController<FakePostEvent>> _controllers =
      <String, StreamController<FakePostEvent>>{};
  final FakePager _pager = FakePager();
  int _generated = 0;

  /// Gönderi → beğenen uid'ler (`posts.likes` görünümü).
  Map<String, List<String>> get likesByPost => {
    for (final post in posts.values) post.id: post.likes,
  };

  /// [postId] akışının denetleyicisi: test elle olay yazar (hata dahil).
  StreamController<FakePostEvent> watchPostController(String postId) =>
      _controllers.putIfAbsent(
        postId,
        StreamController<FakePostEvent>.broadcast,
      );

  /// [post] belgesini yazar (varsa üzerine), sabitse kulübün işaretçisini
  /// kurar ve gönderinin akışını günceller.
  void put(PostModel post) {
    posts[post.id] = post;
    if (post.pinned && !post.isDeleted) pinnedByClub[post.clubId] = post.id;
    _emit(post.id);
  }

  /// Yorum sayacını [delta] kadar oynatır ve işaretçiyi [commentId] yorumuna
  /// çevirir (`FakeCommentRepository` yorum yazımıyla birlikte çağırır).
  void bumpComments(String postId, int delta, String commentId) {
    final post = posts[postId];
    if (post == null) return;
    posts[postId] = post.copyWith(
      commentCount: post.commentCount + delta,
      lastCommentRef: FirestoreIds.commentRef(commentId),
      updatedAt: _clock.nowUtc(),
    );
    _emit(postId);
  }

  @override
  String newPostId() {
    record('newPostId');
    return newPostIdQueue.isEmpty
        ? 'p_fake_${++_generated}'
        : newPostIdQueue.removeAt(0);
  }

  @override
  Future<FirestoreResult<PostModel>> create(
    PostDraft draft, {
    required String authorId,
    required String clubId,
    required String postId,
  }) async {
    record('create', [draft, authorId, clubId, postId]);
    if (_rejected<PostModel>([authorId, clubId, postId]) case final failure?) {
      return failure;
    }
    if (!_draftOk(draft, postId)) return _invalid();
    // Var olan kimliğe yazım kurallarda güncellemedir: reddedilir.
    if (posts.containsKey(postId)) return _denied();
    final pushSent = draft.pushSent && draft.type == PostType.announcement;
    if (pushSent && !counterRepository.tryBump(clubId)) {
      return const FirebaseFailure(
        FirestoreError.ruleViolation,
        detail: FirestoreFailureDetail(FirestoreRuleCode.announcementLimit),
      );
    }
    final now = _clock.nowUtc();
    final poll = draft.poll;
    final post = PostModel(
      id: postId,
      clubId: clubId,
      authorId: authorId,
      type: draft.type,
      title: draft.title,
      text: draft.text,
      images: draft.images,
      poll: poll == null
          ? null
          : PollModel(
              options: [
                for (final (index, text) in poll.options.indexed)
                  PollOptionModel(
                    id: FirestoreIds.pollOption(index),
                    text: text,
                  ),
              ],
              endsAt: now.add(Duration(days: poll.durationDays)),
              showResultsAfterVote: poll.showResultsAfterVote,
            ),
      pushSent: pushSent,
      createdAt: now,
      updatedAt: now,
    );
    _write(post);
    return FirebaseSuccess(post);
  }

  @override
  Future<FirestoreResult<void>> update(
    String postId,
    PostEditPatch patch, {
    required String authorId,
  }) async {
    record('update', [postId, patch, authorId]);
    if (_rejected<void>([postId, authorId]) case final failure?) {
      return failure;
    }
    final text = patch.text;
    final title = patch.title;
    final images = patch.images;
    if (patch.isEmpty ||
        (text != null && FieldValidators.postText(text) != null) ||
        (title != null &&
            FieldValidators.postTitle(title, type: PostType.announcement) !=
                null) ||
        (images != null && !_imagesOk(images, postId))) {
      return _invalid();
    }
    final post = posts[postId];
    // Kurallar: yalnızca yazarı, silinmemiş gönderi; başlık yalnızca duyuruda;
    // anket sorusu (ankette `text`) yayından sonra değişmez (CD-141 madde 11).
    if (post == null ||
        post.isDeleted ||
        post.authorId != authorId ||
        (title != null && !post.isAnnouncement) ||
        (post.isPoll && text != null && text != post.text)) {
      return _denied();
    }
    final now = _clock.nowUtc();
    _write(
      post.copyWith(
        text: text,
        title: title,
        images: images,
        editedAt: now,
        updatedAt: now,
      ),
    );
    return const FirebaseSuccess(null);
  }

  @override
  Future<FirestoreResult<void>> softDeletePost(
    String postId, {
    required String actorId,
    required String clubId,
  }) async {
    record('softDeletePost', [postId, actorId, clubId]);
    if (_rejected<void>([postId, actorId, clubId]) case final failure?) {
      return failure;
    }
    final post = posts[postId];
    if (_unreadable<void>(post, clubId) case final failure?) return failure;
    final now = _clock.nowUtc();
    // Sabit gönderi aynı yazımda sabitlikten çıkar; yorumlar, oylar, sayaçlar
    // ve duyuru hakkı değişmez.
    if (pinnedByClub[clubId] == postId) pinnedByClub.remove(clubId);
    _write(
      post!.copyWith(
        isDeleted: true,
        deletedAt: now,
        deletedBy: actorId,
        pinned: false,
        updatedAt: now,
      ),
    );
    return const FirebaseSuccess(null);
  }

  @override
  Future<FirestoreResult<void>> restorePost(String postId) async {
    record('restorePost', [postId]);
    if (_rejected<void>([postId]) case final failure?) return failure;
    final post = posts[postId];
    if (post == null || !post.isDeleted) return _denied();
    // Yalnızca silme alanları geri alınır: gönderi yeniden sabitlenmez.
    _write(
      post.copyWith(
        isDeleted: false,
        clearDeletedAt: true,
        clearDeletedBy: true,
        updatedAt: _clock.nowUtc(),
      ),
    );
    return const FirebaseSuccess(null);
  }

  @override
  Future<FirestoreResult<void>> pin(
    String postId, {
    required String clubId,
  }) async {
    record('pin', [postId, clubId]);
    if (_rejected<void>([postId, clubId]) case final failure?) return failure;
    final post = posts[postId];
    if (_unreadable<void>(post, clubId) case final failure?) return failure;
    if (post!.isHidden) return const FirebaseFailure(FirestoreError.notFound);
    final previousId = pinnedByClub[clubId];
    if (previousId == postId && post.pinned) return const FirebaseSuccess(null);
    final now = _clock.nowUtc();
    final previous = previousId == null ? null : posts[previousId];
    // Kulüpte en çok bir sabit gönderi: önceki sabit kalkar.
    if (previous != null && previous.id != postId && previous.pinned) {
      _write(previous.copyWith(pinned: false, updatedAt: now));
    }
    pinnedByClub[clubId] = postId;
    _write(post.copyWith(pinned: true, updatedAt: now));
    return const FirebaseSuccess(null);
  }

  @override
  Future<FirestoreResult<void>> unpin(
    String postId, {
    required String clubId,
  }) async {
    record('unpin', [postId, clubId]);
    if (_rejected<void>([postId, clubId]) case final failure?) return failure;
    final post = posts[postId];
    if (_unreadable<void>(post, clubId) case final failure?) return failure;
    // Sabit değilse hiçbir şey yazılmaz.
    if (pinnedByClub[clubId] == postId) pinnedByClub.remove(clubId);
    if (post!.pinned) {
      _write(post.copyWith(pinned: false, updatedAt: _clock.nowUtc()));
    }
    return const FirebaseSuccess(null);
  }

  @override
  Future<FirestoreResult<void>> like(String postId, {required String uid}) =>
      _toggleLike('like', postId, uid, liked: true);

  @override
  Future<FirestoreResult<void>> unlike(String postId, {required String uid}) =>
      _toggleLike('unlike', postId, uid, liked: false);

  @override
  Future<FirestoreResult<void>> vote(
    String postId, {
    required String uid,
    required String optionId,
  }) async {
    record('vote', [postId, uid, optionId]);
    if (_rejected<void>([postId, uid]) case final failure?) return failure;
    final post = posts[postId];
    if (post == null) return _denied();
    // Oy değiştirilemez: belge varsa (aynı ya da başka seçenek) yazım yok.
    if (votes[postId]?.containsKey(uid) ?? false) {
      return const FirebaseFailure(FirestoreError.alreadyExists);
    }
    final poll = post.poll;
    if (poll == null ||
        !_visible(post) ||
        post.pollEnded(_clock) ||
        !poll.options.any((option) => option.id == optionId)) {
      return _denied();
    }
    votes.putIfAbsent(postId, () => <String, String>{})[uid] = optionId;
    return const FirebaseSuccess(null);
  }

  @override
  Future<FirestoreResult<String?>> myVote(
    String postId, {
    required String uid,
  }) async {
    record('myVote', [postId, uid]);
    if (_rejected<String?>([postId, uid]) case final failure?) return failure;
    if (!posts.containsKey(postId)) return _denied();
    return FirebaseSuccess(votes[postId]?[uid]);
  }

  @override
  Future<FirestoreResult<Map<String, int>>> countVotes(
    String postId,
    List<String> optionIds,
  ) async {
    record('countVotes', [postId, optionIds]);
    if (_rejected<Map<String, int>>([postId]) case final failure?) {
      return failure;
    }
    final distinct = optionIds.toSet();
    if (distinct.length > Limits.pollOptionsMax) return _invalid();
    if (!posts.containsKey(postId)) return _denied();
    final cast = votes[postId]?.values ?? const <String>[];
    return FirebaseSuccess({
      for (final optionId in distinct)
        optionId: cast.where((voted) => voted == optionId).length,
    });
  }

  @override
  Future<FirestoreResult<PageResult<PostModel>>> listFeed(
    String clubId,
    PageRequest page, {
    PostType? type,
  }) async {
    record('listFeed', [clubId, page, type]);
    if (_rejected<PageResult<PostModel>>([clubId]) case final failure?) {
      return failure;
    }
    final feed = _pager.slice(_inClub(clubId, includeHidden: false), page);
    if (type == null) return FirebaseSuccess(feed);
    // Tür süzgeci sayfa alındıktan sonra uygulanır (gerçek repository gibi):
    // imleç süzülmemiş sayfanın sonunu gösterir.
    return FirebaseSuccess(
      PageResult(
        items: [
          for (final post in feed.items)
            if (post.type == type) post,
        ],
        next: feed.next,
      ),
    );
  }

  @override
  Future<FirestoreResult<PageResult<PostModel>>> listForManagement(
    String clubId,
    PageRequest page,
  ) async {
    record('listForManagement', [clubId, page]);
    if (_rejected<PageResult<PostModel>>([clubId]) case final failure?) {
      return failure;
    }
    // Gizlenmişler dahil (MGT-08).
    return FirebaseSuccess(
      _pager.slice(_inClub(clubId, includeHidden: true), page),
    );
  }

  @override
  Future<FirestoreResult<PostModel>> getPost(String postId) async {
    record('getPost', [postId]);
    if (_rejected<PostModel>([postId]) case final failure?) return failure;
    final post = posts[postId];
    if (post == null) return _denied();
    if (post.isDeleted) return const FirebaseFailure(FirestoreError.notFound);
    return FirebaseSuccess(post);
  }

  @override
  Stream<FirestoreResult<PostModel?>> watchPost(String postId) {
    record('watchPost', [postId]);
    if (!RepositoryHelpers.isValidId(postId)) {
      return Stream.value(
        const FirebaseFailure(FirestoreError.invalidArgument),
      );
    }
    final source = watchPostController(postId);
    late final StreamController<FakePostEvent> output;
    StreamSubscription<FakePostEvent>? subscription;
    output = StreamController<FakePostEvent>(
      onListen: () {
        activeListeners++;
        // İlk anlık görüntü (Firestore dinleyicisi gibi), sonra değişiklikler.
        output.add(_snapshot(postId));
        subscription = source.stream.listen(output.add);
      },
      onCancel: () {
        activeListeners--;
        return subscription?.cancel();
      },
    );
    return output.stream;
  }

  @override
  Future<FirestoreResult<void>> hide(
    String postId, {
    required String actorId,
  }) async {
    record('hide', [postId, actorId]);
    if (_rejected<void>([postId, actorId]) case final failure?) return failure;
    final post = posts[postId];
    if (post == null || post.isHidden) return _denied();
    final now = _clock.nowUtc();
    _write(
      post.copyWith(
        isHidden: true,
        hiddenBy: actorId,
        hiddenAt: now,
        updatedAt: now,
      ),
    );
    return const FirebaseSuccess(null);
  }

  @override
  Future<FirestoreResult<void>> unhide(String postId) async {
    record('unhide', [postId]);
    if (_rejected<void>([postId]) case final failure?) return failure;
    final post = posts[postId];
    if (post == null || !post.isHidden) return _denied();
    _write(
      post.copyWith(
        isHidden: false,
        clearHiddenBy: true,
        clearHiddenAt: true,
        updatedAt: _clock.nowUtc(),
      ),
    );
    return const FirebaseSuccess(null);
  }

  /// Beğeni ekleme / geri almanın ortak **kör** yazımı: durum gerçekten
  /// değişmiyorsa (çift beğeni, beğenmeden geri alma) kural reddeder;
  /// `updatedAt` değişmez.
  Future<FirestoreResult<void>> _toggleLike(
    String method,
    String postId,
    String uid, {
    required bool liked,
  }) async {
    record(method, [postId, uid]);
    if (_rejected<void>([postId, uid]) case final failure?) return failure;
    final post = posts[postId];
    if (post == null || !_visible(post) || post.likedBy(uid) == liked) {
      return _denied();
    }
    _write(post.withLike(uid, liked: liked));
    return const FirebaseSuccess(null);
  }

  /// Gönderiyi okuyan işlemlerin (`pin`, `unpin`, `softDeletePost`) ortak
  /// ön koşulu: olmayan gönderi okunamaz (`permissionDenied`), silinmiş
  /// gönderi `notFound`, başka kulübün gönderisi `invalidArgument`.
  FirestoreResult<T>? _unreadable<T>(PostModel? post, String clubId) {
    if (post == null) return _denied();
    if (post.isDeleted) return const FirebaseFailure(FirestoreError.notFound);
    return post.clubId == clubId ? null : _invalid();
  }

  /// Akışın güncel olayı: olmayan gönderi okunamaz; silinmiş gönderi "yok".
  FakePostEvent _snapshot(String postId) {
    final post = posts[postId];
    if (post == null) return _denied();
    return FirebaseSuccess(post.isDeleted ? null : post);
  }

  void _write(PostModel post) {
    posts[post.id] = post;
    _emit(post.id);
  }

  void _emit(String postId) {
    final controller = _controllers[postId];
    if (controller != null && controller.hasListener) {
      controller.add(_snapshot(postId));
    }
  }

  /// [clubId] kulübünün silinmemiş gönderileri, en yeni üstte.
  List<PostModel> _inClub(String clubId, {required bool includeHidden}) => [
    for (final post in posts.values)
      if (post.clubId == clubId &&
          !post.isDeleted &&
          (includeHidden || !post.isHidden))
        post,
  ]..sort(_newestFirst);

  /// Taslağın tür kuralları (gerçek repository ile aynı doğrulayıcılar).
  static bool _draftOk(PostDraft draft, String postId) {
    final poll = draft.poll;
    return FieldValidators.postText(draft.text) == null &&
        FieldValidators.postTitle(draft.title, type: draft.type) == null &&
        FieldValidators.postPoll(type: draft.type, hasPoll: poll != null) ==
            null &&
        (poll == null ||
            (FieldValidators.pollOptions(poll.options) == null &&
                FieldValidators.pollDurationDays(poll.durationDays) == null)) &&
        _imagesOk(draft.images, postId);
  }

  /// En çok `Limits.postImagesMax` görsel; her yol gönderinin kendi
  /// klasöründe (CD-39).
  static bool _imagesOk(List<PostImageModel> images, String postId) =>
      FieldValidators.postImageCount(images.length) == null &&
      images.every((image) => StoragePaths.isPostImage(image.path, postId));

  /// Üyenin etkileşebildiği gönderi: silinmemiş ve gizli değil.
  static bool _visible(PostModel post) => !post.isDeleted && !post.isHidden;

  /// `createdAt` azalan; zamanı olmayan gönderi sonda.
  static int _newestFirst(PostModel a, PostModel b) {
    final left = a.createdAt;
    final right = b.createdAt;
    if (left == null || right == null) {
      return left == right ? 0 : (left == null ? 1 : -1);
    }
    return right.compareTo(left);
  }

  static FirestoreResult<T> _denied<T>() =>
      const FirebaseFailure(FirestoreError.permissionDenied);

  static FirestoreResult<T> _invalid<T>() =>
      const FirebaseFailure(FirestoreError.invalidArgument);

  /// Bekleyen hata ya da geçersiz kimlik varsa başarısızlık; yoksa `null`.
  FirestoreResult<T>? _rejected<T>(List<String> ids) {
    final failure = switch (takeFailure()) {
      null => null,
      final FirestoreError error => error,
      _ => FirestoreError.unknown,
    };
    if (failure != null) return FirebaseFailure(failure);
    if (!ids.every(RepositoryHelpers.isValidId)) return _invalid();
    return null;
  }
}
