// CLB-01 · ClubListViewModel: ilk okuma (hata + yeniden dene), çek-yenile,
// kategori / süzgeç / sıralama / görünüm, oturumdan üyelikler (canlı),
// yönetici önizlemesi (kulüp başına tek okuma), katılım akışı (TST-X1,
// bekleme, SHT-05 gereği, iyimser anında katılım TST-34, geri alma TST-24 /
// TST-X18), art arda tetikleme (PLAN §12.6).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/clubs/provider/club_filters.dart';
import 'package:gu_kulupler/features/clubs/provider/club_list_state.dart';
import 'package:gu_kulupler/features/clubs/provider/club_list_view_model.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/mixin/club_join_mixin.dart'
    show JoinOutcome;
import 'package:gu_kulupler/product/service/connectivity_service.dart';

import '../../../fakes/fake_club_repository.dart';
import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_membership_repository.dart';
import '../../../fakes/fake_session_states.dart';
import '../../../fakes/register_fakes.dart';
import '../../../helpers/test_container.dart';
import '../club_list_test_support.dart';

/// TST-X4 tarih biçimleyicisinin test karşılığı.
String _formatDate(DateTime instant) => 'D:${instant.toIso8601String()}';

void main() {
  late FakeClubRepository clubs;
  late FakeMembershipRepository memberships;
  late FakeFeedbackService feedback;
  late FakeConnectivityService connectivity;

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    clubs = GetIt.I<ClubRepository>() as FakeClubRepository;
    memberships = GetIt.I<MembershipRepository>() as FakeMembershipRepository;
    feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
    connectivity = GetIt.I<ConnectivityService>() as FakeConnectivityService;
    seedClubs();
  });

  /// [session] oturumuyla, ViewModel'i dinlenen kapsayıcı; [states] verilirse
  /// her state değişimi sırayla eklenir. İlk okuma **bekletilmez**.
  ProviderContainer containerOf(
    SessionState session, {
    List<ClubListState>? states,
  }) {
    final container = createContainer(
      overrides: [
        sessionViewModelProvider.overrideWithBuild((ref, notifier) => session),
      ],
    );
    addTearDown(
      container
          .listen(clubListViewModelProvider, (_, next) => states?.add(next))
          .close,
    );
    return container;
  }

  /// İlk okuması bitmiş kapsayıcı (okuma çağrıları sayılmaz).
  Future<ProviderContainer> loaded(
    SessionState session, {
    List<ClubListState>? states,
  }) async {
    final container = containerOf(session, states: states);
    await pumpEventQueue();
    states?.clear();
    clubs.calls.clear();
    memberships.calls.clear();
    return container;
  }

  ClubListViewModel vmOf(ProviderContainer container) =>
      container.read(clubListViewModelProvider.notifier);

  ClubListState stateOf(ProviderContainer container) =>
      container.read(clubListViewModelProvider);

  void setSession(ProviderContainer container, SessionState session) =>
      container.read(sessionViewModelProvider.notifier).state = session;

  Future<JoinOutcome> join(ProviderContainer container, String clubId) =>
      vmOf(container).join(clubId, formatDate: _formatDate);

  int countOf(ProviderContainer container, String clubId) =>
      stateOf(container).clubById(clubId)!.memberCount;

  group('CLB-01 · ClubListViewModel · yükleme', () {
    test('ilk kare iskelet; okuma sonrası tüm kulüpler, görünen liste '
        'askıdakini atar ve üye sayısına göre sıralıdır', () async {
      final container = containerOf(kVisitorSession);
      expect(stateOf(container).isFetching, isTrue);
      expect(stateOf(container).clubs, isEmpty);

      await pumpEventQueue();
      final state = stateOf(container);
      expect(state.isFetching, isFalse);
      expect(state.isError, isFalse);
      expect(state.clubs, hasLength(kAllClubs.length));
      expect(state.visible, hasLength(kActiveClubCount));
      expect(state.visible.first.id, kApprovalClubId);
      expect(clubs.callsTo('fetchActiveClubs'), hasLength(1));
    });

    test('okunamazsa hata görünümü; fetch() yeniden dener', () async {
      clubs.failNext(FirestoreError.unavailable);
      final container = containerOf(kVisitorSession);
      await pumpEventQueue();
      expect(stateOf(container).isError, isTrue);
      expect(stateOf(container).isFetching, isFalse);

      final states = <ClubListState>[];
      container.listen(
        clubListViewModelProvider,
        (_, next) => states.add(next),
      );
      await vmOf(container).fetch();
      expect(states.first.isFetching, isTrue);
      expect(states.first.isError, isFalse);
      expect(stateOf(container).isError, isFalse);
      expect(stateOf(container).clubs, hasLength(kAllClubs.length));
    });

    test(
      'refresh: iskelet göstermeden yeniler; okunamazsa içerik kalır',
      () async {
        final states = <ClubListState>[];
        final container = await loaded(kVisitorSession, states: states);
        clubs.clubs.remove(kSuspendedClubId);
        await vmOf(container).refresh();
        expect(states.map((s) => s.isFetching), everyElement(isFalse));
        expect(states.first.isRefreshing, isTrue);
        expect(stateOf(container).isRefreshing, isFalse);
        expect(stateOf(container).clubs, hasLength(kAllClubs.length - 1));

        clubs.failNext(FirestoreError.unavailable);
        await vmOf(container).refresh();
        expect(stateOf(container).isError, isFalse);
        expect(stateOf(container).clubs, hasLength(kAllClubs.length - 1));
      },
    );

    test('refresh: içerik yokken okunamazsa hata görünümü', () async {
      clubs.clubs.clear();
      final container = await loaded(kVisitorSession);
      clubs.failNext(FirestoreError.unavailable);
      await vmOf(container).refresh();
      expect(stateOf(container).isError, isTrue);
    });
  });

  group('CLB-01 · ClubListViewModel · süzgeç ve görünüm', () {
    test('setCategory: tek kategori seçer; aynı çip seçimi kaldırır; '
        '"Tümü" temizler', () async {
      final container = await loaded(kVisitorSession);
      final vm = vmOf(container)..setCategory('k04');
      expect(stateOf(container).filters.categoryIds, {'k04'});
      expect(stateOf(container).activeFilterCount, 1);
      expect(
        stateOf(container).visible.map((club) => club.categoryId).toSet(),
        {'k04'},
      );

      vm.setCategory('k01');
      expect(stateOf(container).filters.categoryIds, {'k01'});
      vm.setCategory('k01');
      expect(stateOf(container).filters, ClubFilters.none);

      vm
        ..setCategory('k07')
        ..setCategory(null);
      expect(stateOf(container).filters, ClubFilters.none);
    });

    test(
      'setFilters / countFor / clearFilters: SHT-04 süzgeci ve sıralaması',
      () async {
        final container = await loaded(kVisitorSession);
        final vm = vmOf(container);
        const filters = ClubFilters(instantOnly: true, sort: ClubSort.az);
        final instant = kAllClubs
            .where((c) => c.status == ClubStatus.active && !c.approvalRequired)
            .length;
        expect(vm.countFor(filters), instant);
        expect(stateOf(container).filters, ClubFilters.none);

        vm.setFilters(filters);
        final visible = stateOf(container).visible;
        expect(visible, hasLength(instant));
        expect(
          visible.map((c) => c.nameLower),
          [
            ...visible.map((c) => c.nameLower),
          ]..sort(),
        );
        expect(stateOf(container).activeFilterCount, 2);

        vm.clearFilters();
        expect(stateOf(container).filters, ClubFilters.none);
        expect(stateOf(container).visible, hasLength(kActiveClubCount));
      },
    );

    test('toggleLayout: liste ↔ ızgara', () async {
      final container = await loaded(kVisitorSession);
      vmOf(container).toggleLayout();
      expect(stateOf(container).layout, ClubListLayout.grid);
      vmOf(container).toggleLayout();
      expect(stateOf(container).layout, ClubListLayout.list);
    });

    test(
      'üye kulüpler oturumdan canlı gelir: "Üye olduklarım" süzgeci',
      () async {
        final container = await loaded(kVisitorSession);
        vmOf(container).setFilters(
          const ClubFilters(membership: ClubMembershipFilter.mine),
        );
        expect(stateOf(container).visible, isEmpty);

        setSession(container, kMemberSession);
        await pumpEventQueue();
        // Bekleyen (c06) ve reddedilen (c05) üyelik sayılmaz.
        expect(stateOf(container).memberClubIds, {'c01', 'c07'});
        expect(stateOf(container).visible.map((c) => c.id).toSet(), {
          'c01',
          'c07',
        });
      },
    );
  });

  group('CLB-01 · ClubListViewModel · yönetici önizlemesi (CD-139)', () {
    test('loadPreview: başkan önde; kulüp başına tek okuma', () async {
      final container = await loaded(kVisitorSession);
      final vm = vmOf(container);
      await Future.wait([
        vm.loadPreview(kApprovalClubId),
        vm.loadPreview(kApprovalClubId),
      ]);
      expect(stateOf(container).managerPreviews[kApprovalClubId], kManagers);

      await vm.loadPreview(kApprovalClubId);
      expect(memberships.callsTo('listManagers'), hasLength(1));
    });

    test('okunamazsa önizleme yok; sonraki istekte yeniden denenir', () async {
      final container = await loaded(kVisitorSession);
      memberships.failNext(FirestoreError.permissionDenied);
      await vmOf(container).loadPreview(kApprovalClubId);
      expect(stateOf(container).managerPreviews, isEmpty);

      await vmOf(container).loadPreview(kApprovalClubId);
      expect(stateOf(container).managerPreviews[kApprovalClubId], kManagers);
    });
  });

  group('CLB-01 · ClubListViewModel · katılım', () {
    test('başvurular kapalı → TST-X1; yazılmaz', () async {
      final container = await loaded(kVisitorSession);
      expect(await join(container, kClosedClubId), JoinOutcome.closed);
      expect(feedback.toasts, [ToastId.tstX1]);
      expect(memberships.calls, isEmpty);
    });

    test('onay gerekli → needsApplication (SHT-05); yazılmaz', () async {
      final container = await loaded(kVisitorSession);
      expect(
        await join(container, kApprovalClubId),
        JoinOutcome.needsApplication,
      );
      expect(feedback.toasts, isEmpty);
      expect(memberships.calls, isEmpty);
    });

    test('yeniden başvuru beklemesi sürüyor → waiting (CLB-05)', () async {
      final base = FakeSessionStates.withMembership(
        kInstantClubId,
        status: MembershipStatus.rejected,
      );
      final container = await loaded(
        base.copyWith(
          user: kUser,
          memberships: {
            kInstantClubId: base.memberships[kInstantClubId]!.copyWith(
              retryAfter: DateTime.utc(2100),
            ),
          },
        ),
      );
      expect(await join(container, kInstantClubId), JoinOutcome.waiting);
      expect(memberships.calls, isEmpty);
    });

    test('bilinmeyen / askıdaki kulüp → failed', () async {
      final container = await loaded(kVisitorSession);
      expect(await join(container, 'yok'), JoinOutcome.failed);
      expect(await join(container, kSuspendedClubId), JoinOutcome.failed);
      expect(feedback.toasts, isEmpty);
    });

    test('onaysız kulüp: kart iyimser "üye" + üye sayısı + 1, TST-34; '
        'oturum üyeliği gösterince iyimser işaret düşer', () async {
      final states = <ClubListState>[];
      final container = await loaded(kVisitorSession, states: states);
      final before = countOf(container, kInstantClubId);
      var opened = 0;

      final pending = vmOf(container).join(
        kInstantClubId,
        formatDate: _formatDate,
        onOpenClub: () => opened++,
      );
      // Yazım bitmeden: iyimser durum.
      expect(stateOf(container).pendingJoinIds, {kInstantClubId});
      expect(countOf(container, kInstantClubId), before + 1);

      expect(await pending, JoinOutcome.joined);
      expect(feedback.toasts, [ToastId.tst34]);
      expect(memberships.callsTo('joinInstant').single.args, [
        kInstantClubId,
        kUid,
        kEmail,
      ]);
      // Oturum henüz üyeliği göstermiyor: kart iyimser kalır.
      expect(stateOf(container).pendingJoinIds, {kInstantClubId});
      expect(countOf(container, kInstantClubId), before + 1);
      feedback.tapToastAction();
      expect(opened, 1);

      setSession(
        container,
        FakeSessionStates.withMembership(kInstantClubId).copyWith(user: kUser),
      );
      await pumpEventQueue();
      expect(stateOf(container).pendingJoinIds, isEmpty);
      expect(stateOf(container).memberClubIds, {kInstantClubId});
    });

    for (final (error, toast) in [
      (FirestoreError.unavailable, ToastId.tst24),
      (FirestoreError.permissionDenied, ToastId.tstX18),
    ]) {
      test(
        'yazılamadı (${error.name}) → geri alınır + ${toast.name}',
        () async {
          final container = await loaded(kVisitorSession);
          final before = countOf(container, kInstantClubId);
          memberships.failNext(error);
          expect(await join(container, kInstantClubId), JoinOutcome.failed);
          expect(feedback.toasts, [toast]);
          expect(stateOf(container).pendingJoinIds, isEmpty);
          expect(countOf(container, kInstantClubId), before);
        },
      );
    }

    test('sunucu: başvurular bu arada kapanmış → geri alınır, TST-X1, liste '
        'yenilenir', () async {
      final container = await loaded(kVisitorSession);
      final before = countOf(container, kInstantClubId);
      clubs.clubs[kInstantClubId] = clubOf(
        kInstantClubId,
      ).copyWith(applicationsOpen: false);

      expect(await join(container, kInstantClubId), JoinOutcome.closed);
      await pumpEventQueue();
      expect(feedback.toasts, [ToastId.tstX1]);
      expect(stateOf(container).pendingJoinIds, isEmpty);
      expect(countOf(container, kInstantClubId), before);
      expect(
        stateOf(container).clubById(kInstantClubId)!.applicationsOpen,
        isFalse,
      );
    });

    test('çevrimdışı → TST-24; sunucuya gidilmez', () async {
      final container = await loaded(kVisitorSession);
      connectivity.isOffline = true;
      expect(await join(container, kInstantClubId), JoinOutcome.failed);
      expect(feedback.toasts, [ToastId.tst24]);
      expect(memberships.calls, isEmpty);
      expect(stateOf(container).pendingJoinIds, isEmpty);
    });

    test('art arda dokunma: tek katılım yazılır', () async {
      final container = await loaded(kVisitorSession);
      final results = await Future.wait([
        join(container, kInstantClubId),
        join(container, kInstantClubId),
      ]);
      expect(results, [JoinOutcome.joined, JoinOutcome.failed]);
      expect(memberships.callsTo('joinInstant'), hasLength(1));
    });

    test(
      'showJoined (SHT-05 katılımla kapandı): TST-34 + liste yenilenir',
      () async {
        final container = await loaded(kVisitorSession);
        vmOf(container).showJoined();
        await pumpEventQueue();
        expect(feedback.toasts, [ToastId.tst34]);
        expect(clubs.callsTo('fetchActiveClubs'), hasLength(1));
      },
    );
  });
}
