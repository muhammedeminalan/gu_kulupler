// T-11 · SessionRefreshListenable: oturum değişince router yönlendirmeyi
// yeniden değerlendirir (PLAN §13.1, §13.5; navigation.md §3).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/navigation/session_refresh_listenable.dart';
import 'package:gu_kulupler/product/navigation/splash_hold.dart';

import '../../fakes/fake_session_states.dart';
import '../../fakes/register_fakes.dart';
import '../../fakes/test_router.dart';
import '../../helpers/test_container.dart';

void main() {
  group('T-11 · SessionRefreshListenable', () {
    late ProviderContainer container;

    setUp(() async {
      await GetIt.I.reset();
      registerDefaultFakes();
      addTearDown(GetIt.I.reset);
      container = createContainer(
        overrides: [
          sessionViewModelProvider.overrideWithBuild(
            (ref, notifier) => FakeSessionStates.signedOut,
          ),
        ],
      );
    });

    test('oturum state’i değişince dinleyicilere haber verir', () {
      var notifications = 0;
      container
          .read(sessionRefreshListenableProvider)
          .addListener(() => notifications++);
      void setSession(SessionState session) =>
          container.read(sessionViewModelProvider.notifier).state = session;

      setSession(FakeSessionStates.active);
      expect(notifications, 1);
      setSession(FakeSessionStates.activeManager('c01'));
      expect(notifications, 2);
      setSession(FakeSessionStates.signedOut);
      expect(notifications, 3);
    });

    test('açılış beklemesi kalkınca haber verir (bir kez)', () {
      var notifications = 0;
      container
          .read(sessionRefreshListenableProvider)
          .addListener(() => notifications++);
      expect(container.read(splashHoldProvider), isTrue);

      container.read(splashHoldProvider.notifier).release();
      expect(container.read(splashHoldProvider), isFalse);
      expect(notifications, 1);

      // Bekleme tek yönlüdür: yinelenen çağrı bildirim üretmez.
      container.read(splashHoldProvider.notifier).release();
      expect(notifications, 1);
    });

    test('eşit state yeniden bildirim üretmez', () {
      var notifications = 0;
      container
          .read(sessionRefreshListenableProvider)
          .addListener(() => notifications++);
      container.read(sessionViewModelProvider.notifier).state =
          FakeSessionStates.signedOut.copyWith();
      expect(notifications, 0);
    });

    test('uygulama ömrü boyunca tek örnektir; kapsayıcıyla kapanır', () {
      final listenable = container.read(sessionRefreshListenableProvider);
      expect(
        container.read(sessionRefreshListenableProvider),
        same(listenable),
      );
      container.dispose();
      // Kapatılmış ChangeNotifier dinleyici kabul etmez.
      expect(() => listenable.addListener(() {}), throwsFlutterError);
    });
  });

  group('T-11 · oturum değişimi → yönlendirme (kabuk düzeneği)', () {
    testWidgets('rol manager → member düşünce yönetim ekranından atılır: '
        '/clubs/c01 + TST-X18', (tester) async {
      final app = await TestRouter.pumpShell(
        tester,
        redirect: true,
        session: FakeSessionStates.activeManager('c01'),
        location: '/clubs/c01/manage/members',
      );
      expect(app.location, '/clubs/c01/manage/members');
      expect(app.feedback.toasts, isEmpty);

      app.session = FakeSessionStates.activeMember('c01');
      await tester.pumpAndSettle();
      expect(app.location, '/clubs/c01');
      expect(app.feedback.toasts, [ToastId.tstX18]);
    });

    testWidgets('üyelikten çıkarılınca üye listesinden atılır (toast yok)', (
      tester,
    ) async {
      final app = await TestRouter.pumpShell(
        tester,
        redirect: true,
        session: FakeSessionStates.activeMember('c01'),
        location: '/clubs/c01/members',
      );
      app.session = FakeSessionStates.active;
      await tester.pumpAndSettle();
      expect(app.location, '/clubs/c01');
      expect(app.feedback.toasts, isEmpty);
    });

    testWidgets('danışman yazma ekranına giremez: /clubs/c01/manage + '
        'TST-26', (tester) async {
      final app = await TestRouter.pumpShell(
        tester,
        redirect: true,
        session: FakeSessionStates.activeAdvisor('c01'),
        location: '/clubs/c01/manage',
      );
      await app.go('/clubs/c01/manage/events/new');
      expect(app.location, '/clubs/c01/manage');
      expect(app.feedback.toasts, [ToastId.tst26]);
    });

    testWidgets('süper admin claim’i kalkınca admin ekranından atılır', (
      tester,
    ) async {
      final app = await TestRouter.pumpShell(
        tester,
        redirect: true,
        session: FakeSessionStates.activeSuper,
        location: '/admin/users',
      );
      expect(app.location, '/admin/users');

      app.session = FakeSessionStates.active;
      await tester.pumpAndSettle();
      expect(app.location, '/clubs');
      expect(app.feedback.toasts, [ToastId.tstX18]);
    });

    testWidgets('yetki kazanınca bulunduğu yerde kalır (yönlendirme yok)', (
      tester,
    ) async {
      final app = await TestRouter.pumpShell(
        tester,
        redirect: true,
        session: FakeSessionStates.activeMember('c01'),
        location: '/clubs/c01/members',
      );
      app.session = FakeSessionStates.activeManager('c01');
      await tester.pumpAndSettle();
      expect(app.location, '/clubs/c01/members');
      expect(app.feedback.toasts, isEmpty);
    });
  });
}
