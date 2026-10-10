// T-04 · GuKpi (widget-catalog #32; G3, G14, CD-112; css:302–304, 340).
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

TextStyle _style(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!;

void main() {
  group('T-04 · GuKpi', () {
    testWidgets('T-04 · GuKpi · standard: caption etiket + 16 px ikon, '
        'kpiValue (accent → brand.primaryText), bodyS alt metin, dolgu 14/16; '
        'dokunma → callback, basılı ölçek .98, Semantics, dokunma hedefi', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final key = GuKey.action('MGT-01.kpi.members');
      var taps = 0;
      Widget kpi({bool accent = false}) => Center(
        child: SizedBox(
          width: 171,
          child: GuKpi(
            key: key,
            label: 'Toplam üye',
            value: '231',
            subtitle: '+12 bu ay',
            icon: GuIcons.users,
            accent: accent,
            onTap: () => taps++,
          ),
        ),
      );

      for (final (mode, colors) in [
        (ThemeMode.light, GuColors.light),
        (ThemeMode.dark, GuColors.dark),
      ]) {
        final text = GuTypography.resolve(colors);
        await tester.pumpApp(kpi(), theme: mode);
        expect(_style(tester, 'Toplam üye'), text.caption, reason: '$mode');
        expect(_style(tester, '231'), text.kpiValue);
        expect(
          _style(tester, '+12 bu ay'),
          text.bodyS.copyWith(color: colors.textSecondary),
        );
        final icon = tester.widget<GuIcon>(find.byType(GuIcon));
        expect(icon.icon, GuIcons.users);
        expect(icon.size, GuSizes.kpiIcon);
        expect(icon.color, colors.textMuted);

        await tester.pumpApp(kpi(accent: true), theme: mode);
        expect(
          _style(tester, '231'),
          text.kpiValue.copyWith(color: colors.brandPrimaryText),
        );
      }

      await tester.pumpApp(kpi());
      // Gövde GuCard: dolgu 14/16 (+ 1 px kenarlık), basılı ölçek .98.
      final card = tester.widget<GuCard>(find.byType(GuCard));
      expect(
        card.padding,
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
      expect(card.pressScale, GuMotion.pressScale);
      final origin = tester.getTopLeft(find.byKey(key));
      expect(
        tester.getTopLeft(find.text('Toplam üye')) - origin,
        const Offset(17, 15),
      );
      expect(tester.getTopRight(find.byType(GuIcon)).dx - origin.dx, 171 - 17);
      // Satırlar arası 6.
      expect(
        tester.getTopLeft(find.text('+12 bu ay')).dy -
            tester.getBottomLeft(find.text('231')).dy,
        moreOrLessEquals(GuSizes.kpiGap, epsilon: 0.01),
      );

      await tester.tap(find.byKey(key));
      expect(taps, 1);
      expect(
        tester.getSemantics(find.byKey(key)),
        matchesSemantics(
          label: 'Toplam üye\n231\n+12 bu ay',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(key)),
      );
      await tester.pump(kPressTimeout);
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        GuMotion.pressScale,
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, 2);
      handle.dispose();
    });

    testWidgets('T-04 · GuKpi · compact (PRF-01): önce değer sonra etiket, '
        'dolgu 12, ikon / alt metin yok; semanticLabel', (tester) async {
      final handle = tester.ensureSemantics();
      final key = GuKey.action('PRF-01.stat.events');
      await tester.pumpApp(
        Center(
          child: SizedBox(
            width: 110,
            child: GuKpi(
              key: key,
              label: 'Katıldığım etkinlik',
              value: '1',
              subtitle: 'yok sayılır',
              icon: GuIcons.calendar,
              layout: GuKpiLayout.compact,
              semanticLabel: 'Katıldığım etkinlik: 1',
              onTap: () {},
            ),
          ),
        ),
      );
      expect(
        tester.widget<GuCard>(find.byType(GuCard)).padding,
        GuInsets.all12,
      );
      expect(find.byType(GuIcon), findsNothing);
      expect(find.text('yok sayılır'), findsNothing);
      final origin = tester.getTopLeft(find.byKey(key));
      expect(tester.getTopLeft(find.text('1')) - origin, const Offset(13, 13));
      expect(
        tester.getTopLeft(find.text('Katıldığım etkinlik')).dy -
            tester.getBottomLeft(find.text('1')).dy,
        moreOrLessEquals(GuSizes.kpiGap, epsilon: 0.01),
      );
      expect(
        tester.getSemantics(find.byKey(key)),
        isSemantics(label: 'Katıldığım etkinlik: 1', isButton: true),
      );
      handle.dispose();
    });

    testWidgets('T-04 · GuKpi · 320 dp iki / üç sütun × metin ölçeği 1.6 + '
        'uzun metin → taşma yok; aynı satırdaki kartlar eşit boy', (
      tester,
    ) async {
      Widget grid(List<Widget> cards) => IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: GuSpacing.s12,
          children: [for (final card in cards) Expanded(child: card)],
        ),
      );
      await tester.pumpApp(
        SingleChildScrollView(
          padding: GuInsets.all16,
          child: Column(
            spacing: GuSpacing.s12,
            children: [
              grid([
                GuKpi(
                  label: 'Bu ay yayımlanan duyuru sayısı',
                  value: '1.234.567',
                  subtitle: 'Geçen aya göre +12 yeni duyuru',
                  icon: GuIcons.megaphone,
                  onTap: () {},
                ),
                GuKpi(
                  label: 'Bekleyen başvuru',
                  value: '9',
                  accent: true,
                  icon: GuIcons.userPlus,
                  onTap: () {},
                ),
              ]),
              grid([
                for (final label in [
                  'Kulüp',
                  'Katıldığım etkinlik',
                  'Bekleyen başvuru',
                ])
                  GuKpi(
                    label: label,
                    value: '12',
                    layout: GuKpiLayout.compact,
                    onTap: () {},
                  ),
              ]),
            ],
          ),
        ),
        size: const Size(320, 640),
        textScale: 1.6,
      );
      expect(tester.takeException(), isNull);
      final sizes = [
        for (final element in find.byType(GuKpi).evaluate()) element.size!,
      ];
      expect(sizes[0].width, 138);
      expect(sizes[0].height, sizes[1].height);
      expect(sizes[2].width, 88);
      expect(sizes[2].height, sizes[4].height);
    });
  });
}
