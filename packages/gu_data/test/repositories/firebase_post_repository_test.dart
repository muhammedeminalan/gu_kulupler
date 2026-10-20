// T-19 · PostRepository: yayın (gönderi / duyuru / anket) — gönderi + günlük
// tek işlem, bildirimli duyuruda günün sayacı aynı transaction'da +1, hak
// 2 / Istanbul günü, gün sınırında komşu günle bir kez yeniden deneme
// (W-50, CD-129); görsel yolu denetimi (CD-39); düzenleme; beğeni ±1 (kör,
// `updatedAt` yazılmaz); oy (bir kez, değiştirilemez) ve sayım; sabitleme /
// kaldırma (`posts.pinned` ↔ `clubs.pinnedPostId` aynı transaction'da);
// kaldırma + geri yükleme (sabit gönderi dahil); gizleme; akış ve yönetim
// sorguları (süzgeçler, sıra, sayfalama, tür); tekil okuma ve canlı dinleme;
// geçersiz kimlik, ayrıştırma ve hata eşlemesi (PLAN §10.4, §10.6;
// rules-spec §3.5, §3.16, §4, §6; D-10, Q-10, W-51; docs/plans/T-19.md §6).
//
// T-21 · uploadImages: gönderi görselleri `posts/{postId}/{yeni ad}` yoluna
// `customMetadata.clubId` + `.uploaderId` ile sırayla yüklenir (CD-39); ön denetim tüm liste
// için dosya gönderilmeden; kısmi hatada yüklenenler kalır (D-10), kalanlar
// gönderilmez; Firestore'a yazılmaz (K-18).
//
// Mutlu yollar `fake_cloud_firestore` ile (Q-06); transaction yazım kümesi
// kayıt tutan servis çiftiyle (`test/fakes/recording_firestore_service.dart`),
// Rules'ın gün denetimi `test/fakes/rules_day_firestore.dart` ile, hata
// yolları el yazımı SDK çiftleriyle (`test/fakes/sdk_firestore_stubs.dart`).
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../fakes/fake_app_clock.dart';
import '../fakes/recording_firestore_service.dart';
import '../fakes/recording_storage_service.dart';
import '../fakes/rules_day_firestore.dart';
import '../fakes/sdk_firestore_stubs.dart';
import '../helpers/plan_repository_table.dart';
import '../helpers/plan_service_table.dart';

const String _interface =
    'packages/gu_data/lib/src/repositories/post_repository.dart';
const String _implementation =
    'packages/gu_data/lib/src/repositories/firebase_post_repository.dart';

const String _clubId = 'c01';
const String _author = 'u_baskan';
const String _member = 'u_uye';
const String _postId = 'p01';
const String _clubPath = 'clubs/c01';
const String _postPath = 'posts/p01';
const String _votePath = 'posts/p01/votes/u_uye';
const String _text = 'Bu hafta atölye var.';
const String _title = 'Genel kurul';

/// Geçersiz belge kimlikleri (W-54).
const List<String> _invalidIds = ['', 'c/1', '..', '__id__'];

/// Istanbul'da 13 Ekim 2026 12:00 — gün sınırı penceresinin dışında.
final DateTime _now = DateTime.utc(2026, 10, 13, 9);
final DateTime _createdAt = DateTime.utc(2026, 9, 1, 8);

/// Istanbul'da 14 Ekim 00:00 (gün sınırı).
final DateTime _midnight = DateTime.utc(2026, 10, 13, 21);

const String _day13 = '20261013';
const String _day14 = '20261014';

/// `StoragePaths.postImage` şemasında bir dosya adı.
const String _file = '20261013T090000Z_0123456789abcdef.jpg';

/// `BaseFieldsPayload.create()` yükü.
const Json _baseCreate = {
  'createdAt': serverTimestampMark,
  'updatedAt': serverTimestampMark,
  'isDeleted': false,
  'deletedAt': null,
  'deletedBy': null,
};

/// Yeni gönderi belgesinin yükü: `null` alanların (`title`, `poll`,
/// `lastCommentRef`, gizleme ve düzenleme alanları) anahtarı yoktur (W-51).
Json _postCreate({
  String type = 'post',
  String? title,
  Json? poll,
  bool pushSent = false,
  List<Json> images = const [],
}) => {
  'clubId': _clubId,
  'authorId': _author,
  'type': type,
  'title': ?title,
  'text': _text,
  'images': images,
  'poll': ?poll,
  'pinned': false,
  'pushSent': pushSent,
  'likes': <String>[],
  'likeCount': 0,
  'commentCount': 0,
  'isHidden': false,
  ..._baseCreate,
};

Json _activity(String kind, String postId) => {
  'clubId': _clubId,
  'actorId': _author,
  'kind': kind,
  'refs': {'postId': postId},
  'createdAt': serverTimestampMark,
};

Json _counter(String day, int count, String postId) => {
  'clubId': _clubId,
  'day': day,
  'count': count,
  'lastPostRef': 'posts/$postId',
  'updatedAt': serverTimestampMark,
};

Json _pinned({required bool pinned}) => {
  'pinned': pinned,
  'updatedAt': serverTimestampMark,
};

Json _pointer(String? postId) => {
  'pinnedPostId': postId,
  'updatedAt': serverTimestampMark,
};

/// `SoftDelete.payload` yükü.
const Json _softDelete = {
  'isDeleted': true,
  'deletedAt': serverTimestampMark,
  'deletedBy': _author,
  'updatedAt': serverTimestampMark,
};

Map<String, Object?> _write(String op, String path, Json data) => {
  'op': op,
  'path': path,
  'data': data,
};

/// Okunan belgede sunucu zamanı alanlarını ([keys]) nöbetçiyle değiştirir:
/// batch ile yazılan belge, kayıt tutulan transaction yüküyle aynı biçimde
/// karşılaştırılır.
Json _marked(
  Json data, [
  List<String> keys = const ['createdAt', 'updatedAt'],
]) => {
  for (final MapEntry(:key, :value) in data.entries)
    key: keys.contains(key) && value is Timestamp ? serverTimestampMark : value,
};

const PostDraft _postDraft = PostDraft(type: PostType.post, text: _text);

PostDraft _announcement({bool pushSent = true}) => PostDraft(
  type: PostType.announcement,
  title: _title,
  text: _text,
  pushSent: pushSent,
);

const PostDraft _pollDraft = PostDraft(
  type: PostType.poll,
  text: _text,
  poll: PollDraft(options: ['Evet', 'Hayır', 'Kararsızım'], durationDays: 3),
);

void main() {
  late FakeFirebaseFirestore db;
  late RecordingFirestoreService service;
  late FakeAppClock clock;
  late PostRepository repository;

  PostRepository repositoryOn(FirestoreService firestore) =>
      FirebasePostRepository(
        firestore,
        RecordingStorageService(),
        FirebaseActivityRepository(firestore),
        FirebaseAnnouncementCounterRepository(firestore, clock),
        clock,
        SequenceRandom(const [0]),
      );

  /// Her çağrısı [code] hatasıyla biten veritabanına bağlı repository.
  PostRepository failing(String code) => repositoryOn(
    FirebaseFirestoreService(StubFirestore(error: firestoreException(code))),
  );

  /// Sunucunun günü [serverDayKey] olan (Rules gün denetimli) repository;
  /// [service] bu veritabanına bağlanır.
  RulesDayFirestore useServerDay(String serverDayKey) {
    final rules = RulesDayFirestore(db, serverDayKey: serverDayKey);
    service = RecordingFirestoreService(FirebaseFirestoreService(rules));
    repository = repositoryOn(service);
    return rules;
  }

  Future<Json?> read(String path) async => (await db.doc(path).get()).data();

  Future<List<String>> ids(String collection) async => [
    for (final doc in (await db.collection(collection).get()).docs) doc.id,
  ];

  /// Transaction'da kuyruğa giren yazımlar, sırayla.
  List<Map<String, Object?>> writes() => [
    for (final write in service.writes)
      _write(write.op, write.path, write.data),
  ];

  Future<void> seedClub({
    String? pinnedPostId,
    ClubStatus status = ClubStatus.active,
    bool isDeleted = false,
  }) => db
      .doc(_clubPath)
      .set(
        ClubModel(
          name: 'Yazılım Kulübü',
          nameLower: 'yazılım kulübü',
          categoryId: 'k01',
          iconName: 'code-xml',
          palette: ClubPalette.red,
          pattern: ClubPattern.dots,
          founded: 2015,
          presidentId: _author,
          pinnedPostId: pinnedPostId,
          status: status,
          isDeleted: isDeleted,
        ).toJson(),
      );

  Future<void> seedPost({
    String id = _postId,
    String clubId = _clubId,
    PostType type = PostType.post,
    bool pinned = false,
    bool isHidden = false,
    bool isDeleted = false,
    List<String> likes = const [],
    int commentCount = 0,
    DateTime? createdAt,
  }) => db
      .doc('posts/$id')
      .set(
        PostModel(
          clubId: clubId,
          authorId: _author,
          type: type,
          title: type == PostType.announcement ? _title : null,
          text: _text,
          poll: type == PostType.poll
              ? PollModel(
                  options: const [
                    PollOptionModel(id: 'o1', text: 'Evet'),
                    PollOptionModel(id: 'o2', text: 'Hayır'),
                  ],
                  endsAt: _now.add(const Duration(days: 1)),
                )
              : null,
          pinned: pinned,
          likes: likes,
          likeCount: likes.length,
          commentCount: commentCount,
          isHidden: isHidden,
          isDeleted: isDeleted,
          createdAt: createdAt ?? _createdAt,
          updatedAt: createdAt ?? _createdAt,
        ).toJson(),
      );

  Future<void> seedCounter(String dayKey, int count) => db
      .doc('announcementCounters/${_clubId}_$dayKey')
      .set({'clubId': _clubId, 'day': 'gün', 'count': count});

  Future<FirestoreResult<PostModel>> create(
    PostDraft draft, {
    String postId = _postId,
    String clubId = _clubId,
    String authorId = _author,
  }) => repository.create(
    draft,
    authorId: authorId,
    clubId: clubId,
    postId: postId,
  );

  /// [result] duyuru hakkı reddi mi (`detail` kodu taşır)?
  void expectLimit(FirestoreResult<Object?> result) {
    expect(result.errorOrNull, FirestoreError.ruleViolation);
    expect(
      switch (result) {
        FirebaseFailure(:final detail) => detail,
        FirebaseSuccess() => null,
      },
      const FirestoreFailureDetail(FirestoreRuleCode.announcementLimit),
    );
  }

  setUp(() {
    db = FakeFirebaseFirestore();
    service = RecordingFirestoreService(FirebaseFirestoreService(db));
    clock = FakeAppClock(_now);
    repository = repositoryOn(service);
  });

  group('T-19 · PostRepository · sözleşme', () {
    test('PLAN §10.4 tablosunun üyeleri arayüzde aynı imzayla var', () {
      final plan = readPlanRepositoryMembers('$PostRepository');

      expect(plan.map((row) => row.member), [
        'newPostId',
        // T-21 · görsel yükleme (CD-39).
        'uploadImages',
        'create',
        'update',
        'softDeletePost',
        'restorePost',
        'pin',
        'unpin',
        'like',
        'unlike',
        'vote',
        'myVote',
        'countVotes',
        'listFeed',
        'watchFeedHead',
        'listForManagement',
        'getPost',
        'watchPost',
        // Tek satır: `hide` / `unhide` (yalnızca `hide` imzası yazılı).
        'hide',
      ]);
      expect(interfaceMembers(_interface, '$PostRepository').toSet(), {
        for (final row in plan) normalizeDartSource(row.signature),
        normalizeDartSource(
          'Future<FirestoreResult<void>> unhide(String postId)',
        ),
      });
    });

    test('arayüzde ve uygulamada silme üyesi yok (D-10)', () {
      expect(deleteIdentifiersIn(_interface), isEmpty);
      expect(deleteIdentifiersIn(_implementation), isEmpty);
    });

    test('newPostId her çağrıda yeni, geçerli bir kimlik üretir', () {
      final first = repository.newPostId();
      final second = repository.newPostId();

      expect(RepositoryHelpers.isValidId(first), isTrue);
      expect(first, isNot(second));
    });
  });

  group('T-21 · uploadImages · gönderi görselleri (CD-39)', () {
    late RecordingStorageService storage;
    late PostRepository uploader;

    /// Sırayla artan baytlar: her dosya adı (8 bayt) farklıdır.
    final sequence = List<int>.generate(64, (i) => i);
    const first = 'posts/p01/20261013T090000Z_0001020304050607.jpg';
    const second = 'posts/p01/20261013T090000Z_08090a0b0c0d0e0f.png';
    const third = 'posts/p01/20261013T090000Z_1011121314151617.webp';

    PostImageUpload image({
      String contentType = 'image/jpeg',
      int length = 3,
      int width = 1200,
      int height = 900,
    }) => PostImageUpload(
      bytes: Uint8List(length),
      contentType: contentType,
      width: width,
      height: height,
    );

    setUp(() {
      storage = RecordingStorageService();
      uploader = FirebasePostRepository(
        service,
        storage,
        FirebaseActivityRepository(service),
        FirebaseAnnouncementCounterRepository(service, clock),
        clock,
        SequenceRandom(sequence),
      );
    });

    test('her görsel posts/{postId}/{yeni ad} yoluna, türünün uzantısıyla ve '
        'yalnızca clubId + uploaderId üst verisiyle, girdi sırasıyla '
        'yüklenir', () async {
      final images = [
        image(),
        image(contentType: 'image/png', width: 800, height: 800),
        image(contentType: 'image/webp', width: 640, height: 960),
      ];
      final reported = <(int, PostImageModel)>[];

      final result = await uploader.uploadImages(
        _postId,
        images,
        clubId: _clubId,
        uploaderId: _author,
        onUploaded: (index, image) => reported.add((index, image)),
      );

      const models = [
        PostImageModel(path: first, w: 1200, h: 900),
        PostImageModel(path: second, w: 800, h: 800),
        PostImageModel(path: third, w: 640, h: 960),
      ];
      expect(result.dataOrNull, models);
      expect(reported, [(0, models[0]), (1, models[1]), (2, models[2])]);
      expect(storage.uploads.map((upload) => upload.path), [
        first,
        second,
        third,
      ]);
      for (final (index, upload) in storage.uploads.indexed) {
        expect(StoragePaths.isPostImage(upload.path, _postId), isTrue);
        expect(upload.bytes, same(images[index].bytes));
        expect(upload.contentType, images[index].contentType);
        // Rules: `uploaderId == request.auth.uid` — yükleyen izlenebilir.
        expect(upload.customMetadata, {
          'clubId': _clubId,
          'uploaderId': _author,
        });
      }
      // K-18: yükleme Firestore'a hiçbir şey yazmaz.
      expect(service.outsideWrites, 0);
      expect(service.transactions, 0);
      expect(await ids('posts'), isEmpty);
    });

    test(
      'yüklenen modeller yayın yükünde aynen kabul edilir (create)',
      () async {
        final uploaded = (await uploader.uploadImages(
          _postId,
          [
            image(),
          ],
          clubId: _clubId,
          uploaderId: _author,
        )).dataOrNull!;

        final created = await uploader.create(
          PostDraft(type: PostType.post, text: _text, images: uploaded),
          authorId: _author,
          clubId: _clubId,
          postId: _postId,
        );

        expect(created.dataOrNull!.images, uploaded);
        expect((await read(_postPath))!['images'], [
          {'path': first, 'w': 1200, 'h': 900},
        ]);
      },
    );

    test('boş liste hiçbir şey yüklemeden başarıdır; en çok 4 görsel yüklenir; '
        '5. görsel hiçbir dosya gönderilmeden reddedilir', () async {
      final none = await uploader.uploadImages(
        _postId,
        [],
        clubId: _clubId,
        uploaderId: _author,
      );
      final four = await uploader.uploadImages(
        _postId,
        [
          for (var i = 0; i < Limits.postImagesMax; i++) image(),
        ],
        clubId: _clubId,
        uploaderId: _author,
      );
      final sent = storage.uploads.length;
      final five = await uploader.uploadImages(
        _postId,
        [
          for (var i = 0; i <= Limits.postImagesMax; i++) image(),
        ],
        clubId: _clubId,
        uploaderId: _author,
      );

      expect(none.dataOrNull, isEmpty);
      expect(four.dataOrNull, hasLength(Limits.postImagesMax));
      expect(
        {for (final upload in storage.uploads) upload.path},
        hasLength(Limits.postImagesMax),
      );
      expect(
        five.errorOrNull,
        const MediaDocumentError(FirestoreError.invalidArgument),
      );
      expect(storage.uploads, hasLength(sent));
    });

    test(
      'geçersiz kimlik ya da boyut bilgisi → belge hatası (invalidArgument), '
      'dosya gönderilmez',
      () async {
        final results = [
          for (final id in _invalidIds) ...[
            await uploader.uploadImages(
              id,
              [image()],
              clubId: _clubId,
              uploaderId: _author,
            ),
            await uploader.uploadImages(
              _postId,
              [image()],
              clubId: id,
              uploaderId: _author,
            ),
            await uploader.uploadImages(
              _postId,
              [image()],
              clubId: _clubId,
              uploaderId: id,
            ),
          ],
          await uploader.uploadImages(
            _postId,
            [
              image(),
              image(width: 0),
            ],
            clubId: _clubId,
            uploaderId: _author,
          ),
          await uploader.uploadImages(
            _postId,
            [
              image(height: -1),
            ],
            clubId: _clubId,
            uploaderId: _author,
          ),
        ];

        for (final result in results) {
          expect(
            result.errorOrNull,
            const MediaDocumentError(FirestoreError.invalidArgument),
          );
        }
        expect(storage.uploads, isEmpty);
      },
    );

    test('izinsiz tür, boş ve sınırdaki / üstündeki görsel → yükleme hatası; '
        'listedeki geçerli görseller de gönderilmez', () async {
      Future<MediaUpdateError?> upload(PostImageUpload bad) async =>
          (await uploader.uploadImages(
            _postId,
            [
              image(),
              bad,
            ],
            clubId: _clubId,
            uploaderId: _author,
          )).errorOrNull;

      expect(
        await upload(image(contentType: 'image/gif')),
        const MediaUploadError(StorageError.invalidType),
      );
      expect(
        await upload(image(contentType: 'image/svg+xml')),
        const MediaUploadError(StorageError.invalidType),
      );
      expect(
        await upload(image(length: 0)),
        const MediaUploadError(StorageError.noFile),
      );
      expect(
        await upload(image(length: Limits.imageMaxBytes)),
        const MediaUploadError(StorageError.sizeLimit),
      );
      expect(
        await upload(image(length: Limits.imageMaxBytes + 1)),
        const MediaUploadError(StorageError.sizeLimit),
      );
      expect(storage.uploads, isEmpty);

      final under = await uploader.uploadImages(
        _postId,
        [
          image(length: Limits.imageMaxBytes - 1),
        ],
        clubId: _clubId,
        uploaderId: _author,
      );
      expect(under.isSuccess, isTrue);
    });

    test('yükleme hatası (ağ, zaman aşımı, Rules reddi) aynen döner; kalanlar '
        'gönderilmez, yüklenenler bildirilmiş kalır', () async {
      for (final error in [
        StorageError.retryLimitExceeded,
        StorageError.timeout,
        StorageError.unauthorized,
      ]) {
        storage.uploads.clear();
        final reported = <int>[];

        final result = await uploader.uploadImages(
          _postId,
          [image(), image(), image()],
          clubId: _clubId,
          uploaderId: _author,
          // İkinci yükleme başarısız olur.
          onUploaded: (index, _) {
            reported.add(index);
            storage.nextError = error;
          },
        );

        expect(result.errorOrNull, MediaUploadError(error));
        expect(reported, [0]);
        expect(storage.uploads, hasLength(2));
        storage.nextError = null;
      }
    });

    test('yeniden deneme yalnızca kalanları yeni adla gönderir (üzerine yazma '
        'yok)', () async {
      final kept = <PostImageModel>[];
      storage.nextError = null;
      final failed = await uploader.uploadImages(
        _postId,
        [image(), image()],
        clubId: _clubId,
        uploaderId: _author,
        onUploaded: (_, image) {
          kept.add(image);
          storage.nextError = StorageError.retryLimitExceeded;
        },
      );
      storage.nextError = null;

      final retried = await uploader.uploadImages(
        _postId,
        [
          image(),
        ],
        clubId: _clubId,
        uploaderId: _author,
      );

      expect(failed.isSuccess, isFalse);
      expect(kept, hasLength(1));
      final paths = [for (final upload in storage.uploads) upload.path];
      expect(paths, hasLength(3));
      expect(paths.toSet(), hasLength(3));
      expect(retried.dataOrNull!.single.path, paths.last);
      expect(retried.dataOrNull!.single.path, isNot(kept.single.path));
    });
  });

  group('T-19 · create · gönderi ve anket (sayaçsız, tek batch)', () {
    test('gönderi + günlük tek batch; sıfır sayaçlar, null alanların '
        'anahtarı yok; duyuru sayacı yazılmaz', () async {
      final result = await create(_postDraft);

      expect(service.outsideWrites, 1);
      expect(service.transactions, 0);
      expect(_marked((await read(_postPath))!), _postCreate());
      expect(
        _marked((await read('activity/c01_u_baskan_post_created_p01'))!),
        _activity('post_created', _postId),
      );
      expect(await ids('activity'), hasLength(1));
      expect(await ids('announcementCounters'), isEmpty);

      final model = result.dataOrNull!;
      expect(model.id, _postId);
      expect(model.clubId, _clubId);
      expect(model.authorId, _author);
      expect(model.likeCount, 0);
      expect(model.commentCount, 0);
      expect(model.createdAt, _now);
    });

    test('batch işlenemezse ne gönderi ne günlük yazılır', () async {
      final broken = repositoryOn(
        FirebaseFirestoreService(
          FailingBatchFirestore(db, error: firestoreException('unavailable')),
        ),
      );

      final result = await broken.create(
        _postDraft,
        authorId: _author,
        clubId: _clubId,
        postId: _postId,
      );

      expect(result.errorOrNull, FirestoreError.unavailable);
      expect(await read(_postPath), isNull);
      expect(await ids('activity'), isEmpty);
    });

    test('anket: seçenek kimlikleri o1..oN, bitiş nowUtc + süre; anketteki '
        'pushSent yok sayılır (false, sayaçsız)', () async {
      final result = await create(
        PostDraft(
          type: PostType.poll,
          text: _text,
          poll: _pollDraft.poll,
          pushSent: true,
        ),
      );

      final endsAt = _now.add(const Duration(days: 3));
      expect(
        _marked((await read(_postPath))!),
        _postCreate(
          type: 'poll',
          poll: {
            'options': [
              {'id': 'o1', 'text': 'Evet'},
              {'id': 'o2', 'text': 'Hayır'},
              {'id': 'o3', 'text': 'Kararsızım'},
            ],
            'endsAt': Timestamp.fromDate(endsAt),
            'showResultsAfterVote': true,
          },
        ),
      );
      expect(await ids('activity'), ['c01_u_baskan_poll_p01']);
      expect(await ids('announcementCounters'), isEmpty);
      expect(service.transactions, 0);
      expect(result.dataOrNull!.poll!.endsAt, endsAt);
      expect(result.dataOrNull!.pushSent, isFalse);
    });

    test(
      'bildirimsiz duyuru: başlık yazılır, sayaç ve transaction yok',
      () async {
        await create(_announcement(pushSent: false));

        expect(
          _marked((await read(_postPath))!),
          _postCreate(type: 'announcement', title: _title),
        );
        expect(await ids('activity'), ['c01_u_baskan_announcement_p01']);
        expect(await ids('announcementCounters'), isEmpty);
        expect(service.transactions, 0);
      },
    );

    test('görseller: kendi klasöründeki yollar yazılır (CD-39)', () async {
      final image = PostImageModel(
        path: StoragePaths.postImage(_postId, _file),
        w: 1200,
        h: 800,
      );

      await create(
        PostDraft(type: PostType.post, text: _text, images: [image]),
      );

      expect((await read(_postPath))!['images'], [
        {'path': 'posts/p01/$_file', 'w': 1200, 'h': 800},
      ]);
    });

    test('tür kurallarına uymayan taslak invalidArgument; hiçbir şey '
        'yazılmaz', () async {
      PostImageModel image(String path) =>
          PostImageModel(path: path, w: 10, h: 10);
      const poll = PollDraft(options: ['A', 'B'], durationDays: 1);
      final drafts = <String, PostDraft>{
        'boş metin': const PostDraft(type: PostType.post, text: ' '),
        'uzun metin': PostDraft(
          type: PostType.post,
          text: 'a' * (Limits.postTextMax + 1),
        ),
        'başlıksız duyuru': const PostDraft(
          type: PostType.announcement,
          text: _text,
        ),
        'başlıklı gönderi': const PostDraft(
          type: PostType.post,
          text: _text,
          title: _title,
        ),
        'anketsiz anket': const PostDraft(type: PostType.poll, text: _text),
        'anketli gönderi': const PostDraft(
          type: PostType.post,
          text: _text,
          poll: poll,
        ),
        'tek seçenek': const PostDraft(
          type: PostType.poll,
          text: _text,
          poll: PollDraft(options: ['A'], durationDays: 1),
        ),
        'beş seçenek': const PostDraft(
          type: PostType.poll,
          text: _text,
          poll: PollDraft(options: ['A', 'B', 'C', 'D', 'E'], durationDays: 1),
        ),
        'geçersiz süre': const PostDraft(
          type: PostType.poll,
          text: _text,
          poll: PollDraft(options: ['A', 'B'], durationDays: 2),
        ),
        'beş görsel': PostDraft(
          type: PostType.post,
          text: _text,
          images: [
            for (var i = 0; i <= Limits.postImagesMax; i++)
              image(StoragePaths.postImage(_postId, _file)),
          ],
        ),
        'başka gönderinin görseli': PostDraft(
          type: PostType.post,
          text: _text,
          images: [image(StoragePaths.postImage('p02', _file))],
        ),
        'başka kökün dosyası': PostDraft(
          type: PostType.post,
          text: _text,
          images: [image(StoragePaths.userAvatar(_author, _file))],
        ),
      };

      for (final MapEntry(key: name, value: draft) in drafts.entries) {
        expect(
          (await create(draft)).errorOrNull,
          FirestoreError.invalidArgument,
          reason: name,
        );
      }
      expect(service.outsideWrites, 0);
      expect(service.transactions, 0);
      expect(await read(_postPath), isNull);
    });
  });

  group('T-19 · create · bildirimli duyuru (sayaç + hak 2 / gün)', () {
    test('sayaç +1 + gönderi + günlük tek transaction; sayaç aynı işlemde '
        'okunur ve bu gönderiyi gösterir', () async {
      final result = await create(_announcement());

      expect(writes(), [
        _write(
          'set',
          'announcementCounters/c01_$_day13',
          _counter('2026-10-13', 1, _postId),
        ),
        _write(
          'set',
          _postPath,
          _postCreate(type: 'announcement', title: _title, pushSent: true),
        ),
        _write(
          'set',
          'activity/c01_u_baskan_announcement_p01',
          _activity('announcement', _postId),
        ),
      ]);
      expect(service.transactions, 1);
      expect(service.outsideWrites, 0);
      expect(service.reads, ['announcementCounters/c01_$_day13']);
      expect(result.dataOrNull!.pushSent, isTrue);
      expect(result.dataOrNull!.title, _title);
    });

    test('günde iki hak: ikinci duyuru sayacı 2 yapar, üçüncüsü '
        'announcementLimit döner ve hiçbir şey yazmaz', () async {
      await create(_announcement());
      final second = await create(_announcement(), postId: 'p02');
      final writtenSoFar = service.writes.length;

      final third = await create(_announcement(), postId: 'p03');

      expect(second.isSuccess, isTrue);
      expectLimit(third);
      expect(service.writes, hasLength(writtenSoFar));
      expect(await read('posts/p03'), isNull);
      expect(await ids('activity'), hasLength(2));
      final counter = (await read('announcementCounters/c01_$_day13'))!;
      expect(counter['count'], Limits.announcementDailyLimit);
      expect(counter['lastPostRef'], 'posts/p02');
    });

    test('hak kulübe ve güne göredir: başka kulüp ve bildirimsiz duyuru '
        'haktan düşmez', () async {
      await seedCounter(_day13, Limits.announcementDailyLimit);

      final otherClub = await create(_announcement(), clubId: 'c02');
      final silent = await create(
        _announcement(pushSent: false),
        postId: 'p02',
      );
      final post = await create(_postDraft, postId: 'p03');

      expect(otherClub.isSuccess, isTrue);
      expect(silent.isSuccess, isTrue);
      expect(post.isSuccess, isTrue);
      expect((await read('announcementCounters/c02_$_day13'))!['count'], 1);
    });

    test('gün Istanbul günüdür: 20:59:59Z bugünün, 21:00:00Z yarının '
        'sayacına yazar', () async {
      clock.set(_midnight.subtract(const Duration(seconds: 1)));
      await create(_announcement());
      clock.set(_midnight);
      await create(_announcement(), postId: 'p02');

      expect(
        _marked((await read('announcementCounters/c01_$_day13'))!),
        _counter('2026-10-13', 1, _postId),
      );
      expect(
        _marked((await read('announcementCounters/c01_$_day14'))!),
        _counter('2026-10-14', 1, 'p02'),
      );
    });
  });

  group('T-19 · create · gün sınırı (W-50, CD-129)', () {
    test('gün başından sonraki pencere: cihaz yarında, sunucu dünde → ret, '
        'dünün sayacıyla bir kez yeniden denenir', () async {
      final rules = useServerDay(_day13);
      clock.set(_midnight.add(const Duration(minutes: 2)));

      final result = await create(_announcement());

      expect(result.isSuccess, isTrue);
      expect(service.transactions, 2);
      expect(service.reads, [
        'announcementCounters/c01_$_day14',
        'announcementCounters/c01_$_day13',
      ]);
      expect(rules.denied, ['announcementCounters/c01_$_day14']);
      expect(
        _marked((await read('announcementCounters/c01_$_day13'))!),
        _counter('2026-10-13', 1, _postId),
      );
      expect(await ids('announcementCounters'), ['c01_$_day13']);
      expect(await ids('posts'), [_postId]);
      expect(await ids('activity'), hasLength(1));
    });

    test('gün bitmeden önceki pencere: cihaz bugünde, sunucu yarında → '
        'yarının sayacıyla yeniden denenir', () async {
      useServerDay(_day14);
      clock.set(_midnight.subtract(const Duration(minutes: 3)));

      final result = await create(_announcement());

      expect(result.isSuccess, isTrue);
      expect(service.transactions, 2);
      expect(
        _marked((await read('announcementCounters/c01_$_day14'))!),
        _counter('2026-10-14', 1, _postId),
      );
      expect(await ids('announcementCounters'), ['c01_$_day14']);
    });

    test('pencere dışında yeniden deneme yok: ret olduğu gibi döner', () async {
      useServerDay(_day14);

      final result = await create(_announcement());

      expect(result.errorOrNull, FirestoreError.permissionDenied);
      expect(service.transactions, 1);
      expect(await ids('posts'), isEmpty);
      expect(await ids('announcementCounters'), isEmpty);
    });

    test('ikinci deneme de reddedilirse sonuç onun hatasıdır; üçüncü deneme '
        'yok', () async {
      useServerDay('20261101');
      clock.set(_midnight.add(const Duration(minutes: 2)));

      final result = await create(_announcement());

      expect(result.errorOrNull, FirestoreError.permissionDenied);
      expect(service.transactions, 2);
      expect(await ids('posts'), isEmpty);
      expect(await ids('activity'), isEmpty);
    });

    test('komşu günün hakkı dolmuşsa yeniden deneme announcementLimit '
        'döner', () async {
      useServerDay(_day13);
      clock.set(_midnight.add(const Duration(minutes: 2)));
      await seedCounter(_day13, Limits.announcementDailyLimit);

      final result = await create(_announcement());

      expectLimit(result);
      expect(service.transactions, 2);
      expect(await ids('posts'), isEmpty);
    });

    test('cihaz gününün hakkı dolmuşsa pencere içinde de yeniden deneme '
        'yok', () async {
      useServerDay(_day13);
      clock.set(_midnight.add(const Duration(minutes: 2)));
      await seedCounter(_day14, Limits.announcementDailyLimit);

      final result = await create(_announcement());

      expectLimit(result);
      expect(service.transactions, 1);
      expect(await ids('posts'), isEmpty);
    });

    test(
      'sayaçsız yayın pencere içinde reddedilse de yeniden denenmez',
      () async {
        clock.set(_midnight.add(const Duration(minutes: 2)));
        final stub = StubFirestore(
          error: firestoreException('permission-denied'),
        );

        final result = await repositoryOn(FirebaseFirestoreService(stub))
            .create(
              _postDraft,
              authorId: _author,
              clubId: _clubId,
              postId: _postId,
            );

        expect(result.errorOrNull, FirestoreError.permissionDenied);
        expect(stub.batches, hasLength(1));
        expect(stub.transactionMaxAttempts, isNull);
      },
    );
  });

  group('T-19 · update · düzenleme', () {
    test('yalnızca verilen alanlar + editedAt + updatedAt yazılır; tür, '
        'anket, sayaçlar ve sabitleme değişmez', () async {
      await seedPost(type: PostType.poll, pinned: true, commentCount: 3);
      final before = (await read(_postPath))!;

      final result = await repository.update(
        _postId,
        const PostEditPatch(text: 'Yeni soru?'),
        authorId: _author,
      );

      final after = (await read(_postPath))!;
      expect(result.isSuccess, isTrue);
      expect(service.outsideWrites, 1);
      expect(service.transactions, 0);
      expect(after['text'], 'Yeni soru?');
      expect(after['editedAt'], isA<Timestamp>());
      expect(after['updatedAt'], isNot(before['updatedAt']));
      expect(
        {...after}..removeWhere(
          (key, _) => const {'text', 'editedAt', 'updatedAt'}.contains(key),
        ),
        {...before}..removeWhere(
          (key, _) => const {'text', 'updatedAt'}.contains(key),
        ),
      );
    });

    test('başlık ve görseller: boş liste görselleri kaldırır', () async {
      await seedPost(type: PostType.announcement);

      await repository.update(
        _postId,
        const PostEditPatch(title: 'Yeni başlık', images: []),
        authorId: _author,
      );

      final after = (await read(_postPath))!;
      expect(after['title'], 'Yeni başlık');
      expect(after['images'], isEmpty);
      expect(after['text'], _text);
    });

    test('boş yama, sınır dışı alan ve başka gönderinin görseli '
        'invalidArgument; yazım yok', () async {
      await seedPost();
      final patches = <PostEditPatch>[
        const PostEditPatch(),
        const PostEditPatch(text: ''),
        PostEditPatch(title: 'a' * (Limits.postTitleMax + 1)),
        PostEditPatch(
          images: [
            PostImageModel(
              path: StoragePaths.postImage('p02', _file),
              w: 1,
              h: 1,
            ),
          ],
        ),
      ];

      for (final patch in patches) {
        expect(
          (await repository.update(
            _postId,
            patch,
            authorId: _author,
          )).errorOrNull,
          FirestoreError.invalidArgument,
          reason: '$patch',
        );
      }
      expect(service.outsideWrites, 0);
    });
  });

  group('T-19 · like / unlike · likeCount ±1', () {
    test('like: tek yazımda likes dizisine eklenir ve likeCount +1; '
        'updatedAt yazılmaz, önce okuma / transaction yok', () async {
      await seedPost(likes: ['u_x']);
      final before = (await read(_postPath))!;

      final result = await repository.like(_postId, uid: _member);

      final after = (await read(_postPath))!;
      expect(result.isSuccess, isTrue);
      expect(after['likes'], ['u_x', _member]);
      expect(after['likeCount'], 2);
      expect(after['updatedAt'], before['updatedAt']);
      expect(service.outsideWrites, 1);
      expect(service.transactions, 0);
    });

    test('unlike: tek yazımda diziden çıkar ve likeCount −1; updatedAt '
        'yazılmaz', () async {
      await seedPost(likes: ['u_x', _member]);
      final before = (await read(_postPath))!;

      final result = await repository.unlike(_postId, uid: _member);

      final after = (await read(_postPath))!;
      expect(result.isSuccess, isTrue);
      expect(after['likes'], ['u_x']);
      expect(after['likeCount'], 1);
      expect(after['updatedAt'], before['updatedAt']);
      expect(service.outsideWrites, 1);
    });

    test('çift beğeni / beğenmeden geri alma: yazım kördür, Rules reddi '
        'permissionDenied olarak döner', () async {
      final denied = failing('permission-denied');

      expect(
        (await denied.like(_postId, uid: _member)).errorOrNull,
        FirestoreError.permissionDenied,
      );
      expect(
        (await denied.unlike(_postId, uid: _member)).errorOrNull,
        FirestoreError.permissionDenied,
      );
    });
  });

  group('T-19 · vote · bir kullanıcı bir oy', () {
    test('oy belgesi transaction içinde okunur, yoksa yazılır (optionId + '
        'createdAt); sayaç alanı yazılmaz', () async {
      await seedPost(type: PostType.poll);
      final before = (await read(_postPath))!;

      final result = await repository.vote(
        _postId,
        uid: _member,
        optionId: 'o2',
      );

      expect(result.isSuccess, isTrue);
      expect(writes(), [
        _write('set', _votePath, {
          'optionId': 'o2',
          'createdAt': serverTimestampMark,
        }),
      ]);
      expect(service.reads, [_votePath]);
      expect(service.transactions, 1);
      expect(service.outsideWrites, 0);
      expect(await read(_postPath), before);
    });

    test(
      'çift oy ve oy değiştirme alreadyExists; ilk oy olduğu gibi kalır',
      () async {
        await seedPost(type: PostType.poll);
        await repository.vote(_postId, uid: _member, optionId: 'o2');

        final again = await repository.vote(
          _postId,
          uid: _member,
          optionId: 'o2',
        );
        final changed = await repository.vote(
          _postId,
          uid: _member,
          optionId: 'o1',
        );

        expect(again.errorOrNull, FirestoreError.alreadyExists);
        expect(changed.errorOrNull, FirestoreError.alreadyExists);
        expect(service.writes, hasLength(1));
        expect((await read(_votePath))!['optionId'], 'o2');
      },
    );

    test('myVote: seçilen seçenek; oy yoksa null', () async {
      await repository.vote(_postId, uid: _member, optionId: 'o2');

      expect(
        (await repository.myVote(_postId, uid: _member)).dataOrNull,
        'o2',
      );
      final none = await repository.myVote(_postId, uid: 'u_baska');
      expect(none.isSuccess, isTrue);
      expect(none.dataOrNull, isNull);
    });

    test(
      'countVotes: seçenek başına sayım, oy almayan 0; tekrar eden '
      'kimlik bir kez sayılır; dörtten çok seçenek invalidArgument',
      () async {
        await repository.vote(_postId, uid: 'u1', optionId: 'o1');
        await repository.vote(_postId, uid: 'u2', optionId: 'o1');
        await repository.vote(_postId, uid: 'u3', optionId: 'o2');
        await repository.vote('p02', uid: 'u4', optionId: 'o1');

        final counts = await repository.countVotes(_postId, [
          'o1',
          'o2',
          'o3',
          'o1',
        ]);
        final tooMany = await repository.countVotes(_postId, [
          'o1',
          'o2',
          'o3',
          'o4',
          'o5',
        ]);

        expect(counts.dataOrNull, {'o1': 2, 'o2': 1, 'o3': 0});
        expect(tooMany.errorOrNull, FirestoreError.invalidArgument);
        expect((await repository.countVotes(_postId, [])).dataOrNull, isEmpty);
      },
    );
  });

  group('T-19 · pin / unpin · posts.pinned ↔ clubs.pinnedPostId', () {
    test('pin: gönderi pinned:true + kulüp pinnedPostId tek transaction; '
        'kulüp ve gönderi önce okunur', () async {
      await seedClub();
      await seedPost();

      final result = await repository.pin(_postId, clubId: _clubId);

      expect(result.isSuccess, isTrue);
      expect(writes(), [
        _write('update', _postPath, _pinned(pinned: true)),
        _write('update', _clubPath, _pointer(_postId)),
      ]);
      expect(service.reads, [_clubPath, _postPath]);
      expect(service.transactions, 1);
      expect(service.outsideWrites, 0);
      expect((await read(_postPath))!['pinned'], isTrue);
      expect((await read(_clubPath))!['pinnedPostId'], _postId);
    });

    test('pin: önceki sabit gönderi aynı işlemde kalkar (kulüpte en çok bir '
        'sabit)', () async {
      await seedClub(pinnedPostId: 'p_eski');
      await seedPost(id: 'p_eski', pinned: true);
      await seedPost();

      await repository.pin(_postId, clubId: _clubId);

      expect(writes(), [
        _write('update', 'posts/p_eski', _pinned(pinned: false)),
        _write('update', _postPath, _pinned(pinned: true)),
        _write('update', _clubPath, _pointer(_postId)),
      ]);
      expect(service.reads, [_clubPath, _postPath, 'posts/p_eski']);
      expect((await read('posts/p_eski'))!['pinned'], isFalse);
      expect((await read(_clubPath))!['pinnedPostId'], _postId);
    });

    test('pin: zaten sabitse hiçbir şey yazılmaz', () async {
      await seedClub(pinnedPostId: _postId);
      await seedPost(pinned: true);

      final result = await repository.pin(_postId, clubId: _clubId);

      expect(result.isSuccess, isTrue);
      expect(service.writes, isEmpty);
    });

    test(
      'pin: gönderi yok / silinmiş / gizli → notFound; başka kulübün '
      'gönderisi → invalidArgument; kulüp yok → notFound; yazım yok',
      () async {
        await seedClub();
        await seedPost(id: 'p_silik', isDeleted: true);
        await seedPost(id: 'p_gizli', isHidden: true);
        await seedPost(id: 'p_baska', clubId: 'c02');
        await seedPost();

        Future<FirestoreError?> pin(String postId, {String clubId = _clubId}) =>
            repository.pin(postId, clubId: clubId).then((r) => r.errorOrNull);

        expect(await pin('p_yok'), FirestoreError.notFound);
        expect(await pin('p_silik'), FirestoreError.notFound);
        expect(await pin('p_gizli'), FirestoreError.notFound);
        expect(await pin('p_baska'), FirestoreError.invalidArgument);
        expect(await pin(_postId, clubId: 'c_yok'), FirestoreError.notFound);
        expect(service.writes, isEmpty);
      },
    );

    test('unpin: pinned:false + pinnedPostId:null tek transaction; sabit '
        'değilse hiçbir şey yazılmaz', () async {
      await seedClub(pinnedPostId: _postId);
      await seedPost(pinned: true);
      await seedPost(id: 'p02');

      final unpinned = await repository.unpin(_postId, clubId: _clubId);

      expect(unpinned.isSuccess, isTrue);
      expect(writes(), [
        _write('update', _postPath, _pinned(pinned: false)),
        _write('update', _clubPath, _pointer(null)),
      ]);
      final club = (await read(_clubPath))!;
      expect(club, contains('pinnedPostId'));
      expect(club['pinnedPostId'], isNull);

      final noop = await repository.unpin('p02', clubId: _clubId);

      expect(noop.isSuccess, isTrue);
      expect(service.writes, hasLength(2));
      expect(service.outsideWrites, 0);
    });
  });

  group('T-19 · softDeletePost / restorePost', () {
    test('sabit olmayan gönderi: yalnızca silme alanları yazılır; kulüp, '
        'sayaçlar ve duyuru hakkı değişmez', () async {
      await seedClub(pinnedPostId: 'p_baska');
      await seedPost(likes: [_member], commentCount: 4);
      await seedCounter(_day13, 1);

      final result = await repository.softDeletePost(
        _postId,
        actorId: _author,
        clubId: _clubId,
      );

      expect(result.isSuccess, isTrue);
      expect(writes(), [_write('update', _postPath, _softDelete)]);
      expect(service.reads, [_postPath]);
      expect(service.outsideWrites, 0);
      final post = (await read(_postPath))!;
      expect(post['isDeleted'], isTrue);
      expect(post['deletedBy'], _author);
      expect(post['likeCount'], 1);
      expect(post['commentCount'], 4);
      expect((await read(_clubPath))!['pinnedPostId'], 'p_baska');
      expect((await read('announcementCounters/c01_$_day13'))!['count'], 1);
    });

    test('sabit gönderi: aynı işlemde pinned:false ve kulübün '
        'pinnedPostId alanı boşalır', () async {
      await seedClub(pinnedPostId: _postId);
      await seedPost(pinned: true);

      await repository.softDeletePost(
        _postId,
        actorId: _author,
        clubId: _clubId,
      );

      expect(writes(), [
        _write('update', _postPath, {..._softDelete, 'pinned': false}),
        _write('update', _clubPath, _pointer(null)),
      ]);
      expect(service.transactions, 1);
      expect((await read(_postPath))!['pinned'], isFalse);
      expect((await read(_clubPath))!['pinnedPostId'], isNull);
    });

    test('gönderi yok ya da zaten silinmiş → notFound; başka kulübün '
        'gönderisi → invalidArgument; yazım yok', () async {
      await seedPost(id: 'p_silik', isDeleted: true);
      await seedPost(id: 'p_baska', clubId: 'c02');

      Future<FirestoreError?> remove(String postId) => repository
          .softDeletePost(postId, actorId: _author, clubId: _clubId)
          .then((r) => r.errorOrNull);

      expect(await remove('p_yok'), FirestoreError.notFound);
      expect(await remove('p_silik'), FirestoreError.notFound);
      expect(await remove('p_baska'), FirestoreError.invalidArgument);
      expect(service.writes, isEmpty);
    });

    test('restorePost: silme alanları geri alınır (null yazılır); sabit '
        'gönderi yeniden sabitlenmez', () async {
      await seedClub(pinnedPostId: _postId);
      await seedPost(pinned: true);
      await repository.softDeletePost(
        _postId,
        actorId: _author,
        clubId: _clubId,
      );

      final result = await repository.restorePost(_postId);

      expect(result.isSuccess, isTrue);
      expect(service.outsideWrites, 1);
      final post = (await read(_postPath))!;
      expect(post['isDeleted'], isFalse);
      expect(post, containsPair('deletedAt', null));
      expect(post, containsPair('deletedBy', null));
      expect(post['pinned'], isFalse);
      expect((await read(_clubPath))!['pinnedPostId'], isNull);
      expect((await repository.getPost(_postId)).isSuccess, isTrue);
    });
  });

  group('T-19 · hide / unhide', () {
    test('hide: isHidden + hiddenBy + hiddenAt; unhide: ikisi null; sayaç '
        've sabitleme değişmez', () async {
      await seedPost(pinned: true, commentCount: 2);

      final hidden = await repository.hide(_postId, actorId: 'u_super');
      final afterHide = (await read(_postPath))!;
      final shown = await repository.unhide(_postId);
      final afterShow = (await read(_postPath))!;

      expect(hidden.isSuccess, isTrue);
      expect(afterHide['isHidden'], isTrue);
      expect(afterHide['hiddenBy'], 'u_super');
      expect(afterHide['hiddenAt'], isA<Timestamp>());
      expect(afterHide['pinned'], isTrue);
      expect(afterHide['commentCount'], 2);
      expect(shown.isSuccess, isTrue);
      expect(afterShow['isHidden'], isFalse);
      expect(afterShow, containsPair('hiddenBy', null));
      expect(afterShow, containsPair('hiddenAt', null));
      expect(service.outsideWrites, 2);
    });
  });

  group('T-19 · okumalar', () {
    Future<void> seedFeed() async {
      Future<void> post(
        String id,
        int day, {
        PostType type = PostType.post,
        bool isHidden = false,
        bool isDeleted = false,
        String clubId = _clubId,
      }) => seedPost(
        id: id,
        type: type,
        isHidden: isHidden,
        isDeleted: isDeleted,
        clubId: clubId,
        createdAt: DateTime.utc(2026, 9, day),
      );
      await post('p1', 1);
      await post('p2', 2, type: PostType.announcement);
      await post('p3', 3, type: PostType.poll);
      await post('p4', 4, isHidden: true);
      await post('p5', 5, isDeleted: true);
      await post('p6', 6, clubId: 'c02');
      await post('p7', 7);
    }

    List<String> idsOf(FirestoreResult<PageResult<PostModel>> page) => [
      for (final post in page.dataOrNull!.items) post.id,
    ];

    test('listFeed: yalnızca bu kulübün silinmemiş ve gizlenmemiş '
        'gönderileri, en yeni üstte, sayfalı', () async {
      await seedFeed();

      final first = await repository.listFeed(
        _clubId,
        const PageRequest(limit: 2),
      );
      final second = await repository.listFeed(
        _clubId,
        PageRequest(limit: 3, after: first.dataOrNull!.next),
      );

      expect(idsOf(first), ['p7', 'p3']);
      expect(first.dataOrNull!.hasMore, isTrue);
      expect(idsOf(second), ['p2', 'p1']);
      expect(second.dataOrNull!.hasMore, isFalse);
    });

    test('listFeed: tür süzgeci istemcidedir — sayfa eksik dönebilir, '
        'imleç süzülmemiş sayfayı izler', () async {
      await seedFeed();

      final first = await repository.listFeed(
        _clubId,
        const PageRequest(limit: 2),
        type: PostType.post,
      );
      final second = await repository.listFeed(
        _clubId,
        PageRequest(limit: 2, after: first.dataOrNull!.next),
        type: PostType.post,
      );

      expect(idsOf(first), ['p7']);
      expect(first.dataOrNull!.hasMore, isTrue);
      expect(idsOf(second), ['p1']);
    });

    test('listForManagement: gizlenmişler dahil, silinmişler hariç', () async {
      await seedFeed();

      final page = await repository.listForManagement(
        _clubId,
        const PageRequest(),
      );

      expect(idsOf(page), ['p7', 'p4', 'p3', 'p2', 'p1']);
    });

    test('getPost: gönderi döner (gizlenmiş dahil); silinmiş ve olmayan '
        'notFound', () async {
      await seedFeed();

      final found = await repository.getPost('p3');
      final hidden = await repository.getPost('p4');

      expect(found.dataOrNull!.id, 'p3');
      expect(found.dataOrNull!.poll!.options, hasLength(2));
      expect(hidden.dataOrNull!.isHidden, isTrue);
      expect(
        (await repository.getPost('p5')).errorOrNull,
        FirestoreError.notFound,
      );
      expect(
        (await repository.getPost('p_yok')).errorOrNull,
        FirestoreError.notFound,
      );
    });

    test('watchPost: canlı gönderi; kaldırılınca ve belge yokken olay '
        'null', () async {
      await seedPost();
      final events = <FirestoreResult<PostModel?>>[];
      final subscription = repository.watchPost(_postId).listen(events.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await repository.like(_postId, uid: _member);
      await pumpEventQueue();
      await repository.softDeletePost(
        _postId,
        actorId: _author,
        clubId: _clubId,
      );
      await pumpEventQueue();

      expect(events.first.dataOrNull!.likeCount, 0);
      expect(events[1].dataOrNull!.likedBy(_member), isTrue);
      expect(events.last.isSuccess, isTrue);
      expect(events.last.dataOrNull, isNull);
      final missing = await repository.watchPost('p_yok').first;
      expect(missing.isSuccess, isTrue);
      expect(missing.dataOrNull, isNull);
    });
  });

  group('T-19 · geçersiz kimlik, ayrıştırma ve hata eşlemesi', () {
    test('geçersiz kimlik invalidArgument döner, hiçbir çağrı yapılmaz '
        '(W-54)', () async {
      const patch = PostEditPatch(text: _text);
      for (final id in _invalidIds) {
        final results = <FirestoreResult<Object?>>[
          await create(_postDraft, postId: id),
          await create(_postDraft, clubId: id),
          await create(_announcement(), authorId: id),
          await repository.update(id, patch, authorId: _author),
          await repository.update(_postId, patch, authorId: id),
          await repository.softDeletePost(
            id,
            actorId: _author,
            clubId: _clubId,
          ),
          await repository.softDeletePost(
            _postId,
            actorId: id,
            clubId: _clubId,
          ),
          await repository.softDeletePost(
            _postId,
            actorId: _author,
            clubId: id,
          ),
          await repository.restorePost(id),
          await repository.pin(id, clubId: _clubId),
          await repository.pin(_postId, clubId: id),
          await repository.unpin(id, clubId: _clubId),
          await repository.unpin(_postId, clubId: id),
          await repository.like(id, uid: _member),
          await repository.like(_postId, uid: id),
          await repository.unlike(id, uid: _member),
          await repository.unlike(_postId, uid: id),
          await repository.vote(id, uid: _member, optionId: 'o1'),
          await repository.vote(_postId, uid: id, optionId: 'o1'),
          await repository.myVote(id, uid: _member),
          await repository.myVote(_postId, uid: id),
          await repository.countVotes(id, ['o1']),
          await repository.listFeed(id, const PageRequest()),
          await repository.listForManagement(id, const PageRequest()),
          await repository.getPost(id),
          await repository.watchPost(id).single,
          await repository.hide(id, actorId: 'u_super'),
          await repository.hide(_postId, actorId: id),
          await repository.unhide(id),
        ];
        for (final result in results) {
          expect(
            result.errorOrNull,
            FirestoreError.invalidArgument,
            reason: 'kimlik "$id"',
          );
        }
      }
      expect(service.transactions, 0);
      expect(service.outsideWrites, 0);
    });

    test('ayrıştırılamayan gönderi belgesi parse (okuma ve geçiş)', () async {
      await seedClub();
      await db.doc(_postPath).set({
        'clubId': _clubId,
        'authorId': _author,
        'text': _text,
        'type': 'bilinmeyen',
        'isDeleted': false,
        'isHidden': false,
        'createdAt': Timestamp.fromDate(_createdAt),
      });

      final results = <FirestoreResult<Object?>>[
        await repository.getPost(_postId),
        await repository.listFeed(_clubId, const PageRequest()),
        await repository.listForManagement(_clubId, const PageRequest()),
        await repository.watchPost(_postId).first,
        await repository.pin(_postId, clubId: _clubId),
        await repository.unpin(_postId, clubId: _clubId),
        await repository.softDeletePost(
          _postId,
          actorId: _author,
          clubId: _clubId,
        ),
      ];

      for (final result in results) {
        expect(result.errorOrNull, FirestoreError.parse);
      }
      expect(service.writes, isEmpty);
    });

    test(
      'SDK hatası sözlüğe çevrilir (yetkisiz çağrı permissionDenied)',
      () async {
        final denied = failing('permission-denied');

        final results = <FirestoreResult<Object?>>[
          await denied.create(
            _postDraft,
            authorId: _author,
            clubId: _clubId,
            postId: _postId,
          ),
          await denied.create(
            _announcement(),
            authorId: _author,
            clubId: _clubId,
            postId: _postId,
          ),
          await denied.update(
            _postId,
            const PostEditPatch(text: _text),
            authorId: _author,
          ),
          await denied.softDeletePost(
            _postId,
            actorId: _author,
            clubId: _clubId,
          ),
          await denied.restorePost(_postId),
          await denied.pin(_postId, clubId: _clubId),
          await denied.unpin(_postId, clubId: _clubId),
          await denied.vote(_postId, uid: _member, optionId: 'o1'),
          await denied.myVote(_postId, uid: _member),
          await denied.countVotes(_postId, ['o1', 'o2']),
          await denied.getPost(_postId),
          await denied.hide(_postId, actorId: 'u_super'),
          await denied.unhide(_postId),
        ];

        for (final result in results) {
          expect(result.errorOrNull, FirestoreError.permissionDenied);
        }
      },
    );
  });
}
