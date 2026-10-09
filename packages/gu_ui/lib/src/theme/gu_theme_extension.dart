import 'package:flutter/material.dart';
import 'package:gu_ui/src/tokens/gu_colors.dart';
import 'package:gu_ui/src/tokens/gu_component_colors.dart';
import 'package:gu_ui/src/tokens/gu_shadows.dart';
import 'package:gu_ui/src/tokens/gu_typography.dart';

/// `context.gu` arkasındaki değer nesnesi (PLAN §7.9.1, CD-18).
///
/// Yalnızca tema parlaklığına bağlı token'ları taşır: [colors], [text],
/// [shadows], [component], [brightness]/[isDark] ile erişilebilirlik
/// tercihleri ([reduceMotion], [textScaler]). Statik token sınıfları
/// (`GuSpacing`, `GuGap`, `GuInsets`, `GuRadius`, `GuMotion`, `GuSizes`,
/// `GuOpacity`, `GuBreakpoints`) burada yoktur — tek erişim yolu (CD-18).
///
/// `Theme.of(context)` paket genelinde yalnızca burada çağrılır (HC03).
/// `Equatable` değildir; [GuThemeExtension.of] her `build`'de alanları
/// `const` referanslardan kuran hafif bir nesne döndürür.
@immutable
final class GuThemeExtension {
  const GuThemeExtension._({
    required this.colors,
    required this.text,
    required this.shadows,
    required this.component,
    required this.brightness,
    required this.reduceMotion,
    required this.textScaler,
  });

  /// `ThemeData.extensions`'tan token'ları, `MediaQuery`'den erişilebilirlik
  /// tercihlerini okur. Tema `GuTheme.light()/dark()` ile kurulmamışsa
  /// (extension eksik) debug'da assert ile durur.
  factory GuThemeExtension.of(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _require<GuColors>(theme);
    return GuThemeExtension._(
      colors: colors,
      text: _require<GuTypography>(theme),
      shadows: _require<GuShadows>(theme),
      component: _require<GuComponentColors>(theme),
      brightness: colors.brightness,
      reduceMotion: MediaQuery.maybeDisableAnimationsOf(context) ?? false,
      textScaler: MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling,
    );
  }

  /// Renk token'ları (`context.gu.colors.brandPrimary`).
  final GuColors colors;

  /// Tipografi (`context.gu.text.titleL`; renkler temaya bağlı).
  final GuTypography text;

  /// Gölgeler (`context.gu.shadows.e1`; koyu temada `[]`).
  final GuShadows shadows;

  /// Registry dışı bileşen renkleri (`context.gu.component.chipBorder`).
  final GuComponentColors component;

  /// Etkin tema parlaklığı ([GuColors.brightness]).
  final Brightness brightness;

  /// Koyu tema mı (token-map §1.1 koyu tema farkları).
  bool get isDark => brightness == Brightness.dark;

  /// Sistem "hareketi azalt" tercihi (`MediaQuery.disableAnimations`).
  final bool reduceMotion;

  /// Etkin metin ölçekleyici (`MediaQuery.textScaler`; `GuTextScale`
  /// sonrası, T-07).
  final TextScaler textScaler;

  /// Hareket azaltılmışsa `Duration.zero`, değilse [d]
  /// (`AnimatedX(duration: context.gu.duration(GuMotion.base))`).
  Duration duration(Duration d) => reduceMotion ? Duration.zero : d;

  static T _require<T>(ThemeData theme) {
    final extension = theme.extension<T>();
    assert(
      extension != null,
      'GuTheme.light()/dark() kullanılmalı: ThemeData.extensions içinde $T '
      'yok.',
    );
    return extension!;
  }
}
