// MGT-02 · ManageApplicationsViewModel: yükleme (bekleyen + not, W-92
// silinmiş başvuran süzülür), onay (iyimser + TST-27), ret (`retryAfter`
// 7 gün + TST-28), geri al (pencere içi → TST-X17, dışı → yazım yok —
// FakeAppClock), iki yönetici çakışması (DLG-18 + liste yenilenir), toplu
// onay (DLG-17 → `approveMany` → sayaç ve MGT-01 göstergeleri tutarlı),
// danışman (TST-26), başvuruları aç (TST-54) — PLAN §12.6, roadmap T-32.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/management/provider/manage_applications_state.dart';
import 'package:gu_kulupler/features/management/provider/manage_applications_view_model.dart';
import 'package:gu_kulupler/features/management/provider/manage_view_model.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/dialog_spec.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/navigation/applications_tab.dart';

import '../../../fakes/fake_club_repository.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_management_repository.dart';
import '../../../fakes/fake_membership_repository.dart';
import '../../../fakes/fake_user_repository.dart';
import '../../../fakes/register_fakes.dart';
import '../../../helpers/fake_app_clock.dart';
import '../../../helpers/test_container.dart';
import '../applications_test_support.dart';
import '../manage_test_support.dart';

void main() {
  late FakeClubRepository clubs;
  late FakeMembershipRepository memberships;
  late FakeManagementRepository management;
  late FakeFeedbackService feedback;
  late FakeAppClock clock;

  final provider = manageApplicationsViewModelProvider(kManageClubId);

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    clubs = GetIt.I<ClubRepository>() as FakeClubRepository;
    memberships = GetIt.I<MembershipRepository>() as FakeMembershipRepository;
    management = GetIt.I<ManagementRepository>() as FakeManagementRepository;
    feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
    clock = GetIt.I<AppClock>() as FakeAppClock;
    seedApplications();
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

  MembershipStatus statusOf(String uid) => memberships
      .memberships[FirestoreIds.membership(kManageClubId, uid)]!
      .status;

  group('MGT-02 · yükleme', () {
    test('bekleyen 9 başvuru + notlar + kulüp; silinmiş başvuran (W-92) '
        'listelenmez', () async {
      final users = GetIt.I<UserRepository>() as FakeUserRepository;
      users.users['u109'] = users.users['u109']!.copyWith(
        status: UserStatus.deleted,
      );
      final container = await loaded();
      final state = container.read(provider);
      expect(state.isFetching, isFalse);
      expect(state.isError, isFalse);
      expect(state.club?.id, kManageClubId);
      expect(
        state.visible.map((m) => m.userId).toSet(),
        kPendingIds.toSet()..remove('u109'),
      );
      expect(state.pendingCount, kPendingIds.length - 1);
      expect(state.contacts['u_cem']?.note, contactOf('u_cem').note);

      final outcome = await container.read(provider.notifier).approve('u109');
      expect(outcome, DecisionOutcome.blocked);
      expect(management.callsTo('approveApplication'), isEmpty);
    });

    test('okunamadı → hata; "Yeniden dene" → dolu', () async {
      memberships.failNext(FirestoreError.unavailable);
      final container = await loaded();
      expect(container.read(provider).isError, isTrue);
      await container.read(provider.notifier).fetch();
      expect(container.read(provider).isError, isFalse);
      expect(container.read(provider).visible, hasLength(kPendingIds.length));
    });

    test('"Onaylanan" sekmesi: yalnızca karar verilmiş aktif üyeler', () async {
      final container = await loaded();
      container.read(provider.notifier).setTab(ApplicationsTab.approved);
      await pumpEventQueue();
      final state = container.read(provider);
      expect(state.visible, isNotEmpty);
      expect(
        state.visible.every(
          (m) => m.status == MembershipStatus.active && m.decidedAt != null,
        ),
        isTrue,
      );
    });
  });

  group('MGT-02 · Reddedilen sekmesi (W-98)', () {
    test('sekme seçilince sunucudan `listByStatus(rejected)` okunur', () async {
      final container = await loaded();
      container.read(provider.notifier).setTab(ApplicationsTab.rejected);
      await pumpEventQueue();
      final state = container.read(provider);
      final expected = {
        for (final m in clubMemberships())
          if (m.status == MembershipStatus.rejected) m.userId,
      };
      expect(expected, isNotEmpty);
      expect(state.visible.map((m) => m.userId).toSet(), expected);
      expect(memberships.callsTo('listByStatus').single.args, [
        kManageClubId,
        MembershipStatus.rejected,
        const PageRequest(),
      ]);
    });
  });

  group('MGT-02 · onay / ret / geri al', () {
    test('onay: satır anında kalkar → TST-27 (Geri al); üyelik aktif, '
        'memberCount +1', () async {
      final before = clubs.clubs[kManageClubId]!.memberCount;
      final container = await loaded();
      final outcome = await container.read(provider.notifier).approve('u_cem');
      expect(outcome, DecisionOutcome.done);
      final state = container.read(provider);
      expect(state.visible.map((m) => m.userId), isNot(contains('u_cem')));
      expect(state.undoable.keys, contains('u_cem'));
      expect(statusOf('u_cem'), MembershipStatus.active);
      expect(clubs.clubs[kManageClubId]!.memberCount, before + 1);
      expect(feedback.toasts, [ToastId.tst27]);
      expect(feedback.toastParams.single.name, 'Cem Aydın');
      expect(feedback.hasToastAction, isTrue);
    });

    test(
      'TST-28 ret: neden + not yazılır, retryAfter = şimdi + 7 gün',
      () async {
        final container = await loaded();
        final outcome = await container
            .read(provider.notifier)
            .reject('u043', RejectReason.criteria, 'Koşullar');
        expect(outcome, DecisionOutcome.done);
        final m = memberships
            .memberships[FirestoreIds.membership(kManageClubId, 'u043')]!;
        expect(m.status, MembershipStatus.rejected);
        expect(m.rejectReason, RejectReason.criteria);
        expect(m.rejectNote, 'Koşullar');
        expect(m.retryAfter, clock.nowUtc().add(Limits.reapplyCooldown));
        expect(feedback.toasts, [ToastId.tst28]);
      },
    );

    test('TST-X17 geri al pencere içinde: başvuru yeniden beklemede, satır '
        'geri gelir', () async {
      final container = await loaded();
      await container.read(provider.notifier).approve('u_cem');
      clock.advance(const Duration(seconds: 5));
      feedback.tapToastAction();
      await pumpEventQueue();
      expect(management.callsTo('undoDecision'), hasLength(1));
      expect(statusOf('u_cem'), MembershipStatus.pending);
      expect(feedback.toasts.last, ToastId.tstX17);
      final state = container.read(provider);
      expect(state.visible.map((m) => m.userId), contains('u_cem'));
      expect(state.undoable, isEmpty);
    });

    test('geri al pencere dışında (30 sn): yazım yok', () async {
      final container = await loaded();
      await container.read(provider.notifier).approve('u_cem');
      clock.advance(Limits.managerUndoWindow);
      final outcome = await container
          .read(provider.notifier)
          .undoDecision('u_cem');
      expect(outcome, DecisionOutcome.blocked);
      expect(management.callsTo('undoDecision'), isEmpty);
      expect(statusOf('u_cem'), MembershipStatus.active);
      expect(container.read(provider).undoable, isEmpty);
    });

    test('DLG-18 iki yönetici çakışması: başka yönetici onaylamış → '
        'conflict, liste yenilenir', () async {
      final container = await loaded();
      await memberships.approve(
        clubId: kManageClubId,
        userId: 'u039',
        actorId: 'u_other',
      );
      final outcome = await container.read(provider.notifier).approve('u039');
      expect(outcome, DecisionOutcome.conflict);
      expect(feedback.dialogs, [DialogId.dlg18]);
      expect(
        feedback.dialogParams.single[DialogParamKeys.result],
        MembershipStatus.active,
      );
      expect(
        container.read(provider).visible.map((m) => m.userId),
        isNot(contains('u039')),
      );
      expect(feedback.toasts, isEmpty);
    });

    test('yazılamadı (ağ) → satır geri gelir + TST-24', () async {
      final container = await loaded();
      management.failNext(FirestoreError.unavailable);
      final outcome = await container.read(provider.notifier).approve('u_cem');
      expect(outcome, DecisionOutcome.failed);
      expect(
        container.read(provider).visible.map((m) => m.userId),
        contains('u_cem'),
      );
      expect(feedback.toasts, [ToastId.tst24]);
    });

    test('danışman: onay → TST-26, yazım yok', () async {
      final container = await loaded(
        session: manageSession(role: ClubRole.advisor),
      );
      final outcome = await container.read(provider.notifier).approve('u_cem');
      expect(outcome, DecisionOutcome.blocked);
      expect(feedback.toasts, [ToastId.tst26]);
      expect(management.callsTo('approveApplication'), isEmpty);
    });
  });

  group('MGT-02 · toplu işlem', () {
    test('DLG-17 → approveMany: üç başvuru aktif, memberCount +3, MGT-01 '
        'göstergeleri tutarlı, TST-27 "3 başvuru"', () async {
      final before = clubs.clubs[kManageClubId]!.memberCount;
      final container = await loaded();
      addTearDown(
        container
            .listen(manageViewModelProvider(kManageClubId), (_, _) {})
            .close,
      );
      await pumpEventQueue();
      expect(
        container
            .read(manageViewModelProvider(kManageClubId))
            .kpis
            .pendingCount,
        kPendingIds.length,
      );
      final vm = container.read(provider.notifier)
        ..toggleSelect('u035')
        ..toggleSelect('u039')
        ..toggleSelect('u043');
      expect(container.read(provider).selecting, isTrue);
      feedback.dialogResults[DialogId.dlg17] = true;

      final result = await vm.bulkApprove();
      await pumpEventQueue();
      expect(result?.succeeded, hasLength(3));
      expect(feedback.dialogs, [DialogId.dlg17]);
      expect(feedback.dialogParams.single[DialogParamKeys.count], 3);
      for (final id in ['u035', 'u039', 'u043']) {
        expect(statusOf(id), MembershipStatus.active);
      }
      expect(clubs.clubs[kManageClubId]!.memberCount, before + 3);
      final state = container.read(provider);
      expect(state.pendingCount, kPendingIds.length - 3);
      expect(state.selecting, isFalse);
      expect(state.selectedIds, isEmpty);
      expect(feedback.toasts, [ToastId.tst27]);
      expect(feedback.toastParams.single.applicants, 3);
      final kpis = container.read(manageViewModelProvider(kManageClubId)).kpis;
      expect(kpis.pendingCount, kPendingIds.length - 3);
      expect(kpis.memberCount, before + 3);
    });

    test('DLG-17 vazgeç → yazım yok', () async {
      final container = await loaded();
      final vm = container.read(provider.notifier)..toggleSelect('u035');
      expect(await vm.bulkReject(), isNull);
      expect(management.callsTo('rejectMany'), isEmpty);
      expect(container.read(provider).selectedIds, {'u035'});
    });
  });

  group('MGT-02 · başvurular kapalı', () {
    test('TST-54 "Başvuruları aç" → kulüp açılır', () async {
      clubs.clubs[kManageClubId] = kManageClub.copyWith(
        applicationsOpen: false,
      );
      final container = await loaded();
      expect(container.read(provider).applicationsClosed, isTrue);
      expect(
        await container.read(provider.notifier).openApplications(),
        isTrue,
      );
      expect(container.read(provider).applicationsClosed, isFalse);
      expect(feedback.toasts, [ToastId.tst54]);
      expect(feedback.toastParams.single.open, isTrue);
      expect(clubs.clubs[kManageClubId]!.applicationsOpen, isTrue);
    });
  });
}
