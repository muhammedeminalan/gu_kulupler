// T-06 · GuOfflineState (widget-catalog #25; CD-27; ui.js:110–114; css:334,
// 421).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

const _title = 'Çevrimdışısın';
const _description =
    'Önbellekte gösterilecek veri yok. Bağlantı gelince yeniden dene.';

/// Gövdenin yatay kayması (dp).
double _shift(WidgetTester tester) => tester
    .widget<Transform>(
      find
          .descendant(
            of: find.byType(GuOfflineState),
            matching: find.byType(Transform),
          )
          .first,
    )
    .transform
    .getTranslation()
    .x;

void main() {
  group('T-06 · GuOfflineState', () {
    testWidgets('T-06 · GuOfflineState · illüstrasyon 140, açıklama sınırsız, '
        'yeniden dene; false → 400 ms sallanma (0 / −8 / 8 / −5 / 5 / 0), '
        'true → sallanmaz; beklerken çift dokunma yok', (tester) async {
      final retryKey = GuKey.action('SYS-03.retry');
      var pending = Completer<bool>();
      var retries = 0;
      await tester.pumpApp(
        Center(
          child: GuOfflineState(
            title: _title,
            description: _description,
            retryLabel: 'Yeniden dene',
            onRetry: () {
              retries++;
              return pending.future;
            },
            retryActionKey: retryKey,
          ),
        ),
      );
      final body = tester.widget<GuEmptyState>(find.byType(GuEmptyState));
      expect(body.illustration, GuIllustrations.offline);
      expect(body.layout, GuEmptyStateLayout.regular);
      expect(body.descriptionMaxWidth, isNull);
      expect(
        tester.getSize(find.byType(GuIllustration)),
        const Size.square(GuSizes.illustration),
      );
      expect(find.text(_title), findsOneWidget);
      // SYS-03: açıklama 280'den geniş (dolgu içi 342).
      expect(
        tester.getSize(find.text(_description)).width,
        greaterThan(GuSizes.emptyDescMaxWidth),
      );
      final retry = tester.widget<GuButton>(find.byKey(retryKey));
      expect(retry.variant, GuButtonVariant.primary);
      expect(retry.icon, GuIcons.refreshCw);
      expect(_shift(tester), 0);

      // Beklerken ikinci dokunma yok sayılır.
      await tester.tap(find.byKey(retryKey));
      await tester.tap(find.byKey(retryKey));
      expect(retries, 1);

      // Hâlâ çevrimdışı → sallanır.
      pending.complete(false);
      await tester.pump();
      await tester.pump();
      for (final (fraction, offset) in [
        (0.2, -8.0),
        (0.4, 8.0),
        (0.6, -5.0),
        (0.8, 5.0),
      ]) {
        await tester.pump(GuMotion.shake * 0.2);
        expect(
          _shift(tester),
          moreOrLessEquals(offset, epsilon: 0.01),
          reason: '%${fraction * 100}',
        );
      }
      await tester.pumpAndSettle();
      expect(_shift(tester), 0);

      // Bağlantı geldi → sallanmaz.
      pending = Completer<bool>()..complete(true);
      await tester.tap(find.byKey(retryKey));
      await tester.pump();
      await tester.pump(GuMotion.shake * 0.2);
      expect(retries, 2);
      expect(_shift(tester), 0);
      await tester.pumpAndSettle();
    });

    testWidgets('T-06 · GuOfflineState · azaltılmış harekette sallanmaz; '
        '320 dp × metin ölçeği 1.6 → taşma yok', (tester) async {
      final retryKey = GuKey.action('SYS-03.retry');
      await tester.pumpApp(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: SingleChildScrollView(
              child: GuOfflineState(
                title: _title,
                description: _description,
                retryLabel: 'Bağlantıyı yeniden kontrol et ve tekrar dene',
                onRetry: () async => false,
                retryActionKey: retryKey,
              ),
            ),
          ),
        ),
        size: const Size(320, 640),
        textScale: 1.6,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(retryKey));
      await tester.pump();
      await tester.pump(GuMotion.shake * 0.2);
      expect(_shift(tester), 0);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
