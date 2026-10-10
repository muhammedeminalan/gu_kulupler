import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/icons/gu_icon.dart';
import 'package:gu_ui/src/icons/gu_icons.dart';
import 'package:gu_ui/src/tokens/gu_colors.dart';
import 'package:gu_ui/src/tokens/gu_radius.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';

/// İkon kutusu tonu — CSS `.ni-*` (css:406).
enum GuIconBoxTone {
  /// `brand.primaryContainer` + `brand.primaryText`.
  brand,

  /// `state.successContainer` + `state.success`.
  success,

  /// `state.dangerContainer` + `state.danger`.
  danger,

  /// `state.infoContainer` + `state.info`.
  info,

  /// `state.warningContainer` + `state.warning`.
  warning,

  /// `bg.surfaceMuted` + `text.secondary`.
  neutral;

  /// (zemin, ikon) renk çifti.
  (Color background, Color foreground) resolve(GuColors c) => switch (this) {
    brand => (c.brandPrimaryContainer, c.brandPrimaryText),
    success => (c.stateSuccessContainer, c.stateSuccess),
    danger => (c.stateDangerContainer, c.stateDanger),
    info => (c.stateInfoContainer, c.stateInfo),
    warning => (c.stateWarningContainer, c.stateWarning),
    neutral => (c.bgSurfaceMuted, c.textSecondary),
  };
}

/// Daire ikon kutusu — CSS `.notif-icon` + `.ni-*` (css:405–406; prototipte
/// ayrı bileşen yok: `NotificationRow` `cards.js:139`, `DialogFrame` ikonu
/// `ui.js:186`, `Tile` leading).
///
/// Varsayılan 40 px daire + 20 px ikon; SHT-24 sonuç ikonu
/// `size: GuSizes.notifIconLg`, `iconSize: GuSizes.notifIconLgIcon`
/// (`sheets.js:116`). Kare amblem için `GuEmblem` (G9, CD-91).
/// [semanticLabel] verilmezse dekoratiftir.
class GuIconBox extends StatelessWidget {
  const GuIconBox({
    required this.icon,
    this.tone = GuIconBoxTone.brand,
    this.size = GuSizes.notifIcon,
    this.iconSize = GuSizes.icon20,
    this.semanticLabel,
    super.key,
  });

  /// Kutudaki ikon.
  final GuIcons icon;

  /// Renk tonu.
  final GuIconBoxTone tone;

  /// Daire çapı (dp).
  final double size;

  /// İkon kenarı (dp).
  final double iconSize;

  /// Erişilebilirlik etiketi; `null` → dekoratif.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = tone.resolve(context.gu.colors);
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: GuRadius.borderFull,
        ),
        child: Center(
          child: GuIcon(
            icon,
            size: iconSize,
            color: foreground,
            semanticLabel: semanticLabel,
          ),
        ),
      ),
    );
  }
}
