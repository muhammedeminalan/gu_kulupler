// T-07 · GuSystemUi (widget-catalog ek-4; D-20; PLAN §7.12 tablosu).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../helpers/pump_app.dart';

/// (durum çubuğu ikonu — Android, durum çubuğu zemini — iOS).
typedef _Status = (Brightness icon, Brightness bar);

const _Status _lightIcons = (Brightness.light, Brightness.dark);
const _Status _darkIcons = (Brightness.dark, Brightness.light);

void main() {
  group('T-07 · GuSystemUi', () {
    test('T-07 · GuSystemUi · styleFor: 3 stil × 2 tema tablosu (§7.12); '
        'şeffaf durum çubuğu, gezinme çubuğu temadan', () {
      const table = <(Brightness, GuSystemUiStyle), _Status>{
        (Brightness.light, GuSystemUiStyle.auto): _darkIcons,
        (Brightness.dark, GuSystemUiStyle.auto): _lightIcons,
        (Brightness.light, GuSystemUiStyle.lightIcons): _lightIcons,
        (Brightness.dark, GuSystemUiStyle.lightIcons): _lightIcons,
        (Brightness.light, GuSystemUiStyle.darkIcons): _darkIcons,
        (Brightness.dark, GuSystemUiStyle.darkIcons): _darkIcons,
      };
      expect(table.length, GuSystemUiStyle.values.length * 2);

      for (final MapEntry(key: (theme, style), value: (icon, bar))
          in table.entries) {
        final colors = theme == Brightness.dark
            ? GuColors.dark
            : GuColors.light;
        final result = GuSystemUi.styleFor(
          theme,
          style: style,
          navBarColor: colors.bgSurface,
          navDivider: colors.borderSoft,
        );
        final reason = '$theme · $style';
        expect(result.statusBarColor, Colors.transparent, reason: reason);
        expect(result.statusBarIconBrightness, icon, reason: reason);
        expect(result.statusBarBrightness, bar, reason: reason);
        expect(
          result.systemNavigationBarColor,
          colors.bgSurface,
          reason: reason,
        );
        expect(
          result.systemNavigationBarIconBrightness,
          theme == Brightness.dark ? Brightness.light : Brightness.dark,
          reason: reason,
        );
        expect(
          result.systemNavigationBarDividerColor,
          colors.borderSoft,
          reason: reason,
        );
        expect(
          result.systemNavigationBarContrastEnforced,
          isFalse,
          reason: reason,
        );
      }

      // Varsayılan stil `auto`; tema `appBarTheme` aynı kaynağı kullanır.
      for (final (theme, colors) in [
        (GuTheme.light(), GuColors.light),
        (GuTheme.dark(), GuColors.dark),
      ]) {
        expect(
          theme.appBarTheme.systemOverlayStyle,
          GuSystemUi.styleFor(
            colors.brightness,
            navBarColor: colors.bgCanvas,
            navDivider: colors.borderSoft,
          ),
        );
      }
    });

    testWidgets('T-07 · GuSystemUi · bölge sistem stilini verir: açık / koyu '
        'auto, navBarColor üst yazımı; içteki lightIcons dıştakini geçersiz '
        'kılar', (tester) async {
      for (final (mode, colors) in [
        (ThemeMode.light, GuColors.light),
        (ThemeMode.dark, GuColors.dark),
      ]) {
        await tester.pumpApp(
          const GuSystemUi(child: SizedBox.expand()),
          theme: mode,
        );
        expect(
          SystemChrome.latestStyle,
          GuSystemUi.styleFor(
            colors.brightness,
            navBarColor: colors.bgCanvas,
            navDivider: colors.borderSoft,
          ),
          reason: '$mode',
        );
        expect(
          tester
              .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
                find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
              )
              .value,
          SystemChrome.latestStyle,
          reason: '$mode',
        );
      }

      // Sekme kökü: gezinme çubuğu `bg.surface`; iç bölge açık ikon.
      const c = GuColors.light;
      await tester.pumpApp(
        GuSystemUi(
          navBarColor: c.bgSurface,
          child: const GuSystemUi(
            style: GuSystemUiStyle.lightIcons,
            child: SizedBox.expand(),
          ),
        ),
      );
      final regions = tester
          .widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
            find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
          )
          .toList();
      expect(regions, hasLength(2));
      expect(regions.first.value.systemNavigationBarColor, c.bgSurface);
      expect(regions.first.value.statusBarIconBrightness, Brightness.dark);
      expect(
        SystemChrome.latestStyle,
        GuSystemUi.styleFor(
          Brightness.light,
          style: GuSystemUiStyle.lightIcons,
          navBarColor: c.bgCanvas,
          navDivider: c.borderSoft,
        ),
      );
      expect(
        SystemChrome.latestStyle!.statusBarIconBrightness,
        Brightness.light,
      );
    });
  });
}
