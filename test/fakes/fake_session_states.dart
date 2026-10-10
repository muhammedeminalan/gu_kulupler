// Hazır `SessionState` örnekleri (PLAN §13.4): yönlendirme tablosu, guard ve
// kabuk testleri oturumu bunlarla kurar. Üyelikler demo veriden gelir
// (`MembershipModelFixtures.c01Mehmet`), yalnızca durum ve rol değiştirilir.
//
//   AppRedirect.resolve(FakeSessionStates.activeManager('c01'), uri);
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_state.dart';

import '../fixtures/membership_model_fixtures.dart';

abstract final class FakeSessionStates {
  /// Aktif oturumların kullanıcı kimliği.
  static const String uid = 'u_mehmet';

  /// Oturum henüz çözülmedi.
  static const SessionState unknown = SessionState();

  /// Oturum yok, tanıtım görülmedi (ilk açılış).
  static const SessionState signedOutFirstRun = SessionState(
    status: AuthStatus.signedOut,
  );

  /// Oturum yok, tanıtım görüldü.
  static const SessionState signedOut = SessionState(
    status: AuthStatus.signedOut,
    onboardingSeen: true,
  );

  /// Oturum var, e-posta doğrulanmamış.
  static const SessionState unverified = SessionState(
    status: AuthStatus.unverified,
    uid: uid,
    onboardingSeen: true,
  );

  /// Doğrulanmış, profil eksik.
  static const SessionState profileIncomplete = SessionState(
    status: AuthStatus.profileIncomplete,
    uid: uid,
    onboardingSeen: true,
  );

  /// Hesap askıda.
  static const SessionState suspended = SessionState(
    status: AuthStatus.suspended,
    uid: uid,
    onboardingSeen: true,
  );

  /// Aktif oturum, hiçbir kulüpte üyeliği yok (ziyaretçi).
  static const SessionState active = SessionState(
    status: AuthStatus.active,
    uid: uid,
    onboardingSeen: true,
  );

  /// Aktif oturum, süper admin (üyelik yok).
  static const SessionState activeSuper = SessionState(
    status: AuthStatus.active,
    uid: uid,
    isSuperAdmin: true,
    onboardingSeen: true,
  );

  /// [clubId] kulübünde aktif üye.
  static SessionState activeMember(String clubId) => withMembership(clubId);

  /// [clubId] kulübünde yönetici ([role]: `board` ya da `president`).
  static SessionState activeManager(
    String clubId, {
    ClubRole role = ClubRole.board,
  }) => withMembership(clubId, role: role);

  /// [clubId] kulübünde danışman (salt okunur yönetim).
  static SessionState activeAdvisor(String clubId) =>
      withMembership(clubId, role: ClubRole.advisor);

  /// [clubId] kulübüne başvurusu karar bekliyor.
  static SessionState activePending(String clubId) =>
      withMembership(clubId, status: MembershipStatus.pending);

  /// [clubId] kulübüne başvurusu reddedilmiş.
  static SessionState activeRejected(String clubId) =>
      withMembership(clubId, status: MembershipStatus.rejected);

  /// Aktif oturum + [clubId] kulübünde verilen [status] / [role] üyeliği.
  static SessionState withMembership(
    String clubId, {
    MembershipStatus status = MembershipStatus.active,
    ClubRole role = ClubRole.member,
    bool isSuperAdmin = false,
  }) => SessionState(
    status: AuthStatus.active,
    uid: uid,
    isSuperAdmin: isSuperAdmin,
    onboardingSeen: true,
    memberships: <String, MembershipModel>{
      clubId: MembershipModelFixtures.c01Mehmet.copyWith(
        id: FirestoreIds.membership(clubId, uid),
        clubId: clubId,
        userId: uid,
        status: status,
        role: role,
      ),
    },
  );
}
