// Tasarım hataları turu (2026-10-16) · GuContentFade / GuSliverContentFade /
// GuFadeIndexedStack (widget-catalog ek-10; kullanıcı kararı: sekme ve
// içerik değişiminde kısa solma — `GuMotion.tabSwitch`, D-06 eki).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

/// [of] içeriğini saran en yakın `GuContentFade` / `GuSliverContentFade`
/// solmasının opaklığı (sayfa geçişinin `FadeTransition`'ı sayılmaz).
double _opacity(WidgetTester tester, Finder of) {
  final sliver = find.ancestor(
    of: of,
    matching: find.byType(SliverFadeTransition),
  );
  if (sliver.evaluate().isNotEmpty) {
    return tester.widget<SliverFadeTransition>(sliver.first).opacity.value;
  }
  final fade = find.descendant(
    of: find.ancestor(of: of, matching: find.byType(GuContentFade)).first,
    matching: find.byType(FadeTransition),
  );
  return tester.widget<FadeTransition>(fade.first).opacity.value;
}

/// Seçili değeri değiştirilebilen kap; hareket azaltma isteğe bağlı.
class _Host extends StatefulWidget {
  const _Host({required this.builder, this.reduceMotion = false});

  final Widget Function(int value) builder;
  final bool reduceMotion;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  int value = 0;

  void select(int next) => setState(() => value = next);

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(disableAnimations: widget.reduceMotion),
    child: Builder(builder: (_) => widget.builder(value)),
  );
}

_HostState _host(WidgetTester tester) =>
    tester.state<_HostState>(find.byType(_Host));

Future<void> _select(WidgetTester tester, int value) async {
  _host(tester).select(value);
  await tester.pump();
}

/// Sayaçlı çocuk: hâl korunuyor mu?
class _Counter extends StatefulWidget {
  const _Counter(this.label, {super.key});

  final String label;

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int taps = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => setState(() => taps++),
    child: Text('${widget.label}:$taps'),
  );
}

void main() {
  group('GuContentFade', () {
    testWidgets('ilk çizimde opak; değer değişince saydamdan '
        '`GuMotion.tabSwitch` boyunca solar, anlam ağacı yerinde', (
      tester,
    ) async {
      await tester.pumpApp(
        _Host(
          builder: (value) =>
              GuContentFade(value: value, child: Text('içerik $value')),
        ),
      );
      expect(_opacity(tester, find.text('içerik 0')), 1);

      await _select(tester, 1);
      expect(find.text('içerik 1'), findsOneWidget);
      expect(_opacity(tester, find.text('içerik 1')), 0);
      expect(find.bySemanticsLabel('içerik 1'), findsOneWidget);

      await tester.pump(GuMotion.tabSwitch ~/ 2);
      final mid = _opacity(tester, find.text('içerik 1'));
      expect(mid, greaterThan(0));
      expect(mid, lessThan(1));

      await tester.pump(GuMotion.tabSwitch ~/ 2);
      expect(_opacity(tester, find.text('içerik 1')), 1);
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('değer aynıysa (yeniden çizim) solma yok', (tester) async {
      await tester.pumpApp(
        _Host(
          builder: (value) =>
              const GuContentFade(value: 'sabit', child: Text('içerik')),
        ),
      );
      await _select(tester, 1);
      expect(_opacity(tester, find.text('içerik')), 1);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('hareket azaltılmışsa anında opak', (tester) async {
      await tester.pumpApp(
        _Host(
          reduceMotion: true,
          builder: (value) =>
              GuContentFade(value: value, child: Text('içerik $value')),
        ),
      );
      await _select(tester, 1);
      expect(_opacity(tester, find.text('içerik 1')), 1);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('GuSliverContentFade', () {
    testWidgets('dilim değer değişince solar', (tester) async {
      await tester.pumpApp(
        _Host(
          builder: (value) => CustomScrollView(
            slivers: [
              GuSliverContentFade(
                value: value,
                sliver: SliverToBoxAdapter(child: Text('dilim $value')),
              ),
            ],
          ),
        ),
      );
      expect(_opacity(tester, find.text('dilim 0')), 1);
      await _select(tester, 1);
      expect(_opacity(tester, find.text('dilim 1')), 0);
      await tester.pumpAndSettle();
      expect(_opacity(tester, find.text('dilim 1')), 1);
    });
  });

  group('GuFadeIndexedStack', () {
    Widget stack(int index, {bool lazy = false}) => GuFadeIndexedStack(
      index: index,
      lazy: lazy,
      children: const [
        _Counter('a', key: ValueKey<String>('a')),
        _Counter('b', key: ValueKey<String>('b')),
        _Counter('c', key: ValueKey<String>('c')),
      ],
    );

    testWidgets('yalnızca seçili çocuk sahnede; hâl korunur; seçim '
        'değişince solar', (tester) async {
      await tester.pumpApp(_Host(builder: stack));
      expect(find.text('a:0'), findsOneWidget);
      expect(find.text('b:0'), findsNothing);
      // Sahne dışı çocuk ağaçta (hâl tutulur).
      expect(find.text('b:0', skipOffstage: false), findsOneWidget);

      await tester.tap(find.text('a:0'));
      await tester.pump();
      expect(find.text('a:1'), findsOneWidget);

      await _select(tester, 1);
      expect(find.text('a:1'), findsNothing);
      expect(find.text('b:0'), findsOneWidget);
      expect(_opacity(tester, find.text('b:0')), 0);
      await tester.pumpAndSettle();
      expect(_opacity(tester, find.text('b:0')), 1);

      await _select(tester, 0);
      await tester.pumpAndSettle();
      expect(find.text('a:1'), findsOneWidget);
    });

    testWidgets('sahne dışı çocuğun saati durur (TickerMode)', (tester) async {
      await tester.pumpApp(_Host(builder: stack));
      bool tickerOf(String key) => TickerMode.valuesOf(
        tester.element(find.byKey(ValueKey<String>(key), skipOffstage: false)),
      ).enabled;
      expect(tickerOf('a'), isTrue);
      expect(tickerOf('b'), isFalse);
      await _select(tester, 1);
      expect(tickerOf('a'), isFalse);
      expect(tickerOf('b'), isTrue);
    });

    testWidgets('lazy: seçilmemiş çocuk kurulmaz; seçilince kurulur ve '
        'kalır', (tester) async {
      await tester.pumpApp(
        _Host(builder: (index) => stack(index, lazy: true)),
      );
      expect(find.text('b:0', skipOffstage: false), findsNothing);
      expect(find.text('c:0', skipOffstage: false), findsNothing);

      await _select(tester, 1);
      await tester.pumpAndSettle();
      expect(find.text('b:0'), findsOneWidget);

      await _select(tester, 0);
      await tester.pumpAndSettle();
      expect(find.text('b:0', skipOffstage: false), findsOneWidget);
      expect(find.text('c:0', skipOffstage: false), findsNothing);
    });

    testWidgets('hareket azaltılmışsa geçiş anında', (tester) async {
      await tester.pumpApp(_Host(reduceMotion: true, builder: stack));
      await _select(tester, 2);
      expect(_opacity(tester, find.text('c:0')), 1);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
