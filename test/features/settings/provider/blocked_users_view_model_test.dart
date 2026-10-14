// SET-02 · BlockedUsersViewModel: açılış (listBlocked → getUsers), boş,
// hata / yeniden dene, engeli kaldır (iyimser gizle → softDeleteBlock →
// TST-09 + oturum eşitlemesi → "Geri al" restoreBlock), yazım hatası,
// çevrimdışı, başka ekrandaki değişikliğin eşitlenmesi (PLAN §12.12).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/settings/provider/blocked_users_state.dart';
import 'package:gu_kulupler/features/settings/provider/blocked_users_view_model.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';

import '../../../fakes/fake_block_repository.dart';
import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_user_repository.dart';
import '../../../fakes/register_fakes.dart';
import '../../../helpers/test_container.dart';
import '../blocked_users_test_support.dart';

void main() {
  late FakeBlockRepository blocks;
  late FakeUserRepository users;
  late FakeFeedbackService feedback;

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    blocks = GetIt.I<BlockRepository>() as FakeBlockRepository;
    users = GetIt.I<UserRepository>() as FakeUserRepository;
    feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
  });

  Future<ProviderContainer> loaded({List<UserModel>? blocked}) async {
    final container = createContainer(
      overrides: [
        sessionViewModelProvider.overrideWithBuild(
          (ref, notifier) => blockedSession(blocked),
        ),
      ],
    );
    addTearDown(
      container.listen(blockedUsersViewModelProvider, (_, _) {}).close,
    );
    await pumpEventQueue();
    return container;
  }

  BlockedUsersState stateOf(ProviderContainer c) =>
      c.read(blockedUsersViewModelProvider);

  BlockedUsersViewModel vmOf(ProviderContainer c) =>
      c.read(blockedUsersViewModelProvider.notifier);

  List<String> idsOf(ProviderContainer c) => [
    for (final (block, _) in stateOf(c).visible) block.blockedId,
  ];

  bool isBlockedInSession(ProviderContainer c, String userId) =>
      c.read(sessionViewModelProvider).isBlocked(userId);

  group('SET-02 · açılış', () {
    test('engeller + kullanıcılar toplu', () async {
      seedBlocked([kBlockedEren, kBlockedAyse]);
      final c = await loaded(blocked: [kBlockedEren, kBlockedAyse]);
      expect(stateOf(c).isFetching, isFalse);
      expect(idsOf(c), unorderedEquals(['u042', 'u_ayse']));
      expect(stateOf(c).entryOf('u042')!.$2, kBlockedEren);
      expect(users.callsTo('getUsers'), hasLength(1));
    });

    test('engel yok → boş, kullanıcı okunmaz', () async {
      final c = await loaded(blocked: const []);
      expect(stateOf(c).items, isEmpty);
      expect(stateOf(c).isError, isFalse);
      expect(users.callsTo('getUsers'), isEmpty);
    });

    test('engeller okunamazsa hata; "Yeniden dene" okur', () async {
      seedBlocked();
      blocks.failNext(FirestoreError.unavailable);
      final c = await loaded();
      expect(stateOf(c).isError, isTrue);
      await vmOf(c).fetch();
      expect(stateOf(c).isError, isFalse);
      expect(idsOf(c), ['u042']);
    });

    test('kullanıcılar okunamazsa hata', () async {
      seedBlocked();
      users.failNext(FirestoreError.unavailable);
      final c = await loaded();
      expect(stateOf(c).isError, isTrue);
    });
  });

  group('SET-02 · engeli kaldır', () {
    test('satır düşer + TST-09 + oturum; "Geri al" geri yükler', () async {
      seedBlocked();
      final c = await loaded();
      await vmOf(c).unblock('u042', name: kBlockedEren.name);
      expect(idsOf(c), isEmpty);
      expect(feedback.toasts, [ToastId.tst09]);
      expect(feedback.toastParams.single.name, kBlockedEren.name);
      expect(feedback.toastParams.single.unblocked, isTrue);
      expect(blocks.callsTo('softDeleteBlock'), hasLength(1));
      expect(isBlockedInSession(c, 'u042'), isFalse);

      feedback.tapToastAction();
      await pumpEventQueue();
      expect(blocks.callsTo('restoreBlock'), hasLength(1));
      expect(idsOf(c), ['u042']);
      expect(isBlockedInSession(c, 'u042'), isTrue);
    });

    test('yazım reddedilirse satır geri gelir + TST-24', () async {
      seedBlocked();
      final c = await loaded();
      blocks.failNext(FirestoreError.unavailable);
      await vmOf(c).unblock('u042', name: kBlockedEren.name);
      expect(idsOf(c), ['u042']);
      expect(feedback.toasts, [ToastId.tst24]);
      expect(isBlockedInSession(c, 'u042'), isTrue);
    });

    test('çevrimdışı: yazılmaz, TST-24', () async {
      seedBlocked();
      final c = await loaded();
      (GetIt.I<ConnectivityService>() as FakeConnectivityService).isOffline =
          true;
      await vmOf(c).unblock('u042', name: kBlockedEren.name);
      expect(blocks.callsTo('softDeleteBlock'), isEmpty);
      expect(feedback.toasts, [ToastId.tst24]);
      expect(idsOf(c), ['u042']);
    });

    test('başka ekranda kaldırılan engel satırı gizler, yeniden engel '
        'gösterir', () async {
      seedBlocked();
      final c = await loaded();
      final session = c.read(sessionViewModelProvider.notifier)
        ..setBlocked('u042', isBlocked: false);
      expect(idsOf(c), isEmpty);
      session.setBlocked('u042', isBlocked: true);
      expect(idsOf(c), ['u042']);
    });
  });
}
