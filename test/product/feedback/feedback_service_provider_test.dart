// T-07 · feedbackServiceProvider (CD-93): view katmanının GetIt köprüsü.
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';

import '../../fakes/fake_feedback_service.dart';
import '../../helpers/test_container.dart';

void main() {
  group('T-07 · feedbackServiceProvider', () {
    setUp(GetIt.I.reset);
    tearDown(GetIt.I.reset);

    test('GetIt kaydını verir ve canlı tutar (keepAlive)', () {
      final fake = FakeFeedbackService();
      GetIt.I.registerSingleton<FeedbackService>(fake);
      final container = createContainer();
      expect(container.read(feedbackServiceProvider), same(fake));
      expect(container.read(feedbackServiceProvider), same(fake));
      expect(feedbackServiceProvider.isAutoDispose, isFalse);
    });

    test('overrideWithValue ile testte değiştirilir', () {
      final fake = FakeFeedbackService();
      final container = createContainer(
        overrides: [feedbackServiceProvider.overrideWithValue(fake)],
      );
      expect(container.read(feedbackServiceProvider), same(fake));
    });
  });
}
