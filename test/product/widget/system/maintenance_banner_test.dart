// T-11 · MaintenanceBanner (CD-48, K-27): Remote Config `maintenance_message`
// doluyken bilgi bandı; kapatılamaz, boş metinde çizilmez, çevrimdışı
// bandının altında, dar ekranda taşmaz.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/connectivity/connectivity_state.dart';
import 'package:gu_kulupler/core/connectivity/connectivity_view_model.dart';
import 'package:gu_kulupler/product/init/app_gate_state.dart';
import 'package:gu_kulupler/product/init/app_gate_view_model.dart';
import 'package:gu_kulupler/product/widget/system/maintenance_banner.dart';
import 'package:gu_kulupler/product/widget/system/offline_banner.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fakes/fake_remote_config_service.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/pump_app.dart';

const Key _childKey = ValueKey<String>('banner.child');
const Widget _child = SizedBox.expand(key: _childKey);
const String _message = 'Bu gece 02.00–04.00 arası bakım çalışması yapılacak.';

final Override _withMessage = appGateViewModelProvider.overrideWithBuild(
  (ref, notifier) => const AppGateState(maintenanceMessage: _message),
);

void main() {
  group('T-11 · MaintenanceBanner', () {
    testWidgets('mesaj boşken çizilmez', (tester) async {
      await tester.pumpApp(const MaintenanceBanner(child: _child));
      await tester.pump();
      expect(find.byType(GuBanner), findsNothing);
      expect(tester.getRect(find.byKey(_childKey)).top, 0);
    });

    testWidgets('mesaj doluyken GuBanner(info): metin olduğu gibi, kapatma ve '
        'eylem düğmesi yok', (tester) async {
      await tester.pumpApp(
        const MaintenanceBanner(child: _child),
        overrides: [_withMessage],
        viewPadding: const EdgeInsets.only(top: 24),
      );
      final banner = tester.widget<GuBanner>(find.byType(GuBanner));
      expect(banner.kind, GuBannerKind.info);
      expect(banner.text, _message);
      expect(banner.onDismiss, isNull);
      expect(banner.onAction, isNull);
      expect(find.byType(GuIconButton), findsNothing);
      final rect = tester.getRect(find.byType(GuBanner));
      expect(rect.top, 24);
      expect(tester.getRect(find.byKey(_childKey)).top, rect.bottom);
    });

    testWidgets('canlı: Remote Config güncellenince bant gelir; mesaj '
        'boşalınca kalkar', (tester) async {
      await tester.pumpApp(const MaintenanceBanner(child: _child));
      await tester.pump();
      final config = GetIt.I<RemoteConfigService>() as FakeRemoteConfigService;
      expect(find.byType(GuBanner), findsNothing);

      config.values[RemoteConfigKeys.maintenanceMessage] = _message;
      config.configUpdatedController.add(null);
      await tester.pump();
      await tester.pump();
      expect(tester.widget<GuBanner>(find.byType(GuBanner)).text, _message);

      config.values[RemoteConfigKeys.maintenanceMessage] = '';
      config.configUpdatedController.add(null);
      await tester.pump();
      await tester.pump();
      expect(find.byType(GuBanner), findsNothing);
    });

    testWidgets('çevrimdışı bandının altında durur', (tester) async {
      await tester.pumpApp(
        const OfflineBanner(child: MaintenanceBanner(child: _child)),
        overrides: [
          _withMessage,
          connectivityViewModelProvider.overrideWithBuild(
            (ref, notifier) => const ConnectivityState(isOffline: true),
          ),
        ],
        viewPadding: const EdgeInsets.only(top: 47),
      );
      final banners = tester.widgetList<GuBanner>(find.byType(GuBanner));
      expect(banners.map((b) => b.kind), [
        GuBannerKind.offline,
        GuBannerKind.info,
      ]);
      final offline = tester.getRect(find.byType(GuBanner).first);
      final maintenance = tester.getRect(find.byType(GuBanner).last);
      expect(offline.top, 47);
      expect(maintenance.top, offline.bottom);
      expect(tester.getRect(find.byKey(_childKey)).top, maintenance.bottom);
    });

    testWidgets('cihaz matrisi: uzun mesaj taşmaz (320 dp, %160 dahil)', (
      tester,
    ) async {
      await DeviceMatrix.run(
        tester,
        (_) => const MaintenanceBanner(child: _child),
        overrides: [_withMessage],
        safeAreas: true,
      );
    });
  });
}
