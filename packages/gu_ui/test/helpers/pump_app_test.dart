import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import 'pump_app.dart';

/// Çocuğun bağlamını yakalar ve durum nesnesini kaydeder.
class _Probe extends StatefulWidget {
  const _Probe(this.onBuild);

  final void Function(BuildContext context, State<_Probe> state) onBuild;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  Widget build(BuildContext context) {
    widget.onBuild(context, this);
    return const SizedBox.shrink();
  }
}

void main() {
  group('T-02 · pumpApp (gu_ui, CD-122(3))', () {
    testWidgets('varsayılanlar: TR · açık · 1.0 · 390×844 · Android', (
      tester,
    ) async {
      late BuildContext ctx;
      await tester.pumpApp(_Probe((c, _) => ctx = c));

      final mq = MediaQuery.of(ctx);
      expect(Localizations.localeOf(ctx), const Locale('tr'));
      expect(MaterialLocalizations.of(ctx), isA<GlobalMaterialLocalizations>());
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
    });

    testWidgets('parametreler MediaQuery / tema / dil / platforma yansır', (
      tester,
    ) async {
      late BuildContext ctx;
      const padding = EdgeInsets.only(top: 47, bottom: 34);
      await tester.pumpApp(
        _Probe((c, _) => ctx = c),
        locale: const Locale('en'),
        theme: ThemeMode.dark,
        textScale: 1.6,
        size: const Size(320, 640),
        platform: TargetPlatform.iOS,
        viewPadding: padding,
        keyboardInset: 320,
      );

      final mq = MediaQuery.of(ctx);
      expect(Localizations.localeOf(ctx), const Locale('en'));
      expect(ctx.gu.isDark, isTrue);
      expect(ctx.gu.colors, GuColors.dark);
      expect(mq.textScaler, const TextScaler.linear(1.6));
      expect(ctx.gu.textScaler, const TextScaler.linear(1.6));
      expect(mq.size, const Size(320, 640));
      expect(mq.viewPadding, padding);
      expect(mq.viewInsets, const EdgeInsets.only(bottom: 320));
      // Klavye alt güvenli alanı örter: padding = viewPadding − viewInsets.
      expect(mq.padding, const EdgeInsets.only(top: 47));
      expect(defaultTargetPlatform, TargetPlatform.iOS);
      expect(Theme.of(ctx).platform, TargetPlatform.iOS);
    });

    testWidgets('görünüm boyutu ve platform test sonunda geri alınır', (
      tester,
    ) async {
      final initialSize = tester.view.physicalSize;
      final initialRatio = tester.view.devicePixelRatio;
      // addTearDown LIFO: bu kontrol pumpApp'ın sıfırlamalarından sonra koşar.
      addTearDown(() {
        expect(tester.view.physicalSize, initialSize);
        expect(tester.view.devicePixelRatio, initialRatio);
        expect(debugDefaultTargetPlatformOverride, isNull);
      });
      await tester.pumpApp(
        const SizedBox.shrink(),
        size: const Size(768, 1024),
        platform: TargetPlatform.iOS,
      );
      expect(tester.view.physicalSize, const Size(768, 1024));
      expect(tester.view.devicePixelRatio, kPumpAppDevicePixelRatio);
    });

    testWidgets('her çağrı ağacı baştan kurar; son platform geçerli', (
      tester,
    ) async {
      final states = <State<_Probe>>[];
      await tester.pumpApp(
        _Probe((_, s) => states.add(s)),
        platform: TargetPlatform.iOS,
      );
      await tester.pumpApp(_Probe((_, s) => states.add(s)));
      expect(states.toSet(), hasLength(2));
      expect(defaultTargetPlatform, TargetPlatform.android);
    });

    test('testMediaQuery: klavye alt dolguyu sıfırın altına indirmez', () {
      final data = testMediaQuery(
        const MediaQueryData(),
        textScale: 1.3,
        viewPadding: const EdgeInsets.only(bottom: 48),
        keyboardInset: 20,
      );
      expect(data.padding, const EdgeInsets.only(bottom: 28));
      expect(data.viewInsets, const EdgeInsets.only(bottom: 20));
      expect(data.textScaler, const TextScaler.linear(1.3));
    });
  });
}
