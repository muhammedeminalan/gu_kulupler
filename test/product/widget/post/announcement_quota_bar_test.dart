// AnnouncementQuotaBar (widget-catalog P23; Q-10, CD-109) — düz görünüm
// (FED-03: etiket + "{used}/{limit}" + çubuk) ve kart görünümü (MGT-01: kalan
// hak metni); hak dolunca uyarı rengi.
// Referans: design/prototype/app/screens-clubs.js:208, screens-manage.js:27.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/product/widget/post/announcement_quota_bar.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';

void main() {
  group('AnnouncementQuotaBar', () {
    testWidgets('düz: etiket, tabular sayaç, çubuk (kalan → brand, dolu → '
        'warning); kart ve kalan metni yok', (tester) async {
      await tester.pumpApp(const AnnouncementQuotaBar(used: 1, limit: 2));
      final l10n = tester.l10n;
      expect(find.text(l10n.composeDailyQuota), findsOneWidget);
      expect(find.text('1/2'), findsOneWidget);
      var progress = tester.widget<GuProgress>(find.byType(GuProgress));
      expect((progress.value, progress.max), (1, 2));
      expect(progress.kind, GuProgressKind.brand);
      expect(progress.semanticLabel, l10n.composeDailyQuota);
      expect(find.byType(GuCard), findsNothing);
      expect(find.text(l10n.mgtQuotaLeft(1)), findsNothing);

      await tester.pumpApp(const AnnouncementQuotaBar(used: 3, limit: 2));
      expect(find.text('3/2'), findsOneWidget);
      progress = tester.widget<GuProgress>(find.byType(GuProgress));
      expect(progress.value, 2);
      expect(progress.kind, GuProgressKind.warning);
    });

    testWidgets('kart (MGT-01): kalan hak metni; dolunca "Bugünkü duyuru '
        'hakkın doldu." — TR + EN, dar ekran + büyük metin taşmaz', (
      tester,
    ) async {
      for (final locale in const [Locale('tr'), Locale('en')]) {
        await tester.pumpApp(
          const AnnouncementQuotaBar(used: 0, limit: 2, card: true),
          locale: locale,
          size: const Size(320, 568),
          textScale: 1.6,
        );
        final l10n = tester.l10n;
        expect(find.byType(GuCard), findsOneWidget);
        expect(find.text(l10n.mgtQuotaLeft(2)), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.pumpApp(
          const AnnouncementQuotaBar(used: 2, limit: 2, card: true),
          locale: locale,
        );
        expect(find.text(l10n.composeLimitReached), findsOneWidget);
        expect(find.text(l10n.mgtQuotaLeft(0)), findsNothing);
      }
    });
  });
}
