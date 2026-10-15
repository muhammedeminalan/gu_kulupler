// ADM-01 · AdminViewModel: yükleme (KPI'lar kaynakla tutarlı — `stats`
// sayaçları, askıdaki kulüp ve en aktif beş kulüp tek kulüp okumasından),
// grafik (CD-46: son 8 hafta, tüm kulüpler, 8 `count()`, boş hafta 0),
// dönem penceresi ("+x yeni", katılım oranı; okunamazsa önceki çip), hata +
// yeniden dene, `permissionDenied` → claim yenileme + bir kez yineleme
// (CD-160) — PLAN §12 `AdminViewModel`.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/admin/provider/admin_state.dart';
import 'package:gu_kulupler/features/admin/provider/admin_view_model.dart';

import '../../../fakes/fake_activity_repository.dart';
import '../../../fakes/fake_admin_repository.dart';
import '../../../fakes/fake_auth_repository.dart';
import '../../../fakes/fake_auth_service.dart';
import '../../../fakes/fake_event_repository.dart';
import '../../../fakes/register_fakes.dart';
import '../../../fixtures/event_model_fixtures.dart';
import '../../../helpers/test_container.dart';
import '../admin_test_support.dart';

void main() {
  late FakeAdminRepository admin;
  late FakeActivityRepository activity;
  late FakeEventRepository events;

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    admin = GetIt.I<AdminRepository>() as FakeAdminRepository;
    activity = GetIt.I<ActivityRepository>() as FakeActivityRepository;
    events = GetIt.I<EventRepository>() as FakeEventRepository;
    seedAdmin();
    // Saat: 12 Ekim 2026 Pazartesi 19:30 Istanbul (kDefaultFakeNowUtc).
    activity.entries.addAll([
      for (final (id, kind, at) in [
        ('a1', ActivityKind.memberJoined, DateTime.utc(2026, 10, 12, 10)),
        ('a2', ActivityKind.applicationApproved, DateTime.utc(2026, 10, 1, 9)),
        ('a3', ActivityKind.memberJoined, DateTime.utc(2026, 9, 5)),
        ('a4', ActivityKind.memberLeft, DateTime.utc(2026, 10, 10)),
        ('a5', ActivityKind.memberJoined, DateTime.utc(2026, 8, 10)),
        ('a6', ActivityKind.memberJoined, DateTime.utc(2026, 8, 20)),
      ])
        ActivityModel(
          id: id,
          clubId: id == 'a3' ? 'c10' : 'c01',
          actorId: 'u1',
          kind: kind,
          createdAt: at,
        ),
    ]);
    final template = EventModelFixtures.byId('e03').copyWith(
      visibility: EventVisibility.public,
      isDeleted: false,
    );
    for (final (id, status, start, going, attended) in [
      ('ev1', EventStatus.published, DateTime.utc(2026, 10, 1, 15), 10, 7),
      ('ev2', EventStatus.cancelled, DateTime.utc(2026, 10, 8, 15), 9, 0),
      ('ev3', EventStatus.published, DateTime.utc(2026, 10, 20, 15), 30, 0),
      ('ev4', EventStatus.published, DateTime.utc(2026, 9, 5, 15), 4, 4),
    ]) {
      events.put(
        template.copyWith(
          id: id,
          status: status,
          startsAt: start,
          endsAt: start.add(const Duration(hours: 2)),
          goingCount: going,
          attendedCount: attended,
        ),
      );
    }
  });

  Future<ProviderContainer> loaded() async {
    final container = createContainer(
      overrides: [
        sessionViewModelProvider.overrideWithBuild(
          (ref, notifier) => kAdminSession,
        ),
      ],
    );
    addTearDown(container.listen(adminViewModelProvider, (_, _) {}).close);
    await pumpEventQueue();
    return container;
  }

  AdminViewModel vm(ProviderContainer c) =>
      c.read(adminViewModelProvider.notifier);

  group('ADM-01 · AdminViewModel · yükleme', () {
    test('KPI kaynakla tutarlı: stats sayaçları, askıdaki kulüp, en aktif '
        'beş etkin kulüp (memberCount ↓); grafik 8 hafta, boş hafta 0; '
        '30 gün "+x yeni" ve katılım', () async {
      final container = await loaded();
      final state = container.read(adminViewModelProvider);

      expect(state.isLoaded, isTrue);
      expect(state.isFetching, isFalse);
      expect(state.isError, isFalse);
      expect(state.range, AdminRange.days30);
      expect(state.stats, kDesignStats);
      expect(state.suspendedClubCount, 1);
      expect(state.topClubs.map((c) => c.id), kTopClubIds);
      expect(
        state.topClubs.map((c) => c.memberCount),
        [231, 204, 188, 157, 142],
      );
      // Kovalar 17 Ağu 21:00Z'den haftalık: a6 → 0, a3 → 2, a2 → 6, a1 → 7.
      expect(state.chart, [1, 0, 1, 0, 0, 0, 1, 1]);
      final chartCall = activity.callsTo('countByWeek').first.args;
      expect(chartCall[0], AdminViewModel.growthKinds);
      expect(chartCall[1], DateTime.utc(2026, 8, 17, 21));
      expect(chartCall[2], AdminViewModel.chartWeeks);
      expect(state.newCount, 2);
      expect(
        state.attendance,
        const AdminAttendance(eventCount: 1, registered: 10, attended: 7),
      );
      expect(state.attendance.rate, 70);
      expect(admin.callsTo('stats'), hasLength(1));
    });

    test('dönem çipi: 7 gün → yalnızca bu haftanın kayıtları; Dönem → 1 '
        "Eylül'den beri", () async {
      final container = await loaded();

      await vm(container).selectRange(AdminRange.days7);
      var state = container.read(adminViewModelProvider);
      expect(state.range, AdminRange.days7);
      expect(state.newCount, 1);
      expect(state.attendance, const AdminAttendance());

      await vm(container).selectRange(AdminRange.term);
      state = container.read(adminViewModelProvider);
      expect(state.range, AdminRange.term);
      expect(state.newCount, 3);
      expect(
        state.attendance,
        const AdminAttendance(eventCount: 2, registered: 14, attended: 11),
      );
      expect(
        vm(container).rangeStart(AdminRange.term, kDefaultFakeNowUtc),
        DateTime.utc(2026, 8, 31, 21),
      );
      // KPI sayaçları yeniden okunmaz.
      expect(admin.callsTo('stats'), hasLength(1));
    });

    test('dönem verisi okunamazsa önceki çipe döner', () async {
      final container = await loaded();
      activity.failNext(FirestoreError.unavailable);

      await vm(container).selectRange(AdminRange.days7);

      final state = container.read(adminViewModelProvider);
      expect(state.range, AdminRange.days30);
      expect(state.newCount, 2);
    });
  });

  group('ADM-01 · AdminViewModel · hata', () {
    test('ilk okuma başarısız → hata; "Yeniden dene" → dolu', () async {
      admin.failNext(FirestoreError.unavailable);
      final container = await loaded();
      expect(container.read(adminViewModelProvider).isError, isTrue);

      await vm(container).fetch();

      final state = container.read(adminViewModelProvider);
      expect(state.isError, isFalse);
      expect(state.stats, kDesignStats);
    });

    test('çek-yenile hatası eski içeriği korur', () async {
      final container = await loaded();
      admin.failNext(FirestoreError.unavailable);

      await vm(container).refresh();

      final state = container.read(adminViewModelProvider);
      expect(state.isError, isFalse);
      expect(state.isRefreshing, isFalse);
      expect(state.stats, kDesignStats);
    });

    test('permissionDenied → claim yenilenir; hâlâ süper admin → bir kez '
        'yinelenir (CD-160)', () async {
      final auth = GetIt.I<AuthRepository>() as FakeAuthRepository;
      _signIn();
      auth.isSuperAdminResult = true;
      admin.failNext(FirestoreError.permissionDenied);

      final container = await loaded();

      final state = container.read(adminViewModelProvider);
      expect(state.isError, isFalse);
      expect(state.stats, kDesignStats);
      expect(admin.callsTo('stats'), hasLength(2));
      expect(auth.callsTo('isSuperAdmin').single.args, [true]);
    });

    test('permissionDenied + claim geri alınmış → yinelenmez, hata; oturum '
        'süper admin değil (guard sekmeyi kapatır)', () async {
      final auth = GetIt.I<AuthRepository>() as FakeAuthRepository;
      _signIn();
      auth.isSuperAdminResult = false;
      admin.failNext(FirestoreError.permissionDenied);

      final container = await loaded();

      expect(container.read(adminViewModelProvider).isError, isTrue);
      expect(container.read(sessionViewModelProvider).isSuperAdmin, isFalse);
      expect(admin.callsTo('stats'), hasLength(1));
    });
  });
}

/// Fake Auth'ta oturumu açar (claim okuması `sessionExpired` dönmesin).
void _signIn() {
  (GetIt.I<AuthService>() as FakeAuthService).currentUser = const AuthUserInfo(
    uid: 'u_admin',
    email: 'admin@ogr.gumushane.edu.tr',
    emailVerified: true,
    displayName: 'Admin',
  );
}
