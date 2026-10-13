// CLB-07 · UserProfileState: varsayılanlar, türetilmiş alanlar
// (`isDeletedUser`, `canOpenMenu`, `showsDetails`), `props` ve `copyWith`.
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/clubs/provider/user_profile_state.dart';

import '../user_profile_test_support.dart';

void main() {
  group('CLB-07 · UserProfileState', () {
    test('varsayılan: kullanıcı okunmadı, görünür, engelsiz', () {
      const state = UserProfileState();
      expect(state.user, isNull);
      expect(state.sharedClubIds, isEmpty);
      expect(state.sharedClubs, isEmpty);
      expect(state.roles, isEmpty);
      expect(state.contextMembership, isNull);
      expect(state.isSelf, isFalse);
      expect(state.isSuperAdmin, isFalse);
      expect(state.isHiddenByPrivacy, isFalse);
      expect(state.isBlocked, isFalse);
      expect(state.isFetching, isFalse);
      expect(state.isError, isFalse);
      expect(state.isNotFound, isFalse);
      expect(state.isActing, isFalse);
      expect(state.canOpenMenu, isFalse);
    });

    test('menü: kullanıcı okunduysa, kendisi değilse ve silinmemişse', () {
      expect(kVisibleState.canOpenMenu, isTrue);
      expect(kPrivateState.canOpenMenu, isTrue);
      expect(kVisibleState.copyWith(isSelf: true).canOpenMenu, isFalse);
      expect(kDeletedState.canOpenMenu, isFalse);
    });

    test('ayrıntılar gizli profilde ve silinmiş kullanıcıda çizilmez', () {
      expect(kVisibleState.showsDetails, isTrue);
      expect(kPrivateState.showsDetails, isFalse);
      expect(kDeletedState.showsDetails, isFalse);
      expect(kDeletedState.isDeletedUser, isTrue);
      expect(
        UserProfileState(
          user: kUser.copyWith(status: UserStatus.deleted),
        ).isDeletedUser,
        isTrue,
      );
      expect(kVisibleState.isDeletedUser, isFalse);
    });

    test('`props` tüm alanları taşır; her alan eşitliği bozar', () {
      const base = UserProfileState();
      expect(base.props, hasLength(13));
      final variants = [
        UserProfileState(user: kUser),
        const UserProfileState(sharedClubIds: [kSharedClubId]),
        UserProfileState(sharedClubs: [kSharedClub]),
        const UserProfileState(roles: [ClubRole.board]),
        UserProfileState(contextMembership: kUserInShared),
        const UserProfileState(isSelf: true),
        const UserProfileState(isSuperAdmin: true),
        const UserProfileState(isHiddenByPrivacy: true),
        const UserProfileState(isBlocked: true),
        const UserProfileState(isFetching: true),
        const UserProfileState(isError: true),
        const UserProfileState(isNotFound: true),
        const UserProfileState(isActing: true),
      ];
      expect(variants, hasLength(base.props.length));
      for (final variant in variants) {
        expect(variant, isNot(base));
      }
      expect(const UserProfileState(), base);
    });

    test('`copyWith` her alanı değiştirir, verilmeyeni korur; '
        '`clearContextMembership` üyeliği siler', () {
      final full = const UserProfileState().copyWith(
        user: kUser,
        sharedClubIds: const [kSharedClubId],
        sharedClubs: [kSharedClub],
        roles: const [ClubRole.president],
        contextMembership: kUserInShared,
        isSelf: true,
        isSuperAdmin: true,
        isHiddenByPrivacy: true,
        isBlocked: true,
        isFetching: true,
        isError: true,
        isNotFound: true,
        isActing: true,
      );
      expect(
        full,
        UserProfileState(
          user: kUser,
          sharedClubIds: const [kSharedClubId],
          sharedClubs: [kSharedClub],
          roles: const [ClubRole.president],
          contextMembership: kUserInShared,
          isSelf: true,
          isSuperAdmin: true,
          isHiddenByPrivacy: true,
          isBlocked: true,
          isFetching: true,
          isError: true,
          isNotFound: true,
          isActing: true,
        ),
      );
      expect(full.copyWith(), full);
      expect(
        full.copyWith(clearContextMembership: true).contextMembership,
        isNull,
      );
    });
  });
}
