// T-07 · GuPageTransitions (PLAN §13.6, navigation.md §5, D-06, CD-55).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/product/navigation/gu_page_transitions.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

const LocalKey _homeKey = ValueKey<String>('page.home');
const LocalKey _nextKey = ValueKey<String>('page.next');
const Key _homeChild = ValueKey<String>('child.home');
const Key _nextChild = ValueKey<String>('child.next');

/// `pages` ile kurulan gezgin: ikinci sayfa [second] kurucusundan gelir.
class _Pages extends StatelessWidget {
  const _Pages({required this.second, this.reduceMotion = false});

  final Page<void> Function(BuildContext context)? second;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
    child: Builder(
      builder: (context) => Navigator(
        pages: [
          GuPageTransitions.platform<void>(
            key: _homeKey,
            child: const SizedBox.expand(key: _homeChild),
          ),
          if (second case final build?) build(context),
        ],
        onDidRemovePage: (_) {},
      ),
    ),
  );
}

Page<void> _fade(BuildContext context) => GuPageTransitions.fade<void>(
  context: context,
  key: _nextKey,
  child: const SizedBox.expand(key: _nextChild),
);

double _opacity(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find
          .ancestor(
            of: find.byKey(_nextChild),
            matching: find.byType(FadeTransition),
          )
          .first,
    )
    .opacity
    .value;

void main() {
  group('T-07 · GuPageTransitions', () {
    testWidgets('platform → MaterialPage (anahtar + çocuk)', (tester) async {
      final page = GuPageTransitions.platform<int>(
        key: _homeKey,
        child: const SizedBox(key: _homeChild),
      );
      expect(page, isA<MaterialPage<int>>());
      expect(page.key, _homeKey);
      expect((page as MaterialPage<int>).child.key, _homeChild);
    });

    testWidgets('fade → CustomTransitionPage, süre GuMotion.base (iki yön)', (
      tester,
    ) async {
      late Page<void> page;
      await tester.pumpApp(
        _Pages(second: (context) => page = _fade(context)),
      );
      expect(page, isA<CustomTransitionPage<void>>());
      final custom = page as CustomTransitionPage<void>;
      expect(custom.key, _nextKey);
      expect(custom.transitionDuration, GuMotion.base);
      expect(custom.reverseTransitionDuration, GuMotion.base);
    });

    testWidgets('fade: opaklık easeStandard ile 0 → 1 solar', (tester) async {
      // İlk kurulumda sayfalar animasyonsuz gelir; geçişi görmek için ikinci
      // sayfa sonradan eklenir.
      final pages = ValueNotifier<bool>(false);
      addTearDown(pages.dispose);
      await tester.pumpApp(
        ValueListenableBuilder<bool>(
          valueListenable: pages,
          builder: (context, show, _) => _Pages(second: show ? _fade : null),
        ),
      );
      expect(find.byKey(_nextChild), findsNothing);
      pages.value = true;
      await tester.pump();
      await tester.pump();
      expect(_opacity(tester), 0);
      await tester.pump(GuMotion.base ~/ 2);
      expect(
        _opacity(tester),
        closeTo(GuMotion.easeStandard.transform(0.5), 0.001),
      );
      await tester.pumpAndSettle();
      expect(_opacity(tester), 1);
      expect(find.byKey(_nextChild), findsOneWidget);
    });

    testWidgets('azaltılmış harekette süre sıfır: sayfa anında görünür', (
      tester,
    ) async {
      late Page<void> page;
      final pages = ValueNotifier<bool>(false);
      addTearDown(pages.dispose);
      await tester.pumpApp(
        ValueListenableBuilder<bool>(
          valueListenable: pages,
          builder: (context, show, _) => _Pages(
            reduceMotion: true,
            second: show ? (context) => page = _fade(context) : null,
          ),
        ),
      );
      pages.value = true;
      await tester.pump();
      await tester.pump();
      final custom = page as CustomTransitionPage<void>;
      expect(custom.transitionDuration, Duration.zero);
      expect(custom.reverseTransitionDuration, Duration.zero);
      expect(_opacity(tester), 1);
    });
  });
}
