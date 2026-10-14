// PRF-04 · SavedViewModel: açılış (listSaved → getPost → kulüp adları),
// kaldırılmış gönderi satırı (silinmiş / gizlenmiş / görünmeyen), sayfalama
// (20 + imleç), kaydı kaldır (iyimser gizle → TST-11 → "Geri al"
// restoreSaved; hata → geri), hata / yenileme (PLAN §12.6).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/profile/provider/saved_state.dart';
import 'package:gu_kulupler/features/profile/provider/saved_view_model.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';

import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_post_repository.dart';
import '../../../fakes/fake_saved_post_repository.dart';
import '../../../fakes/fake_session_states.dart';
import '../../../fakes/register_fakes.dart';
import '../../../fixtures/club_model_fixtures.dart';
import '../../../helpers/test_container.dart';
import '../saved_test_support.dart';

void main() {
  late FakePostRepository posts;
  late FakeSavedPostRepository saved;
  late FakeFeedbackService feedback;

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    posts = GetIt.I<PostRepository>() as FakePostRepository;
    saved = GetIt.I<SavedPostRepository>() as FakeSavedPostRepository;
    feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
  });

  Future<ProviderContainer> loaded() async {
    final container = createContainer(
      overrides: [
        sessionViewModelProvider.overrideWithBuild(
          (ref, notifier) => FakeSessionStates.active,
        ),
      ],
    );
    addTearDown(container.listen(savedViewModelProvider, (_, _) {}).close);
    await pumpEventQueue();
    return container;
  }

  SavedState stateOf(ProviderContainer c) => c.read(savedViewModelProvider);

  SavedViewModel vmOf(ProviderContainer c) =>
      c.read(savedViewModelProvider.notifier);

  List<String> idsOf(ProviderContainer c) => [
    for (final (record, _) in stateOf(c).visible) record.postId,
  ];

  group('PRF-04 · açılış', () {
    test('kayıtlar (en yeni üstte) + gönderiler + kulüp adları', () async {
      seedSaved();
      final c = await loaded();
      final state = stateOf(c);
      expect(state.isFetching, isFalse);
      expect(idsOf(c), ['p01', 'p21']);
      expect(state.items.first.$2, kSavedP01);
      expect(state.clubNames['c01'], ClubModelFixtures.byId('c01').name);
      expect(state.hasMore, isFalse);
    });

    test(
      'silinmiş, gizlenmiş ve görünmeyen gönderi "kaldırıldı" satırı',
      () async {
        final hidden = kSavedP21.copyWith(isHidden: true);
        final gone = kSavedP01.copyWith(id: 'p99');
        seedSaved(
          posts: [kSavedP01.copyWith(isDeleted: true), hidden],
          records: [
            kSavedRecordP01,
            kSavedRecordP21,
            savedOf(gone, DateTime.utc(2026, 10, 2)),
          ],
        );
        final c = await loaded();
        final entries = stateOf(c).visible;
        expect(entries, hasLength(3));
        expect(entries[0].$2, isNull); // silinmiş → notFound
        expect(SavedState.isRemoved(entries[1].$2), isTrue); // gizli
        expect(entries[2].$2, isNull); // görünmeyen → permissionDenied
      },
    );

    test('kayıtlar okunamazsa hata; "Yeniden dene" okur', () async {
      seedSaved();
      saved.failNext(FirestoreError.unavailable);
      final c = await loaded();
      expect(stateOf(c).isError, isTrue);
      await vmOf(c).fetch();
      expect(stateOf(c).isError, isFalse);
      expect(idsOf(c), hasLength(2));
    });

    test('gönderide bağlantı hatası sayfayı düşürür', () async {
      seedSaved();
      posts.failNext(FirestoreError.unavailable);
      final c = await loaded();
      expect(stateOf(c).isError, isTrue);
    });

    test('20 + imleç: loadMore sonraki sayfayı ekler', () async {
      final batch = savedBatch(25);
      seedSaved(posts: batch.posts, records: batch.records);
      final c = await loaded();
      expect(stateOf(c).items, hasLength(20));
      expect(stateOf(c).hasMore, isTrue);
      await vmOf(c).loadMore();
      expect(stateOf(c).items, hasLength(25));
      expect(stateOf(c).hasMore, isFalse);
      expect(idsOf(c).last, 's24');
    });
  });

  group('PRF-04 · kaydı kaldır', () {
    test('iyimser gizle → TST-11 → "Geri al" geri yükler', () async {
      seedSaved();
      final c = await loaded();
      await vmOf(c).unsave('p01');
      expect(idsOf(c), ['p21']);
      expect(feedback.toasts, [ToastId.tst11]);
      expect(feedback.toastParams.single.saved, isFalse);
      expect(
        saved.saved.values.firstWhere((r) => r.postId == 'p01').isDeleted,
        isTrue,
      );
      expect(feedback.hasToastAction, isTrue);
      feedback.tapToastAction();
      await pumpEventQueue();
      expect(idsOf(c), ['p01', 'p21']);
      expect(saved.callsTo('restoreSaved'), hasLength(1));
      expect(
        saved.saved.values.firstWhere((r) => r.postId == 'p01').isDeleted,
        isFalse,
      );
    });

    test('yazım reddedilirse satır geri gelir + TST-24', () async {
      seedSaved();
      final c = await loaded();
      saved.failNext(FirestoreError.unavailable);
      await vmOf(c).unsave('p21');
      expect(idsOf(c), ['p01', 'p21']);
      expect(feedback.toasts, [ToastId.tst24]);
    });

    test('kaldırılmış gönderinin kaydı da kaldırılır', () async {
      seedSaved(posts: [kSavedP21]);
      final c = await loaded();
      expect(stateOf(c).items.first.$2, isNull);
      await vmOf(c).unsave('p01');
      expect(idsOf(c), ['p21']);
      expect(feedback.toasts, [ToastId.tst11]);
    });
  });
}
