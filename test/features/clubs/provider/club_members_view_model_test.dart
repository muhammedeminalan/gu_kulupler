// CLB-06 · ClubMembersViewModel: ilk okuma (hata + yeniden dene), sayfalama
// (20 + imleç), çek-yenile, rol süzgeci, arama (Türkçe küçük harf), oturumda
// engellenenlerin süzülmesi, yönetici menüsü (SHT-21 → profil /
// SHT-22 → DLG-20 / DLG-19 → TST-47 → Geri al; W-20) — PLAN §12.6.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/clubs/provider/club_members_state.dart';
import 'package:gu_kulupler/features/clubs/provider/club_members_view_model.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/member_actions_sheet.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/mixin/manage_member_actions_mixin.dart';
import 'package:gu_ui/gu_ui.dart' show TurkishCaseX;

import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_management_repository.dart';
import '../../../fakes/fake_membership_repository.dart';
import '../../../fakes/fake_user_repository.dart';
import '../../../fakes/register_fakes.dart';
import '../../../helpers/test_container.dart';
import '../club_members_test_support.dart';

void main() {
  late FakeMembershipRepository memberships;
  late FakeUserRepository users;
  late FakeFeedbackService feedback;

  final provider = clubMembersViewModelProvider(kMembersClubId);

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    memberships = GetIt.I<MembershipRepository>() as FakeMembershipRepository;
    users = GetIt.I<UserRepository>() as FakeUserRepository;
    feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
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

  group('CLB-06 · ClubMembersViewModel · engellenenler', () {
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
  });

  group('CLB-06 · ClubMembersViewModel · yönetici menüsü (SHT-21, W-20)', () {
    FakeManagementRepository management() =>
        GetIt.I<ManagementRepository>() as FakeManagementRepository;

    bool listed(ProviderContainer container, String userId) => stateOf(
      container,
    ).visible.any((m) => m.userId == userId);

    test('"Profili gör" view\'a döner; yazım yok', () async {
      final container = await loaded(
        session: membersSession(role: ClubRole.board),
      );
      feedback.nextSheetResult = MemberAction.viewProfile;
      final outcome = await vmOf(container).openMemberMenu(kOtherMember);
      expect(outcome, MemberMenuOutcome.viewProfile);
      expect(feedback.sheets, [SheetId.sht21]);
      expect(management().calls, isEmpty);
    });

    test('yönetim kurulu üyeyi çıkarır: DLG-19 → satır iyimser düşer → '
        'TST-47; "Geri al" satırı geri getirir', () async {
      final container = await loaded(
        session: membersSession(role: ClubRole.board),
      );
      final userId = kOtherMember.userId;
      feedback
        ..nextSheetResult = MemberAction.remove
        ..dialogResults[DialogId.dlg19] = '';
      final outcome = await vmOf(container).openMemberMenu(kOtherMember);
      expect(outcome, MemberMenuOutcome.removed);
      expect(feedback.dialogs, [DialogId.dlg19]);
      expect(feedback.toasts, [ToastId.tst47]);
      expect(listed(container, userId), isFalse);
      expect(
        memberships
            .memberships[FirestoreIds.membership(kMembersClubId, userId)]
            ?.status,
        MembershipStatus.removed,
      );

      feedback.tapToastAction();
      await pumpEventQueue();
      expect(management().callsTo('undoRemoval'), hasLength(1));
      expect(listed(container, userId), isTrue);
    });

    test('yazılamazsa satır geri gelir + TST-24', () async {
      final container = await loaded(
        session: membersSession(role: ClubRole.board),
      );
      management().failNext(FirestoreError.unavailable);
      feedback.dialogResults[DialogId.dlg19] = '';
      final removed = await vmOf(container).removeMember(
        kMembersClubId,
        kOtherMember,
        name: 'Üye',
      );
      expect(removed, isFalse);
      expect(feedback.toasts, [ToastId.tst24]);
      expect(listed(container, kOtherMember.userId), isTrue);
    });

    test('yönetim kurulu, yönetim kurulu üyesini çıkaramaz ve rol '
        'değiştiremez → TST-X18 (dialog yok)', () async {
      final container = await loaded(
        session: membersSession(role: ClubRole.board),
      );
      final vm = vmOf(container);
      expect(
        await vm.removeMember(kMembersClubId, kBoardMember, name: 'Y'),
        isFalse,
      );
      expect(
        await vm.changeMemberRole(kMembersClubId, kOtherMember, name: 'Ü'),
        isFalse,
      );
      expect(feedback.dialogs, isEmpty);
      expect(feedback.sheets, isEmpty);
      expect(feedback.toasts, [ToastId.tstX18, ToastId.tstX18]);
      expect(management().calls, isEmpty);
    });

    test('başkan rol değiştirir: SHT-22 → DLG-20 → üye yönetim kurulu '
        'grubuna geçer → TST-46', () async {
      final container = await loaded(
        session: membersSession(role: ClubRole.president),
      );
      feedback
        ..nextSheetResult = ClubRole.board
        ..dialogResults[DialogId.dlg20] = true;
      final changed = await vmOf(
        container,
      ).changeMemberRole(kMembersClubId, kOtherMember, name: 'Ü');
      expect(changed, isTrue);
      expect(feedback.sheets, [SheetId.sht22]);
      expect(feedback.toasts, [ToastId.tst46]);
      final state = stateOf(container);
      expect(
        state.managers.any((m) => m.userId == kOtherMember.userId),
        isTrue,
      );
      expect(
        state.members.any((m) => m.userId == kOtherMember.userId),
        isFalse,
      );
    });
  });
}
