// EVT-02 testlerinin ortak verisi: demo verideki `e01` (Yapay Zekâya Giriş
// Atölyesi — `c01`, herkese açık, 36 / 40), `e03` (dolu, 4 bekleyen), `e02`
// (üyelere özel), `e19` (geçmiş), `e21` (iptal, `weather`) etkinlikleri ve
// oturum durumları. Modeller fixture'lardan kurulur; elle yazılmış alan
// yoktur.
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/features/events/provider/event_detail_state.dart';
import 'package:gu_kulupler/features/events/view/event_detail_view.dart';

import '../../fakes/fake_club_repository.dart';
import '../../fakes/fake_event_repository.dart';
import '../../fakes/fake_rsvp_repository.dart';
import '../../fakes/fake_session_states.dart';
import '../../fixtures/club_model_fixtures.dart';
import '../../fixtures/event_model_fixtures.dart';
import '../../fixtures/rsvp_model_fixtures.dart';
import '../../helpers/fake_app_clock.dart';

/// Oturumdaki kullanıcı (`u_mehmet`).
const String kUid = FakeSessionStates.uid;

/// `e01` — yaklaşan, herkese açık, 36 / 40 (`c01`).
final EventModel kEvent = EventModelFixtures.e01;

/// `e01` etkinliğinin kulübü (`c01` — Yazılım ve Yapay Zekâ Topluluğu).
final ClubModel kClub = ClubModelFixtures.byId(kEvent.clubId);

/// Mehmet'in `e01` kaydı (`going`, hatırlatma 1 saat önce).
final RsvpModel kGoing = RsvpModelFixtures.e01Mehmet;

/// "Şu an": `e01` başlamadan bir gün önce (8 Ekim 2026 15:00 İstanbul).
final DateTime kNowUtc = DateTime.utc(2026, 10, 8, 12);

/// Üyeliği olmayan aktif oturum (ziyaretçi).
const SessionState kVisitorSession = FakeSessionStates.active;

/// `e01` kulübünde [role] rolünde etkin üyelik.
SessionState memberSession({ClubRole role = ClubRole.member}) =>
    FakeSessionStates.withMembership(kEvent.clubId, role: role);

/// Kayıtlı fake'leri tohumlar: saat [kNowUtc]; [events] (varsayılan `e01`,
/// `e03`, `e21`) ve kulüpleri; [rsvps] katılım kayıtları.
void seedEvents({
  List<EventModel>? events,
  List<RsvpModel> rsvps = const [],
  DateTime? nowUtc,
}) {
  (GetIt.I<AppClock>() as FakeAppClock).set(nowUtc ?? kNowUtc);
  final eventRepo = GetIt.I<EventRepository>() as FakeEventRepository;
  final clubs = GetIt.I<ClubRepository>() as FakeClubRepository;
  final rsvpRepo = GetIt.I<RsvpRepository>() as FakeRsvpRepository;
  for (final event
      in events ?? [kEvent, EventModelFixtures.e03, EventModelFixtures.e21]) {
    eventRepo.put(event);
    clubs.clubs[event.clubId] = ClubModelFixtures.byId(event.clubId);
  }
  rsvps.forEach(rsvpRepo.put);
}

/// [event] etkinliğinin dolu ekran durumu ([session] kipiyle).
EventDetailState loadedState({
  EventModel? event,
  RsvpModel? rsvp,
  SessionState session = kVisitorSession,
  int? waitlistPosition,
}) {
  final current = event ?? kEvent;
  return EventDetailState(
    event: current,
    club: ClubModelFixtures.byId(current.clubId),
    rsvp: rsvp,
    access: session.accessTo(current.clubId),
    waitlistPosition: waitlistPosition,
  );
}

/// EVT-02 ekranı.
Widget eventDetailView({String? eventId, bool showCancelled = false}) =>
    EventDetailView(
      eventId: eventId ?? kEvent.id,
      showCancelled: showCancelled,
    );
