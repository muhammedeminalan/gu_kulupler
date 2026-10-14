// NTF-01 testlerinin ortak verisi: demo verideki Mehmet'in dokuz bildirimi
// (`n004`…`n012`; 4 okunmamış: `n005`, `n007`, `n009`, `n011`) ve adları
// (kulüpler, etkinlikler, gönderiler). Modeller demo veriden kurulur (PLAN
// §9.12 dönüşümü); "şu an" `n009`'dan iki saat sonradır.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/notifications/provider/notifications_state.dart';
import 'package:gu_kulupler/features/notifications/provider/notifications_view_model.dart';

import '../../fakes/fake_club_repository.dart';
import '../../fakes/fake_event_repository.dart';
import '../../fakes/fake_notification_repository.dart';
import '../../fakes/fake_post_repository.dart';
import '../../fakes/fake_session_states.dart';
import '../../fakes/register_fakes.dart';
import '../../fixtures/club_model_fixtures.dart';
import '../../fixtures/demo_data.dart';
import '../../fixtures/event_model_fixtures.dart';
import '../../fixtures/post_model_fixtures.dart';
import '../../helpers/fake_app_clock.dart';
import '../../helpers/test_container.dart';

/// Oturumdaki kullanıcı (`u_mehmet`).
const String kNtfUid = FakeSessionStates.uid;

/// "Şu an": 8 Ekim 2026 19:08:42 İstanbul — `n009` "2 saat önce".
final DateTime kNtfNowUtc = DateTime.utc(2026, 10, 8, 16, 8, 42);

/// Demo bildirimi [id] (zamanlar dosyadaki gibi).
NotificationModel ntf(String id) => NotificationModel.fromJson(
  DemoDataFixture.toFirestoreJson(FirestoreCollections.notifications, id),
  id: id,
);

/// Mehmet'in demo bildirim kimlikleri.
const List<String> kNtfIds = [
  'n004',
  'n005',
  'n006',
  'n007',
  'n008',
  'n009',
  'n010',
  'n011',
  'n012',
];

/// Okunmamış demo bildirimleri.
const Set<String> kNtfUnread = {'n005', 'n007', 'n009', 'n011'};

const List<String> _clubIds = ['c01', 'c05', 'c07'];
const List<String> _eventIds = ['e01', 'e02', 'e07', 'e17', 'e21'];
const List<String> _postIds = ['p01', 'p22'];

/// Fake'leri tohumlar: saat [nowUtc]; bildirimler ([notifications] ya da
/// demo dokuzu) ve adları (kulüpler, etkinlikler, gönderiler).
void seedNotifications({
  List<NotificationModel>? notifications,
  DateTime? nowUtc,
}) {
  (GetIt.I<AppClock>() as FakeAppClock).set(nowUtc ?? kNtfNowUtc);
  final clubs = GetIt.I<ClubRepository>() as FakeClubRepository;
  for (final id in _clubIds) {
    clubs.clubs[id] = ClubModelFixtures.byId(id);
  }
  final events = GetIt.I<EventRepository>() as FakeEventRepository;
  _eventIds.map(EventModelFixtures.byId).forEach(events.put);
  final posts = GetIt.I<PostRepository>() as FakePostRepository;
  _postIds.map(PostModelFixtures.byId).forEach(posts.put);
  final inbox = GetIt.I<NotificationRepository>() as FakeNotificationRepository;
  (notifications ?? kNtfIds.map(ntf)).forEach(inbox.put);
}

/// Gelen kutusu fake'i.
FakeNotificationRepository get ntfInbox =>
    GetIt.I<NotificationRepository>() as FakeNotificationRepository;

/// Oturum [session] ile kurulmuş, akışı dinlenen kap (ilk görüntü ve adlar
/// okunmuş).
Future<ProviderContainer> notificationsContainer({
  SessionState? session,
}) async {
  final container = createContainer(
    overrides: [
      sessionViewModelProvider.overrideWithBuild(
        (ref, notifier) => session ?? FakeSessionStates.active,
      ),
    ],
  )..listen(notificationsViewModelProvider, (_, _) {});
  await settleNotifications();
  return container;
}

/// Akış, tercih ve ad okumalarının bitmesini bekler.
Future<void> settleNotifications() async {
  for (var i = 0; i < 4; i++) {
    await pumpEventQueue();
  }
}

/// Dolu NTF-01 durumu: gerçek ViewModel demo veriyle kurulup okunur
/// (ekran testlerinde `overrideWithBuild` ile verilir). GetIt bu çağrıda
/// sıfırlanır ve bırakılır; `pumpApp` yeniden kurar.
Future<NotificationsState> loadedNotificationsState({
  List<NotificationModel>? notifications,
}) async {
  await GetIt.I.reset();
  registerDefaultFakes();
  seedNotifications(notifications: notifications);
  final container = await notificationsContainer();
  final state = container.read(notificationsViewModelProvider);
  container.dispose();
  await GetIt.I.reset();
  return state;
}
