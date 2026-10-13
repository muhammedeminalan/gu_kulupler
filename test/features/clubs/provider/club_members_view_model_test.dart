// CLB-06 · ClubMembersViewModel: ilk okuma (hata + yeniden dene), sayfalama
// (20 + imleç), çek-yenile, rol süzgeci, arama (Türkçe küçük harf), oturumda
// engellenenlerin süzülmesi, engelle (DLG-13 → TST-09 → Geri al), kullanıcı
// şikayeti (SHT-10 yazımı → DLG-12) — PLAN §12.6.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/clubs/provider/club_members_state.dart';
import 'package:gu_kulupler/features/clubs/provider/club_members_view_model.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/report_reason_sheet.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/mixin/block_user_mixin.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';
import 'package:gu_ui/gu_ui.dart' show TurkishCaseX;

import '../../../fakes/fake_block_repository.dart';
import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_membership_repository.dart';
import '../../../fakes/fake_report_repository.dart';
import '../../../fakes/fake_user_repository.dart';
import '../../../fakes/register_fakes.dart';
import '../../../helpers/test_container.dart';
import '../club_members_test_support.dart';

void main() {
  late FakeMembershipRepository memberships;
  late FakeUserRepository users;
  late FakeBlockRepository blocks;
  late FakeReportRepository reports;
  late FakeFeedbackService feedback;
  late FakeConnectivityService connectivity;

  final provider = clubMembersViewModelProvider(kMembersClubId);

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    memberships = GetIt.I<MembershipRepository>() as FakeMembershipRepository;
    users = GetIt.I<UserRepository>() as FakeUserRepository;
    blocks = GetIt.I<BlockRepository>() as FakeBlockRepository;
    reports = GetIt.I<ReportRepository>() as FakeReportRepository;
    feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
    connectivity = GetIt.I<ConnectivityService>() as FakeConnectivityService;
    seedMembers();
  });

  /// [session] oturumuyla, ViewModel'i dinlenen kapsayıcı; [states] verilirse
  /// her state değişimi sırayla eklenir. İlk okuma **bekletilmez**.
  ProviderContainer containerOf({
    SessionState? session,
    List<ClubMembersState>? states,
  }) {
    final container = createContainer(
      overrides: [
        sessionViewModelProvider.overrideWithBuild(
          (ref, notifier) => session ?? membersSession(),
        ),
      ],
    );
    addTearDown(
      container.listen(provider, (_, next) => states?.add(next)).close,
    );
    return container;
  }

  /// İlk okuması bitmiş kapsayıcı (okuma çağrıları sayılmaz).
  Future<ProviderContainer> loaded({
    SessionState? session,
    List<ClubMembersState>? states,
  }) async {
    final container = containerOf(session: session, states: states);
    await pumpEventQueue();
    states?.clear();
    memberships.calls.clear();
    users.calls.clear();
    return container;
  }

  ClubMembersViewModel vmOf(ProviderContainer container) =>
      container.read(provider.notifier);

  ClubMembersState stateOf(ProviderContainer container) =>
      container.read(provider);

  /// Kalan tüm sayfaları okur.
  Future<void> loadAll(ProviderContainer container) async {
    while (stateOf(container).hasMore) {
      await vmOf(container).loadMore();
    }
  }

  group('CLB-06 · ClubMembersViewModel · yükleme', () {
    test('ilk kare iskelet; okuma sonrası kulüp, yöneticiler, danışman ve '
        'üyelerin ilk sayfası; kullanıcı belgeleri toplu okunur', () async {
      final container = containerOf();
      expect(stateOf(container).isFetching, isTrue);
      expect(stateOf(container).visible, isEmpty);

      await pumpEventQueue();
      final state = stateOf(container);
      expect(state.isFetching, isFalse);
      expect(state.isError, isFalse);
      expect(state.club, kMembersClub);
      expect(state.managers, unorderedEquals(kClubManagers));
      expect(state.advisors, kClubAdvisors);
      expect(state.members, hasLength(Limits.pageSize));
      expect(state.hasMore, isTrue);
      expect(memberships.callsTo('listManagers'), hasLength(1));
      expect(memberships.callsTo('listActiveMembers'), hasLength(2));
      expect(users.callsTo('getUsers'), hasLength(1));
      expect(
        state.users.keys,
        containsAll([
          for (final membership in state.visible) membership.userId,
        ]),
      );
      expect(state.groups.map((group) => group.role), [
        ClubRole.president,
        ClubRole.board,
        ClubRole.advisor,
        ClubRole.member,
      ]);
    });

    test('okunamazsa hata; "Yeniden dene" listeyi getirir', () async {
      memberships.failNext(FirestoreError.unavailable);
      final container = containerOf();
      await pumpEventQueue();
      expect(stateOf(container).isError, isTrue);
      expect(stateOf(container).isFetching, isFalse);

      await vmOf(container).fetch();
      expect(stateOf(container).isError, isFalse);
      expect(stateOf(container).members, hasLength(Limits.pageSize));
    });

    test('loadMore sıradaki sayfayı ekler (süren istek yinelenmez); son '
        'sayfada imleç biter ve sayaç gerçek sayıya iner', () async {
      final container = await loaded();
      // Sayfalama sürerken üye grubu kulüp sayacından türetilir.
      expect(
        stateOf(container).groups.last.count,
        kMembersClub.memberCount - kClubManagers.length,
      );

      final vm = vmOf(container);
      await Future.wait([vm.loadMore(), vm.loadMore()]);
      expect(memberships.callsTo('listActiveMembers'), hasLength(1));
      expect(stateOf(container).members, hasLength(Limits.pageSize * 2));
      expect(stateOf(container).isLoadingMore, isFalse);

      await loadAll(container);
      final state = stateOf(container);
      expect(state.hasMore, isFalse);
      expect(state.members, unorderedEquals(kClubMembers));
      expect(state.groups.last.count, kClubMembers.length);
      expect(state.totalCount, kClubMemberships.length);
      expect(state.users.keys, containsAll(kClubUsers.keys));

      memberships.calls.clear();
      await vm.loadMore();
      expect(memberships.calls, isEmpty);
    });

    test('sonraki sayfa okunamazsa liste ve imleç kalır', () async {
      final container = await loaded();
      memberships.failNext(FirestoreError.unavailable);
      await vmOf(container).loadMore();
      final state = stateOf(container);
      expect(state.members, hasLength(Limits.pageSize));
      expect(state.hasMore, isTrue);
      expect(state.isLoadingMore, isFalse);
      expect(state.isError, isFalse);
    });

    test('çek-yenile iskelet göstermeden baştan okur; okunamazsa içerik '
        'kalır', () async {
      final states = <ClubMembersState>[];
      final container = await loaded(states: states);
      await vmOf(container).loadMore();
      states.clear();

      await vmOf(container).refresh();
      expect(states.any((state) => state.isFetching), isFalse);
      expect(states.first.isRefreshing, isTrue);
      expect(stateOf(container).isRefreshing, isFalse);
      expect(stateOf(container).members, hasLength(Limits.pageSize));

      memberships.failNext(FirestoreError.unavailable);
      await vmOf(container).refresh();
      expect(stateOf(container).isError, isFalse);
      expect(stateOf(container).members, hasLength(Limits.pageSize));
    });
  });

  group('CLB-06 · ClubMembersViewModel · süzgeç ve arama', () {
    test('rol süzgeci: "Yönetim" başkan + yönetim kurulu, "Üye" yalnızca '
        'üyeler; üyeler ada göre sıralı', () async {
      final container = await loaded();
      await loadAll(container);
      final vm = vmOf(container)..setRoleFilter(MemberRoleFilter.board);
      expect(stateOf(container).visible, unorderedEquals(kClubManagers));
      expect(stateOf(container).visible.first.role, ClubRole.president);
      expect(stateOf(container).wantsMore, isFalse);

      vm.setRoleFilter(MemberRoleFilter.member);
      final state = stateOf(container);
      expect(state.visible, unorderedEquals(kClubMembers));
      final names = [
        for (final membership in state.visible)
          state.nameOf(membership).trLower(),
      ];
      expect(names, [...names]..sort());

      vm.setRoleFilter(MemberRoleFilter.all);
      expect(stateOf(container).visible, hasLength(kClubMemberships.length));
    });

    test(
      'arama adı Türkçe küçük harfle süzer; eşleşme yoksa liste boş',
      () async {
        final container = await loaded();
        await loadAll(container);
        final target = kClubUsers[kBoardMember.userId]!;
        vmOf(container).setQuery('  ${target.name.trUpper()} ');
        final state = stateOf(container);
        expect(state.visible, isNotEmpty);
        expect(state.visible, contains(kBoardMember));
        expect(
          state.visible.every(
            (membership) => state
                .nameOf(membership)
                .trLower()
                .contains(target.name.trLower()),
          ),
          isTrue,
        );
        expect(state.totalCount, state.visible.length);

        vmOf(container).setQuery('qqqq');
        expect(stateOf(container).visible, isEmpty);
        expect(stateOf(container).groups, isEmpty);
      },
    );
  });

  group('CLB-06 · ClubMembersViewModel · engelleme', () {
    final blockedId = kOtherMember.userId;

    test('oturumda engellenen kullanıcı listeden süzülür; oturum değişince '
        'liste güncellenir', () async {
      final container = await loaded(
        session: membersSession(blocked: {blockedId, kBoardMember.userId}),
      );
      await loadAll(container);
      final ids = stateOf(container).visible.map((m) => m.userId);
      expect(ids, isNot(contains(blockedId)));
      expect(ids, isNot(contains(kBoardMember.userId)));
      expect(stateOf(container).totalCount, kClubMemberships.length - 2);

      container.read(sessionViewModelProvider.notifier).state =
          membersSession();
      expect(
        stateOf(container).visible,
        hasLength(kClubMemberships.length),
      );
    });

    test('engelle: DLG-13 onayı → satır kaybolur, engel yazılır, TST-09; '
        '"Geri al" → satır geri gelir (soft delete)', () async {
      final container = await loaded();
      await loadAll(container);
      feedback.dialogResults[DialogId.dlg13] = true;

      await vmOf(container).block(blockedId);
      await pumpEventQueue();
      var state = stateOf(container);
      expect(feedback.dialogs, [DialogId.dlg13]);
      expect(blocks.callsTo('block').single.args, [kMembersUid, blockedId]);
      expect(state.blockedUserIds, contains(blockedId));
      expect(state.visible.map((m) => m.userId), isNot(contains(blockedId)));
      expect(
        state.pendingUndo,
        BlockUndo(userId: blockedId, name: kClubUsers[blockedId]!.name),
      );
      expect(feedback.toasts, [ToastId.tst09]);
      // Oturumdaki engel kümesi sunucudan yeniden okunur.
      expect(
        container.read(sessionViewModelProvider).blockedUserIds,
        contains(blockedId),
      );

      feedback.tapToastAction();
      await pumpEventQueue();
      state = stateOf(container);
      expect(blocks.callsTo('softDeleteBlock'), hasLength(1));
      expect(state.blockedUserIds, isNot(contains(blockedId)));
      expect(state.visible.map((m) => m.userId), contains(blockedId));
      expect(state.pendingUndo, isNull);
      expect(
        container.read(sessionViewModelProvider).blockedUserIds,
        isNot(contains(blockedId)),
      );
    });

    test('vazgeçilirse yazılmaz; yazılamazsa satır geri gelir + TST-24; '
        'çevrimdışıyken yazılmaz', () async {
      final container = await loaded();
      await vmOf(container).block(blockedId);
      expect(blocks.callsTo('block'), isEmpty);
      expect(stateOf(container).blockedUserIds, isEmpty);

      feedback.dialogResults[DialogId.dlg13] = true;
      blocks.failNext(FirestoreError.unavailable);
      await vmOf(container).block(blockedId);
      expect(stateOf(container).blockedUserIds, isEmpty);
      expect(stateOf(container).pendingUndo, isNull);
      expect(feedback.toasts, [ToastId.tst24]);

      blocks.calls.clear();
      connectivity.isOffline = true;
      await vmOf(container).block(blockedId);
      expect(blocks.callsTo('block'), isEmpty);
      expect(feedback.toasts, [ToastId.tst24, ToastId.tst24]);
    });
  });

  group('CLB-06 · ClubMembersViewModel · şikayet', () {
    final target = kOtherMember.userId;

    test('kullanıcı şikayeti yazılır (kulüpsüz hedef); DLG-12 "… engelle" '
        '→ DLG-13', () async {
      final container = await loaded();
      final vm = vmOf(container);
      final report = ReportReasonResult(
        target: vm.reportTargetOf(target),
        reason: ReportReason.spam,
      );
      expect(report.target, (
        type: ReportTargetType.user,
        id: target,
        clubId: null,
      ));
      expect(await vm.submitReport(report), isTrue);
      expect(reports.reports, hasLength(1));
      // Aynı kullanıcı yeniden bildirilirse de sheet kapanır.
      expect(await vm.submitReport(report), isTrue);

      // DLG-12: "Tamam" → true, "… engelle" → false.
      feedback.dialogResults[DialogId.dlg12] = false;
      await vm.showReportReceived(target);
      expect(feedback.dialogs, [DialogId.dlg12, DialogId.dlg13]);
      expect(blocks.callsTo('block'), isEmpty);
    });

    test('yazılamazsa sheet açık kalır: çevrimdışı / ağ → TST-24, yetki yok '
        '→ TST-X18', () async {
      final container = await loaded();
      final vm = vmOf(container);
      final report = ReportReasonResult(
        target: vm.reportTargetOf(target),
        reason: ReportReason.spam,
      );
      reports.failNext(FirestoreError.permissionDenied);
      expect(await vm.submitReport(report), isFalse);
      connectivity.isOffline = true;
      expect(await vm.submitReport(report), isFalse);
      expect(feedback.toasts, [ToastId.tstX18, ToastId.tst24]);
      expect(reports.reports, isEmpty);
    });
  });
}
