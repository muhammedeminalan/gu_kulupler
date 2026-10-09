// T-01 · GuTheme — PLAN §7.9.3 tablosu satır satır. Bileşen ölçü/renkleri
// tasarım kaynağından (component-css.css) OKUNUR; CSS karşılığı olmayan
// Material alanları (colorScheme eşlemesi, splash, sayfa geçişleri, yoğunluk)
// PLAN tablosundaki sabit beklentiyle doğrulanır.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../helpers/css_measure.dart';
import '../helpers/design_sources.dart';

/// CSS `var(--x)` değerlerini tema bloğundan çözer (css:2–45 açık, 46–75 koyu;
/// koyu blokta olmayan değişken açık bloktan okunur — radius/hareket).
final class _CssTheme {
  _CssTheme(this.css);

  final CssMeasure css;

  static const String _lightRoot = '.gu-root[data-theme="light"]';
  static const String _darkRoot = '.gu-root[data-theme="dark"]';

  String resolve(String value, Brightness brightness) {
    final m = RegExp(r'^var\((--[\w-]+)\)$').firstMatch(value.trim());
    if (m == null) return value.trim();
    final name = m.group(1)!;
    if (brightness == Brightness.dark && css.has(_darkRoot, name)) {
      return css.raw(_darkRoot, name);
    }
    return css.raw(_lightRoot, name);
  }

  int argb(String selector, String prop, Brightness b) =>
      parseCssColor(resolve(css.raw(selector, prop), b));

  double px(String selector, String prop, Brightness b) =>
      CssMeasure.parsePx(resolve(css.raw(selector, prop), b));

  /// `border:1px solid var(--x)` → (genişlik, ARGB).
  (double, int) border(String selector, String prop, Brightness b) {
    final parts = css.tokens(selector, prop);
    expect(parts, hasLength(3), reason: '$selector $prop');
    expect(parts[1], 'solid', reason: '$selector $prop');
    return (CssMeasure.parsePx(parts[0]), parseCssColor(resolve(parts[2], b)));
  }

  /// `border-radius` kısa yazımı → px listesi (`var(--r-xl) var(--r-xl) 0 0`).
  List<double> radii(String selector, Brightness b) => [
    for (final t in css.tokens(selector, 'border-radius'))
      CssMeasure.parsePx(resolve(t, b)),
  ];
}

typedef _Case = ({
  String name,
  ThemeData theme,
  GuColors colors,
  GuComponentColors component,
  GuShadows shadows,
  Brightness brightness,
});

/// colorScheme 15 alanı ↔ GuColors (PLAN §7.9.3).
final List<(String, Color Function(ColorScheme), Color Function(GuColors))>
_schemeMap = [
  ('primary', (s) => s.primary, (c) => c.brandPrimary),
  ('onPrimary', (s) => s.onPrimary, (c) => c.brandOnPrimary),
  (
    'primaryContainer',
    (s) => s.primaryContainer,
    (c) => c.brandPrimaryContainer,
  ),
  (
    'onPrimaryContainer',
    (s) => s.onPrimaryContainer,
    (c) => c.brandOnPrimaryContainer,
  ),
  ('secondary', (s) => s.secondary, (c) => c.brandPrimaryText),
  ('surface', (s) => s.surface, (c) => c.bgSurface),
  ('onSurface', (s) => s.onSurface, (c) => c.textPrimary),
  (
    'surfaceContainerHighest',
    (s) => s.surfaceContainerHighest,
    (c) => c.bgSurfaceMuted,
  ),
  ('outline', (s) => s.outline, (c) => c.borderDefault),
  ('outlineVariant', (s) => s.outlineVariant, (c) => c.borderSoft),
  ('error', (s) => s.error, (c) => c.stateDanger),
  ('onError', (s) => s.onError, (c) => c.brandOnPrimary),
  ('errorContainer', (s) => s.errorContainer, (c) => c.stateDangerContainer),
  ('onErrorContainer', (s) => s.onErrorContainer, (c) => c.stateDanger),
  ('scrim', (s) => s.scrim, (c) => c.overlayScrim),
];

/// textTheme 10 alanı ↔ GuTypography (PLAN §7.9.3).
final List<
  (String, TextStyle? Function(TextTheme), TextStyle Function(GuTypography))
>
_textMap = [
  ('displaySmall', (t) => t.displaySmall, (g) => g.display),
  ('titleLarge', (t) => t.titleLarge, (g) => g.titleL),
  ('titleMedium', (t) => t.titleMedium, (g) => g.titleM),
  ('titleSmall', (t) => t.titleSmall, (g) => g.titleS),
  ('bodyLarge', (t) => t.bodyLarge, (g) => g.bodyL),
  ('bodyMedium', (t) => t.bodyMedium, (g) => g.bodyM),
  ('bodySmall', (t) => t.bodySmall, (g) => g.bodyS),
  ('labelLarge', (t) => t.labelLarge, (g) => g.labelL),
  ('labelMedium', (t) => t.labelMedium, (g) => g.labelM),
  ('labelSmall', (t) => t.labelSmall, (g) => g.caption),
];

void main() {
  late _CssTheme css;

  setUpAll(() => css = _CssTheme(CssMeasure.load()));

  final cases = <_Case>[
    (
      name: 'açık',
      theme: GuTheme.light(),
      colors: GuColors.light,
      component: GuComponentColors.light,
      shadows: GuShadows.light,
      brightness: Brightness.light,
    ),
    (
      name: 'koyu',
      theme: GuTheme.dark(),
      colors: GuColors.dark,
      component: GuComponentColors.dark,
      shadows: GuShadows.dark,
      brightness: Brightness.dark,
    ),
  ];

  for (final c in cases) {
    final theme = c.theme;
    final colors = c.colors;
    final b = c.brightness;
    final isDark = b == Brightness.dark;

    group('T-01 · GuTheme.${isDark ? 'dark' : 'light'}() (${c.name})', () {
      test('useMaterial3 ve brightness', () {
        expect(theme.useMaterial3, isTrue);
        expect(theme.brightness, b);
        expect(theme.colorScheme.brightness, b);
      });

      test('extensions: 4 tip, §7.9.2 değerleri', () {
        expect(theme.extensions.keys.toSet(), {
          GuColors,
          GuComponentColors,
          GuTypography,
          GuShadows,
        });
        expect(theme.extension<GuColors>(), same(colors));
        expect(theme.extension<GuComponentColors>(), same(c.component));
        expect(theme.extension<GuShadows>(), same(c.shadows));
        expect(
          theme.extension<GuTypography>(),
          GuTypography.resolve(colors),
        );
      });

      test("fontFamily 'Inter' (kök `.gu-root` font-family css:77)", () {
        final rootFamily = css.css.tokens('.gu-root', 'font-family').first;
        final first = rootFamily.split(',').first;
        expect(first, GuTypography.fontFamilyInter);
        // Eşlenmeyen Material stilleri kök aileyi alır.
        for (final s in [
          theme.textTheme.displayLarge,
          theme.textTheme.headlineMedium,
          theme.textTheme.headlineSmall,
          theme.primaryTextTheme.bodyMedium,
        ]) {
          expect(s?.fontFamily, first);
        }
        // Eşlenen stil kendi ailesini korur (Montserrat başlık).
        expect(
          theme.textTheme.displaySmall?.fontFamily,
          GuTypography.resolve(colors).display.fontFamily,
        );
        expect(theme.textTheme.displaySmall?.fontFamily, 'Montserrat');
      });

      test('textTheme 10 eşleme GuTypography.resolve ile', () {
        final t = GuTypography.resolve(colors);
        for (final (name, material, gu) in _textMap) {
          final actual = material(theme.textTheme);
          final expected = gu(t);
          expect(actual, isNotNull, reason: name);
          expect(actual!.fontFamily, expected.fontFamily, reason: name);
          expect(actual.fontSize, expected.fontSize, reason: name);
          expect(actual.fontWeight, expected.fontWeight, reason: name);
          expect(actual.height, expected.height, reason: name);
          expect(actual.letterSpacing, expected.letterSpacing, reason: name);
          expect(actual.color, expected.color, reason: name);
        }
      });

      test('colorScheme 15 alan GuColors eşlemesi (fromSeed yok)', () {
        expect(_schemeMap, hasLength(15));
        for (final (name, scheme, gu) in _schemeMap) {
          expect(scheme(theme.colorScheme), gu(colors), reason: name);
        }
      });

      test('colorScheme tamamı == ColorScheme.${isDark ? 'dark' : 'light'}'
          '(15 alan) — türetilmiş alanlar (surfaceTint, primaryFixed, '
          'inversePrimary, surfaceContainer*) eşlenen renklerden', () {
        final expected =
            Function.apply(
                  isDark ? ColorScheme.dark : ColorScheme.light,
                  const [],
                  {
                    for (final (name, _, gu) in _schemeMap)
                      Symbol(name): gu(colors),
                  },
                )
                as ColorScheme;
        expect(theme.colorScheme, expected);
        expect(theme.colorScheme.surfaceTint, colors.brandPrimary);
        expect(theme.colorScheme.primaryFixed, colors.brandPrimary);
        expect(theme.colorScheme.surfaceContainer, colors.bgSurface);
        expect(theme.colorScheme.inverseSurface, colors.textPrimary);
      });

      test(
        'scaffoldBackgroundColor / canvasColor = bgCanvas (.screen css:119)',
        () {
          final canvas = css.argb('.screen', 'background', b);
          expect(colors.bgCanvas.toARGB32(), canvas);
          expect(theme.scaffoldBackgroundColor, colors.bgCanvas);
          expect(theme.canvasColor, colors.bgCanvas);
        },
      );

      test('cardTheme: .card css:203 (+ koyu kenarlık css:204), radius 20', () {
        final card = theme.cardTheme;
        expect(card.color, colors.bgSurface);
        expect(card.color!.toARGB32(), css.argb('.card', 'background', b));
        expect(card.elevation, 0);
        expect(card.margin, EdgeInsets.zero);

        final shape = card.shape! as RoundedRectangleBorder;
        expect(shape.borderRadius, GuRadius.borderLg);
        final radius = (shape.borderRadius as BorderRadius).topLeft;
        expect(radius.x, 20);
        expect(radius.x, css.px('.card', 'border-radius', b));

        final (width, lightBorder) = css.border('.card', 'border', b);
        expect(shape.side.width, width);
        expect(shape.side.width, GuSizes.cardBorder);
        final darkBorder = parseCssColor(
          css.resolve(
            css.css.raw('.gu-root[data-theme="dark"] .card', 'border-color'),
            b,
          ),
        );
        expect(shape.side.color.toARGB32(), isDark ? darkBorder : lightBorder);
        expect(
          shape.side.color,
          isDark ? colors.borderDefault : colors.borderSoft,
        );
      });

      test(
        'dialogTheme: .dialog css:282 (+ koyu kenarlık css:283), scrim css:267',
        () {
          final dialog = theme.dialogTheme;
          expect(dialog.backgroundColor, colors.bgSurfaceRaised);
          expect(
            dialog.backgroundColor!.toARGB32(),
            css.argb('.dialog', 'background', b),
          );
          expect(dialog.elevation, 0);
          expect(dialog.barrierColor, colors.overlayScrim);
          expect(
            dialog.barrierColor!.toARGB32(),
            css.argb('.scrim', 'background', b),
          );

          final shape = dialog.shape! as RoundedRectangleBorder;
          expect(shape.borderRadius, GuRadius.borderLg);
          expect(
            (shape.borderRadius as BorderRadius).topLeft.x,
            css.px('.dialog', 'border-radius', b),
          );
          if (isDark) {
            final (width, color) = css.border(
              '.gu-root[data-theme="dark"] .dialog',
              'border',
              b,
            );
            expect(shape.side.width, width);
            expect(shape.side.color, colors.borderDefault);
            expect(shape.side.color.toARGB32(), color);
            expect(shape.side.style, BorderStyle.solid);
          } else {
            expect(shape.side, BorderSide.none);
          }

          // width:min(320px,calc(100% - 48px)) → en çok 320, yatay 24 + 24.
          final margin = -css.css.fn('.dialog', 'width', 'min', arg: 1);
          final maxWidth = css.css.fn('.dialog', 'width', 'min');
          expect(
            dialog.insetPadding,
            const EdgeInsets.symmetric(horizontal: GuSizes.dialogMarginX),
          );
          expect(dialog.insetPadding, GuInsets.h24);
          expect(dialog.insetPadding!.horizontal, margin);
          expect(dialog.insetPadding!.vertical, 0);
          expect(GuSizes.dialogMarginX * 2, margin);
          expect(
            dialog.constraints,
            const BoxConstraints(maxWidth: GuSizes.dialogMaxWidth),
          );
          expect(dialog.constraints!.maxWidth, maxWidth);
          expect(dialog.constraints!.minWidth, 0);
        },
      );

      test('bottomSheetTheme: .sheet css:268, scrim css:267, tutamaç yok', () {
        final sheet = theme.bottomSheetTheme;
        final bg = css.argb('.sheet', 'background', b);
        expect(sheet.backgroundColor, colors.bgSurfaceRaised);
        expect(sheet.modalBackgroundColor, colors.bgSurfaceRaised);
        expect(sheet.backgroundColor!.toARGB32(), bg);
        expect(sheet.modalBackgroundColor!.toARGB32(), bg);
        expect(sheet.modalBarrierColor, colors.overlayScrim);
        expect(
          sheet.modalBarrierColor!.toARGB32(),
          css.argb('.scrim', 'background', b),
        );
        expect(sheet.elevation, 0);
        expect(sheet.showDragHandle, isFalse);

        final shape = sheet.shape! as RoundedRectangleBorder;
        expect(shape.borderRadius, GuRadius.topXl);
        final r = shape.borderRadius as BorderRadius;
        // border-radius: var(--r-xl) var(--r-xl) 0 0 → TL TR BR BL.
        final cssRadii = css.radii('.sheet', b);
        expect(cssRadii, [28, 28, 0, 0]);
        expect(r.topLeft.x, cssRadii[0]);
        expect(r.topRight.x, cssRadii[1]);
        expect(r.bottomRight, Radius.zero);
        expect(r.bottomLeft, Radius.zero);
        // Koyu üst kenarlık (css:269) GuSheetFrame'de; temada kenarlık yok.
        expect(shape.side, BorderSide.none);
      });

      test('dividerTheme: .divider css:106 (1px, border-soft)', () {
        final divider = theme.dividerTheme;
        expect(divider.color, colors.borderSoft);
        expect(
          divider.color!.toARGB32(),
          css.argb('.divider', 'background', b),
        );
        expect(divider.thickness, css.px('.divider', 'height', b));
        expect(divider.thickness, 1);
        expect(divider.space, 1);
      });

      test(
        'appBarTheme: .appbar css:127 + systemOverlayStyle (§7.12 auto)',
        () {
          final appBar = theme.appBarTheme;
          expect(appBar.backgroundColor, colors.bgCanvas);
          expect(
            appBar.backgroundColor!.toARGB32(),
            css.argb('.appbar', 'background', b),
          );
          expect(appBar.elevation, 0);
          expect(appBar.scrolledUnderElevation, 0);
          expect(appBar.toolbarHeight, 56);
          expect(appBar.toolbarHeight, css.px('.appbar', 'min-height', b));

          final style = appBar.systemOverlayStyle!;
          expect(style.statusBarColor, Colors.transparent);
          expect(
            style.statusBarIconBrightness,
            isDark ? Brightness.light : Brightness.dark,
          );
          expect(
            style.statusBarBrightness,
            isDark ? Brightness.dark : Brightness.light,
          );
          expect(style.systemNavigationBarColor, colors.bgCanvas);
          expect(
            style.systemNavigationBarIconBrightness,
            isDark ? Brightness.light : Brightness.dark,
          );
          expect(style.systemNavigationBarDividerColor, colors.borderSoft);
          expect(style.systemNavigationBarContrastEnforced, isFalse);
        },
      );

      test('textSelectionTheme.cursorColor = textPrimary (caret-color yok; '
          '.input color css:163)', () {
        expect(
          css.css.declarations.where((d) => d.prop == 'caret-color'),
          isEmpty,
        );
        expect(theme.textSelectionTheme.cursorColor, colors.textPrimary);
        expect(
          theme.textSelectionTheme.cursorColor!.toARGB32(),
          css.argb('.input', 'color', b),
        );
      });

      test('splash yok: NoSplash + şeffaf highlight/splash/hover', () {
        expect(theme.splashFactory, same(NoSplash.splashFactory));
        expect(theme.highlightColor, Colors.transparent);
        expect(theme.splashColor, Colors.transparent);
        expect(theme.hoverColor, Colors.transparent);
      });

      test('pageTransitionsTheme: 3 platform (D-06)', () {
        final builders = theme.pageTransitionsTheme.builders;
        expect(builders.keys.toSet(), {
          TargetPlatform.iOS,
          TargetPlatform.macOS,
          TargetPlatform.android,
        });
        expect(
          builders[TargetPlatform.iOS],
          isA<CupertinoPageTransitionsBuilder>(),
        );
        expect(
          builders[TargetPlatform.macOS],
          isA<CupertinoPageTransitionsBuilder>(),
        );
        expect(
          builders[TargetPlatform.android],
          isA<PredictiveBackPageTransitionsBuilder>(),
        );
      });

      test('visualDensity standard, materialTapTargetSize padded', () {
        expect(theme.visualDensity, VisualDensity.standard);
        expect(theme.materialTapTargetSize, MaterialTapTargetSize.padded);
      });

      test(
        'cupertinoOverrideTheme: primaryColor brandPrimary + brightness',
        () {
          final cupertino = theme.cupertinoOverrideTheme!;
          expect(cupertino.primaryColor, colors.brandPrimary);
          expect(cupertino.brightness, b);
        },
      );

      test('her çağrı eşit ThemeData döndürür', () {
        final again = isDark ? GuTheme.dark() : GuTheme.light();
        expect(again, theme);
        expect(again.hashCode, theme.hashCode);
      });
    });
  }

  group('T-01 · GuTheme açık ↔ koyu', () {
    test("ThemeData.lerp extension'ları alan alan geçirir", () {
      final light = GuTheme.light();
      final dark = GuTheme.dark();
      expect(
        ThemeData.lerp(light, dark, 0).extension<GuColors>(),
        GuColors.light,
      );
      expect(
        ThemeData.lerp(light, dark, 1).extension<GuColors>(),
        GuColors.dark,
      );
      final mid = ThemeData.lerp(light, dark, 0.5);
      expect(
        mid.extension<GuColors>()!.bgCanvas,
        Color.lerp(GuColors.light.bgCanvas, GuColors.dark.bgCanvas, 0.5),
      );
      expect(
        mid.extension<GuComponentColors>(),
        GuComponentColors.light.lerp(GuComponentColors.dark, 0.5),
      );
    });

    test('yalnızca koyu temaya özgü farklar: kart/dialog kenarlığı', () {
      final light = GuTheme.light();
      final dark = GuTheme.dark();
      final lightCard = light.cardTheme.shape! as RoundedRectangleBorder;
      final darkCard = dark.cardTheme.shape! as RoundedRectangleBorder;
      expect(lightCard.side.color, GuColors.light.borderSoft);
      expect(darkCard.side.color, GuColors.dark.borderDefault);
      final lightDialog = light.dialogTheme.shape! as RoundedRectangleBorder;
      final darkDialog = dark.dialogTheme.shape! as RoundedRectangleBorder;
      expect(lightDialog.side, BorderSide.none);
      expect(darkDialog.side, BorderSide(color: GuColors.dark.borderDefault));
    });
  });

  group('T-01 · GuTheme Material widget varsayılanları', () {
    Future<double> dialogWidth(WidgetTester tester, double screenWidth) async {
      tester.view
        ..physicalSize = Size(screenWidth, 640)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: GuTheme.light(),
          home: const Scaffold(
            body: Dialog(
              child: SizedBox(width: double.infinity, height: 40),
            ),
          ),
        ),
      );
      return tester
          .getSize(
            find.descendant(
              of: find.byType(Dialog),
              matching: find.byType(Material),
            ),
          )
          .width;
    }

    testWidgets('Dialog genişliği min(320, ekran − 48) (css:282)', (
      tester,
    ) async {
      expect(await dialogWidth(tester, 800), GuSizes.dialogMaxWidth);
      expect(
        await dialogWidth(tester, 320),
        320 - 2 * GuSizes.dialogMarginX,
      );
    });

    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      testWidgets('TextField imleci textPrimary (${platform.name})', (
        tester,
      ) async {
        for (final (theme, colors) in [
          (GuTheme.light(), GuColors.light),
          (GuTheme.dark(), GuColors.dark),
        ]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: theme.copyWith(platform: platform),
              home: const Scaffold(body: TextField()),
            ),
          );
          final editable = tester.widget<EditableText>(
            find.byType(EditableText),
          );
          expect(editable.cursorColor, colors.textPrimary);
        }
      });
    }

    testWidgets(
      'CupertinoTextField imleci textPrimary (DefaultSelectionStyle)',
      (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: GuTheme.dark(),
            home: const Scaffold(body: CupertinoTextField()),
          ),
        );
        final editable = tester.widget<EditableText>(find.byType(EditableText));
        expect(editable.cursorColor, GuColors.dark.textPrimary);
      },
    );

    testWidgets('Divider ve Card temadan renk/şekil alır', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: GuTheme.dark(),
          home: const Scaffold(
            body: Column(
              children: [
                Divider(),
                Card(child: SizedBox()),
              ],
            ),
          ),
        ),
      );
      final context = tester.element(find.byType(Divider));
      expect(DividerTheme.of(context).color, GuColors.dark.borderSoft);
      final material = tester.widget<Material>(
        find.descendant(of: find.byType(Card), matching: find.byType(Material)),
      );
      expect(material.color, GuColors.dark.bgSurface);
      expect(
        (material.shape! as RoundedRectangleBorder).side.color,
        GuColors.dark.borderDefault,
      );
      final scaffold = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(Scaffold),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(scaffold.color, GuColors.dark.bgCanvas);
    });
  });
}
