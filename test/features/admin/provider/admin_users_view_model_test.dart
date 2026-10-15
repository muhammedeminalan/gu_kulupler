// ADM-05 · AdminUsersViewModel: yükleme (ad kipi ilk sayfa + yönetici
// kimlikleri + kulüp sayıları), arama dalları (e-posta → collectionGroup
// `findUserByEmail`, ad → `listUsersByName` önek, boş → varsayılan liste;
// gecikmeli), süzgeçler (yöneticiler / askıdakiler, istemci), sayfalama,
// askıya al / askıyı kaldır (iyimser; TST-52; hata → geri + TST-24), kendi
// hesabında yazım yok (W-101 b), `permissionDenied` → claim yenileme + bir
// kez yineleme (CD-160) — PLAN §12 `AdminUsersViewModel`.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/admin/provider/admin_users_state.dart';
import 'package:gu_kulupler/features/admin/provider/admin_users_view_model.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/navigation/admin_users_filter.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';

import '../../../fakes/fake_admin_repository.dart';
import '../../../fakes/fake_auth_repository.dart';
import '../../../fakes/fake_auth_service.dart';
import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_session_states.dart';
import '../../../fakes/fake_user_repository.dart';
import '../../../fakes/register_fakes.dart';
import '../../../helpers/test_container.dart';
import '../admin_users_test_support.dart';

void main() {
  late FakeAdminRepository admin;
  late FakeUserRepository users;
  late FakeFeedbackService feedback;

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    admin = GetIt.I<AdminRepository>() as FakeAdminRepository;
    users = GetIt.I<UserRepository>() as FakeUserRepository;
    feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
    seedAdminUsers();
  });

  Future<ProviderContainer> loaded() async {
    final container = createContainer(
      overrides: [
        sessionViewModelProvider.overrideWithBuild(
          (ref, notifier) => FakeSessionStates.activeSuper,
        ),
      ],
    );
    addTearDown(container.listen(adminUsersViewModelProvider, (_, _) {}).close);
    await pumpEventQueue();
    return container;
  }

  AdminUsersViewModel vm(ProviderContainer c) =>
      c.read(adminUsersViewModelProvider.notifier);

  AdminUsersState read(ProviderContainer c) =>
      c.read(adminUsersViewModelProvider);

  /// Arama gecikmesini (`Limits.searchDebounce`) bekler.
  Future<void> settleSearch() async {
    await Future<void>.delayed(Limits.searchDebounce);
    await pumpEventQueue();
  }

  group('ADM-05 · AdminUsersViewModel · okuma', () {
    test('ilk sayfa (ad kipi, boş önek) + yönetici kimlikleri + kulüp '
        'sayıları', () async {
      final container = await loaded();
      final state = read(container);

      expect(state.isLoaded, isTrue);
      expect(state.isError, isFalse);
      expect(state.mode, UserSearchMode.name);
      expect(state.users, hasLength(Limits.adminSearchMax));
      expect(admin.callsTo('listUsersByName').single.args.first, '');
      expect(state.managerUserIds, demoManagerIds());
      final counts = demoClubCounts();
      for (final user in state.users) {
        expect(state.clubCounts[user.uid], counts[user.uid]);
      }
    });

    test('okuma hatası → hata; "Yeniden dene" okur', () async {
      admin.failNext(FirestoreError.unavailable);
      final container = await loaded();
      expect(read(container).isError, isTrue);

      await vm(container).fetch();
      expect(read(container).isError, isFalse);
      expect(read(container).users, isNotEmpty);
    });

    test('permissionDenied → claim yenilenir; hâlâ süper admin → bir kez '
        'yinelenir (CD-160)', () async {
      final auth = GetIt.I<AuthRepository>() as FakeAuthRepository;
      (GetIt.I<AuthService>() as FakeAuthService).currentUser =
          const AuthUserInfo(
            uid: 'u_admin',
            email: 'admin@ogr.gumushane.edu.tr',
            emailVerified: true,
            displayName: 'Admin',
          );
      auth.isSuperAdminResult = true;
      admin.failNext(FirestoreError.permissionDenied);

      final container = await loaded();

      expect(read(container).isError, isFalse);
      expect(auth.callsTo('isSuperAdmin'), isNotEmpty);
    });
  });

  group('ADM-05 · AdminUsersViewModel · arama', () {
    test('"@" → e-posta kipi: findUserByEmail (toLowerCase)', () async {
      final container = await loaded();
      vm(container).setQuery(' AYSE.DEMIR@');
      expect(admin.callsTo('findUserByEmail'), isEmpty, reason: 'gecikme');
      await settleSearch();

      final state = read(container);
      expect(admin.callsTo('findUserByEmail').single.args, ['ayse.demir@']);
      expect(state.mode, UserSearchMode.email);
      expect(state.users.map((u) => u.uid), ['u_ayse']);
      expect(state.hasMore, isFalse);
    });

    test('ad → listUsersByName öneki; boş → varsayılan liste', () async {
      final container = await loaded();
      vm(container).setQuery('Alp');
      await settleSearch();

      var state = read(container);
      expect(admin.callsTo('listUsersByName').last.args.first, 'alp');
      expect(state.mode, UserSearchMode.name);
      expect(state.users, isNotEmpty);
      expect(
        state.visible.map((u) => u.name).every((n) => n.startsWith('Alp')),
        isTrue,
      );
      expect(state.visible.first.name, kFirstUserName);

      vm(container).setQuery('');
      await settleSearch();
      state = read(container);
      expect(admin.callsTo('listUsersByName').last.args.first, '');
      expect(state.users, hasLength(Limits.adminSearchMax));
    });

    test('gecikme içinde ardışık girdi → tek okuma (son girdi)', () async {
      final container = await loaded();
      vm(container)
        ..setQuery('a')
        ..setQuery('al')
        ..setQuery('alp');
      await settleSearch();
      expect(
        admin.callsTo('listUsersByName').skip(1).map((c) => c.args.first),
        ['alp'],
      );
    });

    test('arama hatası → hata görünümü', () async {
      final container = await loaded();
      admin.failNext(FirestoreError.unavailable);
      vm(container).setQuery('alp');
      await settleSearch();
      expect(read(container).isError, isTrue);
    });
  });

  group('ADM-05 · AdminUsersViewModel · süzgeç', () {
    test('askıdakiler → yalnızca askıdaki hesaplar; yöneticiler → etkin '
        'yönetim üyeliği olanlar', () async {
      final container = await loaded();
      vm(container).setQuery('Askıdaki');
      await settleSearch();
      vm(container).setFilter(AdminUsersFilter.suspended);
      expect(read(container).visible.map((u) => u.uid), [kSuspendedUserId]);

      vm(container)
        ..setQuery('')
        ..setFilter(AdminUsersFilter.managers);
      await settleSearch();
      final managers = read(container).visible;
      expect(managers, isNotEmpty);
      expect(
        managers.every((u) => demoManagerIds().contains(u.uid)),
        isTrue,
      );
    });
  });

  group('ADM-05 · AdminUsersViewModel · askı', () {
    test(
      'askıya al: rozet hemen, neden kırpılır, TST-52 (askıya alındı)',
      () async {
        final container = await loaded();
        final target = read(container).users.first.uid;

        final ok = await vm(container).suspend(target, '  Kural ihlali ');

        expect(ok, isTrue);
        expect(admin.callsTo('suspendUser').single.args, [
          target,
          'Kural ihlali',
        ]);
        expect(users.users[target]!.status, UserStatus.suspended);
        expect(read(container).userById(target)!.status, UserStatus.suspended);
        expect(read(container).pendingIds, isEmpty);
        expect(feedback.toasts, [ToastId.tst52]);
        expect(feedback.toastParams.single.suspended, isTrue);
      },
    );

    test('askıyı kaldır: etkin, TST-52 (askı kaldırıldı)', () async {
      final container = await loaded();
      vm(container).setQuery('Askıdaki');
      await settleSearch();

      final ok = await vm(container).unsuspend(kSuspendedUserId);

      expect(ok, isTrue);
      expect(admin.callsTo('activateUser').single.args, [kSuspendedUserId]);
      expect(
        read(container).userById(kSuspendedUserId)!.status,
        UserStatus.active,
      );
      expect(feedback.toastParams.single.suspended, isFalse);
    });

    test('yazım hatası → durum geri döner + TST-24', () async {
      final container = await loaded();
      final target = read(container).users.first.uid;
      admin.failNext(FirestoreError.unavailable);

      final ok = await vm(container).suspend(target, 'Neden');

      expect(ok, isFalse);
      expect(read(container).userById(target)!.status, UserStatus.active);
      expect(read(container).pendingIds, isEmpty);
      expect(feedback.toasts, [ToastId.tst24]);
    });

    test('çevrimdışı (T-43): yazım yok, durum aynı + TST-24', () async {
      final container = await loaded();
      final target = read(container).users.first.uid;
      (GetIt.I<ConnectivityService>() as FakeConnectivityService).isOffline =
          true;

      final ok = await vm(container).suspend(target, 'Neden');

      expect(ok, isFalse);
      expect(admin.callsTo('suspendUser'), isEmpty);
      expect(read(container).userById(target)!.status, UserStatus.active);
      expect(feedback.toasts, [ToastId.tst24]);
    });

    test('kendi hesabı (W-101 b) → yazım yok', () async {
      final container = await loaded();
      vm(container).setQuery('Mehmet');
      await settleSearch();
      expect(read(container).userById(FakeSessionStates.uid), isNotNull);
      expect(vm(container).isSelf(FakeSessionStates.uid), isTrue);

      final ok = await vm(container).suspend(FakeSessionStates.uid, 'Neden');

      expect(ok, isFalse);
      expect(admin.callsTo('suspendUser'), isEmpty);
      expect(feedback.toasts, isEmpty);
    });
  });
}
