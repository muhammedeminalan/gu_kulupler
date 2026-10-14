// CLB-02 testlerinin ortak verisi: demo verideki kulüpler (fixture; elle
// yazılmış alan yok), oturum durumları ve ekranın tasarımdaki varsayılan
// durumu (`screens/CLB-02__light__tr.webp`: üç son arama, altı popüler arama,
// üç önerilen kulüp).
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/features/search/provider/search_state.dart';

import '../../fakes/fake_auth_repository.dart';
import '../../fakes/fake_club_repository.dart';
import '../../fakes/fake_event_repository.dart';
import '../../fakes/fake_session_states.dart';
import '../../fakes/register_fakes.dart';
import '../../fixtures/club_model_fixtures.dart';
import '../../fixtures/event_model_fixtures.dart';
import '../../fixtures/user_model_fixtures.dart';

/// Oturumdaki kullanıcının kimliği (`FakeSessionStates.uid`).
const String kUid = FakeSessionStates.uid;

/// Oturumdaki kullanıcı (`u_mehmet` — Mehmet Kaya).
final UserModel kUser = UserModelFixtures.byId(kUid);

/// Oturumdaki kullanıcının e-postası (izinli alan adı).
const String kEmail = 'mehmet.kaya@ogr.gumushane.edu.tr';

/// `c01` — Yazılım ve Yapay Zekâ Topluluğu (k01, onay gerekli).
final ClubModel kSoftware = ClubModelFixtures.byId('c01');

/// `c02` — Girişimcilik ve İnovasyon Kulübü (k06, onay gerekli).
final ClubModel kStartup = ClubModelFixtures.byId('c02');

/// `c03` — Doğa Sporları ve Dağcılık Kulübü (k03, onay gerekli).
final ClubModel kOutdoor = ClubModelFixtures.byId('c03');

/// `c05` — Tiyatro Kulübü (k04, başvurular kapalı).
final ClubModel kTheatre = ClubModelFixtures.byId('c05');

/// `c07` — Fotoğraf ve Sinema Kulübü (k08, anında katılım).
final ClubModel kPhoto = ClubModelFixtures.byId('c07');

/// `c09` — Satranç ve Zekâ Oyunları Kulübü (k07, anında katılım).
final ClubModel kChess = ClubModelFixtures.byId('c09');

/// `c14` — Kariyer ve Mezunlar Kulübü (askıda).
final ClubModel kSuspended = ClubModelFixtures.byId('c14');

/// Depoya yazılan kulüpler (askıdaki dahil).
final List<ClubModel> kSeeded = [
  kSoftware,
  kTheatre,
  kPhoto,
  kChess,
  kSuspended,
];

/// Havuzda beklenen sıra: `nameLower`, askıdaki kulüp yok.
final List<ClubModel> kPool = [kPhoto, kChess, kTheatre, kSoftware];

/// Tasarımdaki son aramalar (`seed.js` `recentSearches`).
const List<String> kRecent = ['hackathon', 'doğa yürüyüşü', 'satranç'];

/// Aktif oturum + profil; üyelik yok (ziyaretçi).
final SessionState kVisitorSession = FakeSessionStates.active.copyWith(
  user: kUser,
);

/// Tasarımdaki varsayılan durum: üç son arama, popüler aramalar ve önerilen
/// `c01`–`c03` (referans yakalamasındaki üç kart).
final SearchState kDefaultState = SearchState(
  recent: kRecent,
  popular: StaticTables.popularSearches,
  clubPool: [kSoftware, kStartup, kOutdoor, kTheatre, kPhoto, kChess],
  suggested: [kSoftware, kStartup, kOutdoor],
);

/// Kayıtlı fake'lere [kSeeded] kulüplerini yazar; oturumun e-postasını
/// kurar.
void seedSearch() {
  final clubs = GetIt.I<ClubRepository>() as FakeClubRepository;
  for (final club in kSeeded) {
    clubs.clubs[club.id] = club;
  }
  (GetIt.I<AuthRepository>() as FakeAuthRepository)
    ..service.uid = kUid
    ..currentUser = const AuthUserInfo(
      uid: kUid,
      email: kEmail,
      emailVerified: true,
    );
}

/// [id] demo etkinliği, "şimdi"den ([kDefaultFakeNowUtc]) [inDays] gün sonra
/// başlayan iki saatlik kopya ([clubId] verilirse o kulübün).
EventModel upcomingEvent(String id, {required int inDays, String? clubId}) {
  final start = kDefaultFakeNowUtc.add(Duration(days: inDays));
  return EventModelFixtures.byId(id).copyWith(
    clubId: clubId,
    startsAt: start,
    endsAt: start.add(const Duration(hours: 2)),
  );
}

/// `e08` — Satranç Turnuvası (c09, herkese açık), yarın.
final EventModel kChessCup = upcomingEvent('e08', inDays: 1);

/// `e07` — Karadeniz Fotoğraf Yürüyüşü (c07, herkese açık), iki gün sonra.
final EventModel kPhotoWalk = upcomingEvent('e07', inDays: 2);

/// `e02` — Hackathon Hazırlık Buluşması (c01, üyelere özel), üç gün sonra.
final EventModel kHackathonPrep = upcomingEvent('e02', inDays: 3);

/// Askıdaki kulübün (c14) herkese açık etkinliği, yarın (havuza girmez).
final EventModel kSuspendedEvent = upcomingEvent(
  'e15',
  inDays: 1,
  clubId: kSuspended.id,
);

/// `e20` — geçmiş etkinlik (c07), iki gün önce (sorgu dışı).
final EventModel kPastEvent = upcomingEvent('e20', inDays: -2);

/// `c01` kulübünün etkin üyesi oturum.
final SessionState kSoftwareMemberSession = FakeSessionStates.withMembership(
  kSoftware.id,
).copyWith(user: kUser);

/// Kayıtlı etkinlik fake'ine arama etkinliklerini yazar.
void seedSearchEvents() {
  final events = GetIt.I<EventRepository>() as FakeEventRepository;
  [
    kChessCup,
    kPhotoWalk,
    kHackathonPrep,
    kSuspendedEvent,
    kPastEvent,
  ].forEach(events.put);
}
