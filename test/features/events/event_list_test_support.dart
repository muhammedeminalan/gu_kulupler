// EVT-01 testlerinin ortak verisi: demo verinin tüm etkinlikleri ve
// kulüpleri, 8 Ekim 2026 15:00 (İstanbul) — referans görüntünün günü
// ("Bugün" = `e17` Veri Bilimi Söyleşisi, "Yarın" = `e01`). Modeller
// fixture'lardan kurulur; elle yazılmış alan yoktur.
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/features/events/provider/event_list_state.dart';
import 'package:gu_kulupler/features/events/provider/event_list_view_model.dart';

import '../../fakes/fake_club_repository.dart';
import '../../fakes/fake_event_repository.dart';
import '../../fakes/fake_rsvp_repository.dart';
import '../../fakes/fake_session_states.dart';
import '../../fixtures/club_model_fixtures.dart';
import '../../fixtures/demo_data.dart';
import '../../fixtures/event_model_fixtures.dart';
import '../../fixtures/membership_model_fixtures.dart';
import '../../fixtures/rsvp_model_fixtures.dart';
import '../../helpers/fake_app_clock.dart';

/// Oturumdaki kullanıcı (`u_mehmet`).
const String kUid = FakeSessionStates.uid;

/// "Şu an": 8 Ekim 2026 12:00 UTC (15:00 İstanbul).
final DateTime kNowUtc = DateTime.utc(2026, 10, 8, 12);

/// Demo verinin tüm kulüpleri (askıdaki `c14` dahil).
final List<ClubModel> kAllClubs = [
  for (final id in DemoDataFixture.ids(FirestoreCollections.clubs))
    ClubModelFixtures.byId(id),
];

/// Demo verinin tüm etkinlikleri.
final List<EventModel> kAllEvents = EventModelFixtures.all();

/// Ziyaretçi (üyeliksiz) oturum — referans görüntünün kullanıcısı gibi.
const SessionState kVisitorSession = FakeSessionStates.active;

/// Mehmet'in demo üyelikleri: `c01`, `c07` etkin; `c06` bekleyen, `c05`
/// reddedilmiş.
final SessionState kMemberSession = kVisitorSession.copyWith(
  memberships: {
    for (final clubId in ['c01', 'c07', 'c06', 'c05'])
      clubId: MembershipModelFixtures.byId('${clubId}_u_mehmet'),
  },
);

/// Mehmet'in katılım kayıtları (`e01` going, `e08` waitlist, …).
final List<RsvpModel> kMyRsvps = RsvpModelFixtures.ofUser(kUid);

/// Herkese açık, askıda olmayan kulübün, 8 Ekim 00:00'dan (İstanbul) sonra
/// başlayan ve [kNowUtc]'de bitmemiş (ya da iptal) etkinliklerin kimlikleri
/// — envanterdeki 14 kart.
const List<String> kVisitorCardIds = [
  'e17', 'e01', 'e04', 'e06', 'e03', 'e21', 'e07', 'e08', 'e09', 'e10', //
  'e12', 'e13', 'e14', 'e15',
];

/// Kayıtlı fake'leri tohumlar: saat [kNowUtc]; tüm demo kulüpleri ve
/// etkinlikleri; [rsvps] katılım kayıtları.
void seedEventList({
  List<EventModel>? events,
  List<RsvpModel> rsvps = const [],
}) {
  (GetIt.I<AppClock>() as FakeAppClock).set(kNowUtc);
  final eventRepo = GetIt.I<EventRepository>() as FakeEventRepository;
  final clubRepo = GetIt.I<ClubRepository>() as FakeClubRepository;
  final rsvpRepo = GetIt.I<RsvpRepository>() as FakeRsvpRepository;
  for (final club in kAllClubs) {
    clubRepo.clubs[club.id] = club;
  }
  (events ?? kAllEvents).forEach(eventRepo.put);
  rsvps.forEach(rsvpRepo.put);
}

/// [session] oturumunun dolu ekran durumu (ViewModel'in ürettiğiyle aynı
/// birleştirme): herkese açıklar + etkin üye olunan kulüplerin üyelere
/// özelleri, askıdaki kulüp yok.
EventListState loadedListState(
  SessionState session, {
  List<RsvpModel> rsvps = const [],
  EventListState base = const EventListState(),
}) {
  final from = FakeAppClock(kNowUtc).istanbulStartOfDay(kNowUtc);
  final members = {
    for (final MapEntry(key: clubId, value: membership)
        in session.memberships.entries)
      if (membership.status == MembershipStatus.active) clubId,
  };
  final pool = [
    for (final club in kAllClubs)
      if (!club.isSuspended) club,
  ];
  final today = EventListState.istanbulCalendarDay(kNowUtc);
  return base.copyWith(
    clubs: pool,
    events: EventListViewModel.mergeEvents(
      clubIds: {for (final club in pool) club.id},
      results: [
        FirebaseSuccess([
          for (final event in kAllEvents)
            if (event.visibility == EventVisibility.public &&
                event.status != EventStatus.draft &&
                !event.startsAt.isBefore(from))
              event,
        ]),
        FirebaseSuccess([
          for (final event in kAllEvents)
            if (members.contains(event.clubId) &&
                event.visibility == EventVisibility.membersOnly &&
                event.status != EventStatus.draft &&
                !event.startsAt.isBefore(from))
              event,
        ]),
      ],
    ),
    rsvps: EventListViewModel.latestRsvps(rsvps),
    memberClubIds: members,
    calendarMonth: DateTime(today.year, today.month),
    selectedDay: today,
  );
}
