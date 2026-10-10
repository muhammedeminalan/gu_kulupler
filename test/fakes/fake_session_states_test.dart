// T-11 · FakeSessionStates: her hazır durum adının söylediği oturumu üretir.
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';

import 'fake_session_states.dart';

void main() {
  group('T-11 · FakeSessionStates', () {
    test('oturumsuz durumlar', () {
      expect(FakeSessionStates.unknown.status, AuthStatus.unknown);
      expect(FakeSessionStates.signedOutFirstRun.status, AuthStatus.signedOut);
      expect(FakeSessionStates.signedOutFirstRun.onboardingSeen, isFalse);
      expect(FakeSessionStates.signedOut.status, AuthStatus.signedOut);
      expect(FakeSessionStates.signedOut.onboardingSeen, isTrue);
      expect(FakeSessionStates.signedOut.uid, isNull);
    });

    test('oturumlu ama uygulamaya giremeyen durumlar', () {
      expect(FakeSessionStates.unverified.status, AuthStatus.unverified);
      expect(
        FakeSessionStates.profileIncomplete.status,
        AuthStatus.profileIncomplete,
      );
      expect(FakeSessionStates.suspended.status, AuthStatus.suspended);
    });

    test('aktif durumların kulüp erişimi', () {
      expect(FakeSessionStates.active.accessTo('c01'), ClubAccess.visitor);
      expect(
        FakeSessionStates.activeSuper.accessTo('c01'),
        ClubAccess.superAdmin,
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
        FakeSessionStates.activeManager(
          'c01',
          role: ClubRole.president,
        ).roleIn('c01'),
        ClubRole.president,
      );
      expect(
        FakeSessionStates.activeAdvisor('c01').accessTo('c01'),
        ClubAccess.advisor,
      );
      expect(
        FakeSessionStates.activePending('c01').accessTo('c01'),
        ClubAccess.pending,
      );
      expect(
        FakeSessionStates.activeRejected('c01').accessTo('c01'),
        ClubAccess.rejected,
      );
    });

    test('üyelik yalnızca verilen kulüp içindir', () {
      final state = FakeSessionStates.activeManager('c01');
      expect(state.memberships.keys, ['c01']);
      expect(state.memberships['c01']!.id, 'c01_${FakeSessionStates.uid}');
      expect(state.accessTo('c02'), ClubAccess.visitor);
    });
  });
}
