// T-06 · GuListState (widget-catalog #26; CD-118; ui.js:115–121; CLAUDE.md §4).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/src/widgets/feedback/gu_list_state.dart';
import 'package:gu_ui/src/widgets/feedback/gu_skeleton.dart';

import '../../helpers/pump_app.dart';

Widget _list(
  GuListStatus status, {
  WidgetBuilder? skeletonBuilder,
  int skeletonCount = 5,
  GuSkeletonVariant skeletonVariant = GuSkeletonVariant.tile,
}) => SingleChildScrollView(
  child: GuListState(
    status: status,
    dataBuilder: (_) => const Text('dolu'),
    emptyBuilder: (_) => const Text('boş'),
    errorBuilder: (_) => const Text('hata'),
    skeletonBuilder: skeletonBuilder,
    skeletonCount: skeletonCount,
    skeletonVariant: skeletonVariant,
    skeletonSemanticLabel: 'Yükleniyor',
  ),
);

void main() {
  group('T-06 · GuListState', () {
    test('T-06 · GuListState · GuListStatus.resolve önceliği: hata → '
        'yükleniyor → boş → dolu', () {
      GuListStatus resolve({
        bool isError = false,
        bool isLoading = false,
        bool isEmpty = false,
      }) => GuListStatus.resolve(
        isError: isError,
        isLoading: isLoading,
        isEmpty: isEmpty,
      );
      expect(
        resolve(isError: true, isLoading: true, isEmpty: true),
        GuListStatus.error,
      );
      expect(resolve(isError: true), GuListStatus.error);
      expect(resolve(isLoading: true, isEmpty: true), GuListStatus.loading);
      expect(resolve(isLoading: true), GuListStatus.loading);
      expect(resolve(isEmpty: true), GuListStatus.empty);
      expect(resolve(), GuListStatus.data);
    });

    testWidgets('T-06 · GuListState · duruma göre tek gövde; varsayılan '
        'iskelet GuSkeletonList(5, tile) + etiket; özel iskelet', (
      tester,
    ) async {
      for (final (status, label) in [
        (GuListStatus.error, 'hata'),
        (GuListStatus.empty, 'boş'),
        (GuListStatus.data, 'dolu'),
      ]) {
        await tester.pumpApp(_list(status));
        expect(find.byType(Text), findsOneWidget, reason: '$status');
        expect(find.text(label), findsOneWidget, reason: '$status');
        expect(find.byType(GuSkeletonList), findsNothing, reason: '$status');
      }

      await tester.pumpApp(_list(GuListStatus.loading));
      expect(find.byType(Text), findsNothing);
      var skeleton = tester.widget<GuSkeletonList>(
        find.byType(GuSkeletonList),
      );
      expect(skeleton.count, 5);
      expect(skeleton.variant, GuSkeletonVariant.tile);
      expect(skeleton.semanticLabel, 'Yükleniyor');
      expect(find.byType(GuSkeleton), findsNWidgets(15));

      await tester.pumpApp(
        _list(
          GuListStatus.loading,
          skeletonCount: 2,
          skeletonVariant: GuSkeletonVariant.card,
        ),
      );
      skeleton = tester.widget<GuSkeletonList>(find.byType(GuSkeletonList));
      expect(skeleton.count, 2);
      expect(skeleton.variant, GuSkeletonVariant.card);

      await tester.pumpApp(
        _list(
          GuListStatus.loading,
          skeletonBuilder: (_) => const Text('özel iskelet'),
        ),
      );
      expect(find.text('özel iskelet'), findsOneWidget);
      expect(find.byType(GuSkeletonList), findsNothing);
    });
  });
}
