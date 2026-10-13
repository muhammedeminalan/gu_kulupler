// FED-02 · PostDetailState: varsayılanlar, `copyWith` (tüm alanlar + oy
// temizleme bayrağı), değer eşitliği, türetilmişler (görünen yorumlar, gönder
// düğmesi, silinmiş yazar).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/feed/provider/post_detail_state.dart';

import '../post_detail_test_support.dart';

void main() {
  group('FED-02 · PostDetailState', () {
    test('varsayılan: içerik yok, bayraklar kapalı', () {
      const state = PostDetailState();
      expect(state.post, isNull);
      expect(state.club, isNull);
      expect(state.comments, isEmpty);
      expect(state.visibleComments, isEmpty);
      expect(state.users, isEmpty);
      expect(state.roles, isEmpty);
      expect(state.blockedUserIds, isEmpty);
      expect(state.removedCommentIds, isEmpty);
      expect(state.commentDraft, isEmpty);
      expect(state.myOptionId, isNull);
      expect(state.pollResults, isEmpty);
      expect(state.isSendingComment || state.isSaved, isFalse);
      expect(state.isFetching || state.isFetchingComments, isFalse);
      expect(state.isError || state.isCommentsError, isFalse);
      expect(state.isNotFound || state.isRemoved, isFalse);
      expect(state.canSendComment, isFalse);
    });

    test('copyWith her alanı değiştirir; clearMyOptionId oyu boşaltır; props '
        'değer eşitliği taşır', () {
      final full = const PostDetailState().copyWith(
        post: kPost,
        club: kPostClub,
        comments: kPostComments,
        users: kPostUsers,
        roles: kPostRoles,
        blockedUserIds: {'u1'},
        removedCommentIds: {'cm01'},
        commentDraft: 'taslak',
        isSendingComment: true,
        isSaved: true,
        myOptionId: 'o1',
        pollResults: {'o1': 2},
        isFetching: true,
        isFetchingComments: true,
        isError: true,
        isNotFound: true,
        isCommentsError: true,
        isRemoved: true,
      );
      expect(full.props, [
        kPost,
        kPostClub,
        kPostComments,
        kPostUsers,
        kPostRoles,
        {'u1'},
        {'cm01'},
        'taslak',
        true,
        true,
        'o1',
        {'o1': 2},
        true,
        true,
        true,
        true,
        true,
        true,
      ]);
      expect(full.copyWith(), full);
      expect(full, isNot(const PostDetailState()));
      expect(full.copyWith(clearMyOptionId: true).myOptionId, isNull);
      expect(
        full.copyWith(clearMyOptionId: true, myOptionId: 'o2').myOptionId,
        isNull,
      );
      // Her alan eşitliği tek başına bozar.
      for (final changed in [
        full.copyWith(post: kPollPost),
        full.copyWith(comments: const []),
        full.copyWith(users: const {}),
        full.copyWith(roles: const {}),
        full.copyWith(blockedUserIds: const {}),
        full.copyWith(removedCommentIds: const {}),
        full.copyWith(commentDraft: ''),
        full.copyWith(isSendingComment: false),
        full.copyWith(isSaved: false),
        full.copyWith(myOptionId: 'o2'),
        full.copyWith(pollResults: const {}),
        full.copyWith(isFetching: false),
        full.copyWith(isFetchingComments: false),
        full.copyWith(isError: false),
        full.copyWith(isNotFound: false),
        full.copyWith(isCommentsError: false),
        full.copyWith(isRemoved: false),
      ]) {
        expect(changed, isNot(full));
      }
    });

    test('visibleComments: kaldırılanlar ve engellenen yazarların yorumları '
        'yok; sıra korunur', () {
      final state = loadedPostState();
      expect(state.visibleComments, kPostComments);
      final first = kPostComments.first;
      final last = kPostComments.last;
      expect(
        state.copyWith(removedCommentIds: {first.id}).visibleComments,
        kPostComments.skip(1),
      );
      expect(
        state.copyWith(blockedUserIds: {last.authorId}).visibleComments,
        kPostComments.take(kPostComments.length - 1),
      );
      expect(state.commentById(first.id), first);
      expect(state.commentById('yok'), isNull);
    });

    test('canSendComment: boşluk dışında metin var ve gönderim sürmüyor', () {
      const state = PostDetailState();
      expect(state.copyWith(commentDraft: '   ').canSendComment, isFalse);
      expect(state.copyWith(commentDraft: ' a ').canSendComment, isTrue);
      expect(
        state
            .copyWith(commentDraft: 'a', isSendingComment: true)
            .canSendComment,
        isFalse,
      );
    });

    test('authorOf: belgesi olmayan ya da hesabı silinmiş yazar null '
        '("Silinmiş kullanıcı")', () {
      final author = kPostUsers[kPost.authorId]!;
      final state = loadedPostState();
      expect(state.authorOf(author.uid), author);
      expect(state.authorOf('yok'), isNull);
      final anonymized = state.copyWith(
        users: {
          ...kPostUsers,
          author.uid: author.copyWith(status: UserStatus.deleted),
        },
      );
      expect(anonymized.authorOf(author.uid), isNull);
    });
  });
}
