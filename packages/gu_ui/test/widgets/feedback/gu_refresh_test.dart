// T-06 · GuRefresh (widget-catalog #38; A.2 #38; ui.js:154–164; css:123–125;
// CD-24, CD-28).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

const Key _refreshKey = ValueKey<String>('refresh.area');
const Key _firstKey = ValueKey<String>('refresh.first');

/// Dokunma payını (18) aşan ilk hareket: satırlar dokunulabilir olduğundan
/// liste sürüklemeyi bu noktada kazanır, çekme buradan ölçülür.
const Offset _slop = Offset(0, 20);

Finder get _row => find.descendant(
  of: find.byType(GuRefresh),
  matching: find.byType(AnimatedContainer),
);

double _height(WidgetTester tester) => tester.getSize(_row).height;

Widget _rowAt(int index, {bool tappable = true}) => SizedBox(
  key: index == 0 ? _firstKey : null,
  height: 60,
  child: tappable
      ? GestureDetector(onTap: () {}, child: Text('Satır $index'))
      : Text('Satır $index'),
);

Widget _list({int count = 30, bool tappable = true}) => ListView(
  children: [
    for (var index = 0; index < count; index++)
      _rowAt(index, tappable: tappable),
  ],
);

/// Çekme alanında tek `ExcludeSemantics` → gösterge satırı (`aria-hidden`).
final Finder _hiddenRow = find.descendant(
  of: find.byType(GuRefresh),
  matching: find.byWidgetPredicate(
    (widget) => widget is ExcludeSemantics && widget.child is ClipRect,
  ),
);

double _turns(WidgetTester tester) =>
    tester.widget<AnimatedRotation>(find.byType(AnimatedRotation)).turns;

Future<TestGesture> _startPull(WidgetTester tester) async {
  final gesture = await tester.startGesture(const Offset(195, 300));
  await gesture.moveBy(_slop);
  await tester.pump();
  return gesture;
}

void main() {
  group('T-06 · GuRefresh', () {
    testWidgets('T-06 · GuRefresh · çekme: yükseklik min(90, dy × .6), ok 20 '
        'text.muted 180° → 0°, içerik itilir; 60 ve altında bırakma → '
        'onRefresh yok; gösterge dekoratif', (tester) async {
      const colors = GuColors.light;
      var calls = 0;
      await tester.pumpApp(
        GuRefresh(
          onRefresh: () async => calls++,
          refreshActionKey: _refreshKey,
          child: _list(),
        ),
      );
      expect(find.byKey(_refreshKey), findsOneWidget);
      expect(_height(tester), 0);
      expect(find.byType(GuIcon), findsNothing);

      final gesture = await _startPull(tester);
      expect(_height(tester), 0);

      await gesture.moveBy(const Offset(0, 50));
      await tester.pump();
      expect(_height(tester), 30);
      expect(tester.getTopLeft(find.byKey(_firstKey)).dy, 30);
      final icon = tester.widget<GuIcon>(find.byType(GuIcon));
      expect(icon.icon, GuIcons.arrowUp);
      expect(icon.size, GuSizes.refreshIcon);
      expect(icon.color, colors.textMuted);
      expect(_turns(tester), 0.5);
      expect(_hiddenRow, findsOneWidget);

      // dy 100 → 60: eşik dahil değil (ui.js:160 `pull > 60`).
      await gesture.moveBy(const Offset(0, 50));
      await tester.pump();
      expect(_height(tester), 60);
      expect(_turns(tester), 0.5);
      await gesture.up();
      await tester.pump();
      expect(calls, 0);
      expect(_height(tester), 0);
      expect(find.byType(GuIcon), findsNothing);
      expect(find.byType(GuSpinner), findsNothing);
    });

    testWidgets('T-06 · GuRefresh · 60 aşıldı → ok 0°, üst sınır 90; bırakınca '
        'onRefresh bir kez, 48 px + GuSpinner, Future bitince kapanır; '
        'yenilerken yeni çekme başlamaz', (tester) async {
      const colors = GuColors.light;
      final done = Completer<void>();
      var calls = 0;
      await tester.pumpApp(
        GuRefresh(
          onRefresh: () {
            calls++;
            return done.future;
          },
          child: _list(),
        ),
      );
      final gesture = await _startPull(tester);
      await gesture.moveBy(const Offset(0, 102));
      await tester.pump();
      expect(_height(tester), closeTo(61.2, 1e-9));
      expect(_turns(tester), 0);
      await gesture.moveBy(const Offset(0, 200));
      await tester.pump();
      expect(_height(tester), GuSizes.refreshMaxPull);

      await gesture.up();
      expect(calls, 1);
      await tester.pump();
      // Yükseklik 90 → 48, GuMotion.base ile.
      expect(_height(tester), GuSizes.refreshMaxPull);
      await tester.pump(GuMotion.base ~/ 2);
      expect(_height(tester), inExclusiveRange(48, 90));
      await tester.pump(GuMotion.base);
      expect(_height(tester), GuSizes.refreshIndicatorHeight);
      expect(find.byType(GuIcon), findsNothing);
      final spinner = tester.widget<GuSpinner>(find.byType(GuSpinner));
      expect(spinner.color, colors.textPrimary);
      expect(spinner.size, GuSizes.spinner);
      expect(tester.getTopLeft(find.byKey(_firstKey)).dy, 48);

      // Yenileme sürerken çekme yok sayılır.
      final again = await _startPull(tester);
      await again.moveBy(const Offset(0, 150));
      await tester.pump();
      expect(_height(tester), GuSizes.refreshIndicatorHeight);
      await again.up();
      await tester.pump();
      expect(calls, 1);

      done.complete();
      await tester.pump();
      await tester.pump();
      expect(_height(tester), 0);
      expect(find.byType(GuSpinner), findsNothing);
      expect(calls, 1);
    });

    testWidgets('T-06 · GuRefresh · üstte değilken başlamaz; çekme açıkken '
        'liste kaymaz, geri çıkınca kapanır; iptal tetiklemez; iOS üst kenarda '
        'esnemez; kısa içerik de çekilir; kaydırma sonu dolgusu (noSafe → 0)', (
      tester,
    ) async {
      var calls = 0;
      final controller = ScrollController();
      addTearDown(controller.dispose);
      Widget refresh({bool noSafe = false, Widget? child}) => GuRefresh(
        onRefresh: () async => calls++,
        noSafe: noSafe,
        child:
            child ??
            ListView.builder(
              controller: controller,
              itemCount: 30,
              itemBuilder: (context, index) => _rowAt(index),
            ),
      );

      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        await tester.pumpApp(refresh(), platform: platform);
        // Üstte değil → çekme başlamaz (ui.js:157); üste varınca da açılmaz.
        controller.jumpTo(200);
        await tester.pump();
        var gesture = await _startPull(tester);
        await gesture.moveBy(const Offset(0, 400));
        await tester.pump();
        expect(controller.offset, 0, reason: '$platform');
        expect(_height(tester), 0);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(calls, 0);

        // Üstte: liste yerinde kalır (iOS'ta esneme yok), gösterge açılır.
        gesture = await _startPull(tester);
        await gesture.moveBy(const Offset(0, 100));
        await tester.pump();
        expect(controller.offset, 0, reason: '$platform');
        expect(_height(tester), 60);
        // Parmak geri çıkar: önce gösterge kapanır, liste kaymaz.
        await gesture.moveBy(const Offset(0, -50));
        await tester.pump();
        expect(_height(tester), 30);
        expect(controller.offset, 0);
        // Başlangıcın üstüne çıkınca gösterge kapanır, liste kaymaya başlar.
        await gesture.moveBy(const Offset(0, -60));
        await gesture.moveBy(const Offset(0, -40));
        await tester.pump();
        expect(_height(tester), 0);
        expect(controller.offset, greaterThan(0));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(calls, 0);
        controller.jumpTo(0);
        await tester.pump();

        // İptal: eşik aşılmış olsa da yenileme yok.
        gesture = await _startPull(tester);
        await gesture.moveBy(const Offset(0, 140));
        await tester.pump();
        expect(_height(tester), 84);
        await gesture.cancel();
        await tester.pump();
        expect(_height(tester), 0);
        expect(calls, 0);
      }

      // Kısa içerik: liste kaymasa da çekilir. Boş alanda liste tek
      // algılayıcıdır → sürüklemeyi parmak inince kazanır (pay yok).
      await tester.pumpApp(refresh(child: _list(count: 2, tappable: false)));
      final gesture = await _startPull(tester);
      expect(_height(tester), 12);
      await gesture.moveBy(const Offset(0, 110));
      await tester.pump();
      expect(_height(tester), 78);
      await gesture.up();
      await tester.pump();
      expect(calls, 1);
      await tester.pump();
      expect(_height(tester), 0);

      // css:123 `padding-bottom: safe-bottom + 8`; css:125 `.no-safe` → 0.
      for (final (noSafe, keyboard, expected) in [
        (false, 0.0, 34.0 + 8),
        (false, 320.0, 8.0),
        (true, 0.0, 0.0),
      ]) {
        late EdgeInsets padding;
        await tester.pumpApp(
          refresh(
            noSafe: noSafe,
            child: Builder(
              builder: (context) {
                padding = MediaQuery.paddingOf(context);
                return _list(count: 2);
              },
            ),
          ),
          viewPadding: const EdgeInsets.only(top: 47, bottom: 34),
          keyboardInset: keyboard,
        );
        expect(padding.bottom, expected, reason: '$noSafe / $keyboard');
        expect(padding.top, 47);
      }
    });
  });
}
