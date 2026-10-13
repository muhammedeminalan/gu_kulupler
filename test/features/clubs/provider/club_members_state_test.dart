// CLB-06 · ClubMembersState: varsayılanlar, `copyWith` (tüm alanlar + temizleme
// bayrakları), değer eşitliği, türetilmiş gruplar (sıra, sayı, silinmiş hesap).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/clubs/provider/club_members_state.dart';
import 'package:gu_kulupler/product/mixin/block_user_mixin.dart';

import '../club_members_test_support.dart';

void main() {
  group('CLB-06 · ClubMembersState', () {
    test('varsayılan: içerik yok, süzgeç "Tümü", sayfa yok', () {
      const state = ClubMembersState();
      expect(state.club, isNull);
      expect(state.visible, isEmpty);
      expect(state.groups, isEmpty);
      expect(state.totalCount, 0);
      expect(state.roleFilter, MemberRoleFilter.all);
      expect(state.query, isEmpty);
      expect(state.hasMore, isFalse);
      expect(state.wantsMore, isFalse);
      expect(state.pendingUndo, isNull);
      expect(state.isFetching || state.isLoadingMore, isFalse);
      expect(state.isRefreshing || state.isError, isFalse);
    });

    test('copyWith her alanı değiştirir; clearCursor / clearPendingUndo '
        'alanı boşaltır; props değer eşitliği taşır', () {
      final cursor = PageCursor.fake();
      const undo = BlockUndo(userId: 'u1', name: 'Ad');
      final full = const ClubMembersState().copyWith(
        club: kMembersClub,
        managers: kClubManagers,
        advisors: kClubAdvisors,
        members: kClubMembers,
        users: kClubUsers,
        blockedUserIds: {'u1'},
        roleFilter: MemberRoleFilter.member,
        query: 'a',
        cursor: cursor,
        pendingUndo: undo,
        isFetching: true,
        isLoadingMore: true,
        isRefreshing: true,
        isError: true,
      );
      expect(full.props, [
        kMembersClub,
        kClubManagers,
        kClubAdvisors,
        kClubMembers,
        kClubUsers,
        {'u1'},
        MemberRoleFilter.member,
        'a',
        cursor,
        undo,
        true,
        true,
        true,
        true,
      ]);
      expect(full.copyWith(), full);
      expect(full.hasMore, isTrue);
      expect(full, isNot(full.copyWith(query: 'b')));

      final cleared = full.copyWith(clearCursor: true, clearPendingUndo: true);
      expect(cleared.cursor, isNull);
      expect(cleared.pendingUndo, isNull);
      expect(cleared.hasMore, isFalse);
    });

    test('gruplar tasarım sırasıyla ve sayılarıyla; "Yönetim" süzgecinde '
        'sonraki sayfa istenmez', () {
      final state = loadedMembersState();
      expect(
        [for (final group in state.groups) (group.role, group.count)],
        [
          (ClubRole.president, 1),
          (ClubRole.board, kClubManagers.length - 1),
          (ClubRole.advisor, kClubAdvisors.length),
          (ClubRole.member, kClubMembers.length),
        ],
      );
      expect(state.totalCount, kClubMemberships.length);
      expect(state.nameOfUser(kBoardMember.userId), isNotNull);
      expect(state.nameOfUser('yok'), isNull);

      final paging = state.copyWith(cursor: PageCursor.fake());
      expect(paging.wantsMore, isTrue);
      expect(
        paging.copyWith(roleFilter: MemberRoleFilter.board).wantsMore,
        isFalse,
      );
    });

    test('belgesi okunmamış üye anlık görüntüyle adlandırılır; silinmiş '
        'hesap listelenmez', () {
      final deleted = kOtherMember.userId;
      final state = loadedMembersState().copyWith(
        users: {
          deleted: kClubUsers[deleted]!.copyWith(status: UserStatus.deleted),
        },
      );
      expect(state.nameOf(kBoardMember), kBoardMember.applicant.name);
      expect(state.visible.map((m) => m.userId), isNot(contains(deleted)));
      expect(state.totalCount, kClubMemberships.length - 1);
    });
  });
}
