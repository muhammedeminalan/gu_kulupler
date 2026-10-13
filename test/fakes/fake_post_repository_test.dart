// T-19 · FakePostRepository sözleşmesi (PLAN §16.3): `posts`, `likesByPost`,
// `votes`, `pinnedByClub`, `watchPostController(postId)`, `newPostIdQueue`;
// gerçek repository + Security Rules sonuçlarını izler
// (docs/plans/T-19.md §6). Kuraldan bağımsız sonuçlar son grupta gerçek
// `FirebasePostRepository` ile aynı komut dizisi üzerinde karşılaştırılır.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';

import '../fixtures/post_model_fixtures.dart';
import '../helpers/fake_app_clock.dart';
import 'fake_post_repository.dart';
import 'register_fakes.dart';

const String _club = 'c01';
const String _author = 'u_p_c01';
const String _me = 'u_mehmet';
final DateTime _now = DateTime.utc(2026, 10, 13, 9);

const PostDraft _plain = PostDraft(type: PostType.post, text: 'Merhaba kulüp.');
const PostDraft _pushed = PostDraft(
  type: PostType.announcement,
  title: 'Genel kurul',
  text: 'Cuma 14.00.',
  pushSent: true,
);
const PostDraft _poll = PostDraft(
  type: PostType.poll,
  text: 'Hangi gün?',
  poll: PollDraft(options: ['Cuma', 'Cumartesi'], durationDays: 3),
);

PostImageModel _image(String postId) => PostImageModel(
  path: 'posts/$postId/20261008T201502Z_0a1b2c3d4e5f6071.jpg',
  w: 1200,
  h: 800,
);

void main() {
  late FakeAppClock clock;
  late FakePostRepository fake;

  setUp(() {
    clock = FakeAppClock(_now);
    fake = FakePostRepository(clock);
  });

  Future<FirestoreResult<PostModel>> publish(
    String postId, [
    PostDraft draft = _plain,
  ]) => fake.create(draft, authorId: _author, clubId: _club, postId: postId);

  group('T-19 · FakePostRepository', () {
    test('PostRepository arayüzünü uygular; registerDefaultFakes kayıtlı '
        'duyuru sayacıyla paylaşımlı kaydeder: günde iki bildirimli duyuru, '
        'üçüncüsü announcementLimit (yazım yok)', () async {
      addTearDown(GetIt.I.reset);
      registerDefaultFakes();
      final posts = GetIt.I<PostRepository>();
      final counters = GetIt.I<AnnouncementCounterRepository>();
      expect((posts as FakePostRepository).counterRepository, same(counters));

      for (final id in ['a1', 'a2']) {
        final published = await posts.create(
          _pushed,
          authorId: _author,
          clubId: _club,
          postId: id,
        );
        expect(published.dataOrNull?.pushSent, isTrue);
      }
      final third = await posts.create(
        _pushed,
        authorId: _author,
        clubId: _club,
        postId: 'a3',
      );

      expect(third.errorOrNull, FirestoreError.ruleViolation);
      expect(
        (third as FirebaseFailure).detail,
        const FirestoreFailureDetail(FirestoreRuleCode.announcementLimit),
      );
      expect(posts.posts.keys, ['a1', 'a2']);
      expect((await counters.remainingToday(_club)).dataOrNull, 0);
      // Bildirimsiz duyuru ve başka kulüp hak harcamaz.
      final quiet = await posts.create(
        const PostDraft(
          type: PostType.announcement,
          title: 'Sessiz',
          text: 'Bildirimsiz.',
        ),
        authorId: _author,
        clubId: _club,
        postId: 'a4',
      );
      expect(quiet.dataOrNull?.pushSent, isFalse);
      expect((await counters.remainingToday('c02')).dataOrNull, 2);
    });

    test('create: sayaçlar sıfır başlar, anket seçenekleri o1…oN kimliği '
        've saat + süre bitişi alır; newPostId kuyruğu önce tüketir', () async {
      fake.newPostIdQueue.addAll(['p_a', 'p_b']);
      expect([fake.newPostId(), fake.newPostId()], ['p_a', 'p_b']);
      expect(fake.newPostId(), 'p_fake_1');

      final post = (await publish('p_a')).dataOrNull!;
      final poll = (await publish('p_b', _poll)).dataOrNull!;

      expect(
        (post.likeCount, post.commentCount, post.pinned, post.isHidden),
        (0, 0, false, false),
      );
      expect(
        (post.authorId, post.clubId, post.createdAt),
        (_author, _club, _now),
      );
      expect(poll.poll!.options.map((option) => option.id), ['o1', 'o2']);
      expect(poll.poll!.endsAt, _now.add(const Duration(days: 3)));
      // Var olan kimliğe ikinci yayın kurallarda güncellemedir.
      expect(
        (await publish('p_a')).errorOrNull,
        FirestoreError.permissionDenied,
      );
    });

    test('beğeni: likeCount likes ile birlikte tam ±1 oynar; çift beğeni, '
        'beğenmeden geri alma, gizli / silinmiş / olmayan gönderi '
        'permissionDenied (değişiklik yok)', () async {
      await publish('p1');

      expect((await fake.like('p1', uid: _me)).isSuccess, isTrue);
      expect((await fake.like('p1', uid: 'u2')).isSuccess, isTrue);
      expect(fake.likesByPost['p1'], [_me, 'u2']);
      expect(fake.posts['p1']!.likeCount, 2);

      expect(
        (await fake.like('p1', uid: _me)).errorOrNull,
        FirestoreError.permissionDenied,
      );
      expect((await fake.unlike('p1', uid: _me)).isSuccess, isTrue);
      expect(
        (await fake.unlike('p1', uid: _me)).errorOrNull,
        FirestoreError.permissionDenied,
      );
      expect(fake.likesByPost['p1'], ['u2']);
      expect(fake.posts['p1']!.likeCount, 1);

      await fake.hide('p1', actorId: 'u_admin');
      expect(
        (await fake.like('p1', uid: _me)).errorOrNull,
        FirestoreError.permissionDenied,
      );
      expect(
        (await fake.like('p_yok', uid: _me)).errorOrNull,
        FirestoreError.permissionDenied,
      );
      expect(fake.posts['p1']!.likeCount, 1);
    });

    test('oy: bir kullanıcı bir oy (ikincisi alreadyExists); olmayan '
        'seçenek, anket olmayan gönderi ve kapanmış anket permissionDenied; '
        'countVotes seçenek başına sayar', () async {
      await publish('pl', _poll);
      await publish('p1');

      expect((await fake.myVote('pl', uid: _me)).dataOrNull, isNull);
      expect(
        (await fake.vote('pl', uid: _me, optionId: 'o2')).isSuccess,
        isTrue,
      );
      expect(
        (await fake.vote('pl', uid: _me, optionId: 'o1')).errorOrNull,
        FirestoreError.alreadyExists,
      );
      expect(
        (await fake.vote('pl', uid: 'u2', optionId: 'o3')).errorOrNull,
        FirestoreError.permissionDenied,
      );
      expect(
        (await fake.vote('p1', uid: 'u2', optionId: 'o1')).errorOrNull,
        FirestoreError.permissionDenied,
      );
      await fake.vote('pl', uid: 'u2', optionId: 'o2');
      expect(fake.votes['pl'], {_me: 'o2', 'u2': 'o2'});
      expect((await fake.myVote('pl', uid: _me)).dataOrNull, 'o2');
      expect((await fake.countVotes('pl', ['o1', 'o2', 'o2'])).dataOrNull, {
        'o1': 0,
        'o2': 2,
      });

      // Bitiş anı kapalı sayılır.
      clock.set(_now.add(const Duration(days: 3)));
      expect(
        (await fake.vote('pl', uid: 'u3', optionId: 'o1')).errorOrNull,
        FirestoreError.permissionDenied,
      );
    });

    test('sabitleme: kulüpte en çok bir sabit gönderi; sabit gönderi '
        'silinince işaretçi kalkar, geri yükleme yeniden sabitlemez', () async {
      await publish('p1');
      await publish('p2');

      await fake.pin('p1', clubId: _club);
      await fake.pin('p2', clubId: _club);

      expect(fake.pinnedByClub, {_club: 'p2'});
      expect(
        (fake.posts['p1']!.pinned, fake.posts['p2']!.pinned),
        (false, true),
      );

      await fake.softDeletePost('p2', actorId: _author, clubId: _club);
      final removed = fake.posts['p2']!;
      expect(
        (removed.isDeleted, removed.deletedBy, removed.pinned),
        (true, _author, false),
      );
      expect(fake.pinnedByClub, isEmpty);
      // Silinmiş gönderi: notFound; başka kulüp: invalidArgument; olmayan
      // gönderi okunamaz.
      expect(
        (await fake.pin('p2', clubId: _club)).errorOrNull,
        FirestoreError.notFound,
      );
      expect(
        (await fake.softDeletePost(
          'p2',
          actorId: _author,
          clubId: _club,
        )).errorOrNull,
        FirestoreError.notFound,
      );
      expect(
        (await fake.unpin('p1', clubId: 'c02')).errorOrNull,
        FirestoreError.invalidArgument,
      );
      expect(
        (await fake.pin('p_yok', clubId: _club)).errorOrNull,
        FirestoreError.permissionDenied,
      );

      await fake.restorePost('p2');
      expect(
        (fake.posts['p2']!.isDeleted, fake.posts['p2']!.pinned),
        (false, false),
      );
      expect(
        (await fake.restorePost('p2')).errorOrNull,
        FirestoreError.permissionDenied,
      );

      await fake.pin('p1', clubId: _club);
      await fake.unpin('p1', clubId: _club);
      expect(fake.pinnedByClub, isEmpty);
      expect(fake.posts['p1']!.pinned, isFalse);
    });

    test('listeler: akış silinmiş ve gizli gönderiyi içermez, yönetim '
        'listesi gizliyi içerir; en yeni üstte; tür süzgeci sayfadan sonra '
        'uygulanır', () async {
      PostModelFixtures.ofClub(_club).forEach(fake.put);
      fake.put(PostModelFixtures.byId('p08'));
      final total = PostModelFixtures.ofClub(_club).length;
      await fake.hide('p02', actorId: 'u_admin');
      await fake.softDeletePost('p03', actorId: _author, clubId: _club);

      final feed = (await fake.listFeed(
        _club,
        const PageRequest(),
      )).dataOrNull!;
      final managed = (await fake.listForManagement(
        _club,
        const PageRequest(),
      )).dataOrNull!;

      expect(feed.items, hasLength(total - 2));
      expect(managed.items, hasLength(total - 1));
      expect(managed.items.map((post) => post.id), contains('p02'));
      expect(feed.items.every((post) => post.clubId == _club), isTrue);
      for (var i = 1; i < feed.items.length; i++) {
        expect(
          feed.items[i - 1].createdAt!.isBefore(feed.items[i].createdAt!),
          isFalse,
        );
      }
      // Sabit gönderi fixture'ı `put` ile işaretçiyi de kurar.
      expect(fake.pinnedByClub[_club], 'p01');

      final firstTwo = (await fake.listFeed(
        _club,
        const PageRequest(limit: 2),
        type: PostType.poll,
      )).dataOrNull!;
      expect(firstTwo.next, isNotNull);
      expect(firstTwo.items.every((post) => post.isPoll), isTrue);
      final rest = (await fake.listFeed(
        _club,
        PageRequest(after: firstTwo.next),
      )).dataOrNull!;
      expect(rest.items, hasLength(total - 4));
    });

    test('watchPost: ilk anlık görüntü, her değişiklikte yeniden yayar; '
        'silinen gönderi null, olmayan gönderi permissionDenied; dinleyici '
        'kapanınca activeListeners sıfırlanır', () async {
      await publish('p1');
      final events = <FirestoreResult<PostModel?>>[];
      final subscription = fake.watchPost('p1').listen(events.add);
      await pumpEventQueue();

      expect(fake.activeListeners, 1);
      expect(events.single.dataOrNull?.likeCount, 0);

      await fake.like('p1', uid: _me);
      await pumpEventQueue();
      expect(events.last.dataOrNull?.likeCount, 1);

      fake.bumpComments('p1', 1, 'cm9');
      await pumpEventQueue();
      expect(
        (
          events.last.dataOrNull?.commentCount,
          events.last.dataOrNull?.lastCommentRef,
        ),
        (1, 'comments/cm9'),
      );

      fake
          .watchPostController('p1')
          .add(const FirebaseFailure(FirestoreError.unavailable));
      await pumpEventQueue();
      expect(events.last.errorOrNull, FirestoreError.unavailable);

      await fake.softDeletePost('p1', actorId: _author, clubId: _club);
      await pumpEventQueue();
      expect(events.last.isSuccess, isTrue);
      expect(events.last.dataOrNull, isNull);
      expect((await fake.getPost('p1')).errorOrNull, FirestoreError.notFound);

      await subscription.cancel();
      expect(fake.activeListeners, 0);
      expect(
        (await fake.watchPost('p_yok').first).errorOrNull,
        FirestoreError.permissionDenied,
      );
      expect(
        (await fake.getPost('p_yok')).errorOrNull,
        FirestoreError.permissionDenied,
      );
    });

    test('düzenleme yalnızca yazarındır; gizle / göster çift çağrıda '
        'reddedilir; failNext ve geçersiz kimlik yazım yapmaz', () async {
      await publish('p1');

      final edited = await fake.update(
        'p1',
        PostEditPatch(text: 'Yeni metin.', images: [_image('p1')]),
        authorId: _author,
      );
      expect(edited.isSuccess, isTrue);
      final post = fake.posts['p1']!;
      expect(
        (post.text, post.images.length, post.editedAt),
        ('Yeni metin.', 1, _now),
      );
      expect(
        (await fake.update(
          'p1',
          const PostEditPatch(text: 'Başkası'),
          authorId: _me,
        )).errorOrNull,
        FirestoreError.permissionDenied,
      );
      // Başlık yalnızca duyuruda bulunur (türü kural denetler).
      expect(
        (await fake.update(
          'p1',
          const PostEditPatch(title: 'Başlık'),
          authorId: _author,
        )).errorOrNull,
        FirestoreError.permissionDenied,
      );

      expect((await fake.hide('p1', actorId: 'u_admin')).isSuccess, isTrue);
      expect(
        (fake.posts['p1']!.isHidden, fake.posts['p1']!.hiddenBy),
        (true, 'u_admin'),
      );
      expect(
        (await fake.hide('p1', actorId: 'u_admin')).errorOrNull,
        FirestoreError.permissionDenied,
      );
      expect((await fake.unhide('p1')).isSuccess, isTrue);
      expect(fake.posts['p1']!.hiddenBy, isNull);
      expect(
        (await fake.unhide('p1')).errorOrNull,
        FirestoreError.permissionDenied,
      );

      fake.failNext(FirestoreError.unavailable);
      expect((await publish('p2')).errorOrNull, FirestoreError.unavailable);
      expect(
        (await fake.like('', uid: _me)).errorOrNull,
        FirestoreError.invalidArgument,
      );
      expect(fake.posts.keys, ['p1']);
      expect(fake.callsTo('create'), hasLength(2));
    });

    test(
      'anket sorusu yayından sonra değişmez (oylar başka soruya '
      'taşınamaz — CD-141 madde 11); soru aynı kalan düzenleme geçer',
      () async {
        await publish('pl', _poll);

        final changed = await fake.update(
          'pl',
          const PostEditPatch(text: 'Bütçe başkana devredilsin mi?'),
          authorId: _author,
        );
        expect(changed.errorOrNull, FirestoreError.permissionDenied);
        expect(fake.posts['pl']!.text, _poll.text);
        expect(fake.posts['pl']!.editedAt, isNull);

        final same = await fake.update(
          'pl',
          PostEditPatch(text: _poll.text, images: [_image('pl')]),
          authorId: _author,
        );
        expect(same.isSuccess, isTrue);
        expect(fake.posts['pl']!.images, hasLength(1));
      },
    );
  });

  group('T-19 · FakePostRepository ↔ FirebasePostRepository', () {
    /// Kuraldan bağımsız komut dizisi: doğrulama, hak sınırı, oy, sabitleme,
    /// silme / geri yükleme, beğeni, düzenleme, gizleme.
    Future<List<Object?>> script(PostRepository posts) async {
      Future<FirestoreResult<Object?>> create(String id, PostDraft draft) =>
          posts.create(draft, authorId: _author, clubId: _club, postId: id);
      final results = <FirestoreResult<Object?>>[
        await create('x1', const PostDraft(type: PostType.post, text: '  ')),
        await create(
          'x2',
          const PostDraft(type: PostType.post, text: 'a', title: 'Başlık'),
        ),
        await create(
          'x3',
          const PostDraft(type: PostType.announcement, text: 'Başlıksız'),
        ),
        await create(
          'x4',
          const PostDraft(
            type: PostType.poll,
            text: 'Tek seçenek',
            poll: PollDraft(options: ['Evet'], durationDays: 3),
          ),
        ),
        await create(
          'x5',
          const PostDraft(
            type: PostType.poll,
            text: 'Geçersiz süre',
            poll: PollDraft(options: ['Evet', 'Hayır'], durationDays: 2),
          ),
        ),
        await create('x6', const PostDraft(type: PostType.poll, text: 'Yok')),
        await create(
          'x7',
          PostDraft(
            type: PostType.post,
            text: 'a',
            images: [_image('p_other')],
          ),
        ),
        await create(
          'x8',
          PostDraft(
            type: PostType.post,
            text: 'a',
            images: [for (var i = 0; i < 5; i++) _image('x8')],
          ),
        ),
        await create('a1', _pushed),
        await create('a2', _pushed),
        await create('a3', _pushed),
        await create('pl', _poll),
        await create(
          'p1',
          PostDraft(type: PostType.post, text: 'a', images: [_image('p1')]),
        ),
        await posts.vote('pl', uid: _me, optionId: 'o1'),
        await posts.vote('pl', uid: _me, optionId: 'o2'),
        await posts.countVotes('pl', ['o1', 'o2']),
        await posts.countVotes('pl', ['o1', 'o2', 'o3', 'o4', 'o5']),
        await posts.myVote('pl', uid: _me),
        await posts.pin('a1', clubId: _club),
        await posts.pin('a2', clubId: _club),
        await posts.pin('a2', clubId: _club),
        await posts.softDeletePost('a2', actorId: _author, clubId: _club),
        await posts.softDeletePost('a2', actorId: _author, clubId: _club),
        await posts.pin('a2', clubId: _club),
        await posts.unpin('a2', clubId: _club),
        await posts.getPost('a2'),
        await posts.unpin('a1', clubId: 'c02'),
        await posts.softDeletePost('a1', actorId: _author, clubId: 'c02'),
        await posts.restorePost('a2'),
        await posts.pin('p1', clubId: _club),
        await posts.unpin('p1', clubId: _club),
        await posts.unpin('p1', clubId: _club),
        await posts.like('p1', uid: _me),
        await posts.like('p1', uid: 'u2'),
        await posts.unlike('p1', uid: _me),
        await posts.update('p1', const PostEditPatch(), authorId: _author),
        await posts.update(
          'p1',
          const PostEditPatch(text: 'Düzenlendi.', images: []),
          authorId: _author,
        ),
        await posts.update(
          'a1',
          const PostEditPatch(title: 'Yeni başlık'),
          authorId: _author,
        ),
        await posts.update(
          'a1',
          PostEditPatch(title: 'a' * (Limits.postTitleMax + 1)),
          authorId: _author,
        ),
        await posts.hide('pl', actorId: 'u_admin'),
        await posts.pin('pl', clubId: _club),
        await posts.unhide('pl'),
        await posts.like('p/1', uid: _me),
      ];
      final outcomes = <Object?>[
        for (final result in results)
          switch (result) {
            FirebaseSuccess(:final data) =>
              data is PostModel ? 'ok ${data.id}' : 'ok $data',
            FirebaseFailure(:final error, :final detail) =>
              '${error.name} ${(detail as FirestoreFailureDetail?)?.code.name}',
          },
      ];
      // Son durum: her gönderinin sayaç ve bayrakları + listeler.
      for (final id in ['a1', 'a2', 'a3', 'pl', 'p1', 'x1']) {
        final post = (await posts.getPost(id)).dataOrNull;
        outcomes.add(
          post == null
              ? '$id yok'
              : '$id ${post.type.name} pinned=${post.pinned} '
                    'push=${post.pushSent} likes=${post.likes} '
                    '${post.likeCount} hidden=${post.isHidden} '
                    'text=${post.text} title=${post.title} '
                    'images=${post.images.length} '
                    'edited=${post.editedAt != null} '
                    'options=${post.poll?.options.map((o) => o.id).toList()} '
                    'endsAt=${post.poll?.endsAt}',
        );
      }
      final feed = (await posts.listFeed(
        _club,
        const PageRequest(),
      )).dataOrNull!;
      final managed = (await posts.listForManagement(
        _club,
        const PageRequest(),
      )).dataOrNull!;
      final polls = (await posts.listFeed(
        _club,
        const PageRequest(),
        type: PostType.poll,
      )).dataOrNull!;
      return outcomes..addAll([
        {for (final post in feed.items) post.id},
        {for (final post in managed.items) post.id},
        {for (final post in polls.items) post.id},
      ]);
    }

    test('aynı komut dizisi iki uygulamada aynı sonuçları ve aynı son durumu '
        'verir (sabit işaretçi ve kalan duyuru hakkı dahil)', () async {
      final db = FakeFirebaseFirestore();
      final service = FirebaseFirestoreService(db);
      final realClock = FakeAppClock(_now);
      final counters = FirebaseAnnouncementCounterRepository(
        service,
        realClock,
      );
      final real = FirebasePostRepository(
        service,
        FirebaseActivityRepository(service),
        counters,
        realClock,
      );
      // Gerçek sabitleme kulüp belgesini okur.
      for (final clubId in [_club, 'c02']) {
        await db
            .doc('clubs/$clubId')
            .set(
              ClubModel(
                name: 'Kulüp $clubId',
                nameLower: 'kulüp $clubId',
                categoryId: 'k01',
                iconName: 'cpu',
                palette: ClubPalette.red,
                pattern: ClubPattern.dots,
                founded: 2015,
                presidentId: _author,
              ).toJson(),
            );
      }

      final expected = await script(real);
      final actual = await script(fake);

      expect(actual, expected);
      // Komut dizisi boş geçmedi: hak doldu, oy değişmedi, silinen bulunamadı.
      expect(expected, contains('ruleViolation announcementLimit'));
      expect(expected, contains('alreadyExists null'));
      expect(expected, contains('notFound null'));
      expect(expected, contains('invalidArgument null'));
      expect(
        fake.pinnedByClub[_club],
        (await db.doc('clubs/$_club').get()).data()!['pinnedPostId'],
      );
      expect(
        (await fake.counterRepository.remainingToday(_club)).dataOrNull,
        (await counters.remainingToday(_club)).dataOrNull,
      );
    });
  });
}
