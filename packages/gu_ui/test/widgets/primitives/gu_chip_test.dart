// T-04 · GuChip (widget-catalog #10; A.2 #10; K-03, K-53, CD-81, CD-111).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

BoxDecoration _decoration(WidgetTester tester, Finder chip) =>
    tester
            .widget<AnimatedContainer>(
              find.descendant(
                of: chip,
                matching: find.byType(AnimatedContainer),
              ),
            )
            .decoration!
        as BoxDecoration;

Color? _labelColor(WidgetTester tester, Finder chip) => tester
    .widget<Text>(
      find.descendant(of: chip, matching: find.byType(Text)).first,
    )
    .style!
    .color;

Color? _iconColor(WidgetTester tester, Finder chip) => tester
    .widget<GuIcon>(
      find.descendant(of: chip, matching: find.byType(GuIcon)).first,
    )
    .color;

const Key _plain = ValueKey<String>('plain');
const Key _selected = ValueKey<String>('selected');
const Key _input = ValueKey<String>('input');
const Key _disabled = ValueKey<String>('disabled');

Widget _set() => Center(
  child: Column(
    mainAxisSize: MainAxisSize.min,
    spacing: GuSpacing.s16,
    children: [
      GuChip(
        key: _plain,
        label: 'Teknoloji',
        icon: GuIcons.cpu,
        count: 2,
        onTap: () {},
      ),
      GuChip(
        key: _selected,
        label: 'Tümü',
        icon: GuIcons.check,
        count: 3,
        selected: true,
        onTap: () {},
      ),
      GuChip(
        key: _input,
        label: 'hackathon',
        input: true,
        removable: true,
        removeSemanticLabel: 'Kaldır',
        onRemove: () {},
      ),
      GuChip(
        key: _disabled,
        label: 'Başvurular kapalı',
        disabled: true,
        count: 0,
        onTap: () {},
      ),
    ],
  ),
);

void main() {
  group('T-04 · GuChip', () {
    testWidgets('T-04 · GuChip · varsayılan / seçili / input / disabled açık + '
        'koyu token değerleriyle; basılı zemin', (tester) async {
      // ── açık tema (css:176, 178, 181, 184, 185) ──
      var c = GuColors.light;
      await tester.pumpApp(_set());
      final plain = find.byKey(_plain);
      final selected = find.byKey(_selected);
      final input = find.byKey(_input);
      final disabled = find.byKey(_disabled);

      // Ölçü: en az 38, dolgu 14, aralık 6, ikon 16, sayaç 18.
      final labelWidth = tester.getSize(find.text('Teknoloji')).width;
      expect(
        tester.getSize(plain),
        Size(1 + 14 + 16 + 6 + labelWidth + 6 + 18 + 14 + 1, 38),
      );
      var decoration = _decoration(tester, plain);
      expect(decoration.color, c.bgSurface);
      expect(decoration.borderRadius, GuRadius.borderChip);
      expect(
        decoration.border,
        Border.all(color: GuComponentColors.light.chipBorder),
      );
      expect(
        tester.widget<Text>(find.text('Teknoloji')).style,
        GuTypography.resolve(c).chip.copyWith(color: c.textPrimary),
      );
      expect(_iconColor(tester, plain), c.textMuted);
      var badges = tester
          .widgetList<GuCountBadge>(find.byType(GuCountBadge))
          .toList();
      // count 0 → rozet yok.
      expect(badges.map((b) => (b.label, b.size, b.tone)), [
        ('2', GuCountBadgeSize.sm, GuCountBadgeTone.brand),
        ('3', GuCountBadgeSize.sm, GuCountBadgeTone.brand),
      ]);

      decoration = _decoration(tester, selected);
      expect(decoration.color, c.brandPrimaryContainer);
      expect(decoration.border, Border.all(color: c.brandPrimary));
      expect(_labelColor(tester, selected), c.brandOnPrimaryContainer);
      expect(_iconColor(tester, selected), c.brandPrimaryText);

      // input: bg.surfaceMuted, kenarlık zeminle aynı; kaldır ikonu 14,
      // sağ dolgu 14 − 4.
      decoration = _decoration(tester, input);
      expect(decoration.color, c.bgSurfaceMuted);
      expect(decoration.border, Border.all(color: c.bgSurfaceMuted));
      final remove = tester.widget<GuIcon>(
        find.descendant(of: input, matching: find.byType(GuIcon)),
      );
      expect(
        (remove.icon, remove.size, remove.color),
        (
          GuIcons.x,
          14,
          c.textMuted,
        ),
      );
      expect(
        tester.getSize(input).width,
        1 + 14 + tester.getSize(find.text('hackathon')).width + 6 + 14 + 10 + 1,
      );

      expect(
        tester
            .widget<Opacity>(
              find.descendant(of: disabled, matching: find.byType(Opacity)),
            )
            .opacity,
        GuOpacity.disabled,
      );

      // Basılı (K-53): varsayılan → bg.surfaceMuted; seçili değişmez.
      for (final (chip, pressed) in [
        (plain, c.bgSurfaceMuted),
        (selected, c.brandPrimaryContainer),
      ]) {
        final gesture = await tester.startGesture(tester.getCenter(chip));
        await tester.pump();
        expect(_decoration(tester, chip).color, pressed);
        await gesture.up();
        await tester.pumpAndSettle();
      }
      expect(_decoration(tester, plain).color, c.bgSurface);

      // ── koyu tema (css:177, 182, 183) ──
      c = GuColors.dark;
      await tester.pumpApp(_set(), theme: ThemeMode.dark);
      decoration = _decoration(tester, plain);
      expect(decoration.color, c.bgSurfaceMuted);
      expect(
        decoration.border,
        Border.all(color: GuComponentColors.dark.chipBorder),
      );
      decoration = _decoration(tester, selected);
      expect(decoration.color, c.brandPrimary);
      expect(decoration.border, Border.all(color: c.brandPrimary));
      expect(_labelColor(tester, selected), c.brandOnPrimary);
      expect(_iconColor(tester, selected), c.brandOnPrimary);
      // Koyu temada input kenarlığı korunur (css:177 baskın).
      expect(
        _decoration(tester, input).border,
        Border.all(color: GuComponentColors.dark.chipBorder),
      );
      badges = tester
          .widgetList<GuCountBadge>(find.byType(GuCountBadge))
          .toList();
      expect(badges.map((b) => b.tone), [
        GuCountBadgeTone.brand,
        GuCountBadgeTone.inverted,
      ]);
    });

    testWidgets('T-04 · GuChip · dokunma → onTap; disabled → çağrılmaz; kaldır '
        '→ yalnızca onRemove; Semantics(selected); dokunma hedefi', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final log = <String>[];
      final chipKey = GuKey.action('CLB-01.category.tech');
      final removeKey = GuKey.action('CLB-01.category.tech.remove');
      await tester.pumpApp(
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: GuSpacing.s24,
            children: [
              GuChip(
                key: chipKey,
                label: 'Teknoloji',
                selected: true,
                removable: true,
                removeKey: removeKey,
                removeSemanticLabel: 'Kaldır',
                onTap: () => log.add('tap'),
                onRemove: () => log.add('remove'),
              ),
              GuChip(
                key: _disabled,
                label: 'Kapalı',
                disabled: true,
                removable: true,
                removeSemanticLabel: 'Kaldır',
                onTap: () => log.add('disabled'),
                onRemove: () => log.add('disabled.remove'),
              ),
              const GuChip(key: _plain, label: 'Doğa'),
            ],
          ),
        ),
      );
      final chip = find.byKey(chipKey);
      expect(tester.getSize(chip).height, 38);
      // 38 px çip ve 14 px kaldır ikonu dahil etkin alan ≥ 48 dp.
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));

      await tester.tapAt(tester.getTopLeft(chip) + const Offset(10, 19));
      // Görünmez dolgu: çipin 4 px altı da etkin (css:179 `inset:-6px`).
      await tester.tapAt(tester.getBottomLeft(chip) + const Offset(10, 4));
      expect(log, ['tap', 'tap']);
      await tester.tap(find.byKey(removeKey));
      expect(log, ['tap', 'tap', 'remove']);

      final disabled = find.byKey(_disabled);
      await tester.tapAt(tester.getTopLeft(disabled) + const Offset(10, 19));
      await tester.tap(
        find.descendant(of: disabled, matching: find.byType(GuIcon)),
        warnIfMissed: false,
      );
      expect(log, hasLength(3));

      expect(
        tester.getSemantics(chip),
        isSemantics(
          label: 'Teknoloji',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.byKey(removeKey)),
        isSemantics(label: 'Kaldır', isButton: true, hasTapAction: true),
      );
      expect(
        tester.getSemantics(disabled),
        isSemantics(label: 'Kapalı', isButton: true, isEnabled: false),
      );
      // onTap yok → etkileşimsiz etiket: düğme rolü ve dokunma eylemi yok.
      expect(
        tester.getSemantics(find.text('Doğa')),
        isSemantics(label: 'Doğa', isButton: false, hasTapAction: false),
      );
      handle.dispose();
    });

    testWidgets('T-04 · GuChip · 320 dp × 1.6 uzun metin taşmaz; sayaç '
        'ölçeklenmez (K-57)', (tester) async {
      await tester.pumpApp(
        Center(
          child: GuChip(
            label: 'Doğa Sporları ve Dağcılık ' * 5,
            icon: GuIcons.cpu,
            count: 12,
            removable: true,
            removeSemanticLabel: 'Kaldır',
            onTap: () {},
            onRemove: () {},
          ),
        ),
        size: const Size(320, 640),
        textScale: 1.6,
      );
      expect(tester.takeException(), isNull);
      final size = tester.getSize(find.byType(GuChip));
      expect(size.width, 320);
      expect(size.height, greaterThanOrEqualTo(38));
      expect(tester.getSize(find.byType(GuCountBadge)).height, 18);
    });
  });
}
