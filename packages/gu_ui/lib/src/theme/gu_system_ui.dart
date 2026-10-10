import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';

/// Durum çubuğu ikon stili (D-20, PLAN §7.12).
enum GuSystemUiStyle {
  /// Tema parlaklığına göre: açık tema → koyu ikon, koyu tema → açık ikon.
  auto,

  /// Her iki temada açık ikon (koyu zemin üstünde başlayan yüzeyler:
  /// CLB-03, EVT-02 kapaklı, MGT-07, SHT-34 — CD-89).
  lightIcons,

  /// Her iki temada koyu ikon.
  darkIcons,
}

/// Tek `SystemUiOverlayStyle` kaynağı — prototipteki `StatusBar` maketinin
/// (`shell.js:10`, `darkChrome` `shell.js:24`) karşılığı (D-20, K-02).
///
/// `GuApp.builder` kökünde `GuSystemUi()` (auto) durur; istisna ekranlar
/// kendi gövdesini `GuSystemUi(style: GuSystemUiStyle.lightIcons)` ile
/// sarar (içteki bölge dıştakini geçersiz kılar). Hiçbir ekran
/// `SystemChrome.setSystemUIOverlayStyle` çağırmaz; modal rotalar bölge
/// eklemez (scrim açıkken alttaki stil korunur).
///
/// Gezinme çubuğu rengi varsayılan `bg.canvas` (iç ekran); sekme kökü
/// [navBarColor] ile `bg.surface` verir (PLAN §7.12 tablosu).
final class GuSystemUi extends StatelessWidget {
  const GuSystemUi({
    required this.child,
    this.style = GuSystemUiStyle.auto,
    this.navBarColor,
    super.key,
  });

  /// Durum çubuğu ikon stili.
  final GuSystemUiStyle style;

  /// Sistem gezinme çubuğu rengi; `null` → `bg.canvas`.
  final Color? navBarColor;

  /// Stilin uygulanacağı alt ağaç.
  final Widget child;

  /// PLAN §7.12 tablosu: şeffaf durum çubuğu; ikon parlaklığı [style]'a
  /// göre ([GuSystemUiStyle.auto] → [themeBrightness]'ın tersi); gezinme
  /// çubuğu rengi [navBarColor], ikonu temadan, ayırıcı [navDivider],
  /// kontrast zorlaması kapalı.
  static SystemUiOverlayStyle styleFor(
    Brightness themeBrightness, {
    required Color navBarColor,
    required Color navDivider,
    GuSystemUiStyle style = GuSystemUiStyle.auto,
  }) {
    final isDarkTheme = themeBrightness == Brightness.dark;
    final lightIcons = switch (style) {
      GuSystemUiStyle.auto => isDarkTheme,
      GuSystemUiStyle.lightIcons => true,
      GuSystemUiStyle.darkIcons => false,
    };
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      // Android: ikonun kendi parlaklığı.
      statusBarIconBrightness: lightIcons ? Brightness.light : Brightness.dark,
      // iOS: çubuğun arkasındaki zeminin parlaklığı (ikonun tersi).
      statusBarBrightness: lightIcons ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: navBarColor,
      systemNavigationBarIconBrightness: isDarkTheme
          ? Brightness.light
          : Brightness.dark,
      systemNavigationBarDividerColor: navDivider,
      systemNavigationBarContrastEnforced: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: styleFor(
        gu.brightness,
        style: style,
        navBarColor: navBarColor ?? gu.colors.bgCanvas,
        navDivider: gu.colors.borderSoft,
      ),
      child: child,
    );
  }
}
