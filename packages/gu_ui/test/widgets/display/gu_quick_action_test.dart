// T-04 · GuQuickAction (widget-catalog #33; CD-84, K-45; css:305–306, 340).
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

List<BoxDecoration> _boxes(WidgetTester tester) => tester
    .widgetList<DecoratedBox>(
      find.descendant(
        of: find.byType(GuQuickAction),
        matching: find.byType(DecoratedBox),
      ),
    )
    .map((box) => box.decoration as BoxDecoration)
    .toList();

double _scale(WidgetTester tester) => tester
    .widget<AnimatedScale>(
      find.descendant(
        of: find.byType(GuQuickAction),
        matching: find.byType(AnimatedScale),
      ),
    )
    .scale;

double _opacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find.descendant(
        of: find.byType(GuQuickAction),
        matching: find.byType(Opacity),
      ),
    )
    .opacity;

void main() {
  group('T-04 · GuQuickAction', () {
    testWidgets('T-04 · GuQuickAction · kart ve ikon kutusu token '
        'değerleriyle (açık + koyu); dokunma → callback, basılı ölçek .98, '
        'Semantics, dokunma hedefi', (tester) async {
      final handle = tester.ensureSemantics();
      final key = GuKey.action('MGT-01.quick.post');
      var taps = 0;
      for (final (mode, colors) in [
        (ThemeMode.light, GuColors.light),
        (ThemeMode.dark, GuColors.dark),
      ]) {
        await tester.pumpApp(
          Center(
            child: SizedBox(
              width: 110,
              child: GuQuickAction(
                key: key,
                icon: GuIcons.pencil,
                label: 'Gönderi yaz',
                onTap: () => taps++,
              ),
            ),
          ),
          theme: mode,
        );
        final [card, iconBox] = _boxes(tester);
        expect(card.color, colors.bgSurface, reason: '$mode');
        expect(card.borderRadius, GuRadius.borderMd);
        expect(card.border, Border.all(color: colors.borderSoft));
        expect(card.boxShadow, isNull);
        expect(iconBox.color, colors.brandPrimaryContainer);
        expect(iconBox.borderRadius, GuRadius.borderSm);
        final icon = tester.widget<GuIcon>(find.byType(GuIcon));
        expect(icon.icon, GuIcons.pencil);
        expect(icon.size, GuSizes.quickIcon);
        expect(icon.color, colors.brandPrimaryText);
        expect(
          tester.widget<Text>(find.text('Gönderi yaz')).style,
          GuTypography.resolve(colors).quick,
        );
      }
      // Genişlik ebeveynden; yükseklik 1 + 14 + 40 + 8 + etiket + 14 + 1.
      final size = tester.getSize(find.byKey(key));
      final label = tester.getSize(find.text('Gönderi yaz'));
      expect(size.width, 110);
      expect(size.height, moreOrLessEquals(78 + label.height, epsilon: 0.01));
      expect(
        tester.getSize(find.byType(GuIcon)),
        const Size.square(GuSizes.quickIcon),
      );
      // İkon kutusu 40 px, yatayda ortalı, üstten 15.
      final iconCenter = tester.getCenter(find.byType(GuIcon));
      final topLeft = tester.getTopLeft(find.byKey(key));
      expect(iconCenter.dx - topLeft.dx, 55);
      expect(iconCenter.dy - topLeft.dy, 15 + 20);

      await tester.tap(find.byKey(key));
      expect(taps, 1);
      expect(
        tester.getSemantics(find.byKey(key)),
        matchesSemantics(
          label: 'Gönderi yaz',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));

      expect(_scale(tester), 1);
      expect(_opacity(tester), 1);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(key)),
      );
      await tester.pump(kPressTimeout);
      expect(_scale(tester), GuMotion.pressScale);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_scale(tester), 1);
      expect(taps, 2);
      handle.dispose();
    });

    testWidgets('T-04 · GuQuickAction · disabled: opaklık .5, onTap '
        'çağrılmaz, onDisabledPressed çağrılır, basılı ölçek yok, Semantics '
        'devre dışı', (tester) async {
      final handle = tester.ensureSemantics();
      final key = GuKey.action('MGT-01.quick.event');
      var taps = 0;
      var blocked = 0;
      Widget action({VoidCallback? onDisabledPressed}) => Center(
        child: GuQuickAction(
          key: key,
          icon: GuIcons.calendarPlus,
          label: 'Etkinlik oluştur',
          onTap: () => taps++,
          disabled: true,
          onDisabledPressed: onDisabledPressed,
        ),
      );

      await tester.pumpApp(action(onDisabledPressed: () => blocked++));
      expect(_opacity(tester), GuOpacity.disabled);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(key)),
      );
      await tester.pump(kPressTimeout);
      expect(_scale(tester), 1);
      await gesture.up();
      await tester.pump();
      expect(taps, 0);
      expect(blocked, 1);
      expect(
        tester.getSemantics(find.byKey(key)),
        matchesSemantics(
          label: 'Etkinlik oluştur',
          isButton: true,
          hasEnabledState: true,
        ),
      );

      // onDisabledPressed yok: dokunma sessizce yutulur.
      await tester.pumpApp(action());
      await tester.tap(find.byKey(key));
      expect(taps, 0);
      expect(blocked, 1);
      handle.dispose();
    });

    testWidgets('T-04 · GuQuickAction · 320 dp üç sütun × metin ölçeği 1.6 + '
        'uzun etiket → taşma yok (etiket sarar, ortalı)', (tester) async {
      await tester.pumpApp(
        SingleChildScrollView(
          child: Padding(
            padding: GuInsets.h16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: GuSpacing.s12,
              children: [
                for (final label in [
                  'Etkinlik oluştur ve duyur',
                  'Yoklama al',
                  'Kulüp ayarlarını düzenle',
                ])
                  Expanded(
                    child: GuQuickAction(
                      icon: GuIcons.settings,
                      label: label,
                      onTap: () {},
                    ),
                  ),
              ],
            ),
          ),
        ),
        size: const Size(320, 640),
        textScale: 1.6,
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.widget<Text>(find.text('Yoklama al')).textAlign,
        TextAlign.center,
      );
      // (320 − 32 − 24) / 3 = 88.
      for (final element in find.byType(GuQuickAction).evaluate()) {
        expect(element.size!.width, 88);
      }
    });
  });
}
