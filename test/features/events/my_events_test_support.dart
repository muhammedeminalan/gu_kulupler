// EVT-04 testlerinin ortak verisi: demo verideki Mehmet'in üç kaydı — `e01`
// (Yapay Zekâya Giriş Atölyesi, `going`, yaklaşan), `e08` (Satranç Turnuvası,
// `waitlist`), `e18` (Açılış Tanışma Toplantısı, `attended`, geçmiş) — ve
// sayfalama için üretilmiş etkinlik / kayıt kümeleri. Modeller fixture'lardan
// kurulur.
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/events/provider/my_events_state.dart';

import '../../fakes/fake_club_repository.dart';
import '../../fakes/fake_event_repository.dart';
import '../../fakes/fake_rsvp_repository.dart';
import '../../fakes/fake_session_states.dart';
import '../../fixtures/club_model_fixtures.dart';
import '../../fixtures/event_model_fixtures.dart';
import '../../fixtures/rsvp_model_fixtures.dart';
import '../../helpers/fake_app_clock.dart';

/// Oturumdaki kullanıcı (`u_mehmet`).
const String kMyUid = FakeSessionStates.uid;

/// "Şu an": 8 Ekim 2026 15:00 İstanbul (`e01` yarın, `e18` geçti).
final DateTime kMyNowUtc = DateTime.utc(2026, 10, 8, 12);

/// `e01` — yaklaşan (`c01`).
final EventModel kMyE01 = EventModelFixtures.e01;

/// `e08` — yaklaşan; Mehmet bekleme listesinde (`c09`).
final EventModel kMyE08 = EventModelFixtures.byId('e08');

/// `e18` — geçmiş; Mehmet'in yoklaması alındı (`c01`).
final EventModel kMyE18 = EventModelFixtures.byId('e18');

/// Mehmet'in kayıtları (`listMine` sırası: en yeni üstte).
final List<RsvpModel> kMyRsvps = [
  RsvpModelFixtures.e01Mehmet,
  RsvpModelFixtures.e08Mehmet,
  RsvpModelFixtures.e18Mehmet,
];

/// Demo verideki etkinlikler.
List<EventModel> get kMyEvents => [kMyE01, kMyE08, kMyE18];

/// Fake'leri tohumlar: saat [nowUtc]; [events] ve kulüpleri; [rsvps].
void seedMyEvents({
  List<EventModel>? events,
  List<RsvpModel>? rsvps,
  DateTime? nowUtc,
}) {
  (GetIt.I<AppClock>() as FakeAppClock).set(nowUtc ?? kMyNowUtc);
  final eventRepo = GetIt.I<EventRepository>() as FakeEventRepository;
  final clubs = GetIt.I<ClubRepository>() as FakeClubRepository;
  final rsvpRepo = GetIt.I<RsvpRepository>() as FakeRsvpRepository;
  for (final event in events ?? kMyEvents) {
    eventRepo.put(event);
    clubs.clubs[event.clubId] = ClubModelFixtures.byId(event.clubId);
  }
  (rsvps ?? kMyRsvps).forEach(rsvpRepo.put);
}

/// [count] adet geçmiş etkinlik (`p0`, `p1`, …; `e18` kopyası, gün gün
/// geriye) ve Mehmet'in onlardaki `going` kayıtları — kayıtlar en yeni
/// üstte.
({List<EventModel> events, List<RsvpModel> rsvps}) pastBatch(
  int count, {
  String prefix = 'p',
}) {
  final events = <EventModel>[];
  final rsvps = <RsvpModel>[];
  for (var i = 0; i < count; i++) {
    final id = '$prefix$i';
    final shift = Duration(days: i);
    events.add(
      kMyE18.copyWith(
        id: id,
        startsAt: kMyE18.startsAt.subtract(shift),
        endsAt: kMyE18.endsAt.subtract(shift),
      ),
    );
    rsvps.add(
      RsvpModelFixtures.e18Mehmet.copyWith(
        id: FirestoreIds.rsvp(id, kMyUid),
        eventId: id,
        status: RsvpStatus.going,
        createdAt: RsvpModelFixtures.e18Mehmet.createdAt!.subtract(shift),
      ),
    );
  }
  return (events: events, rsvps: rsvps);
}

/// Dolu ekran durumu: [rsvps] kayıtları ve [events] etkinlikleri okunmuş,
/// kulüp adları fixture'dan.
MyEventsState loadedMyEvents({
  MyEventsTab tab = MyEventsTab.upcoming,
  List<RsvpModel>? rsvps,
  List<EventModel>? events,
}) {
  final list = rsvps ?? kMyRsvps;
  final all = events ?? kMyEvents;
  return MyEventsState(
    tab: tab,
    rsvps: list,
    events: {for (final event in all) event.id: event},
    clubNames: {
      for (final event in all)
        event.clubId: ClubModelFixtures.byId(event.clubId).name,
    },
    loadedCount: list.length,
  );
}
