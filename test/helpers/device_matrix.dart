// Cihaz matrisi (D-21, testing.md §5, PLAN §16.2/§16.4, CD-42).
//
// Tam: 4 boyut × 2 tema × 2 dil × 3 metin ölçeği = 48 vaka.
// Hızlı (`--dart-define=GU_MATRIX=fast`): {320, 390} × açık × TR × {1.0, 1.6}
// = 4 vaka. Klavye (`viewInsets.bottom = 320`) ve 4 güvenli alan varyantı
// yalnızca 390×844 × açık × TR × 1.0 üzerinde, moddan bağımsız eklenir.
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_ui/gu_ui.dart';

import 'overflow_detector.dart';
import 'pump_app.dart';

/// Matris boyutları (dp).
enum MatrixSize {
  small(320, 640),
  reference(390, 844),
  large(430, 932),
  tablet(768, 1024);

  const MatrixSize(this.width, this.height);

  final double width;
  final double height;

  Size get size => Size(width, height);
}

/// Tek matris vakası.
final class MatrixCase extends Equatable {
  const MatrixCase({
    required this.size,
    required this.theme,
    required this.locale,
    required this.textScale,
    this.keyboardInset = 0,
    this.viewPadding = EdgeInsets.zero,
  });

  final MatrixSize size;
  final ThemeMode theme;
  final Locale locale;
  final double textScale;

  /// Klavye yüksekliği (`viewInsets.bottom`; 0 = kapalı).
  final double keyboardInset;

  /// Güvenli alan (`viewPadding`).
  final EdgeInsets viewPadding;

  /// Benzersiz, okunur vaka adı (hata mesajlarında):
  /// `small 320×640 · light · tr · 1.0` (+ ` · klavye 320`,
  /// ` · alan t47 b0`).
  String get name {
    final parts = [
      '${size.name} ${size.width.round()}×${size.height.round()}',
      theme.name,
      locale.languageCode,
      textScale.toStringAsFixed(1),
      if (keyboardInset > 0) 'klavye ${keyboardInset.round()}',
      if (viewPadding != EdgeInsets.zero)
        'alan t${viewPadding.top.round()} b${viewPadding.bottom.round()}',
    ];
    return parts.join(' · ');
  }

  @override
  List<Object?> get props => [
    size,
    theme,
    locale,
    textScale,
    keyboardInset,
    viewPadding,
  ];

  @override
  String toString() => 'MatrixCase($name)';
}

abstract final class DeviceMatrix {
  /// Kapı seçimi: `flutter test --dart-define=GU_MATRIX=fast|full`.
  static const String mode = String.fromEnvironment(
    'GU_MATRIX',
    defaultValue: 'full',
  );

  /// Metin ölçekleri (Q-14).
  static const List<double> textScales = [1.0, 1.3, 1.6];

  /// Matris temaları.
  static const List<ThemeMode> themes = [ThemeMode.light, ThemeMode.dark];

  /// Matris dilleri.
  static const List<Locale> locales = [Locale('tr'), Locale('en')];

  /// Klavye açık varyantının `viewInsets.bottom` değeri (testing.md §5).
  static const double keyboardInset = 320;

  /// Güvenli alan varyantları: üst 47 (çentik) · üst 59 (Dynamic Island) ·
  /// alt 34 (home indicator) · Android üst 24 + alt 48 (sistem çubukları).
  static const List<EdgeInsets> safeAreaVariants = [
    EdgeInsets.only(top: 47),
    EdgeInsets.only(top: 59),
    EdgeInsets.only(bottom: 34),
    EdgeInsets.only(top: 24, bottom: 48),
  ];

  /// Varyantların taban vakası: 390×844 × açık × TR × 1.0.
  static const MatrixCase referenceCase = MatrixCase(
    size: MatrixSize.reference,
    theme: ThemeMode.light,
    locale: Locale('tr'),
    textScale: 1,
  );

  /// [mode] (varsayılan [DeviceMatrix.mode]) için temel vakalar:
  /// `full` 48, `fast` 4.
  static List<MatrixCase> cases({String? mode}) {
    final selected = mode ?? DeviceMatrix.mode;
    return switch (selected) {
      'full' => [
        for (final size in MatrixSize.values)
          for (final theme in themes)
            for (final locale in locales)
              for (final scale in textScales)
                MatrixCase(
                  size: size,
                  theme: theme,
                  locale: locale,
                  textScale: scale,
                ),
      ],
      'fast' => [
        for (final size in const [MatrixSize.small, MatrixSize.reference])
          for (final scale in const [1.0, 1.6])
            MatrixCase(
              size: size,
              theme: ThemeMode.light,
              locale: const Locale('tr'),
              textScale: scale,
            ),
      ],
      _ => throw ArgumentError.value(
        selected,
        'mode',
        'GU_MATRIX full ya da fast olmalı',
      ),
    };
  }

  /// Klavye (1) ve güvenli alan (4) varyantları — yalnızca [referenceCase].
  static List<MatrixCase> variantCases({
    bool keyboard = false,
    bool safeAreas = false,
  }) => [
    if (keyboard)
      MatrixCase(
        size: referenceCase.size,
        theme: referenceCase.theme,
        locale: referenceCase.locale,
        textScale: referenceCase.textScale,
        keyboardInset: keyboardInset,
      ),
    if (safeAreas)
      for (final padding in safeAreaVariants)
        MatrixCase(
          size: referenceCase.size,
          theme: referenceCase.theme,
          locale: referenceCase.locale,
          textScale: referenceCase.textScale,
          viewPadding: padding,
        ),
  ];

  /// [builder]'ı her vakada `pumpApp` ile çizer → `pump(GuMotion.base)` →
  /// `OverflowDetector.assertNone(vaka adı)` → `takeException() == null`.
  /// İlk ihlalde `TestFailure` (mesajda vaka adı). Her vaka yeni ağaçtır.
  static Future<void> run(
    WidgetTester tester,
    WidgetBuilder builder, {
    List<Override> overrides = const [],
    bool keyboard = false,
    bool safeAreas = false,
    String? mode,
    bool wrapInShell = false,
    GuTab shellTab = GuTab.clubs,
  }) async {
    final all = [
      ...cases(mode: mode),
      ...variantCases(keyboard: keyboard, safeAreas: safeAreas),
    ];
    OverflowDetector.install();
    try {
      for (final c in all) {
        OverflowDetector.reset();
        await tester.pumpApp(
          Builder(builder: builder),
          locale: c.locale,
          theme: c.theme,
          textScale: c.textScale,
          size: c.size.size,
          overrides: overrides,
          viewPadding: c.viewPadding,
          keyboardInset: c.keyboardInset,
          wrapInShell: wrapInShell,
          shellTab: shellTab,
        );
        await tester.pump(GuMotion.base);
        OverflowDetector.assertNone(c.name);
        expect(
          tester.takeException(),
          isNull,
          reason: 'Beklenmeyen istisna (${c.name})',
        );
      }
    } finally {
      OverflowDetector.uninstall();
      OverflowDetector.reset();
    }
  }
}
