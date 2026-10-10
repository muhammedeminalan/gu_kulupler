// T-06 · GuErrorState (widget-catalog #24; CD-27, CD-118; ui.js:104–109;
// css:152).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

const _title = 'Bir şeyler ters gitti';
const _description =
    'İçerik yüklenemedi. Bağlantını kontrol edip yeniden deneyebilirsin.';

void main() {
  group('T-06 · GuErrorState', () {
    testWidgets('T-06 · GuErrorState · tam ekran (140, 32 / 24) + ana sayfa; '
        'yeniden dene Future beklenirken loading, çift dokunma yok; inline '
        '(96, 24 / 16); canlı bölge', (tester) async {
      final handle = tester.ensureSemantics();
      final retryKey = GuKey.action('SYS-02.retry');
      final homeKey = GuKey.action('SYS-02.home');
      var pending = Completer<void>();
      var retries = 0;
      var homes = 0;

      await tester.pumpApp(
        Align(
          alignment: Alignment.topCenter,
          child: GuErrorState(
            title: _title,
            description: _description,
            retryLabel: 'Yeniden dene',
            onRetry: () {
              retries++;
              return pending.future;
            },
            retryActionKey: retryKey,
            homeLabel: 'Ana sayfaya dön',
            onHome: () => homes++,
            homeActionKey: homeKey,
          ),
        ),
      );
      final body = tester.widget<GuEmptyState>(find.byType(GuEmptyState));
      expect(body.illustration, GuIllustrations.error);
      expect(body.layout, GuEmptyStateLayout.regular);
      expect(
        tester.getRect(find.byType(GuIllustration)),
        const Rect.fromLTWH(125, GuSizes.emptyPaddingY, 140, 140),
      );
      expect(find.text(_title), findsOneWidget);
      expect(find.text(_description), findsOneWidget);
      // `role="alert"`.
      expect(
        tester.getSemantics(find.byType(GuEmptyState)),
        isSemantics(isLiveRegion: true),
      );

      GuButton retry() => tester.widget<GuButton>(find.byKey(retryKey));
      expect(retry().variant, GuButtonVariant.primary);
      expect(retry().icon, GuIcons.refreshCw);
      expect(retry().loading, isFalse);
      expect(
        tester.widget<GuButton>(find.byKey(homeKey)).variant,
        GuButtonVariant.text,
      );
      // `.row.gap8`: aynı satır, 8 dp aralık.
      expect(
        tester.getCenter(find.byKey(homeKey)).dy,
        tester.getCenter(find.byKey(retryKey)).dy,
      );
      expect(
        tester.getTopLeft(find.byKey(homeKey)).dx,
        tester.getTopRight(find.byKey(retryKey)).dx + GuSpacing.s8,
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));

      await tester.tap(find.byKey(retryKey));
      await tester.pump();
      expect(retries, 1);
      expect(retry().loading, isTrue);
      await tester.tap(find.byKey(retryKey));
      await tester.pump();
      expect(retries, 1);
      pending.complete();
      await tester.pumpAndSettle();
      expect(retry().loading, isFalse);
      pending = Completer<void>()..complete();
      await tester.tap(find.byKey(retryKey));
      await tester.pumpAndSettle();
      expect(retries, 2);

      await tester.tap(find.byKey(homeKey));
      expect(homes, 1);
      await tester.pumpAndSettle();

      // inline (GuListState içi).
      await tester.pumpApp(
        Align(
          alignment: Alignment.topCenter,
          child: GuErrorState(
            title: _title,
            description: _description,
            retryLabel: 'Yeniden dene',
            onRetry: () async {},
            inline: true,
          ),
        ),
      );
      expect(
        tester.widget<GuEmptyState>(find.byType(GuEmptyState)).layout,
        GuEmptyStateLayout.inline,
      );
      expect(
        tester.getRect(find.byType(GuIllustration)),
        const Rect.fromLTWH(147, GuSizes.emptyInlinePaddingY, 96, 96),
      );
      expect(find.byType(GuButton), findsOneWidget);
      expect(
        tester.getBottomLeft(find.byType(GuErrorState)).dy,
        tester.getBottomLeft(find.byType(GuButton)).dy +
            GuSizes.emptyInlinePaddingY,
      );
      handle.dispose();
    });

    testWidgets('T-06 · GuErrorState · 320 dp × metin ölçeği 1.6 → düğmeler '
        'alt alta sarar, taşma yok', (tester) async {
      final retryKey = GuKey.action('SYS-02.retry');
      final homeKey = GuKey.action('SYS-02.home');
      await tester.pumpApp(
        SingleChildScrollView(
          child: GuErrorState(
            title: _title,
            description: _description,
            retryLabel: 'Yeniden dene',
            onRetry: () async {},
            retryActionKey: retryKey,
            homeLabel: 'Ana sayfaya dön',
            onHome: () {},
            homeActionKey: homeKey,
          ),
        ),
        size: const Size(320, 640),
        textScale: 1.6,
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getTopLeft(find.byKey(homeKey)).dy,
        tester.getBottomLeft(find.byKey(retryKey)).dy + GuSpacing.s8,
      );
    });
  });
}
