// PRF-03 · MyClubsViewModel: açılış (oturum üyelikleri → toplu kulüp
// okuması, ayrı üyelik sorgusu yok), sekme ayrımı ve sıra, iptal (DLG-07 →
// iyimser "Geçmiş" → TST-40; hata → geri), ayrılma (DLG-08 → TST-39; başkan
// DLG-09; sunucu kuralı → geri + DLG-09), tekrar başvuru bekleme süresi
// (TST-X4), hata / yenileme (PLAN §12.6).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/profile/provider/my_clubs_state.dart';
import 'package:gu_kulupler/features/profile/provider/my_clubs_view_model.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/navigation/my_clubs_tab.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';

import '../../../fakes/fake_club_repository.dart';
import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_membership_repository.dart';
import '../../../fakes/register_fakes.dart';
import '../../../helpers/test_container.dart';
import '../my_clubs_test_support.dart';

void main() {
  late FakeClubRepository clubs;
  late FakeMembershipRepository memberships;
  late FakeFeedbackService feedback;

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    clubs = GetIt.I<ClubRepository>() as FakeClubRepository;
    memberships = GetIt.I<MembershipRepository>() as FakeMembershipRepository;
    feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
  });

  Future<ProviderContainer> loaded([SessionState? session]) async {
    final container = createContainer(
      overrides: [
        sessionViewModelProvider.overrideWithBuild(
          (ref, notifier) => session ?? myClubsSession(),
        ),
      ],
    );
    addTearDown(container.listen(myClubsViewModelProvider, (_, _) {}).close);
    await pumpEventQueue();
    return container;
  }

  MyClubsState stateOf(ProviderContainer c) => c.read(myClubsViewModelProvider);

  MyClubsViewModel vmOf(ProviderContainer c) =>
      c.read(myClubsViewModelProvider.notifier);

  List<String> idsOf(ProviderContainer c, MyClubsTab tab) => [
    for (final (membership, _) in stateOf(c).entriesOf(tab)) membership.clubId,
  ];

  group('PRF-03 · açılış ve sekmeler', () {
    test('oturum üyelikleri + tek toplu kulüp okuması; sekme ayrımı ve en '
        'yeni üstte', () async {
      seedMyClubs();
      memberships.resetFake();
      final c = await loaded();
      final state = stateOf(c);
      expect(state.isFetching, isFalse);
      expect(state.isError, isFalse);
      expect(clubs.callsTo('getClubs'), hasLength(1));
      expect(memberships.callsTo('listMine'), isEmpty);
      // c07 (Ağustos) c01'den (Mayıs) yeni.
      expect(idsOf(c, MyClubsTab.active), ['c07', 'c01']);
      expect(idsOf(c, MyClubsTab.pending), ['c06']);
      expect(idsOf(c, MyClubsTab.past), ['c05']);
      expect(vmOf(c).visible, hasLength(2));
      vmOf(c).setTab(MyClubsTab.pending);
      expect(stateOf(c).tab, MyClubsTab.pending);
      expect(vmOf(c).visible.single.$1.clubId, 'c06');
    });

    test('ayrılınan ve iptal edilen üyelikler "Geçmiş"te; kulübü okunamayan '
        'satır çizilmez', () async {
      final left = kC01Active.copyWith(status: MembershipStatus.left);
      final cancelled = kC06Pending.copyWith(
        status: MembershipStatus.cancelled,
      );
      seedMyClubs([left, cancelled, kC07Active]);
      clubs.clubs.remove('c07');
      final c = await loaded(myClubsSession([left, cancelled, kC07Active]));
      expect(idsOf(c, MyClubsTab.past), unorderedEquals(['c01', 'c06']));
      expect(idsOf(c, MyClubsTab.active), isEmpty);
    });

    test('kulüpler okunamazsa hata; "Yeniden dene" okur', () async {
      seedMyClubs();
      clubs.failNext(FirestoreError.unavailable);
      final c = await loaded();
      expect(stateOf(c).isError, isTrue);
      await vmOf(c).fetch();
      expect(stateOf(c).isError, isFalse);
      expect(idsOf(c, MyClubsTab.active), hasLength(2));
    });

    test('üyelik yoksa okuma yok, boş', () async {
      final c = await loaded(myClubsSession(const []));
      expect(stateOf(c).isFetching, isFalse);
      expect(clubs.callsTo('getClubs'), isEmpty);
      expect(vmOf(c).visible, isEmpty);
    });

    test('çek-yenile: listMine + kulüpler baştan', () async {
      seedMyClubs();
      final c = await loaded();
      clubs.resetFake();
      await vmOf(c).refresh();
      expect(memberships.callsTo('listMine'), hasLength(1));
      expect(clubs.callsTo('getClubs'), hasLength(1));
      expect(stateOf(c).isRefreshing, isFalse);
    });
  });

  group('PRF-03 · iptal', () {
    test('DLG-07 onay → iyimser "Geçmiş" → TST-40', () async {
      seedMyClubs();
      final c = await loaded();
      feedback.dialogResults[DialogId.dlg07] = true;
      final done = await vmOf(c).cancelApplication('c06');
      expect(done, isTrue);
      expect(feedback.dialogs, [DialogId.dlg07]);
      expect(feedback.toasts, [ToastId.tst40]);
      expect(idsOf(c, MyClubsTab.pending), isEmpty);
      expect(idsOf(c, MyClubsTab.past), contains('c06'));
      expect(stateOf(c).pendingIds, isEmpty);
      expect(memberships.callsTo('cancelApplication'), hasLength(1));
    });

    test('vazgeçilirse yazım yok', () async {
      seedMyClubs();
      final c = await loaded();
      expect(await vmOf(c).cancelApplication('c06'), isFalse);
      expect(memberships.callsTo('cancelApplication'), isEmpty);
      expect(idsOf(c, MyClubsTab.pending), ['c06']);
    });

    test('yazım reddedilirse satır "Bekleyen"e döner + TST-24', () async {
      seedMyClubs();
      final c = await loaded();
      feedback.dialogResults[DialogId.dlg07] = true;
      memberships.failNext(FirestoreError.unavailable);
      expect(await vmOf(c).cancelApplication('c06'), isFalse);
      expect(idsOf(c, MyClubsTab.pending), ['c06']);
      expect(feedback.toasts, [ToastId.tst24]);
    });

    test('çevrimdışı → TST-24, yazım yok', () async {
      seedMyClubs();
      final c = await loaded();
      feedback.dialogResults[DialogId.dlg07] = true;
      (GetIt.I<ConnectivityService>() as FakeConnectivityService).isOffline =
          true;
      expect(await vmOf(c).cancelApplication('c06'), isFalse);
      expect(feedback.toasts, [ToastId.tst24]);
      expect(memberships.callsTo('cancelApplication'), isEmpty);
    });
  });

  group('PRF-03 · ayrılma', () {
    test('DLG-08 onay → iyimser "Geçmiş" → TST-39', () async {
      seedMyClubs();
      final c = await loaded();
      feedback.dialogResults[DialogId.dlg08] = true;
      final outcome = await vmOf(c).leave('c01');
      expect(outcome, MyClubLeaveOutcome.left);
      expect(feedback.toasts, [ToastId.tst39]);
      expect(idsOf(c, MyClubsTab.active), ['c07']);
      expect(idsOf(c, MyClubsTab.past), contains('c01'));
    });

    test(
      'başkan: onay sorulmadan DLG-09; "devret" → transferRequested',
      () async {
        final president = kC01Active.copyWith(role: ClubRole.president);
        seedMyClubs([president]);
        final c = await loaded(myClubsSession([president]));
        feedback.dialogResults[DialogId.dlg09] = true;
        expect(
          await vmOf(c).leave('c01'),
          MyClubLeaveOutcome.transferRequested,
        );
        expect(feedback.dialogs, [DialogId.dlg09]);
        expect(memberships.callsTo('leave'), isEmpty);
      },
    );

    test('W-14: "Başkanlığı devret" → SHT-25 → DLG-21 → devredilir '
        '(TST-49)', () async {
      final president = kC01Active.copyWith(role: ClubRole.president);
      seedMyClubs([president]);
      final heir = president.copyWith(
        id: FirestoreIds.membership('c01', 'u_heir'),
        userId: 'u_heir',
        role: ClubRole.member,
      );
      memberships.put(heir);
      final c = await loaded(myClubsSession([president]));
      feedback
        ..nextSheetResult = 'u_heir'
        ..dialogResults[DialogId.dlg21] = true;
      expect(await vmOf(c).transferPresidencyForLeave('c01'), isTrue);
      expect(feedback.sheets, [SheetId.sht25]);
      expect(feedback.toasts, [ToastId.tst49]);
      expect(memberships.memberships[heir.id]?.role, ClubRole.president);
    });

    test('sunucu başkanlık kuralı → satır döner + DLG-09', () async {
      final president = kC01Active.copyWith(role: ClubRole.president);
      seedMyClubs([president]);
      // Oturumdaki rol eski: üye görünüyor.
      final c = await loaded(myClubsSession([kC01Active]));
      feedback.dialogResults[DialogId.dlg08] = true;
      expect(await vmOf(c).leave('c01'), MyClubLeaveOutcome.solePresident);
      expect(feedback.dialogs, [DialogId.dlg08, DialogId.dlg09]);
      expect(idsOf(c, MyClubsTab.active), ['c01']);
    });
  });

  group('PRF-03 · tekrar başvur', () {
    test('bekleme süresi dolmadıysa TST-X4; dolduysa izin', () async {
      final waiting = kC05Rejected.copyWith(
        retryAfter: DateTime.utc(2026, 12, 2),
      );
      seedMyClubs([waiting]);
      final c = await loaded(myClubsSession([waiting]));
      expect(vmOf(c).reapply('c05', formatDate: (d) => 'D'), isFalse);
      expect(feedback.toasts, [ToastId.tstX4]);
      expect(feedback.toastParams.single.date, 'D');

      final c2 = await loaded(myClubsSession([kC05Rejected]));
      expect(vmOf(c2).reapply('c05', formatDate: (d) => 'D'), isTrue);
    });
  });
}
