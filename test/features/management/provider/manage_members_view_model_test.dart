// MGT-03 · ManageMembersViewModel: yükleme (21 etkin üye), süzgeç, arama
// (Türkçe küçük harf), sıralama; ortak `ManageMemberActionsMixin` akışları:
// SHT-21 → çıkarma (iyimser + TST-47 "Geri al"), rol değişimi (TST-46),
// devir sonrası roller (TST-49); hiyerarşi (board yalnız member çıkarır,
// başkan çıkarılamaz → TST-X18, yazım yok); danışman (TST-26); CSV içeriği
// (TST-29) — PLAN §12.6, roadmap T-33.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/management/provider/manage_members_state.dart';
import 'package:gu_kulupler/features/management/provider/manage_members_view_model.dart';
import 'package:gu_kulupler/features/management/provider/members_csv.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/member_actions_sheet.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/mixin/manage_member_actions_mixin.dart';
import 'package:gu_kulupler/product/service/file_service.dart';
import 'package:gu_kulupler/product/service/share_service.dart';

import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_file_service.dart';
import '../../../fakes/fake_management_repository.dart';
import '../../../fakes/fake_membership_repository.dart';
import '../../../fakes/fake_share_service.dart';
import '../../../fakes/register_fakes.dart';
import '../../../fixtures/user_model_fixtures.dart';
import '../../../helpers/test_container.dart';
import '../applications_test_support.dart';
import '../manage_test_support.dart';
import '../members_test_support.dart';

/// CSV etiketleri: kimlikler olduğu gibi (yerelleştirme view'dadır).
final MembersCsvLabels _labels = (
  role: (role) => role.name,
  department: (code) => code,
  year: (year) => year.name,
);

void main() {
  late FakeMembershipRepository memberships;
  late FakeManagementRepository management;
  late FakeFeedbackService feedback;

  final provider = manageMembersViewModelProvider(kManageClubId);

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    memberships = GetIt.I<MembershipRepository>() as FakeMembershipRepository;
    management = GetIt.I<ManagementRepository>() as FakeManagementRepository;
    feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
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

  MembershipModel stored(String uid) =>
      memberships.memberships[FirestoreIds.membership(kManageClubId, uid)]!;

  List<String> visibleIds(ProviderContainer c) => [
    for (final m in c.read(provider).visible) m.userId,
  ];

  group('MGT-03 · yükleme, süzgeç, arama, sıralama', () {
    test(
      '21 etkin üye ada göre; rol çipleri; arama Türkçe küçük harf',
      () async {
        final container = await loaded();
        final vm = container.read(provider.notifier);
        final state = container.read(provider);
        expect(state.isFetching, isFalse);
        expect(state.visible, hasLength(activeMemberships().length));
        expect(state.totalCount, 21);
        expect(visibleIds(container).take(3), ['u_burak', 'u133', 'u_a_c03']);

        vm.setRoleFilter(ManageRoleFilter.board);
        expect(visibleIds(container), hasLength(5));
        vm.setRoleFilter(ManageRoleFilter.advisor);
        expect(visibleIds(container), ['u_a_c03']);
        vm.setRoleFilter(ManageRoleFilter.member);
        expect(visibleIds(container), hasLength(14));

        vm
          ..setRoleFilter(ManageRoleFilter.all)
          ..setQuery('  EBRU ');
        expect(visibleIds(container).toSet(), {'u071', 'u086'});
        vm.setQuery('zzz');
        expect(container.read(provider).visible, isEmpty);
      },
    );

    test('sıralama: katılım tarihi (en yeni üstte), rol', () async {
      final container = await loaded();
      final vm = container.read(provider.notifier)..setSort(MemberSort.joined);
      final joined = container.read(provider).visible;
      for (var i = 1; i < joined.length; i++) {
        expect(
          ManageMembersState.joinedAt(joined[i - 1])!.isBefore(
            ManageMembersState.joinedAt(joined[i])!,
          ),
          isFalse,
        );
      }
      vm.setSort(MemberSort.role);
      final roles = [for (final m in container.read(provider).visible) m.role];
      expect(roles.first, ClubRole.president);
      expect(roles.sublist(1, 6), everyElement(ClubRole.board));
      expect(roles[6], ClubRole.advisor);
      expect(roles.last, ClubRole.member);
    });

    test('okunamadı → hata; "Yeniden dene" → dolu', () async {
      memberships.failNext(FirestoreError.unavailable);
      final container = await loaded();
      expect(container.read(provider).isError, isTrue);
      await container.read(provider.notifier).fetch();
      expect(container.read(provider).isError, isFalse);
      expect(container.read(provider).visible, hasLength(21));
    });
  });

  group('MGT-03 · çıkarma (SHT-21 → DLG-19) ve geri al (TST-47)', () {
    test('menü → çıkar: satır düşer → TST-47; "Geri al" → üye olarak '
        'geri gelir', () async {
      final container = await loaded();
      final vm = container.read(provider.notifier);
      feedback
        ..nextSheetResult = MemberAction.remove
        ..dialogResults[DialogId.dlg19] = 'Kurallara aykırı';
      final outcome = await vm.openMemberMenu(stored('u032'));
      expect(outcome, MemberMenuOutcome.removed);
      expect(feedback.sheets, [SheetId.sht21]);
      expect(visibleIds(container), isNot(contains('u032')));
      expect(stored('u032').status, MembershipStatus.removed);
      expect(stored('u032').rejectNote, 'Kurallara aykırı');
      expect(feedback.toasts.last, ToastId.tst47);

      feedback.tapToastAction();
      await pumpEventQueue();
      expect(stored('u032').status, MembershipStatus.active);
      expect(container.read(provider).find('u032')?.role, ClubRole.member);
    });

    test('menü → "Profili gör" → viewProfile sonucu, yazım yok', () async {
      final container = await loaded();
      feedback.nextSheetResult = MemberAction.viewProfile;
      final outcome = await container
          .read(provider.notifier)
          .openMemberMenu(stored('u086'));
      expect(outcome, MemberMenuOutcome.viewProfile);
      expect(management.calls, isEmpty);
    });
  });

  group('MGT-03 · hiyerarşi (RolePolicy, yazımdan önce)', () {
    test('yönetim kurulu yalnız üye çıkarır: board hedef → TST-X18, yazım '
        'yok', () async {
      final container = await loaded(
        session: manageSession(role: ClubRole.board),
      );
      final vm = container.read(provider.notifier);
      expect(
        await vm.removeMember(kManageClubId, stored('u032'), name: 'x'),
        isFalse,
      );
      expect(feedback.toasts.last, ToastId.tstX18);
      expect(management.calls, isEmpty);
      expect(container.read(provider).find('u032'), isNotNull);

      feedback.dialogResults[DialogId.dlg19] = '';
      expect(
        await vm.removeMember(kManageClubId, stored('u086'), name: 'x'),
        isTrue,
      );
      expect(stored('u086').status, MembershipStatus.removed);
    });

    test('başkan çıkarılamaz (süper admin dahil) → TST-X18', () async {
      final container = await loaded(session: superAdminSession());
      final vm = container.read(provider.notifier);
      expect(
        await vm.removeMember(kManageClubId, stored('u_burak'), name: 'x'),
        isFalse,
      );
      expect(feedback.toasts.last, ToastId.tstX18);
      expect(stored('u_burak').status, MembershipStatus.active);
      // Süper admin yönetim kurulu üyesini çıkarabilir.
      feedback.dialogResults[DialogId.dlg19] = '';
      expect(
        await vm.removeMember(kManageClubId, stored('u032'), name: 'x'),
        isTrue,
      );
    });
  });

  group('MGT-03 · rol (SHT-22 → DLG-20) ve devir (SHT-25 → DLG-21)', () {
    test('rol değişimi: rozet anında → TST-46', () async {
      final container = await loaded();
      feedback
        ..nextSheetResult = ClubRole.board
        ..dialogResults[DialogId.dlg20] = true;
      final done = await container
          .read(provider.notifier)
          .changeMemberRole(kManageClubId, stored('u086'), name: 'Ebru Yavuz');
      expect(done, isTrue);
      expect(feedback.sheets, [SheetId.sht22]);
      expect(container.read(provider).find('u086')?.role, ClubRole.board);
      expect(stored('u086').role, ClubRole.board);
      expect(feedback.toasts.last, ToastId.tst46);
      expect(feedback.toastParams.last.role, ClubRole.board.json);
    });

    test('rol yazılamazsa eski rol geri gelir → TST-X18', () async {
      final container = await loaded();
      management.failNext(FirestoreError.permissionDenied);
      feedback
        ..nextSheetResult = ClubRole.board
        ..dialogResults[DialogId.dlg20] = true;
      final done = await container
          .read(provider.notifier)
          .changeMemberRole(kManageClubId, stored('u086'), name: 'x');
      expect(done, isFalse);
      expect(container.read(provider).find('u086')?.role, ClubRole.member);
      expect(feedback.toasts.last, ToastId.tstX18);
    });

    test('devir sonrası roller: yeni başkan, eski başkan yönetim kurulu, '
        'devir kartı kalkar → TST-49', () async {
      final container = await loaded();
      expect(container.read(provider).canTransfer, isTrue);
      feedback
        ..nextSheetResult = 'u086'
        ..dialogResults[DialogId.dlg21] = true;
      expect(await container.read(provider.notifier).startTransfer(), isTrue);
      expect(feedback.sheets, [SheetId.sht25]);
      final state = container.read(provider);
      expect(state.find('u086')?.role, ClubRole.president);
      expect(state.find(kManageUid)?.role, ClubRole.board);
      expect(state.role, ClubRole.board);
      expect(state.club?.presidentId, 'u086');
      expect(state.canTransfer, isFalse);
      expect(stored('u086').role, ClubRole.president);
      expect(stored(kManageUid).role, ClubRole.board);
      expect(feedback.toasts.last, ToastId.tst49);
      expect(management.callsTo('transferPresidency').single.args, [
        kManageClubId,
        kManageUid,
        'u086',
        kManageUid,
      ]);
    });
  });

  group('MGT-03 · danışman (Q-09)', () {
    test('devir ve dışa aktarma yok → TST-26', () async {
      final container = await loaded(
        session: manageSession(role: ClubRole.advisor),
      );
      final vm = container.read(provider.notifier);
      expect(container.read(provider).isReadOnly, isTrue);
      expect(await vm.startTransfer(), isFalse);
      expect(await vm.exportCsv(_labels), isFalse);
      expect(feedback.toasts, [ToastId.tst26, ToastId.tst26]);
      expect(management.calls, isEmpty);
    });
  });

  group('MGT-03 · CSV dışa aktarma (TST-29)', () {
    test(
      'BOM + başlık + 21 satır; e-posta contact belgesinden; paylaşım',
      () async {
        final container = await loaded();
        expect(
          await container.read(provider.notifier).exportCsv(_labels),
          isTrue,
        );
        final files = GetIt.I<FileService>() as FakeFileService;
        final bytes = files.written[MembersCsv.fileName]!;
        // UTF-8 BOM (`EF BB BF`); `utf8.decode` onu atar.
        expect(bytes.take(3), [0xEF, 0xBB, 0xBF]);
        final lines = utf8.decode(bytes).split(MembersCsv.lineBreak)
          ..removeLast();
        expect(
          lines.first,
          '"ad";"eposta";"bolum";"sinif";"rol";"katilim_tarihi"',
        );
        expect(lines, hasLength(22));
        final burak = stored(kManageUid);
        final user = UserModelFixtures.byId(kManageUid);
        expect(
          lines[1],
          [
            user.name,
            contactOf(kManageUid).email,
            user.department ?? '',
            user.year?.name ?? '',
            'president',
            MembersCsv.isoDate(ManageMembersState.joinedAt(burak)!),
          ].map(MembersCsv.cell).join(MembersCsv.separator),
        );
        final shares = GetIt.I<ShareService>() as FakeShareService;
        expect(shares.sharedFiles.single.mimeType, MembersCsv.mimeType);
        expect(feedback.toasts.last, ToastId.tst29);
        expect(memberships.callsTo('readContact'), hasLength(21));
      },
    );

    test('kaçış: tırnak ikilenir, formül öneki etkisizleşir', () {
      expect(MembersCsv.cell('a"b;c'), '"a""b;c"');
      expect(MembersCsv.cell('=HYPERLINK(1)'), '"\'=HYPERLINK(1)"');
      expect(MembersCsv.cell(''), '""');
    });
  });
}
