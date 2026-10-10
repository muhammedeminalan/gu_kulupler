// T-11 · SessionState: props / copyWith tüm alanlar (PLAN §12.16) ve rol
// türetimi (`RolePolicy`, CD-129).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_state.dart';

import '../../fakes/fake_session_states.dart';
import '../../fixtures/membership_model_fixtures.dart';
import '../../fixtures/user_model_fixtures.dart';

void main() {
  group('T-11 · SessionState', () {
    const a = SessionState();
    final user = UserModelFixtures.ayse;
    final memberships = <String, MembershipModel>{
      'c01': MembershipModelFixtures.c01Mehmet,
    };

    test('props tüm alanları içerir (alan sayısı = 10)', () {
      expect(a.props.length, 10);
    });

    test('varsayılanlar: oturum çözülmedi, kullanıcıya bağlı alan yok', () {
      expect(a.status, AuthStatus.unknown);
      expect(a.uid, isNull);
      expect(a.user, isNull);
      expect(a.isSuperAdmin, isFalse);
      expect(a.memberships, isEmpty);
      expect(a.blockedUserIds, isEmpty);
      expect(a.onboardingSeen, isFalse);
      expect(a.isResolving, isFalse);
      expect(a.isError, isFalse);
      expect(a.sessionExpired, isFalse);
    });

    test('copyWith her alanı taşır ve eşitliği bozar', () {
      expect(a.copyWith(status: AuthStatus.active).status, AuthStatus.active);
      expect(a.copyWith(status: AuthStatus.active), isNot(a));
      expect(a.copyWith(uid: 'u1').uid, 'u1');
      expect(a.copyWith(uid: 'u1'), isNot(a));
      expect(a.copyWith(user: user).user, user);
      expect(a.copyWith(user: user), isNot(a));
      expect(a.copyWith(isSuperAdmin: true).isSuperAdmin, isTrue);
      expect(a.copyWith(isSuperAdmin: true), isNot(a));
      expect(a.copyWith(memberships: memberships).memberships, memberships);
      expect(a.copyWith(memberships: memberships), isNot(a));
      expect(a.copyWith(blockedUserIds: {'u9'}).blockedUserIds, {'u9'});
      expect(a.copyWith(blockedUserIds: {'u9'}), isNot(a));
      expect(a.copyWith(onboardingSeen: true).onboardingSeen, isTrue);
      expect(a.copyWith(onboardingSeen: true), isNot(a));
      expect(a.copyWith(isResolving: true).isResolving, isTrue);
      expect(a.copyWith(isResolving: true), isNot(a));
      expect(a.copyWith(isError: true).isError, isTrue);
      expect(a.copyWith(isError: true), isNot(a));
      expect(a.copyWith(sessionExpired: true).sessionExpired, isTrue);
      expect(a.copyWith(sessionExpired: true), isNot(a));
    });

    test('copyWith parametresiz aynı değeri verir', () {
      final b = a.copyWith(
        status: AuthStatus.active,
        uid: 'u1',
        user: user,
        isSuperAdmin: true,
        memberships: memberships,
        blockedUserIds: {'u9'},
        onboardingSeen: true,
        isResolving: true,
        isError: true,
        sessionExpired: true,
      );
      expect(b.copyWith(), b);
    });

    test('clearUid / clearUser alanı boşaltır ve verilen değerden önce '
        'gelir', () {
      final b = a.copyWith(uid: 'u1', user: user);
      expect(b.copyWith(clearUid: true).uid, isNull);
      expect(b.copyWith(clearUid: true).user, user);
      expect(b.copyWith(clearUser: true).user, isNull);
      expect(b.copyWith(clearUser: true).uid, 'u1');
      expect(b.copyWith(uid: 'u2', clearUid: true).uid, isNull);
      expect(b.copyWith(user: user, clearUser: true).user, isNull);
    });
  });

  group('T-11 · SessionState · rol türetimi', () {
    test('roleIn yalnızca aktif üyelikte rol verir (CD-129)', () {
      expect(FakeSessionStates.active.roleIn('c01'), isNull);
      expect(
        FakeSessionStates.activeMember('c01').roleIn('c01'),
        ClubRole.member,
      );
      expect(
        FakeSessionStates.activeManager('c01').roleIn('c01'),
        ClubRole.board,
      );
      expect(
        FakeSessionStates.activeAdvisor('c01').roleIn('c01'),
        ClubRole.advisor,
      );
      // Başvuru belgesi `role: member` ile yazılır; başvuran üye sayılmaz.
      expect(FakeSessionStates.activePending('c01').roleIn('c01'), isNull);
      expect(FakeSessionStates.activeRejected('c01').roleIn('c01'), isNull);
      for (final status in [
        MembershipStatus.left,
        MembershipStatus.cancelled,
        MembershipStatus.removed,
      ]) {
        expect(
          FakeSessionStates.withMembership('c01', status: status).roleIn('c01'),
          isNull,
          reason: status.name,
        );
      }
    });

    test('roleIn başka kulübün üyeliğini okumaz', () {
      expect(FakeSessionStates.activeManager('c01').roleIn('c02'), isNull);
    });

    test('accessTo yedi kipi çözer', () {
      expect(FakeSessionStates.active.accessTo('c01'), ClubAccess.visitor);
      expect(
        FakeSessionStates.activePending('c01').accessTo('c01'),
        ClubAccess.pending,
      );
      expect(
        FakeSessionStates.activeRejected('c01').accessTo('c01'),
        ClubAccess.rejected,
      );
      expect(
        FakeSessionStates.activeMember('c01').accessTo('c01'),
        ClubAccess.member,
      );
      expect(
        FakeSessionStates.activeManager('c01').accessTo('c01'),
        ClubAccess.manager,
      );
      expect(
        FakeSessionStates.activeAdvisor('c01').accessTo('c01'),
        ClubAccess.advisor,
      );
      expect(
        FakeSessionStates.activeSuper.accessTo('c01'),
        ClubAccess.superAdmin,
      );
    });

    test('süper admin üyelikten bağımsız olarak superAdmin kipindedir', () {
      final state = FakeSessionStates.withMembership(
        'c01',
        role: ClubRole.board,
        isSuperAdmin: true,
      );
      expect(state.accessTo('c01'), ClubAccess.superAdmin);
      expect(state.roleIn('c01'), ClubRole.board);
    });

    test('isBlocked yalnızca listedeki kimlik için doğrudur', () {
      final state = FakeSessionStates.active.copyWith(blockedUserIds: {'u9'});
      expect(state.isBlocked('u9'), isTrue);
      expect(state.isBlocked('u8'), isFalse);
    });
  });
}
