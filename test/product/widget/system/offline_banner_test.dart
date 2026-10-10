// SYS-03 · çevrimdışı bandı (OfflineBanner) — görünür / gizli, kabuk dışı
// kapalı, canlı bağlantı değişimi ve TST-25, dar ekran + büyük yazı.
// Referans: design/reference-shots/states/CLB-01__offline.webp.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_kulupler/core/connectivity/connectivity_state.dart';
import 'package:gu_kulupler/core/connectivity/connectivity_view_model.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';
import 'package:gu_kulupler/product/widget/system/offline_banner.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';

const Key _childKey = ValueKey<String>('banner.child');
const Widget _child = SizedBox.expand(key: _childKey);

final Override _offline = connectivityViewModelProvider.overrideWithBuild(
  (ref, notifier) => const ConnectivityState(isOffline: true, wasOffline: true),
);

void main() {
  group('SYS-03 · çevrimdışı bandı', () {
    testWidgets('çevrimiçiyken bant yok', (tester) async {
      await tester.pumpApp(const OfflineBanner(child: _child));
      expect(find.byType(GuBanner), findsNothing);
      expect(tester.getRect(find.byKey(_childKey)).top, 0);
    });

    testWidgets('çevrimdışıyken GuBanner(offline) + sys.offline.banner metni; '
        'kapatma düğmesi yok', (tester) async {
      await tester.pumpApp(
        const OfflineBanner(child: _child),
        overrides: [_offline],
        viewPadding: const EdgeInsets.only(top: 47),
      );
      final banner = tester.widget<GuBanner>(find.byType(GuBanner));
      expect(banner.kind, GuBannerKind.offline);
      expect(banner.text, tester.l10n.sysOfflineBanner);
      expect(banner.onDismiss, isNull);
      expect(banner.onAction, isNull);
      // Bant gerçek üst güvenli alanın altında; içerik bandın altında.
      final rect = tester.getRect(find.byType(GuBanner));
      expect(rect.top, 47);
      expect(rect.width, 390);
      expect(tester.getRect(find.byKey(_childKey)).top, rect.bottom);
    });

    testWidgets('enabled: false (uygulama kabuğu dışı) → çevrimdışıyken de '
        'bant yok', (tester) async {
      await tester.pumpApp(
        const OfflineBanner(enabled: false, child: _child),
        overrides: [_offline],
      );
      expect(find.byType(GuBanner), findsNothing);
    });

    testWidgets('canlı: bağlantı kopunca bant gelir; dönünce kalkar ve '
        'TST-25 gösterilir', (tester) async {
      await tester.pumpApp(const OfflineBanner(child: _child));
      final connectivity =
          GetIt.I<ConnectivityService>() as FakeConnectivityService;
      final feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
      expect(find.byType(GuBanner), findsNothing);

      connectivity.emit(true);
      await tester.pump();
      await tester.pump();
      expect(find.byType(GuBanner), findsOneWidget);
      expect(feedback.toasts, isEmpty);

      connectivity.emit(false);
      await tester.pump();
      await tester.pump();
      expect(find.byType(GuBanner), findsNothing);
      expect(feedback.toasts, [ToastId.tst25]);
    });

    testWidgets('cihaz matrisi: taşma yok (320 dp, %160 dahil)', (
      tester,
    ) async {
      await DeviceMatrix.run(
        tester,
        (_) => const OfflineBanner(child: _child),
        overrides: [_offline],
        safeAreas: true,
      );
    });
  });
}
