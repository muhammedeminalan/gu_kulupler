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
      expect(base.props, hasLength(16));
      final variants = [
        UserProfileState(user: kUser),
        const UserProfileState(sharedClubIds: [kSharedClubId]),
        UserProfileState(sharedClubs: [kSharedClub]),
        const UserProfileState(roles: [ClubRole.board]),
        UserProfileState(contextMembership: kUserInShared),
        const UserProfileState(contextClubName: 'Kulüp'),
        const UserProfileState(contactEmail: 'a@ogr.gumushane.edu.tr'),
        const UserProfileState(canAssignRoles: true),
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
        contextClubName: 'Kulüp',
        contactEmail: 'a@ogr.gumushane.edu.tr',
        canAssignRoles: true,
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
          contextClubName: 'Kulüp',
          contactEmail: 'a@ogr.gumushane.edu.tr',
          canAssignRoles: true,
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
      final cleared = full.copyWith(clearContextMembership: true);
      expect(cleared.contextMembership, isNull);
      expect(cleared.contextClubName, isNull);
      expect(cleared.contactEmail, isNull);
    });

    test('yönetici kartı yalnızca aktif bağlam üyeliğinde; düğmeler başkan '
        've danışman hedefinde çizilmez', () {
      final active = kUserInShared.copyWith(
        status: MembershipStatus.active,
        role: ClubRole.member,
      );
      final state = UserProfileState(user: kUser, contextMembership: active);
      expect(state.showsManagerCard, isTrue);
      expect(state.showsManagerActions, isTrue);
      final pending = state.copyWith(
        contextMembership: active.copyWith(status: MembershipStatus.pending),
      );
      expect(pending.showsManagerCard, isFalse);
      for (final role in [ClubRole.president, ClubRole.advisor]) {
        final target = state.copyWith(
          contextMembership: active.copyWith(role: role),
        );
        expect(target.showsManagerCard, isTrue);
        expect(target.showsManagerActions, isFalse);
      }
      expect(const UserProfileState().showsManagerCard, isFalse);
    });
  });
}
