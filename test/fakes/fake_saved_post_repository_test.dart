// T-19 · FakeSavedPostRepository sözleşmesi (PLAN §16.3): `saved`; gerçek
// repository + Security Rules sonuçlarını izler (kaldırma = soft delete,
// D-10; docs/plans/T-19.md §6).
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';

import '../fixtures/post_model_fixtures.dart';
import '../helpers/fake_app_clock.dart';
import 'fake_post_repository.dart';
import 'fake_saved_post_repository.dart';
import 'register_fakes.dart';

const String _me = 'u_mehmet';
const String _club = 'c01';

void main() {
  late FakeAppClock clock;
  late FakePostRepository posts;
  late FakeSavedPostRepository fake;

  setUp(() {
    clock = FakeAppClock(DateTime.utc(2026, 10, 13, 9));
    posts = FakePostRepository(clock)
      ..put(PostModelFixtures.p01)
      ..put(PostModelFixtures.p02)
      ..put(PostModelFixtures.p04);
    fake = FakeSavedPostRepository(clock, posts: posts);
  });

  Future<List<String>> listed() async => [
    for (final record in (await fake.listSaved(
      _me,
      const PageRequest(),
    )).dataOrNull!.items)
      record.postId,
  ];

  group('T-19 · FakeSavedPostRepository', () {
    test('SavedPostRepository arayüzünü uygular; registerDefaultFakes '
        'kayıtlı gönderi fake’iyle paylaşımlı kaydeder', () {
      addTearDown(GetIt.I.reset);
      registerDefaultFakes();
      final registered =
          GetIt.I<SavedPostRepository>() as FakeSavedPostRepository;
      expect(registered.postRepository, same(GetIt.I<PostRepository>()));
    });

    test('save → listSaved en son kaydedilen üstte; yürürlükteki kaydın '
        'yeniden kaydedilmesi yazımsız başarıdır', () async {
      await fake.save(userId: _me, postId: 'p01', clubId: _club);
      clock.advance(const Duration(minutes: 1));
      await fake.save(userId: _me, postId: 'p02', clubId: _club);
      final savedAt = fake.saved['${_me}_p01']!.savedAt;
      clock.advance(const Duration(minutes: 1));

      final again = await fake.save(userId: _me, postId: 'p01', clubId: _club);

      expect(again.isSuccess, isTrue);
      expect(fake.saved['${_me}_p01']!.savedAt, savedAt);
      expect(await listed(), ['p02', 'p01']);
      expect(
        (await fake.isSaved(userId: _me, postId: 'p01')).dataOrNull,
        isTrue,
      );
      // Sayfalama: sayfa dolu geldiyse imleç vardır.
      final page = await fake.listSaved(_me, const PageRequest(limit: 1));
      expect(page.dataOrNull!.items.single.postId, 'p02');
      expect(page.dataOrNull!.next, isNotNull);
    });

    test(
      'kaldır → kayıt silinmez, işaretlenir; Geri al savedAt’i korur; '
      'yeniden kaydetme aynı belgeyi geri yükler ve savedAt’i yeniler',
      () async {
        await fake.save(userId: _me, postId: 'p01', clubId: _club);
        final savedAt = fake.saved['${_me}_p01']!.savedAt;
        clock.advance(const Duration(minutes: 5));

        await fake.softDeleteSaved(userId: _me, postId: 'p01');
        final removed = fake.saved['${_me}_p01']!;
        expect((removed.isDeleted, removed.deletedBy), (true, _me));
        expect(await listed(), isEmpty);
        expect(
          (await fake.isSaved(userId: _me, postId: 'p01')).dataOrNull,
          isFalse,
        );

        await fake.restoreSaved(userId: _me, postId: 'p01');
        expect(fake.saved['${_me}_p01']!.savedAt, savedAt);
        expect(fake.saved['${_me}_p01']!.deletedBy, isNull);

        await fake.softDeleteSaved(userId: _me, postId: 'p01');
        await fake.save(userId: _me, postId: 'p01', clubId: _club);
        expect(fake.saved, hasLength(1));
        expect(fake.saved['${_me}_p01']!.isDeleted, isFalse);
        expect(fake.saved['${_me}_p01']!.savedAt, clock.nowUtc());
      },
    );

    test('kuralların reddettiği yazımlar permissionDenied döner ve hiçbir '
        'şey değişmez', () async {
      posts
        ..put(PostModelFixtures.p02.copyWith(isHidden: true))
        ..put(PostModelFixtures.p04.copyWith(isDeleted: true));
      final denied = [
        // gizli, silinmiş, olmayan ve başka kulübün gönderisi kaydedilemez
        await fake.save(userId: _me, postId: 'p02', clubId: _club),
        await fake.save(userId: _me, postId: 'p04', clubId: _club),
        await fake.save(userId: _me, postId: 'p_yok', clubId: _club),
        await fake.save(userId: _me, postId: 'p01', clubId: 'c02'),
        // olmayan kayıt kaldırılamaz / geri alınamaz
        await fake.softDeleteSaved(userId: _me, postId: 'p01'),
        await fake.restoreSaved(userId: _me, postId: 'p01'),
      ];
      expect(
        denied.map((result) => result.errorOrNull),
        everyElement(FirestoreError.permissionDenied),
      );
      expect(fake.saved, isEmpty);

      await fake.save(userId: _me, postId: 'p01', clubId: _club);
      // yürürlükteki kayıt geri alınamaz; çift kaldırma reddedilir
      expect(
        (await fake.restoreSaved(userId: _me, postId: 'p01')).errorOrNull,
        FirestoreError.permissionDenied,
      );
      await fake.softDeleteSaved(userId: _me, postId: 'p01');
      expect(
        (await fake.softDeleteSaved(userId: _me, postId: 'p01')).errorOrNull,
        FirestoreError.permissionDenied,
      );
    });

    test('failNext ve geçersiz kimlik: hata döner, kayıt yazılmaz', () async {
      fake.failNext(FirestoreError.unavailable);
      expect(
        (await fake.save(
          userId: _me,
          postId: 'p01',
          clubId: _club,
        )).errorOrNull,
        FirestoreError.unavailable,
      );
      expect(
        (await fake.save(userId: '', postId: 'p01', clubId: _club)).errorOrNull,
        FirestoreError.invalidArgument,
      );
      expect(fake.saved, isEmpty);
      expect(fake.callsTo('save'), hasLength(2));
    });
  });
}
