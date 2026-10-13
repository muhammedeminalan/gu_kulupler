// FED-01 · ClubFeedState: türetilen görünür liste (sabit üstte, süzgeç,
// engellenenler), yardımcılar, eşitlik ve copyWith (her alan) — PLAN §12.6.
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/clubs/provider/club_feed_state.dart';

import '../club_feed_test_support.dart';

void main() {
  group('FED-01 · ClubFeedState', () {
    test('varsayılan: boş akış, süzgeç "Tümü", bayraklar kapalı', () {
      const state = ClubFeedState();
      expect(state.posts, isEmpty);
      expect(state.pinned, isNull);
      expect(state.filter, FeedFilter.all);
      expect(state.visible, isEmpty);
      expect(state.hasMore, isFalse);
      expect(
        [
          state.isFetching,
          state.isLoadingMore,
          state.isRefreshing,
          state.isError,
        ],
        everyElement(isFalse),
      );
    });

    test('visible: sabit gönderi en üstte, bir kez; kalanlar en yeniden '
        'eskiye', () {
      final state = loadedFeedState();
      expect(state.visible.map((post) => post.id), kFeedOrder);
      expect(state.visible.first.pinned, isTrue);
      expect(state.visible, hasLength(kFeedPosts.length));
    });

    test('visible: sabit gönderi okunan sayfalarda yoksa da en üstte', () {
      final others = [
        for (final post in kFeedPosts)
          if (post.id != kPinnedPost.id) post,
      ];
      final state = loadedFeedState().copyWith(posts: others);
      expect(state.visible.map((post) => post.id), kFeedOrder);
      expect(state.postById(kPinnedPost.id), kPinnedPost);
    });

    test('süzgeçler: duyurular, anketler, görseller (sabit gönderi dahil)', () {
      List<String> idsOf(FeedFilter filter) => [
        for (final post in loadedFeedState().copyWith(filter: filter).visible)
          post.id,
      ];
      expect(idsOf(FeedFilter.announcements), [kPinnedPost.id]);
      expect(idsOf(FeedFilter.polls), [kPollPost.id]);
      expect(idsOf(FeedFilter.images), [
        for (final id in kFeedOrder)
          if (kFeedPosts.firstWhere((p) => p.id == id).images.isNotEmpty) id,
      ]);
      expect(idsOf(FeedFilter.images), hasLength(2));
      expect(idsOf(FeedFilter.all), kFeedOrder);
    });

    test('engellenen yazarın gönderileri (sabit dahil) çizilmez', () {
      final blocked = kImagePost.authorId;
      final state = loadedFeedState().copyWith(blockedUserIds: {blocked});
      expect(state.visible.any((post) => post.authorId == blocked), isFalse);
      expect(state.visible, isNotEmpty);

      final pinnedBlocked = loadedFeedState().copyWith(
        blockedUserIds: {kPinnedPost.authorId},
      );
      expect(pinnedBlocked.visible.first.id, isNot(kPinnedPost.id));
    });

    test('authorName: güncel belge; belgesi olmayan yazar null', () {
      final state = loadedFeedState();
      expect(
        state.authorName(kPinnedPost.authorId),
        kFeedAuthors[kPinnedPost.authorId]!.name,
      );
      expect(state.authorName('u_yok'), isNull);
      expect(state.postById('p_yok'), isNull);
    });

    test(
      'eşitlik ve copyWith: her alan ayrı ayrı değişir; clear bayrakları',
      () {
        final base = loadedFeedState();
        expect(base, loadedFeedState());
        expect(base.copyWith(), base);
        final cursor = PageCursor.fake();
        final variants = <ClubFeedState>[
          base.copyWith(posts: const []),
          base.copyWith(pinned: kImagePost),
          base.copyWith(clearPinned: true),
          base.copyWith(filter: FeedFilter.polls),
          base.copyWith(club: kMembersClub.copyWith(name: 'Başka')),
          base.copyWith(users: const {}),
          base.copyWith(roles: const {'u1': ClubRole.board}),
          base.copyWith(savedPostIds: const {'p02'}),
          base.copyWith(myVotes: const {'p04': 'o1'}),
          base.copyWith(pollResults: const {}),
          base.copyWith(blockedUserIds: const {'u1'}),
          base.copyWith(cursor: cursor),
          base.copyWith(isFetching: true),
          base.copyWith(isLoadingMore: true),
          base.copyWith(isRefreshing: true),
          base.copyWith(isError: true),
        ];
        for (final (index, variant) in variants.indexed) {
          expect(variant, isNot(base), reason: 'değişken $index');
        }
        expect(variants.toSet(), hasLength(variants.length));

        final withCursor = base.copyWith(cursor: cursor);
        expect(withCursor.hasMore, isTrue);
        expect(withCursor.copyWith(clearCursor: true).hasMore, isFalse);
        expect(base.copyWith(clearPinned: true).pinned, isNull);
        expect(
          base.copyWith(pinned: kImagePost, clearPinned: true).pinned,
          isNull,
        );
      },
    );
  });
}
