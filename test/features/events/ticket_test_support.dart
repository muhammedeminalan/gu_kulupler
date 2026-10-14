// EVT-03 testlerinin ortak verisi: demo verideki `e01` (Yapay Zekâya Giriş
// Atölyesi — `c01`, 9 Eki 18:00 Istanbul, Bilgisayar Laboratuvarı-2) ve
// Mehmet'in `going` kaydı (`GU-CWV4-JMW9`, hatırlatma 1 saat). Saat demo
// verinin üretim anına kurulur (etkinlikten bir gün önce): "Vazgeç" görünür.
// Modeller fixture'lardan kurulur; elle yazılmış alan yoktur.
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/features/events/provider/ticket_state.dart';

import '../../fakes/fake_auth_repository.dart';
import '../../fakes/fake_club_repository.dart';
import '../../fakes/fake_event_repository.dart';
import '../../fakes/fake_rsvp_repository.dart';
import '../../fakes/fake_session_states.dart';
import '../../fixtures/club_model_fixtures.dart';
import '../../fixtures/event_model_fixtures.dart';
import '../../fixtures/rsvp_model_fixtures.dart';
import '../../fixtures/user_model_fixtures.dart';
import '../../helpers/fake_app_clock.dart';

/// Testlerdeki etkinliğin kimliği.
const String kTicketEventId = 'e01';

/// Oturumdaki kullanıcı (`u_mehmet` — Mehmet Kaya).
const String kTicketUid = FakeSessionStates.uid;

/// Testlerin "şu an"ı: demo verinin üretim anı (8 Eki 19:24 Istanbul),
/// etkinlikten bir gün önce.
final DateTime kTicketNowUtc = DateTime.utc(2026, 10, 8, 16, 24, 30);

/// `e01` — 9 Eki 2026 15:00Z (18:00 Istanbul), mekân `pl04`.
final EventModel kTicketEvent = EventModelFixtures.e01;

/// `c01` — Yazılım ve Yapay Zekâ Topluluğu.
final ClubModel kTicketClub = ClubModelFixtures.byId(kTicketEvent.clubId);

/// Mehmet'in `e01` kaydı (`going`, `GU-CWV4-JMW9`).
final RsvpModel kTicketRsvp = RsvpModelFixtures.e01Mehmet;

/// Kaydın okutulmuş hâli (yönetici okuttu: `attended`, 9 Eki 18:05).
final RsvpModel kScannedRsvp = kTicketRsvp.copyWith(
  status: RsvpStatus.attended,
  scannedAt: DateTime.utc(2026, 10, 9, 15, 5),
  scannedBy: 'u_baran',
);

/// Aktif oturum, profil adı "Mehmet Kaya".
SessionState ticketSession() => FakeSessionStates.active.copyWith(
  user: UserModelFixtures.byId(kTicketUid),
);

/// Dolu ekran durumu (ViewModel'in ürettiğiyle aynı).
TicketViewState loadedTicketState({RsvpModel? rsvp, EventModel? event}) =>
    TicketViewState(
      event: event ?? kTicketEvent,
      club: kTicketClub,
      rsvp: rsvp ?? kTicketRsvp,
    );

/// Kayıtlı fake'lere etkinliği, kulübü ve ([withRsvp] ise) kaydı yazar; saati
/// [kTicketNowUtc]'ye, oturum kimliğini [kTicketUid]'ye kurar. Çağrı
/// günlükleri temizlenir.
void seedTicket({bool withRsvp = true}) {
  (GetIt.I<AppClock>() as FakeAppClock).set(kTicketNowUtc);
  final events = GetIt.I<EventRepository>() as FakeEventRepository
    ..put(kTicketEvent);
  (GetIt.I<ClubRepository>() as FakeClubRepository).clubs[kTicketClub.id] =
      kTicketClub;
  final rsvps = GetIt.I<RsvpRepository>() as FakeRsvpRepository;
  if (withRsvp) rsvps.put(kTicketRsvp);
  (GetIt.I<AuthRepository>() as FakeAuthRepository).service.uid = kTicketUid;
  events.calls.clear();
  rsvps.calls.clear();
}
