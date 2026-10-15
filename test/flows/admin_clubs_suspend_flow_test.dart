// T-39 · Askı → kulüp kartı ve etkinlik gizleme (roadmap testi): süper admin
// ADM-02'den c03'ü askıya alır (`AdminRepository.suspendClub`, sahte depolar
// paylaşılır) → ziyaretçinin CLB-01 listesinde c03 kartı, EVT-01 listesinde
// c03 etkinlikleri (e03) yer almaz; etkinleştirince ikisi geri gelir.
// İstemci süzgeci: `ClubFilters` (askıdaki kulüp girmez, T-17) ve
// `EventListViewModel` havuzu (`!club.isSuspended`, T-24 — PLAN S-5).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/admin/provider/admin_clubs_view_model.dart';
import 'package:gu_kulupler/features/clubs/provider/club_list_view_model.dart';
import 'package:gu_kulupler/features/events/provider/event_list_view_model.dart';

import '../fakes/fake_session_states.dart';
import '../fakes/register_fakes.dart';
import '../features/events/event_list_test_support.dart';
import '../helpers/test_container.dart';

/// Askıya alınan kulüp ve herkese açık yaklaşan etkinliği.
const String _clubId = 'c03';
const String _eventId = 'e03';

void main() {
  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    seedEventList();
  });

  /// [provider]'ı süper admin ([admin]) ya da ziyaretçi oturumuyla okur.
  Future<ProviderContainer> containerFor(
    ProviderListenable<Object?> provider, {
    bool admin = false,
  }) async {
    final container = createContainer(
      overrides: [
        sessionViewModelProvider.overrideWithBuild(
          (ref, notifier) =>
              admin ? FakeSessionStates.activeSuper : FakeSessionStates.active,
        ),
      ],
    );
    addTearDown(container.listen(provider, (_, _) {}).close);
    await pumpEventQueue();
    return container;
  }

  Future<(List<String>, List<String>)> visitorView() async {
    final clubs = await containerFor(clubListViewModelProvider);
    final events = await containerFor(eventListViewModelProvider);
    return (
      [for (final c in clubs.read(clubListViewModelProvider).visible) c.id],
      [
        for (final e
            in events.read(eventListViewModelProvider).upcomingAt(kNowUtc))
          e.id,
      ],
    );
  }

  test('askı → CLB-01 kartı ve EVT-01 etkinliği gizlenir; etkinleştirme → '
      'geri gelir', () async {
    final (clubsBefore, eventsBefore) = await visitorView();
    expect(clubsBefore, contains(_clubId));
    expect(eventsBefore, contains(_eventId));

    final admin = await containerFor(adminClubsViewModelProvider, admin: true);
    final vm = admin.read(adminClubsViewModelProvider.notifier);
    expect(await vm.suspend(_clubId, 'Kural ihlali'), isTrue);

    final (clubsSuspended, eventsSuspended) = await visitorView();
    expect(clubsSuspended, isNot(contains(_clubId)));
    expect(eventsSuspended, isNot(contains(_eventId)));
    expect(eventsSuspended, contains('e01'));

    expect(await vm.activate(_clubId), isTrue);
    final (clubsAfter, eventsAfter) = await visitorView();
    expect(clubsAfter, contains(_clubId));
    expect(eventsAfter, contains(_eventId));
  });
}
