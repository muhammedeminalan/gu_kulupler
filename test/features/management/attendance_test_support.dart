// MGT-06 testlerinin ortak verisi: tasarım yakalaması — `u_elif` (yönetim
// kurulu) → `c01` Yazılım ve Yapay Zekâ Topluluğu, `e17` Veri Bilimi
// Söyleşisi (52 kayıt: 47 `going`, 5 `attended`; bekleme listesi boş,
// kontenjan 80). Saat yoklama penceresinin içinde: başlangıçtan 30 dk sonra
// (referansta bant yok). Fake'ler `seedAttendance` ile doldurulur.
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/features/management/provider/attendance_state.dart';

import '../../fakes/fake_club_repository.dart';
import '../../fakes/fake_event_repository.dart';
import '../../fakes/fake_rsvp_repository.dart';
import '../../fakes/fake_user_repository.dart';
import '../../fixtures/club_model_fixtures.dart';
import '../../fixtures/event_model_fixtures.dart';
import '../../fixtures/membership_model_fixtures.dart';
import '../../fixtures/rsvp_model_fixtures.dart';
import '../../fixtures/user_model_fixtures.dart';
import '../../helpers/fake_app_clock.dart';

/// Testlerdeki kulüp (`c01`).
const String kAttendanceClubId = 'c01';

/// Testlerdeki etkinlik (`e17`).
const String kAttendanceEventId = 'e17';

/// Oturumdaki kullanıcı (`u_elif`, `c01` yönetim kurulu; kendi kaydı
/// `going`).
const String kAttendanceUid = 'u_elif';

/// `e17` etkinliği (demo veri; sayaçlar kayıtlardan).
final EventModel kAttendanceEvent = EventModelFixtures.byId(kAttendanceEventId);

/// `c01` kulüp belgesi.
final ClubModel kAttendanceClub = ClubModelFixtures.byId(kAttendanceClubId);

/// Yoklama penceresinin içindeki an: başlangıçtan 30 dk sonra.
final DateTime kInWindowNow = kAttendanceEvent.startsAt.add(
  const Duration(minutes: 30),
);

/// `e17`'nin kayıtları (demo veri).
List<RsvpModel> attendanceRsvps() =>
    RsvpModelFixtures.ofEvent(kAttendanceEventId);

/// [rsvps] sahiplerinin kullanıcı belgeleri.
Map<String, UserModel> attendanceUsers([List<RsvpModel>? rsvps]) => {
  for (final r in rsvps ?? attendanceRsvps())
    r.userId: UserModelFixtures.byId(r.userId),
};

/// `e17`'nin bekleme listesine [userId] kaydı ([position]. sıra).
RsvpModel waitlisted(String userId, {int position = 1}) =>
    attendanceRsvps().first.copyWith(
      id: FirestoreIds.rsvp(kAttendanceEventId, userId),
      userId: userId,
      status: RsvpStatus.waitlist,
      waitlistAt: kAttendanceEvent.startsAt.subtract(
        Duration(days: 2, minutes: -position),
      ),
    );

/// `c01` kulübünde [role] rolüyle aktif oturum (`u_elif`).
SessionState attendanceSession({ClubRole role = ClubRole.board}) =>
    SessionState(
      status: AuthStatus.active,
      uid: kAttendanceUid,
      onboardingSeen: true,
      user: UserModelFixtures.byId(kAttendanceUid),
      memberships: {
        kAttendanceClubId: MembershipModelFixtures.byId(
          FirestoreIds.membership(kAttendanceClubId, kAttendanceUid),
        ).copyWith(role: role),
      },
    );

/// Tasarımdaki dolu durum (ViewModel'in üreteceği biçimde).
AttendanceState loadedAttendanceState({
  ClubAccess access = ClubAccess.manager,
  AttendancePhase phase = AttendancePhase.open,
  List<RsvpModel>? rsvps,
  EventModel? event,
  AttendanceSummaryFilter summary = AttendanceSummaryFilter.all,
}) {
  final all = rsvps ?? attendanceRsvps();
  return AttendanceState(
    access: access,
    actorId: kAttendanceUid,
    club: kAttendanceClub,
    event: event ?? kAttendanceEvent,
    rsvps: all,
    users: attendanceUsers(all),
    summary: summary,
    phase: phase,
  );
}

/// Kayıtlı fake'lere `c01`'i, `e17`'yi (+ [extra] kayıtlar), kayıtlarını ve
/// kullanıcılarını yazar; saati [now]'a (varsayılan pencere içi) kurar.
void seedAttendance({DateTime? now, List<RsvpModel> extra = const []}) {
  (GetIt.I<AppClock>() as FakeAppClock).set(now ?? kInWindowNow);
  (GetIt.I<ClubRepository>() as FakeClubRepository).clubs[kAttendanceClubId] =
      kAttendanceClub;
  EventModelFixtures.ofClub(
    kAttendanceClubId,
  ).forEach((GetIt.I<EventRepository>() as FakeEventRepository).put);
  final rsvps = [...attendanceRsvps(), ...extra]
    ..forEach((GetIt.I<RsvpRepository>() as FakeRsvpRepository).put);
  (GetIt.I<UserRepository>() as FakeUserRepository).users.addAll(
    attendanceUsers(rsvps),
  );
}
