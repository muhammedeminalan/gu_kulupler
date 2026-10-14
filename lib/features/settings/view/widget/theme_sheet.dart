import 'dart:async';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/init/app_preferences_view_model.dart';
import 'package:gu_ui/gu_ui.dart';

/// SHT-17 Tema — SET-01 "Tema" satırı (`sheets.js:84–86`).
///
/// Üç eşit sütun (`.grid3`, aralık 12) seçenek kartı (`GuOptionCard`):
/// Sistem (açık + koyu iki küçük önizleme, aralık 4), Açık, Koyu. Kartta
/// önizleme + ad (`labelM`, `text.heading`, ortalı; aralık 8). Seçili kart
/// etkin tercihtir (`AppPreferencesState.themeMode`).
///
/// Dokunma tercihi yazar (`AppPreferencesViewModel.setThemeMode` — kalıcı,
/// `pref.themeMode`) ve sayfayı kapatır (sonuç yok):
///
/// ```dart
/// feedback.showSheet<void>(
///   SheetId.sht17,
///   builder: (_) => const ThemeSheet(),
/// );
/// ```
///
/// Anahtarlar `SHT-17.select.system|light|dark`, `SHT-17.close`.
///
/// Design: SHT-17
class ThemeSheet extends ConsumerWidget {
  /// Tema alt sayfası.
  const ThemeSheet({super.key});

  /// Seçenekler, ekrandaki sırayla (`['system', 'light', 'dark']`).
  static const List<ThemeMode> modes = <ThemeMode>[
    ThemeMode.system,
    ThemeMode.light,
    ThemeMode.dark,
  ];

  /// [mode] seçeneğinin aksiyon anahtarı.
  static Key keyOf(ThemeMode mode) => switch (mode) {
    ThemeMode.system => GuKey.action('SHT-17.select.system'),
    ThemeMode.light => GuKey.action('SHT-17.select.light'),
    ThemeMode.dark => GuKey.action('SHT-17.select.dark'),
  };

  /// [mode] seçeneğinin adı ("Sistem", "Açık", "Koyu").
  static String labelOf(AppLocalizations l10n, ThemeMode mode) =>
      switch (mode) {
        ThemeMode.system => l10n.themeSystem,
        ThemeMode.light => l10n.themeLight,
        ThemeMode.dark => l10n.themeDark,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final current = ref.watch(
      appPreferencesViewModelProvider.select((s) => s.themeMode),
    );

    void select(ThemeMode mode) {
      unawaited(
        ref.read(appPreferencesViewModelProvider.notifier).setThemeMode(mode),
      );
      context.pop();
    }

    return GuSheetFrame(
      title: l10n.sht17Title,
      closeSemanticLabel: l10n.a11yClose,
      closeKey: FeedbackKeys.of(SheetId.sht17.designId, 'close'),
      // `.grid3.pb16`.
      body: Padding(
        padding: GuInsets.only(bottom: GuSpacing.s16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: GuSpacing.s12,
          children: [
            for (final mode in modes)
              Expanded(
                child: GuOptionCard(
                  key: keyOf(mode),
                  selected: mode == current,
                  semanticLabel: labelOf(l10n, mode),
                  onTap: () => select(mode),
                  child: _ThemeOption(
                    mode: mode,
                    label: labelOf(l10n, mode),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Kart içeriği — `.col.gap8` (`align-items:stretch`): önizleme + ad.
class _ThemeOption extends StatelessWidget {
  const _ThemeOption({required this.mode, required this.label});

  final ThemeMode mode;
  final String label;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: GuSpacing.s8,
      children: [
        switch (mode) {
          // `.row.gap4` > `.flex1` × 2.
          ThemeMode.system => const Row(
            spacing: GuSpacing.s4,
            children: [
              Expanded(child: _ThemeMini(palette: GuColors.light)),
              Expanded(child: _ThemeMini(palette: GuColors.dark)),
            ],
          ),
          ThemeMode.light => const _ThemeMini(palette: GuColors.light),
          ThemeMode.dark => const _ThemeMini(palette: GuColors.dark),
        },
        Text(
          label,
          textAlign: TextAlign.center,
          style: gu.text.labelM.copyWith(color: gu.colors.textHeading),
        ),
      ],
    );
  }
}

/// Küçük tema önizlemesi — prototip `Mini` (`sheets.js:85`): [palette]
/// temasının zemini üstünde marka çubuğu ve yüzey kutusu. Dış kenarlık
/// **etkin** temanın `border.default`'udur (`var(--border-default)`); iç
/// renkler [palette]'ten gelir (açık önizleme koyu temada da açıktır).
class _ThemeMini extends StatelessWidget {
  const _ThemeMini({required this.palette});

  final GuColors palette;

  /// `height:48px`.
  static const double _height = GuSpacing.s48;

  /// Çubuk ve kutunun sol / sağ / üst boşluğu (`left:8px; top:8px`).
  static const double _inset = GuSpacing.s8;

  /// Marka çubuğu: `width:40%; height:8px`.
  static const double _barShare = 0.4;
  static const double _barHeight = GuSpacing.s8;

  /// Yüzey kutusu: `top:22px; height:16px`.
  static const double _boxTop = GuSpacing.s20 + GuSpacing.s2;
  static const double _boxHeight = GuSpacing.s16;

  /// Kenarlık kalınlığı (`1px`).
  static const double _border = GuSizes.cardBorder;

  /// Dış radius `8px`, iç radius `4px`.
  static const BorderRadius _outerRadius = BorderRadius.all(
    Radius.circular(GuSpacing.s8),
  );
  static const BorderRadius _innerRadius = BorderRadius.all(
    Radius.circular(GuSpacing.s4),
  );

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: palette.bgCanvas,
        borderRadius: _outerRadius,
        border: Border.all(
          color: context.gu.colors.borderDefault,
          // Token değeri varsayılanla (1) aynı; kaynak token kalır.
          // ignore: avoid_redundant_argument_values
          width: _border,
        ),
      ),
      child: Padding(
        // `box-sizing:border-box`: yükseklik kenarlığı içerir; mutlak
        // konumlar kenarlığın içinden (dolgu kutusu) ölçülür.
        padding: GuInsets.sym(h: _border, v: _border),
        child: SizedBox(
          height: _height - _border * 2,
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                Positioned(
                  left: _inset,
                  top: _inset,
                  width: constraints.maxWidth * _barShare,
                  height: _barHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: palette.brandPrimary,
                      borderRadius: _innerRadius,
                    ),
                  ),
                ),
                Positioned(
                  left: _inset,
                  right: _inset,
                  top: _boxTop,
                  height: _boxHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: palette.bgSurface,
                      borderRadius: _innerRadius,
                      border: Border.all(
                        color: palette.borderDefault,
                        // Token değeri varsayılanla (1) aynı; kaynak token kalır.
                        // ignore: avoid_redundant_argument_values
                        width: _border,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
