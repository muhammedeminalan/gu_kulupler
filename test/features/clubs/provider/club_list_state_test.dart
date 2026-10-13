// CLB-01 · ClubListState: varsayılanlar, türetilen değerler (`visible`,
// `activeFilterCount`, `clubById`), `props` / `copyWith` tüm alanlar.
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/features/clubs/provider/club_filters.dart';
import 'package:gu_kulupler/features/clubs/provider/club_list_state.dart';

import '../club_list_test_support.dart';

void main() {
  group('CLB-01 · ClubListState', () {
    test('varsayılan: kulüp yok, süzgeç yok, liste görünümü', () {
      const state = ClubListState();
      expect(state.clubs, isEmpty);
      expect(state.filters, ClubFilters.none);
      expect(state.layout, ClubListLayout.list);
      expect(state.memberClubIds, isEmpty);
      expect(state.managerPreviews, isEmpty);
      expect(state.pendingJoinIds, isEmpty);
      expect(state.isFetching, isFalse);
      expect(state.isRefreshing, isFalse);
      expect(state.isError, isFalse);
      expect(state.visible, isEmpty);
      expect(state.activeFilterCount, 0);
    });

    test('visible: askıdaki kulüp yok, üye sayısına göre sıralı; süzgeç ve '
        'üyelik uygulanır', () {
      final state = ClubListState(
        clubs: kAllClubs,
        memberClubIds: const {'c01'},
      );
      expect(state.visible, hasLength(kActiveClubCount));
      expect(state.visible.first.id, kApprovalClubId);
      expect(
        state.visible.map((club) => club.id),
        isNot(contains(kSuspendedClubId)),
      );

      final mine = state.copyWith(
        filters: const ClubFilters(membership: ClubMembershipFilter.mine),
      );
      expect(mine.visible.map((club) => club.id), ['c01']);
      expect(mine.activeFilterCount, 1);
    });

    test('clubById: listedeki kulüp; yoksa null', () {
      final state = ClubListState(clubs: kAllClubs);
      expect(state.clubById(kSuspendedClubId)?.id, kSuspendedClubId);
      expect(state.clubById('yok'), isNull);
    });

    test('copyWith her alanı değiştirir; props tüm alanları taşır', () {
      const base = ClubListState();
      final variants = [
        base.copyWith(clubs: kAllClubs),
        base.copyWith(filters: const ClubFilters(instantOnly: true)),
        base.copyWith(layout: ClubListLayout.grid),
        base.copyWith(memberClubIds: const {'c01'}),
        base.copyWith(managerPreviews: {kApprovalClubId: kManagers}),
        base.copyWith(pendingJoinIds: const {'c07'}),
        base.copyWith(isFetching: true),
        base.copyWith(isRefreshing: true),
        base.copyWith(isError: true),
      ];
      expect(base.props, hasLength(variants.length));
      for (final variant in variants) {
        expect(variant, isNot(base));
        expect(variant.copyWith(), variant);
      }
      expect(variants.toSet(), hasLength(variants.length));
    });
  });
}
