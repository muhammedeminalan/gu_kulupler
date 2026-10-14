// MGT-10 testlerinin ortak verisi: demo verideki `c03` (Doğa Sporları ve
// Dağcılık) kulübünün 16 faaliyet kaydı (envanterdeki `MGT-10.row.<id>`
// kimlikleri), eylemci / hedef kullanıcıları ve etkinlikleri. "Şu an" 8 Ekim
// 2026 20:00 İstanbul: `a062` "20 saat önce" (referans görüntü).
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/management/provider/activity_log_state.dart';
import 'package:gu_kulupler/features/management/provider/activity_log_view_model.dart';

import '../../fakes/fake_activity_repository.dart';
import '../../fakes/fake_club_repository.dart';
import '../../fakes/fake_event_repository.dart';
import '../../fakes/fake_session_states.dart';
import '../../fakes/fake_user_repository.dart';
import '../../fakes/register_fakes.dart';
import '../../fixtures/club_model_fixtures.dart';
import '../../fixtures/demo_data.dart';
import '../../fixtures/event_model_fixtures.dart';
import '../../fixtures/user_model_fixtures.dart';
import '../../helpers/fake_app_clock.dart';
import '../../helpers/test_container.dart';

/// Kulüp (`c03`).
const String kActClubId = 'c03';

/// "Şu an": 8 Ekim 2026 20:00 İstanbul.
final DateTime kActNowUtc = DateTime.utc(2026, 10, 8, 17);

/// `c03`'ün demo faaliyet kimlikleri (en yeni üstte).
const List<String> kActIds = [
  'a105',
  'a062',
  'a061',
  'a064',
  'a052',
  'a065',
  'a063',
  'a050',
  'a117',
  'a092',
  'a049',
  'a066',
  'a118',
  'a051',
  'a116',
  'a108',
];

/// Kayıtların eylemci ve hedef kullanıcıları.
const List<String> _userIds = [
  'u_burak',
  'u151',
  'u155',
  'u032',
  'u071',
  'u002',
  'u118',
  'u180',
  'u167',
  'u133',
  'u082',
  'u086',
  'u111',
];

/// Kayıtların etkinlikleri.
const List<String> _eventIds = ['e16', 'e03', 'e19'];

/// Demo faaliyet kaydı [id].
ActivityModel act(String id) => ActivityModel.fromJson(
  DemoDataFixture.toFirestoreJson(FirestoreCollections.activity, id),
  id: id,
);

/// `c03` yöneticisi (başkan) oturumu.
SessionState get kActSession =>
    FakeSessionStates.activeManager(kActClubId, role: ClubRole.president);

/// Günlük fake'i.
FakeActivityRepository get actRepo =>
    GetIt.I<ActivityRepository>() as FakeActivityRepository;

/// Fake'leri tohumlar: saat, kulüp, kayıtlar ([entries] ya da demo 16),
/// kullanıcılar ([skipUsers] hariç) ve etkinlikler.
void seedActivity({
  List<ActivityModel>? entries,
  Set<String> skipUsers = const {},
}) {
  (GetIt.I<AppClock>() as FakeAppClock).set(kActNowUtc);
  (GetIt.I<ClubRepository>() as FakeClubRepository).clubs[kActClubId] =
      ClubModelFixtures.byId(kActClubId);
  final users = GetIt.I<UserRepository>() as FakeUserRepository;
  for (final id in _userIds) {
    if (!skipUsers.contains(id)) users.users[id] = UserModelFixtures.byId(id);
  }
  _eventIds
      .map(EventModelFixtures.byId)
      .forEach((GetIt.I<EventRepository>() as FakeEventRepository).put);
  actRepo.entries.addAll(entries ?? kActIds.map(act));
}

/// Okumaların bitmesini bekler.
Future<void> settleActivity() async {
  for (var i = 0; i < 4; i++) {
    await pumpEventQueue();
  }
}

/// Dolu MGT-10 durumu: gerçek ViewModel demo veriyle kurulup okunur (ekran
/// testlerinde `overrideWithBuild` ile verilir). GetIt bu çağrıda sıfırlanır
/// ve bırakılır; `pumpApp` yeniden kurar.
Future<ActivityLogState> loadedActivityState() async {
  await GetIt.I.reset();
  registerDefaultFakes();
  seedActivity();
  final container = createContainer(
    overrides: [
      sessionViewModelProvider.overrideWithBuild(
        (ref, notifier) => kActSession,
      ),
    ],
  );
  final sub = container.listen(
    activityLogViewModelProvider(kActClubId),
    (_, _) {},
  );
  await settleActivity();
  final state = container.read(activityLogViewModelProvider(kActClubId));
  sub.close();
  container.dispose();
  await GetIt.I.reset();
  return state;
}
