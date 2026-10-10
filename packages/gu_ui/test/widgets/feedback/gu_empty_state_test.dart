// T-06 · GuEmptyState (widget-catalog #23; CD-27, CD-105; css:300–301;
// ui.js:100–103).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

Widget _host(Widget child) =>
    Align(alignment: Alignment.topCenter, child: child);

void main() {
  group('T-06 · GuEmptyState', () {
    testWidgets('T-06 · GuEmptyState · dolgu 32 / 24, illüstrasyon 140, '
        'aralık 12, titleS + bodyS (en çok 280); CTA / ikincil → callback; '
        'compact 20 / 16 + 96; başlıksız (CD-105)', (tester) async {
      final handle = tester.ensureSemantics();
      final text = GuTypography.resolve(GuColors.light);
      final ctaKey = GuKey.action('CLB-01.clearFilter');
      final secondaryKey = GuKey.action('CLB-01.search');
      const title = 'Aramana uygun kulüp bulamadık';
      const description =
          'Filtreleri gevşetmeyi ya da başka bir kategori seçmeyi dene.';
      var cta = 0;
      var secondary = 0;

      await tester.pumpApp(
        _host(
          GuEmptyState(
            illustration: GuIllustrations.emptyClubs,
            title: title,
            description: description,
            ctaLabel: 'Filtreleri temizle',
            onCta: () => cta++,
            ctaActionKey: ctaKey,
            secondaryLabel: 'Kulüp ara',
            onSecondary: () => secondary++,
            secondaryActionKey: secondaryKey,
          ),
        ),
      );
      final state = find.byType(GuEmptyState);
      expect(tester.getSize(state).width, 390);
      expect(tester.widget<GuEmptyState>(state).compact, isFalse);
      expect(
        tester.getRect(find.byType(GuIllustration)),
        const Rect.fromLTWH(
          (390 - GuSizes.illustration) / 2,
          GuSizes.emptyPaddingY,
          GuSizes.illustration,
          GuSizes.illustration,
        ),
      );
      expect(
        tester.widget<GuIllustration>(find.byType(GuIllustration)).illustration,
        GuIllustrations.emptyClubs,
      );
      final titleText = tester.widget<Text>(find.text(title));
      expect(titleText.style, text.titleS);
      expect(titleText.textAlign, TextAlign.center);
      expect(
        tester.getTopLeft(find.text(title)).dy,
        GuSizes.emptyPaddingY + GuSizes.illustration + GuSizes.emptyGap,
      );
      expect(
        tester.getSemantics(find.text(title)),
        matchesSemantics(label: title, isHeader: true),
      );
      final descText = tester.widget<Text>(find.text(description));
      expect(
        descText.style,
        text.bodyS.copyWith(color: GuColors.light.textSecondary),
      );
      expect(descText.textAlign, TextAlign.center);
      expect(
        tester.getSize(find.text(description)).width,
        lessThanOrEqualTo(GuSizes.emptyDescMaxWidth),
      );
      expect(
        tester.getTopLeft(find.text(description)).dy,
        tester.getBottomLeft(find.text(title)).dy + GuSizes.emptyGap,
      );

      final ctaButton = tester.widget<GuButton>(find.byKey(ctaKey));
      expect(ctaButton.variant, GuButtonVariant.primary);
      expect(ctaButton.label, 'Filtreleri temizle');
      expect(
        tester.widget<GuButton>(find.byKey(secondaryKey)).variant,
        GuButtonVariant.text,
      );
      expect(
        tester.getTopLeft(find.byKey(secondaryKey)).dy,
        tester.getBottomLeft(find.byKey(ctaKey)).dy + GuSizes.emptyGap,
      );
      expect(
        tester.getBottomLeft(state).dy,
        tester.getBottomLeft(find.byKey(secondaryKey)).dy +
            GuSizes.emptyPaddingY,
      );
      await tester.tap(find.byKey(ctaKey));
      await tester.tap(find.byKey(secondaryKey));
      expect((cta, secondary), (1, 1));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await tester.pumpAndSettle();

      // compact (EVT-01 gün listesi): 20 / 16, illüstrasyon 96, düğme yok.
      await tester.pumpApp(
        _host(
          const GuEmptyState(
            illustration: GuIllustrations.emptyEvents,
            title: 'Bu gün etkinlik yok',
            description: 'Başka bir gün seç.',
            compact: true,
          ),
        ),
      );
      expect(tester.widget<GuEmptyState>(state).compact, isTrue);
      expect(
        tester.getRect(find.byType(GuIllustration)),
        const Rect.fromLTWH(
          (390 - GuSizes.illustrationCompact) / 2,
          GuSizes.emptyCompactPaddingY,
          GuSizes.illustrationCompact,
          GuSizes.illustrationCompact,
        ),
      );
      expect(find.byType(GuButton), findsNothing);
      expect(
        tester.getBottomLeft(state).dy,
        tester.getBottomLeft(find.text('Başka bir gün seç.')).dy +
            GuSizes.emptyCompactPaddingY,
      );

      // Başlıksız (NoAccessView, CD-105) + serbest eylem alanı (ham `.empty`).
      await tester.pumpApp(
        _host(
          const GuEmptyState.body(
            illustration: GuIllustrations.locked,
            description: 'Bu sayfayı görme yetkin yok.',
            actions: Text('eylem'),
          ),
        ),
      );
      expect(find.byType(Text), findsNWidgets(2));
      expect(
        tester.getTopLeft(find.text('Bu sayfayı görme yetkin yok.')).dy,
        GuSizes.emptyPaddingY + GuSizes.illustration + GuSizes.emptyGap,
      );
      expect(find.text('eylem'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('T-06 · GuEmptyState · 320 dp × metin ölçeği 1.6 + uzun '
        'metinler → taşma yok', (tester) async {
      final ctaKey = GuKey.action('PRF-03.discover');
      await tester.pumpApp(
        SingleChildScrollView(
          child: GuEmptyState(
            illustration: GuIllustrations.emptyApplications,
            title: 'Henüz hiçbir kulübe başvuruda bulunmadın',
            description:
                'İlgi alanlarına uygun kulüpleri keşfet, başvurunu gönder ve '
                'sonucunu buradan takip et.',
            ctaLabel: 'İlgi alanlarıma uygun kulüpleri keşfetmeye başla',
            onCta: () {},
            ctaActionKey: ctaKey,
            secondaryLabel: 'Tüm kulüplerin listesine geri dön',
            onSecondary: () {},
          ),
        ),
        size: const Size(320, 640),
        textScale: 1.6,
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(ctaKey)).width,
        lessThanOrEqualTo(320 - 2 * GuSizes.emptyPaddingX),
      );
    });
  });
}
