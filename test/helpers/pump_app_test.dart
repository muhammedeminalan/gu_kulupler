import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_ui/gu_ui.dart';

import 'pump_app.dart';

/// Çocuğun bağlamını yakalar.
class _Probe extends StatelessWidget {
  const _Probe(this.onBuild);

  final void Function(BuildContext context) onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild(context);
    return const SizedBox.shrink();
  }
}

final class _Marker {}

final Provider<String> _probeProvider = Provider<String>((ref) => 'gerçek');

void main() {
  group('T-02 · pumpApp (kök, PLAN §16.2)', () {
    testWidgets('varsayılanlar: TR · açık · 1.0 · 390×844 · Android', (
      tester,
    ) async {
      late BuildContext ctx;
      await tester.pumpApp(_Probe((c) => ctx = c));

      final mq = MediaQuery.of(ctx);
      expect(Localizations.localeOf(ctx), const Locale('tr'));
      expect(AppLocalizations.of(ctx).localeName, 'tr');
      expect(ctx.gu.isDark, isFalse);
      expect(ctx.gu.colors, GuColors.light);
      expect(mq.textScaler, TextScaler.noScaling);
      expect(mq.size, const Size(390, 844));
      expect(mq.viewPadding, EdgeInsets.zero);
      expect(mq.viewInsets, EdgeInsets.zero);
      expect(defaultTargetPlatform, TargetPlatform.android);
      expect(Theme.of(ctx).platform, TargetPlatform.android);
      expect(find.byKey(kPumpAppChildKey), findsOneWidget);
      expect(find.byKey(kPumpAppBoundaryKey), findsOneWidget);
      expect(find.byType(ProviderScope), findsOneWidget);
    });

    testWidgets('parametreler MediaQuery / tema / dil / platforma yansır', (
      tester,
    ) async {
      late BuildContext ctx;
      const padding = EdgeInsets.only(top: 59, bottom: 34);
      await tester.pumpApp(
        _Probe((c) => ctx = c),
        locale: const Locale('en'),
        theme: ThemeMode.dark,
        textScale: 1.3,
        size: const Size(430, 932),
        platform: TargetPlatform.iOS,
        viewPadding: padding,
        keyboardInset: 320,
      );

      final mq = MediaQuery.of(ctx);
      expect(Localizations.localeOf(ctx), const Locale('en'));
      expect(AppLocalizations.of(ctx).localeName, 'en');
      expect(ctx.gu.isDark, isTrue);
      expect(ctx.gu.colors, GuColors.dark);
      expect(mq.textScaler, const TextScaler.linear(1.3));
      expect(ctx.gu.textScaler, const TextScaler.linear(1.3));
      expect(mq.size, const Size(430, 932));
      expect(mq.viewPadding, padding);
      expect(mq.viewInsets, const EdgeInsets.only(bottom: 320));
      expect(mq.padding, const EdgeInsets.only(top: 59));
      expect(defaultTargetPlatform, TargetPlatform.iOS);
      expect(Theme.of(ctx).platform, TargetPlatform.iOS);
    });

    testWidgets("overrides ProviderScope'a geçer", (tester) async {
      late BuildContext ctx;
      await tester.pumpApp(
        _Probe((c) => ctx = c),
        overrides: [_probeProvider.overrideWithValue('sahte')],
      );
      final container = ProviderScope.containerOf(ctx);
      expect(container.read(_probeProvider), 'sahte');
    });

    testWidgets('GetIt her çağrıda sıfırlanır (+ registerDefaultFakes)', (
      tester,
    ) async {
      GetIt.I.registerSingleton<_Marker>(_Marker());
      expect(GetIt.I.isRegistered<_Marker>(), isTrue);
      await tester.pumpApp(const SizedBox.shrink());
      expect(GetIt.I.isRegistered<_Marker>(), isFalse);

      GetIt.I.registerSingleton<_Marker>(_Marker());
      await tester.pumpApp(const SizedBox.shrink());
      expect(GetIt.I.isRegistered<_Marker>(), isFalse);
    });

    testWidgets('görünüm boyutu, platform ve GetIt test sonunda geri alınır', (
      tester,
    ) async {
      final initialSize = tester.view.physicalSize;
      final initialRatio = tester.view.devicePixelRatio;
      // addTearDown LIFO: bu kontrol pumpApp'ın sıfırlamalarından sonra koşar.
      addTearDown(() {
        expect(tester.view.physicalSize, initialSize);
        expect(tester.view.devicePixelRatio, initialRatio);
        expect(debugDefaultTargetPlatformOverride, isNull);
        expect(GetIt.I.isRegistered<_Marker>(), isFalse);
      });
      await tester.pumpApp(
        const SizedBox.shrink(),
        size: const Size(320, 640),
        platform: TargetPlatform.iOS,
      );
      GetIt.I.registerSingleton<_Marker>(_Marker());
      expect(tester.view.physicalSize, const Size(320, 640));
      expect(tester.view.devicePixelRatio, kPumpAppDevicePixelRatio);
    });

    testWidgets('art arda çağrıda son platform geçerli', (tester) async {
      await tester.pumpApp(
        const SizedBox.shrink(),
        platform: TargetPlatform.iOS,
      );
      expect(defaultTargetPlatform, TargetPlatform.iOS);
      await tester.pumpApp(const SizedBox.shrink());
      expect(defaultTargetPlatform, TargetPlatform.android);
    });

    test('testMediaQuery: klavye alt dolguyu sıfırın altına indirmez', () {
      final data = testMediaQuery(
        const MediaQueryData(),
        textScale: 1.6,
        viewPadding: const EdgeInsets.only(top: 24, bottom: 48),
        keyboardInset: 20,
      );
      expect(data.padding, const EdgeInsets.only(top: 24, bottom: 28));
      expect(data.viewInsets, const EdgeInsets.only(bottom: 20));
      expect(data.textScaler, const TextScaler.linear(1.6));
    });
  });
}
