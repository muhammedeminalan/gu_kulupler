// T-04 · GuButton (widget-catalog #1; A.2 #1; K-03, K-19, K-53, CD-111).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

final Finder _button = find.byType(GuButton);

BoxDecoration _decoration(WidgetTester tester) =>
    tester
            .widget<AnimatedContainer>(
              find.descendant(
                of: _button,
                matching: find.byType(AnimatedContainer),
              ),
            )
            .decoration!
        as BoxDecoration;

Color? _labelColor(WidgetTester tester) => tester
    .widget<Text>(find.descendant(of: _button, matching: find.byType(Text)))
    .style!
    .color;

double _scale(WidgetTester tester) => tester
    .widget<AnimatedScale>(
      find.descendant(of: _button, matching: find.byType(AnimatedScale)),
    )
    .scale;

/// CSS `filter:brightness(1 − amount)`.
Color _darken(Color c, double amount) => c.withValues(
  red: c.r * (1 - amount),
  green: c.g * (1 - amount),
  blue: c.b * (1 - amount),
);

void main() {
  group('T-04 · GuButton', () {
    testWidgets('T-04 · GuButton · 7 varyant × 3 boyut token değerleriyle; '
        'basılı renk + ölçek .98; dokunma → onPressed', (tester) async {
      const c = GuColors.light;
      final text = GuTypography.resolve(c);
      var taps = 0;

      // Boyutlar: yükseklik 40 / 48 / 56, dolgu 14 / 20 / 24, yazı 13 / 14 / 16.
      for (final (size, height, paddingX, style) in [
        (GuButtonSize.sm, 40.0, 14.0, text.buttonSm),
        (GuButtonSize.md, 48.0, 20.0, text.button),
        (GuButtonSize.lg, 56.0, 24.0, text.buttonLg),
      ]) {
        await tester.pumpApp(
          Center(
            child: GuButton(label: 'Katıl', size: size, onPressed: () {}),
          ),
        );
        final label = tester.widget<Text>(find.text('Katıl'));
        expect(label.style, style.copyWith(color: c.brandOnPrimary));
        final box = tester.getSize(_button);
        expect(box.height, height, reason: '$size');
        expect(
          box.width,
          closeTo(tester.getSize(find.text('Katıl')).width + 2 * paddingX, .01),
          reason: '$size',
        );
        expect(_decoration(tester).borderRadius, GuRadius.borderSm);
      }

      // Varyantlar: (zemin, basılı zemin, ön plan, basılı ön plan, kenarlık).
      final cases =
          <(GuButtonVariant, Color?, Color?, Color, Color, Color?, double)>[
            (
              GuButtonVariant.primary,
              c.brandPrimary,
              c.brandPrimaryPressed,
              c.brandOnPrimary,
              c.brandOnPrimary,
              null,
              48,
            ),
            (
              GuButtonVariant.tonal,
              c.brandPrimaryContainer,
              _darken(c.brandPrimaryContainer, GuOpacity.tonalPressedDarken),
              c.brandOnPrimaryContainer,
              _darken(c.brandOnPrimaryContainer, GuOpacity.tonalPressedDarken),
              null,
              48,
            ),
            (
              GuButtonVariant.outline,
              c.bgSurface,
              c.bgSurfaceMuted,
              c.textHeading,
              c.textHeading,
              c.borderDefault,
              48,
            ),
            (
              GuButtonVariant.text,
              null,
              c.brandPrimaryContainer,
              c.brandPrimaryText,
              c.brandPrimaryText,
              null,
              44,
            ),
            (
              GuButtonVariant.dangerOutline,
              null,
              c.stateDangerContainer,
              c.stateDanger,
              c.stateDanger,
              c.stateDanger,
              48,
            ),
            (
              GuButtonVariant.danger,
              c.stateDanger,
              _darken(c.stateDanger, GuOpacity.dangerPressedDarken),
              c.brandOnPrimary,
              _darken(c.brandOnPrimary, GuOpacity.dangerPressedDarken),
              null,
              48,
            ),
            (
              GuButtonVariant.ghost,
              null,
              c.bgSurfaceMuted,
              c.textHeading,
              c.textHeading,
              null,
              48,
            ),
          ];
      for (final (variant, bg, pressedBg, fg, pressedFg, border, height)
          in cases) {
        await tester.pumpApp(
          Center(
            child: GuButton(
              key: GuKey.action('CLB-03.join'),
              label: 'Katıl',
              variant: variant,
              onPressed: () => taps++,
            ),
          ),
        );
        final finder = find.byKey(GuKey.action('CLB-03.join'));
        expect(tester.getSize(finder).height, height, reason: '$variant');
        var decoration = _decoration(tester);
        expect(decoration.color, bg, reason: '$variant');
        expect(_labelColor(tester), fg, reason: '$variant');
        expect(
          decoration.border,
          border == null ? isNull : Border.all(color: border),
          reason: '$variant',
        );
        expect(_scale(tester), 1);

        final before = taps;
        final gesture = await tester.startGesture(tester.getCenter(finder));
        await tester.pump();
        decoration = _decoration(tester);
        expect(decoration.color, pressedBg, reason: '$variant basılı');
        expect(_labelColor(tester), pressedFg, reason: '$variant basılı');
        expect(_scale(tester), GuMotion.pressScale);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(taps, before + 1);
        expect(_scale(tester), 1);
        expect(_decoration(tester).color, bg);
      }

      // text / ghost: boyut ne olursa olsun dolgu 12; text yüksekliği 44.
      await tester.pumpApp(
        Center(
          child: GuButton(
            label: 'Katıl',
            variant: GuButtonVariant.text,
            size: GuButtonSize.lg,
            onPressed: () {},
          ),
        ),
      );
      expect(
        tester.getSize(_button),
        Size(tester.getSize(find.text('Katıl')).width + 2 * 12, 44),
      );
    });

    testWidgets('T-04 · GuButton · ikon / iconOnly; disabled → '
        'onDisabledPressed; loading → çağrılmaz + spinner; Semantics; dokunma '
        'hedefi; klavye odağı', (tester) async {
      final handle = tester.ensureSemantics();
      const c = GuColors.light;
      var taps = 0;
      var disabledTaps = 0;
      Widget row(List<Widget> children) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: GuSpacing.s24,
          children: children,
        ),
      );

      // İkonlu: baştaki 20 (sm 18), sondaki 18, aralık 8; iconOnly 20+20+20.
      await tester.pumpApp(
        row([
          GuButton(
            label: 'Seçenek ekle',
            icon: GuIcons.plus,
            iconTrailing: GuIcons.arrowRight,
            onPressed: () => taps++,
          ),
          GuButton(
            label: 'Beğen',
            semanticLabel: 'Beğen',
            icon: GuIcons.heart,
            iconOnly: true,
            size: GuButtonSize.sm,
            onPressed: () => taps++,
          ),
        ]),
      );
      final icons = tester.widgetList<GuIcon>(find.byType(GuIcon)).toList();
      expect(icons.map((i) => i.size), [20, 18, 18]);
      expect(icons.map((i) => i.color).toSet(), {c.brandOnPrimary});
      expect(
        tester.getSize(_button.first).width,
        closeTo(
          2 * 20 +
              20 +
              8 +
              tester.getSize(find.text('Seçenek ekle')).width +
              8 +
              18,
          .01,
        ),
      );
      expect(tester.getSize(_button.last), const Size(14 + 18 + 14, 40));
      expect(find.text('Beğen'), findsNothing);
      // 40 px yüksek düğme dahil etkin alan ≥ 48 dp.
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      expect(
        tester.getSemantics(_button.last),
        isSemantics(
          label: 'Beğen',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          isFocusable: true,
        ),
      );
      await tester.tap(_button.last);
      expect(taps, 1);

      // disabled: opaklık .5, onPressed yok, onDisabledPressed var; basılı
      // geri bildirimi yok. onPressed null → aynı görünüm.
      await tester.pumpApp(
        row([
          GuButton(
            label: 'Kaydet',
            disabled: true,
            onPressed: () => taps++,
            onDisabledPressed: () => disabledTaps++,
          ),
          const GuButton(label: 'Devam', onPressed: null),
        ]),
      );
      for (final opacity in tester.widgetList<Opacity>(find.byType(Opacity))) {
        expect(opacity.opacity, GuOpacity.disabled);
      }
      final gesture = await tester.startGesture(
        tester.getCenter(_button.first),
      );
      await tester.pump();
      expect(
        tester
            .widgetList<AnimatedScale>(find.byType(AnimatedScale))
            .first
            .scale,
        1,
      );
      await gesture.up();
      await tester.tap(_button.last);
      expect((taps, disabledTaps), (1, 1));
      expect(
        tester.getSemantics(_button.first),
        isSemantics(
          label: 'Kaydet',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          hasTapAction: false,
        ),
      );

      // loading: içerik yer tutar ama çizilmez, ortada ön plan renginde
      // spinner; dokunma yok sayılır.
      await tester.pumpApp(
        Center(
          child: GuButton(label: 'Gönder', onPressed: () => taps++),
        ),
      );
      final idle = tester.getSize(_button);
      await tester.pumpApp(
        Center(
          child: GuButton(
            label: 'Gönder',
            loading: true,
            onPressed: () => taps++,
            onDisabledPressed: () => disabledTaps++,
          ),
        ),
      );
      expect(tester.getSize(_button), idle);
      expect(
        tester.widget<Visibility>(find.byType(Visibility)).visible,
        isFalse,
      );
      final spinner = tester.widget<GuSpinner>(find.byType(GuSpinner));
      expect(spinner.color, c.brandOnPrimary);
      expect(
        tester.getCenter(find.byType(GuSpinner)),
        tester.getCenter(_button),
      );
      await tester.tap(_button);
      expect((taps, disabledTaps), (1, 1));
      expect(
        tester.getSemantics(_button),
        isSemantics(label: 'Gönder', isButton: true, isEnabled: false),
      );

      // Klavye odağı (K-19): 2 px focus.ring halkası 2 px dışarıda; Enter →
      // onPressed. Halka odaktayken yeniden boyanır.
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      await tester.pumpApp(
        Center(
          child: GuButton(
            label: 'Katıl',
            autofocus: true,
            onPressed: () => taps++,
          ),
        ),
      );
      await tester.pump();
      final ring = find.descendant(
        of: _button,
        matching: find.byWidgetPredicate(
          (w) => w is CustomPaint && w.foregroundPainter != null,
        ),
      );
      expect(ring, findsOneWidget);
      final size = tester.getSize(_button);
      expect(
        tester.renderObject(ring),
        paints
          ..rrect(color: c.brandPrimary)
          ..paragraph()
          ..rrect(
            rrect: GuRadius.borderSm.toRRect(Offset.zero & size).inflate(3),
            color: c.focusRing,
            strokeWidth: 2,
            style: PaintingStyle.stroke,
          ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(taps, 2);
      await tester.tap(_button);
      await tester.pumpAndSettle();
      expect(taps, 3);
      expect(ring, findsOneWidget);
      handle.dispose();
    });

    testWidgets('T-04 · GuButton · 320 dp × 1.6 uzun metin taşmaz; full satırı '
        'doldurur', (tester) async {
      final long = 'Başvuruyu gönder ' * 8;
      await tester.pumpApp(
        Padding(
          padding: GuInsets.all16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: GuSpacing.s8,
            children: [
              GuButton(
                label: long,
                icon: GuIcons.plus,
                iconTrailing: GuIcons.arrowRight,
                size: GuButtonSize.lg,
                onPressed: () {},
              ),
              GuButton(
                label: long,
                variant: GuButtonVariant.text,
                loading: true,
                onPressed: () {},
              ),
              GuButton(label: 'Kısa', full: true, onPressed: () {}),
              Row(
                spacing: GuSpacing.s8,
                children: [
                  Expanded(
                    child: GuButton(
                      label: long,
                      variant: GuButtonVariant.outline,
                      onPressed: () {},
                    ),
                  ),
                  Expanded(
                    child: GuButton(label: 'Tamam', onPressed: () {}),
                  ),
                ],
              ),
            ],
          ),
        ),
        size: const Size(320, 640),
        textScale: 1.6,
      );
      expect(tester.takeException(), isNull);
      final widths = tester
          .widgetList<GuButton>(_button)
          .indexed
          .map((e) => tester.getSize(_button.at(e.$1)).width)
          .toList();
      expect(widths, [288, 288, 288, 140, 140]);
      // Metin ölçeklenir (K-57 kapsamında değil): 56 px alt sınır korunur.
      expect(tester.getSize(_button.first).height, greaterThanOrEqualTo(56));
      final label = tester.widget<Text>(
        find.descendant(of: _button.first, matching: find.byType(Text)),
      );
      expect((label.maxLines, label.overflow), (1, TextOverflow.ellipsis));
    });
  });
}
