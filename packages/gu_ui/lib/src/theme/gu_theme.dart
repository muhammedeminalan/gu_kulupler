import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gu_ui/src/tokens/gu_colors.dart';
import 'package:gu_ui/src/tokens/gu_component_colors.dart';
import 'package:gu_ui/src/tokens/gu_radius.dart';
import 'package:gu_ui/src/tokens/gu_shadows.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/tokens/gu_typography.dart';

/// Uygulama temaları — `GuTheme.light()` / `GuTheme.dark()` → `ThemeData`
/// (PLAN §7.9.3 tablosu satır satır; K-11: `CardThemeData`/`DialogThemeData`).
///
/// Kullanım (D-24):
/// `MaterialApp.router(theme: GuTheme.light(), darkTheme: GuTheme.dark())`,
/// `themeMode` kullanıcı tercihinden. Ekranlar Material
/// varsayılanlarını değil `context.gu.*` token'larını kullanır; buradaki
/// Material alanları yalnızca Material widget'larının varsayılanını tasarıma
/// hizalar. `ColorScheme.fromSeed` kullanılmaz.
abstract final class GuTheme {
  /// Açık tema (`GuColors.light`, `GuComponentColors.light`,
  /// `GuShadows.light`).
  static ThemeData light() => _build(
    colors: GuColors.light,
    component: GuComponentColors.light,
    shadows: GuShadows.light,
  );

  /// Koyu tema (`GuColors.dark`, `GuComponentColors.dark`, `GuShadows.dark`).
  static ThemeData dark() => _build(
    colors: GuColors.dark,
    component: GuComponentColors.dark,
    shadows: GuShadows.dark,
  );

  /// iOS/macOS Cupertino, Android `PredictiveBack` (D-06, navigation §5).
  /// `GuPageTransitions` `fade` istisnaları uygulama katmanındadır (CD-55).
  static const PageTransitionsTheme _pageTransitions = PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
    },
  );

  static ThemeData _build({
    required GuColors colors,
    required GuComponentColors component,
    required GuShadows shadows,
  }) {
    final brightness = colors.brightness;
    final isDark = brightness == Brightness.dark;
    final text = GuTypography.resolve(colors);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      // Kök yazı tipi ailesi (`.gu-root{font-family:Inter,…}` css:77).
      fontFamily: GuTypography.fontFamilyInter,
      textTheme: _textTheme(text),
      colorScheme: _colorScheme(colors),
      scaffoldBackgroundColor: colors.bgCanvas,
      canvasColor: colors.bgCanvas,
      // `.card` css:203; koyu kenarlık `border-default` css:204.
      cardTheme: CardThemeData(
        color: colors.bgSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: GuRadius.borderLg,
          side: BorderSide(
            color: isDark ? colors.borderDefault : colors.borderSoft,
          ),
        ),
      ),
      // `.dialog` css:282: genişlik `min(320px, 100% − 48px)` → en çok
      // `dialogMaxWidth` 320 + yatay `dialogMarginX` 24; koyu kenarlık
      // css:283; scrim `.scrim` css:267.
      dialogTheme: DialogThemeData(
        backgroundColor: colors.bgSurfaceRaised,
        elevation: 0,
        barrierColor: colors.overlayScrim,
        shape: RoundedRectangleBorder(
          borderRadius: GuRadius.borderLg,
          side: isDark
              ? BorderSide(color: colors.borderDefault)
              : BorderSide.none,
        ),
        insetPadding: const EdgeInsets.symmetric(
          horizontal: GuSizes.dialogMarginX,
        ),
        constraints: const BoxConstraints(maxWidth: GuSizes.dialogMaxWidth),
      ),
      // `.sheet` css:268; koyu üst kenarlık (css:269) ve 36×4 tutamaç
      // `GuSheetFrame` içinde çizilir.
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.bgSurfaceRaised,
        modalBackgroundColor: colors.bgSurfaceRaised,
        modalBarrierColor: colors.overlayScrim,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: GuRadius.topXl),
        showDragHandle: false,
      ),
      // `.divider{height:1px;background:var(--border-soft)}` css:106.
      dividerTheme: DividerThemeData(
        color: colors.borderSoft,
        thickness: GuSizes.divider,
        space: GuSizes.divider,
      ),
      // `.appbar` css:127. `GuAppBar` özel widget'tır; Material `AppBar`
      // kullanılmaz.
      appBarTheme: AppBarThemeData(
        backgroundColor: colors.bgCanvas,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: GuSizes.appBarMinHeight,
        systemOverlayStyle: _systemOverlayStyle(colors),
      ),
      // CSS'te `caret-color` yok → imleç metin rengini alır (`.input`
      // `color:var(--text-primary)` css:163/166). Material `TextField` ve
      // `CupertinoTextField` imleci `DefaultSelectionStyle` üzerinden okur.
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.textPrimary,
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      hoverColor: Colors.transparent,
      pageTransitionsTheme: _pageTransitions,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: <ThemeExtension<dynamic>>[
        colors,
        component,
        text,
        shadows,
      ],
      cupertinoOverrideTheme: NoDefaultCupertinoThemeData(
        primaryColor: colors.brandPrimary,
        brightness: brightness,
      ),
    );
  }

  /// Material varsayılanları için eşleme; ekranlar `context.gu.text` kullanır.
  static TextTheme _textTheme(GuTypography t) => TextTheme(
    displaySmall: t.display,
    titleLarge: t.titleL,
    titleMedium: t.titleM,
    titleSmall: t.titleS,
    bodyLarge: t.bodyL,
    bodyMedium: t.bodyM,
    bodySmall: t.bodyS,
    labelLarge: t.labelL,
    labelMedium: t.labelM,
    labelSmall: t.caption,
  );

  /// 15 alanlı eşleme (PLAN §7.9.3); diğer alanlar Material varsayılanı.
  ///
  /// Tek eşleme bloğu, temaya göre `ColorScheme.light`/`.dark` yapıcısı
  /// (tear-off) ile kurulur. `const ColorScheme.light().copyWith(…)`
  /// kullanılmaz: `copyWith` türetilmiş alanları (`surfaceTint`,
  /// `primaryFixed`, `inversePrimary`, `surfaceContainer*`, `inverseSurface`
  /// …) varsayılan şemanın `primary`/`surface` değerlerinden dondurur.
  static ColorScheme _colorScheme(GuColors c) {
    final scheme = c.brightness == Brightness.dark
        ? ColorScheme.dark
        : ColorScheme.light;
    return scheme(
      primary: c.brandPrimary,
      onPrimary: c.brandOnPrimary,
      primaryContainer: c.brandPrimaryContainer,
      onPrimaryContainer: c.brandOnPrimaryContainer,
      secondary: c.brandPrimaryText,
      surface: c.bgSurface,
      onSurface: c.textPrimary,
      surfaceContainerHighest: c.bgSurfaceMuted,
      outline: c.borderDefault,
      outlineVariant: c.borderSoft,
      error: c.stateDanger,
      onError: c.brandOnPrimary,
      errorContainer: c.stateDangerContainer,
      onErrorContainer: c.stateDanger,
      scrim: c.overlayScrim,
    );
  }

  /// PLAN §7.12 `auto` satırı (token-map §11): şeffaf durum çubuğu; açık
  /// temada koyu ikon, koyu temada açık ikon; gezinme çubuğu `bgCanvas`
  /// (iç ekran), ayırıcı `borderSoft`, kontrast zorlaması kapalı.
  static SystemUiOverlayStyle _systemOverlayStyle(GuColors c) {
    // TODO(T-07): GuSystemUi.styleFor(brightness, navBarColor: bgCanvas, navDivider: borderSoft) ile değiştirilir (PLAN §7.9.3, §7.12).
    final isDark = c.brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: c.bgCanvas,
      systemNavigationBarIconBrightness: isDark
          ? Brightness.light
          : Brightness.dark,
      systemNavigationBarDividerColor: c.borderSoft,
      systemNavigationBarContrastEnforced: false,
    );
  }
}
