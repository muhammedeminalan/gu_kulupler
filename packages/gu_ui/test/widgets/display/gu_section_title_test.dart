// T-04 · GuSectionTitle (widget-catalog #27; K-35; css:108–109).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

Widget _host(Widget child) =>
    Column(mainAxisSize: MainAxisSize.min, children: [child]);

void main() {
  group('T-04 · GuSectionTitle', () {
    testWidgets('T-04 · GuSectionTitle · titleM + caption, yatay dolgu 16, '
        'üst boşluk 24 / 8 / 0, alt 12; eylem bağlantısı → callback, '
        'Semantics, dokunma hedefi', (tester) async {
      final handle = tester.ensureSemantics();
      final text = GuTypography.resolve(GuColors.light);
      final actionKey = GuKey.action('CLB-02.clearRecent');
      var taps = 0;

      // Eylemsiz: yükseklik = üst boşluk + titleM satırı (24) + alt 12.
      for (final (margin, top) in [
        (GuSectionTitleMargin.normal, GuSizes.sectionTitleMarginTop),
        (GuSectionTitleMargin.first, GuSizes.sectionTitleFirstMarginTop),
        (GuSectionTitleMargin.none, 0.0),
      ]) {
        await tester.pumpApp(
          _host(GuSectionTitle(title: 'Popüler aramalar', topMargin: margin)),
        );
        expect(margin.top, top);
        expect(
          tester.getSize(find.byType(GuSectionTitle)),
          Size(390, top + 24 + GuSizes.sectionTitleMarginBottom),
          reason: '$margin',
        );
        expect(
          tester.getTopLeft(find.text('Popüler aramalar')),
          Offset(16, top),
        );
      }
      expect(find.byType(GuButton), findsNothing);
      expect(
        tester.widget<Text>(find.text('Popüler aramalar')).style,
        text.titleM,
      );
      expect(
        tester.getSemantics(find.text('Popüler aramalar')),
        matchesSemantics(label: 'Popüler aramalar', isHeader: true),
      );

      await tester.pumpApp(
        _host(
          GuSectionTitle(
            title: 'Son aramalar',
            subtitle: 'Bu cihazda',
            actionLabel: 'Temizle',
            onAction: () => taps++,
            actionKey: actionKey,
          ),
        ),
      );
      expect(tester.widget<Text>(find.text('Bu cihazda')).style, text.caption);
      final button = tester.widget<GuButton>(find.byKey(actionKey));
      expect(button.variant, GuButtonVariant.text);
      expect(button.size, GuButtonSize.sm);
      expect(button.label, 'Temizle');
      // Eylem sağ kenardan 16 px içeride, satırla dikey ortalı.
      expect(tester.getTopRight(find.byKey(actionKey)).dx, 390 - 16);
      expect(
        tester.getCenter(find.byKey(actionKey)).dy,
        moreOrLessEquals(
          tester.getCenter(find.byType(Column).last).dy,
          epsilon: 0.01,
        ),
      );
      await tester.tap(find.byKey(actionKey));
      expect(taps, 1);
      expect(
        tester.getSemantics(find.byKey(actionKey)),
        isSemantics(
          label: 'Temizle',
          isButton: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await tester.pumpAndSettle();
      handle.dispose();
    });

    testWidgets('T-04 · GuSectionTitle · 320 dp × metin ölçeği 1.6 + uzun '
        'başlık ve eylem → taşma yok (eylem en çok yarı genişlik)', (
      tester,
    ) async {
      final actionKey = GuKey.action('CLB-02.clearRecent');
      await tester.pumpApp(
        _host(
          GuSectionTitle(
            title: 'Sizin için önerilen kulüpler ve yaklaşan etkinlikler',
            subtitle: 'İlgi alanlarına göre seçilmiş topluluk önerileri',
            actionLabel: 'Tüm arama geçmişini temizle',
            onAction: () {},
            actionKey: actionKey,
          ),
        ),
        size: const Size(320, 640),
        textScale: 1.6,
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(actionKey)).width,
        lessThanOrEqualTo((320 - 32) / 2),
      );
      expect(tester.getTopRight(find.byKey(actionKey)).dx, 320 - 16);
    });
  });
}
