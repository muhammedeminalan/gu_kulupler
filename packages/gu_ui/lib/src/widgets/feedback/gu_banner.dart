import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/icons/gu_icon.dart';
import 'package:gu_ui/src/icons/gu_icons.dart';
import 'package:gu_ui/src/tokens/gu_colors.dart';
import 'package:gu_ui/src/tokens/gu_motion.dart';
import 'package:gu_ui/src/tokens/gu_radius.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';
import 'package:gu_ui/src/widgets/primitives/gu_action_surface.dart';
import 'package:gu_ui/src/widgets/primitives/gu_icon_button.dart';

/// Bant türü — CSS `.banner-*` (css:250–255); varsayılan ikon `ui.js:87`.
enum GuBannerKind {
  /// `state.infoContainer` / `state.info`, `info`.
  info(GuIcons.info),

  /// `state.warningContainer` / `state.warning`, `triangle-alert`.
  warning(GuIcons.triangleAlert),

  /// `state.dangerContainer` / `state.danger`, `circle-x`; `role="alert"`.
  danger(GuIcons.circleX),

  /// `text.heading` zemin + `bg.surface` metin, `wifi-off` (kabuk çevrimdışı
  /// bandı, `shell.js:14`).
  offline(GuIcons.wifiOff),

  /// `bg.surfaceMuted` / `text.secondary`, `eye` (salt okunur görünüm).
  readonly(GuIcons.eye),

  /// `state.successContainer` / `state.success`, `circle-check`.
  success(GuIcons.circleCheck);

  const GuBannerKind(this.defaultIcon);

  /// [GuBanner.icon] verilmezse çizilen ikon.
  final GuIcons defaultIcon;

  /// (zemin, ön plan) renk çifti.
  (Color, Color) colorsOf(GuColors c) => switch (this) {
    GuBannerKind.info => (c.stateInfoContainer, c.stateInfo),
    GuBannerKind.warning => (c.stateWarningContainer, c.stateWarning),
    GuBannerKind.danger => (c.stateDangerContainer, c.stateDanger),
    GuBannerKind.offline => (c.textHeading, c.bgSurface),
    GuBannerKind.readonly => (c.bgSurfaceMuted, c.textSecondary),
    GuBannerKind.success => (c.stateSuccessContainer, c.stateSuccess),
  };
}

/// Bilgi bandı — prototip `Banner` (`ui.js:86–91`), CSS `.banner` /
/// `.banner-*` / `.is-card` / `.banner-text` (css:248–257). Kabuktaki
/// çevrimdışı bandı (`shell.js:14`) ve bakım bandı (K-27) da budur.
///
/// Satır: ikon 18 · [text] (500 13 / 1.4, sarar) · [trailing] (metnin
/// sonunda satır içi, 8 dp boşlukla — MGT-02 anahtarı) · [actionLabel]
/// (altı çizili metin düğmesi: 36 yükseklik, dolgu 10, renk banttan; en çok
/// satırın yarısı) · kapat (`x` 18, 40 px ikon düğmesi). Dolgu 10 / 16,
/// aralık 10, tam genişlik.
///
/// * [card] → radius `md` + yatay 16 dış boşluk (`.is-card`).
/// * `danger` → `role="alert"`: canlı bölge.
/// * Kapatılınca bandı çağıran kaldırır (CSS'te geçiş yok).
class GuBanner extends StatelessWidget {
  const GuBanner({
    required this.text,
    this.kind = GuBannerKind.info,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.actionKey,
    this.onDismiss,
    this.dismissActionKey,
    this.dismissSemanticLabel,
    this.card = false,
    this.trailing,
    super.key,
  }) : assert(
         (actionLabel == null) == (onAction == null),
         'actionLabel ve onAction birlikte verilir.',
       ),
       assert(
         onDismiss == null || dismissSemanticLabel != null,
         'onDismiss verildiyse dismissSemanticLabel de verilmeli.',
       );

  /// Bant metni (çağırandan; ARB).
  final String text;

  /// Tür (renk + varsayılan ikon).
  final GuBannerKind kind;

  /// İkon üst yazımı; `null` → [GuBannerKind.defaultIcon].
  final GuIcons? icon;

  /// Eylem düğmesi metni; `null` → düğme yok.
  final String? actionLabel;

  /// Eylem dokunması.
  final VoidCallback? onAction;

  /// Eylem düğmesi anahtarı (`GuKey.action`, çağırandan — CD-111).
  final Key? actionKey;

  /// Kapatma; `null` → kapat düğmesi yok.
  final VoidCallback? onDismiss;

  /// Kapat düğmesi anahtarı.
  final Key? dismissActionKey;

  /// Kapat düğmesi erişilebilirlik etiketi (ARB `a11yDismiss`).
  final String? dismissSemanticLabel;

  /// Kart görünümü (`.is-card`).
  final bool card;

  /// Metnin sonuna satır içi eklenen öğe (prototip `children`).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final (background, foreground) = kind.colorsOf(gu.colors);
    final actionLabel = this.actionLabel;
    final onAction = this.onAction;
    final onDismiss = this.onDismiss;
    final trailing = this.trailing;

    Widget body = DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: card ? GuRadius.borderMd : null,
      ),
      child: Padding(
        padding: GuInsets.sym(
          h: GuSizes.bannerPaddingX,
          v: GuSizes.bannerPaddingY,
        ),
        child: DefaultTextStyle(
          style: gu.text.banner.copyWith(color: foreground),
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
              spacing: GuSizes.bannerGap,
              children: [
                GuIcon(
                  icon ?? kind.defaultIcon,
                  size: GuSizes.bannerIcon,
                  color: foreground,
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: text,
                      children: [
                        if (trailing != null)
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Padding(
                              padding: GuInsets.only(left: GuSpacing.s8),
                              child: trailing,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (actionLabel != null && onAction != null)
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth / 2,
                    ),
                    child: _BannerAction(
                      key: actionKey,
                      label: actionLabel,
                      onTap: onAction,
                      foreground: foreground,
                    ),
                  ),
                if (onDismiss != null)
                  GuIconButton(
                    key: dismissActionKey,
                    icon: GuIcons.x,
                    semanticLabel: dismissSemanticLabel ?? '',
                    onPressed: onDismiss,
                    size: GuIconButtonSize.sm,
                    iconSize: GuSizes.bannerDismissIcon,
                    foregroundInherit: true,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (card) {
      body = Padding(
        padding: GuInsets.sym(h: GuSizes.bannerCardMarginX),
        child: body,
      );
    }
    return Semantics(
      container: true,
      liveRegion: kind == GuBannerKind.danger,
      child: body,
    );
  }
}

/// `.banner .btn-text` (css:257 + `.btn` css:139–140, `.btn-text:hover`
/// css:145): 36 px, dolgu 10, altı çizili, renk banttan; basılı `scale(.98)`
/// + `brand.primaryContainer` zemin (K-53).
class _BannerAction extends StatelessWidget {
  const _BannerAction({
    required this.label,
    required this.onTap,
    required this.foreground,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final Color foreground;

  @override
  Widget build(BuildContext context) => GuActionSurface(
    onTap: onTap,
    semanticLabel: label,
    borderRadius: GuRadius.borderSm,
    builder: (context, pressed) {
      final gu = context.gu;
      final duration = gu.duration(GuMotion.fast);
      return AnimatedScale(
        scale: pressed ? GuMotion.pressScale : 1,
        duration: duration,
        curve: GuMotion.easeCss,
        child: AnimatedContainer(
          duration: duration,
          curve: GuMotion.easeCss,
          constraints: const BoxConstraints(
            minHeight: GuSizes.bannerTextButtonHeight,
          ),
          padding: GuInsets.sym(h: GuSizes.bannerTextButtonPaddingX),
          decoration: BoxDecoration(
            color: pressed ? gu.colors.brandPrimaryContainer : null,
            borderRadius: GuRadius.borderSm,
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Text(
              label,
              style: gu.text.bannerAction.copyWith(
                color: foreground,
                decorationColor: foreground,
              ),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
    },
  );
}
