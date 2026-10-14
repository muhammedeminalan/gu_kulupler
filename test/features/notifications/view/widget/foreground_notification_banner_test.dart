// T-26 · TST-55 ön plan bandı (`ForegroundNotificationBanner`; PLAN §15.5):
// akışa yeni bildirim düşünce (`NotificationsState.incoming`) tek TST-55
// gösterilir ve tüketilir; "Görüntüle" → `NotificationNavigator.open`
// (okundu + hedef); NTF-01 açıkken gösterilmez; kabukta kuruludur.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/notifications/provider/notifications_state.dart';
import 'package:gu_kulupler/features/notifications/provider/notifications_view_model.dart';
import 'package:gu_kulupler/features/notifications/view/widget/foreground_notification_banner.dart';
import 'package:gu_kulupler/l10n/app_localizations_tr.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/notification_navigator.dart';

import '../../../../fakes/fake_feedback_service.dart';
import '../../../../fakes/fake_notification_repository.dart';
import '../../../../fakes/fake_session_states.dart';
import '../../../../fakes/register_fakes.dart';
import '../../../../fakes/test_router.dart';
import '../../../../helpers/pump_app.dart';

final class _RecordingRouter extends Fake implements GoRouter {
  final List<String> gone = <String>[];

  @override
  void go(String location, {Object? extra}) => gone.add(location);
}

const NotificationModel _cancelled = NotificationModel(
  id: 'n01',
  userId: FakeSessionStates.uid,
  type: NotificationType.eventCancelled,
  refs: NotificationRefsModel(clubId: 'c01', eventId: 'e01'),
);

void main() {
  final tr = AppLocalizationsTr();

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(
        tester.element(find.byType(ForegroundNotificationBanner)),
      );

  /// Akışa yeni bildirim düşmüş gibi `incoming` alanını yazar.
  Future<void> arrive(WidgetTester tester, NotificationModel n) async {
    final notifier = containerOf(
      tester,
    ).read(notificationsViewModelProvider.notifier);
    // `state` test için görünürdür (riverpod `@visibleForTesting`).
    notifier.state = notifier.state.copyWith(incoming: n);
    await tester.pump();
  }

  NotificationsState incomingOf(WidgetTester tester) =>
      containerOf(tester).read(notificationsViewModelProvider);

  final idle = notificationsViewModelProvider.overrideWithBuild(
    (ref, notifier) => NotificationsState(sessionStartedAt: kDefaultFakeNowUtc),
  );

  group('T-26 · ForegroundNotificationBanner (TST-55)', () {
    testWidgets('yeni bildirim → tek TST-55 (başlık), tüketilir; Görüntüle → '
        'okundu + hedef', (tester) async {
      final feedback = FakeFeedbackService();
      final router = _RecordingRouter();
      await tester.pumpApp(
        const ForegroundNotificationBanner(child: SizedBox.shrink()),
        overrides: [
          idle,
          feedbackServiceProvider.overrideWithValue(feedback),
          notificationNavigatorProvider.overrideWith(
            (ref) => NotificationNavigator(
              router: router,
              userId: FakeSessionStates.uid,
              isSuperAdmin: false,
            ),
          ),
        ],
      );
      final inbox =
          GetIt.I<NotificationRepository>() as FakeNotificationRepository
            ..put(_cancelled);

      await arrive(tester, _cancelled);

      expect(feedback.toasts, [ToastId.tst55]);
      expect(
        feedback.toastParams.single.title,
        tr.notifTypeEventCancelledTitle,
      );
      expect(feedback.hasToastAction, isTrue);
      expect(incomingOf(tester).incoming, isNull);

      feedback.tapToastAction();
      await tester.pumpAndSettle();
      expect(router.gone, ['/events/e01?showCancelled=true']);
      expect(inbox.callsTo('markRead').single.args, ['n01']);
    });

    testWidgets('başlık üreticisi verilirse o kullanılır', (tester) async {
      final feedback = FakeFeedbackService();
      await tester.pumpApp(
        ForegroundNotificationBanner(
          titleOf: (context, n) => 'Yapay Zekâya Giriş',
          child: const SizedBox.shrink(),
        ),
        overrides: [idle, feedbackServiceProvider.overrideWithValue(feedback)],
      );

      await arrive(tester, _cancelled);

      expect(feedback.toastParams.single.title, 'Yapay Zekâya Giriş');
    });

    testWidgets('kabukta kurulu: NTF-01 açıkken gösterilmez (yine tüketilir), '
        'başka sekmede gösterilir', (tester) async {
      final shell = await TestRouter.pumpShell(
        tester,
        location: AppPaths.notifications,
        overrides: [idle],
      );

      await arrive(tester, _cancelled);
      expect(shell.feedback.toasts, isEmpty);
      expect(incomingOf(tester).incoming, isNull);

      await shell.go(AppPaths.clubs);
      await arrive(tester, _cancelled);
      expect(shell.feedback.toasts, [ToastId.tst55]);
    });
  });
}
