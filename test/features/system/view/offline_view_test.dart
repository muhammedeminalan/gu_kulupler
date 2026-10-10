// SYS-03 · Çevrimdışı (tam ekran) — metinler, 2 aksiyon (`SYS-03.back`,
// `.retry`) ve sonuçları (hâlâ çevrimdışı → sallanma + TST-24; bağlantı
// geldi → çıkış), cihaz matrisi, aksiyon envanteri, açık + koyu golden.
// Referans: design/reference-shots/screens/SYS-03__*.webp.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_kulupler/features/system/view/offline_view.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/test_router.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';

final Key _back = GuKey.action('SYS-03.back');
final Key _retry = GuKey.action('SYS-03.retry');

FakeConnectivityService _connectivity() =>
    GetIt.I<ConnectivityService>() as FakeConnectivityService;

/// `ConnectivityViewModel`'in (GetIt) toast kaydı — TST-25 buraya düşer.
FakeFeedbackService _rootFeedback() =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;

/// Gövdeyi sallayan `Transform`'un yatay kayması.
double _shakeOffset(WidgetTester tester) => tester
    .widget<Transform>(
      find
          .ancestor(
            of: find.byType(GuEmptyState),
            matching: find.byType(Transform),
          )
          .first,
    )
    .transform
    .getTranslation()
    .x;

void main() {
  group('SYS-03 · Çevrimdışı', () {
    testWidgets('illüstrasyon, başlık, açıklama ve yeniden dene çizilir', (
      tester,
    ) async {
      await tester.pumpApp(const OfflineView());
      final l10n = tester.l10n;
      expect(find.byType(GuOfflineState), findsOneWidget);
      expect(
        tester.widget<GuIllustration>(find.byType(GuIllustration)).illustration,
        GuIllustrations.offline,
      );
      expect(find.text(l10n.sysOfflineTitle), findsOneWidget);
      expect(find.text(l10n.sysOfflineFullDesc), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(_retry),
          matching: find.text(l10n.commonRetry),
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(l10n.a11yBack), findsOneWidget);
    });

    testWidgets('aksiyon envanteri: SYS-03.back / .retry', (tester) async {
      await tester.pumpApp(const OfflineView());
      expectActionInventory(tester, 'SYS-03');
    });

    testWidgets('cihaz matrisi: taşma yok', (tester) async {
      await DeviceMatrix.run(
        tester,
        (_) => const OfflineView(),
        safeAreas: true,
      );
    });

    testWidgets('golden: açık + koyu', (tester) async {
      await goldenForThemes(tester, 'SYS-03', const OfflineView());
    });
  });

  group('SYS-03 · Çevrimdışı · aksiyonlar', () {
    testWidgets('SYS-03.retry, hâlâ çevrimdışı: gövde sallanır, TST-24 '
        'gösterilir, ekranda kalınır', (tester) async {
      final app = await TestRouter.pump(tester, location: '/offline');
      _connectivity().isOffline = true;

      await tester.tap(find.byKey(_retry));
      await tester.pump();
      await tester.pump();
      expect(_connectivity().callsTo('refresh'), hasLength(1));
      expect(app.feedback.toasts, [ToastId.tst24]);

      await tester.pump(GuMotion.shake ~/ 4);
      expect(_shakeOffset(tester), isNot(0));
      await tester.pumpAndSettle();
      expect(_shakeOffset(tester), 0);
      expect(app.location, '/offline');
      expect(find.byType(OfflineView), findsOneWidget);
    });

    testWidgets('SYS-03.retry, bağlantı geldi: TST-25 ve ekrandan çıkış', (
      tester,
    ) async {
      final app = await TestRouter.pump(tester, location: '/offline');
      _connectivity()
        ..isOffline = true
        ..nextRefresh = false;

      await tester.tap(find.byKey(_retry));
      await tester.pumpAndSettle();
      expect(app.feedback.toasts, isEmpty);
      expect(_rootFeedback().toasts, [ToastId.tst25]);
      expect(app.location, '/clubs');
      expect(find.byType(OfflineView), findsNothing);
    });

    testWidgets('SYS-03.retry, zaten çevrimiçi: toast yok, ekrandan çıkış', (
      tester,
    ) async {
      final app = await TestRouter.pump(tester, location: '/offline');
      await tester.tap(find.byKey(_retry));
      await tester.pumpAndSettle();
      expect(app.feedback.toasts, isEmpty);
      expect(_rootFeedback().toasts, isEmpty);
      expect(app.location, '/clubs');
    });

    testWidgets('SYS-03.back: ana sayfa (bağlantı yoklanmaz)', (tester) async {
      final app = await TestRouter.pump(tester, location: '/offline');
      await tester.tap(find.byKey(_back));
      await tester.pumpAndSettle();
      expect(app.location, '/clubs');
      expect(_connectivity().callsTo('refresh'), isEmpty);
    });
  });
}
