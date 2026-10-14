// MGT-04 testlerinin ortak verisi: tasarım yakalaması — `u_burak` (başkan)
// → `c03`. Demo etkinlikler (bugün = `DemoDataFixture.today`): yayında e03
// (13 Eki, 30/30, herkese açık) ve e16 (28 Eki, 11/25, yalnızca üyeler),
// geçmiş e19, taslak e22. Fake'ler `seedManage` ile doldurulur.
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/management/provider/manage_events_state.dart';
import 'package:gu_kulupler/product/navigation/manage_events_tab.dart';

import '../../fixtures/event_model_fixtures.dart';
import 'manage_test_support.dart';

/// `c03`'ün demo etkinlikleri (`startsAt ↓`, repository sırası).
List<EventModel> clubEvents() =>
    EventModelFixtures.ofClub(kManageClubId)
      ..sort((a, b) => b.startsAt.compareTo(a.startsAt));

/// Tasarımdaki dolu durum (ViewModel'in üreteceği biçimde).
ManageEventsState loadedEventsState({
  ClubAccess access = ClubAccess.manager,
  ClubRole? role = ClubRole.president,
  ManageEventsTab tab = ManageEventsTab.published,
  List<EventModel>? events,
}) => ManageEventsState(
  access: access,
  role: role,
  club: kManageClub,
  tab: tab,
  events: events ?? clubEvents(),
);
