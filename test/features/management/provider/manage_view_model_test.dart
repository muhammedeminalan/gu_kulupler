// MGT-01 · ManageViewModel: yükleme (KPI'lar sayaçlarla tutarlı, bekleyen
// toplamı sayfalar boyunca), grafik toplama (CD-46: son 8 hafta, haftalık,
// boş hafta 0), son hareketler + adlar, danışman (salt okunur → TST-26),
// yoklama hedefi (yoksa TST-X12), hata + yeniden dene, çek-yenile — PLAN
// §12.6.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/management/provider/manage_view_model.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';

import '../../../fakes/fake_activity_repository.dart';
import '../../../fakes/fake_club_repository.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_membership_repository.dart';
import '../../../fakes/register_fakes.dart';
import '../../../fixtures/membership_model_fixtures.dart';
import '../../../helpers/test_container.dart';
import '../manage_test_support.dart';

void main() {
  late FakeClubRepository clubs;
  late FakeActivityRepository activity;
  late FakeFeedbackService feedback;
  late AppClock clock;

  final provider = manageViewModelProvider(kManageClubId);

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    clubs = GetIt.I<ClubRepository>() as FakeClubRepository;
    activity = GetIt.I<ActivityRepository>() as FakeActivityRepository;
    feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
    clock = GetIt.I<AppClock>();
  });

  Future<ProviderContainer> loaded({SessionState? session}) async {
    final container = createContainer(
      overrides: [
        sessionViewModelProvider.overrideWithBuild(
          (ref, notifier) => session ?? manageSession(),
        ),
      ],
    );
    addTearDown(container.listen(provider, (_, _) {}).close);
    await pumpEventQueue();
    return container;
  }

  group('yükleme', () {
    test('KPI sayaçlardan: üye = clubs.memberCount (yeniden sayılmaz), '
        'bekleyen = listPending toplamı (sayfalar boyunca), yaklaşan, '
        'bu ay duyuru, bugünkü hak', () async {
      seedManage();
      clubs.clubs[kManageClubId] = kManageClub.copyWith(memberCount: 500);
      final memberships =
          GetIt.I<MembershipRepository>() as FakeMembershipRepository;
      final template = MembershipModelFixtures.byId(
        FirestoreIds.membership(kManageClubId, kManageUid),
      );
      for (var i = 0; i < 25; i++) {
        final uid = 'u_pending_$i';
        memberships.put(
          template.copyWith(
            id: FirestoreIds.membership(kManageClubId, uid),
            userId: uid,
            status: MembershipStatus.pending,
            role: ClubRole.member,
          ),
        );
      }
      final counters = manageCounters();
      counters.counts[counters.keyOf(kManageClubId)] = 1;

      final container = await loaded();
      final state = container.read(provider);
      expect(state.isFetching, isFalse);
      expect(state.isError, isFalse);
      expect(state.club?.id, kManageClubId);
      expect(state.kpis.memberCount, 500);
      expect(state.kpis.pendingCount, 9 + 25);
      expect(state.kpis.upcomingEventCount, 2);
      expect(state.kpis.announcementCount, 1);
      expect(state.announcementsToday, 1);
      expect(state.upcomingEvents.map((e) => e.id), ['e03', 'e16']);
      expect(state.attendanceEventId, 'e03');
      expect(state.hasMembers, isTrue);
      expect(state.showNewClubCard, isFalse);
    });

    test('son hareketler: ilk 5 (tanınmayan tür süzülür) + eylemci / hedef '
        'adları + etkinlik başlığı', () async {
      seedManage();
      activity.entries.add(
        ActivityModel(
          id: 'a_unknown',
          clubId: kManageClubId,
          actorId: kManageUid,
          kind: ActivityKind.unknown,
          createdAt: clock.nowUtc(),
        ),
      );
      final state = (await loaded()).read(provider);
      expect(state.recentActivity.map((a) => a.id), kRecentIds);
      expect(state.lookups.users.keys, containsAll(recentUsers().keys));
      expect(state.lookups.eventTitles['e16'], kUpcomingEvents.last.title);
    });

    test('grafik: son 8 hafta haftalık (member_joined + '
        'application_approved), boş hafta 0; "+x bu ay" aynı kaynak', () async {
      clubs.clubs[kManageClubId] = kManageClub;
      final now = clock.nowUtc();
      ActivityModel entry(String id, ActivityKind kind, Duration ago) =>
          ActivityModel(
            id: id,
            clubId: kManageClubId,
            actorId: 'u_x',
            kind: kind,
            createdAt: now.subtract(ago),
          );
      activity.entries.addAll([
        entry('j1', ActivityKind.memberJoined, const Duration(hours: 1)),
        entry('a1', ActivityKind.applicationApproved, const Duration(days: 2)),
        entry('j2', ActivityKind.memberJoined, const Duration(days: 8)),
        entry(
          'a2',
          ActivityKind.applicationApproved,
          const Duration(days: 30, hours: 1),
        ),
        entry('old', ActivityKind.memberJoined, const Duration(days: 60)),
        entry(
          'r1',
          ActivityKind.applicationReceived,
          const Duration(days: 1),
        ),
        entry('l1', ActivityKind.memberLeft, const Duration(days: 1)),
      ]);

      final state = (await loaded()).read(provider);
      // Varsayılan saat 12 Eki 2026 19:30 (Istanbul): kovalar 17 Ağu 00:00'dan
      // 7'şer gün; son kova bugünü içerir. 1 sa + 2 g → 7, 8 g → 6,
      // 30 g 1 sa → 3; 60 g önce pencere dışı; diğer türler sayılmaz.
      expect(state.chart, [0, 0, 0, 1, 0, 0, 1, 2]);
      expect(state.kpis.joinedThisMonth, 3);
    });

    test('etkinlik yoksa: yoklama → TST-X12, hedef yok; sıradan üye yok → '
        '"Henüz üyen yok" kartı', () async {
      clubs.clubs[kManageClubId] = kManageClub;
      final container = await loaded();
      final state = container.read(provider);
      expect(state.upcomingEvents, isEmpty);
      expect(state.attendanceEventId, isNull);
      expect(state.showNewClubCard, isTrue);
      expect(container.read(provider.notifier).nextAttendanceEventId(), isNull);
      expect(feedback.toasts, [ToastId.tstX12]);
    });

    test('hata → isError; "Yeniden dene" → dolu', () async {
      seedManage();
      clubs.failNext(FirestoreError.unavailable);
      final container = await loaded();
      expect(container.read(provider).isError, isTrue);
      expect(container.read(provider).isFetching, isFalse);
      await container.read(provider.notifier).fetch();
      final state = container.read(provider);
      expect(state.isError, isFalse);
      expect(state.club?.id, kManageClubId);
    });

    test('çek-yenile hatası eski içeriği korur', () async {
      seedManage();
      final container = await loaded();
      clubs.failNext(FirestoreError.unavailable);
      await container.read(provider.notifier).refresh();
      final state = container.read(provider);
      expect(state.isError, isFalse);
      expect(state.isRefreshing, isFalse);
      expect(state.club?.id, kManageClubId);
    });
  });

  group('danışman (Q-09)', () {
    test('salt okunur: yazma → TST-26, false', () async {
      seedManage();
      final container = await loaded(
        session: manageSession(role: ClubRole.advisor),
      );
      final state = container.read(provider);
      expect(state.isReadOnly, isTrue);
      expect(state.showNewClubCard, isFalse);
      expect(container.read(provider.notifier).ensureWritable(), isFalse);
      expect(feedback.toasts, [ToastId.tst26]);
    });

    test('yönetici: yazabilir, toast yok', () async {
      seedManage();
      final container = await loaded();
      expect(container.read(provider).isReadOnly, isFalse);
      expect(container.read(provider.notifier).ensureWritable(), isTrue);
      expect(feedback.toasts, isEmpty);
    });
  });
}
