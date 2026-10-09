// T-01 · context.gu (GuThemeExtension + GuBuildContextX) — PLAN §7.9.1,
// CD-18. Barrel (`package:gu_ui/gu_ui.dart`) üzerinden içe aktarılır; barrel
// export listesi lib/src dizin taramasıyla doğrulanır.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

/// `MaterialApp` içindeki bir `Builder`'dan `context.gu` değerini yakalar.
Future<GuThemeExtension> _pumpGu(
  WidgetTester tester, {
  ThemeData? theme,
  ThemeData? darkTheme,
  ThemeMode themeMode = ThemeMode.system,
  MediaQueryData Function(MediaQueryData)? mediaQuery,
}) async {
  late GuThemeExtension captured;
  Widget probe = Builder(
    builder: (context) {
      captured = context.gu;
      return const SizedBox.shrink();
    },
  );
  if (mediaQuery != null) {
    final inner = probe;
    probe = Builder(
      builder: (context) => MediaQuery(
        data: mediaQuery(MediaQuery.of(context)),
        child: inner,
      ),
    );
  }
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      home: probe,
    ),
  );
  return captured;
}

void main() {
  group('T-01 · context.gu açık/koyu', () {
    for (final (name, theme, colors, component, shadows, brightness) in [
      (
        'açık',
        GuTheme.light,
        GuColors.light,
        GuComponentColors.light,
        GuShadows.light,
        Brightness.light,
      ),
      (
        'koyu',
        GuTheme.dark,
        GuColors.dark,
        GuComponentColors.dark,
        GuShadows.dark,
        Brightness.dark,
      ),
    ]) {
      testWidgets('$name: colors/component/shadows/text/brightness', (
        tester,
      ) async {
        final gu = await _pumpGu(tester, theme: theme());
        expect(gu.colors, colors);
        expect(gu.component, component);
        expect(gu.shadows, shadows);
        expect(gu.text, GuTypography.resolve(colors));
        expect(gu.brightness, brightness);
        expect(gu.isDark, brightness == Brightness.dark);
      });

      testWidgets('$name: metin renkleri resolve ile (CSS kökü)', (
        tester,
      ) async {
        final gu = await _pumpGu(tester, theme: theme());
        // .gu-root color:text-primary; .t-display/.t-title-* text-heading;
        // .t-caption/.t-overline text-muted.
        expect(gu.text.bodyM.color, colors.textPrimary);
        expect(gu.text.labelL.color, colors.textPrimary);
        expect(gu.text.display.color, colors.textHeading);
        expect(gu.text.titleL.color, colors.textHeading);
        expect(gu.text.caption.color, colors.textMuted);
        expect(gu.text.overline.color, colors.textMuted);
      });
    }

    testWidgets('themeMode.dark → darkTheme seçilir', (tester) async {
      final gu = await _pumpGu(
        tester,
        theme: GuTheme.light(),
        darkTheme: GuTheme.dark(),
        themeMode: ThemeMode.dark,
      );
      expect(gu.isDark, isTrue);
      expect(gu.colors, GuColors.dark);
    });

    testWidgets('themeMode.system + platform koyu → koyu', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final gu = await _pumpGu(
        tester,
        theme: GuTheme.light(),
        darkTheme: GuTheme.dark(),
      );
      expect(gu.isDark, isTrue);
      expect(gu.colors, GuColors.dark);
    });

    testWidgets('tema değişimi animasyonla geçer ve koyuda biter', (
      tester,
    ) async {
      late BuildContext ctx;
      Widget app(ThemeData theme) => MaterialApp(
        theme: theme,
        // Süre varsayılanı kThemeAnimationDuration = GuMotion.base (§7.9.2).
        themeAnimationCurve: GuMotion.easeStandard,
        home: Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox.shrink();
          },
        ),
      );
      expect(kThemeAnimationDuration, GuMotion.base);
      await tester.pumpWidget(app(GuTheme.light()));
      expect(ctx.gu.colors, GuColors.light);

      await tester.pumpWidget(app(GuTheme.dark()));
      await tester.pump(GuMotion.base ~/ 2);
      final mid = ctx.gu.colors.bgCanvas;
      expect(mid, isNot(GuColors.light.bgCanvas));
      expect(mid, isNot(GuColors.dark.bgCanvas));

      await tester.pumpAndSettle();
      expect(ctx.gu.colors, GuColors.dark);
      expect(ctx.gu.isDark, isTrue);
    });
  });

  group('T-01 · context.gu reduceMotion / duration', () {
    testWidgets('varsayılan: hareket açık, süre aynen döner', (tester) async {
      final gu = await _pumpGu(tester, theme: GuTheme.light());
      expect(gu.reduceMotion, isFalse);
      expect(gu.duration(GuMotion.base), GuMotion.base);
      expect(gu.duration(GuMotion.slow), GuMotion.slow);
    });

    testWidgets(
      'MediaQuery(disableAnimations: true) → duration(GuMotion.base) == zero',
      (tester) async {
        final gu = await _pumpGu(
          tester,
          theme: GuTheme.light(),
          mediaQuery: (mq) => mq.copyWith(disableAnimations: true),
        );
        expect(gu.reduceMotion, isTrue);
        expect(gu.duration(GuMotion.base), Duration.zero);
        expect(gu.duration(GuMotion.fast), Duration.zero);
        expect(gu.duration(GuMotion.slow), Duration.zero);
      },
    );

    testWidgets('platform erişilebilirlik ayarı (disableAnimations) okunur', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final gu = await _pumpGu(tester, theme: GuTheme.dark());
      expect(gu.reduceMotion, isTrue);
      expect(gu.duration(GuMotion.base), Duration.zero);
    });
  });

  group('T-01 · context.gu textScaler', () {
    testWidgets('varsayılan: sistem ölçekleyicisi, ölçek 1.0', (tester) async {
      final gu = await _pumpGu(tester, theme: GuTheme.light());
      expect(gu.textScaler, isA<SystemTextScaler>());
      expect(gu.textScaler.scale(15), 15);
      expect(gu.textScaler.scale(24), 24);
    });

    testWidgets('MediaQuery.textScaler aynen taşınır', (tester) async {
      final gu = await _pumpGu(
        tester,
        theme: GuTheme.light(),
        mediaQuery: (mq) =>
            mq.copyWith(textScaler: const TextScaler.linear(1.3)),
      );
      expect(gu.textScaler, const TextScaler.linear(1.3));
      expect(gu.textScaler.scale(15), closeTo(19.5, 1e-9));
    });

    testWidgets('platform metin ölçeği okunur', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final gu = await _pumpGu(tester, theme: GuTheme.light());
      expect(gu.textScaler.scale(10), closeTo(16, 1e-9));
    });
  });

  group('T-01 · context.gu MediaQuery yokken', () {
    testWidgets('reduceMotion false, textScaler noScaling', (tester) async {
      late GuThemeExtension gu;
      await tester.pumpWidget(
        RawView(
          view: tester.view,
          child: Theme(
            data: GuTheme.dark(),
            child: Builder(
              builder: (context) {
                expect(MediaQuery.maybeOf(context), isNull);
                gu = context.gu;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        wrapWithView: false,
      );
      expect(gu.reduceMotion, isFalse);
      expect(gu.textScaler, TextScaler.noScaling);
      expect(gu.colors, GuColors.dark);
      expect(gu.duration(GuMotion.base), GuMotion.base);
    });
  });

  group('T-01 · context.gu eksik extension', () {
    Future<Object?> pumpWith(WidgetTester tester, ThemeData theme) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) {
              context.gu;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return tester.takeException();
    }

    testWidgets("extension'sız ThemeData → assert 'GuTheme.light()/dark()'", (
      tester,
    ) async {
      final error = await pumpWith(tester, ThemeData());
      expect(error, isA<AssertionError>());
      expect(
        (error! as AssertionError).message.toString(),
        allOf(
          contains('GuTheme.light()/dark() kullanılmalı'),
          contains('GuColors'),
        ),
      );
    });

    final complete = <ThemeExtension<dynamic>>[
      GuColors.light,
      GuComponentColors.light,
      GuTypography.resolve(GuColors.light),
      GuShadows.light,
    ];
    for (final missing in complete) {
      final type = missing.type;
      testWidgets('$type eksik → assert mesajı türü adlandırır', (
        tester,
      ) async {
        final error = await pumpWith(
          tester,
          ThemeData(extensions: complete.where((e) => e != missing)),
        );
        expect(error, isA<AssertionError>());
        final message = (error! as AssertionError).message.toString();
        expect(message, contains('GuTheme.light()/dark() kullanılmalı'));
        expect(message, contains('$type'));
      });
    }
  });

  group('T-01 · barrel (lib/gu_ui.dart)', () {
    test(
      'lib/src/{tokens,theme,extensions} dosyalarının tümü alfabetik export edilir',
      () {
        final barrel = File('lib/gu_ui.dart').readAsStringSync();
        final exports = RegExp(
          "^export '([^']+)';",
          multiLine: true,
        ).allMatches(barrel).map((m) => m.group(1)!).toList();

        final files = <String>[
          for (final dir in ['extensions', 'theme', 'tokens'])
            for (final f in Directory('lib/src/$dir').listSync())
              if (f is File && f.path.endsWith('.dart'))
                'src/$dir/${f.uri.pathSegments.last}',
        ]..sort();

        expect(files, isNotEmpty);
        expect(exports, files);
        expect(exports, [...exports]..sort());
        expect(barrel, isNot(contains('TODO')));
      },
    );

    test('barrel üzerinden token/tema/extension türleri erişilebilir', () {
      expect(GuSpacing.s16, 16);
      expect(GuRadius.lg, 20);
      expect(GuMotion.base, const Duration(milliseconds: 200));
      expect(GuBreakpoints.maxContentWidth, 480);
      expect(GuSizes.divider, 1);
      expect(GuOpacity.disabled, 0.5);
      expect('istanbul'.trUpper(), 'İSTANBUL');
      expect(GuTheme.light().extension<GuColors>(), GuColors.light);
    });
  });
}
