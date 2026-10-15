// T-44 · A4-03 · SYS-03 liste içi varyantı (OfflineListFallback): çevrimdışı
// + boş / hata → GuOfflineState; veri varken ya da çevrimiçiyken ekranın
// kendi gövdesi; "Yeniden dene" (SYS-03.retry) hâlâ çevrimdışıysa TST-24 ve
// yenileme yok; bağlantı dönünce sessiz yenileme bir kez.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_kulupler/core/connectivity/connectivity_state.dart';
import 'package:gu_kulupler/core/connectivity/connectivity_view_model.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';
import 'package:gu_kulupler/product/widget/system/offline_list_fallback.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';

const Key _emptyKey = ValueKey<String>('list.empty');
const Key _dataKey = ValueKey<String>('list.data');

/// Liste ekranı benzeri: durum switch'inin başında koruma (view'larla aynı
/// biçim).
class _List extends ConsumerWidget {
  const _List({required this.status, required this.onReload});

  final GuListStatus status;
  final Future<void> Function() onReload;

  @override
  Widget build(BuildContext context, WidgetRef ref) => CustomScrollView(
    slivers: [
      ...switch (status) {
        _ when OfflineListFallback.applies(ref, status) => [
          OfflineListFallback.sliver(onReload: onReload),
        ],
        GuListStatus.error || GuListStatus.empty || GuListStatus.loading => [
          const SliverToBoxAdapter(child: SizedBox(key: _emptyKey, height: 40)),
        ],
        GuListStatus.data => [
          const SliverToBoxAdapter(child: SizedBox(key: _dataKey, height: 40)),
        ],
      },
    ],
  );
}

void main() {
  late FakeConnectivityService connectivity;
  late FakeFeedbackService feedback;
  late int reloads;

  Future<void> reload() async => reloads++;

  Future<void> pumpList(WidgetTester tester, GuListStatus status) async {
    await tester.pumpApp(_List(status: status, onReload: reload));
    connectivity = GetIt.I<ConnectivityService>() as FakeConnectivityService;
    feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
  }

  Future<void> goOffline(WidgetTester tester) async {
    connectivity.emit(true);
    await tester.pump();
    await tester.pump();
  }

  setUp(() => reloads = 0);

  group('T-44 · SYS-03 · liste içi çevrimdışı gövdesi', () {
    for (final status in [GuListStatus.empty, GuListStatus.error]) {
      testWidgets('çevrimdışı + ${status.name} → GuOfflineState; ekranın '
          'gövdesi çizilmez', (tester) async {
        await pumpList(tester, status);
        expect(find.byKey(_emptyKey), findsOneWidget);
        expect(find.byType(GuOfflineState), findsNothing);

        await goOffline(tester);

        expect(find.byType(GuOfflineState), findsOneWidget);
        expect(find.byKey(_emptyKey), findsNothing);
        expect(find.text(tester.l10n.sysOfflineTitle), findsOneWidget);
        expect(find.text(tester.l10n.sysOfflineFullDesc), findsOneWidget);
        expect(find.byKey(GuKey.action('SYS-03.retry')), findsOneWidget);
      });
    }

    testWidgets('çevrimdışı + veri → liste (bant kökte; gövde değişmez)', (
      tester,
    ) async {
      await pumpList(tester, GuListStatus.data);
      await goOffline(tester);
      expect(find.byKey(_dataKey), findsOneWidget);
      expect(find.byType(GuOfflineState), findsNothing);
    });

    testWidgets('çevrimdışı + yükleniyor → iskelet kalır', (tester) async {
      await pumpList(tester, GuListStatus.loading);
      await goOffline(tester);
      expect(find.byType(GuOfflineState), findsNothing);
    });

    testWidgets('"Yeniden dene" hâlâ çevrimdışıyken TST-24; yenileme yok', (
      tester,
    ) async {
      await pumpList(tester, GuListStatus.empty);
      await goOffline(tester);

      await tester.tap(find.byKey(GuKey.action('SYS-03.retry')));
      await tester.pumpAndSettle();

      expect(feedback.toasts, [ToastId.tst24]);
      expect(reloads, 0);
      expect(find.byType(GuOfflineState), findsOneWidget);
    });

    testWidgets('"Yeniden dene" bağlantı geldiyse liste bir kez yenilenir', (
      tester,
    ) async {
      await pumpList(tester, GuListStatus.error);
      await goOffline(tester);
      connectivity.nextRefresh = false;

      await tester.tap(find.byKey(GuKey.action('SYS-03.retry')));
      await tester.pumpAndSettle();

      expect(reloads, 1);
      expect(feedback.toasts, isNot(contains(ToastId.tst24)));
      expect(find.byType(GuOfflineState), findsNothing);
    });

    testWidgets('bağlantı dönünce boş / hatalı liste sessizce bir kez '
        'yenilenir', (tester) async {
      await pumpList(tester, GuListStatus.empty);
      await goOffline(tester);

      connectivity.emit(false);
      await tester.pump();
      await tester.pump();

      expect(reloads, 1);
      expect(find.byKey(_emptyKey), findsOneWidget);
    });

    testWidgets('veri varken bağlantı dönüşü yenileme tetiklemez', (
      tester,
    ) async {
      await pumpList(tester, GuListStatus.data);
      await goOffline(tester);
      connectivity.emit(false);
      await tester.pump();
      await tester.pump();
      expect(reloads, 0);
    });

    testWidgets('kutu bağlamı: çevrimiçiyken child, çevrimdışıyken SYS-03', (
      tester,
    ) async {
      await tester.pumpApp(
        OfflineListFallback(
          onReload: reload,
          child: const SizedBox(key: _emptyKey, height: 40),
        ),
      );
      connectivity = GetIt.I<ConnectivityService>() as FakeConnectivityService;
      expect(find.byKey(_emptyKey), findsOneWidget);
      await goOffline(tester);
      expect(find.byType(GuOfflineState), findsOneWidget);
    });

    testWidgets('cihaz matrisi: taşma yok', (tester) async {
      await DeviceMatrix.run(
        tester,
        (_) => _List(status: GuListStatus.empty, onReload: reload),
        overrides: [
          connectivityViewModelProvider.overrideWithBuild(
            (ref, notifier) =>
                const ConnectivityState(isOffline: true, wasOffline: true),
          ),
        ],
      );
    });
  });
}
