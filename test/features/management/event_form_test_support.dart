// MGT-05 testlerinin ortak verisi: tasarım yakalamasındaki görünüm —
// `u_burak` (başkan) → `c03` "Etkinlik oluştur" (yeni etkinlik, 1. adım).
// Düzenleme kipi için demo verideki `c03` etkinlikleri: `e22` (taslak),
// `e03` (yayında, 30 kayıtlı) ve ondan türetilen başlamış etkinlik.
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/management/provider/event_form_state.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';

import '../../fakes/fake_app_preferences_store.dart';
import '../../fakes/fake_club_repository.dart';
import '../../fakes/fake_event_repository.dart';
import '../../fakes/register_fakes.dart';
import '../../fixtures/event_model_fixtures.dart';
import 'manage_test_support.dart';

/// `e22` — `c03`'ün kontenjansız, üyelere özel taslağı.
final EventModel kDraftEvent = EventModelFixtures.e22;

/// `e03` — `c03`'ün yayındaki, kontenjanı dolu (30 / 30) etkinliği.
final EventModel kPublishedEvent = EventModelFixtures.e03;

/// `e03`'ün bir saat önce başlamış, bir saat sonra bitecek kopyası (W-82).
final EventModel kStartedEvent = kPublishedEvent.copyWith(
  id: 'e_started',
  startsAt: kDefaultFakeNowUtc.subtract(const Duration(hours: 1)),
  endsAt: kDefaultFakeNowUtc.add(const Duration(hours: 1)),
);

/// `e03`'ün kayıtsız kopyası (taslağa alınabilir — K-F).
final EventModel kEmptyPublishedEvent = kPublishedEvent.copyWith(
  id: 'e_empty',
  goingCount: 0,
  waitlistCount: 0,
);

/// Yeni etkinliğin varsayılan başlangıcı: saatin bugününden 7 gün sonra
/// 18:00 Istanbul (`kDefaultFakeNowUtc` = 12 Ekim 2026 19:30 Istanbul).
final DateTime kDefaultStart = DateTime.utc(2026, 10, 19, 15);

/// Tasarımdaki dolu durum (ViewModel'in yeni etkinlikte üreteceği biçimde):
/// kulüp okunmuş, kapak kulübün paletinde.
EventFormState newEventState({EventFormStep step = EventFormStep.basics}) =>
    EventFormState(
      step: step,
      club: kManageClub,
      coverPalette: kManageClub.palette,
      startsAt: kDefaultStart,
      endsAt: kDefaultStart.add(EventFormState.defaultDuration),
    );

/// [newEventState] + doldurulmuş zorunlu alanlar (2. ve 3. adım için).
EventFormState filledEventState({EventFormStep step = EventFormStep.basics}) =>
    newEventState(step: step).copyWith(
      title: 'Ilgaz Kayak Günü',
      desc: 'Kayak ekipmanı kulüpten.',
      placeId: 'pl09',
      isDirty: true,
    );

/// Kayıtlı fake'lere `c03` kulübünü ve etkinliklerini (başlamış ve kayıtsız
/// kopyalar dahil) yazar; galeri ön açıklamasını (DLG-05) onaylanmış sayar.
void seedEventForm() {
  (GetIt.I<ClubRepository>() as FakeClubRepository).clubs[kManageClubId] =
      kManageClub;
  final events = GetIt.I<EventRepository>() as FakeEventRepository;
  EventModelFixtures.ofClub(kManageClubId).forEach(events.put);
  events
    ..put(kStartedEvent)
    ..put(kEmptyPublishedEvent)
    ..calls.clear();
  (GetIt.I<AppPreferencesStore>() as FakeAppPreferencesStore)
          .values[AppPreferenceKeys.photoAccessExplained] =
      true;
}
