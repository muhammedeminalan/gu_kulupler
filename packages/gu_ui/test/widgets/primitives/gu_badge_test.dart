// T-04 · GuBadge (widget-catalog #13; CD-27, CD-80, K-33).
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/design_sources.dart';
import '../../helpers/pump_app.dart';

/// CSS `.badge-<tür>{…}` gövdeleri (`.badge-full,.badge-neutral` ayrıştırılır).
Map<String, String> _badgeRules() {
  final rules = <String, String>{};
  final pattern = RegExp(r'((?:\.badge-[a-z]+,?)+)\{([^}]*)\}');
  for (final match in pattern.allMatches(componentCss())) {
    for (final selector in match.group(1)!.split(',')) {
      rules[selector.substring('.badge-'.length)] = match.group(2)!;
    }
  }
  return rules;
}

/// CSS değişkeni → tema rengi (rozetlerin kullandığı küme).
Map<String, Color> _vars(GuColors c) => {
  'brand-primary': c.brandPrimary,
  'brand-primary-container': c.brandPrimaryContainer,
  'brand-on-primary-container': c.brandOnPrimaryContainer,
  'bg-surface': c.bgSurface,
  'bg-surface-muted': c.bgSurfaceMuted,
  'text-heading': c.textHeading,
  'text-secondary': c.textSecondary,
  'text-muted': c.textMuted,
  'border-default': c.borderDefault,
  'state-success': c.stateSuccess,
  'state-success-container': c.stateSuccessContainer,
  'state-danger': c.stateDanger,
  'state-danger-container': c.stateDangerContainer,
  'state-warning': c.stateWarning,
  'state-warning-container': c.stateWarningContainer,
  'state-info': c.stateInfo,
  'state-info-container': c.stateInfoContainer,
};

/// `var(--x)` ya da `#fff` → renk.
Color _cssColor(String value, GuColors c) {
  final variable = RegExp(r'^var\(--([a-z-]+)\)$').firstMatch(value);
  if (variable != null) return _vars(c)[variable.group(1)]!;
  expect(parseCssColor(value), c.brandOnPrimary.toARGB32());
  return c.brandOnPrimary;
}

String? _declaration(String rule, String property) =>
    RegExp('(?:^|;)$property:([^;]+)').firstMatch(rule)?.group(1);

BoxDecoration _decoration(WidgetTester tester) =>
    tester
            .widget<DecoratedBox>(
              find.descendant(
                of: find.byType(GuBadge),
                matching: find.byType(DecoratedBox),
              ),
            )
            .decoration
        as BoxDecoration;

void main() {
  group('T-04 · GuBadge', () {
    testWidgets('T-04 · GuBadge · 12 tür CSS .badge-* renkleriyle (açık + '
        'koyu); 22 px, dolgu 8, ikon 12 + boşluk 4, board kenarlığı', (
      tester,
    ) async {
      final rules = _badgeRules();
      expect(
        GuBadgeKind.values.map((kind) => kind.name),
        orderedEquals(<String>[
          'neutral',
          'success',
          'danger',
          'pending',
          'info',
          'full',
          'brand',
          'president',
          'board',
          'advisor',
          'member',
          'superadmin',
        ]),
      );
      for (final theme in [ThemeMode.light, ThemeMode.dark]) {
        final colors = theme == ThemeMode.light
            ? GuColors.light
            : GuColors.dark;
        for (final kind in GuBadgeKind.values) {
          final rule = rules[kind.name]!;
          final background = _cssColor(
            _declaration(rule, 'background')!,
            colors,
          );
          final foreground = _cssColor(_declaration(rule, 'color')!, colors);
          final borderRule = _declaration(rule, 'border');

          await tester.pumpApp(
            Center(
              child: GuBadge(label: 'Etiket', kind: kind, icon: GuIcons.info),
            ),
            theme: theme,
          );
          final reason = '${kind.name} · ${theme.name}';
          final decoration = _decoration(tester);
          expect(decoration.color, background, reason: reason);
          expect(decoration.borderRadius, GuRadius.borderFull, reason: reason);
          final text = tester.widget<Text>(find.text('Etiket'));
          expect(
            text.style,
            GuTypography.resolve(colors).badge.copyWith(color: foreground),
            reason: reason,
          );
          final icon = tester.widget<GuIcon>(find.byType(GuIcon));
          expect(icon.icon, GuIcons.info);
          expect(icon.size, 12);
          expect(icon.color, foreground, reason: reason);

          // border-box: kenarlık yüksekliği değiştirmez, genişliğe 2 px ekler.
          var chrome = 2 * 8.0 + 12 + 4;
          if (borderRule == null) {
            expect(decoration.border, isNull, reason: reason);
          } else {
            expect(borderRule, '1px solid var(--border-default)');
            expect(kind, GuBadgeKind.board);
            expect(
              decoration.border,
              Border.all(color: colors.borderDefault),
              reason: reason,
            );
            chrome += 2 * 1;
          }
          final size = tester.getSize(find.byType(GuBadge));
          expect(size.height, 22, reason: reason);
          expect(
            size.width,
            closeTo(chrome + tester.getSize(find.text('Etiket')).width, 1e-6),
            reason: reason,
          );
        }
      }

      // İkonsuz varsayılan (neutral): yalnız metin + 2 × 8 dolgu.
      await tester.pumpApp(const Center(child: GuBadge(label: 'Spor ve Doğa')));
      expect(find.byType(GuIcon), findsNothing);
      expect(_decoration(tester).color, GuColors.light.bgSurfaceMuted);
      expect(
        tester.getSize(find.byType(GuBadge)).width,
        closeTo(tester.getSize(find.text('Spor ve Doğa')).width + 16, 1e-6),
      );
    });

    testWidgets('T-04 · GuBadge · 320 dp × 1.6 uzun metin taşmaz, metin '
        'ölçeklenir, yükseklik sabit; Semantics', (tester) async {
      final handle = tester.ensureSemantics();
      final long = 'Çok uzun bir rozet etiketi ' * 6;
      await tester.pumpApp(
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const GuBadge(
                label: 'Onay gerekli',
                kind: GuBadgeKind.info,
                icon: GuIcons.shieldCheck,
              ),
              GuBadge(
                label: long,
                kind: GuBadgeKind.board,
                icon: GuIcons.info,
              ),
            ],
          ),
        ),
        size: const Size(320, 640),
        textScale: 1.6,
      );
      expect(tester.takeException(), isNull);
      final wide = tester.getSize(find.byType(GuBadge).last);
      expect(wide, const Size(320, 22));
      final text = tester.widget<Text>(find.text(long));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
      // `.badge` yazısı `calc(12px*var(--ts))` → ölçeklenir (K-57 dışında).
      expect(
        tester.renderObject<RenderParagraph>(find.text(long)).textScaler,
        const TextScaler.linear(1.6),
      );
      expect(tester.getSize(find.byType(GuBadge).first).height, 22);
      // İkon dekoratif; etiket metinden okunur.
      expect(find.bySemanticsLabel('Onay gerekli'), findsOneWidget);
      handle.dispose();
    });
  });
}
