import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gu_data/src/constants/firestore_collections.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/constants/firestore_ids.dart';
import 'package:gu_data/src/constants/limits.dart';
import 'package:gu_data/src/constants/storage_paths.dart';
import 'package:gu_data/src/core/app_clock.dart';
import 'package:gu_data/src/core/base_fields.dart';
import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/core/media_update_error.dart';
import 'package:gu_data/src/core/page_request.dart';
import 'package:gu_data/src/core/page_result.dart';
import 'package:gu_data/src/core/soft_delete.dart';
import 'package:gu_data/src/core/storage_error.dart';
import 'package:gu_data/src/models/activity_draft.dart';
import 'package:gu_data/src/models/activity_refs_model.dart';
import 'package:gu_data/src/models/club_model.dart';
import 'package:gu_data/src/models/counter_model.dart';
import 'package:gu_data/src/models/enums/activity_kind.dart';
import 'package:gu_data/src/models/enums/post_type.dart';
import 'package:gu_data/src/models/poll_model.dart';
import 'package:gu_data/src/models/poll_option_model.dart';
import 'package:gu_data/src/models/post_draft.dart';
import 'package:gu_data/src/models/post_image_model.dart';
import 'package:gu_data/src/models/post_model.dart';
import 'package:gu_data/src/models/vote_model.dart';
import 'package:gu_data/src/repositories/announcement_counter_repository.dart';
import 'package:gu_data/src/repositories/firebase_activity_repository.dart';
import 'package:gu_data/src/repositories/firebase_announcement_counter_repository.dart';
import 'package:gu_data/src/repositories/firebase_club_repository.dart';
import 'package:gu_data/src/repositories/post_repository.dart';
import 'package:gu_data/src/repositories/query_x.dart';
import 'package:gu_data/src/repositories/repository_helpers.dart';
import 'package:gu_data/src/services/firestore_service.dart';
import 'package:gu_data/src/services/firestore_types.dart';
import 'package:gu_data/src/services/storage_service.dart';
import 'package:gu_data/src/utils/field_validators.dart';

/// [PostRepository] uygulaması: `posts/{postId}`, `posts/{postId}/votes/{uid}`,
/// `clubs.pinnedPostId`, günlük kaydı ve duyuru sayacı (PLAN §10.4;
/// rules-spec §3.5, §3.16).
///
/// Birden çok belgeye dokunan her yol tek işlemdir (ya hepsi ya hiçbiri):
/// - **yayın** — gönderi + günlük tek batch; bildirimli duyuruda günün sayacı
///   da aynı işlemde okunup artırıldığı için transaction;
/// - **sabitleme / kaldırma / silme** — gönderi(ler) ile `clubs.pinnedPostId`
///   aynı transaction'da;
/// - **oy** — oy belgesi okunur, yoksa yazılır (transaction).
///
/// Beğeni tek ve **kör** yazımdır (önce okuma yok): çift beğeniyi ve
/// yetkiyi Security Rules denetler, repository aktöre göre dallanmaz.
/// Bildirim dağıtımı burada yapılmaz (PLAN §10.5: çağıran yapar).
final class FirebasePostRepository implements PostRepository {
  /// [_firestore] üzerinden okur ve yazar; gönderi görsellerini [_storage]
  /// ile yükler; günlük kaydını [_activity] ile, duyuru sayacını [_counters]
  /// ile yayın işlemine ekler. Anket bitişi, sayaç günü ve görsel dosya adı
  /// damgası [_clock] saatinden; dosya adının rastgele kısmı [_random]
  /// kaynağından gelir (kompozisyon kökü `Random.secure()` verir; `gu_data`
  /// rastgele kaynağı kendisi kurmaz).
  FirebasePostRepository(
    this._firestore,
    this._storage,
    this._activity,
    this._counters,
    this._clock,
    this._random,
  );

  final FirestoreService _firestore;
  final StorageService _storage;
  final FirebaseActivityRepository _activity;
  final FirebaseAnnouncementCounterRepository _counters;
  final AppClock _clock;
  final Random _random;

  /// Gönderi görselinin özel üst veri anahtarı: Storage Rules yükleyenin
  /// yöneticiliğini `request.resource.metadata.clubId` kulübünde doğrular
  /// (CD-39). [_uploaderIdMetadata] dışında özel üst veri gönderilmez (Rules
  /// reddeder).
  static const String _clubIdMetadata = 'clubId';

  /// Yükleyenin kimliği: Storage Rules değerin oturumdaki uid olmasını ister.
  /// Storage nesnesi yükleyeni kendiliğinden kaydetmez; dosyayı kimin
  /// yüklediği (moderasyon, hesap askısı) yalnızca bu alandan izlenir.
  static const String _uploaderIdMetadata = 'uploaderId';

  /// `likeCount` deltası: beğeni eklendi.
  static const int _liked = 1;

  /// `likeCount` deltası: beğeni geri alındı.
  static const int _unliked = -1;

  /// [doc] belgesinden gönderi modeli.
  static PostModel postOf(FirestoreDoc doc) =>
      PostModel.fromJson(doc.data, id: doc.id);

  @override
  String newPostId() => _firestore.newId(FirestoreCollections.posts);

  @override
  Future<MediaUpdateResult<List<PostImageModel>>> uploadImages(
    String postId,
    List<PostImageUpload> images, {
    required String clubId,
    required String uploaderId,
    void Function(int index, PostImageModel image)? onUploaded,
  }) async {
    // Ön denetim tüm liste içindir: tek görsel bile geçersizse hiçbir dosya
    // gönderilmez (yüklenen dosya silinemez — D-10).
    if (_rejectUploads(postId, clubId, uploaderId, images)
        case final rejected?) {
      return rejected;
    }
    final uploaded = <PostImageModel>[];
    for (final (index, upload) in images.indexed) {
      // Her görsel yeni adla yüklenir (üzerine yazma yok); uzantı içerik
      // türünden gelir — ön denetim türü doğruladı.
      final extension =
          StoragePaths.extensionByContentType[upload.contentType]!;
      final result = await _storage.upload(
        path: StoragePaths.postImage(
          postId,
          StoragePaths.newFileName(_clock, _random, extension),
        ),
        bytes: upload.bytes,
        contentType: upload.contentType,
        customMetadata: {
          _clubIdMetadata: clubId,
          _uploaderIdMetadata: uploaderId,
        },
      );
      switch (result) {
        case FirebaseFailure(:final error, :final message):
          // Kalanlar gönderilmez; o ana kadar yüklenenler yerinde kalır ve
          // çağıran onları `onUploaded` ile zaten öğrenmiştir.
          return FirebaseFailure(MediaUploadError(error), message: message);
        case FirebaseSuccess(data: final path):
          final image = PostImageModel(
            path: path,
            w: upload.width,
            h: upload.height,
          );
          uploaded.add(image);
          onUploaded?.call(index, image);
      }
    }
    return FirebaseSuccess(uploaded);
  }

  /// [uploadImages] ön denetimi; sorun yoksa `null`. Önce çağrının kendisi
  /// (kimlikler, adet, boyut bilgisi — belge hatası), sonra her görselin
  /// baytları (tür → boş → boyut sınırı — yükleme hatası) denetlenir;
  /// `StorageService.upload` ile aynı koşullar, ağ çağrısından önce.
  static MediaUpdateResult<List<PostImageModel>>? _rejectUploads(
    String postId,
    String clubId,
    String uploaderId,
    List<PostImageUpload> images,
  ) {
    final invalid =
        RepositoryHelpers.rejectInvalidIds<void>({
          'postId': postId,
          'clubId': clubId,
          'uploaderId': uploaderId,
        }) ??
        RepositoryHelpers.rejectInvalidFields<void>({
          FirestoreFields.images: FieldValidators.postImageCount(
            images.length,
          ),
        }) ??
        (images.any((image) => image.width < 1 || image.height < 1)
            ? RepositoryHelpers.invalidArgument<void>(
                'uploadImages: görsel boyutu (width / height) 1 pikselden küçük',
              )
            : null);
    if (invalid case FirebaseFailure(:final error, :final message)) {
      return FirebaseFailure(MediaDocumentError(error), message: message);
    }
    for (final image in images) {
      final StorageError? error;
      if (!StoragePaths.extensionByContentType.containsKey(
        image.contentType,
      )) {
        error = StorageError.invalidType;
      } else if (image.bytes.isEmpty) {
        error = StorageError.noFile;
      } else if (image.bytes.length >= Limits.imageMaxBytes) {
        // Storage Rules `size < imageMaxBytes` ister: sınırın kendisi de ret.
        error = StorageError.sizeLimit;
      } else {
        error = null;
      }
      if (error != null) return FirebaseFailure(MediaUploadError(error));
    }
    return null;
  }

  @override
  Future<FirestoreResult<PostModel>> create(
    PostDraft draft, {
    required String authorId,
    required String clubId,
    required String postId,
  }) async {
    final rejected =
        RepositoryHelpers.rejectInvalidIds<PostModel>({
          'authorId': authorId,
          'clubId': clubId,
          'postId': postId,
        }) ??
        _rejectDraft(draft, postId);
    if (rejected != null) return rejected;

    final now = _clock.nowUtc();
    final poll = draft.poll;
    // Model varsayılanları: sayaçlar sıfır, `likes` boş, `pinned` ve
    // `isHidden` `false`. `null` alanların (`title`, `poll`, `lastCommentRef`,
    // gizleme ve düzenleme alanları) anahtarı yazılmaz (W-51).
    final post = PostModel(
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
      // Bildirim bayrağı yalnızca duyuruda anlam taşır.
      pushSent: draft.pushSent && draft.type == PostType.announcement,
    );
    // Sunucu zamanı yazım anında okunamaz: zaman alanları yaklaşık değerdir.
    final published = post.copyWith(id: postId, createdAt: now, updatedAt: now);

    if (!post.pushSent) {
      final written = await _firestore.commitBatch((batch) {
        batch.set(_postRef(postId), _createPayload(post));
        _activity.addToBatch(batch, _activityOf(post, postId));
      });
      return written.map((_) => published);
    }

    final first = await _publishCounted(post, published, dayInstant: now);
    // Gün sınırı (CD-129): Rules günü sunucu saatinden hesaplar; cihaz saati
    // sınıra tolerans içindeyse ret yanlış gün anahtarından olabilir. İşlem
    // komşu günün sayacıyla bir kez baştan koşulur; o sonuç nihaidir.
    final adjacent = AnnouncementCounterRepository.adjacentDayInstant(
      _clock,
      now,
    );
    if (first.errorOrNull != FirestoreError.permissionDenied ||
        adjacent == null) {
      return first;
    }
    return _publishCounted(post, published, dayInstant: adjacent);
  }

  @override
  Future<FirestoreResult<void>> update(
    String postId,
    PostEditPatch patch, {
    required String authorId,
  }) async {
    final text = patch.text;
    final title = patch.title;
    final images = patch.images;
    final rejected =
        RepositoryHelpers.rejectInvalidIds<void>({
          'postId': postId,
          'authorId': authorId,
        }) ??
        (patch.isEmpty
            ? RepositoryHelpers.invalidArgument<void>('update: boş yama')
            : null) ??
        RepositoryHelpers.rejectInvalidFields<void>({
          if (text != null)
            FirestoreFields.text: FieldValidators.postText(text),
          // Başlık yalnızca duyuruda bulunur; türü Security Rules denetler.
          if (title != null)
            FirestoreFields.title: FieldValidators.postTitle(
              title,
              type: PostType.announcement,
            ),
        }) ??
        (images == null ? null : _rejectImages<void>(images, postId));
    if (rejected != null) return rejected;
    // Yalnızca verilen alanlar yazılır; `updatedAt` servis tarafından eklenir.
    return _firestore.update(_postRef(postId), {
      FirestoreFields.text: ?text,
      FirestoreFields.title: ?title,
      if (images != null)
        FirestoreFields.images: [for (final image in images) image.toJson()],
      FirestoreFields.editedAt: _firestore.serverTimestamp(),
    });
  }

  @override
  Future<FirestoreResult<void>> softDeletePost(
    String postId, {
    required String actorId,
    required String clubId,
  }) async {
    if (RepositoryHelpers.rejectInvalidIds<void>({
          'postId': postId,
          'actorId': actorId,
          'clubId': clubId,
        })
        case final rejected?) {
      return rejected;
    }
    final postRef = _postRef(postId);
    final clubRef = _clubRef(clubId);
    return _transact((tx) async {
      final post = _livePost(await tx.get(postRef), clubId);
      // Sabit gönderi silinirken sabitleme aynı işlemde kalkar; yorumlar,
      // oylar, sayaçlar ve duyuru hakkı değişmez.
      tx.update(postRef, {
        ...SoftDelete.payload(actorId: actorId),
        if (post.pinned) FirestoreFields.pinned: false,
      });
      if (post.pinned) tx.update(clubRef, _pointerPayload(null));
    });
  }

  @override
  Future<FirestoreResult<void>> restorePost(String postId) async {
    if (RepositoryHelpers.rejectInvalidIds<void>({'postId': postId})
        case final rejected?) {
      return rejected;
    }
    // Yalnızca silme alanları geri alınır: gönderi yeniden sabitlenmez.
    return _firestore.restore(_postRef(postId));
  }

  @override
  Future<FirestoreResult<void>> pin(
    String postId, {
    required String clubId,
  }) async {
    if (_rejectPair<void>(postId, clubId) case final rejected?) {
      return rejected;
    }
    final postRef = _postRef(postId);
    final clubRef = _clubRef(clubId);
    return _transact((tx) async {
      // Transaction kuralı: tüm okumalar yazımlardan önce.
      final club = _liveClub(await tx.get(clubRef));
      final post = _livePost(await tx.get(postRef), clubId);
      if (post.isHidden) {
        throw _Halt(FirestoreError.notFound, '${postRef.path}: gizli');
      }
      final previousId = club.pinnedPostId;
      if (previousId == postId && post.pinned) return;
      final previousRef =
          previousId == null ||
              previousId == postId ||
              !RepositoryHelpers.isValidId(previousId)
          ? null
          : _postRef(previousId);
      final previous = previousRef == null
          ? null
          : _postOrNull(await tx.get(previousRef));

      // Kulüpte en çok bir sabit gönderi: önceki sabit (silinmemişse) kalkar.
      if (previousRef != null &&
          previous != null &&
          previous.pinned &&
          !previous.isDeleted) {
        tx.update(previousRef, _pinPayload(pinned: false));
      }
      tx
        ..update(postRef, _pinPayload(pinned: true))
        ..update(clubRef, _pointerPayload(postId));
    });
  }

  @override
  Future<FirestoreResult<void>> unpin(
    String postId, {
    required String clubId,
  }) async {
    if (_rejectPair<void>(postId, clubId) case final rejected?) {
      return rejected;
    }
    final postRef = _postRef(postId);
    final clubRef = _clubRef(clubId);
    return _transact((tx) async {
      // Transaction kuralı: tüm okumalar yazımlardan önce.
      final club = _liveClub(await tx.get(clubRef));
      final post = _livePost(await tx.get(postRef), clubId);
      // Sabit değilse hiçbir şey yazılmaz. İki alan ayrı ayrı denetlenir:
      // yalnızca gerçekten değişen belge yazılır.
      if (post.pinned) tx.update(postRef, _pinPayload(pinned: false));
      if (club.pinnedPostId == postId) {
        tx.update(clubRef, _pointerPayload(null));
      }
    });
  }

  @override
  Future<FirestoreResult<void>> like(String postId, {required String uid}) =>
      _toggleLike(postId, uid, FieldValue.arrayUnion([uid]), _liked);

  @override
  Future<FirestoreResult<void>> unlike(String postId, {required String uid}) =>
      _toggleLike(postId, uid, FieldValue.arrayRemove([uid]), _unliked);

  @override
  Future<FirestoreResult<void>> vote(
    String postId, {
    required String uid,
    required String optionId,
  }) async {
    if (_rejectVoter<void>(postId, uid) case final rejected?) return rejected;
    final voteRef = _voteRef(postId, uid);
    return _transact((tx) async {
      // Oy değiştirilemez: belge varsa (aynı ya da başka seçenek) yazım yok.
      if ((await tx.get(voteRef)).exists) {
        throw _Halt(
          FirestoreError.alreadyExists,
          '${voteRef.path}: oy verilmiş',
        );
      }
      tx.set(voteRef, {
        ...VoteModel(optionId: optionId).toJson(),
        FirestoreFields.createdAt: _firestore.serverTimestamp(),
      });
    });
  }

  @override
  Future<FirestoreResult<String?>> myVote(
    String postId, {
    required String uid,
  }) async {
    if (_rejectVoter<String?>(postId, uid) case final rejected?) {
      return rejected;
    }
    final vote = RepositoryHelpers.parseOrNull(
      await _firestore.getDoc(_voteRef(postId, uid)),
      (doc) => VoteModel.fromJson(doc.data, id: doc.id),
    );
    return vote.map((vote) => vote?.optionId);
  }

  @override
  Future<FirestoreResult<Map<String, int>>> countVotes(
    String postId,
    List<String> optionIds,
  ) async {
    if (RepositoryHelpers.rejectInvalidIds<Map<String, int>>({'postId': postId})
        case final rejected?) {
      return rejected;
    }
    final distinct = optionIds.toSet();
    if (distinct.length > Limits.pollOptionsMax) {
      return RepositoryHelpers.invalidArgument(
        'countVotes: ${distinct.length} seçenek, sınır '
        '${Limits.pollOptionsMax}',
      );
    }
    final votes = _firestore.collection(_votesPath(postId));
    final counts = await Future.wait([
      for (final optionId in distinct)
        _firestore.count(
          votes.where(FirestoreFields.optionId, isEqualTo: optionId),
        ),
    ]);
    final result = <String, int>{};
    for (final (index, optionId) in distinct.indexed) {
      switch (counts[index]) {
        case FirebaseSuccess(:final data):
          result[optionId] = data;
        case FirebaseFailure(:final error, :final message, :final detail):
          return FirebaseFailure(error, message: message, detail: detail);
      }
    }
    return FirebaseSuccess(result);
  }

  @override
  Future<FirestoreResult<PageResult<PostModel>>> listFeed(
    String clubId,
    PageRequest page, {
    PostType? type,
  }) async {
    if (RepositoryHelpers.rejectInvalidIds<PageResult<PostModel>>({
          'clubId': clubId,
        })
        case final rejected?) {
      return rejected;
    }
    final feed = RepositoryHelpers.parsePage(
      await _firestore.getPage(
        _inClub(clubId)
            .where(FirestoreFields.isHidden, isEqualTo: false)
            .orderBy(FirestoreFields.createdAt, descending: true),
        page,
      ),
      postOf,
    );
    if (type == null) return feed;
    // Tür süzgeci istemcidedir (ek indeks açılmaz — rules-spec §8); imleç
    // süzülmemiş sayfanın son belgesini gösterir.
    return feed.map(
      (unfiltered) => PageResult(
        items: [
          for (final post in unfiltered.items)
            if (post.type == type) post,
        ],
        next: unfiltered.next,
      ),
    );
  }

  @override
  Stream<FirestoreResult<List<PostModel>>> watchFeedHead(
    String clubId, {
    int limit = Limits.pageSize,
  }) {
    if (RepositoryHelpers.rejectInvalidIds<List<PostModel>>({
          'clubId': clubId,
        })
        case final rejected?) {
      return Stream.value(rejected);
    }
    return _firestore
        .watchList(
          _inClub(clubId)
              .where(FirestoreFields.isHidden, isEqualTo: false)
              .orderBy(FirestoreFields.createdAt, descending: true)
              .limit(limit),
        )
        .map((event) => RepositoryHelpers.parseAll(event, postOf));
  }

  @override
  Future<FirestoreResult<PageResult<PostModel>>> listForManagement(
    String clubId,
    PageRequest page,
  ) async {
    if (RepositoryHelpers.rejectInvalidIds<PageResult<PostModel>>({
          'clubId': clubId,
        })
        case final rejected?) {
      return rejected;
    }
    // Gizlenmişler dahil: `isHidden` süzgeci yoktur (MGT-08).
    return RepositoryHelpers.parsePage(
      await _firestore.getPage(
        _inClub(clubId).orderBy(FirestoreFields.createdAt, descending: true),
        page,
      ),
      postOf,
    );
  }

  @override
  Future<FirestoreResult<PostModel>> getPost(String postId) async {
    if (RepositoryHelpers.rejectInvalidIds<PostModel>({'postId': postId})
        case final rejected?) {
      return rejected;
    }
    final ref = _postRef(postId);
    // Silinmiş belge `parseOrNull` içinde "bulunamadı" olur; gizlenmiş gönderi
    // (Rules okumaya izin verdiyse) döner.
    return switch (RepositoryHelpers.parseOrNull(
      await _firestore.getDoc(ref),
      postOf,
    )) {
      FirebaseSuccess(data: final post?) => FirebaseSuccess(post),
      FirebaseSuccess() => FirebaseFailure(
        FirestoreError.notFound,
        message: '${ref.path}: yok',
      ),
      FirebaseFailure(:final error, :final message, :final detail) =>
        FirebaseFailure(error, message: message, detail: detail),
    };
  }

  @override
  Stream<FirestoreResult<PostModel?>> watchPost(String postId) {
    if (RepositoryHelpers.rejectInvalidIds<PostModel?>({'postId': postId})
        case final rejected?) {
      return Stream.value(rejected);
    }
    return _firestore
        .watchDoc(_postRef(postId))
        .map(
          (event) => switch (event) {
            FirebaseSuccess(data: final doc?)
                when !RepositoryHelpers.isSoftDeleted(doc) =>
              RepositoryHelpers.parse<PostModel?>(doc, postOf),
            // Belge yoksa ya da açık ekranda kaldırıldıysa olay "yok" olur
            // (hata değil); hata olayı olduğu gibi iletilir.
            _ => event.map((_) => null),
          },
        );
  }

  @override
  Future<FirestoreResult<void>> hide(
    String postId, {
    required String actorId,
  }) async {
    if (RepositoryHelpers.rejectInvalidIds<void>({
          'postId': postId,
          'actorId': actorId,
        })
        case final rejected?) {
      return rejected;
    }
    return _firestore.update(_postRef(postId), _hidePayload(actorId));
  }

  /// [hide]'ın batch karşılığı (T-37, şikayet çözümü "kaldırıldı" —
  /// `AdminRepository.resolveReports`): [postId] gönderisinin gizleme
  /// yazımını (`isHidden: true`, `hiddenBy: actorId`, `hiddenAt` +
  /// `updatedAt` sunucu zamanı) [batch]'e **eşzamanlı** ekler; commit ve ağ
  /// çağrısı yoktur. Arayüzde değildir (SDK tipi `WriteBatch` arayüze
  /// sızmaz); yalnızca `gu_data` içindeki çözüm sınıfı çağırır.
  ///
  /// Kimlikleri çağıran önceden doğrular (`RepositoryHelpers.isValidId`);
  /// geçersiz [postId] `ArgumentError` fırlatır ve `commitBatch` batch'i
  /// düşürür. Sayaçlar ve sabitleme değişmez; Rules (`isHideToggle`) gönderi
  /// zaten gizliyse yazımı reddeder — çağıran önce okur.
  void addHideToBatch(
    WriteBatch batch,
    String postId, {
    required String actorId,
  }) => batch.update(_postRef(postId), {
    ..._hidePayload(actorId),
    ...BaseFieldsPayload.update(),
  });

  /// Gizleme yazımının alanları ([hide] ve [addHideToBatch] ortak yükü).
  Json _hidePayload(String actorId) => {
    FirestoreFields.isHidden: true,
    FirestoreFields.hiddenBy: actorId,
    FirestoreFields.hiddenAt: _firestore.serverTimestamp(),
  };

  @override
  Future<FirestoreResult<void>> unhide(String postId) async {
    if (RepositoryHelpers.rejectInvalidIds<void>({'postId': postId})
        case final rejected?) {
      return rejected;
    }
    // Gizleme izleri kaldırılmaz, açıkça `null` yazılır (Rules bunu bekler).
    return _firestore.update(_postRef(postId), {
      FirestoreFields.isHidden: false,
      FirestoreFields.hiddenBy: null,
      FirestoreFields.hiddenAt: null,
    });
  }

  /// Bildirimli duyuruyu [dayInstant] anının Istanbul gününe ait sayaçla tek
  /// transaction'da yayınlar: sayaç okunur, hak varsa sayaç artışı + gönderi
  /// + günlük birlikte yazılır.
  ///
  /// Sayaç ilk yazımdır: günün hakkı dolmuşsa işlem, hiçbir yazım kuyruğa
  /// girmeden [FirestoreRuleCode.announcementLimit] ile durur (DLG-24).
  Future<FirestoreResult<PostModel>> _publishCounted(
    PostModel post,
    PostModel published, {
    required DateTime dayInstant,
  }) {
    final postId = published.id;
    final dayKey = _clock.istanbulDayKey(dayInstant);
    final counterRef = _counters.refOf(post.clubId, dayKey);
    return _transact((tx) async {
      final previous = _counterOrNull(await tx.get(counterRef))?.count ?? 0;
      _counters.addToTransaction(
        tx,
        clubId: post.clubId,
        dayKey: dayKey,
        day: _clock.istanbulDay(dayInstant),
        previousCount: previous,
        postId: postId,
      );
      tx.set(_postRef(postId), _createPayload(post));
      _activity.addToTransaction(tx, _activityOf(post, postId));
      return published;
    });
  }

  /// Beğeni ekleme / geri almanın ortak, **kör** yazımı: [likes] dizi işlemi
  /// ve `likeCount` [delta]'sı tek güncellemededir; `updatedAt` yazılmaz
  /// (Rules beyaz listesi yalnızca `likes` ve `likeCount` — rules-spec §3.5).
  Future<FirestoreResult<void>> _toggleLike(
    String postId,
    String uid,
    FieldValue likes,
    int delta,
  ) async {
    if (_rejectVoter<void>(postId, uid) case final rejected?) return rejected;
    return _firestore.update(_postRef(postId), {
      FirestoreFields.likes: likes,
      FirestoreFields.likeCount: FieldValue.increment(delta),
    }, touchUpdatedAt: false);
  }

  /// [body] gövdesini transaction içinde çalıştırır. Gövde, yazım kuyruğa
  /// girmeden **önce** reddedebilir: `ConflictException` (iş kuralı) ya da
  /// [_Halt] (bulunamadı, zaten var, ayrıştırılamadı, geçersiz girdi).
  Future<FirestoreResult<T>> _transact<T>(
    Future<T> Function(Transaction tx) body,
  ) async {
    final result = await _firestore.runTransaction<FirestoreResult<T>>((
      tx,
    ) async {
      try {
        return FirebaseSuccess(await body(tx));
      } on _Halt catch (halt) {
        return FirebaseFailure(halt.error, message: halt.message);
      }
    });
    return switch (result) {
      FirebaseSuccess(:final data) => data,
      FirebaseFailure(:final error, :final message, :final detail) =>
        FirebaseFailure(error, message: message, detail: detail),
    };
  }

  /// [draft] taslağının tür kuralları (PLAN §9.6.6; rules-spec §3.5 C):
  /// metin, başlık (yalnızca duyuruda), görseller (sayı + CD-39 yolu) ve
  /// anket (yalnızca ankette; seçenekler ve süre).
  static FirestoreResult<PostModel>? _rejectDraft(
    PostDraft draft,
    String postId,
  ) {
    final poll = draft.poll;
    return RepositoryHelpers.rejectInvalidFields<PostModel>({
          FirestoreFields.text: FieldValidators.postText(draft.text),
          FirestoreFields.title: FieldValidators.postTitle(
            draft.title,
            type: draft.type,
          ),
          FirestoreFields.poll: FieldValidators.postPoll(
            type: draft.type,
            hasPoll: poll != null,
          ),
          if (poll != null) ...{
            FirestoreFields.options: FieldValidators.pollOptions(poll.options),
            FirestoreFields.endsAt: FieldValidators.pollDurationDays(
              poll.durationDays,
            ),
          },
        }) ??
        _rejectImages<PostModel>(draft.images, postId);
  }

  /// [images] en çok `Limits.postImagesMax` görsel taşır ve her yol [postId]
  /// gönderisinin kendi klasöründedir (`posts/{postId}/{file}` — CD-39:
  /// başka gönderinin ya da başka kökün dosyası gönderiye iliştirilemez).
  static FirestoreResult<T>? _rejectImages<T>(
    List<PostImageModel> images,
    String postId,
  ) {
    if (RepositoryHelpers.rejectInvalidFields<T>({
          FirestoreFields.images: FieldValidators.postImageCount(images.length),
        })
        case final rejected?) {
      return rejected;
    }
    for (final image in images) {
      if (!StoragePaths.isPostImage(image.path, postId)) {
        return RepositoryHelpers.invalidArgument(
          'geçersiz alan: ${FirestoreFields.images} (yol gönderinin '
          'klasöründe değil)',
        );
      }
    }
    return null;
  }

  /// Yeni gönderinin Firestore yükü: model alanları + ortak alanlar.
  static Json _createPayload(PostModel post) => {
    ...post.toJson(),
    ...BaseFieldsPayload.create(),
  };

  /// Yayının günlük kaydı. Kimlik sabittir (`FirestoreIds.postActivity`):
  /// bir yayına tek kayıt (CD-137).
  static ActivityDraft _activityOf(PostModel post, String postId) {
    final kind = switch (post.type) {
      PostType.post => ActivityKind.postCreated,
      PostType.announcement => ActivityKind.announcement,
      PostType.poll => ActivityKind.poll,
    };
    return ActivityDraft(
      clubId: post.clubId,
      actorId: post.authorId,
      kind: kind,
      refs: ActivityRefsModel(postId: postId),
      id: FirestoreIds.postActivity(
        post.clubId,
        post.authorId,
        kind.json,
        postId,
      ),
    );
  }

  /// `posts.pinned` yükü.
  static Json _pinPayload({required bool pinned}) => {
    FirestoreFields.pinned: pinned,
    ...BaseFieldsPayload.update(),
  };

  /// `clubs.pinnedPostId` yükü; [postId] `null` ise alan boşaltılır (anahtar
  /// kaldırılmaz, açıkça `null` yazılır).
  static Json _pointerPayload(String? postId) => {
    FirestoreFields.pinnedPostId: postId,
    ...BaseFieldsPayload.update(),
  };

  /// Okunan kulüp: belge yoksa ya da silinmişse [FirestoreError.notFound],
  /// ayrıştırılamıyorsa [FirestoreError.parse] ile işlemi durdurur.
  static ClubModel _liveClub(DocumentSnapshot<Json> snapshot) {
    final doc = FirestoreDoc.fromSnapshot(snapshot);
    if (doc == null || RepositoryHelpers.isSoftDeleted(doc)) {
      throw _Halt(FirestoreError.notFound, '${snapshot.reference.path}: yok');
    }
    return _parsed(doc, FirebaseClubRepository.clubOf);
  }

  /// Okunan, [clubId] kulübüne ait gönderi: belge yoksa ya da silinmişse
  /// [FirestoreError.notFound], başka kulübün gönderisiyse
  /// [FirestoreError.invalidArgument], ayrıştırılamıyorsa
  /// [FirestoreError.parse] ile işlemi durdurur.
  static PostModel _livePost(DocumentSnapshot<Json> snapshot, String clubId) {
    final doc = FirestoreDoc.fromSnapshot(snapshot);
    if (doc == null || RepositoryHelpers.isSoftDeleted(doc)) {
      throw _Halt(FirestoreError.notFound, '${snapshot.reference.path}: yok');
    }
    final post = _parsed(doc, postOf);
    if (post.clubId != clubId) {
      throw _Halt(
        FirestoreError.invalidArgument,
        '${doc.path}: başka kulübün gönderisi',
      );
    }
    return post;
  }

  /// Okunan gönderi; belge yoksa `null`. Ayrıştırılamıyorsa
  /// [FirestoreError.parse] ile işlemi durdurur.
  static PostModel? _postOrNull(DocumentSnapshot<Json> snapshot) {
    final doc = FirestoreDoc.fromSnapshot(snapshot);
    return doc == null ? null : _parsed(doc, postOf);
  }

  /// Okunan duyuru sayacı; belge yoksa `null`. Ayrıştırılamıyorsa
  /// [FirestoreError.parse] ile işlemi durdurur.
  static CounterModel? _counterOrNull(DocumentSnapshot<Json> snapshot) {
    final doc = FirestoreDoc.fromSnapshot(snapshot);
    return doc == null
        ? null
        : _parsed(doc, FirebaseAnnouncementCounterRepository.counterOf);
  }

  static T _parsed<T>(FirestoreDoc doc, T Function(FirestoreDoc doc) fromDoc) =>
      switch (RepositoryHelpers.parse(doc, fromDoc)) {
        FirebaseSuccess(:final data) => data,
        FirebaseFailure(:final error, :final message) => throw _Halt(
          error,
          message,
        ),
      };

  static FirestoreResult<T>? _rejectPair<T>(String postId, String clubId) =>
      RepositoryHelpers.rejectInvalidIds<T>({
        'postId': postId,
        'clubId': clubId,
      });

  static FirestoreResult<T>? _rejectVoter<T>(String postId, String uid) =>
      RepositoryHelpers.rejectInvalidIds<T>({'postId': postId, 'uid': uid});

  /// [clubId] kulübünün silinmemiş gönderileri.
  Query<Json> _inClub(String clubId) => _firestore
      .collection(FirestoreCollections.posts)
      .where(FirestoreFields.clubId, isEqualTo: clubId)
      .notDeleted();

  DocumentReference<Json> _postRef(String postId) =>
      _firestore.doc(FirestoreCollections.posts, postId);

  DocumentReference<Json> _clubRef(String clubId) =>
      _firestore.doc(FirestoreCollections.clubs, clubId);

  DocumentReference<Json> _voteRef(String postId, String uid) =>
      _firestore.doc(_votesPath(postId), FirestoreIds.vote(uid));

  static String _votesPath(String postId) =>
      RepositoryHelpers.subcollectionPath(
        FirestoreCollections.posts,
        postId,
        FirestoreCollections.votesSub,
      );
}

/// Transaction gövdesinin, yazım kuyruğa girmeden işlemi durdurduğu hata
/// (bulunamadı, zaten var, ayrıştırılamadı, geçersiz girdi). İş kuralı reddi
/// bunun yerine `ConflictException` ile bildirilir.
final class _Halt implements Exception {
  const _Halt(this.error, this.message);

  final FirestoreError error;
  final String? message;
}
