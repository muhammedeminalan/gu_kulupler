// T-19 · FakeCommentRepository sözleşmesi (PLAN §16.3):
// `watchCommentsController(postId)`, `activeListeners`, `added`; gerçek
// repository + Security Rules sonuçlarını izler (docs/plans/T-19.md §6).
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';

import '../fixtures/comment_model_fixtures.dart';
import '../fixtures/post_model_fixtures.dart';
import '../helpers/fake_app_clock.dart';
import 'fake_comment_repository.dart';
import 'fake_post_repository.dart';
import 'register_fakes.dart';

const String _post = 'p01';
const String _club = 'c01';
const String _me = 'u_mehmet';

void main() {
  late FakeAppClock clock;
  late FakePostRepository posts;
  late FakeCommentRepository fake;

  setUp(() {
    clock = FakeAppClock(DateTime.utc(2026, 10, 13, 9));
    posts = FakePostRepository(clock)..put(PostModelFixtures.p01);
    fake = FakeCommentRepository(clock, posts: posts);
    CommentModelFixtures.ofPost(_post).forEach(fake.put);
  });

  int count() => posts.posts[_post]!.commentCount;

  group('T-19 · FakeCommentRepository', () {
    test('W-103 getComment: gizli yorum döner; silinmiş notFound, olmayan '
        'permissionDenied; geçersiz kimlik invalidArgument', () async {
      await fake.hide('cm02', actorId: 'u_admin');
      expect((await fake.getComment('cm01')).dataOrNull?.id, 'cm01');
      expect((await fake.getComment('cm02')).dataOrNull?.isHidden, isTrue);
      await fake.softDeleteComment('cm01', postId: _post, actorId: _me);
      expect(
        (await fake.getComment('cm01')).errorOrNull,
        FirestoreError.notFound,
      );
      expect(
        (await fake.getComment('cm_yok')).errorOrNull,
        FirestoreError.permissionDenied,
      );
      expect(
        (await fake.getComment('a/b')).errorOrNull,
        FirestoreError.invalidArgument,
      );
      fake.failNext(FirestoreError.unavailable);
      expect(
        (await fake.getComment('cm03')).errorOrNull,
        FirestoreError.unavailable,
      );
    });

    test('CommentRepository arayüzünü uygular; registerDefaultFakes kayıtlı '
        'gönderi fake’iyle paylaşımlı kaydeder', () {
      addTearDown(GetIt.I.reset);
      registerDefaultFakes();
      final registered = GetIt.I<CommentRepository>() as FakeCommentRepository;
      expect(registered.postRepository, same(GetIt.I<PostRepository>()));
    });

    test('add → kaldır → geri al: yorum ile commentCount ve lastCommentRef '
        'birlikte oynar; kaldırılan yorum silinmez, işaretlenir', () async {
      expect(count(), 3);

      final added = (await fake.add(
        postId: _post,
        clubId: _club,
        authorId: _me,
        text: 'Ben de katılıyorum.',
      )).dataOrNull!;

      expect(fake.added, [added]);
      expect((added.authorId, added.createdAt), (_me, clock.nowUtc()));
      expect(count(), 4);
      expect(posts.posts[_post]!.lastCommentRef, 'comments/${added.id}');

      await fake.softDeleteComment('cm01', postId: _post, actorId: _me);
      expect(count(), 3);
      expect(posts.posts[_post]!.lastCommentRef, 'comments/cm01');
      final removed = fake.comments['cm01']!;
      expect((removed.isDeleted, removed.deletedBy), (true, _me));

      await fake.restoreComment('cm01', postId: _post);
      expect(count(), 4);
      expect(fake.comments['cm01']!.deletedBy, isNull);
    });

    test('kuralların reddettiği kör yazımlar permissionDenied döner; yorum '
        'da sayaç da değişmez', () async {
      await fake.softDeleteComment('cm02', postId: _post, actorId: _me);
      posts
        ..put(PostModelFixtures.p02.copyWith(isHidden: true))
        ..put(PostModelFixtures.p04.copyWith(isDeleted: true));
      final before = (count(), fake.comments.length);

      final denied = [
        // çift kaldırma · silinmemiş yorumu geri alma · olmayan yorum
        await fake.softDeleteComment('cm02', postId: _post, actorId: _me),
        await fake.restoreComment('cm01', postId: _post),
        await fake.softDeleteComment('cm_yok', postId: _post, actorId: _me),
        // yorum başka gönderinin
        await fake.softDeleteComment('cm01', postId: 'p02', actorId: _me),
        // gizli · silinmiş · olmayan gönderiye ve yanlış kulüple yorum
        await fake.add(postId: 'p02', clubId: _club, authorId: _me, text: 'x'),
        await fake.add(postId: 'p04', clubId: _club, authorId: _me, text: 'x'),
        await fake.add(
          postId: 'p_yok',
          clubId: _club,
          authorId: _me,
          text: 'x',
        ),
        await fake.add(postId: _post, clubId: 'c02', authorId: _me, text: 'x'),
      ];

      expect(
        denied.map((result) => result.errorOrNull),
        everyElement(FirestoreError.permissionDenied),
      );
      expect((count(), fake.comments.length), before);
      expect(fake.added, isEmpty);
    });

    test('watchComments: ilk anlık görüntü eskiden yeniye, her değişiklikte '
        'yeniden yayar; gizlenen yorum listeden düşer ama sayaç değişmez; '
        'dinleyici kapanınca activeListeners sıfırlanır', () async {
      final events = <FirestoreResult<List<CommentModel>>>[];
      final subscription = fake
          .watchComments(_post, clubId: _club)
          .listen(events.add);
      await pumpEventQueue();
      List<String> last() => [
        for (final comment in events.last.dataOrNull!) comment.id,
      ];

      expect(fake.activeListeners, 1);
      expect(last(), ['cm03', 'cm02', 'cm01']);

      clock.advance(const Duration(minutes: 1));
      final added = (await fake.add(
        postId: _post,
        clubId: _club,
        authorId: _me,
        text: 'Yeni yorum.',
      )).dataOrNull!;
      await pumpEventQueue();
      expect(last(), ['cm03', 'cm02', 'cm01', added.id]);

      final hidden = await fake.hide('cm02', actorId: 'u_admin');
      await pumpEventQueue();
      expect(hidden.isSuccess, isTrue);
      expect(last(), ['cm03', 'cm01', added.id]);
      expect(count(), 4);
      expect(
        (await fake.hide('cm02', actorId: 'u_admin')).errorOrNull,
        FirestoreError.permissionDenied,
      );

      // Test elle olay (hata dahil) yazabilir.
      fake
          .watchCommentsController(_post)
          .add(const FirebaseFailure(FirestoreError.unavailable));
      await pumpEventQueue();
      expect(events.last.errorOrNull, FirestoreError.unavailable);

      await subscription.cancel();
      expect(fake.activeListeners, 0);
    });

    test('failNext ve geçersiz girdi: hata döner, yorum yazılmaz', () async {
      fake.failNext(FirestoreError.unavailable);
      final failed = await fake.add(
        postId: _post,
        clubId: _club,
        authorId: _me,
        text: 'Merhaba',
      );
      final empty = await fake.add(
        postId: _post,
        clubId: _club,
        authorId: _me,
        text: '   ',
      );
      final long = await fake.add(
        postId: _post,
        clubId: _club,
        authorId: _me,
        text: 'a' * (Limits.commentMax + 1),
      );

      expect(failed.errorOrNull, FirestoreError.unavailable);
      expect(empty.errorOrNull, FirestoreError.invalidArgument);
      expect(long.errorOrNull, FirestoreError.invalidArgument);
      expect(
        (await fake.watchComments('', clubId: _club).first).errorOrNull,
        FirestoreError.invalidArgument,
      );
      expect(count(), 3);
      expect(fake.added, isEmpty);
    });
  });
}
