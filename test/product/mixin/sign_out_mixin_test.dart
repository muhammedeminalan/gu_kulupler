// DLG-06 · Çıkış yapılsın mı? — `SignOutMixin.confirmSignOut`: onay →
// `SessionViewModel.signOut()`; vazgeçme, hata ve çift dokunuş.
// Prototip: dialogs.js:21, screens-auth.js:121 (AUT-03.logout),
// screens-profile.js:69 (SET-01.logout).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/mixin/sign_out_mixin.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../fakes/fake_auth_repository.dart';
import '../../fakes/fake_feedback_service.dart';
import '../../helpers/pump_app.dart';

const Key _logoutKey = ValueKey<String>('test.logout');

/// Çıkış düğmesi olan bir ekranın en küçük hali.
class _Host extends ConsumerStatefulWidget {
  const _Host({required this.outcomes});

  final List<SignOutOutcome> outcomes;

  @override
  ConsumerState<_Host> createState() => _HostState();
}

class _HostState extends ConsumerState<_Host> with SignOutMixin {
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        key: _logoutKey,
        onPressed: () async => widget.outcomes.add(await confirmSignOut()),
        child: const SizedBox.square(dimension: 48),
      ),
    ),
  );
}

void main() {
  late List<SignOutOutcome> outcomes;
  late FakeFeedbackService feedback;
  late FakeAuthRepository auth;

  Future<void> pump(WidgetTester tester) async {
    outcomes = [];
    await tester.pumpApp(_Host(outcomes: outcomes));
    feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
    auth = GetIt.I<AuthRepository>() as FakeAuthRepository;
  }

  Future<void> tapLogout(WidgetTester tester) async {
    await tester.tap(find.byKey(_logoutKey));
    await tester.pumpAndSettle();
  }

  group('DLG-06 · Çıkış yapılsın mı? · SignOutMixin', () {
    testWidgets('"Çıkış yap" (true): DLG-06 katalog kipinde açılır, oturum '
        'kapatılır → signedOut', (tester) async {
      await pump(tester);
      feedback.nextDialogResult = true;

      await tapLogout(tester);

      expect(feedback.dialogs, [DialogId.dlg06]);
      expect(feedback.lastDialogBuilder, isNull);
      expect(feedback.dialogParams.single, isEmpty);
      expect(auth.callsTo('signOut'), hasLength(1));
      expect(outcomes, [SignOutOutcome.signedOut]);
    });

    testWidgets('"Vazgeç" (false) ve scrim / geri (null): oturum '
        'kapatılmaz → cancelled', (tester) async {
      await pump(tester);
      for (final choice in [false, null]) {
        feedback.nextDialogResult = choice;
        await tapLogout(tester);
      }

      expect(feedback.dialogs, [DialogId.dlg06, DialogId.dlg06]);
      expect(auth.callsTo('signOut'), isEmpty);
      expect(outcomes, [SignOutOutcome.cancelled, SignOutOutcome.cancelled]);
    });

    testWidgets('oturum kapatılamazsa → failed (fırlatmaz; oturum açık '
        'kalır)', (tester) async {
      await pump(tester);
      feedback.nextDialogResult = true;
      auth.failNext(AuthError.network);

      // Hata günlüğe düşer; test çıktısını kirletmesin (test bitmeden geri
      // konur: flutter_test `debugPrint`'in değişmemesini denetler).
      final original = debugPrint;
      debugPrint = (message, {wrapWidth}) {};
      try {
        await tapLogout(tester);
      } finally {
        debugPrint = original;
      }

      expect(auth.callsTo('signOut'), hasLength(1));
      expect(outcomes, [SignOutOutcome.failed]);

      // Sonraki deneme yeniden sorar ve başarır.
      feedback.nextDialogResult = true;
      await tapLogout(tester);
      expect(outcomes.last, SignOutOutcome.signedOut);
    });

    testWidgets('gerçek dialog açıkken ikinci dokunuş yeni dialog açmaz; '
        '"Çıkış yap" oturumu bir kez kapatır', (tester) async {
      await pump(tester);
      final navigatorKey = GlobalKey<NavigatorState>();
      final controller = GuToastController();
      addTearDown(controller.dispose);
      // Kendi gezginiyle gerçek servis: dialog gerçekten çizilir.
      await tester.pumpApp(
        Navigator(
          key: navigatorKey,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => _Host(outcomes: outcomes),
          ),
        ),
      );
      await GetIt.I.unregister<FeedbackService>();
      GetIt.I.registerSingleton<FeedbackService>(
        AppFeedbackService(
          navigatorKey: navigatorKey,
          toastController: controller,
        ),
      );
      auth = GetIt.I<AuthRepository>() as FakeAuthRepository;
      final state = tester.state<_HostState>(find.byType(_Host));

      unawaited(state.confirmSignOut().then(outcomes.add));
      await tester.pumpAndSettle();
      expect(find.byType(GuDialogFrame), findsOneWidget);

      // Dialog açıkken ikinci çağrı: etkisiz.
      expect(await state.confirmSignOut(), SignOutOutcome.cancelled);
      await tester.pumpAndSettle();
      expect(find.byType(GuDialogFrame), findsOneWidget);

      await tester.tap(
        find.byKey(FeedbackKeys.of(DialogId.dlg06.designId, 'logout')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GuDialogFrame), findsNothing);
      expect(auth.callsTo('signOut'), hasLength(1));
      expect(outcomes, [SignOutOutcome.signedOut]);
    });
  });
}
