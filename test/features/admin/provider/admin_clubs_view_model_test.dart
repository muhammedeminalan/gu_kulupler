// ADM-02 · AdminClubsViewModel: yükleme (askıdakiler dahil tek okuma +
// başkan adları), sekme / arama süzgeci (istemci, Türkçe), askıya al /
// etkinleştir (iyimser; TST-50; hata → geri + TST-24), başkan ata (SHT-25
// adayları + TST-49), `permissionDenied` → claim yenileme + bir kez yineleme
// (CD-160), çevrimdışı yazım engeli — PLAN §12 `AdminClubsViewModel`.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/admin/provider/admin_clubs_view_model.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/navigation/admin_clubs_tab.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';

import '../../../fakes/fake_admin_repository.dart';
import '../../../fakes/fake_auth_repository.dart';
import '../../../fakes/fake_auth_service.dart';
import '../../../fakes/fake_club_repository.dart';
import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_session_states.dart';
import '../../../fakes/fake_user_repository.dart';
import '../../../fakes/register_fakes.dart';
import '../../../fixtures/user_model_fixtures.dart';
import '../../../helpers/test_container.dart';
import '../admin_clubs_test_support.dart';

void main() {
  late FakeAdminRepository admin;
  late FakeClubRepository clubs;
  late FakeFeedbackService feedback;

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    admin = GetIt.I<AdminRepository>() as FakeAdminRepository;
    clubs = GetIt.I<ClubRepository>() as FakeClubRepository;
    feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
    seedAdminClubs();
    clubs.clubs[kAdminSuspendedClubId] = clubs.clubs[kAdminSuspendedClubId]!
        .copyWith(status: ClubStatus.suspended);
  });

  Future<ProviderContainer> loaded() async {
    final container = createContainer(
      overrides: [
        sessionViewModelProvider.overrideWithBuild(
          (ref, notifier) => FakeSessionStates.activeSuper,
        ),
      ],
    );
    addTearDown(container.listen(adminClubsViewModelProvider, (_, _) {}).close);
    await pumpEventQueue();
    return container;
  }

  AdminClubsViewModel vm(ProviderContainer c) =>
      c.read(adminClubsViewModelProvider.notifier);

  group('ADM-02 · AdminClubsViewModel · okuma ve süzgeç', () {
    test('tek okuma: askıdakiler dahil; etkin sekme 13 kulüp ada göre; '
        'başkan adları okunur', () async {
      final container = await loaded();
      final state = container.read(adminClubsViewModelProvider);

      expect(state.isLoaded, isTrue);
      expect(state.isError, isFalse);
      expect(state.clubs, hasLength(14));
      expect(state.tab, AdminClubsTab.active);
      expect(state.visible, hasLength(13));
      expect(state.visible.first.id, kFirstClubId);
      expect(state.presidents['u_burak']?.name, 'Burak Şahin');
      expect(clubs.callsTo('fetchActiveClubs'), hasLength(1));
    });

    test(
      'sekme askıda → yalnızca c14; arama Türkçe küçük harfle süzer',
      () async {
        final container = await loaded();
        vm(container).setTab(AdminClubsTab.suspended);
        expect(
          container.read(adminClubsViewModelProvider).visible.map((c) => c.id),
          [kAdminSuspendedClubId],
        );

        vm(container)
          ..setTab(AdminClubsTab.active)
          ..setQuery('  İNOVASYON ');
        expect(
          container.read(adminClubsViewModelProvider).visible.map((c) => c.id),
          ['c02'],
        );
      },
    );

    test('okuma hatası → hata; "Yeniden dene" okur', () async {
      clubs.failNext(FirestoreError.unavailable);
      final container = await loaded();
      expect(container.read(adminClubsViewModelProvider).isError, isTrue);

      await vm(container).fetch();
      final state = container.read(adminClubsViewModelProvider);
      expect(state.isError, isFalse);
      expect(state.visible, hasLength(13));
    });

    test('permissionDenied → claim yenilenir; hâlâ süper admin → bir kez '
        'yinelenir (CD-160)', () async {
      final auth = GetIt.I<AuthRepository>() as FakeAuthRepository;
      _signIn();
      auth.isSuperAdminResult = true;
      clubs.failNext(FirestoreError.permissionDenied);

      final container = await loaded();

      expect(container.read(adminClubsViewModelProvider).isError, isFalse);
      expect(clubs.callsTo('fetchActiveClubs'), hasLength(2));
      expect(auth.callsTo('isSuperAdmin').single.args, [true]);
    });
  });

  group('ADM-02 · AdminClubsViewModel · askı / etkinleştirme', () {
    test('askıya al: satır hemen askıdakilere geçer, neden kırpılır, '
        'TST-50 (askıya alındı)', () async {
      final container = await loaded();

      final ok = await vm(container).suspend('c03', '  Kural ihlali ');

      expect(ok, isTrue);
      expect(admin.callsTo('suspendClub').single.args, ['c03', 'Kural ihlali']);
      expect(clubs.clubs['c03']!.isSuspended, isTrue);
      final state = container.read(adminClubsViewModelProvider);
      expect(state.visible.map((c) => c.id), isNot(contains('c03')));
      expect(state.pendingIds, isEmpty);
      expect(feedback.toasts, [ToastId.tst50]);
      expect(feedback.toastParams.single.suspended, isTrue);
    });

    test(
      'etkinleştir: askıdaki satır etkinlere döner, TST-50 (etkin)',
      () async {
        final container = await loaded();

        final ok = await vm(container).activate(kAdminSuspendedClubId);

        expect(ok, isTrue);
        expect(clubs.clubs[kAdminSuspendedClubId]!.isSuspended, isFalse);
        expect(
          container.read(adminClubsViewModelProvider).visible,
          hasLength(14),
        );
        expect(feedback.toastParams.single.suspended, isFalse);
      },
    );

    test('yazım hatası → satır geri döner + TST-24', () async {
      final container = await loaded();
      admin.failNext(FirestoreError.unavailable);

      final ok = await vm(container).suspend('c03', 'Neden');

      expect(ok, isFalse);
      final state = container.read(adminClubsViewModelProvider);
      expect(state.clubById('c03')!.isSuspended, isFalse);
      expect(state.visible.map((c) => c.id), contains('c03'));
      expect(state.pendingIds, isEmpty);
      expect(feedback.toasts, [ToastId.tst24]);
    });

    test('çevrimdışı → yazım yok, TST-24', () async {
      final container = await loaded();
      (GetIt.I<ConnectivityService>() as FakeConnectivityService).isOffline =
          true;

      expect(await vm(container).activate(kAdminSuspendedClubId), isFalse);
      expect(admin.callsTo('activateClub'), isEmpty);
      expect(feedback.toasts, [ToastId.tst24]);
    });
  });

  group('ADM-02 · AdminClubsViewModel · başkan ata', () {
    test(
      'adaylar: etkin, personel olmayan, silinmemiş; mevcut başkan hariç',
      () async {
        final users = GetIt.I<UserRepository>() as FakeUserRepository;
        for (final id in ['u_ayse', 'u_zeynep', 'u_suspended']) {
          users.users[id] = UserModelFixtures.byId(id);
        }
        final container = await loaded();

        final candidates = await vm(container).presidentCandidates('c03');

        final ids = candidates!.map((u) => u.uid).toSet();
        expect(ids, contains('u_ayse'));
        expect(ids, isNot(contains('u_burak')));
        expect(ids, isNot(contains('u_zeynep')));
        expect(ids, isNot(contains('u_suspended')));
      },
    );

    test('başkan ata → presidentId güncellenir, TST-49 {ad}', () async {
      final users = GetIt.I<UserRepository>() as FakeUserRepository;
      final ayse = users.users['u_ayse'] = UserModelFixtures.byId('u_ayse');
      final container = await loaded();

      final ok = await vm(container).assignPresident('c03', ayse);
      await pumpEventQueue();

      expect(ok, isTrue);
      expect(admin.callsTo('assignPresident').single.args, [
        'c03',
        'u_ayse',
        FakeSessionStates.uid,
      ]);
      expect(clubs.clubs['c03']!.presidentId, 'u_ayse');
      final state = container.read(adminClubsViewModelProvider);
      expect(state.clubById('c03')!.presidentId, 'u_ayse');
      expect(state.presidents['u_ayse']?.name, ayse.name);
      expect(feedback.toasts, [ToastId.tst49]);
      expect(feedback.toastParams.single.name, ayse.name);
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
